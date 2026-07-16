# OddQ Security

OddQ v1.0.0 is a local, guidance-only Ashita addon. It is not gameplay automation
and does not require a companion process or server component.

## Runtime boundary

The shipped 13-file addon:

- renders a local Guide Browser and Guide in one shared window;
- reads bundled guide data; and
- writes only a first-launch marker under Ashita's local
  `config/addons/oddq` directory.

The shipped addon does not:

- inspect or track player zone, position, heading, level, or activity;
- ship a Pointer window, Settings popup, or player-state module;
- make network requests or load a bridge, backend, updater, or telemetry client;
- register packet handlers or inject, mutate, or send packets;
- issue movement, targeting, trading, combat, or addon-control commands;
- read or upload chat; or
- collect, store, or transmit account credentials.

## Fail-closed guidance

OddQ does not fabricate position data or write fallback map values into source
data. A source-backed map number appears beside the objective grid. When a grid
is known but its map number is not established, the UI temporarily displays
`Map #1`. Guide progression remains manual.

## Local files

OddQ may create one text file below the active Ashita installation:

```text
config/addons/oddq/first-launch-seen.txt
```

It records only that the addon has launched. OddQ does not create a preferences
file, and the marker must not contain chat, credentials, private messages, or
raw packet data.

## Reporting a security issue

Use the repository's private vulnerability-reporting channel when available.
Do not post credentials, private logs, or unredacted process output in a public
issue. Include the OddQ version, operating system, Ashita version, reproduction
steps, and a redacted description of the impact.

Security claims cover the shipped addon files, not
third-party launchers, the game client, Ashita itself, or external plugins.
