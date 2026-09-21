param([switch]$SkipAssets, [switch]$SkipTests, [switch]$SkipInstaller)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Set-Location -LiteralPath $root
$flutter = Join-Path $root '.tools/flutter/bin/flutter.bat'
if (!(Test-Path -LiteralPath $flutter)) {
    $found = Get-Command flutter -ErrorAction SilentlyContinue
    if (!$found) { throw 'Install Flutter 3.47.5 or run scripts/setup-flutter.ps1 first.' }
    $flutter = $found.Source
}
$expectedFlutter = (Get-Content -LiteralPath (Join-Path $root 'desktop/toolchain.lock.json') -Raw | ConvertFrom-Json).flutter.version
$installedFlutter = (& $flutter --version --machine | ConvertFrom-Json).frameworkVersion
if ($LASTEXITCODE -or $installedFlutter -ne $expectedFlutter) { throw ('This build requires Flutter '+$expectedFlutter) }
if (!$SkipAssets) { python scripts/bootstrap_assets.py; if ($LASTEXITCODE) { throw 'Asset bootstrap failed' } }
Push-Location desktop
try {
    & $flutter pub get
    # Directory junctions work without changing Windows Developer Mode.
    if ($LASTEXITCODE -and (Test-Path '.flutter-plugins-dependencies')) {
        $metadata = Get-Content '.flutter-plugins-dependencies' -Raw | ConvertFrom-Json
        $links = Join-Path $PWD 'windows/flutter/ephemeral/.plugin_symlinks'
        New-Item -ItemType Directory -Force -Path $links | Out-Null
        foreach ($plugin in $metadata.plugins.windows) {
            $link = Join-Path $links $plugin.name
            if (!(Test-Path -LiteralPath $link)) { New-Item -ItemType Junction -Path $link -Target $plugin.path | Out-Null }
        }
        & $flutter pub get
        if ($LASTEXITCODE) { throw 'Flutter dependency resolution failed' }
    }
    if (!$SkipTests) {
        & $flutter analyze --no-pub; if ($LASTEXITCODE) { throw 'Static analysis failed' }
        & $flutter test --no-pub; if ($LASTEXITCODE) { throw 'Flutter tests failed' }
        node --test ../browser-extension/protocol.test.mjs; if ($LASTEXITCODE) { throw 'Browser protocol tests failed' }
    }
    & $flutter build windows --release --no-pub
    if ($LASTEXITCODE) { throw 'Windows build failed' }
} finally { Pop-Location }
$release = Join-Path $root 'desktop/build/windows/x64/runner/Release'
$stage = Join-Path $root 'artifacts/VDM-2.0.0-windows-x64'
New-Item -ItemType Directory -Force -Path $stage | Out-Null
Copy-Item -Path (Join-Path $release '*') -Destination $stage -Recurse -Force
Copy-Item -LiteralPath (Join-Path $root 'browser-extension') -Destination $stage -Recurse -Force
Copy-Item -LiteralPath (Join-Path $root 'docs/VDM-2-User-Guide.md') -Destination (Join-Path $stage 'README.md') -Force
Copy-Item -LiteralPath (Join-Path $root 'desktop/assets.lock.json') -Destination $stage -Force
Copy-Item -LiteralPath (Join-Path $root 'desktop/toolchain.lock.json') -Destination $stage -Force
Copy-Item -LiteralPath (Join-Path $root 'desktop/assets/legal') -Destination $stage -Recurse -Force

# Include the Visual C++ runtime app-locally, so no Python, Flutter or global
# runtime installation is required on the destination machine.
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$vs = & $vswhere -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
$redist = Get-ChildItem -Path (Join-Path $vs 'VC/Redist/MSVC/*/x64/Microsoft.VC*.CRT') -Directory | Sort-Object FullName -Descending | Select-Object -First 1
if (!$redist) { throw 'Visual C++ redistributable DLLs were not found' }
Copy-Item -Path (Join-Path $redist.FullName '*.dll') -Destination $stage -Force

$lock = Get-Content desktop/assets.lock.json -Raw | ConvertFrom-Json
foreach ($file in $lock.files) {
    if ($file.path.StartsWith('engines/')) {
        $actual = (Get-FileHash -LiteralPath (Join-Path $stage $file.path) -Algorithm SHA256).Hash.ToLower()
        if ($actual -ne $file.sha256) { throw ('Runtime hash mismatch: '+$file.path) }
    }
}
Compress-Archive -Path $stage -DestinationPath (Join-Path $root 'artifacts/VDM-2.0.0-windows-x64.zip') -Force
Compress-Archive -Path (Join-Path $root 'browser-extension') -DestinationPath (Join-Path $root 'artifacts/VDM-2.0.0-browser-extension.zip') -Force
if (!$SkipInstaller) {
    $iscc = Join-Path $root '.tools/inno/ISCC.exe'
    if (!(Test-Path $iscc)) { $iscc = (Get-Command ISCC -ErrorAction Stop).Source }
    & $iscc scripts/installer.iss
    if ($LASTEXITCODE) { throw 'Installer build failed' }
}
Get-ChildItem -LiteralPath (Join-Path $root 'artifacts') -File | Where-Object Extension -in '.exe','.zip' | ForEach-Object {
    $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLower()
    "$hash  $($_.Name)"
} | Set-Content -LiteralPath (Join-Path $root 'artifacts/SHA256SUMS.txt')
Write-Output 'Windows release artifacts are ready in artifacts/.'
