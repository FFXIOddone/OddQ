# OddQ

Clean, helpful quest and mission guidance for CatsEyeXI.

OddQ is a local Ashita v4 addon with a searchable guide browser, a focused
current-step view, and an optional objective pointer. The MVP keeps the UI to:

- one shared window that switches between the guide browser and loaded guide;
- one objective-pointer window; and
- one Settings popup.

The retired Guide Hub, developer tuner, map-pin panel, and addon-control helpers
are not part of the RC4 runtime.

## Release status

`v0.1.0-rc4` is a public MVP review candidate. The Pointer uses OddQ's literal
2.5D arrow geometry for exact directions and concise zone/map transitions. It
is a prerelease so the addon can receive real-world guide and UX feedback
without claiming stable coverage.

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
/odd settings              Open pointer settings
/odd close                 Close OddQ
/odd help                  Print the command list
```

The browser and guide share one window. Loading a guide replaces the browser
view; **Back to Guides** returns to search without opening another guide window.

## Pointer behavior

- In the objective zone, available exact coordinates produce a rotating arrow.
- Outside the objective zone, a fixed transition arrow names the destination;
  detailed travel steps stay in the Guide.
- A zone or map-grid checkpoint uses the same clearly labeled transition arrow,
  not a fabricated world direction.
- A non-spatial instruction does not display or invent a direction.

OddQ does not move the character, target, trade, cast, attack, follow, or mark a
step complete. The player advances the guide with **Next** or `/odd next`.

## Local-only safety and privacy

The RC4 addon makes no network requests and has no bridge, backend, updater,
telemetry, packet handler, or credential path. It does not read or upload chat.

For the pointer, it reads the current zone, player position and heading, and
level through Ashita's local APIs. Its only writes are first-launch state and
pointer preferences under Ashita's local `config/addons/oddq` directory.

See `SECURITY.md`, `CATSEYEXI_HOSTED.md`, and the repository `NOTICE.md` for the
runtime boundary and guide-data attribution.

## Verification boundary

RC4 has offline source, syntax, test, layout-probe, and package checks. Those
checks do not prove live on-screen behavior. No automated interaction with a
CatsEyeXI game window is part of the release evidence; in-game UX is checked
manually.
