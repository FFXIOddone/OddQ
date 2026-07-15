# OddQ

Clean, helpful quest and mission guidance for CatsEyeXI.

OddQ is an Ashita v4 addon that puts searchable mission, quest, unlock, item,
and route guidance into one in-game browser. Open it with `/odd`, choose a
category, and load the guide you need.

## Release status

`v0.1.0-rc2` is a public review candidate. The addon, generated guidance data,
safety manifests, checksums, and focused release evidence are ready for staff
review. Three optional Odd Server route-quality walks remain open, so this is a
prerelease rather than a stable claim.

## Install

Download the release zip and copy:

```text
Ashita/addons/oddq -> <Ashita>/addons/oddq
```

Then load and open it in game:

```text
/addon load oddq
/odd
```

No scripts, executables, DLLs, services, or server changes are required.

## Safety and privacy

OddQ is guidance-only. It does not move the player, target NPCs, trade, cast,
attack, follow, read chat, mutate packets, or automatically mark arrival.

- Incoming packet reads are passive and limited to declared mission/quest state.
- The optional route bridge is loopback-only (`127.0.0.1`) and fails closed when absent.
- Local files contain preferences, cached guidance, or explicit pilot evidence only.
- Command helpers are opt-in and restricted to allowlisted UI addons.
- Private-server test commands and helper scripts are excluded from public releases.

See `review/manifests` in the release zip for the generated packet, network,
filesystem, command, dependency, marker, and privacy disclosures.

## Useful commands

```text
/odd                       Open the guide browser
/odd <search>              Search and open a guide
/odd status                Show concise current guidance status
/odd close                 Close the UI
/odd help                  Show normal commands
/odd help advanced         Show reviewer and diagnostic commands
```

## Source and checks

The public repository contains the exact installable addon tree plus the
generated review manifests and current finish-gate evidence. Each release zip
also includes `MANIFEST.json` and `SHA256SUMS.txt` so reviewers can verify every
bundled file. LuaJIT compilation and the full automated suite are required by
the internal OddQ release gate.
