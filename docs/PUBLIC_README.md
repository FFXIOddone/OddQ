# OddQ

Clean, helpful quest and mission guidance for CatsEyeXI.

OddQ is a local Ashita v4 addon with source-backed item lookup and two focused
views in one shared window:

- **Browser** searches and filters the bundled guide catalog.
- **Guide** shows the selected guide and its current step.

The `OddQ` main window is movable and content-bounded. A compact, always-visible
Step Pointer reads the player's local zone, position, and heading and points at
the selected guide step. OddQ also reads rank for its opt-in Rank 9-1 milestone
watch. There is no Settings popup, developer tuner, map-pin
panel, bridge, backend, updater, or outgoing packet automation.

## Release status

`v1.0.7` is the current stable public patch release. It adds source-backed item
search, a custom coordinate/grid pointer, and an **Items** Browser button. The
Browser is taller by default so the Catseye Quests view shows five complete
results. Windurst 8-2 and 9-2 begin the pointer-authoritative guide model: the
pointer keeps detailed corridor legs and gates while the Guide presents fewer,
readable phases: 77 pointer legs behind 12 phases in 8-2 and 23 legs behind 11
phases in 9-2. The completed Windurst mission routing, faceted 3D HP-crystal
pointer, HP/SG-first routing, mapless-zone exits, and progression triggers from
v1.0.6 remain included.

## In-game views

### Guide Browser

The primary row keeps **Items** between **NPC Finder** and **EXP Camps**, while
the taller Browser shows five complete Catseye Quest results.

![OddQ Guide Browser with Items between NPC Finder and EXP Camps](images/oddq-guide-display-1.0.7.png)

### Guide display

The focused Guide view keeps the current mission step, destination, progress,
and navigation controls together while the Step Pointer remains visible.

![OddQ mission Guide display with the Step Pointer](images/oddq-guide-display-with-pointer-1.0.7.png)

### Minimal obstruction

The Guide window collapses while the compact Step Pointer keeps the selected
destination and available Warp action visible.

![OddQ Step Pointer with Warp and the Guide minimized](images/oddq-mission-guide-warp-with-minimized-guide-window-1.0.7.png)

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

## Using OddQ

Most players can use OddQ entirely through its windows and buttons:

1. Open OddQ and choose **Missions**, **Catseye Quests**, **NPC Finder**,
   **Items**, or **EXP Camps**.
2. Search, select a result, then choose **Open Guide** or **Open Item**.
3. Follow the Step Pointer. Use the Guide's **Previous** and **Next** controls
   only for semantic steps that cannot be observed safely.

The **Items** view searches 23,210 canonical numeric item identities by name,
ID, and alias. It currently has source details for 6,375 items across normal
drops, gil/guild shops, synthesis, and desynthesis. Exact merchant locations
can open a temporary pointer; ambiguous drop and recipe sources remain
descriptive. Item details also remind players to use `/find "<item>"` and check
Mog House/storage before farming. Known server drop-rate tokens are translated
to their documented percentages and rarity labels; unknown tokens stay clearly
identified instead of being guessed. Missing coverage is shown as **No sourced
acquisition path yet**.

When no guide is selected, **Custom Pointer** accepts copied `(X, Y)` pairs and
verified grids such as `(E-5)`. Multi-map zones require an explicit form such
as `Map 2 (E-5)` when the map page cannot be established safely. Custom
destinations are current-zone, no-warp, and intentionally session-only.

Loading a guide replaces the Browser view in the same window. **Back to
Guides** returns to search without opening another window. In the Browser,
**Cancel Guide** ends the current guide and removes its saved reload state.
OddQ restores the last loaded guide, selected step, Warp/No-Warp choice, and
window state after an addon reload or the next login.
Opening any nation's Rank 9-1 mission while the character is Rank 9 arms a
local watch. When Rank changes to 10, OddQ shows a persistent congratulations
window with the CatsEyeXI milestone collection point and all reward choices.
Quest, mission, and job search rows show `ACE / CW / WeW` ownership instead of
map metadata. Supported modes are blue, unavailable modes are white, and the
separators remain white.
The bundled standard quest catalog includes every BG-Wiki-listed Windurst (92),
San d'Oria (82), Bastok (94), and Jeuno (159) quest. Existing routed guides take
priority; a title that is indexed but not routed is labeled **Catalog entry
only** instead of presenting invented directions.

