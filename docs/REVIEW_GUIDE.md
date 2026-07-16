# OddQ v1.0.1 Review Guide

This is the shortest review path for the local-only OddQ MVP.

## What ships

The release contains exactly 13 runtime Lua/data files under
`Ashita/addons/oddq`:

```text
oddq.lua
guidance_state.lua
objective_catalog.lua
local_filesystem.lua
ui/guide_browser.lua
ui/imgui_text.lua
ui/main_window.lua
ui/route_window.lua
ui/skin.lua
ui/window_state.lua
data/objectives.lua
data/exp_camps.lua
data/zone_names.lua
```

`oddq.lua` owns Ashita events and `/odd` command routing.
`ui/main_window.lua` owns the one movable, resizable window that switches
between Browser and Guide. `ui/route_window.lua` renders the current step and
Previous/Next controls.

There is no Pointer window, Settings popup, Guide Hub, player-state tracker,
bridge, backend, service, helper executable, updater, or server component.

## Runtime review

Review these properties directly in the shipped Lua tree:

1. There is no outgoing-command or packet-mutation API.
2. No network client or endpoint is loaded by the addon.
3. The D3D-present handler renders bundled local guide data; it does not inspect
   player state or automate gameplay.
4. A source-backed map number appears beside its grid. If only the grid is
   established, the UI temporarily displays `Map #1`; source data remains unset.
5. The only local write is the first-launch marker.
6. Closing `OddQ` leaves no second OddQ window or popup behind.

Useful source scans:

```powershell
rg -n "QueueCommand|AddOutgoingPacket|InjectPacket|packet_out|packet_in" addon/ashita/oddq
rg -n -i "socket|websocket|httpclient|localhost|127\.0\.0\.1" addon/ashita/oddq -g "*.lua"
rg -n "ODD_SECURITY_NOTE|ODD_FILE_WRITE" addon/ashita/oddq/oddq.lua
```

The first two scans should return no executable runtime integration. Bundled
guide records may contain `https://` source-attribution links; those strings are
data, not network calls.

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
9. Confirm no Pointer, Settings, or other OddQ window appears.
10. Close the window and confirm no OddQ UI remains open.

## Release artifact

The release zip should contain the installable 13-file
`Ashita/addons/oddq` tree plus release notes, a file manifest, and
`SHA256SUMS.txt`. It should not contain development caches, private paths,
captures, credentials, executables, or unrelated projects.

Verify the checksum manifest after extracting the archive and review
`SECURITY.md`, `CATSEYEXI_HOSTED.md`, and the repository `../NOTICE.md`
alongside the addon.

## Evidence boundary

Offline tests and layout probes establish source and package contracts. They do
not establish live-client UX. v1.0.1 makes no automated CatsEyeXI-window test
claim; the player-facing checklist above remains a manual review step.

## Known limitations

- OddQ provides written guidance, not pathfinding or movement automation.
- Some steps have no source-backed map number and temporarily display `Map #1`.
- Guide correctness and server-specific route quality should be reported and
  improved incrementally after release.
