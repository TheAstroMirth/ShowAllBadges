# Shared helpers for the ShowAllBadges Windows installer and uninstaller.
# Dot-sourced by install.ps1 and uninstall.ps1. Works on Windows PowerShell 5.1 and PowerShell 7.

$PluginName   = 'ShowAllBadges'
$PluginFolder = 'showAllBadges'

$VencordDocs       = 'https://docs.vencord.dev/installing/'
$VencordPluginDocs = 'https://docs.vencord.dev/installing/custom-plugins/'
$EquicordDocs      = 'https://github.com/Equicord/Equicord#installing-equicord-devbuild'

$script:HasVencord       = $false
$script:HasEquicord      = $false
$script:InstallNotes     = @()
$script:InjectedPatchers = @()

function Write-Step($m) { Write-Host ''; Write-Host "== $m ==" -ForegroundColor White }
function Write-Info($m) { Write-Host "   $m" }
function Write-Ok($m)   { Write-Host ' + ' -ForegroundColor Green -NoNewline; Write-Host $m }
function Write-Warn($m) { Write-Host ' ! ' -ForegroundColor Yellow -NoNewline; Write-Host $m }
function Write-Fail($m) { Write-Host ' x ' -ForegroundColor Red -NoNewline; Write-Host $m }

function Stop-Script($m) {
    Write-Fail $m
    Write-Host ''
    Write-Host "$ScriptTitle did not finish. Nothing else was changed." -ForegroundColor Red
    exit 1
}

