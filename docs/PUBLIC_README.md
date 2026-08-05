# OddQ

Clean, helpful quest and mission guidance for CatsEyeXI.

OddQ is a local Ashita v4 addon with two focused views in one shared window:

- **Browser** searches and filters the bundled guide catalog.
- **Guide** shows the selected guide and its current step.

The `OddQ` main window is movable and content-bounded. A compact, always-visible
Step Pointer reads the player's local zone, position, and heading and points at
the selected guide step. There is no Settings popup, developer tuner, map-pin
panel, bridge, backend, updater, or packet-driven progression system.

## Release status

`v1.0.3` is the current stable public patch release. It adds the Step Pointer,
local HP/Survival Guide route selection, expanded mission and EXP coordinates,
CatsEyeXI-specific job unlocks, and explicit Gate Guard starts for all three
nation mission lines.

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
- Ordinary mission, quest, and job steps do not show raw XYZ coordinates in the
  main Guide window; the Step Pointer shows rounded XYZ for its destination.
- EXP guides intentionally use guide markers with `Map #1` when
  the map page is unrecorded; these markers are arrival or reset references,
  not verified pull locations.
- The player normally advances with **Next** or `/odd next`. Only steps with an
  explicit destination-zone contract advance after that zone transition.

## Local-only safety and privacy

The v1.0.3 addon makes no network requests and has no bridge, backend, updater,
telemetry, packet handler, or credential path. It reads local zone, position,
and heading for pointer guidance. A user-clicked **Warp** button can send only
`/uw hp <alias>` or `/uw sg <alias>` while the player is within interaction
range of the selected service point. OddQ does not read or upload chat and does
not move, target, trade, cast, attack, or follow.

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

v1.0.3 has source, syntax, test, layout-probe, package, and installed-hash
checks. The release package contains exactly 16 runtime Lua/data files. Those checks do not
prove live on-screen behavior. No automated interaction with a CatsEyeXI game
window is part of the release evidence; the owner checks in-game UX manually.
