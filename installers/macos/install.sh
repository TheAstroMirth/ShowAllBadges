#!/bin/bash
# ShowAllBadges installer for macOS (Apple Silicon and Intel).
# Adds the plugin to an existing Vencord or Equicord source folder and builds it.
# It never downloads, clones or installs Vencord or Equicord.

SCRIPT_TITLE="ShowAllBadges install"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=common.sh
. "$SCRIPT_DIR/common.sh"

usage() {
    cat <<EOF
Usage: install.sh [options]
  --source "PATH"  Use this Vencord/Equicord source folder (skips the search)
  --yes            Do not ask questions, use the default answers
  --no-build       Copy the plugin but do not run 'pnpm build'
  --help           Show this help
EOF
}

parse_args "$@"
trap pause_if_double_clicked EXIT

PLUGIN_SRC="$SCRIPT_DIR/../../plugin/index.ts"

printf '%sShowAllBadges installer%s\n' "$C_BOLD" "$C_OFF"
printf '%sUnofficial third-party plugin. Client mods are against the Discord ToS. Use at your own risk.%s\n' "$C_DIM" "$C_OFF"

require_macos
[ -f "$PLUGIN_SRC" ] || die "Cannot find plugin/index.ts next to the installers. Keep the project folder together."
extend_path

step "1/6  Looking for Vencord / Equicord"
detect_installed
if [ -n "$INSTALL_NOTES" ]; then
    printf '%s' "$INSTALL_NOTES" | while IFS= read -r line; do ok "$line"; done
else
    warn "No installed Vencord or Equicord was detected on this Mac."
    info "Looked for a patched Discord in /Applications and for their data folders."
    info "You can still add the plugin to a source folder if you have one."
fi

step "2/6  Source folder"
select_checkout install
if [ "$CLIENT" = "equicord" ] && [ "$HAS_EQUICORD" = "0" ] && [ "$HAS_VENCORD" = "1" ]; then
    warn "This is an Equicord source folder, but only Vencord looks installed."
elif [ "$CLIENT" = "vencord" ] && [ "$HAS_VENCORD" = "0" ] && [ "$HAS_EQUICORD" = "1" ]; then
    warn "This is a Vencord source folder, but only Equicord looks installed."
fi

# Informational only: some Equicord versions carry their own copy of this patch
# in EquiTweaks and move a plugin named "ShowAllBadges" over to that setting.
EQUI_NOTE=0
if [ "$CLIENT" = "equicord" ] && grep -q -E 'migratePluginToSettings\([^)]*"ShowAllBadges"' \
        "$REPO/src/equicordplugins/equiTweaks/index.tsx" 2>/dev/null; then
    EQUI_NOTE=1
fi

step "3/6  Prerequisites"
check_repo_valid
check_build_tools

step "4/6  Copying the plugin"
USERPLUGINS="$REPO/src/userplugins"
DEST="$USERPLUGINS/$PLUGIN_FOLDER"
if [ -e "$DEST/index.ts" ] && cmp -s "$PLUGIN_SRC" "$DEST/index.ts"; then
    ok "The same plugin file is already in place, no backup needed"
elif [ -e "$DEST" ]; then
    STAMP=$(date +%Y%m%d-%H%M%S)
    BACKUP="$BACKUP_ROOT/$CLIENT-$STAMP"
    mkdir -p "$BACKUP" || die "Could not create the backup folder: $BACKUP"
    cp -R "$DEST" "$BACKUP/" || die "Could not back up the existing plugin. Nothing was replaced."
    printf '%s\n' "$DEST" > "$BACKUP/original-location.txt"
    ok "Existing plugin backed up to: $BACKUP/$PLUGIN_FOLDER"
fi
mkdir -p "$DEST" || die "Could not create $DEST"
cp "$PLUGIN_SRC" "$DEST/index.ts" || die "Could not copy the plugin to $DEST"
ok "Plugin copied to: $DEST/index.ts"

step "5/6  Building $CLIENT_LABEL"
BUILT=0
if [ "$OPT_NO_BUILD" = "1" ]; then
    warn "Skipped (--no-build). Run 'pnpm build' in the source folder yourself."
elif check_dependencies; then
    if run_build; then
        BUILT=1
    else
        info "The plugin file was copied, but $CLIENT_LABEL was NOT rebuilt."
        info "Fix the error above, then run:  cd \"$REPO\" && pnpm build"
        info "To remove the plugin again, run uninstall.command."
        die "Build failed."
    fi
else
    info "The plugin file was copied, but $CLIENT_LABEL was NOT built."
    die "Dependencies are missing. Run 'pnpm install --frozen-lockfile' in the source folder, then run this again."
fi

step "6/6  Applying the build"
if [ "$BUILT" = "1" ]; then
    if is_injected_from "$REPO"; then
        ok "Discord already loads $CLIENT_LABEL from this source folder. No inject needed."
    else
        info "Discord is not loading $CLIENT_LABEL from this source folder yet."
        info "$CLIENT_LABEL's own tool for that is:  pnpm inject"
        info "It downloads the official $CLIENT_LABEL installer and asks which Discord to patch."
        info "Quit Discord completely (Cmd+Q) before running it."
        if [ "$OPT_YES" != "1" ] && ask "Run 'pnpm inject' now?" n; then
            ( cd "$REPO" && pnpm inject )
            rc=$?
            if [ $rc -eq 0 ]; then ok "pnpm inject finished"; else warn "pnpm inject exited with code $rc. You can run it again later."; fi
        else
            info "To do it later:  cd \"$REPO\" && pnpm inject"
        fi
        info "Using Vesktop or Equibop instead? Point it at this build in its settings"
        info "(Developer Options > Vencord/Equicord Location) rather than using pnpm inject."
    fi
fi

echo
if [ "$BUILT" = "1" ]; then
    printf '%sDone. ShowAllBadges was added and %s was built successfully.%s\n' "$C_GREEN" "$CLIENT_LABEL" "$C_OFF"
    echo "Next:"
    if discord_running; then
        echo "  1. Quit Discord completely (Cmd+Q) and open it again."
    else
        echo "  1. Open Discord."
    fi
    echo "  2. Go to Settings > Plugins, search for ShowAllBadges and turn it on."
    echo "  3. Restart Discord when it asks."
    if [ "$EQUI_NOTE" = "1" ]; then
        echo
        echo "Note: this Equicord source also has a 'Show All Badges' option under"
        echo "Settings > Plugins > EquiTweaks. If ShowAllBadges turns itself off after a"
        echo "restart, Equicord has moved it to that option, which does the same thing."
    fi
else
    printf '%sShowAllBadges was copied, but %s has not been built yet.%s\n' "$C_YELLOW" "$CLIENT_LABEL" "$C_OFF"
    echo "Run this when you are ready:  cd \"$REPO\" && pnpm build"
fi
exit 0
