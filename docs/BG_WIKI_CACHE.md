# BG-Wiki Data Provenance

OddQ uses BG-Wiki as a reference for retail quest and mission facts and for
public CatsEyeXI documentation hosted there.

During development, source pages are normalized into compact guide records.
The runtime release contains those guide records, not the raw wiki cache, and
does not contact BG-Wiki.

Development cache metadata records the source URL, page revision, retrieval
time, content hash, attribution, and license metadata. Generated records should
preserve a `source_url` where one is available so reviewers can trace a guide
back to its reference page.

The cache tooling identifies BG-Wiki's non-Square Enix content as
`CC BY-NC-SA 3.0` and attributes it to **BG Wiki contributors**:

- Source: <https://www.bg-wiki.com/ffxi/Main_Page>
- License: <https://creativecommons.org/licenses/by-nc-sa/3.0/>

This page documents guide-data provenance only. It does not establish a license
for OddQ source code or for third-party game content.