## Location behavior

- A source-backed map number and grid render as `Map N - (grid)`.
- A known grid without a recorded map number temporarily renders as
  `Map #1 - (grid)`; the fallback is not written into source data.
- Ordinary mission, quest, and job steps do not show raw XYZ coordinates in the
  main Guide window; the Step Pointer shows rounded XYZ for its destination.
- EXP guides intentionally use guide markers with `Map #1` when
  the map page is unrecorded; these markers are arrival or reset references,
  not verified pull locations.
- The player normally advances with **Next** or `/odd next`. An authored step
  may also advance from its declared zone, current-step item/key-item, or
  cutscene evidence.

## Local-only safety and privacy

The v1.0.7 addon makes one notification-only HTTPS check of the public OddQ
GitHub release API per addon session; it never downloads or installs updates.
OddQ has no bridge, backend,
telemetry, outgoing packet mutation, or credential path. It reads local zone,
position, heading, rank, mounted status, and only the named inventory/key-item evidence
needed by the current authored step. A receive-only handler captures cutscene
identity; it never blocks, changes, injects, or sends a packet. A user-clicked
**Warp** button can send only `/uw hp <alias>` or `/uw sg <alias>` while the
player is within interaction range of the selected service point. The pointer
offers **Mount** with the temporary Raptor default only in CatsEye mount-capable
zones, and **Dismount** only while mounted. An explicitly recommended Warp Home
button prefers Instant Warp, then a ready Warp Ring, then Ducal Guard's Ring.
OddQ does not read or upload chat and does not automate directional movement,
targeting, trading, casting, attacking, or following.

Its runtime writes are limited to `first-launch-seen.txt` and
`resume-state.txt` under `config/addons/oddq`. Resume state contains only the
bundled guide ID, step number, route choice, view, window-open flag, and the two
booleans needed to restore the Rank 10 milestone notice. Player rank is not persisted.

See `SECURITY.md`, `CATSEYEXI_HOSTED.md`, the repository `LICENSE`, and
`NOTICE.md` for the runtime, license, redistribution, and attribution boundaries.

## Advanced text commands

The Browser and Guide buttons cover normal use. These durable commands are
available for keyboard-driven workflows and troubleshooting:

<details>
<summary>Show text commands</summary>

```text
/odd                              Open the guide browser
/odd <search>                     Load the best matching local guide
/odd missions|quests|jobs|exp     Browse a guide category
/odd npcs [search]                Browse or search NPC locations
/odd items [search]               Browse or search item acquisition details
/odd pointer <X,Y|GRID>|clear     Set or clear a custom current-zone pointer
/odd next                         Advance one guide step
/odd previous                     Return one guide step
/odd route warp|no-warp           Choose guidance for teleport unlocks
/odd warp-home                    Use the recommended available Warp Home item
/odd cancel                       Cancel the guide and clear its resume state
/odd status                       Print concise current guidance
/odd close                        Close OddQ
/odd help                         Print the durable command list
```

</details>

## License and CatsEyeXI redistribution

OddQ source code and original documentation are licensed under GPL-3.0-only.
CatsEyeXI may package and redistribute OddQ under those same terms, including
the requirements to ship the license, preserve notices, identify modifications,
and provide corresponding OddQ source. Third-party game, wiki, trademark, and
CatsEyeXI-owned material is not relicensed by OddQ; see `NOTICE.md`.

## Verification boundary

v1.0.7 has source, syntax, test, layout-probe, package, archive, and
installed-hash checks. Independent downloaded-asset validation follows
publication. The release package contains exactly 42 runtime Lua/data files.
The screenshots above are direct in-game captures supplied by the product
owner; they are repository documentation and are not included in the release
ZIP. No automated interaction with a CatsEyeXI game window is part of this
release.

Item acquisition currently covers normal drops, gil/guild shops, synthesis,
and desynthesis. Currency exchanges, quest rewards, battlefields, NM spawn
rules, HELM, chests/coffers/caskets, and key items remain future source work.
