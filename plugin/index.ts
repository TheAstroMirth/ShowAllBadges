/*
 * ShowAllBadges - https://github.com/TheAstroMirth/ShowAllBadges
 * Copyright (c) 2026 TheAstroMirth
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import definePlugin from "@utils/types";

export default definePlugin({
    name: "ShowAllBadges",
    description: "Shows all profile badges in the badge row instead of hiding the extras behind a +n counter",

    authors: [{ name: "TheAstroMirth", id: 1456018726074847285n }],

    patches: [
        {
            // Discord's profile badge rows ask a feature gate whether to use the
            // collapsed layout (a few badges plus a "+n" popout). Answering "no"
            // right where the question is asked makes Discord fall back to its
            // regular rows, which contain every badge. No badge data is touched.
            find: 'location:"UserProfileBadgeListRows"',
            replacement: {
                match: /\(0,\i\.\i\)\(\{location:"UserProfileBadgeListRows"\}\)/,
                replace: "!1"
            }
        }
    ]
});
