# OddQ

Clean, helpful quest and mission guidance for CatsEyeXI.

OddQ is a local Ashita v4 addon with two focused views in one shared window:

- **Browser** searches and filters the bundled guide catalog.
- **Guide** shows the selected guide and its current step.

The `OddQ` window is movable and resizable from 480x320 up to the
content-bounded 820x560 maximum. RC5 does not ship an objective pointer,
Settings popup, Guide Hub, player tracking, developer tuner, map-pin panel, or
addon-control helper.

## Release status

`v0.1.0-rc5` is a public MVP review candidate. It is a prerelease so the addon
can receive real-world guide and UX feedback without claiming stable coverage.

## Install

Copy the release addon folder into Ashita:

```text
Ashita/addons/oddq -> <Ashita>/addons/oddq
```

Load and open it in game:

```text
/addon load oddq
/odd
```

No executable, DLL, service, bridge, backend, or server change is required.

## Commands

```text
/odd                       Open the guide browser
/odd <search>              Load the best matching local guide
/odd missions              Browse mission guides
/odd quests                Browse quest guides
/odd jobs                  Browse job-unlock guides
/odd exp                   Browse EXP-camp guides
/odd next                  Advance to the next guide step
/odd previous              Return to the previous guide step
/odd status                Print concise current-step guidance
/odd close                 Close OddQ
/odd help                  Print the command list
```

Loading a guide replaces the Browser view in the same window. **Back to
Guides** returns to search without opening another window.

## Location behavior

- A source-backed map number and grid render as `Map N - (grid)`.
- A known grid without a reliable map number renders as
  `(grid) - map not recorded`.
- OddQ does not guess a map number or show raw XYZ coordinates.
- The player advances the guide with **Next** or `/odd next`; OddQ does not
  infer progression from player activity.

## Local-only safety and privacy

The RC5 addon makes no network requests and has no bridge, backend, updater,
telemetry, packet handler, credential path, or player-state tracker. It does not
read or upload chat and does not move, target, trade, cast, attack, or follow.

Its only runtime write is the first-launch marker at
`config/addons/oddq/first-launch-seen.txt`.

See `SECURITY.md`, `CATSEYEXI_HOSTED.md`, and the repository `NOTICE.md` for the
runtime boundary and guide-data attribution.

## Verification boundary

RC5 has offline source, syntax, test, layout-probe, and package checks. The
release package contains exactly 13 runtime Lua/data files. Those checks do not
prove live on-screen behavior. No automated interaction with a CatsEyeXI game
window is part of the release evidence; in-game UX is checked manually.
