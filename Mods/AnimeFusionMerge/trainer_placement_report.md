# Trainer Placement Investigation

## Method

1. Extracted all 150 entries from `Mods/AnimeFusionMerge/trainers.txt`, compared TrainerType+Name against the base `PBS/trainers.txt` roster: **87 unique "alt" pairs** (already exist in base roster → placed on a live map) and **27 unique "new" pairs** (no analog).
2. Found the compiled trainer-event convention in `Data/Scripts/021_Compiler/004_Compiler_MapsAndEvents.rb` (`convert_to_trainer_event`, ~line 419-556): PBS-style `Type:`/`Name:`/`Battle:` comments get compiled into an event Script command literally containing `pbTrainerBattle(:TRAINERTYPE,"Name", ...)` or `pbTrainerBattle(PBTrainers::TRAINERTYPE,"Name", ...)` (older constant-style), or `pbDoubleTrainerBattle(...)` for double-battle partners. Since `Data/Map*.rxdata` is already compiled, this text is directly grep-able inside the Marshal binary.
3. Grepped all 746 `Map*.rxdata` for `pbTrainerBattle(`/`pbDoubleTrainerBattle(` calls (974 total), matched against the 87 alt pairs → found 86 of 87 across 68 candidate map files (only `CHANNELER,Angelica` had zero hits anywhere).
4. Built Ruby 3.1 stub classes (`Table._load` with the standard `int32 dim,x,y,z,total`+int16 payload format, `RPG::Map`, `RPG::Event`/`Page`/`Condition`/`Graphic`, `RPG::MoveRoute`, `RPG::MoveCommand`, `RPG::EventCommand`, `Color`, `Tone`, `AudioFile`, `RPG::MapInfo`) sufficient to `Marshal.load` these files read-only. Tested on 3 maps first (zero errors), then ran across all 68 target maps (zero errors).
5. For map display names: `if1_locs.txt` only covers about half the needed map IDs (it's a partial/curated list), so `Data/MapInfos.rxdata`'s `name` field (the actual name shown in RPG Maker XP's map tree) was used as primary, cross-checked against `if1_locs.txt` where available — they always agreed.

**Movement key**: `Fixed` = stationary (move_type 0). `STATIONARY - spins/turns in place (...)` = technically move_type 3 "Custom" but the route only contains turn commands with net displacement (0,0) — visually stationary, treat like Fixed. A direction list like `down, up [net(dx=0,dy=0), repeats]` = a real patrol route.

**Caution on RIVAL1,Blue**: matched on 17 maps; 9 of those are named `Oak's Lab.oldest` / `_Johto` / `_Hoenn` / `_Sinnoh` / `_Custom` / `.old` / `_backup` (IDs 430/551/552/593/659/740/847) plus `9F --old--`(131) and `11F.old`(305) — these look like leftover dev/backup map duplicates, not live locations. Flagged below; prefer the un-flagged map (e.g. 77 "Oak's Lab", 757 "11F") for placement reference.

## Alt trainers found (154 placements across 86 trainers)

| TrainerType | Name | Map | Event ID/Name | X,Y | Movement |
|---|---|---|---|---|---|
| BEAUTY | Bridget | 542 — Celadon City Gym | 5/Trainer(4) | 25,19 | Fixed |
| BEAUTY | Tamia | 542 — Celadon City Gym | 2/Trainer(4) | 26,11 | STATIONARY (turn-toward-player), repeats |
| BLACKBELT | Hideki | 191 — Fighting Dojo | 7/Trainer(9) | 19,23 | Fixed |
| BLACKBELT | Hitoshi | 191 — Fighting Dojo | 4/Trainer(9) | 11,26 | Fixed |
| BUGCATCHER | Cale | 8 — Route 24 | 1/Trainer(7) | 18,41 | Fixed |
| BUGCATCHER | Conner | 495 — Route 9 | 7/Trainer(4) | 31,12 | STATIONARY (turn-left,random,right), repeats |
| BUGCATCHER | James | 490 — Route 3 | 10/Trainer(4) | 27,12 | Fixed |
| BUGCATCHER | Rick | 491 — Viridian Forest | 12/Trainer(5) | 34,14 | Fixed |
| BUGCATCHER_F | Lana | 491 — Viridian Forest | 11/Trainer(2) | 9,12 | STATIONARY (turn-toward-player), repeats |
| BUGCATCHER_F | Sally | 490 — Route 3 | 8/Trainer(3) | 15,8 | Fixed |
| BURGLAR | Ramon | 221 — Cinnabar Island Gym | 27/tr3 | 16,13 | Fixed |
| BURGLAR | Ramon | 221 — Cinnabar Island Gym | 28/EV028 | 14,13 | Fixed |
| BURGLAR | Ramon | 221 — Cinnabar Island Gym | 36/EV036 | 13,13 | Fixed |
| BURGLAR | Simon | 187 — Pokémon Mansion | 19/Trainer(3) | 40,16 | STATIONARY (turn-toward-player), repeats |
| CAMPER | Liam | 386 — Pewter City Gym | 2/Trainer(4) | 7,11 | Fixed |
| CHAMPION | Blue | 328 — Champion | 2/Blue | 10,8 | Fixed |
| CHAMPION | Blue | 328 — Champion | 8/Blue | 0,28 | Fixed |
| CHANNELER | Carrietta | 403 — Pokemon Tower F4 | 6/Trainer(2) | 4,6 | Fixed |
| CHANNELER | Emilia | 468 — Pokemon Tower F6 | 6/Trainer(3) | 8,7 | Fixed |
| CHANNELER | Karina | 467 — Pokemon Tower F5 | 6/Trainer(3) | 17,10 | Fixed |
| CHANNELER | Morgan | 403 — Pokemon Tower F4 | 7/Trainer(2) | 13,6 | STATIONARY (down,right,left), repeats |
| CHANNELER | Ruth | 467 — Pokemon Tower F5 | 8/Trainer(1) | 5,6 | STATIONARY (right,left,toward-player), repeats |
| COOLTRAINER_F | Mary | 542 — Celadon City Gym | 6/Trainer(3) | 15,19 | Fixed |
| CRUSHGIRL | Lucy | 191 — Fighting Dojo | 6/Trainer(9) | 11,23 | Fixed |
| CRUSHGIRL | Yoshimi | 191 — Fighting Dojo | 5/Trainer(9) | 19,26 | Fixed |
| CUEBALL | Isaiah | 146 — Route 17 | 10/Trainer(4) | 23,18 | Fixed |
| ELITEFOUR_Bruno | Bruno | 316 — Elite 2 | 1/EV001 | 10,9 | Fixed |
| ELITEFOUR_Lance | Lance | 318 — Elite 4 | 3/EV003 | 10,9 | Fixed |
| ELITEFOUR_Lorelei | Lorelei | 315 — Elite 1 | 5/EV005 | 10,9 | Fixed |
| ENGINEER | Baily | 24 — Vermillion City Gym | 4/Trainer(5) | 5,17 | Fixed |
| ENGINEER | Baily | 61 — Vermillion City Gym | 4/Trainer(5) | 5,17 | Fixed |
| ENGINEER | Bernie | 155 — Route 11 | 12/Trainer(3) | 36,18 | down, up [net 0,0, repeats] |
| FISHERMAN | Elliot | 159 — Route 12 | 38/Trainer(5) | 38,52 | Fixed |
| FISHERMAN | Ned | 36 — SS. Anne | 8/Trainer(1) | 43,16 | Fixed |
| FISHERMAN | Ned | 159 — Route 12 | 1/Trainer(5) | 36,25 | STATIONARY (turn-toward-player), repeats |
| FISHERMAN | Tommy | 564 — Brine Road | 31/Trainer(3) | 64,24 | STATIONARY (left,down), repeats |
| GENTLEMAN | Tucker | 24 — Vermillion City Gym | 7/Trainer(5) | 14,19 | STATIONARY (turn-random), repeats |
| GENTLEMAN | Tucker | 61 — Vermillion City Gym | 7/Trainer(5) | 14,19 | STATIONARY (turn-random), repeats |
| HAUNTEDGIRL | Carol Anne | 467 — Pokemon Tower F5 | 9/Trainer(1) | 12,4 | Fixed |
| HAUNTEDGIRL_YOUNG | Jennifer | 468 — Pokemon Tower F6 | 7/Trainer(2) | 12,13 | STATIONARY (turn-toward-player), repeats |
| HAUNTEDGIRL_YOUNG | Regan | 467 — Pokemon Tower F5 | 7/Trainer(2) | 4,13 | STATIONARY (turn-toward-player), repeats |
| HIKER | Brice | 495 — Route 9 | 10/Trainer(3) | 36,20 | Fixed |
| JUGGLER | Kayden | 479 — Fuchsia City Gym | 5/Trainer(3) | 20,7 | STATIONARY (down,up), repeats |
| JUGGLER | Kirk | 479 — Fuchsia City Gym | 7/Trainer(3) | 5,5 | STATIONARY (down,up), repeats |
| JUGGLER | Nate | 479 — Fuchsia City Gym | 6/Trainer(3) | 16,7 | Fixed |
| JUGGLER | Shawn | 479 — Fuchsia City Gym | 8/Trainer(3) | 7,7 | STATIONARY (down,up), repeats |
| LASS | Janice | 490 — Route 3 | 9/Trainer(5) | 31,6 | Fixed |
| LASS | Lisa | 542 — Celadon City Gym | 4/Trainer(2) | 26,26 | Fixed |
| LEADER_Blaine | Blaine | 221 — Cinnabar Island Gym | 2/EV002 | 14,4 | Fixed |
| LEADER_Blaine | Blaine | 546 — Fighting Arena | 29 | 20,10 | STATIONARY (turn-toward-player), repeats |
| LEADER_Brock | Brock | 386 — Pewter City Gym | 3 | 9,6 | Fixed |
| LEADER_Brock | Brock | 546 — Fighting Arena | 6 | 8,10 | STATIONARY (turn-toward-player), repeats |
| LEADER_Erika | Erika | 542 — Celadon City Gym | 9/. | 12,13 | Fixed |
| LEADER_Erika | Erika | 546 — Fighting Arena | 26 | 14,10 | STATIONARY (turn-toward-player), repeats |
| LEADER_Giovanni | Giovanni | 85 — Viridian City Gym | 92/Giovanni | 9,7 | Fixed |
| LEADER_Giovanni | Giovanni | 378 — Mewtwo Intro | 17/Giovanni | 0,7 | Fixed |
| LEADER_Giovanni | Giovanni | 546 — Fighting Arena | 30 | 22,10 | STATIONARY (turn-toward-player), repeats |
| LEADER_Koga | Koga | 479 — Fuchsia City Gym | 1/EV001 | 13,9 | Fixed |
| LEADER_Koga | Koga | 546 — Fighting Arena | 27 | 16,10 | STATIONARY (turn-toward-player), repeats |
| LEADER_Misty | Misty | 4 — Cerulean City Gym | 3/EV003 | 9,8 | Fixed |
| LEADER_Misty | Misty | 546 — Fighting Arena | 24 | 10,10 | STATIONARY (turn-toward-player), repeats |
| LEADER_Surge | Lt. Surge | 24 — Vermillion City Gym | 2/EV002 | 9,6 | Fixed |
| LEADER_Surge | Lt. Surge | 61 — Vermillion City Gym | 2/EV002 | 9,6 | Fixed |
| LEADER_Surge | Lt. Surge | 546 — Fighting Arena | 25 | 12,10 | STATIONARY (turn-toward-player), repeats |
| PICNICKER | Ariana | 349 — Rock Tunnel | 11/Trainer(2) | 54,33 | Fixed |
| PICNICKER | Kim | 254 — Route 35 | 16/Trainer(4) | 19,29 | STATIONARY (up,down,toward-player), repeats |
| PICNICKER | Kim | 254 — Route 35 | 15/Trainer(4) | 22,36 | STATIONARY (turn-toward-player), repeats |
| PICNICKER | Martine | 542 — Celadon City Gym | 7/Trainer(3) | 5,18 | STATIONARY (right,toward-player,down), repeats |
| PICNICKER | Tina | 542 — Celadon City Gym | 1/Trainer(4) | 3,21 | Fixed |
| PLAYER | Martin | 647 — Magogany Town Gym | 6/Trainer(0) | 12,12 | right x4, left x4 [net 0,0, repeats] |
| PLAYER | Maurice | 647 — Magogany Town Gym | 10/Trainer(0) | 21,17 | down x4, up x4 [net 0,0, repeats] |
| PLAYER | Sidney | 647 — Magogany Town Gym | 9/Trainer(0) | 23,13 | left x4, right x4 [net 0,0, repeats] |
| PLAYER | Wayne | 647 — Magogany Town Gym | 14/Trainer(0) | 7,12 | down x3, up x3 [net 0,0, repeats] |
| POKEMANIAC | Larry | 286 — Union Cave B1 | 7/Trainer(3) | 16,31 | left x5, right x5 [net 0,0, repeats] |
| POKEMONBREEDER | Maude | 12 — Route 5 | 9/Trainer(4) | 9,7 | Fixed |
| POKEMONRANGER_F | Jane | 600 — Bond Bridge | 23/Trainer(4) | 81,40 | Fixed |
| POKEMONRANGER_F | Jane | 600 — Bond Bridge | 21/Trainer(4) | 69,35 | right x2, down, left x2, up [net 0,0, repeats] |
| POKEMONRANGER_M | Osman | 600 — Bond Bridge | 22/Trainer(4) | 62,30 | STATIONARY (left,toward-player,right), repeats |
| POKEMONRANGER_M | Steve | 600 — Bond Bridge | 1/Trainer(4) | 81,30 | Fixed |
| RIVAL1 | Blue | 1 — Cerulean City | 17/EV017 | 17,1 | Fixed |
| RIVAL1 | Blue | 1 — Cerulean City | 9/Blue | 19,6 | Fixed |
| RIVAL1 | Blue | 15 — Northern Gate | 7/gary | 15,7 | Fixed |
| RIVAL1 | Blue | 27 — S.S. Anne | 27/EV027 | 32,9 | Fixed |
| RIVAL1 | Blue | 27 — S.S. Anne | 28/EV028 | 33,9 | Fixed |
| RIVAL1 | Blue | 27 — S.S. Anne | 6/EV006 | 30,9 | Fixed |
| RIVAL1 | Blue | 27 — S.S. Anne | 26/EV026 | 31,9 | Fixed |
| RIVAL1 | Blue | 77 — Oak's Lab | 8/Trainer(5) | 3,0 | Fixed |
| RIVAL1 | Blue | 77 — Oak's Lab | 21/Trainer(5) | 12,14 | Fixed |
| RIVAL1 | Blue | 77 — Oak's Lab | 43/Trainer(5) | 19,14 | Fixed |
| RIVAL1 | Blue | 131 — 9F --old-- *(dev backup)* | 29/Blue | 15,22 | Fixed |
| RIVAL1 | Blue | 171 — Route 22 | 38/Blue | 26,17 | Fixed |
| RIVAL1 | Blue | 171 — Route 22 | 7/Blue | 28,11 | Fixed |
| RIVAL1 | Blue | 171 — Route 22 | 40/Blue | 26,18 | Fixed |
| RIVAL1 | Blue | 171 — Route 22 | 35/Blue | 20,15 | Fixed |
| RIVAL1 | Blue | 171 — Route 22 | 36/Blue | 26,15 | Fixed |
| RIVAL1 | Blue | 171 — Route 22 | 37/Blue | 26,16 | Fixed |
| RIVAL1 | Blue | 305 — 11F.old *(dev backup)* | 29/Blue | 15,22 | Fixed |
| RIVAL1 | Blue | 401 — Pokemon Tower F2 | 12/blue | 0,0 | Fixed |
| RIVAL1 | Blue | 401 — Pokemon Tower F2 | 2/blue | 12,8 | Fixed |
| RIVAL1 | Blue | 401 — Pokemon Tower F2 | 10/blue | 19,14 | Fixed |
| RIVAL1 | Blue | 430 — Oak's Lab.oldest *(dev backup)* | 7 | 12,14 | Fixed |
| RIVAL1 | Blue | 430 — Oak's Lab.oldest *(dev backup)* | 42/EV042 | 15,18 | Fixed |
| RIVAL1 | Blue | 472 — Fuchsia City | 76/Gary | 27,32 | Fixed |
| RIVAL1 | Blue | 472 — Fuchsia City | 77/Gary | 43,44 | Fixed |
| RIVAL1 | Blue | 551 — Oak's Lab _Johto *(dev backup)* | 21/Trainer(5) | 12,14 | Fixed |
| RIVAL1 | Blue | 552 — Oak's Lab _Hoenn *(dev backup)* | 21/Trainer(5) | 12,14 | Fixed |
| RIVAL1 | Blue | 593 — Oak's Lab _Sinnoh *(dev backup)* | 21/Trainer(5) | 12,14 | Fixed |
| RIVAL1 | Blue | 659 — Oak's Lab _Custom *(dev backup)* | 21/Trainer(5) | 12,14 | Fixed |
| RIVAL1 | Blue | 740 — Oak's Lab.old *(dev backup)* | 21/Trainer(5) | 12,14 | Fixed |
| RIVAL1 | Blue | 757 — 11F | 29/Blue | 9,27 | Fixed |
| RIVAL1 | Blue | 757 — 11F | 9/Blue | 11,15 | Fixed |
| RIVAL1 | Blue | 778 — Mt Silver | 1/EV001 | 12,16 | Fixed |
| RIVAL1 | Blue | 847 — Oak's Lab_backup *(dev backup)* | 43/Trainer(5) | 19,14 | Fixed |
| RIVAL1 | Blue | 847 — Oak's Lab_backup *(dev backup)* | 21/Trainer(5) | 12,14 | Fixed |
| SAILOR | Dwayne | 24 — Vermillion City Gym | 6/Trainer(5) | 12,15 | Fixed |
| SAILOR | Dwayne | 61 — Vermillion City Gym | 6/Trainer(5) | 12,15 | Fixed |
| SCIENTIST | Ivan | 181 — Pokémon Mansion | 23/Trainer(4) | 35,17 | Fixed |
| SUPERNERD | Glenn | 409 — Route 8 | 12/Trainer(5) | 46,12 | STATIONARY (toward-player,down,left,up), repeats |
| SUPERNERD | Miguel | 17 — S.S. Anne | 11/EV011 | 3,11 | Fixed |
| SUPERNERD | Miguel | 105 — Mt. Moon B2F | 7/Trainer(4) | 6,5 | Fixed |
| SUPERNERD | Miguel | 105 — Mt. Moon B2F | 37/EV037 | 15,14 | Fixed |
| SUPERNERD | Miguel | 342 — Ruins of Alph | 27/EV027 | 18,16 | Fixed |
| SUPERNERD | Miguel | 406 — Celadon Café | 5/EV005 | 10,9 | Fixed |
| SWIMMER_F | Abigail | 559 — Kindle Road | 36/Trainer(4) | 20,93 | STATIONARY (random,toward-player), repeats |
| SWIMMER_M | Raphael | 564 — Brine Road | 35/Trainer(4) | 72,30 | Fixed |
| SWIMMER_M | Reece | 57 — Route 19 | 7/Trainer(3) | 13,21 | left x3, right x3 [net 0,0, repeats] |
| SWIMMER_M | Richard | 57 — Route 19 | 5/Trainer(3) | 10,27 | left x2, right x5, left x3 [net 0,0, repeats] |
| TAMER | Edgar | 479 — Fuchsia City Gym | 9/Trainer(3) | 16,5 | STATIONARY (up,down,right), repeats |
| TAMER | Phil | 479 — Fuchsia City Gym | 10/Trainer(3) | 11,8 | STATIONARY (toward-player,down,random), repeats |
| TEAMROCKET_F | Kaitlin | 431 — Celadon Sewers | 43/Trainer(4) | 37,18 | Fixed |
| TEAMROCKET_F | Kaitlin | 446 — Celadon Sewers | 26/Trainer(4) | 37,18 | Fixed |
| TEAMROCKET_F | Virginia | 431 — Celadon Sewers | 41/Trainer(3) | 28,19 | Fixed |
| TEAMROCKET_M | Cyrus | 108 — Saffron City | 60/bully1 | 42,16 | Fixed *(double-battle partner)* |
| TEAMROCKET_M | Cyrus | 118 — debug | 23/bully1 | 4,13 | Fixed *(double-battle partner, on a "debug" map)* |
| TEAMROCKET_M | Dennis | 15 — Northern Gate | 9/Lance | 1,6 | Fixed |
| TEAMROCKET_M | Dennis | 18 — Southern Gate | 8/Lance | 1,8 | Fixed |
| TEAMROCKET_M | Dennis | 66 — Eastern Gate | 5/EV005 | 6,12 | Fixed |
| TEAMROCKET_M | Dennis | 66 — Eastern Gate | 1/EV001 | 6,11 | Fixed |
| TEAMROCKET_M | Dennis | 66 — Eastern Gate | 4/Lance | 11,14 | Fixed |
| TEAMROCKET_M | Dennis | 415 — Western Gate | 4/Lance | 12,11 | Fixed |
| TEAMROCKET_M | Francis | 105 — Mt. Moon B2F | 13/Trainer(4) | 33,10 | Fixed |
| TEAMROCKET_M | Joffrey | 431 — Celadon Sewers | 36/Trainer(3) | 7,17 | Fixed |
| TEAMROCKET_M | Joffrey | 446 — Celadon Sewers | 24/Trainer(3) | 28,19 | STATIONARY (turn-toward-player), repeats |
| TEAMROCKET_M | Max | 431 — Celadon Sewers | 46/Trainer(4) | 25,22 | Fixed |
| TEAMROCKET_M | Max | 446 — Celadon Sewers | 23/Trainer(3) | 23,22 | STATIONARY (turn-toward-player), repeats |
| TEAMROCKET_M | Omar | 431 — Celadon Sewers | 44/Trainer(4) | 41,18 | Fixed |
| TEAMROCKET_M | Omar | 446 — Celadon Sewers | 27/Trainer(5) | 41,18 | Fixed |
| TEAMROCKET_M | Paul | 431 — Celadon Sewers | 40/Trainer(3) | 2,9 | Fixed |
| TEAMROCKET_M | Paul | 446 — Celadon Sewers | 28/Trainer(3) | 2,9 | Fixed |
| TEAMROCKET_M | Phillip | 431 — Celadon Sewers | 39/Trainer(3) | 6,9 | Fixed |
| TEAMROCKET_M | Phillip | 446 — Celadon Sewers | 29/Trainer(3) | 6,9 | Fixed |
| YOUNGSTER | Ben | 490 — Route 3 | 6/Trainer(4) | 12,4 | Fixed |
| YOUNGSTER | Dan | 9 — Route 25 | 5/Trainer(4) | 18,15 | STATIONARY (left,down,toward-player), repeats |
| YOUNGSTER | Joey | 8 — Route 24 | 6/Trainer(4) | 41,15 | STATIONARY (down,left,right,up), repeats |

(Map column format: MapID — Display name, from `Data/MapInfos.rxdata`, i.e. what shows in the RPG Maker XP editor's map tree.)

## Alt trainers NOT located on any map (1)

- **CHANNELER, Angelica** — exists in `PBS/trainers.txt` (line 78, `LoseText = "..."` only) but no map event anywhere references it. No reference point available; place manually.

## "New" entries with no existing analog (27 unique pairs, place manually with no reference point)

BEAUTY,Olivia · BUGCATCHER,Nelson · BURGLAR,Jamal · COOLTRAINER_F,Rike · FISHERMAN,Dale · HAUNTEDGIRL,Samara · HIPSTER,Jerry (appears twice in the merge file, two different battle versions) · LASS,Ali · LASS,Haley · LASS,Marina · LASS,Reli · PICNICKER,Diana · POKEMANIAC,Guy · ROBOT,KILLBOT · ROBOT,RED · ROCKETEXEC_F,Ariana · ROCKETEXEC_M,Archer · TEAMROCKET_M,Ritchie · TEAMROCKET_M,Sam · WORKER,Angus · WORKER,Felix · WORKER,Hermann · WORKER,John · WORKER,Kevin · WORKER,Mark · WORKER,Silvio

## Files used / produced during investigation

- Read: `Mods/AnimeFusionMerge/trainers.txt`, `PBS/trainers.txt`, `if1_locs.txt`, `Data/Scripts/021_Compiler/004_Compiler_MapsAndEvents.rb`, `Data/MapInfos.rxdata`, 68 `Data/Map*.rxdata` files.
- No `.rxdata` or any project file was modified — read-only throughout, confirmed via `Marshal.load` on `File.binread`.
