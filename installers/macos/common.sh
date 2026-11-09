#!/bin/bash
# ShowAllBadges - https://github.com/TheAstroMirth/ShowAllBadges
# Copyright (c) 2026 TheAstroMirth
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Shared helpers for the ShowAllBadges macOS installer and uninstaller.
# Sourced by install.sh and uninstall.sh. Written for the bash 3.2 that ships with macOS.
# shellcheck disable=SC2034,SC2088

PLUGIN_NAME="ShowAllBadges"
PLUGIN_FOLDER="showAllBadges"
BACKUP_ROOT="$HOME/.showallbadges/backups"

VENCORD_DOCS="https://docs.vencord.dev/installing/"
VENCORD_PLUGIN_DOCS="https://docs.vencord.dev/installing/custom-plugins/"
EQUICORD_DOCS="https://github.com/Equicord/Equicord#installing-equicord-devbuild"

# Set by parse_args
OPT_SOURCE=""
OPT_YES=0
OPT_NO_BUILD=0

# Set by detection
HAS_VENCORD=0
HAS_EQUICORD=0
INSTALL_NOTES=""     # human readable lines about what was found
INJECTED_PATCHERS="" # newline separated patcher.js paths Discord is loading

REPO=""
CLIENT=""            # vencord | equicord
CLIENT_LABEL=""

if [ -t 1 ]; then
    C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
    C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'; C_OFF=$'\033[0m'
else
    C_RED=""; C_GREEN=""; C_YELLOW=""; C_BOLD=""; C_DIM=""; C_OFF=""
fi

step() { printf '\n%s== %s ==%s\n' "$C_BOLD" "$1" "$C_OFF"; }
info() { printf '   %s\n' "$1"; }
ok()   { printf ' %s+%s %s\n' "$C_GREEN" "$C_OFF" "$1"; }
warn() { printf ' %s!%s %s\n' "$C_YELLOW" "$C_OFF" "$1"; }
fail() { printf ' %sx%s %s\n' "$C_RED" "$C_OFF" "$1" >&2; }

die() {
    fail "$1"
    printf '\n%s%s did not finish. Nothing else was changed.%s\n' "$C_RED" "$SCRIPT_TITLE" "$C_OFF" >&2
    exit 1
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --source)   shift; OPT_SOURCE="${1:-}" ;;
            --source=*) OPT_SOURCE="${1#--source=}" ;;
            --yes|-y)   OPT_YES=1 ;;
            --no-build) OPT_NO_BUILD=1 ;;
            --help|-h)  usage; exit 0 ;;
            *) fail "Unknown option: $1"; usage; exit 2 ;;
        esac
        shift
    done
}

# ask "Question" default(y|n)  -> returns 0 for yes
ask() {
    local prompt="$1" def="$2" hint reply
    if [ "$def" = "y" ]; then hint="[Y/n]"; else hint="[y/N]"; fi
    if [ "$OPT_YES" = "1" ]; then
        [ "$def" = "y" ]; return
    fi
    printf '   %s %s ' "$prompt" "$hint"
    IFS= read -r reply || reply=""
    case "$reply" in
        [Yy]|[Yy][Ee][Ss]) return 0 ;;
        [Nn]|[Nn][Oo])     return 1 ;;
        *) [ "$def" = "y" ] ;;
    esac
}

require_macos() {
    if [ "$(uname -s)" != "Darwin" ] && [ -z "${SAB_ALLOW_NON_MACOS:-}" ]; then
        die "This script is for macOS. On Windows use installers\\windows\\install.bat."
    fi
}

# Double-clicked .command files do not always get the PATH from ~/.zshrc,
# so add the usual places Node, pnpm and Git live. Nothing is installed here.
extend_path() {
    local d
    for d in /opt/homebrew/bin /usr/local/bin "$HOME/Library/pnpm" "$HOME/.local/share/pnpm" \
             "$HOME/.volta/bin" "$HOME/.asdf/shims" "$HOME/.local/share/mise/shims" "$HOME/.local/bin"; do
        if [ -d "$d" ]; then
            case ":$PATH:" in *":$d:"*) ;; *) PATH="$PATH:$d" ;; esac
        fi
    done
    if ! command -v node >/dev/null 2>&1; then
        if [ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]; then
            # shellcheck disable=SC1090,SC1091
            . "${NVM_DIR:-$HOME/.nvm}/nvm.sh" >/dev/null 2>&1
        elif command -v fnm >/dev/null 2>&1; then
            eval "$(fnm env 2>/dev/null)"
        fi
    fi
    export PATH
}

