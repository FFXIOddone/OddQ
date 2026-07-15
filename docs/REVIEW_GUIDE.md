# OddQ RC3 Review Guide

This is the shortest review path for the local-only OddQ MVP.

## What ships

The runtime is the Lua addon under `addon/ashita/oddq`. Its player-facing
surface is deliberately small:

- `oddq.lua` owns Ashita events and `/odd` command routing.
- `ui/main_window.lua` owns the one shared browser/guide window.
- `ui/route_window.lua` renders the current guide step and Previous/Next.
- `objective_pointer.lua` resolves exact targets, zone checkpoints, and manual
  cues.
- `ui/arrow_overlay.lua` owns the optional `OddQ Pointer` window.
- `ui/settings_window.lua` owns the Settings popup.

The release does not require or start a bridge, backend, service, helper
executable, updater, or server component.

## Runtime review

Review these properties directly in the shipped Lua tree:

1. There is no outgoing-command or packet-mutation API.
2. No network client or endpoint is loaded by the addon.
3. The D3D-present handler reads local player context, renders UI, and saves
   preferences; it does not automate gameplay.
4. Missing coordinates remain zone/map checkpoints or manual cues.
5. Closing OddQ closes the guide, pointer, and Settings surfaces.

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
2. Confirm the browser and loaded guide reuse the same `OddQ` window.
3. Search for a guide, load it, and use Previous/Next.
4. Confirm Settings only controls the objective pointer.
5. In the objective zone, confirm a coordinate-backed step points toward its
   target.
6. In another zone, confirm the pointer shows destination-zone travel guidance.
7. Confirm a manual step does not invent a direction.
8. Close the window and confirm no OddQ UI remains open.

## Release artifact

The release zip should contain the installable `Ashita/addons/oddq` tree plus
release notes, a file manifest, and `SHA256SUMS.txt`. It should not contain
development caches, private paths, captures, credentials, executables, or
unrelated projects.

Verify the checksum manifest after extracting the archive and review
`SECURITY.md`, `CATSEYEXI_HOSTED.md`, and the repository `../NOTICE.md`
alongside the addon.

## Evidence boundary

Offline tests and layout probes establish source and package contracts. They do
not establish live-client UX. RC3 makes no automated CatsEyeXI-window test claim;
the player-facing checklist above remains a manual review step.

## Known limitations

- The pointer is guidance, not pathfinding or movement automation.
- Some steps have only a destination zone or map-grid checkpoint.
- Non-spatial steps intentionally remain manual.
- Guide correctness and server-specific route quality should be reported and
  improved incrementally during the prerelease.
