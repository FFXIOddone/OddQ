# OddQ Security

OddQ is guidance software for quest, mission, and route help. It is not gameplay automation.

## Public Promise

OddQ does not automate gameplay.
OddQ does not control your character.
OddQ does not send chat logs.
OddQ does not send account credentials.
OddQ does not modify packets.
OddQ only sends the minimum state needed to calculate route guidance.
In CatseyeXI-hosted mode, OddQ communicates only with CatseyeXI-configured servers.

## Runtime Boundary

The Ashita addon renders guidance, reads approved live game state, and talks only to the local bridge. The local bridge owns network policy, endpoint allowlists, route-response validation, local cache writes, and audit logs.

## Network Policy

CatseyeXI-hosted builds must use `ODD_CXI_REPLACE_API_BASE_URL`, `ODD_CXI_REPLACE_ROUTE_ENDPOINT`, and `ODD_CXI_REPLACE_MANIFEST_ENDPOINT` values supplied by CatseyeXI staff. No fallback server, analytics endpoint, or third-party route source is allowed in that mode.

## Packet Policy

OddQ may later observe specific read-only packet fields for quest evidence. Those reads must appear in `docs/GENERATED_PACKET_MANIFEST.json`. Packet mutation, packet injection, and automatic gameplay commands are out of scope.

## Filesystem Policy

OddQ may write local route cache and audit logs under `%APPDATA%/OddQ/`. These files must not contain chat logs, account credentials, raw packet dumps, or private messages.
