# Multiverse Hub Full-Playthrough Tracker

Multi-day/multi-week project: play each of the 53 games reachable from the in-game PC's
"Change Game" menu all the way through, fixing real bugs as found. Started 2026-09-26.

## How to launch a playtest session (never touches the user's real saves)

Real saves live at `C:\Users\nicko\AppData\Roaming\infinitefusion\File {A,B,C,D}.rxdata` —
**never read/write these.** `Mods/PlaytestSaveIsolation` redirects `SaveData::SAVE_DIR` but
only when an env var is set, so normal launches (double-clicking the exe/shortcut) are
unaffected.

Before launching the game for a playtest, set:
```
GBAWORLD_PLAYTEST_SAVEDIR=C:\Users\nicko\AppData\Roaming\infinitefusion_playtest
```
Then launch the game normally. Confirm the mod's boot line
`[PlaytestSaveIsolation] Saves redirected to ...` appears. Use **save slot 5** (user's
choice) in that isolated folder for the run.

## Known issues found, not yet fixed/decided

- **Animon key collision**: base `Mods/MultiverseHub/main.rb` hardcodes
  `GAMES[:animon]` = old hand-built gauntlet (map 9501). `Mods/AnimonPort` (real ROM port,
  map 70001) also registers `GAMES[:animon]` and loads later, silently winning. Today the
  "Animon" PC menu entry goes to the new full-ROM port; the old gauntlet is orphaned
  (unreachable from the menu, still technically registered). Need user decision: keep new
  port as "Animon" and give the old gauntlet its own separate menu entry/name, or something
  else. Not fixed yet.

- **DigimonGreyPort charset bug**: that ROM is Chinese-patched; its custom charmap bytes
  aren't fully covered by the pipeline's Gen3 charmap, so many species names decode as
  near-empty garbled strings. This causes 40 duplicate `[dex_id]` PBS section headers in
  `Mods/DigimonGreyPort/pokemon.txt` (e.g. `[603238]` x37) — later duplicates likely
  overwrite earlier ones at compile time, so some Grey Digimon may be silently losing data.
  Not fixed yet; needs reverse-engineering Grey's custom charmap. Low urgency until Grey's
  slot comes up in the rotation (#4 below).

- **computer-use can't reach the game window**: `request_access` resolves app names against
  the Windows Start Menu index, and `InfiniteFusion` (a standalone/portable exe, not
  Start-Menu-installed) is confirmed absent from that index — this isn't a naming guess
  problem, the app fundamentally isn't registered anywhere `request_access` looks. Blocks
  computer-use-driven playtesting until either a Start Menu shortcut is created for it or
  another interaction method is used. Needs user input/action.

## Status legend
NS = not started, IP = in progress, DONE = completed, BLOCKED = genuine blocker hit

## Game checklist (53 total: 51 gba_world ROM ports + PIF2 + DBZ Infinite Fusion)

| # | Game key | Status | Notes |
|---|----------|--------|-------|
| 1 | Animon | NS | see key-collision issue above |
| 2 | DbzKakarot | NS | |
| 3 | DigimonEscapeServerIsland | NS | |
| 4 | DigimonGrey | NS | |
| 5 | DigimonOperationDigipedia | NS | |
| 6 | AlteRed | NS | |
| 7 | DarkRisingOrigins | NS | |
| 8 | Fusion3RedBlue | NS | |
| 9 | YugiohPokeduel | NS | |
| 10 | DigimonNovaRed | NS | |
| 11 | DigimonGbaFinal | NS | |
| 12 | DigimonEmeraldProject | NS | |
| 13 | DigimonVirusDemo | NS | |
| 14 | DigimonFireRed2020 | NS | |
| 15 | DigimonNewWorld | NS | |
| 16 | DbzTeamTrainingV92 | NS | |
| 17 | DbzTeamTraining11 | NS | |
| 18 | SuperMariomon | NS | |
| 19 | PokemonMonsterHunterEmerald | NS | |
| 20 | MegaMoemon | NS | |
| 21 | Spectrobes | NS | |
| 22 | Kosmo | NS | |
| 23 | PokemonMeetsFinalFantasy | NS | |
| 24 | MoemonFireRedRevival | NS | |
| 25 | MoemonAshgray | NS | |
| 26 | MoemonQuetzal | NS | |
| 27 | MoemonBonds | NS | |
| 28 | PokemonMarioRed | NS | |
| 29 | Moemon3rdxExtremeBattlers | NS | |
| 30 | MoemonMystical | NS | |
| 31 | PokemonFusedDimensions | NS | |
| 32 | Sonicmon | NS | |
| 33 | PokemonLuigiGreen | NS | |
| 34 | NsansBetaAttashura | NS | |
| 35 | NarutoRuby | NS | |
| 36 | PokemonCrown | NS | |
| 37 | PokemonForbiddenMemories | NS | |
| 38 | PokefangRed | NS | |
| 39 | Pokemetroid | NS | |
| 40 | PokemonLegendsKingdomHearts | NS | |
| 41 | PokemonEmeraldOmniverse | NS | |
| 42 | PokemonGantz | NS | |
| 43 | PokemonPaperMarioRedux | NS | |
| 44 | PokemonFusionOrigins | NS | |
| 45 | PokemonOmniversalEmerald | NS | |
| 46 | PokemonNaruto | NS | |
| 47 | SmashmonsSpiritRed | NS | |
| 48 | PokemonUltimateFusion | NS | |
| 49 | Pokeverse | NS | |
| 50 | PokemonMultiverseBattle | NS | |
| 51 | PokemonMugiwara | NS | |
| 52 | PIF2 (Infinite Fusion 2) | NS | |
| 53 | DBZ Infinite Fusion | NS | |

## Session log
- 2026-09-26: Built save-isolation mod + this tracker. No playtesting started yet.
- 2026-09-26: First game boot after adding the save-isolation mod triggered a full PBS
  recompile across all 51+ mods (normal at this scale, confirmed via climbing CPU time, not
  a hang) — still finishing. Found computer-use can't attach to the game window (see known
  issues). Separately investigated the Digimon evolution-method/species-matching "full
  effort" ask: species matching already works well via an existing mechanism (no fix
  needed); real per-ROM evolution-method decoding turns out much bigger/lower-confidence
  than expected (see memory: project_digimon_evolution_crossref_investigation) — paused
  pending user decision. Found the DigimonGreyPort charset bug along the way (logged above).