# ---------------------------------------------------------------- checkouts

# Prints "vencord" or "equicord" if the folder is a source checkout of either.
checkout_client() {
    local dir="$1" name
    [ -f "$dir/package.json" ] || return 1
    [ -d "$dir/src" ] || return 1
    [ -f "$dir/scripts/build/build.mjs" ] || return 1
    name=$(sed -n 's/^[[:space:]]*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$dir/package.json" | head -n 1)
    case "$name" in
        vencord|equicord) printf '%s\n' "$name"; return 0 ;;
    esac
    return 1
}

# Accepts the repo root, or a folder inside it (src, src/userplugins, dist...),
# and prints the repo root.
find_checkout_root() {
    local dir="$1" i=0
    [ -d "$dir" ] || return 1
    dir=$(cd "$dir" 2>/dev/null && pwd -P) || return 1
    while [ $i -lt 5 ] && [ -n "$dir" ] && [ "$dir" != "/" ]; do
        if checkout_client "$dir" >/dev/null; then
            printf '%s\n' "$dir"; return 0
        fi
        dir=$(dirname "$dir")
        i=$((i + 1))
    done
    return 1
}

# Turns what a user typed or dragged into Terminal into a plain path.
clean_path() {
    local p="$1"
    # trim whitespace
    p="${p#"${p%%[![:space:]]*}"}"
    p="${p%"${p##*[![:space:]]}"}"
    case "$p" in
        \"*\") p="${p#\"}"; p="${p%\"}" ;;
        \'*\') p="${p#\'}"; p="${p%\'}" ;;
        *) p=$(printf '%s' "$p" | sed 's/\\\(.\)/\1/g') ;;
    esac
    case "$p" in
        "~")   p="$HOME" ;;
        "~/"*) p="$HOME/${p#\~/}" ;;
    esac
    printf '%s\n' "$p"
}

# ------------------------------------------------------- installed clients

note() { INSTALL_NOTES="${INSTALL_NOTES}${1}
"; }

detect_installed() {
    local app_dirs base app res stub req support d
    app_dirs="${SAB_APP_DIRS:-/Applications:$HOME/Applications}"
    support="$HOME/Library/Application Support"

    local IFS_OLD="$IFS"
    IFS=":"
    for base in $app_dirs; do
        IFS="$IFS_OLD"
        for app in "Discord" "Discord PTB" "Discord Canary" "Discord Development"; do
            res="$base/$app.app/Contents/Resources"
            stub="$res/app.asar"
            # A patched Discord has the real app moved to _app.asar and a tiny
            # app.asar that just does require("<path to patcher.js>").
            [ -f "$res/_app.asar" ] && [ -f "$stub" ] || continue
            req=$(LC_ALL=C grep -a -o 'require("[^"]*")' "$stub" 2>/dev/null | head -n 1)
            req="${req#require(\"}"; req="${req%\")}"
            [ -n "$req" ] || continue
            INJECTED_PATCHERS="${INJECTED_PATCHERS}${req}
"
            case "$(printf '%s' "$req" | tr '[:upper:]' '[:lower:]')" in
                *equicord*) HAS_EQUICORD=1; note "Equicord is injected into $app ($req)" ;;
                *vencord*)  HAS_VENCORD=1;  note "Vencord is injected into $app ($req)" ;;
                *)          note "$app is patched by something else ($req)" ;;
            esac
        done
        IFS=":"
    done
    IFS="$IFS_OLD"

    for d in Vencord vesktop; do
        if [ -d "$support/$d" ]; then HAS_VENCORD=1; note "Found $d data folder ($support/$d)"; fi
    done
    for d in Equicord equibop; do
        if [ -d "$support/$d" ]; then HAS_EQUICORD=1; note "Found $d data folder ($support/$d)"; fi
    done
}

# Is Discord already loading the build from this checkout?
is_injected_from() {
    local repo="$1" line root
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        root=$(find_checkout_root "$(dirname "$line")" 2>/dev/null) || continue
        [ "$root" = "$repo" ] && return 0
    done <<EOF
$INJECTED_PATCHERS
EOF
    return 1
}