function Test-Cmd($name) {
    return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

# Ask-YesNo 'Question' $true/$false(default)
function Ask-YesNo($prompt, $default) {
    if ($Yes) { return $default }
    if ($default) { $hint = '[Y/n]' } else { $hint = '[y/N]' }
    $reply = Read-Host "   $prompt $hint"
    if ($reply -match '^\s*(y|yes)\s*$') { return $true }
    if ($reply -match '^\s*(n|no)\s*$')  { return $false }
    return $default
}

function Assert-Windows {
    if ($env:OS -ne 'Windows_NT' -and -not $env:SAB_ALLOW_NON_WINDOWS) {
        Stop-Script 'This script is for Windows 10/11. On macOS use installers/macos/install.command.'
    }
}

function Get-BackupRoot {
    $base = $env:LOCALAPPDATA
    if (-not $base) { $base = $HOME }
    return (Join-Path (Join-Path $base 'ShowAllBadges') 'backups')
}

# ---------------------------------------------------------------- checkouts

# Returns 'vencord' or 'equicord' when the folder is a source checkout, otherwise $null.
function Get-CheckoutClient($dir) {
    if (-not $dir) { return $null }
    $pkg = Join-Path $dir 'package.json'
    if (-not (Test-Path -LiteralPath $pkg -PathType Leaf)) { return $null }
    if (-not (Test-Path -LiteralPath (Join-Path $dir 'src') -PathType Container)) { return $null }
    if (-not (Test-Path -LiteralPath (Join-Path (Join-Path (Join-Path $dir 'scripts') 'build') 'build.mjs') -PathType Leaf)) { return $null }
    try {
        $name = (Get-Content -LiteralPath $pkg -Raw | ConvertFrom-Json).name
    } catch {
        return $null
    }
    if ($name -eq 'vencord' -or $name -eq 'equicord') { return [string]$name }
    return $null
}

# Accepts the repo root or a folder inside it (src, src\userplugins, dist...) and returns the repo root.
function Find-CheckoutRoot($dir) {
    if (-not $dir) { return $null }
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { return $null }
    $cur = (Resolve-Path -LiteralPath $dir).ProviderPath
    for ($i = 0; $i -lt 5 -and $cur; $i++) {
        if (Get-CheckoutClient $cur) { return $cur.TrimEnd('\', '/') }
        $parent = Split-Path -Path $cur -Parent
        if (-not $parent -or $parent -eq $cur) { break }
        $cur = $parent
    }
    return $null
}

function Format-UserPath($p) {
    if (-not $p) { return '' }
    $p = $p.Trim().Trim('"').Trim("'").Trim()
    if ($p -eq '~') { $p = $HOME }
    elseif ($p.StartsWith('~\') -or $p.StartsWith('~/')) { $p = Join-Path $HOME $p.Substring(2) }
    return $p
}

# ------------------------------------------------------- installed clients

function Find-InstalledClients {
    $local = $env:LOCALAPPDATA
    $roaming = $env:APPDATA

    if ($local) {
        foreach ($branch in 'Discord', 'DiscordPTB', 'DiscordCanary', 'DiscordDevelopment') {
            $base = Join-Path $local $branch
            if (-not (Test-Path -LiteralPath $base -PathType Container)) { continue }
            $apps = Get-ChildItem -LiteralPath $base -Directory -Filter 'app-*' -ErrorAction SilentlyContinue
            foreach ($app in $apps) {
                $res  = Join-Path $app.FullName 'resources'
                $stub = Join-Path $res 'app.asar'
                # A patched Discord has the real app moved to _app.asar and a tiny
                # app.asar that just does require("<path to patcher.js>").
                if (-not (Test-Path -LiteralPath (Join-Path $res '_app.asar'))) { continue }
                if (-not (Test-Path -LiteralPath $stub -PathType Leaf)) { continue }
                if ((Get-Item -LiteralPath $stub).Length -gt 1MB) { continue }
                try {
                    $text = [System.Text.Encoding]::GetEncoding(28591).GetString([System.IO.File]::ReadAllBytes($stub))
                } catch { continue }
                $m = [regex]::Match($text, 'require\(("(?:[^"\\]|\\.)*")\)')
                if (-not $m.Success) { continue }
                try { $req = [string]($m.Groups[1].Value | ConvertFrom-Json) } catch { continue }
                $script:InjectedPatchers += $req
                if ($req -match 'equicord')    { $script:HasEquicord = $true; $script:InstallNotes += "Equicord is injected into $branch ($req)" }
                elseif ($req -match 'vencord') { $script:HasVencord = $true;  $script:InstallNotes += "Vencord is injected into $branch ($req)" }
                else { $script:InstallNotes += "$branch is patched by something else ($req)" }
            }
        }
    }

    if ($roaming) {
        foreach ($d in 'Vencord', 'vesktop') {
            $p = Join-Path $roaming $d
            if (Test-Path -LiteralPath $p -PathType Container) { $script:HasVencord = $true; $script:InstallNotes += "Found $d data folder ($p)" }
        }
        foreach ($d in 'Equicord', 'equibop') {
            $p = Join-Path $roaming $d
            if (Test-Path -LiteralPath $p -PathType Container) { $script:HasEquicord = $true; $script:InstallNotes += "Found $d data folder ($p)" }
        }
    }
}

# Is Discord already loading the build from this checkout?
function Test-InjectedFrom($repo) {
    foreach ($p in $script:InjectedPatchers) {
        $root = Find-CheckoutRoot (Split-Path -Path $p -Parent)
        if ($root -and ($root -ieq $repo)) { return $true }
    }
    return $false
}

function Search-Checkouts($dir, $depth, $found) {
    if ($depth -lt 0) { return }
    if (Get-CheckoutClient $dir) {
        $full = (Resolve-Path -LiteralPath $dir).ProviderPath.TrimEnd('\', '/')
        if (-not ($found -contains $full)) { [void]$found.Add($full) }
        return
    }
    $children = Get-ChildItem -LiteralPath $dir -Directory -ErrorAction SilentlyContinue
    foreach ($c in $children) {
        if ($c.Name.StartsWith('.')) { continue }
        if ('node_modules', 'AppData', 'Application Data', 'OneDriveTemp', 'Windows', 'Program Files', 'Program Files (x86)' -contains $c.Name) { continue }
        Search-Checkouts $c.FullName ($depth - 1) $found
    }
}

# Returns candidate checkouts without duplicates.
function Find-Checkouts {
    $found = New-Object System.Collections.ArrayList

    # 1. Whatever Discord is already loading (a dev build points into the checkout).
    foreach ($p in $script:InjectedPatchers) {
        $root = Find-CheckoutRoot (Split-Path -Path $p -Parent)
        if ($root -and -not ($found -contains $root)) { [void]$found.Add($root) }
    }

    # 2. Usual places people clone to. Shallow search only.
    $roots = @()
    foreach ($n in 'Vencord', 'Equicord', 'source\repos', 'Projects', 'dev', 'src', 'code', 'git', 'GitHub', 'repos', 'Documents', 'Desktop', 'Downloads') {
        $roots += (Join-Path $HOME $n)
    }
    foreach ($r in $roots) {
        if (Test-Path -LiteralPath $r -PathType Container) { Search-Checkouts $r 3 $found }
    }
    if (Test-Path -LiteralPath $HOME -PathType Container) { Search-Checkouts $HOME 1 $found }
    return $found.ToArray()
}

function Show-MissingSource {
    Write-Host ''
    Write-Warn 'No Vencord or Equicord source folder was found.'
    Write-Info 'Custom plugins cannot be added to the normal installer version.'
    Write-Info 'They have to be built from the source code, so you need a source folder'
    Write-Info "(a 'git clone' of the project) on this PC. This installer will not"
    Write-Info 'download it for you.'
    Write-Host ''
    Write-Info 'How to set one up (official guides):'
    Write-Info "  Vencord:  $VencordDocs"
    Write-Info "            $VencordPluginDocs"
    Write-Info "  Equicord: $EquicordDocs"
    Write-Host ''
}

function Select-FolderManually {
    while ($true) {
        Write-Host ''
        Write-Info 'Type or paste the path of your Vencord or Equicord source folder and press Enter.'
        Write-Info 'Or press Enter on an empty line to open a folder picker. Type q to quit.'
        $reply = Read-Host '   Folder'
        if ($null -eq $reply) { return $null }
        if ($reply -match '^\s*(q|quit)\s*$') { return $null }
        $picked = $null
        if (-not $reply -or -not $reply.Trim()) {
            try {
                Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
                $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
                $dlg.Description = 'Select your Vencord or Equicord source folder'
                $dlg.ShowNewFolderButton = $false
                if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $picked = $dlg.SelectedPath }
            } catch {
                Write-Warn 'Could not open a folder picker here. Please type the path instead.'
                continue
            }
            if (-not $picked) { Write-Warn 'No folder selected.'; continue }
        } else {
            $picked = Format-UserPath $reply
        }
        if (-not (Test-Path -LiteralPath $picked -PathType Container)) {
            Write-Warn "That folder does not exist: $picked"
            continue
        }
        $root = Find-CheckoutRoot $picked
        if ($root) { return $root }
        Write-Warn "That is not a Vencord or Equicord source folder: $picked"
        Write-Info 'It should contain package.json, a src folder and scripts\build\build.mjs.'
    }
}

# Returns the selected repo root or stops the script.
# $mode = 'install' or 'uninstall' (uninstall only lists checkouts that have the plugin)
function Select-Checkout($mode) {
    $repo = $null
    if ($Source) {
        $repo = Find-CheckoutRoot (Format-UserPath $Source)
        if (-not $repo) { Stop-Script "Not a Vencord or Equicord source folder: $Source" }
    } else {
        Write-Info 'Looking for source folders (this can take a few seconds)...'
        $list = @(Find-Checkouts)
        if ($mode -eq 'uninstall') {
            $list = @($list | Where-Object { Test-Path -LiteralPath (Join-Path (Join-Path (Join-Path $_ 'src') 'userplugins') $PluginFolder) })
        }

        if ($list.Count -eq 0) {
            if ($mode -eq 'uninstall') {
                Write-Warn "No source folder containing src\userplugins\$PluginFolder was found."
            } else {
                Show-MissingSource
            }
            if ($Yes) {
                if ($mode -eq 'uninstall') {
                    Write-Ok 'ShowAllBadges does not appear to be installed. Nothing to do.'
                    Write-Info 'If it is in a folder that was not found, pass it with -Source "C:\path\to\folder".'
                    exit 0
                }
                Stop-Script 'No source folder found. Pass one with -Source "C:\path\to\folder".'
            }
            Write-Info 'If you do have one somewhere else, you can select it now.'
            $repo = Select-FolderManually
            if (-not $repo) { Stop-Script 'No source folder selected.' }
        } elseif ($list.Count -eq 1 -and $Yes) {
            $repo = $list[0]
        } else {
            Write-Host ''
            Write-Info 'Source folders found:'
            for ($i = 0; $i -lt $list.Count; $i++) {
                Write-Host ("     [{0}] {1} ({2})" -f ($i + 1), $list[$i], (Get-CheckoutClient $list[$i]))
            }
            Write-Host ("     [{0}] Choose a different folder" -f ($list.Count + 1))
            if ($Yes) { Stop-Script 'More than one source folder found. Pass the one you want with -Source.' }
            while (-not $repo) {
                $choice = Read-Host ("   Which one? [1-{0}]" -f ($list.Count + 1))
                if ($null -eq $choice) { Stop-Script 'No source folder selected.' }
                $n = 0
                if (-not [int]::TryParse($choice, [ref]$n)) { continue }
                if ($n -ge 1 -and $n -le $list.Count) {
                    $repo = $list[$n - 1]
                } elseif ($n -eq $list.Count + 1) {
                    $repo = Select-FolderManually
                    if (-not $repo) { Stop-Script 'No source folder selected.' }
                }
            }
        }
    }
    return $repo
}

# ------------------------------------------------------------ prerequisites

function Assert-RepoValid($repo, $label, $docs) {
    if (-not (Test-Cmd 'git')) {
        Write-Fail 'Git was not found.'
        Write-Info 'Install it from https://git-scm.com/download/win, then open a new window and run this again.'
        Stop-Script 'Git is required.'
    }
    # Windows PowerShell 5.1 turns stderr output into an error when it is redirected, so relax that here.
    $oldPref = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & git -C $repo rev-parse --is-inside-work-tree 2>&1 | Out-Null; $rc = $LASTEXITCODE } catch { $rc = 1 }
    $ErrorActionPreference = $oldPref
    if ($rc -ne 0) {
        Write-Fail "$repo is not a Git repository."
        Write-Info "The source folder must be a 'git clone' of $label, not a downloaded zip."
        Write-Info "Guide: $docs"
        Stop-Script "Source folder is not a valid $label checkout."
    }
    Write-Ok 'Git found, repository looks valid'
}

function Assert-BuildTools($repo, $label) {
    $missing = $false
    if (Test-Cmd 'node') {
        $have = 0
        $want = 0
        $v = (& node -v) -replace '^v', ''
        [void][int]::TryParse(($v -split '\.')[0], [ref]$have)
        try {
            $eng = (Get-Content -LiteralPath (Join-Path $repo 'package.json') -Raw | ConvertFrom-Json).engines.node
            if ($eng -match '(\d+)') { $want = [int]$Matches[1] }
        } catch { $want = 0 }
        if ($want -gt 0 -and $have -lt $want) {
            Write-Fail "Node.js $v is too old. $label needs Node.js $want or newer."
            Write-Info 'Get the current LTS from https://nodejs.org/'
            $missing = $true
        } else {
            Write-Ok "Node.js found (v$v)"
        }
    } else {
        Write-Fail 'Node.js was not found.'
        Write-Info 'Install the LTS version from https://nodejs.org/, then open a new window and run this again.'
        $missing = $true
    }
    if (Test-Cmd 'pnpm') {
        Write-Ok 'pnpm found'
    } else {
        Write-Fail 'pnpm was not found.'
        Write-Info 'Install it with:  npm install -g pnpm'
        Write-Info 'Then open a new window and run this again.'
        $missing = $true
    }
    if ($missing) { Stop-Script 'Missing prerequisites. Install them and run this again.' }
}

# Returns $true when dependencies are ready for a build.
function Confirm-Dependencies($repo) {
    if (Test-Path -LiteralPath (Join-Path $repo 'node_modules') -PathType Container) {
        Write-Ok 'Project dependencies are installed (node_modules)'
        return $true
    }
    Write-Warn 'Project dependencies are not installed yet (no node_modules folder).'
    Write-Info 'The official step for this is: pnpm install --frozen-lockfile'
    if (Ask-YesNo "Run it now in $repo?" $true) {
        Push-Location -LiteralPath $repo
        try {
            & pnpm install --frozen-lockfile | Out-Host
            $rc = $LASTEXITCODE
        } finally { Pop-Location }
        if ($rc -ne 0) {
            Write-Fail "pnpm install failed (exit code $rc). See the output above."
            return $false
        }
        Write-Ok 'Dependencies installed'
        return $true
    }
    return $false
}

# Returns $true only if the build really succeeded.
function Invoke-Build($repo) {
    Write-Info "Running: pnpm build   (in $repo)"
    Write-Host ''
    Push-Location -LiteralPath $repo
    try {
        & pnpm build | Out-Host
        $rc = $LASTEXITCODE
    } finally { Pop-Location }
    Write-Host ''
    if ($rc -ne 0) {
        Write-Fail "The build FAILED (pnpm build exit code $rc). See the output above."
        return $false
    }
    Write-Ok 'Build finished'
    return $true
}

function Test-DiscordRunning {
    return [bool](Get-Process -Name 'Discord', 'DiscordPTB', 'DiscordCanary', 'DiscordDevelopment' -ErrorAction SilentlyContinue)
}
