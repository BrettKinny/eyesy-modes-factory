# Research corpus — factory ports

The two dossiers a port of the stock Critter & Guitari library needs. They were
tracked in the `eyesy` engine repo until the mode collections were split out.

| Dossier | What it grounds |
| --- | --- |
| `EyesyEcosystemMiner.md` | The whole EYESY mode ecosystem mapped and assessed for port viability: `EYESY_OS`, `EYESY_Modes_OSv3`, `EYESY_Modes_Pygame`, `EYESY_OF`, `EYESY_oFLua_Examples`, pysey, and PatchStorage's 209-entry platform. Establishes the three API generations this repo has to bridge |
| `PatchStorageBestOf.md` | Ranked best-of-community port specs, with view/like/download data and the shared pygame idiom (100-sample audio, spring-damped RMS envelope, the veil, `eyesy.trig`) worked out explicitly |

Both were verified against live sources; `PatchStorageBestOf.md` notes which
candidates were judged *not* worth porting and why.

Path conventions: `modes/<name>/...` resolves under this repo's mode folders
once `./eyesyctl modes sync` has assembled them; `docs/API.md`,
`docs/SCENE-LIBRARY.md`, `01-architecture.md` and `eyesyctl` refer to the
`eyesy` engine repo, where `01-architecture.md` documents how the stock engine,
mode API and hardware layer work.