# Prints candidate checkouts, one per line, without duplicates.
list_checkouts() {
    local line root found="" roots r pj
    emit() {
        case "
$found" in *"
$1
"*) return ;; esac
        found="${found}$1
"
        printf '%s\n' "$1"
    }

    # 1. Whatever Discord is already loading (a dev build points into the checkout).
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        root=$(find_checkout_root "$(dirname "$line")" 2>/dev/null) && emit "$root"
    done <<EOF
$INJECTED_PATCHERS
EOF

    # 2. Usual places people clone to. Shallow search only.
    roots="$HOME/Vencord
$HOME/Equicord
$HOME/Developer
$HOME/Projects
$HOME/projects
$HOME/dev
$HOME/src
$HOME/code
$HOME/git
$HOME/GitHub
$HOME/repos
$HOME/Documents
$HOME/Desktop
$HOME/Downloads
$HOME"
    while IFS= read -r r; do
        [ -d "$r" ] || continue
        while IFS= read -r pj; do
            [ -n "$pj" ] || continue
            root=$(dirname "$pj")
            if checkout_client "$root" >/dev/null; then
                root=$(cd "$root" && pwd -P) && emit "$root"
            fi
        done <<EOF
$(find "$r" -maxdepth 4 \( -name node_modules -o -name 'Library' -o -name '.*' \) -prune -o -type f -name package.json -print 2>/dev/null)
EOF
    done <<EOF
$roots
EOF
}

explain_missing_source() {
    echo
    warn "No Vencord or Equicord source folder was found."
    info "Custom plugins cannot be added to the normal installer version."
    info "They have to be built from the source code, so you need a source folder"
    info "(a 'git clone' of the project) on this Mac. This installer will not"
    info "download it for you."
    echo
    info "How to set one up (official guides):"
    info "  Vencord:  $VENCORD_DOCS"
    info "            $VENCORD_PLUGIN_DOCS"
    info "  Equicord: $EQUICORD_DOCS"
    echo
}

pick_folder_manually() {
    local reply picked root
    while :; do
        echo
        info "Drag your Vencord or Equicord source folder into this window and press Return."
        info "Or press Return on an empty line to open a folder picker. Type q to quit."
        printf '   Folder: '
        IFS= read -r reply || return 1
        case "$reply" in q|Q|quit) return 1 ;; esac
        if [ -z "$reply" ]; then
            if command -v osascript >/dev/null 2>&1; then
                picked=$(osascript -e 'POSIX path of (choose folder with prompt "Select your Vencord or Equicord source folder")' 2>/dev/null) || picked=""
            else
                picked=""
            fi
            [ -n "$picked" ] || { warn "No folder selected."; continue; }
        else
            picked=$(clean_path "$reply")
        fi
        if [ ! -d "$picked" ]; then
            warn "That folder does not exist: $picked"
            continue
        fi
        if root=$(find_checkout_root "$picked"); then
            REPO="$root"
            return 0
        fi
        warn "That is not a Vencord or Equicord source folder: $picked"
        info "It should contain package.json, a src folder and scripts/build/build.mjs."
    done
}

# Sets REPO, CLIENT and CLIENT_LABEL or exits.
# $1 = "install" or "uninstall" (uninstall only lists checkouts that have the plugin)
select_checkout() {
    local mode="$1" list="" line count=0 i choice root

    if [ -n "$OPT_SOURCE" ]; then
        root=$(find_checkout_root "$(clean_path "$OPT_SOURCE")") \
            || die "Not a Vencord or Equicord source folder: $OPT_SOURCE"
        REPO="$root"
    else
        info "Looking for source folders (this can take a few seconds)..."
        while IFS= read -r line; do
            [ -n "$line" ] || continue
            if [ "$mode" = "uninstall" ] && [ ! -e "$line/src/userplugins/$PLUGIN_FOLDER" ]; then
                continue
            fi
            list="${list}${line}
"
            count=$((count + 1))
        done <<EOF
$(list_checkouts)
EOF

        if [ "$count" -eq 0 ]; then
            if [ "$mode" = "uninstall" ]; then
                warn "No source folder containing src/userplugins/$PLUGIN_FOLDER was found."
            else
                explain_missing_source
            fi
            if [ "$OPT_YES" = "1" ]; then
                if [ "$mode" = "uninstall" ]; then
                    ok "ShowAllBadges does not appear to be installed. Nothing to do."
                    info "If it is in a folder that was not found, pass it with --source \"/path/to/folder\"."
                    exit 0
                fi
                die "No source folder found. Pass one with --source \"/path/to/folder\"."
            fi
            info "If you do have one somewhere else, you can select it now."
            pick_folder_manually || die "No source folder selected."
        elif [ "$count" -eq 1 ] && [ "$OPT_YES" = "1" ]; then
            REPO=$(printf '%s' "$list" | head -n 1)
        else
            echo
            info "Source folders found:"
            i=0
            while IFS= read -r line; do
                [ -n "$line" ] || continue
                i=$((i + 1))
                printf '     [%d] %s (%s)\n' "$i" "$line" "$(checkout_client "$line")"
            done <<EOF
$list
EOF
            printf '     [%d] Choose a different folder\n' "$((count + 1))"
            [ "$OPT_YES" = "1" ] && die "More than one source folder found. Pass the one you want with --source."
            while :; do
                printf '   Which one? [1-%d] ' "$((count + 1))"
                IFS= read -r choice || die "No source folder selected."
                case "$choice" in ''|*[!0-9]*) continue ;; esac
                if [ "$choice" -ge 1 ] && [ "$choice" -le "$count" ]; then
                    REPO=$(printf '%s' "$list" | sed -n "${choice}p")
                    break
                elif [ "$choice" -eq "$((count + 1))" ]; then
                    pick_folder_manually || die "No source folder selected."
                    break
                fi
            done
        fi
    fi

    CLIENT=$(checkout_client "$REPO") || die "Not a Vencord or Equicord source folder: $REPO"
    if [ "$CLIENT" = "equicord" ]; then CLIENT_LABEL="Equicord"; else CLIENT_LABEL="Vencord"; fi
    ok "Using $CLIENT_LABEL source folder: $REPO"
}

