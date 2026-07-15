# OddQ

Clean, helpful quest and mission guidance for CatsEyeXI.

OddQ is a local Ashita v4 addon with a searchable guide browser, a focused
current-step view, and an optional objective pointer. The MVP deliberately has
one shared browser/guide window, one pointer window, and a small Settings popup.

## Release status

`v0.1.0-rc4` is a public prerelease for review. The Pointer uses OddQ's literal
2.5D arrow geometry for exact directions and concise zone/map transitions. The
retired Guide Hub, developer tuner, map-pin panel, route bridge, pilot tools,
and packet-driven progression are not part of the runtime or release package.

The bundled catalog contains 445 guides:

- 215 mission guides
- 16 job-unlock guides
- 185 quest guides
- 29 EXP guides

First-step pointer coverage is evidence-aware: 227 guides have exact target
coordinates, 183 have a destination-zone or map-grid checkpoint, and 35 use an
honest manual cue. No first step is unsupported, and OddQ does not invent a
location when its data does not establish one.

## Install

Download the RC4 release archive and copy:

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
/odd settings              Open pointer settings
/odd close                 Close OddQ
```

When exact coordinates are available in the current zone, the arrow rotates
toward them. Zone and map checkpoints use a fixed transition arrow with a
destination label; detailed travel steps stay in the Guide. A genuinely
non-spatial instruction does not invent or display a direction.

## Safety and privacy

OddQ is local and guidance-only. It does not use networking, read chat, register
packet handlers, move the player, target entities, send commands, trade, cast,
attack, follow, or handle credentials.

At runtime it passively reads the player zone, position, heading, and level so
the pointer can render. Local writes are limited to a first-launch marker and
the pointer preference under `config/addons/oddq`.

See [docs/SECURITY.md](docs/SECURITY.md) and
[docs/REVIEW_GUIDE.md](docs/REVIEW_GUIDE.md) for the focused reviewer contract.
Source and data attribution are recorded in [NOTICE.md](NOTICE.md).

## Release integrity

The release archive contains only the reachable MVP Lua runtime and its bundled
data. `MANIFEST.json` lists every packaged file, while `SHA256SUMS.txt` provides
independent checksums. Development tools, private evidence, backups, captures,
and executables are excluded.

## Current limitations

- OddQ provides guidance, not pathfinding or movement automation.
- Thirty-five first steps are intentionally manual because a usable spatial
  target is not available.
- RC4 has offline syntax, contract, layout, and packaging proof. It remains a
  prerelease until normal manual in-game review is complete.
