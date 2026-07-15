# CatseyeXI Hosted Profile

`CATSEYEXI_HOSTED` is the staff-safe OddQ distribution profile. It keeps every hosted endpoint and public key as an `ODD_CXI_REPLACE_*` marker until CatseyeXI staff supplies the approved values.

## Required Replace Markers

- `ODD_CXI_REPLACE_SERVER_NAME`
- `ODD_CXI_REPLACE_API_BASE_URL`
- `ODD_CXI_REPLACE_ROUTE_ENDPOINT`
- `ODD_CXI_REPLACE_MANIFEST_ENDPOINT`
- `ODD_CXI_REPLACE_ALLOWED_HOSTNAMES`
- `ODD_CXI_REPLACE_PUBLIC_SIGNING_KEY`
- `ODD_CXI_REPLACE_PRIVACY_POLICY_URL`
- `ODD_CXI_REPLACE_SUPPORT_URL`
- `ODD_CXI_REPLACE_DATA_RETENTION_DAYS`
- `ODD_CXI_REPLACE_ENABLE_PATH_INGEST`
- `ODD_CXI_REPLACE_ENABLE_AUTO_UPDATE_CHECK`

## Endpoint Lockout

The hosted distribution template must not bake in third-party API URLs, analytics URLs, or fallback route servers. Local addon-to-bridge traffic may use `127.0.0.1`; external bridge-to-backend route and manifest URLs must remain `ODD_CXI_REPLACE_*` values in source review artifacts.

At runtime, the bridge uses its configured hostname allowlist and HTTPS-only endpoint checks. Non-allowlisted hosts are rejected and logged as `rejected_endpoint`.

## Generated Review Bundle

Regenerate the hosted review bundle with:

```powershell
python tools/Odd.ManifestBuilder/manifest_builder.py --contract tools/oddq_review/review_contract.json --docs docs --markers-root .
```

The bundle includes:

- `docs/GENERATED_NETWORK_MANIFEST.json`
- `docs/GENERATED_PACKET_MANIFEST.json`
- `docs/GENERATED_FILESYSTEM_MANIFEST.json`
- `docs/GENERATED_COMMAND_MANIFEST.json`
- `docs/GENERATED_DEPENDENCY_MANIFEST.json`
- `docs/GENERATED_BENCHMARK_REPORT.md`
- `docs/GENERATED_PRIVACY_REPORT.md`
- `docs/GENERATED_AUDIT_REPORT.json`
- `docs/GENERATED_CXI_MARKERS.json`

## Reproducible Build

From a clean checkout:

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
python -m unittest discover tests -v
python tools/Odd.ManifestBuilder/manifest_builder.py --contract tools/oddq_review/review_contract.json --docs docs --markers-root .
dotnet test
dotnet publish bridge/Odd.Bridge/Odd.Bridge.csproj -c Release -o build/CATSEYEXI_HOSTED/bridge
dotnet publish backend/Odd.Api/Odd.Api.csproj -c Release -o build/CATSEYEXI_HOSTED/backend
```

Before approval packaging, staff should run:

```powershell
rg -F "ODD_CXI_REPLACE_" .
```

Only CatseyeXI-owned deployment values should replace those markers.