# ------------------------------------------------------------ prerequisites

check_repo_valid() {
    if ! command -v git >/dev/null 2>&1; then
        fail "Git was not found."
        info "Install it with:  xcode-select --install   (or from https://git-scm.com/download/mac)"
        die "Git is required."
    fi
    if ! git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        fail "$REPO is not a Git repository."
        info "The source folder must be a 'git clone' of $CLIENT_LABEL, not a downloaded zip."
        info "Guide: $( [ "$CLIENT" = "equicord" ] && echo "$EQUICORD_DOCS" || echo "$VENCORD_DOCS" )"
        die "Source folder is not a valid $CLIENT_LABEL checkout."
    fi
    ok "Git found, repository looks valid"
}

check_build_tools() {
    local missing=0 want have
    if command -v node >/dev/null 2>&1; then
        have=$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null)
        want=$(cd "$REPO" && node -p '((require("./package.json").engines||{}).node||"").replace(/[^0-9.]/g,"").split(".")[0]||0' 2>/dev/null)
        if [ -n "$want" ] && [ -n "$have" ] && [ "$have" -lt "$want" ] 2>/dev/null; then
            fail "Node.js $have is too old. $CLIENT_LABEL needs Node.js $want or newer."
            info "Get the current LTS from https://nodejs.org/"
            missing=1
        else
            ok "Node.js found ($(node -v 2>/dev/null))"
        fi
    else
        fail "Node.js was not found."
        info "Install the LTS version from https://nodejs.org/ (or 'brew install node')."
        missing=1
    fi
    if command -v pnpm >/dev/null 2>&1; then
        ok "pnpm found"
    else
        fail "pnpm was not found."
        info "Install it with:  npm install -g pnpm   (or 'corepack enable')"
        info "Then close this window and run the installer again."
        missing=1
    fi
    [ "$missing" -eq 0 ] || die "Missing prerequisites. Install them and run this again."
}

# Returns 0 when dependencies are ready for a build.
check_dependencies() {
    if [ -d "$REPO/node_modules" ]; then
        ok "Project dependencies are installed (node_modules)"
        return 0
    fi
    warn "Project dependencies are not installed yet (no node_modules folder)."
    info "The official step for this is: pnpm install --frozen-lockfile"
    if ask "Run it now in $REPO?" y; then
        ( cd "$REPO" && pnpm install --frozen-lockfile )
        local rc=$?
        [ $rc -eq 0 ] || { fail "pnpm install failed (exit code $rc). See the output above."; return 1; }
        ok "Dependencies installed"
        return 0
    fi
    return 1
}

# Returns 0 only if the build really succeeded.
run_build() {
    info "Running: pnpm build   (in $REPO)"
    echo
    ( cd "$REPO" && pnpm build )
    local rc=$?
    echo
    if [ $rc -ne 0 ]; then
        fail "The build FAILED (pnpm build exit code $rc). See the output above."
        return 1
    fi
    ok "Build finished"
    return 0
}

discord_running() {
    pgrep -x Discord >/dev/null 2>&1 || pgrep -f 'Discord( PTB| Canary)?\.app' >/dev/null 2>&1
}

pause_if_double_clicked() {
    if [ -n "${SAB_PAUSE:-}" ]; then
        echo
        printf 'Press Return to close this window. '
        IFS= read -r _ || true
    fi
}
