# Source References

OddQ ships normalized guide and target data inside the addon. The release does
not depend on a developer workstation, server checkout, raw wiki cache, or
network connection at runtime.

## Guide references

The current guide set uses these reference families:

- **BG-Wiki contributors** for retail quest and mission pages and public
  CatsEyeXI documentation hosted on BG-Wiki.
- **FFXIclopedia contributors** for cross-checks and source links on selected
  guides.
- Structured CatsEyeXI-compatible zone, NPC, and target records normalized
  during development for coordinate and checkpoint lookup.
- Project-authored curation that turns source facts into categories, step
  boundaries, search aliases, and source-backed map/location labels.

Where available, generated objective records retain a `source_url`. A source
URL is attribution metadata; the addon does not fetch it at runtime.

See the repository `NOTICE.md` and `docs/BG_WIKI_CACHE.md` for the scoped
attribution and BG-Wiki license metadata. Source-site terms continue to apply to
their content. This document does not choose or grant a license for OddQ source
code.

## Regeneration rule

Data regeneration must preserve source attribution and must not replace an
unknown coordinate or map number in structured source data. The UI temporarily
displays `Map #1` when a grid has no recorded page, but the underlying map field
remains unset. CatsEyeXI-specific facts stay distinguishable from retail
reference material, and manual curation stays identifiable as such.
