param([string]$PackageDirectory = '', [string]$ReportName = 'portable-runtime.json')
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!$PackageDirectory) { $PackageDirectory = Join-Path $root 'artifacts/VDM-2.0.0-windows-x64' }
$package = [IO.Path]::GetFullPath($PackageDirectory)
$report = Join-Path $root ('artifacts/'+$ReportName)
if (Test-Path -LiteralPath $report) { Remove-Item -LiteralPath $report }
$start = New-Object System.Diagnostics.ProcessStartInfo
$start.FileName = Join-Path $package 'vdm.exe'
$start.Arguments = '--verify-runtime "'+$report+'"'
$start.WorkingDirectory = $env:TEMP
$start.UseShellExecute = $false
$start.CreateNoWindow = $true
$start.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
# No developer SDK, Python, Motrix or globally installed engine can be found.
$start.EnvironmentVariables['PATH'] = $env:SystemRoot+'\System32;'+$env:SystemRoot
$process = [System.Diagnostics.Process]::Start($start)
if (!$process.WaitForExit(90000)) { $process.Kill(); throw 'Package verification timed out' }
if ($process.ExitCode -ne 0) { throw ('Package verification failed: '+$process.ExitCode) }
$result = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
if (!$result.ok) { throw 'Runtime checks did not pass' }
Get-Content -LiteralPath $report
