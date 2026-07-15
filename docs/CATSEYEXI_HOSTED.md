# CatsEyeXI Runtime Profile

OddQ RC3 uses one CatsEyeXI profile: a local Ashita addon with bundled guide
data. There are no hosted endpoints, replacement keys, allowlists, bridge
settings, backend services, or server changes to configure.

## Install surface

```text
Ashita/addons/oddq
```

The addon is loaded with `/addon load oddq` and controlled through `/odd`. It
does not install an executable, DLL, Windows service, scheduled task, or server
module.

## Client boundary

OddQ uses Ashita's local APIs to read the current zone, position, heading, and
level for display. It does not register packet handlers, send game commands,
control other addons, or automate player actions.

Its only persistent files are first-launch state and pointer preferences under
`config/addons/oddq` in the active Ashita installation.

## Staff review checklist

- Confirm the archive's addon tree matches `MANIFEST.json` and
  `SHA256SUMS.txt`.
- Confirm no network, bridge, backend, updater, or telemetry module is shipped.
- Confirm no packet or outgoing-command API is referenced.
- Confirm the one-window browser/guide flow, optional pointer, and Settings
  popup are the complete UI surface.
- Confirm a missing coordinate remains a checkpoint or manual cue.
- Confirm the addon does not automatically advance a guide or claim arrival.

Useful offline scans:

```powershell
rg -n "QueueCommand|AddOutgoingPacket|InjectPacket|packet_out|packet_in" Ashita/addons/oddq
rg -n -i "socket|websocket|httpclient|localhost|127\.0\.0\.1" Ashita/addons/oddq -g "*.lua"
```

Bundled guide records may include web URLs as source attribution. OddQ does not
fetch those URLs at runtime.

## Validation boundary

Source scans, Lua syntax checks, unit tests, layout probes, and archive checks
are offline evidence. They do not prove live-client UI behavior. CatsEyeXI
window interaction is not automated for RC3; in-game review is manual and must
be performed only by an authorized tester.
