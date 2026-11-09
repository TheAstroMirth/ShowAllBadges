# ShowAllBadges uninstaller for Windows 10/11.
# Removes only src\userplugins\showAllBadges from a Vencord or Equicord source folder.
# It never removes Vencord, Equicord, Discord or any other plugin.
#
# Options:
#   -Source "PATH"  Use this Vencord/Equicord source folder (skips the search)
#   -Yes            Do not ask questions, use the default answers
#   -NoBuild        Remove the plugin but do not run 'pnpm build'

param(
    [string]$Source = '',
    [switch]$Yes,
    [switch]$NoBuild
)

$ErrorActionPreference = 'Stop'
$ScriptTitle = 'ShowAllBadges uninstall'
. (Join-Path $PSScriptRoot 'common.ps1')

Write-Host 'ShowAllBadges uninstaller' -ForegroundColor White

Assert-Windows

Write-Step '1/3  Source folder'
Find-InstalledClients
$Repo = Select-Checkout 'uninstall'
$Client = Get-CheckoutClient $Repo
if (-not $Client) { Stop-Script "Not a Vencord or Equicord source folder: $Repo" }
if ($Client -eq 'equicord') { $Label = 'Equicord' } else { $Label = 'Vencord' }
Write-Ok "Using $Label source folder: $Repo"

$UserPlugins = Join-Path (Join-Path $Repo 'src') 'userplugins'
$Dest = Join-Path $UserPlugins $PluginFolder

Write-Step '2/3  Removing the plugin'
$Removed = $false
if (-not (Test-Path -LiteralPath $Dest)) {
    Write-Ok 'ShowAllBadges is not installed in this source folder. Nothing to remove.'
} else {
    # Safety: only ever touch <repo>\src\userplugins\showAllBadges.
    if ((Split-Path -Path $Dest -Leaf) -ne $PluginFolder -or (Split-Path -Path (Split-Path -Path $Dest -Parent) -Leaf) -ne 'userplugins') {
        Stop-Script "Refusing to remove an unexpected path: $Dest"
    }
    $item = Get-Item -LiteralPath $Dest -Force
    $isLink = [bool]($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
    $index = Join-Path $Dest 'index.ts'
    if (-not $isLink -and (Test-Path -LiteralPath $index -PathType Leaf)) {
        if (-not (Select-String -LiteralPath $index -Pattern $PluginName -SimpleMatch -Quiet)) {
            Write-Warn "$index does not look like the ShowAllBadges plugin."
            if (-not (Ask-YesNo 'Remove this folder anyway?' $false)) { Stop-Script 'Cancelled. Nothing was removed.' }
        }
    }
    Write-Info "This will remove only: $Dest"
    if (-not (Ask-YesNo 'Continue?' $true)) { Stop-Script 'Cancelled. Nothing was removed.' }
    try {
        if ($isLink) {
            # Remove just the link, never what it points to.
            [System.IO.Directory]::Delete($Dest, $false)
        } else {
            Remove-Item -LiteralPath $Dest -Recurse -Force
        }
    } catch {
        Stop-Script "Could not remove $Dest ($($_.Exception.Message))"
    }
    if (Test-Path -LiteralPath $Dest) { Stop-Script "Could not remove $Dest" }
    $Removed = $true
    Write-Ok "Removed $Dest"
    Write-Info 'Other plugins in src\userplugins were not touched.'
}

Write-Step "3/3  Rebuilding $Label"
$Rebuilt = $false
if (-not $Removed) {
    Write-Info 'Nothing changed, so no rebuild is needed.'
} elseif ($NoBuild) {
    Write-Warn "Skipped (-NoBuild). Run 'pnpm build' in the source folder to finish."
} elseif (-not (Test-Cmd 'pnpm') -or -not (Test-Cmd 'node') -or -not (Test-Path -LiteralPath (Join-Path $Repo 'node_modules'))) {
    Write-Warn 'Cannot rebuild automatically (Node.js, pnpm or node_modules is missing).'
    Write-Info "The plugin stays active in Discord until you run 'pnpm build' in: $Repo"
} elseif (Ask-YesNo "Rebuild $Label now so the plugin disappears from Discord?" $true) {
    if (Invoke-Build $Repo) {
        $Rebuilt = $true
    } else {
        Write-Info 'The plugin folder was removed, but the rebuild failed.'
        Write-Info "Fix the error above, then run 'pnpm build' in: $Repo"
        Stop-Script 'Rebuild failed.'
    }
} else {
    Write-Info "The plugin stays active in Discord until you run 'pnpm build' in: $Repo"
}

$BackupRoot = Get-BackupRoot
if ((Test-Path -LiteralPath $BackupRoot) -and (Get-ChildItem -LiteralPath $BackupRoot -ErrorAction SilentlyContinue)) {
    Write-Host ''
    Write-Info "Backups made by the installer are kept in: $BackupRoot"
    Write-Info 'Each one holds the plugin folder that was replaced. To restore one, copy its'
    Write-Info "'$PluginFolder' folder back into  <source folder>\src\userplugins\  and run 'pnpm build'."
    Write-Info 'You can delete the backups folder if you do not need them.'
}

Write-Host ''
if ($Removed -and $Rebuilt) {
    Write-Host "Done. ShowAllBadges was removed and $Label was rebuilt." -ForegroundColor Green
    Write-Host 'Close Discord completely (also from the system tray) and open it again.'
} elseif ($Removed) {
    Write-Host "ShowAllBadges was removed, but $Label has not been rebuilt yet." -ForegroundColor Yellow
} else {
    Write-Host 'Nothing to do.' -ForegroundColor Green
}
exit 0
