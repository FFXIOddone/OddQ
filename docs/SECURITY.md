# OddQ Security

OddQ v1.0.4 is a local, guidance-only Ashita addon. It is not movement automation
and does not require a companion process or server component.

## Runtime boundary

The shipped 22-file addon:

- renders a local Guide Browser/Guide window and compact Step Pointer;
- reads bundled guide data plus the player's local zone, position, heading,
  mounted status, and only current-step named item/key-item evidence;
- passively observes incoming cutscene identity and ships receive-only copied-field
  quest/mission readers; none can block or mutate a packet;
- may send `/uw hp <alias>` or `/uw sg <alias>` only after the player clicks
  **Warp** within interaction range of the selected service point;
- may send exactly `/mount "Raptor"` from **Mount** in a CatsEye zone whose
  server settings allow mounts, or `/dismount` from **Dismount** while mounted;
- may send an explicit `/item` or `/equip`, `/wait`, `/item` sequence only after
  the player clicks Warp Home on a step that recommends it; and
- writes only a first-launch marker and validated guide resume state under
  Ashita's local `config/addons/oddq` directory.

The shipped addon does not:

- scan unrelated inventory/key items, chat, credentials, or outgoing packets;
- ship a Settings popup, bridge, backend, updater, or telemetry client;
- make network requests;
- inject, mutate, block, or send packets;
- issue directional movement, targeting, trading, or combat commands;
- read or upload chat; or
- collect, store, or transmit account credentials.

## Fail-closed guidance

OddQ does not fabricate position data or write fallback map values into source
data. A source-backed map number appears beside the objective grid. When a grid
is known but its map number is not established, the UI temporarily displays
`Map #1`. Guide progression remains manual unless the current step explicitly
declares zone, item, key-item, or cutscene evidence; only the named evidence for
that selected step is polled.

## Local files

OddQ may create two text files below the active Ashita installation:

```text
config/addons/oddq/first-launch-seen.txt
config/addons/oddq/resume-state.txt
```

The marker records only that the addon has launched. Resume state records only
a bundled guide ID, clamped step number, Warp/No-Warp choice, Browser/Guide
view, and window-open flag. Unknown or malformed guide state fails closed.
Neither file contains live coordinates, chat, credentials, private messages,
or raw packet data.

## Reporting a security issue

Use the repository's private vulnerability-reporting channel when available.
Do not post credentials, private logs, or unredacted process output in a public
issue. Include the OddQ version, operating system, Ashita version, reproduction
steps, and a redacted description of the impact.

Security claims cover the shipped addon files, not
third-party launchers, the game client, Ashita itself, or external plugins.
