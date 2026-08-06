# OddQ v1.0.4 Review Guide

This is the shortest review path for the local-only OddQ MVP.

## What ships

The release contains exactly 22 runtime Lua/data files under
`Ashita/addons/oddq`:

```text
oddq.lua
guidance_state.lua
objective_catalog.lua
local_filesystem.lua
player_state.lua
route_steps.lua
uberwarp_routes.lua
warp_home.lua
progression_triggers.lua
packet_state/readers.lua
ui/guide_browser.lua
ui/imgui_text.lua
ui/main_window.lua
ui/route_window.lua
ui/skin.lua
ui/window_state.lua
ui/step_pointer.lua
data/objectives.lua
data/exp_camps.lua
data/npc_finder.lua
data/mount_zones.lua
data/zone_names.lua
```

`oddq.lua` owns Ashita events and `/odd` command routing.
`ui/main_window.lua` owns the one movable, resizable window that switches
between Browser and Guide. `ui/route_window.lua` renders the current step,
conditional Warp/No SG/HP route selector, and Previous/Next controls.

There is no Settings popup, bridge, backend, service, helper executable,
updater, outgoing packet mutator, or server component. The shipped packet reader
is receive-only and returns copied declared fields.

## Runtime review

Review these properties directly in the shipped Lua tree:

1. Outgoing command paths are guarded, user-clicked actions:
   `/uw hp <alias>` or `/uw sg <alias>` while in service-point range, exactly
   `/mount "Raptor"` while unmounted in a CatsEye mount-capable zone, or exactly
   `/dismount` while mounted. An explicitly authored Warp Home button may send
   `/item`, or `/equip`, `/wait`, `/item`, for the selected ready warp item.
2. No network client or endpoint is loaded by the addon.
3. The D3D-present handler renders bundled local guide data and reads local
   zone, position, heading, mounted status, plus only the current step's named
   item/key-item evidence.
4. A source-backed map number appears beside its grid. If only the grid is
   established, the UI temporarily displays `Map #1`; source data remains unset.
5. Authored steps may advance only after their declared zone, current-step item,
   key-item, or cutscene evidence is observed; distance alone never marks a step complete.
6. Local writes are limited to the first-launch marker and validated guide
   resume state under `config/addons/oddq`; unknown guide IDs fail closed.
7. Closing the main `OddQ` window does not disable the always-visible Step Pointer.

Useful source scans:

```powershell
rg -n "QueueCommand|AddOutgoingPacket|InjectPacket|packet_out|packet_in" addon/ashita/oddq
rg -n -i "socket|websocket|httpclient|localhost|127\.0\.0\.1" addon/ashita/oddq -g "*.lua"
rg -n "ODD_SECURITY_NOTE|ODD_FILE_WRITE" addon/ashita/oddq/oddq.lua
```

The packet scan should find receive-only `packet_in` observation and no outgoing
packet mutation API. `QueueCommand` should find only guarded, user-clicked
pointer, mount/dismount, and Warp Home action paths in `oddq.lua`.
Bundled guide records may contain `https://` source-attribution links; those
strings are data, not network calls.

## Player-facing smoke checklist

Run this checklist manually in an approved environment:

1. Load with `/addon load oddq` and open with `/odd`.
2. Confirm Browser and Guide reuse the same `OddQ` window.
3. Move and resize the window; confirm it remains usable from 480x320 through
   its content-bounded 820x560 maximum.
4. Search for a quest, mission, or job guide. Confirm its result row shows
   `ACE / CW / WeW`, with supported modes blue, unavailable modes white, and
   both `/` separators white. Load it and use Previous/Next.
5. Confirm **Previous Mission** is fully visible while ordinary **Previous**
   keeps its compact width.
6. Confirm a step with sourced map data shows `Map N` beside its grid.
7. Confirm a grid without a sourced map number displays `Map #1`.
8. Load an EXP guide and confirm **Travel**, **Targets**, and **Safety** each appear exactly once.
   Confirm its browser row shows level, style, and zone
   without `1 steps` or `Starts at: EXP Parties` filler.
9. Confirm the Step Pointer remains visible, shows only the selected step, and
   points to its current destination.
10. Confirm **Warp** appears only within range of the selected HP/Survival Guide
    and sends the displayed Uberwarp destination when clicked.
11. In a mount-capable field, confirm **Mount** appears only while unmounted and
    calls Raptor; while mounted, confirm it changes to **Dismount**. Confirm no
    **Mount** button appears in a city or dungeon.
12. On an explicitly authored progression step, confirm only the named item,
    key item, zone, or cutscene evidence advances the guide.
13. On an explicitly authored Warp Home step, confirm the button prefers Instant
    Warp, then a ready Warp Ring, then Ducal Guard's Ring.

## Release artifact

The release zip should contain the installable 22-file
`Ashita/addons/oddq` tree plus release notes, a file manifest, and
`SHA256SUMS.txt`. It should not contain development caches, private paths,
captures, credentials, executables, or unrelated projects.

Verify the checksum manifest after extracting the archive and review
`SECURITY.md`, `CATSEYEXI_HOSTED.md`, and the repository `../NOTICE.md`
alongside the addon.

## Evidence boundary

Offline tests and layout probes establish source and package contracts. They do
not establish live-client UX. v1.0.4 makes no automated CatsEyeXI-window test
claim; the player-facing checklist above remains a manual review step.

## Known limitations

- OddQ selects pointer and teleport guidance; it does not move the character.
- Some steps have no source-backed map number and temporarily display `Map #1`.
- Guide correctness and server-specific route quality should be reported and
  improved incrementally after release.
