#!/bin/bash
# Double-click this file in Finder to run the ShowAllBadges installer in Terminal.
cd "$(dirname "$0")" || exit 1
SAB_PAUSE=1 exec /bin/bash "./install.sh" "$@"
