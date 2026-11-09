#!/bin/bash
# ShowAllBadges uninstaller for macOS.
# Removes only src/userplugins/showAllBadges from a Vencord or Equicord source folder.
# It never removes Vencord, Equicord, Discord or any other plugin.

SCRIPT_TITLE="ShowAllBadges uninstall"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=common.sh
. "$SCRIPT_DIR/common.sh"

usage() {
    cat <<EOF
Usage: uninstall.sh [options]
  --source "PATH"  Use this Vencord/Equicord source folder (skips the search)
  --yes            Do not ask questions, use the default answers
  --no-build       Remove the plugin but do not run 'pnpm build'
  --help           Show this help
EOF
}

parse_args "$@"
trap pause_if_double_clicked EXIT

printf '%sShowAllBadges uninstaller%s\n' "$C_BOLD" "$C_OFF"

require_macos
extend_path

step "1/3  Source folder"
detect_installed
select_checkout uninstall

DEST="$REPO/src/userplugins/$PLUGIN_FOLDER"

step "2/3  Removing the plugin"
REMOVED=0
if [ ! -e "$DEST" ] && [ ! -L "$DEST" ]; then
    ok "ShowAllBadges is not installed in this source folder. Nothing to remove."
else
    # Safety: only ever touch <repo>/src/userplugins/showAllBadges.
    case "$DEST" in
        */src/userplugins/"$PLUGIN_FOLDER") ;;
        *) die "Refusing to remove an unexpected path: $DEST" ;;
    esac
    if [ ! -L "$DEST" ] && [ -f "$DEST/index.ts" ] && ! grep -q "$PLUGIN_NAME" "$DEST/index.ts"; then
        warn "$DEST/index.ts does not look like the ShowAllBadges plugin."
        ask "Remove this folder anyway?" n || die "Cancelled. Nothing was removed."
    fi
    info "This will remove only: $DEST"
    ask "Continue?" y || die "Cancelled. Nothing was removed."
    if [ -L "$DEST" ]; then
        rm -f "$DEST" || die "Could not remove $DEST"
    else
        rm -rf "$DEST" || die "Could not remove $DEST"
    fi
    [ ! -e "$DEST" ] || die "Could not remove $DEST"
    REMOVED=1
    ok "Removed $DEST"
    info "Other plugins in src/userplugins were not touched."
fi

step "3/3  Rebuilding $CLIENT_LABEL"
REBUILT=0
if [ "$REMOVED" = "0" ]; then
    info "Nothing changed, so no rebuild is needed."
elif [ "$OPT_NO_BUILD" = "1" ]; then
    warn "Skipped (--no-build). Run 'pnpm build' in the source folder to finish."
elif ! command -v pnpm >/dev/null 2>&1 || ! command -v node >/dev/null 2>&1 || [ ! -d "$REPO/node_modules" ]; then
    warn "Cannot rebuild automatically (Node.js, pnpm or node_modules is missing)."
    info "The plugin stays active in Discord until you run:  cd \"$REPO\" && pnpm build"
elif ask "Rebuild $CLIENT_LABEL now so the plugin disappears from Discord?" y; then
    if run_build; then
        REBUILT=1
    else
        info "The plugin folder was removed, but the rebuild failed."
        info "Fix the error above, then run:  cd \"$REPO\" && pnpm build"
        die "Rebuild failed."
    fi
else
    info "The plugin stays active in Discord until you run:  cd \"$REPO\" && pnpm build"
fi

if [ -d "$BACKUP_ROOT" ] && [ -n "$(ls -A "$BACKUP_ROOT" 2>/dev/null)" ]; then
    echo
    info "Backups made by the installer are kept in: $BACKUP_ROOT"
    info "Each one holds the plugin folder that was replaced. To restore one, copy its"
    info "'$PLUGIN_FOLDER' folder back into  <source folder>/src/userplugins/  and run 'pnpm build'."
    info "You can delete the backups folder if you do not need them."
fi

echo
if [ "$REMOVED" = "1" ] && [ "$REBUILT" = "1" ]; then
    printf '%sDone. ShowAllBadges was removed and %s was rebuilt.%s\n' "$C_GREEN" "$CLIENT_LABEL" "$C_OFF"
    echo "Quit Discord completely (Cmd+Q) and open it again."
elif [ "$REMOVED" = "1" ]; then
    printf '%sShowAllBadges was removed, but %s has not been rebuilt yet.%s\n' "$C_YELLOW" "$CLIENT_LABEL" "$C_OFF"
else
    printf '%sNothing to do.%s\n' "$C_GREEN" "$C_OFF"
fi
exit 0
