# Research corpus — factory ports

The two dossiers a port of the stock Critter & Guitari library needs. They were
tracked in the `eyesy` engine repo until the mode collections were split out.

| Dossier | What it grounds |
| --- | --- |
| `CoverageMatrix.md` | The merged have/missing verdict over every enumerated source: 406 distinct modes, what we already ship (5 derived scenes), the 401-mode gap list with licences, and the portability gates. Built from `inventory/` |
| `EyesyEcosystemMiner.md` | The whole EYESY mode ecosystem mapped and assessed for port viability: `EYESY_OS`, `EYESY_Modes_OSv3`, `EYESY_Modes_Pygame`, `EYESY_OF`, `EYESY_oFLua_Examples`, pysey, and PatchStorage's 209-entry platform. Establishes the three API generations this repo has to bridge |
| `PatchStorageBestOf.md` | Ranked best-of-community port specs, with view/like/download data and the shared pygame idiom (100-sample audio, spring-damped RMS envelope, the veil, `eyesy.trig`) worked out explicitly |
| `inventory/` | Machine-readable per-source enumeration (patchstorage, github-stock, pysey, community, local) plus the merged `coverage.csv`/`coverage.json`. Regenerable from `tools/inventory/*.py`; see `inventory/README.md` |

The dossiers were verified against live sources; `PatchStorageBestOf.md` notes
which candidates were judged *not* worth porting and why, and `CoverageMatrix.md`
records the same decisions as machine-readable verdicts
(`inventory/verdicts.json`).

Path conventions: `modes/<name>/...` resolves under this repo's mode folders
once `./eyesyctl modes sync` has assembled them; `docs/API.md`,
`docs/SCENE-LIBRARY.md`, `01-architecture.md` and `eyesyctl` refer to the
`eyesy` engine repo, where `01-architecture.md` documents how the stock engine,
mode API and hardware layer work.