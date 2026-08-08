# CatsEyeXI Runtime Profile

OddQ v1.0.7 uses one CatsEyeXI profile: a local Ashita addon with bundled guide
data. There are no hosted endpoints, replacement keys, allowlists, bridge
settings, backend services, or server changes to configure.

## Install surface

```text
Ashita/addons/oddq
```

The 42-file release addon is loaded with `/addon load oddq` and controlled through
`/odd`. It does not install an executable, DLL, Windows service, scheduled task,
or server module.

## Client boundary

OddQ renders bundled guide data in one shared Browser/Guide window and a compact
Step Pointer. It reads local zone, position, heading, rank, mounted status, and only
the current step's named item/key-item evidence. A receive-only cutscene handler
and copied-field quest/mission readers cannot block or mutate packets. OddQ does
not automate movement, targeting, trading, or combat. A user-clicked **Warp**
button may send only `/uw hp <alias>` or
`/uw sg <alias>` to Uberwarp while the player is within interaction range.
The pointer also offers `/mount "Raptor"` only in CatsEye zones carrying the
server's mount capability bit, and `/dismount` only while mounted.

Its persistent files are `first-launch-seen.txt` and `resume-state.txt` under
`config/addons/oddq` in the active Ashita installation. Resume state contains
only the bundled guide ID, step number, route choice, view, window-open flag,
and the armed/pending booleans for the Rank 10 milestone notice. It does not
persist the player's rank.

## Staff review checklist

- Confirm `LICENSE` and `NOTICE.md` accompany any CatsEyeXI redistribution.
- Confirm corresponding OddQ source is available and modified copies identify changes.
- Confirm the archive's 42-file addon tree matches `MANIFEST.json` and
  `SHA256SUMS.txt`.
- Confirm no bridge, backend, auto-updater, or telemetry module is shipped and
  that the sole external request remains the fixed public GitHub release check.
- Confirm no packet mutation API is referenced and every outgoing command is a
  guarded, user-clicked Uberwarp, mount/dismount, or authored Warp Home action.
- Confirm Browser and Guide share the main window and the Step Pointer stays
  limited to the selected guide step.
- Confirm a sourced map number appears beside its grid and an unknown map
  number temporarily displays as `Map #1`.
- Confirm automatic advancement requires explicit current-step zone, item,
  key-item, or cutscene evidence and never claims arrival from distance alone.
- Confirm its local writes are limited to the first-launch marker and validated
  guide resume state under `config/addons/oddq`.

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
window interaction is not automated for v1.0.7; in-game review is manual and must
be performed only by an authorized tester.
