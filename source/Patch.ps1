[CmdletBinding()]
param([ValidateSet('Install','Uninstall','Status')][string]$Action='Install', [string]$GameRoot)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$Game=@{Title='Arctic Eggs'; Process='game'; AppId='2763670'; Build='18492481'; AnyLocation=$false}
# Shared installer steps. The game part sets $Game (Title, Process, AppId, Build, AnyLocation), $GameRoot and $maximumAssetBytes.
function Assert-Hash($Value) {
    if ($Value -isnot [string] -or $Value -cnotmatch '^[0-9a-f]{64}$') { throw 'Invalid SHA-256 format.' }
}
function Assert-PositiveInteger($Value, [long]$Maximum) {
    if (($Value -isnot [int] -and $Value -isnot [long]) -or $Value -le 0 -or $Value -gt $Maximum) {
        throw 'Manifest resource bound/type violation.'
    }
}
function Assert-TrueBoolean($Value) {
    if ($Value -isnot [bool] -or $Value -cne $true) { throw 'Runtime attestation requires exact true booleans.' }
}
function Assert-Keys($Object, [string[]]$Keys) {
    if ($null -eq $Object -or $Object -isnot [pscustomobject]) { throw 'Invalid object type.' }
    $actual = @($Object.PSObject.Properties.Name)
    if ($actual.Count -ne $Keys.Count) { throw 'Unsupported object properties.' }
    foreach ($key in $Keys) { if ($actual -cnotcontains $key) { throw "Missing exact property: $key" } }
}
function Read-Json([string]$Path) {
    if ((Get-Item -LiteralPath $Path).Length -gt 1048576) { throw 'JSON resource bound exceeded.' }
    $raw = [IO.File]::ReadAllText($Path)
    # ConvertFrom-Json silently keeps the last of duplicate property names, so they are refused first.
    $sets = New-Object 'Collections.Generic.Stack[object]'
    foreach ($token in [regex]::Matches($raw, '"(?:[^"\\]|\\.)*"|[{}]')) {
        if ($token.Value -eq '{') { $sets.Push((New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase))) }
        elseif ($token.Value -eq '}') { if ($sets.Count -eq 0) { throw 'Invalid JSON nesting.' }; $null = $sets.Pop() }
        elseif ($raw.Substring($token.Index + $token.Length).TrimStart().StartsWith(':')) {
            $name = $token.Value | ConvertFrom-Json
            if ($sets.Count -eq 0 -or !$sets.Peek().Add([string]$name)) { throw 'Duplicate JSON property.' }
        }
    }
    return ($raw | ConvertFrom-Json)
}
function Assert-Identity($Identity) {
    Assert-Keys $Identity @('sha256','size')
    Assert-Hash $Identity.sha256
    Assert-PositiveInteger $Identity.size $maximumAssetBytes
}
function Assert-Previous($Previous, [string]$PinnedJson) {
    # Assign before @(): PowerShell 5.1 emits a parsed JSON array as one object, so @(ConvertFrom-Json '[]') has one element.
    $pinned = ConvertFrom-Json $PinnedJson
    $pinned = @($pinned)
    $Previous = @($Previous)
    if ($Previous.Count -ne $pinned.Count) { throw 'Unsupported previous output identity.' }
    for ($i = 0; $i -lt $pinned.Count; $i++) {
        if ($Previous[$i].sha256 -cne $pinned[$i].sha256 -or $Previous[$i].size -ne $pinned[$i].size) { throw 'Unsupported previous output identity.' }
    }
}
function Assert-SafePath([string]$Path) {
    $itemPath = [IO.Path]::GetFullPath($Path)
    while ($itemPath) {
        $pathItem = Get-Item -Force -LiteralPath $itemPath -ErrorAction SilentlyContinue
        if ($pathItem -and ($pathItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "Reparse point refused: $itemPath"
        }
        $parent = [IO.Path]::GetDirectoryName($itemPath)
        if ($parent -eq $itemPath) { break }
        $itemPath = $parent
    }
}
function Assert-Contained([string]$Root, [string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if (!$full.StartsWith($Root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Path escape refused.' }
    Assert-SafePath $full
    return $full
}
function Get-Sha([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($hasher.ComputeHash($stream)).Replace('-','').ToLowerInvariant() }
    finally { $hasher.Dispose(); $stream.Dispose() }
}
function Get-BytesSha([byte[]]$Bytes) {
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($hasher.ComputeHash($Bytes)).Replace('-','').ToLowerInvariant() }
    finally { $hasher.Dispose() }
}
function Assert-File([string]$Path, $Identity) {
    Assert-SafePath $Path
    if (!(Test-Path -LiteralPath $Path -PathType Leaf) -or (Get-Item -LiteralPath $Path).Length -ne $Identity.size -or (Get-Sha $Path) -cne $Identity.sha256) {
        throw "File missing or corrupt: $Path"
    }
}
function Assert-GameStopped {
    foreach ($gameProcess in @(Get-Process -Name $Game.Process -ErrorAction SilentlyContinue)) {
        # Elevated processes hide their path, so an unknown path counts as this game.
        if ($Game.AnyLocation -or !$gameProcess.Path -or [IO.Path]::GetDirectoryName($gameProcess.Path) -eq $GameRoot) {
            throw "Close $($Game.Title) before changing files."
        }
    }
}
function Find-SteamGame {
    $roots = @()
    foreach ($key in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam')) {
        $entry = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
        if ($entry) { foreach ($property in @('SteamPath','InstallPath')) { if ($entry.PSObject.Properties.Name -contains $property) { $roots += $entry.$property } } }
    }
    $libraries = @($roots)
    foreach ($root in $roots) {
        $file = Join-Path $root 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $file) { foreach ($match in [regex]::Matches([IO.File]::ReadAllText($file), '"path"\s+"([^"]+)"')) { $libraries += $match.Groups[1].Value.Replace('\\','\') } }
    }
    $games = @()
    foreach ($library in @($libraries | Select-Object -Unique)) {
        $file = Join-Path $library ('steamapps\appmanifest_' + $Game.AppId + '.acf')
        if (Test-Path -LiteralPath $file) {
            $match = [regex]::Match([IO.File]::ReadAllText($file), '"installdir"\s+"([^"]+)"')
            if ($match.Success) { $games += Join-Path (Join-Path $library 'steamapps\common') $match.Groups[1].Value }
        }
    }
    if ($games.Count -eq 1) { return $games[0] }
    # Install.cmd and Uninstall.cmd set THAI_MOD_PICK, so a player picks the folder instead of typing a PowerShell command;
    # a direct or scripted run keeps the error and never waits on a dialog.
    if ($env:THAI_MOD_PICK -eq '1') {
        $picked = Select-GameFolder
        if ($picked) { return $picked }
    }
    throw "Cannot identify one Steam installation. Pass -GameRoot with the $($Game.Title) folder (Steam > Manage > Browse local files)."
}
function Select-GameFolder {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select the $($Game.Title) game folder. In Steam: right-click the game > Manage > Browse local files."
    $dialog.ShowNewFolderButton = $false
    try { if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $dialog.SelectedPath } } finally { $dialog.Dispose() }
    return $null
}
function Read-SteamBuild {
    # User decision 2026-10-26: the Steam build label only warns. File hashes decide what may be patched.
    $library = [IO.Path]::GetDirectoryName([IO.Path]::GetDirectoryName($GameRoot))
    $label = $null
    if ($library) {
        $acf = Join-Path $library ('appmanifest_' + $Game.AppId + '.acf')
        Assert-SafePath $acf
        if (Test-Path -LiteralPath $acf -PathType Leaf) {
            if ((Get-Item -LiteralPath $acf).Length -gt 1048576) { throw 'Steam app manifest bound exceeded.' }
            $text = [IO.File]::ReadAllText($acf)
            $apps = [regex]::Matches($text, '"appid"\s+"([^"\r\n]+)"')
            if ($apps.Count -ne 1 -or $apps[0].Groups[1].Value -cne $Game.AppId) { throw 'Steam app mismatch.' }
            $builds = [regex]::Matches($text, '"buildid"\s+"([^"\r\n]+)"')
            if ($builds.Count -eq 1) { $label = $builds[0].Groups[1].Value }
        }
    }
    if ($label -cne $Game.Build) {
        $seen = if ($label) { "Steam reports build $label" } else { 'Steam build is unknown' }
        Write-Warning "$seen, not the tested build $($Game.Build). Continuing with file hash checks."
    }
    return [pscustomobject]@{Label = $label; Changed = ($null -ne $label -and $label -cne $Game.Build)}
}
$expectedManifest='5bef7c36806f034f333b7cd1fcd385eda9efac8f019ec75e8f262a48238e0374'
$sidecarName='ArcticEggs-Thai-replace-en'
if (!$GameRoot) { $GameRoot=Find-SteamGame }
$GameRoot=[IO.Path]::GetFullPath($GameRoot).TrimEnd('\','/')
Assert-SafePath $GameRoot
$manifestPath=Join-Path $PSScriptRoot 'manifest.json'
Assert-SafePath $PSScriptRoot
if ((Get-Sha $manifestPath) -ne $expectedManifest) { throw 'Package manifest changed.' }
$manifest=Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath | ConvertFrom-Json
if ($manifest.schema -cne 'arctic-replace-en-package/v1' -or $manifest.project_id -cne '7998b3ea-3044-4e4e-b5f0-fa0690d02b8d' -or $manifest.build -cne '18492481' -or !$manifest.preview -or $manifest.human_release_approval) { throw 'Unsupported package identity.' }
$expected=@{'manifest.json'=$expectedManifest;'Patch.ps1'=(Get-Sha $PSCommandPath)}
foreach ($property in $manifest.artifacts.PSObject.Properties) {
    if ($property.Name -cnotmatch '^[A-Za-z0-9_.-]+$' -or $property.Name.Contains('..') -or $property.Value -cnotmatch '^[a-f0-9]{64}$') { throw 'Unsafe package member.' }
    $expected[$property.Name]=$property.Value
}
foreach ($name in @('Install.cmd','Uninstall.cmd')) {
    $verb=if ($name -eq 'Install.cmd') {'Install'} else {'Uninstall'}
    $raw='@echo off'+"`r`n"+'set "THAI_MOD_PICK=1"'+"`r`n"+'powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Patch.ps1" -Action '+$verb+' %*'+"`r`n"+'if errorlevel 1 (echo Operation failed. & pause & exit /b 1)'+"`r`n"+'pause'+"`r`n"
    $expected[$name]=Get-BytesSha ([Text.Encoding]::ASCII.GetBytes($raw))
}
function Verify-Directory([string]$Directory,[bool]$Installed,[bool]$AllowMissing=$false) {
    Assert-SafePath $Directory
    $allowed=@($expected.Keys); if ($Installed) {$allowed += 'install-state.json'}
    $items=@(Get-ChildItem -Force -LiteralPath $Directory)
    if (!$AllowMissing -and $items.Count -ne $allowed.Count) { throw 'Owned directory contains missing or unknown files.' }
    foreach ($item in $items) {
        if ($item.PSIsContainer -or $item.Name -notin $allowed) { throw 'Owned directory contains unknown content.' }
        Assert-SafePath $item.FullName
        if ($item.Name -ne 'install-state.json' -and (Get-Sha $item.FullName) -ne $expected[$item.Name]) { throw ('Changed file refused: '+$item.Name) }
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
$overrideSha=Get-BytesSha $overrideBytes
Assert-SafePath $override; Assert-SafePath $overridePending
Verify-Directory $PSScriptRoot (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'install-state.json'))
Assert-GameStopped
$null=Read-SteamBuild
# bootstrap.gd quits a game whose EXE/PCK differ, so file identity, not the Steam label, gates Install. Uninstall must still clean up.
if ($Action -ne 'Uninstall' -and ((Get-Sha (Join-Path $GameRoot 'game.exe')) -ne $manifest.exe_sha256 -or (Get-Sha (Join-Path $GameRoot 'game.pck')) -ne $manifest.pck_sha256)) {
    if ($Action -eq 'Status') { throw 'Game files changed since tested Steam build 18492481. If the Thai mod is installed, it now stops the game from starting; run Uninstall.' }
    throw 'Game files changed since tested Steam build 18492481; this release would stop the game from starting. Wait for an updated Thai release. Uninstall still works.'
}
$owned=Join-Path $GameRoot $sidecarName
$stage=Join-Path $GameRoot ($sidecarName+'.stage-'+$expectedManifest.Substring(0,16))
$tomb=Join-Path $GameRoot ($sidecarName+'.remove-'+$expectedManifest.Substring(0,16))
Assert-SafePath $owned; Assert-SafePath $stage; Assert-SafePath $tomb
function Check-Override([bool]$Required) {
    if (Test-Path -LiteralPath $override) {
        Assert-SafePath $override
        if ((Get-Sha $override) -cne $overrideSha) { throw 'Existing or changed override.cfg refused. No merge or overwrite is performed.' }
    } elseif ($Required) { throw 'Owned override.cfg is missing.' }
}
function Check-Receipt([string]$Directory) {
    $receipt=Join-Path $Directory 'install-state.json'
    Assert-SafePath $receipt
    if (!(Test-Path -LiteralPath $receipt)) { throw 'Missing ownership receipt.' }
    $state=Get-Content -Raw -Encoding UTF8 -LiteralPath $receipt | ConvertFrom-Json
    if ($state.schema -cne 'arctic-replace-en-install/v1' -or $state.manifest_sha256 -cne $expectedManifest -or $state.sidecar -cne $sidecarName -or $state.override_sha256 -cne $overrideSha -or $state.original_files_replaced -ne 0) {throw 'Unknown ownership receipt.'}
}
function Remove-Verified([string]$Directory) {
    # The only deletion roots are the exact, checked game-child paths above.
    Assert-SafePath $Directory
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
                Assert-SafePath $pending
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
            if ((Get-Sha $pending) -cne $expected[$name]) {throw 'Staged copy hash mismatch.'}
            [IO.File]::Move($pending,$destination)
        }
        Verify-Directory $stage $true
        [IO.Directory]::Move($stage,$owned)
    }
    if (Test-Path -LiteralPath $overridePending) {
        if ((Get-Sha $overridePending) -cne $overrideSha) {throw 'Unknown pending override refused.'}
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
        if ((Get-Sha $overridePending) -cne $overrideSha) {throw 'Changed pending override refused.'}
        Remove-Item -LiteralPath $overridePending -Force
    }
    if (Test-Path -LiteralPath $override) {Remove-Item -LiteralPath $override -Force}
}
if (Test-Path -LiteralPath $owned) {[IO.Directory]::Move($owned,$tomb)}
if (Test-Path -LiteralPath $tomb) {Remove-Verified $tomb}
if (Test-Path -LiteralPath $stage) {Remove-Verified $stage}
Write-Output 'Uninstalled. Original game files and user saves/settings are unchanged.'
