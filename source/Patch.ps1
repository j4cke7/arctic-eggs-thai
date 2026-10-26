[CmdletBinding()]
param([ValidateSet('Install','Uninstall','Status')][string]$Action='Install', [string]$GameRoot)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$expectedManifest='4dd063b4f5b530726a2511df055d4b4e3204b4b2559c294ca7b8e7318274c0f9'
$sidecarName='ArcticEggs-Thai-replace-en'
function Sha([string]$Path) {
    $stream=[IO.File]::OpenRead($Path); $hasher=[Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($hasher.ComputeHash($stream)).Replace('-','').ToLowerInvariant() }
    finally { $hasher.Dispose(); $stream.Dispose() }
}
function Safe([string]$Path) {
    $cursor=[IO.Path]::GetFullPath($Path)
    while ($cursor) {
        $entry=Get-Item -Force -LiteralPath $cursor -ErrorAction SilentlyContinue
        if ($entry -and ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Reparse point refused: $cursor" }
        $parent=[IO.Path]::GetDirectoryName($cursor)
        if ($parent -eq $cursor) { break }; $cursor=$parent
    }
}
function Discover {
    $roots=@()
    foreach ($key in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam')) {
        $entry=Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
        if ($entry) { foreach ($property in @('SteamPath','InstallPath')) { if ($entry.PSObject.Properties.Name -contains $property) { $roots += $entry.$property } } }
    }
    $libraries=@($roots)
    foreach ($root in $roots) {
        $file=Join-Path $root 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $file) { foreach ($match in [regex]::Matches([IO.File]::ReadAllText($file),'"path"\s+"([^"]+)"')) { $libraries += $match.Groups[1].Value.Replace('\\','\') } }
    }
    $games=@()
    foreach ($library in @($libraries | Select-Object -Unique)) {
        $file=Join-Path $library 'steamapps\appmanifest_2763670.acf'
        if (Test-Path -LiteralPath $file) {
            $text=[IO.File]::ReadAllText($file); $match=[regex]::Match($text,'"installdir"\s+"([^"]+)"')
            if ($match.Success) { $games += Join-Path (Join-Path $library 'steamapps\common') $match.Groups[1].Value }
        }
    }
    if ($games.Count -ne 1) { throw 'Cannot identify one Steam installation. Pass -GameRoot with the ArcticEggs directory.' }
    return $games[0]
}
if (!$GameRoot) { $GameRoot=Discover }
$GameRoot=[IO.Path]::GetFullPath($GameRoot).TrimEnd('\','/')
Safe $GameRoot
$manifestPath=Join-Path $PSScriptRoot 'manifest.json'
Safe $PSScriptRoot
if ((Sha $manifestPath) -ne $expectedManifest) { throw 'Package manifest changed.' }
$manifest=Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath | ConvertFrom-Json
if ($manifest.schema -cne 'arctic-replace-en-package/v1' -or $manifest.project_id -cne '7998b3ea-3044-4e4e-b5f0-fa0690d02b8d' -or $manifest.build -cne '18492481' -or !$manifest.preview -or $manifest.human_release_approval) { throw 'Unsupported package identity.' }
$expected=@{'manifest.json'=$expectedManifest;'Patch.ps1'=(Sha $PSCommandPath)}
foreach ($property in $manifest.artifacts.PSObject.Properties) {
    if ($property.Name -cnotmatch '^[A-Za-z0-9_.-]+$' -or $property.Name.Contains('..') -or $property.Value -cnotmatch '^[a-f0-9]{64}$') { throw 'Unsafe package member.' }
    $expected[$property.Name]=$property.Value
}
foreach ($name in @('Install.cmd','Uninstall.cmd')) {
    $verb=if ($name -eq 'Install.cmd') {'Install'} else {'Uninstall'}
    $raw='@echo off'+"`r`n"+'powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Patch.ps1" -Action '+$verb+' %*'+"`r`n"+'if errorlevel 1 (echo Operation failed. & pause & exit /b 1)'+"`r`n"+'pause'+"`r`n"
    $hasher=[Security.Cryptography.SHA256]::Create()
    try { $expected[$name]=[BitConverter]::ToString($hasher.ComputeHash([Text.Encoding]::ASCII.GetBytes($raw))).Replace('-','').ToLowerInvariant() } finally { $hasher.Dispose() }
}
function Verify-Directory([string]$Directory,[bool]$Installed,[bool]$AllowMissing=$false) {
    Safe $Directory
    $allowed=@($expected.Keys); if ($Installed) {$allowed += 'install-state.json'}
    $items=@(Get-ChildItem -Force -LiteralPath $Directory)
    if (!$AllowMissing -and $items.Count -ne $allowed.Count) { throw 'Owned directory contains missing or unknown files.' }
    foreach ($item in $items) {
        if ($item.PSIsContainer -or $item.Name -notin $allowed) { throw 'Owned directory contains unknown content.' }
        Safe $item.FullName
        if ($item.Name -ne 'install-state.json' -and (Sha $item.FullName) -ne $expected[$item.Name]) { throw ('Changed file refused: '+$item.Name) }
    }
    if ($Installed -and (Test-Path -LiteralPath (Join-Path $Directory 'install-state.json'))) {
        $state=Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $Directory 'install-state.json') | ConvertFrom-Json
        if ($state.schema -cne 'arctic-replace-en-install/v1' -or $state.manifest_sha256 -cne $expectedManifest -or $state.sidecar -cne $sidecarName -or $state.original_files_replaced -ne 0 -or $state.override_sha256 -cne $overrideSha) { throw 'Invalid install ownership receipt.' }
    }
}
$owned=Join-Path $GameRoot $sidecarName
$override=Join-Path $GameRoot 'override.cfg'
$overridePending=Join-Path $GameRoot ('override.arctic-'+$expectedManifest.Substring(0,16)+'.pending')
$bootstrap=(Join-Path $owned 'bootstrap.gd').Replace('\','/')
$escaped=$bootstrap.Replace('"','\"')
$overrideRaw='[autoload]'+"`n"+'ArcticThai="*'+$escaped+'"'+"`n`n"+'[arctic_thai]'+"`n"+'manifest_sha256="'+$expectedManifest+'"'+"`n"
$overrideBytes=[Text.UTF8Encoding]::new($false).GetBytes($overrideRaw)
$hash=[Security.Cryptography.SHA256]::Create()
try {$overrideSha=[BitConverter]::ToString($hash.ComputeHash($overrideBytes)).Replace('-','').ToLowerInvariant()} finally {$hash.Dispose()}
Safe $override; Safe $overridePending
Verify-Directory $PSScriptRoot (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'install-state.json'))
foreach ($process in @(Get-Process -Name game -ErrorAction SilentlyContinue)) {
    if (!$process.Path -or [IO.Path]::GetDirectoryName($process.Path) -eq $GameRoot) { throw 'Close Arctic Eggs before changing or verifying this installation.' }
}
$library=[IO.Path]::GetDirectoryName([IO.Path]::GetDirectoryName($GameRoot))
$appmanifest=if ($library) {Join-Path $library 'appmanifest_2763670.acf'} else {$null}
if ($appmanifest) {Safe $appmanifest}
# Uninstall must still clean up after Steam removed or moved the game's app manifest.
$haveManifest=$appmanifest -and (Test-Path -LiteralPath $appmanifest)
if (!$haveManifest -and $Action -ne 'Uninstall') { throw 'Steam app manifest not found. Pass -GameRoot with the Steam ArcticEggs directory.' }
$steamText=if ($haveManifest) {[IO.File]::ReadAllText($appmanifest)} else {'"appid" "2763670"'}
if ($steamText -notmatch '"appid"\s+"2763670"') { throw 'Steam app mismatch.' }
if ($Action -ne 'Uninstall') {
    # bootstrap.gd quits a game whose EXE/PCK differ, so file identity, not the Steam label, gates Install.
    if ((Sha (Join-Path $GameRoot 'game.exe')) -ne $manifest.exe_sha256 -or (Sha (Join-Path $GameRoot 'game.pck')) -ne $manifest.pck_sha256) {
        if ($Action -eq 'Status') { throw 'Game files changed since tested Steam build 18492481. If the Thai mod is installed, it now stops the game from starting; run Uninstall.' }
        throw 'Game files changed since tested Steam build 18492481; this release would stop the game from starting. Wait for an updated Thai release. Uninstall still works.'
    }
    if ($steamText -notmatch '"buildid"\s+"18492481"') { Write-Warning 'Steam reports a build other than 18492481, but game.exe and game.pck match the tested files. Continuing.' }
}
$owned=Join-Path $GameRoot $sidecarName
$stage=Join-Path $GameRoot ($sidecarName+'.stage-'+$expectedManifest.Substring(0,16))
$tomb=Join-Path $GameRoot ($sidecarName+'.remove-'+$expectedManifest.Substring(0,16))
Safe $owned; Safe $stage; Safe $tomb
function Check-Override([bool]$Required) {
    if (Test-Path -LiteralPath $override) {
        Safe $override
        if ((Sha $override) -cne $overrideSha) { throw 'Existing or changed override.cfg refused. No merge or overwrite is performed.' }
    } elseif ($Required) { throw 'Owned override.cfg is missing.' }
}
function Check-Receipt([string]$Directory) {
    $receipt=Join-Path $Directory 'install-state.json'
    Safe $receipt
    if (!(Test-Path -LiteralPath $receipt)) { throw 'Missing ownership receipt.' }
    $state=Get-Content -Raw -Encoding UTF8 -LiteralPath $receipt | ConvertFrom-Json
    if ($state.schema -cne 'arctic-replace-en-install/v1' -or $state.manifest_sha256 -cne $expectedManifest -or $state.sidecar -cne $sidecarName -or $state.override_sha256 -cne $overrideSha -or $state.original_files_replaced -ne 0) {throw 'Unknown ownership receipt.'}
}
function Remove-Verified([string]$Directory) {
    # The only deletion roots are the exact, checked game-child paths above.
    Safe $Directory
    if ($Directory -cne $stage -and $Directory -cne $tomb) {throw 'Unexpected removal directory.'}
    Check-Receipt $Directory
    Verify-Directory $Directory $true $true
    foreach ($item in @(Get-ChildItem -Force -LiteralPath $Directory | Sort-Object { $_.Name -eq 'install-state.json' })) {Remove-Item -LiteralPath $item.FullName -Force}
    [IO.Directory]::Delete($Directory)
}
if ($Action -eq 'Status') {
    if (!(Test-Path -LiteralPath $owned)) { throw 'Thai sidecar is not installed.' }
    Verify-Directory $owned $true
    Check-Override $true
    Write-Output 'Installed English-slot replacement verified. Launch with Steam or game.exe.'; exit 0
}
if ($Action -eq 'Install') {
    if (Test-Path -LiteralPath $tomb) { throw 'An interrupted uninstall is present. Run Uninstall first.' }
    if ((Test-Path -LiteralPath $override) -and !(Test-Path -LiteralPath $owned) -and !(Test-Path -LiteralPath $stage)) {throw 'Unowned override.cfg refused.'}
    Check-Override $false
    if (Test-Path -LiteralPath $owned) {
        Check-Receipt $owned
        Verify-Directory $owned $true
    } else {
        if (Test-Path -LiteralPath $stage) {
            Check-Receipt $stage
            $pending=Join-Path $stage '.pending'
            if (Test-Path -LiteralPath $pending) {
                Safe $pending
                if ((Get-Item -Force -LiteralPath $pending).PSIsContainer) {throw 'Invalid staging scratch.'}
                Remove-Item -LiteralPath $pending -Force
            }
            Verify-Directory $stage $true $true
        } else {
            [IO.Directory]::CreateDirectory($stage) | Out-Null
            $state=@{schema='arctic-replace-en-install/v1';manifest_sha256=$expectedManifest;sidecar=$sidecarName;override_sha256=$overrideSha;original_files_replaced=0;backup_required=$false}
            [IO.File]::WriteAllText((Join-Path $stage 'install-state.json'),($state | ConvertTo-Json),[Text.UTF8Encoding]::new($false))
        }
        foreach ($name in $expected.Keys) {
            $destination=Join-Path $stage $name
            if (Test-Path -LiteralPath $destination) {continue}
            $pending=Join-Path $stage '.pending'
            [IO.File]::Copy((Join-Path $PSScriptRoot $name),$pending,$false)
            if ((Sha $pending) -cne $expected[$name]) {throw 'Staged copy hash mismatch.'}
            [IO.File]::Move($pending,$destination)
        }
        Verify-Directory $stage $true
        [IO.Directory]::Move($stage,$owned)
    }
    if (Test-Path -LiteralPath $overridePending) {
        if ((Sha $overridePending) -cne $overrideSha) {throw 'Unknown pending override refused.'}
        Remove-Item -LiteralPath $overridePending -Force
    }
    if (!(Test-Path -LiteralPath $override)) {
        [IO.File]::WriteAllBytes($overridePending,$overrideBytes)
        [IO.File]::Move($overridePending,$override)
    }
    Check-Override $true
    Write-Output 'Installed. Launch Arctic Eggs normally and select English for Thai.'; exit 0
}
if ((Test-Path -LiteralPath $owned) -and (Test-Path -LiteralPath $tomb)) { throw 'Ambiguous uninstall state. Both owned and retired directories exist.' }
$owner=if (Test-Path -LiteralPath $owned) {$owned} elseif (Test-Path -LiteralPath $tomb) {$tomb} elseif (Test-Path -LiteralPath $stage) {$stage} else {$null}
if ($owner) {Check-Receipt $owner; Verify-Directory $owner $true $true}
if ((Test-Path -LiteralPath $override) -or (Test-Path -LiteralPath $overridePending)) {
    if (!$owner) {throw 'Override has no ownership receipt. Refused.'}
    Check-Override $false
    if (Test-Path -LiteralPath $overridePending) {
        if ((Sha $overridePending) -cne $overrideSha) {throw 'Changed pending override refused.'}
        Remove-Item -LiteralPath $overridePending -Force
    }
    if (Test-Path -LiteralPath $override) {Remove-Item -LiteralPath $override -Force}
}
if (Test-Path -LiteralPath $owned) {[IO.Directory]::Move($owned,$tomb)}
if (Test-Path -LiteralPath $tomb) {Remove-Verified $tomb}
if (Test-Path -LiteralPath $stage) {Remove-Verified $stage}
Write-Output 'Uninstalled. Original game files and user saves/settings are unchanged.'
