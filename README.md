# OddQ

Clean, helpful quest and mission guidance for CatsEyeXI.

OddQ is a local Ashita v4 addon with a searchable Guide Browser and a focused
Guide view in one shared browser/guide window. A compact, always-visible Step Pointer uses
the player's local zone, position, and heading to point at the selected step.

## Release status

`v1.0.3` is the current stable patch release. It adds the Step Pointer, local
HP/Survival Guide route selection, CatsEyeXI job-unlock guidance, expanded
mission/EXP positions, and explicit Gate Guard starts for all three nation
mission lines. The retired Settings popup, developer tuner, map-pin panel,
route bridge, pilot tools, and packet-driven progression are not shipped.

When source data establishes an objective's map number, OddQ displays it beside
the map-grid position. A grid with no recorded map number temporarily displays
as `Map #1`; this fallback is not written into source data. Ordinary mission,
quest, and job steps do not expose raw XYZ coordinates in the main Guide window.
The Step Pointer shows rounded XYZ for the current destination.
EXP guides intentionally show rounded X/Y guide markers in the main Guide window; these are
arrival or reset references, not verified pull locations.

## Install

Download the v1.0.3 release archive and copy:

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
are sourced, or `Map #1 - (grid)` as the temporary missing-map fallback.

## Safety and privacy

OddQ is local and guidance-only. It reads the player's zone, position, and
heading for the pointer. When the player clicks **Warp** within interaction range
of the selected HP or Survival Guide, OddQ sends only `/uw hp <alias>` or
`/uw sg <alias>` to the installed Uberwarp addon. It does not use networking,
read chat, register packet handlers, move the player, target entities, trade,
cast, attack, follow, or handle credentials.

Its only runtime write is a first-launch marker under
`config/addons/oddq/first-launch-seen.txt`.

See [docs/SECURITY.md](docs/SECURITY.md) and
[docs/REVIEW_GUIDE.md](docs/REVIEW_GUIDE.md) for the focused reviewer contract.
Source and data attribution are recorded in [NOTICE.md](NOTICE.md).

## License and redistribution

OddQ source code and original documentation are licensed under
[GPL-3.0-only](LICENSE). CatsEyeXI may package and redistribute OddQ under those
same terms. Redistributors must include the license, preserve applicable notices,
identify modifications, and provide corresponding OddQ source. This grant does
not license Square Enix material, third-party wiki content, or CatsEyeXI-owned
names and content; see [NOTICE.md](NOTICE.md) for the complete boundary.

## Release integrity

The release archive contains the 16-file reachable Lua runtime and its
bundled data. `MANIFEST.json` lists every packaged file, while
`SHA256SUMS.txt` provides independent checksums. Development tools, private
evidence, backups, captures, and executables are excluded.

## Current limitations

- OddQ selects guidance and teleport legs; it does not move the character.
- Unknown map pages use a visible `Map #1` presentation fallback until sourced
  page metadata is added.
- v1.0.3 has syntax, contract, layout, packaging, installed-hash, and owner
  live-client evidence.
