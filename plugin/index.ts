/*
 * Vencord, a Discord client mod
 * Copyright (c) 2026 Vendicated and contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

/*
 * ShowAllBadges
 * Original plugin by ItzMeShadow999: https://github.com/ItzMeShadow999/showAllBadges
 * This copy is redistributed by the cross-platform ShowAllBadges project.
 * The patch below is unchanged from the original; only this notice was added (2026-11-10).
 */

import definePlugin from "@utils/types";

export default definePlugin({
    name: "ShowAllBadges",
    description: "Shows every profile badge instead of collapsing the rest behind +n",
    authors: [{ name: "ItzMeShadow999", id: 1065604516399026176n }],

    patches: [
        {
            // Discord cuts the list to the first few badges when this flag is true
            // and uses the remainder as the "+n" count. Forcing it to false makes
            // Discord render its normal, full badge rows.
            find: "UserProfileBadgeListRows",
            replacement: {
                match: /let (\i)=(\i)&&!(\i),(\i)=\1\?Math\.max\(/,
                replace: "let $1=!1,$4=$1?Math.max("
            }
        }
    ]
});
