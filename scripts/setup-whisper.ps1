param(
    [string]$Destination = (Join-Path $PSScriptRoot '../optional/whisper'),
    [switch]$WithTinyModel
)
$ErrorActionPreference = 'Stop'
$Destination = [IO.Path]::GetFullPath($Destination)
New-Item -ItemType Directory -Force -Path $Destination | Out-Null
function Get-VerifiedAsset([string]$Url, [string]$Path, [string]$Sha256) {
    if (!(Test-Path -LiteralPath $Path) -or (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLower() -ne $Sha256) {
        Invoke-WebRequest -Uri $Url -OutFile ($Path + '.download')
        if ((Get-FileHash -LiteralPath ($Path + '.download') -Algorithm SHA256).Hash.ToLower() -ne $Sha256) { throw ('Checksum mismatch: ' + $Path) }
        Move-Item -LiteralPath ($Path + '.download') -Destination $Path -Force
    }
}
$archive = Join-Path $Destination 'whisper-v1.9.2-x64.zip'
Get-VerifiedAsset 'https://github.com/ggml-org/whisper.cpp/releases/download/v1.9.2/whisper-bin-x64.zip' $archive '49dcc16de826f20bd53d44f947a1ae49dfa81f86cad67a64d80820cb192d674a'
Expand-Archive -LiteralPath $archive -DestinationPath $Destination -Force
if ($WithTinyModel) {
    Get-VerifiedAsset 'https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-tiny.bin' (Join-Path $Destination 'ggml-tiny.bin') 'be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21'
}
Write-Output ('Choose this executable in VDM subtitle settings: ' + (Join-Path $Destination 'Release/whisper-cli.exe'))
if ($WithTinyModel) { Write-Output ('Multilingual model: ' + (Join-Path $Destination 'ggml-tiny.bin')) }
Write-Output 'Keep the DLL files beside whisper-cli.exe. Tiny is for testing; larger multilingual models usually transcribe more accurately.'
