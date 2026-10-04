param([string]$Executable = (Join-Path $PSScriptRoot '../bin/ffmpeg.exe'))
$ErrorActionPreference = 'Stop'
$ffmpeg = [IO.Path]::GetFullPath($Executable)
$root = Join-Path ([IO.Path]::GetTempPath()) ('ffmpeg-audio-smoke-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($root) | Out-Null
function Run-Ffmpeg([string[]]$Arguments) {
    $start = [Diagnostics.ProcessStartInfo]::new($ffmpeg)
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.WorkingDirectory = $root
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::Start($start)
    try {
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(60000)) { $process.Kill($true); $process.WaitForExit(); throw 'Audio smoke timed out.' }
        [Threading.Tasks.Task]::WaitAll(@($stdout, $stderr))
        if ($process.ExitCode -ne 0) { throw "FFmpeg failed: $($stderr.Result)" }
    }
    finally { $process.Dispose() }
}
try {
    # A synthetic PCM fixture; the production build intentionally has no lavfi input device.
    $source = Join-Path $root 'input.wav'
    $writer = [IO.BinaryWriter]::new([IO.File]::Create($source))
    try {
        $frames = 48000 * 3
        $writer.Write([Text.Encoding]::ASCII.GetBytes('RIFF'))
        $writer.Write([int](36 + $frames * 4))
        $writer.Write([Text.Encoding]::ASCII.GetBytes('WAVEfmt '))
        $writer.Write([int]16); $writer.Write([short]1); $writer.Write([short]2)
        $writer.Write([int]48000); $writer.Write([int]192000); $writer.Write([short]4); $writer.Write([short]16)
        $writer.Write([Text.Encoding]::ASCII.GetBytes('data')); $writer.Write([int]($frames * 4))
        for ($i = 0; $i -lt $frames; $i++) {
            $sample = [short](10000 * [Math]::Sin(2 * [Math]::PI * 440 * $i / 48000))
            $writer.Write($sample); $writer.Write($sample)
        }
    }
    finally { $writer.Dispose() }
    $base = @('-hide_banner', '-nostdin', '-nostats', '-loglevel', 'error', '-xerror', '-i', $source, '-map', '0:a:0', '-vn', '-sn', '-dn')
    Run-Ffmpeg -Arguments ($base + @('-f', 'null', '-'))
    # Match PenguinTools' loudness-analysis and conversion filter chains, including stats_file.
    foreach ($offsetFilter in @('adelay=delays=25:all=1', 'atrim=start=0.025,asetpts=PTS-STARTPTS')) {
        $statsName = 'loudness.json'
        $statsPath = Join-Path $root $statsName
        if (Test-Path -LiteralPath $statsPath) { Remove-Item -LiteralPath $statsPath }
        $analysis = "$offsetFilter,loudnorm=I=-8.5:LRA=11:TP=0:linear=true:print_format=json:stats_file=$statsName"
        Run-Ffmpeg -Arguments ($base + @('-af', $analysis, '-f', 'null', '-'))
        if (-not (Test-Path -LiteralPath $statsPath)) { throw 'Loudness statistics file was not produced.' }
        $stats = Get-Content -LiteralPath $statsPath -Raw | ConvertFrom-Json
        foreach ($name in @('input_i', 'input_tp', 'input_lra')) {
            $value = [double]::Parse([string]$stats.$name, [Globalization.CultureInfo]::InvariantCulture)
            if ([double]::IsNaN($value) -or [double]::IsInfinity($value)) { throw "Invalid loudness statistic: $name" }
        }
        $gain = [Math]::Min(-8.5 - [double]$stats.input_i, -[double]$stats.input_tp).ToString('0.#########', [Globalization.CultureInfo]::InvariantCulture)
        $destination = Join-Path $root 'output.wav'
        Run-Ffmpeg -Arguments (@('-y') + $base + @('-af', "$offsetFilter,volume=${gain}dB:precision=double,aformat=sample_fmts=s16:sample_rates=48000:channel_layouts=stereo", '-c:a', 'pcm_s16le', '-ar', '48000', '-ac', '2', '-f', 'wav', $destination))
        $reader = [IO.BinaryReader]::new([IO.File]::OpenRead($destination))
        try {
            if ([Text.Encoding]::ASCII.GetString($reader.ReadBytes(4)) -ne 'RIFF') { throw 'Expected RIFF WAV.' }
            $null = $reader.ReadUInt32()
            if ([Text.Encoding]::ASCII.GetString($reader.ReadBytes(4)) -ne 'WAVE') { throw 'Expected WAVE header.' }
            $formatFound = $false
            while ($reader.BaseStream.Position + 8 -le $reader.BaseStream.Length) {
                $chunk = [Text.Encoding]::ASCII.GetString($reader.ReadBytes(4)); $length = $reader.ReadUInt32()
                $next = $reader.BaseStream.Position + $length + ($length % 2)
                if ($chunk -eq 'fmt ') {
                    $format = $reader.ReadUInt16(); $channels = $reader.ReadUInt16(); $rate = $reader.ReadUInt32()
                    $null = $reader.ReadUInt32(); $null = $reader.ReadUInt16(); $bits = $reader.ReadUInt16()
                    if ($format -ne 1 -or $channels -ne 2 -or $rate -ne 48000 -or $bits -ne 16) { throw 'Incorrect WAV encoding.' }
                    $formatFound = $true
                }
                $reader.BaseStream.Position = $next
            }
            if (-not $formatFound -or $reader.BaseStream.Length -lt 500000) { throw 'Incomplete WAV output.' }
        }
        finally { $reader.Dispose() }
    }
    Write-Host 'Audio smoke passed: decode, stats_file, gain, positive/negative offsets, 48 kHz stereo PCM16 WAV.'
}
finally {
    $resolved = [IO.Path]::GetFullPath($root)
    $parent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($parent, [StringComparison]::OrdinalIgnoreCase)) { throw 'Refusing cleanup outside the temporary root.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
