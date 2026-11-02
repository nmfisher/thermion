param(
    [Parameter(Mandatory = $true)]
    [string]$BundleDirectory
)

$ErrorActionPreference = 'Stop'
$bundle = (Resolve-Path $BundleDirectory).Path
$executable = Join-Path $bundle 'thermion_blit_worker_shutdown_test.exe'
$fixture = Join-Path $bundle 'thermion_blit_worker_shutdown_fixture.dll'
$failed = $false

foreach ($mode in @('no-worker', 'normal-teardown', 'exit-process', 'crt-exit')) {
    $stdout = Join-Path $bundle "shutdown-$mode.stdout.log"
    $stderr = Join-Path $bundle "shutdown-$mode.stderr.log"
    $process = Start-Process -FilePath $executable `
        -ArgumentList "`"$fixture`" $mode" `
        -WorkingDirectory $bundle -PassThru `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if (-not $process.WaitForExit(30000)) {
        $process.Kill()
        $process.WaitForExit()
        Write-Host "::error::$mode timed out during plugin shutdown"
        $failed = $true
        continue
    }

    $output = Get-Content $stdout -Raw
    Get-Content $stdout
    Get-Content $stderr
    $marker = switch ($mode) {
        'no-worker' { 'plugin-loaded' }
        'normal-teardown' { 'plugin-destroyed' }
        default { 'worker-started' }
    }
    # The marker proves startup reached the intended code path; an early exit
    # or DLL load failure must never count as a passing shutdown test.
    if ($process.ExitCode -ne 0 -or $output -notmatch $marker) {
        Write-Host "::error::$mode failed: exit code $($process.ExitCode); required marker: $marker"
        $failed = $true
    } else {
        Write-Host "$mode passed (exit code 0)"
    }
}

if ($failed) {
    exit 1
}
