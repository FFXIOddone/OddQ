# CatsEyeXI Runtime Profile

OddQ v1.0.3 uses one CatsEyeXI profile: a local Ashita addon with bundled guide
data. There are no hosted endpoints, replacement keys, allowlists, bridge
settings, backend services, or server changes to configure.

## Install surface

```text
Ashita/addons/oddq
```

The 16-file addon is loaded with `/addon load oddq` and controlled through
`/odd`. It does not install an executable, DLL, Windows service, scheduled task,
or server module.

## Client boundary

OddQ renders bundled guide data in one shared Browser/Guide window and a compact
Step Pointer. It reads local zone, position, and heading for directions. It does
not register packet handlers or automate movement, targeting, trading, or
combat. A user-clicked **Warp** button may send only `/uw hp <alias>` or
`/uw sg <alias>` to Uberwarp while the player is within interaction range.

Its only persistent file is the first-launch marker at
`config/addons/oddq/first-launch-seen.txt` in the active Ashita installation.

## Staff review checklist

- Confirm `LICENSE` and `NOTICE.md` accompany any CatsEyeXI redistribution.
- Confirm corresponding OddQ source is available and modified copies identify changes.
- Confirm the archive's 16-file addon tree matches `MANIFEST.json` and
  `SHA256SUMS.txt`.
- Confirm no network, bridge, backend, updater, or telemetry module is shipped.
- Confirm no packet API or outgoing command other than the guarded Uberwarp
  commands is referenced.
- Confirm Browser and Guide share the main window and the Step Pointer stays
  limited to the selected guide step.
- Confirm a sourced map number appears beside its grid and an unknown map
  number temporarily displays as `Map #1`.
- Confirm automatic advancement requires an explicit destination-zone contract
  and never claims arrival from distance alone.
- Confirm its only local write is the first-launch marker.

Useful offline scans:

```powershell
rg -n "QueueCommand|AddOutgoingPacket|InjectPacket|packet_out|packet_in" Ashita/addons/oddq
rg -n -i "socket|websocket|httpclient|localhost|127\.0\.0\.1" Ashita/addons/oddq -g "*.lua"
```

Bundled guide records may include web URLs as source attribution. OddQ does not
fetch those URLs at runtime.

## Redistribution boundary

CatsEyeXI may copy, modify, package, and redistribute OddQ under GPL-3.0-only.
The grant covers OddQ code and original documentation only. It does not relicense
the CatsEyeXI name or code, Final Fantasy XI material, or third-party guide data.
The complete attribution and third-party boundary is in `NOTICE.md`.

## Validation boundary

Source scans, Lua syntax checks, unit tests, layout probes, and archive checks
are offline evidence. They do not prove live-client UI behavior. CatsEyeXI
window interaction is not automated for v1.0.3; in-game review is manual and must
be performed only by an authorized tester.
