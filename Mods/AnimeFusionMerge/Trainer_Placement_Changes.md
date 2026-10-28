# Changes To Make — Placing the 150 Merged DBZ Trainers

Read [RMXP_Walkthrough.md](RMXP_Walkthrough.md) first for how to actually clone/place an event. This doc is the per-trainer worklist. Work map-by-map (open one map, knock out every row for it, save, move on).

For every row below: **clone the existing trainer event**, place the clone as described, then edit only the clone's Script command — change the `trainerPartyID` argument (5th positional number in `pbTrainerBattle(:TYPE,"Name",...,version)`) to the version shown. Leave TrainerType/Name untouched.

## Section A — single new version, straightforward (place one clone per row)

| Map | Existing trainer (event / x,y / movement) | Place new clone... | Set version to |
|---|---|---|---|
| 542 Celadon City Gym | Bridget (5, 25,19, Fixed) | adjacent tile | 900 |
| 542 Celadon City Gym | Tamia (2, 26,11, turns toward player) | adjacent tile | 900 |
| 542 Celadon City Gym | Mary (6, 15,19, Fixed) | adjacent tile | 900 |
| 542 Celadon City Gym | Lisa (4, 26,26, Fixed) | adjacent tile | 900 |
| 542 Celadon City Gym | Martine (7, 5,18, turns toward player) | adjacent tile | 900 |
| 542 Celadon City Gym | Tina (1, 3,21, Fixed) | adjacent tile | 900 |
| 542 Celadon City Gym | Erika (9, 12,13, Fixed) — gym leader | adjacent tile | 900 |
| 191 Fighting Dojo | Hideki (7, 19,23, Fixed) | adjacent tile | 900 |
| 191 Fighting Dojo | Hitoshi (4, 11,26, Fixed) | adjacent tile | 900 |
| 191 Fighting Dojo | Lucy (6, 11,23, Fixed) | adjacent tile | 900 |
| 191 Fighting Dojo | Yoshimi (5, 19,26, Fixed) | adjacent tile | 900 |
| 8 Route 24 | Cale (1, 18,41, Fixed) | adjacent tile | 900 |
| 8 Route 24 | Joey (6, 41,15, patrols) | end of patrol route, stationary | 900 |
| 495 Route 9 | Conner (7, 31,12, turns in place) | adjacent tile | 900 |
| 495 Route 9 | Brice (10, 36,20, Fixed) | adjacent tile | 900 |
| 490 Route 3 | James (10, 27,12, Fixed) | adjacent tile | 900 |
| 490 Route 3 | Sally (8, 15,8, Fixed) | adjacent tile | 900 |
| 490 Route 3 | Janice (9, 31,6, Fixed) | adjacent tile | 900 |
| 490 Route 3 | Ben (6, 12,4, Fixed) | adjacent tile | 900 |
| 491 Viridian Forest | Rick (12, 34,14, Fixed) | adjacent tile | 900 |
| 491 Viridian Forest | Lana (11, 9,12, turns toward player) | adjacent tile | 900 |
| 221 Cinnabar Island Gym | Ramon (27, 16,13, Fixed) | adjacent tile | 900 |
| 221 Cinnabar Island Gym | Ramon (28, 14,13, Fixed) | adjacent tile | 900 |
| 221 Cinnabar Island Gym | Ramon (36, 13,13, Fixed) | adjacent tile | 900 |
| 221 Cinnabar Island Gym | Blaine (2, 14,4, Fixed) — gym leader | adjacent tile | 900 |
| 187 Pokémon Mansion | Simon (19, 40,16, turns toward player) | adjacent tile | 900 |
| 181 Pokémon Mansion (different floor than 187) | Ivan (23, 35,17, Fixed) | adjacent tile | 900 |
| 386 Pewter City Gym | Liam (2, 7,11, Fixed) | adjacent tile | 900 |
| 403 Pokemon Tower F4 | Carrietta (6, 4,6, Fixed) | adjacent tile | 900 |
| 403 Pokemon Tower F4 | Morgan (7, 13,6, patrols) | end of patrol route, stationary | 900 |
| 468 Pokemon Tower F6 | Emilia (6, 8,7, Fixed) | adjacent tile | 900 |
| 468 Pokemon Tower F6 | Jennifer (7, 12,13, turns toward player) | adjacent tile | 900 |
| 467 Pokemon Tower F5 | Karina (6, 17,10, Fixed) | adjacent tile | 900 |
| 467 Pokemon Tower F5 | Ruth (8, 5,6, turns in place) | adjacent tile | 900 |
| 467 Pokemon Tower F5 | Carol Anne (9, 12,4, Fixed) | adjacent tile | 900 |
| 467 Pokemon Tower F5 | Regan (7, 4,13, turns toward player) | adjacent tile | 900 |
| 316 Elite 2 | Bruno (1, 10,9, Fixed) | adjacent tile | 900 |
| 318 Elite 4 | Lance (3, 10,9, Fixed) | adjacent tile | 900 |
| 315 Elite 1 | Lorelei (5, 10,9, Fixed) | adjacent tile | 900 |
| 24 & 61 Vermillion City Gym *(see caution below — likely duplicate maps, consider doing only one)* | Baily (4, 5,17, Fixed) | adjacent tile, on both maps | 900 |
| 24 & 61 Vermillion City Gym | Tucker (7, 14,19, turns randomly) | adjacent tile, on both maps | 900 |
| 24 & 61 Vermillion City Gym | Dwayne (6, 12,15, Fixed) | adjacent tile, on both maps | 900 |
| 24 & 61 Vermillion City Gym | Lt. Surge (2, 9,6, Fixed) — gym leader | adjacent tile, on both maps | 900 |
| 155 Route 11 | Bernie (12, 36,18, short down/up patrol) | end of patrol route, stationary | 900 |
| 159 Route 12 | Elliot (38, 38,52, Fixed) | adjacent tile | 900 |
| 159 Route 12 | Ned (1, 36,25, turns toward player) — 2nd Ned | adjacent tile | 900 |
| 36 SS. Anne | Ned (8, 43,16, Fixed) — 1st Ned | adjacent tile | 900 |
| 564 Brine Road | Tommy (31, 64,24, turns left/down) | adjacent tile | 900 |
| 564 Brine Road | Raphael (35, 72,30, Fixed) | adjacent tile | 900 |
| 254 Route 35 | Kim (16, 19,29, patrols up/down) | end of patrol route, stationary | 900 |
| 254 Route 35 | Kim (15, 22,36, turns toward player) — 2nd Kim event | adjacent tile | 900 |
| 349 Rock Tunnel | Ariana (11, 54,33, Fixed) | adjacent tile | 900 |
| 647 Magogany Town Gym | Martin (6, 12,12, tiny loop) | end of loop, stationary | 900 |
| 647 Magogany Town Gym | Maurice (10, 21,17, tiny loop) | end of loop, stationary | 900 |
| 647 Magogany Town Gym | Sidney (9, 23,13, tiny loop) | end of loop, stationary | 900 |
| 647 Magogany Town Gym | Wayne (14, 7,12, tiny loop) | end of loop, stationary | 900 |
| 286 Union Cave B1 | Larry (7, 16,31, tiny loop) | end of loop, stationary | 900 |
| 12 Route 5 | Maude (9, 9,7, Fixed) | adjacent tile | 900 |
| 600 Bond Bridge | Jane (23, 81,40, Fixed) | adjacent tile | 900 |
| 600 Bond Bridge | Jane (21, 69,35, small loop) — 2nd Jane event | end of loop, stationary | 900 |
| 600 Bond Bridge | Osman (22, 62,30, turns toward player) | adjacent tile | 900 |
| 600 Bond Bridge | Steve (1, 81,30, Fixed) | adjacent tile | 900 |
| 479 Fuchsia City Gym | Kayden (5, 20,7, paces down/up) | end of patrol, stationary | 900 |
| 479 Fuchsia City Gym | Kirk (7, 5,5, paces down/up) | end of patrol, stationary | 900 |
| 479 Fuchsia City Gym | Nate (6, 16,7, Fixed) | adjacent tile | 900 |
| 479 Fuchsia City Gym | Shawn (8, 7,7, paces down/up) | end of patrol, stationary | 900 |
| 479 Fuchsia City Gym | Edgar (9, 16,5, turns) | adjacent tile | 900 |
| 479 Fuchsia City Gym | Phil (10, 11,8, turns) | adjacent tile | 900 |
| 479 Fuchsia City Gym | Koga (1, 13,9, Fixed) — gym leader | adjacent tile | 900 |
| 85 Viridian City Gym | Giovanni (92, 9,7, Fixed) | adjacent tile | 900 |
| 378 Mewtwo Intro | Giovanni (17, 0,7, Fixed) — 2nd Giovanni event | adjacent tile | 900 |
| 546 Fighting Arena | Blaine (29, 20,10, turns toward player) | adjacent tile | 900 |
| 546 Fighting Arena | Erika (26, 14,10, turns toward player) | adjacent tile | 900 |
| 546 Fighting Arena | Giovanni (30, 22,10, turns toward player) | adjacent tile | 900 |
| 546 Fighting Arena | Koga (27, 16,10, turns toward player) | adjacent tile | 900 |
| 546 Fighting Arena | Misty (24, 10,10, turns toward player) | adjacent tile | 900 |
| 546 Fighting Arena | Lt. Surge (25, 12,10, turns toward player) | adjacent tile | 900 |
| 4 Cerulean City Gym | Misty (3, 9,8, Fixed) — gym leader | adjacent tile | 900 |
| 105 Mt. Moon B2F | Francis (13, 33,10, Fixed) | adjacent tile | 900 |
| 431 Celadon Sewers | Virginia (41, 28,19, Fixed) | adjacent tile | 900 |
| 431 Celadon Sewers | Kaitlin (43, 37,18, Fixed) | adjacent tile | 900 |
| 431 Celadon Sewers | Joffrey (36, 7,17, Fixed) | adjacent tile | 900 |
| 431 Celadon Sewers | Omar (44, 41,18, Fixed) | adjacent tile | 900 |
| 431 Celadon Sewers | Max (46, 25,22, Fixed) | adjacent tile | 900 |
| 431 Celadon Sewers | Paul (40, 2,9, Fixed) | adjacent tile | 900 |
| 431 Celadon Sewers | Phillip (39, 6,9, Fixed) | adjacent tile | 900 |
| 446 Celadon Sewers *(2nd sewers map — same grunts appear here too)* | Kaitlin (26, 37,18, Fixed) | adjacent tile | 900 |
| 446 Celadon Sewers | Joffrey (24, 28,19, turns toward player) | adjacent tile | 900 |
| 446 Celadon Sewers | Omar (27, 41,18, Fixed) | adjacent tile | 900 |
| 446 Celadon Sewers | Max (23, 23,22, turns toward player) | adjacent tile | 900 |
| 446 Celadon Sewers | Paul (28, 2,9, Fixed) | adjacent tile | 900 |
| 446 Celadon Sewers | Phillip (29, 6,9, Fixed) | adjacent tile | 900 |
| 15 Northern Gate | Dennis (9, 1,6, Fixed) | adjacent tile | 900 |
| 18 Southern Gate | Dennis (8, 1,8, Fixed) | adjacent tile | 900 |
| 66 Eastern Gate | Dennis (5, 6,12, Fixed) | adjacent tile | 900 |
| 66 Eastern Gate | Dennis (1, 6,11, Fixed) — 2nd event | adjacent tile | 900 |
| 66 Eastern Gate | Dennis (4, 11,14, Fixed) — 3rd event | adjacent tile | 900 |
| 415 Western Gate | Dennis (4, 12,11, Fixed) | adjacent tile | 900 |
| 108 Saffron City | Cyrus (60, 42,16, Fixed) — double-battle partner | adjacent tile | 900 |
| 118 debug | Cyrus (23, 4,13, Fixed) — on a dev "debug" map, probably skip | — | skip |
| 57 Route 19 | Reece (7, 13,21, tiny loop) | end of loop, stationary | 900 |
| 57 Route 19 | Richard (5, 10,27, small loop) | end of loop, stationary | 900 |
| 559 Kindle Road | Abigail (36, 20,93, turns) | adjacent tile | 900 |
| 409 Route 8 | Glenn (12, 46,12, turns) | adjacent tile | 900 |
| 17 S.S. Anne | Miguel (11, 3,11, Fixed) | adjacent tile | 903 *(see Section B)* |
| 105 Mt. Moon B2F | Miguel (7, 6,5, Fixed) | adjacent tile | 904 *(see Section B)* |
| 105 Mt. Moon B2F | Miguel (37, 15,14, Fixed) — 2nd Miguel event | adjacent tile | 905 *(see Section B)* |
| 342 Ruins of Alph | Miguel (27, 18,16, Fixed) | adjacent tile | 906 *(see Section B)* |
| 406 Celadon Café | Miguel (5, 10,9, Fixed) | adjacent tile | 900 *(see Section B)* |

