# ShowAllBadges installer for Windows 10/11.
# Adds the plugin to an existing Vencord or Equicord source folder and builds it.
# It never downloads, clones or installs Vencord or Equicord, and needs no administrator rights.
#
# Options:
#   -Source "PATH"  Use this Vencord/Equicord source folder (skips the search)
#   -Yes            Do not ask questions, use the default answers
#   -NoBuild        Copy the plugin but do not run 'pnpm build'

param(
    [string]$Source = '',
    [switch]$Yes,
    [switch]$NoBuild
)

$ErrorActionPreference = 'Stop'
$ScriptTitle = 'ShowAllBadges install'
. (Join-Path $PSScriptRoot 'common.ps1')

$PluginSrc = Join-Path (Join-Path (Join-Path (Join-Path $PSScriptRoot '..') '..') 'plugin') 'index.ts'

Write-Host 'ShowAllBadges installer' -ForegroundColor White
Write-Host 'Unofficial third-party plugin. Client mods are against the Discord ToS. Use at your own risk.' -ForegroundColor DarkGray

Assert-Windows
if (-not (Test-Path -LiteralPath $PluginSrc -PathType Leaf)) {
    Stop-Script 'Cannot find plugin\index.ts next to the installers. Keep the project folder together.'
}

Write-Step '1/6  Looking for Vencord / Equicord'
Find-InstalledClients
if ($script:InstallNotes.Count -gt 0) {
    foreach ($n in $script:InstallNotes) { Write-Ok $n }
} else {
    Write-Warn 'No installed Vencord or Equicord was detected on this PC.'
    Write-Info 'Looked for a patched Discord in %LOCALAPPDATA% and for their data folders in %APPDATA%.'
    Write-Info 'You can still add the plugin to a source folder if you have one.'
}

Write-Step '2/6  Source folder'
$Repo = Select-Checkout 'install'
$Client = Get-CheckoutClient $Repo
if (-not $Client) { Stop-Script "Not a Vencord or Equicord source folder: $Repo" }
if ($Client -eq 'equicord') { $Label = 'Equicord'; $Docs = $EquicordDocs } else { $Label = 'Vencord'; $Docs = $VencordDocs }
Write-Ok "Using $Label source folder: $Repo"
if ($Client -eq 'equicord' -and -not $script:HasEquicord -and $script:HasVencord) {
    Write-Warn 'This is an Equicord source folder, but only Vencord looks installed.'
} elseif ($Client -eq 'vencord' -and -not $script:HasVencord -and $script:HasEquicord) {
    Write-Warn 'This is a Vencord source folder, but only Equicord looks installed.'
}

# Informational only: some Equicord versions carry their own copy of this patch
# in EquiTweaks and move a plugin named "ShowAllBadges" over to that setting.
$EquiNote = $false
if ($Client -eq 'equicord') {
    $tweaks = Join-Path (Join-Path (Join-Path (Join-Path $Repo 'src') 'equicordplugins') 'equiTweaks') 'index.tsx'
    if (Test-Path -LiteralPath $tweaks -PathType Leaf) {
        $EquiNote = [bool](Select-String -LiteralPath $tweaks -Pattern 'migratePluginToSettings\([^)]*"ShowAllBadges"' -Quiet)
    }
}

Write-Step '3/6  Prerequisites'
Assert-RepoValid $Repo $Label $Docs
Assert-BuildTools $Repo $Label

