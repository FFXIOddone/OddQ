# OddQ Review Guide

This is the fast path for reviewing OddQ without spelunking through source first.

## Entry Points

- Build plan: `docs/plans/2026-05-03-odd-build-plan.md`
- Slice guide: `docs/plans/2026-05-03-oddq-slice-by-slice-guide.md`
- Security stance: `docs/SECURITY.md`
- Review contract: `tools/oddq_review/review_contract.json`
- Review generator: `tools/oddq_review/review_tool.py`
- Hosted profile: `docs/CATSEYEXI_HOSTED.md`
- Hosted manifest builder: `tools/Odd.ManifestBuilder/manifest_builder.py`

## Commands

```powershell
python -m tools.oddq_workflow
python -m unittest discover tests -v
python -m tools.oddq_review.review_tool --contract tools/oddq_review/review_contract.json --docs docs --markers-root .
python tools/Odd.ManifestBuilder/manifest_builder.py --contract tools/oddq_review/review_contract.json --docs docs --markers-root .
python -m tools.oddq_release --root . --version 0.1.0-rc2 --force
rg -F "ODD_CXI_" .
rg -F "ODD_NETWORK_CALL" .
rg -F "ODD_PACKET_READ" .
rg -F "ODD_FILE_WRITE" .
rg -F "ODD_SECURITY_NOTE" .
```

## Generated Files

- `docs/GENERATED_NETWORK_MANIFEST.json`
- `docs/GENERATED_PACKET_MANIFEST.json`
- `docs/GENERATED_FILESYSTEM_MANIFEST.json`
- `docs/GENERATED_COMMAND_MANIFEST.json`
- `docs/GENERATED_DEPENDENCY_MANIFEST.json`
- `docs/GENERATED_BENCHMARK_REPORT.md`
- `docs/GENERATED_PRIVACY_REPORT.md`
- `docs/GENERATED_AUDIT_REPORT.json`
- `docs/GENERATED_SCHEMA_VALIDATION.json`
- `docs/GENERATED_CXI_MARKERS.json`

## Release Artifact

`python -m tools.oddq_release --root . --version 0.1.0-rc2 --force` writes
`build/release/oddq-v0.1.0-rc2.zip`. The archive contains only the installable
`Ashita/addons/oddq` tree, `MANIFEST.json`, `SHA256SUMS.txt`, focused release
evidence, and a small reviewer-manifest set. It excludes development and
private-server helper scripts, internal planning/checkpoint files, raw runtime
captures, backups, executables, and unrelated OddAPI/OddG material.

## Pilot Evidence

Live pilot evidence is generated from `reports/pilot/session.jsonl` with:

```powershell
python -m tools.Odd.PilotRecorder.pilot_report --input reports/pilot/session.jsonl --reports reports/pilot
```

The JSONL contains route metrics, manual tester result notes, frame samples, and Lua memory measurements only. It must not contain chat logs, credentials, raw packet dumps, movement commands, target commands, trade commands, or packet mutations.

## Current Review Notes

This early contract pack declares the intended network calls, commands, cache writes, privacy counters, and sample route payloads before runtime code exists. Any later network call, packet read, file write, or command should be added to the review contract or generated manifests in the same slice as the code.