## Section B — trainers with more than one new version (needs a quick decision)

These trainers have **multiple new alt parties**, not just one. There's no data telling us which party goes with which physical location — you get to decide. A reasonable default is used above/below (lowest version → first location alphabetically), but swap them around if you'd prefer a different pairing (e.g. tougher party at a later route).

- **SUPERNERD, Miguel** — versions **900, 903, 904, 905, 906** across the 5 Miguel locations listed in Section A. (Versions 901–902 don't exist for Miguel — not a mistake, DBZ's source file simply didn't have them.)
- **LEADER_Brock** — versions **900, 901**. Two Brock locations exist: 386 Pewter City Gym (Fixed, main gym battle) and 546 Fighting Arena (turns toward player). Suggest: 900 at Pewter, 901 at Fighting Arena — swap if you'd rather the Fighting Arena rematch be the "first" version.

## Section C — Blue: recommend NOT physically cloning (open decision)

- **CHAMPION, Blue** has **9** new versions (900–908), all pointing at the same single location (map 328 "Champion", where Blue already has 2 event instances for an entry cutscene). Nine near-duplicate physical Blue clones standing on the Champion's room floor doesn't make sense.
- **RIVAL1, Blue** has **24** new versions (900–923) across roughly 17 existing Blue encounters spread through the story (Cerulean, Route 22 x6, S.S. Anne x4, Pokemon Tower, Fuchsia, Mt. Silver, etc.) — again far more versions than locations.
- This project already has a rematch-progression system (`Data/Scripts/053_PIF_Hoenn/TrainerRematches/03_TrainerRematch_System.rb`) that calls `pbTrainerBattle` with an escalating `trainerPartyID` as the player re-fights a trainer. These 33 Blue versions look like they're meant to feed **that** system (one party per rematch tier) rather than become 33 separate map NPCs.
- **Recommendation:** don't place new Blue NPCs from this merge. Instead, wire versions 900–908 (Champion) and 900–923 (Rival) into the existing rematch system as its escalating tiers. I can help with that once you confirm this is what you want — it's a script change, not a map-placement change.

## Section D — no existing overworld analog (nothing to clone from)

These need a brand-new event placed wherever makes sense to you — there's no original NPC to copy:

- **CHANNELER, Angelica** (exists in `PBS/trainers.txt` as text only, no map event anywhere — even the original was never placed)
- **27 new trainers**: BEAUTY,Olivia · BUGCATCHER,Nelson · BURGLAR,Jamal · COOLTRAINER_F,Rike · FISHERMAN,Dale · HAUNTEDGIRL,Samara · HIPSTER,Jerry (×2 parties, versions 0 and 1) · LASS,Ali · LASS,Haley · LASS,Marina · LASS,Reli · PICNICKER,Diana · POKEMANIAC,Guy · ROBOT,KILLBOT · ROBOT,RED · ROCKETEXEC_F,Ariana · ROCKETEXEC_M,Archer · TEAMROCKET_M,Ritchie · TEAMROCKET_M,Sam · WORKER,Angus · WORKER,Felix · WORKER,Hermann · WORKER,John · WORKER,Kevin · WORKER,Mark · WORKER,Silvio

For a brand-new event's Script command (no existing one to clone), use:
```
pbTrainerBattle(:TRAINERTYPE,"Name",_INTL("Your end speech here."),false,VERSION)
```
(`VERSION` is `0` for entries with no version shown above, `1` for the second HIPSTER,Jerry entry.)
