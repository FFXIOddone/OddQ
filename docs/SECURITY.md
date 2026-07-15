# OddQ Security

OddQ RC4 is a local, guidance-only Ashita addon. It is not gameplay automation
and does not require a companion process or server component.

## Runtime boundary

The shipped addon:

- renders a local guide browser, current-step view, pointer, and Settings;
- reads current zone, player position and heading, and level through Ashita's
  local APIs;
- reads bundled guide and target data; and
- writes only first-launch state and pointer preferences under Ashita's local
  `config/addons/oddq` directory.

The shipped addon does not:

- make network requests or load a bridge, backend, updater, or telemetry client;
- register packet handlers or inject, mutate, or send packets;
- issue movement, targeting, trading, combat, or addon-control commands;
- read or upload chat; or
- collect, store, or transmit account credentials.

## Fail-closed guidance

OddQ does not fabricate position data. If a step lacks an available exact coordinate,
it remains a zone/map checkpoint or a manual cue. If live position is
unavailable, the pointer cannot claim a direction or arrival. Guide progression
is manual.

## Local files

OddQ may create these text files below the active Ashita installation:

```text
config/addons/oddq/first-launch-seen.txt
config/addons/oddq/preferences.txt
```

They contain only first-launch state and display preferences. They must not
contain chat, credentials, private messages, or raw packet data.

## Reporting a security issue

Use the repository's private vulnerability-reporting channel when available.
Do not post credentials, private logs, or unredacted process output in a public
issue. Include the OddQ version, operating system, Ashita version, reproduction
steps, and a redacted description of the impact.

RC4 is a prerelease. Security claims cover the shipped addon files, not
third-party launchers, the game client, Ashita itself, or external plugins.
