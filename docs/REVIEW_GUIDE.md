# OddQ v1.0.3 Review Guide

This is the shortest review path for the local-only OddQ MVP.

## What ships

The release contains exactly 16 runtime Lua/data files under
`Ashita/addons/oddq`:

```text
oddq.lua
guidance_state.lua
objective_catalog.lua
local_filesystem.lua
player_state.lua
uberwarp_routes.lua
ui/guide_browser.lua
ui/imgui_text.lua
ui/main_window.lua
ui/route_window.lua
ui/skin.lua
ui/window_state.lua
ui/step_pointer.lua
data/objectives.lua
data/exp_camps.lua
data/zone_names.lua
```

`oddq.lua` owns Ashita events and `/odd` command routing.
`ui/main_window.lua` owns the one movable, resizable window that switches
between Browser and Guide. `ui/route_window.lua` renders the current step and
Previous/Next controls.

There is no Settings popup, bridge, backend, service, helper executable,
updater, packet reader, or server component.

## Runtime review

Review these properties directly in the shipped Lua tree:

1. The only outgoing command path is the guarded, user-clicked Uberwarp action:
   `/uw hp <alias>` or `/uw sg <alias>` while in service-point range.
2. No network client or endpoint is loaded by the addon.
3. The D3D-present handler renders bundled local guide data and reads only local
   zone, position, and heading for the Step Pointer.
4. A source-backed map number appears beside its grid. If only the grid is
   established, the UI temporarily displays `Map #1`; source data remains unset.
5. Explicit zone-transition steps may advance only after their destination zone
   is observed; distance alone never marks a step complete.
6. The only local write is the first-launch marker.
7. Closing the main `OddQ` window does not disable the always-visible Step Pointer.

Useful source scans:

```powershell
rg -n "QueueCommand|AddOutgoingPacket|InjectPacket|packet_out|packet_in" addon/ashita/oddq
rg -n -i "socket|websocket|httpclient|localhost|127\.0\.0\.1" addon/ashita/oddq -g "*.lua"
rg -n "ODD_SECURITY_NOTE|ODD_FILE_WRITE" addon/ashita/oddq/oddq.lua
```

The packet/network scan should return no executable runtime integration. The
`QueueCommand` scan should find only the guarded Uberwarp callback in `oddq.lua`.
Bundled guide records may contain `https://` source-attribution links; those
strings are data, not network calls.

## Player-facing smoke checklist

Run this checklist manually in an approved environment:

1. Load with `/addon load oddq` and open with `/odd`.
2. Confirm Browser and Guide reuse the same `OddQ` window.
3. Move and resize the window; confirm it remains usable from 480x320 through
   its content-bounded 820x560 maximum.
4. Search for a guide, load it, and use Previous/Next.
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

## Release artifact

The release zip should contain the installable 16-file
`Ashita/addons/oddq` tree plus release notes, a file manifest, and
`SHA256SUMS.txt`. It should not contain development caches, private paths,
captures, credentials, executables, or unrelated projects.

Verify the checksum manifest after extracting the archive and review
`SECURITY.md`, `CATSEYEXI_HOSTED.md`, and the repository `../NOTICE.md`
alongside the addon.

## Evidence boundary

Offline tests and layout probes establish source and package contracts. They do
not establish live-client UX. v1.0.3 makes no automated CatsEyeXI-window test
claim; the player-facing checklist above remains a manual review step.

## Known limitations

- OddQ selects pointer and teleport guidance; it does not move the character.
- Some steps have no source-backed map number and temporarily display `Map #1`.
- Guide correctness and server-specific route quality should be reported and
  improved incrementally after release.
