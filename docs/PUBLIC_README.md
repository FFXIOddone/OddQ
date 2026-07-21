# OddQ

Clean, helpful quest and mission guidance for CatsEyeXI.

OddQ is a local Ashita v4 addon with two focused views in one shared window:

- **Browser** searches and filters the bundled guide catalog.
- **Guide** shows the selected guide and its current step.

The `OddQ` window is movable and resizable from 480x320 up to the
content-bounded 820x560 maximum. v1.0.2 does not ship an objective pointer,
Settings popup, Guide Hub, player tracking, developer tuner, map-pin panel, or
addon-control helper.

## Release status

`v1.0.2` is the current stable public MVP patch release. It adds explicit
GPL-3.0-only source and CatsEyeXI redistribution terms while preserving the
v1.0.1 EXP-camp fixes.

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
- A known grid without a recorded map number temporarily renders as
  `Map #1 - (grid)`; the fallback is not written into source data.
- Ordinary mission, quest, and job steps do not show raw XYZ coordinates.
- EXP guides intentionally show rounded X/Y guide markers with `Map #1` when
  the map page is unrecorded; these markers are arrival or reset references,
  not verified pull locations.
- The player advances the guide with **Next** or `/odd next`; OddQ does not
  infer progression from player activity.

## Local-only safety and privacy

The v1.0.2 addon makes no network requests and has no bridge, backend, updater,
telemetry, packet handler, credential path, or player-state tracker. It does not
read or upload chat and does not move, target, trade, cast, attack, or follow.

Its only runtime write is the first-launch marker at
`config/addons/oddq/first-launch-seen.txt`.

See `SECURITY.md`, `CATSEYEXI_HOSTED.md`, the repository `LICENSE`, and
`NOTICE.md` for the runtime, license, redistribution, and attribution boundaries.

## License and CatsEyeXI redistribution

OddQ source code and original documentation are licensed under GPL-3.0-only.
CatsEyeXI may package and redistribute OddQ under those same terms, including
the requirements to ship the license, preserve notices, identify modifications,
and provide corresponding OddQ source. Third-party game, wiki, trademark, and
CatsEyeXI-owned material is not relicensed by OddQ; see `NOTICE.md`.

## Verification boundary

v1.0.2 has source, syntax, test, layout-probe, and package checks. The
release package contains exactly 13 runtime Lua/data files. Those checks do not
prove live on-screen behavior. No automated interaction with a CatsEyeXI game
window is part of the release evidence; the owner checks in-game UX manually.