Write-Step '4/6  Copying the plugin'
$UserPlugins = Join-Path (Join-Path $Repo 'src') 'userplugins'
$Dest = Join-Path $UserPlugins $PluginFolder
$DestFile = Join-Path $Dest 'index.ts'
$same = $false
if (Test-Path -LiteralPath $DestFile -PathType Leaf) {
    $same = ((Get-FileHash -LiteralPath $DestFile -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $PluginSrc -Algorithm SHA256).Hash)
}
if ($same) {
    Write-Ok 'The same plugin file is already in place, no backup needed'
} elseif (Test-Path -LiteralPath $Dest) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $Backup = Join-Path (Get-BackupRoot) "$Client-$stamp"
    try {
        New-Item -ItemType Directory -Force -Path $Backup | Out-Null
        Copy-Item -LiteralPath $Dest -Destination $Backup -Recurse -Force
        Set-Content -LiteralPath (Join-Path $Backup 'original-location.txt') -Value $Dest -Encoding ASCII
    } catch {
        Stop-Script "Could not back up the existing plugin ($($_.Exception.Message)). Nothing was replaced."
    }
    Write-Ok "Existing plugin backed up to: $(Join-Path $Backup $PluginFolder)"
}
try {
    New-Item -ItemType Directory -Force -Path $Dest | Out-Null
    Copy-Item -LiteralPath $PluginSrc -Destination $DestFile -Force
} catch {
    Stop-Script "Could not copy the plugin to $Dest ($($_.Exception.Message))"
}
Write-Ok "Plugin copied to: $DestFile"

Write-Step "5/6  Building $Label"
$Built = $false
if ($NoBuild) {
    Write-Warn "Skipped (-NoBuild). Run 'pnpm build' in the source folder yourself."
} elseif (Confirm-Dependencies $Repo) {
    if (Invoke-Build $Repo) {
        $Built = $true
    } else {
        Write-Info "The plugin file was copied, but $Label was NOT rebuilt."
        Write-Info "Fix the error above, then run 'pnpm build' in: $Repo"
        Write-Info 'To remove the plugin again, run uninstall.bat.'
        Stop-Script 'Build failed.'
    }
} else {
    Write-Info "The plugin file was copied, but $Label was NOT built."
    Stop-Script "Dependencies are missing. Run 'pnpm install --frozen-lockfile' in the source folder, then run this again."
}

Write-Step '6/6  Applying the build'
if ($Built) {
    if (Test-InjectedFrom $Repo) {
        Write-Ok "Discord already loads $Label from this source folder. No inject needed."
    } else {
        Write-Info "Discord is not loading $Label from this source folder yet."
        Write-Info "$Label's own tool for that is:  pnpm inject"
        Write-Info "It downloads the official $Label installer and asks which Discord to patch."
        Write-Info 'Close Discord completely (also from the system tray) before running it.'
        if (-not $Yes -and (Ask-YesNo "Run 'pnpm inject' now?" $false)) {
            Push-Location -LiteralPath $Repo
            try {
                & pnpm inject | Out-Host
                $rc = $LASTEXITCODE
            } finally { Pop-Location }
            if ($rc -eq 0) { Write-Ok 'pnpm inject finished' } else { Write-Warn "pnpm inject exited with code $rc. You can run it again later." }
        } else {
            Write-Info "To do it later, run 'pnpm inject' in: $Repo"
        }
        Write-Info 'Using Vesktop or Equibop instead? Point it at this build in its settings'
        Write-Info '(Developer Options > Vencord/Equicord Location) rather than using pnpm inject.'
    }
}

Write-Host ''
if ($Built) {
    Write-Host "Done. ShowAllBadges was added and $Label was built successfully." -ForegroundColor Green
    Write-Host 'Next:'
    if (Test-DiscordRunning) {
        Write-Host '  1. Close Discord completely (also from the system tray) and open it again.'
    } else {
        Write-Host '  1. Open Discord.'
    }
    Write-Host '  2. Go to Settings > Plugins, search for ShowAllBadges and turn it on.'
    Write-Host '  3. Restart Discord when it asks.'
    if ($EquiNote) {
        Write-Host ''
        Write-Host "Note: this Equicord source also has a 'Show All Badges' option under"
        Write-Host 'Settings > Plugins > EquiTweaks. If ShowAllBadges turns itself off after a'
        Write-Host 'restart, Equicord has moved it to that option, which does the same thing.'
    }
} else {
    Write-Host "ShowAllBadges was copied, but $Label has not been built yet." -ForegroundColor Yellow
    Write-Host "Run 'pnpm build' in this folder when you are ready: $Repo"
}
exit 0
