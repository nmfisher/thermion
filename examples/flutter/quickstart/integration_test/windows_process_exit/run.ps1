param(
    [Parameter(Mandatory = $true)]
    [string]$BundleDirectory
)

$ErrorActionPreference = 'Stop'
$bundle = (Resolve-Path $BundleDirectory).Path
$executable = Join-Path $bundle 'quickstart.exe'
$failed = $false

foreach ($mode in @('no-viewer', 'window-close', 'dart-exit')) {
    $ready = Join-Path $bundle "shutdown-$mode.ready"
    $stdout = Join-Path $bundle "shutdown-$mode.stdout.log"
    $stderr = Join-Path $bundle "shutdown-$mode.stderr.log"
    Remove-Item $ready -ErrorAction SilentlyContinue
    $process = Start-Process -FilePath $executable `
        -ArgumentList "$mode `"$ready`"" -WorkingDirectory $bundle -PassThru `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $closeRequested = $false
    while (-not $process.WaitForExit(100)) {
        if ($mode -eq 'window-close' -and -not $closeRequested -and (Test-Path $ready)) {
            $process.Refresh()
            $closeRequested = $process.CloseMainWindow()
        }
        if ($timer.Elapsed.TotalSeconds -ge 120) {
            $process.Kill()
            $process.WaitForExit()
            Write-Host "::error::$mode timed out during startup or shutdown"
            $failed = $true
            break
        }
    }
    Get-Content $stdout
    Get-Content $stderr
    $marker = switch ($mode) {
        'no-viewer' { 'flutter-ready' }
        'window-close' { 'viewer-disposed' }
        'dart-exit' { 'frame-published' }
    }
    $readyContent = if (Test-Path $ready) { Get-Content $ready -Raw } else { '' }
    if ($process.ExitCode -ne 0 -or $readyContent -ne $marker -or
        ($mode -eq 'window-close' -and -not $closeRequested)) {
        Write-Host "::error::$mode failed: exit code $($process.ExitCode); readiness '$readyContent' (expected '$marker')"
        $failed = $true
    } else {
        Write-Host "$mode passed (exit code 0)"
    }
}
if ($failed) { exit 1 }
