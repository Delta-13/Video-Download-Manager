$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$toolsDir = Join-Path $root '.tools'
New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
$asset = (Get-Content -LiteralPath (Join-Path $root 'desktop/toolchain.lock.json') -Raw | ConvertFrom-Json).innoSetup
$installer = Join-Path $toolsDir 'inno-setup.exe'
Invoke-WebRequest $asset.url -OutFile $installer
$hash = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLower()
if ($hash -ne $asset.sha256) { throw 'Inno checksum mismatch' }
if ((Get-AuthenticodeSignature -LiteralPath $installer).Status -ne 'Valid') { throw 'Invalid Inno Setup signature' }
$dest = Join-Path $toolsDir 'inno'
$process = Start-Process -FilePath $installer -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-','/PORTABLE=1',('/DIR="'+$dest+'"')) -WindowStyle Hidden -Wait -PassThru
if ($process.ExitCode) { throw 'Inno Setup portable extraction failed' }
Write-Output ('Inno Setup 7.1.0 is available at '+$dest)
