# OddQ

Clean, helpful quest and mission guidance for CatsEyeXI.

OddQ is a local Ashita v4 addon with a searchable Guide Browser and a focused
Guide view. Both views use one shared browser/guide window that players can move
and resize from 480x320 up to the content-bounded 820x560 maximum. The RC5 MVP has
no objective pointer, Settings popup, or player-state tracking.

## Release status

`v0.1.0-rc5` is a public prerelease for review. The retired Guide Hub,
objective pointer, Settings popup, developer tuner, map-pin panel, route bridge,
pilot tools, and packet-driven progression are not part of the runtime or
release package.

The bundled catalog contains 445 guides:

- 215 mission guides
- 16 job-unlock guides
- 185 quest guides
- 29 EXP guides

When source data establishes an objective's map number, OddQ displays it beside
the map-grid position. A grid with no reliable map number is labeled
`map not recorded`; OddQ does not invent `Map 1` or expose raw XYZ coordinates.

## Install

Download the RC5 release archive and copy:

```text
Ashita/addons/oddq -> <Ashita>/addons/oddq
```

Then load and open the addon:

```text
/addon load oddq
/odd
```

No executable, DLL, service, server change, or account credential is required.

## Use

```text
/odd                       Open the guide browser
/odd <search>              Load the best matching local guide
/odd missions|quests       Browse a category
/odd jobs|exp              Browse a category
/odd next                  Advance one guide step
/odd previous              Return one guide step
/odd status                Print concise current guidance
/odd close                 Close OddQ
```

Loading a guide switches the shared window from Browser to Guide. **Back to
Guides** returns to search. Location rows show `Map N - (grid)` when both values
are sourced, or `(grid) - map not recorded` when only the grid is known.

## Safety and privacy

OddQ is local and guidance-only. It does not use networking, inspect player
state, read chat, register packet handlers, move the player, target entities,
send commands, trade, cast, attack, follow, or handle credentials.

Its only runtime write is a first-launch marker under
`config/addons/oddq/first-launch-seen.txt`.

See [docs/SECURITY.md](docs/SECURITY.md) and
[docs/REVIEW_GUIDE.md](docs/REVIEW_GUIDE.md) for the focused reviewer contract.
Source and data attribution are recorded in [NOTICE.md](NOTICE.md).

## Release integrity

The release archive contains the 13-file reachable MVP Lua runtime and its
bundled data. `MANIFEST.json` lists every packaged file, while
`SHA256SUMS.txt` provides independent checksums. Development tools, private
evidence, backups, captures, and executables are excluded.

## Current limitations

- OddQ provides written guidance, not pathfinding or movement automation.
- A map number appears only when the source data establishes one; unknown map
  numbers remain visibly marked as not recorded.
- RC5 has offline syntax, contract, layout, and packaging proof. It remains a
  prerelease until normal manual in-game review is complete.
