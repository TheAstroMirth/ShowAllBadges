#!/bin/bash
# ShowAllBadges - https://github.com/TheAstroMirth/ShowAllBadges
# Copyright (c) 2026 TheAstroMirth
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Double-click this file in Finder to run the ShowAllBadges installer in Terminal.
cd "$(dirname "$0")" || exit 1
SAB_PAUSE=1 exec /bin/bash "./install.sh" "$@"
