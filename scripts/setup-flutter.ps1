$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$toolDir = Join-Path $root '.tools'
New-Item -ItemType Directory -Force -Path $toolDir | Out-Null
$release = (Get-Content -LiteralPath (Join-Path $root 'desktop/toolchain.lock.json') -Raw | ConvertFrom-Json).flutter
$archive = Join-Path $toolDir 'flutter-sdk.zip'
if (!(Test-Path -LiteralPath $archive) -or (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLower() -ne $release.sha256) {
    Invoke-WebRequest $release.url -OutFile $archive
}
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLower() -ne $release.sha256) { throw 'Flutter checksum mismatch' }
Expand-Archive -LiteralPath $archive -DestinationPath $toolDir -Force
& (Join-Path $toolDir 'flutter/bin/flutter.bat') --disable-analytics
& (Join-Path $toolDir 'flutter/bin/flutter.bat') doctor -v
