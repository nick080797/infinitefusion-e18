# Wild Link

Wild Link is Kanto Reloaded's targeted wild Pokemon search system. It is opened
from the Overworld Menu and does not replace or modify KIF's Poke Radar files.

## Availability

Wild Link reads the current map's native encounter tables and supports:

- Land
- Cave
- Surf
- Fishing
- Headbutt
- Rock Smash

When KIF Pokemon randomization is enabled, Wild Link replaces the authored
roster with the same effective roster used by normal encounters:

- `Global` applies KIF's saved one-to-one species mapping to every authored
  encounter slot.
- `Area` reads the current map directly from KIF's saved
  `GameData::EncounterRandom` table, preserving its randomized species,
  weights, and level ranges.

This lets randomized species fill the Wild Link discovery roster instead of
continuing to show the map's original encounter species. Changing modes does
not require Wild Link to retain a stale copy of the current map's old table.

Land, alternate Land terrain, Cave, and Surf rosters use KIF's current
Morning, Afternoon, Evening, Day, or Night encounter table with the same
fallback order as native encounters. Reopening Wild Link after the time period
changes shows the newly active table. Rare Signal selection remains map-wide
and does not change with the time period.

KIF's Static Encounter randomizer runs after a species has been selected for
battle. Wild Link applies that same final mapping to Global, Area, and generic
Rock Smash fallback species before displaying or generating the target.
Authored Rare Signals instead follow the live Poke Radar rare-species API so
they remain consistent with the actual Poke Radar encounter. If another system
has compatibly extended the live Area encounter table, Wild Link keeps those
additions instead of replacing the live table with the saved randomized table.

Dynamic Pokemon is deliberately different. Its encounter result is rerolled
after a table slot is selected, so those transient species are not recorded or
added to Wild Link's roster. Wild Link continues to show only the stable Global
or Area table that Dynamic Pokemon is rerolling from. Resolving a Wild Link
roster never consumes a Dynamic Pokemon roll.

KIF's `Randomize to Fusions` option is supported because those exact fusions
are stored in the Global mapping or Area encounter table. KIF's separate
chance-based and force-all wild fusion behavior runs after table selection and
can produce an unbounded set of pairings, so Wild Link does not reroll a
selected target through that step or add those transient pairings to its
roster.

Fishing requires both an owned rod and that rod's authored encounter table on
the current map; KIF does not provide a generic fishing fallback. Surf is
available from shore when the current map has a Water encounter table and the
player can use Surf through a Pokemon or Surfboard. Headbutt requires a
compatible nearby map event and encounter table. Rock Smash requires a nearby
smash-rock event. Wild Link is disabled in Safari, Bug Contest, partner, and
non-map contexts.

Rock Smash uses the current map's dedicated `RockSmash` encounter table when
one exists. Maps without an authored table use KIF's generic Geodude fallback
at levels 5-14, including KIF's native Static Encounter randomization of that
fallback species. It never borrows species from Cave or Land tables.

## Discovery

- Unseen standard Pokemon appear as silhouettes and cannot be selected.
- Seen Pokemon can be searched.
- Caught Pokemon use colored previews and unlock full scan details.
- The global `Sprites` option switches detail previews between `Icons` and
  `Full Sprites`. It defaults to `Full Sprites` and does not inherit KIF's Big
  Icons mode.
- Search Level is permanent and stored per exact species or fusion.
- Search Level is capped at 999.
- Exact fusion identities supplied by the active Global or Area randomized
  encounter table appear as normal searchable entries.
- Rare Signal uses KIF's native `Settings::POKE_RADAR_ENCOUNTERS` data when
  the current map has an authored Poké Radar species.
- Authored Poké Radar species remain unchanged by encounter randomization so
  Wild Link and the native Poké Radar identify the same map-exclusive species.
- Maps without an authored rare species receive a deterministic fallback. Wild
  Link calculates the encounter-rate-weighted average BST of the effective
  map-wide Land roster across all time periods, targets approximately 50 BST
  above that average, excludes its normal species and legendaries, and chooses
  from the twelve closest matches. The fallback uses the map's Land level range
  and updates when its effective randomized encounter table changes.
- Rare Signal unlocks after every standard Pokemon in the currently displayed
  time-appropriate Land roster has been seen. Before then, the Rare Signal row
  remains hidden and does not contribute to the method's Seen, Caught, or total
  counts. Catching every standard species is not required.
- An encountered Rare Signal species joins the normal searchable roster.

## Target Lifecycle

Land and Cave searches create one temporary overworld target. Surf places a
centered ripple on a surfable water tile and starts the prepared encounter when
the player Surfs onto it. Fishing, Headbutt, and Rock Smash preserve their
native field interactions and replace only the final matching encounter.

Fishing also marks its water tile with a centered ripple. Headbutt repeatedly
rustles the leaves of the affected native tree. Rock Smash traces the affected
native rock sprite with a pulsing white outline. These field methods do not
create Pokemon overworld sprites. Using Headbutt on the marked tree always
starts the prepared target instead of running KIF's normal tree encounter
chance. Smashing the marked rock always starts the prepared Wild Link
encounter and never runs KIF's normal item-reward roll.

While a target is active, ordinary step encounters are suppressed without
changing Repel. The target and chain are cleared by map changes, trainer
battles, target replacement, native Poke Radar activation, fleeing, losing, or
loading another save. Menus do not break a chain.

Wild Link passes the exact generated Pokemon object to KIF's native wild battle
core. The target's level, personality, IVs, ability, moves, held item, and shiny
state are therefore preserved.

## Overworld Reactions

Direct Land and Cave targets transition between roaming and noticed states.
Each transition into the noticed state plays one of KIF's native
Hoenn-style reaction graphics:

- Curious targets show a question mark, approach, observe the player, and may
  hop or look around while nearby.
- Aggressive targets show anger and charge from farther away.
- Territorial targets show anger but approach only within their territory.
- Skittish and Elusive targets show an exclamation mark and retreat.
- Calm targets continue roaming and face the player without an alert.

Temperament is deterministic for each species. Wild Link derives the eligible
temperament pool from that species' offensive, defensive, and Speed stats, then
uses the species identity to choose consistently from that pool.

When the player leaves detection range, non-fleeing targets return to roaming.
The base detection radius is six tiles; Search Levels 50 and 200 each reduce it
by one tile, making advanced targets easier to approach without being noticed.
Skittish non-shiny targets that remain frightened for too long use a staged
Hoenn-style escape: they cry, play the flee sound, move away, fade out, and end
the chain. Shiny targets and targets at Search Level 500 or higher never
distance-despawn. Shiny targets also never enter the staged flee sequence.

## Progression

- Knockout: Search Level +1 and Chain +1.
- Catch: Search Level +2 and Chain +1.
- Run, loss, or target escape: no Search Level gain and the chain ends.
- Chains are scoped to exact species/fusion, encounter method, and map.

`Continue Search` has three settings:

- `Prompt`: ask after a successful target.
- `Automatic`: begin the next target automatically.
- `Off`: preserve the chain but require Wild Link to be opened again.

Declining the `Prompt` ends the current chain.
Continuation waits for at least eight stable overworld updates after battle.

`Input Z` switches the selected link's detail panel between `SL Info` and
`Current Bonuses`. This works for inactive links and the current active target.
The header shows separate Seen and Caught completion totals for the selected
encounter method, including undiscovered Rare Signal species in its total.
The SL page shows scan unlocks, or the generated target's unlocked level,
temperament, exact perfect-IV count, held item, abilities, Egg Moves, and signal
location. The bonus page is calculated by the same helpers used to generate the
target and includes level, shiny-roll, guaranteed and chance-based perfect-IV,
Hidden Ability, Egg Move, and held-item bonuses. Unavailable species bonuses
display `N/A`.

The active target's `Perfect IVs: X/6` value is its actual number of 31 IVs
after native generation and Wild Link bonuses. It can therefore be higher than
the guaranteed minimum shown on the bonus page.

While a target or chain is active, `Action` in the Wild Link scene cancels the
target and ends its chain after confirmation. The `Cancel Link` footer command
can also be clicked with the mouse.

`Messages` controls routine Wild Link prompts, warnings, and notifications.
Turning it off automatically accepts normal search-flow confirmations.
Placement failures such as `No reachable target position was found nearby`
always remain visible so the player knows why a search did not start. The
configured `Continue Search` prompt and the destructive Search Level reset
confirmation also always remain available.

Rare Signal rows and revealed rare-species rows are drawn in gold. Once a rare
species has been seen, its separate Rare Signal is replaced by the species'
normal Land roster row, which remains gold to identify it as that map's rare
encounter.

## Map Diagnostics

`Gather Map Data` under `Developer / Utility` creates
`KantoReloaded/Logging/WildLinkMapData.txt`, uploads the sanitized report,
and copies a Discord-ready link when clipboard access is available. It does
not open the Kanto Reloaded bug-report thread.

The report snapshots the current map ID, name, dimensions, metadata, player
map position and terrain, field tools, terrain-tag counts, map events, Wild
Link method eligibility, every active encounter table, and Weather System
eligibility, ownership, cell membership, current state, next forecast, and
Town Map position conflicts. It is intended for diagnosing map-dependent
Wild Link and weather behavior. The report does not include save contents or
player identity.

## Scan Unlocks

| Search Level | Detail |
| ---: | --- |
| 1 | Target level |
| 5 | Temperament |
| 10 | IV potential |
| 15 | Held item |
| 20 | Ability |
| 25 | Egg Moves |
| 50 | Exact signal direction and distance |

IV, item, ability, and Egg Move details require the species to be caught.
Shininess is never disclosed in the selection roster.
When Double Abilities is active, an eligible fusion's unlocked scan details
show Ability 1 and Ability 2 separately.

## Shiny Rolls

Additional shiny attempts are independent and apply only to Wild Link targets.
Native shiny generation, Shiny Charm behavior, and the current game shiny odds
run first.

Search Level rolls:

| Search Level | Extra Rolls |
| ---: | ---: |
| 0-24 | 0 |
| 25-99 | 1 |
| 100-199 | 2 |
| 200-499 | 3 |
| 500-999 | 4 |

Chain rolls:

| Chain | Extra Rolls |
| ---: | ---: |
| 0-9 | 0 |
| 10-19 | 1 |
| 20-49 | 2 |
| 50-149 | 3 |
| 150+ | 4 |

The combined Wild Link bonus is capped at eight additional rolls.

## Perfect IVs

Search Level:

- 25-49: 15% chance of one perfect IV.
- 50-99: one guaranteed perfect IV.
- 100-199: one guaranteed, with a 20% chance of a second.
- 200-499: two guaranteed perfect IVs.
- 500-999: two guaranteed, with a 20% chance of a third.

Chain:

- 30-49: 50% chance of one additional perfect IV.
- 50-99: at least two perfect IVs.
- 100-149: at least three perfect IVs.
- 150+: at least four perfect IVs.

Wild Link never guarantees more than four perfect IVs.

## Hidden Ability

Base Search Level chance:

| Search Level | Chance |
| ---: | ---: |
| 0-9 | 0% |
| 10-24 | 2% |
| 25-49 | 5% |
| 50-99 | 8% |
| 100-199 | 12% |
| 200-499 | 18% |
| 500-999 | 25% |

Chain adds 5%, 10%, 15%, 20%, or 25% at chains 10, 20, 50, 100, and 150.
The combined chance is capped at 50% and is skipped when no Hidden Ability
exists.

When Double Abilities is active for an eligible fusion, Wild Link can replace
Ability 1 only with a legal Hidden Ability from Ability 1's recorded component.
If that component has no legal Hidden Ability, the generated ability pair is
left unchanged.

## Egg Moves

A target can receive up to two distinct Egg Moves from its species data. The
first move begins unlocking at Search Level 10 or Chain 10. The second move
requires Search Level 100 or Chain 50 and is rolled only if the first succeeds.
The first and second chances are capped at 90% and 65%, respectively.

First Egg Move base chance:

| Search Level | Chance |
| ---: | ---: |
| 0-9 | 0% |
| 10-24 | 10% |
| 25-49 | 20% |
| 50-99 | 30% |
| 100-199 | 40% |
| 200-499 | 55% |
| 500-999 | 70% |

First Egg Move chain bonus:

| Chain | Added Chance |
| ---: | ---: |
| 0-9 | 0% |
| 10-19 | 5% |
| 20-49 | 10% |
| 50-99 | 15% |
| 100-149 | 20% |
| 150+ | 25% |

Second Egg Move base chance:

| Search Level | Chance |
| ---: | ---: |
| 0-99 | 0% |
| 100-199 | 10% |
| 200-499 | 20% |
| 500-999 | 30% |

Second Egg Move chain bonus:

| Chain | Added Chance |
| ---: | ---: |
| 0-49 | 0% |
| 50-99 | 15% |
| 100-149 | 25% |
| 150+ | 35% |

## Held Items

KIF's native wild held-item generation runs first. Wild Link then performs a
separate Search-Level and chain-based item roll using only that species' native
common, uncommon, and rare held-item table. A successful roll can assign a
native item when KIF generated none, or upgrade an existing result to a
higher-ranked native item. It never introduces generic items or downgrades a
native result. The combined bonus-roll chance is capped at 60%.

Base upgrade chance:

| Search Level | Chance |
| ---: | ---: |
| 0-9 | 0% |
| 10-24 | 5% |
| 25-49 | 10% |
| 50-99 | 15% |
| 100-199 | 20% |
| 200-499 | 25% |
| 500-999 | 30% |

Chain upgrade bonus:

| Chain | Added Chance |
| ---: | ---: |
| 0-9 | 0% |
| 10-19 | 5% |
| 20-49 | 10% |
| 50-99 | 15% |
| 100-149 | 20% |
| 150+ | 30% |

When an upgrade roll succeeds, Search Level and chain progression also shift
the selection weight from the species' common item toward its uncommon and
rare items. Rare-item weight is capped at 40%, uncommon-item weight at 55%,
and common-item weight never falls below 10%.

## Level Bonus

Only Search Level affects target level:

| Search Level | Added Levels |
| ---: | ---: |
| 0-9 | 0 |
| 10-24 | 0-1 |
| 25-49 | 0-2 |
| 50-99 | 1-2 |
| 100-199 | 1-3 |
| 200-499 | 2-4 |
| 500-999 | 3-5 |

The result is capped at KIF's normal maximum level.

## Integration Boundaries

- No KIF base files are edited.
- Native field-move prompts and animations remain authoritative.
- Native Poke Radar and Wild Link are mutually exclusive through guarded
  confirmation prompts.
- Wild Link owns and disposes only its temporary event and sprite.
- KIF's global randomizer mapping is applied once to each encounter-table
  species, so a source species has a stable randomized Wild Link identity.
- KIF's area randomizer is respected through the already-randomized encounter
  table loaded for the current map.
- KR Dynamic Pokemon intentionally does not reroll a selected Wild Link
  target. Dynamic rerolls wrap KIF's normal `choose_wild_pokemon` path, while
  Wild Link directly generates the species explicitly selected in its roster.
- Wild Link uses the same demand-driven loading model as Reloaded PC. Only the
  currently selected preview is requested. The initially selected row is
  prepared before the completed scene becomes visible, source graphics are
  reused through KIF's native bitmap cache, and completed previews remain in a
  bounded KR memory cache between Wild Link scene openings during the current
  game session.
- Wild Link does not generate an entire map roster or export preview PNGs while
  the scene is open. A newly selected species can incur its normal first-load
  cost, but stopping list navigation cannot trigger a bulk loading pass.
- Missing standard fusion-icon previews are assembled with one lower-half
  bitmap copy rather than KIF's per-pixel temporary-file generator. This path
  is scoped to Wild Link previews and does not replace native PC, party, or
  battle sprite behavior.
- Full-sprite previews use KIF's native species and fusion battler resolver,
  crop transparent padding, and fit the selected sprite into the existing
  detail area. They retain the same selected-row demand loading and bounded
  cache behavior as icon previews.
- Fusion targets retain the exact fusion for battle and use the body Pokemon's
  dark silhouette in the overworld.
- Normal and shiny fusion follower silhouettes are distributed in two standard
  ZIP archives with `.pak` extensions under
  `Graphics/Characters/Followers/Fusions`. They can be opened with ordinary ZIP
  tools. Wild Link indexes a pack once, verifies entries with CRC32, and
  extracts only the requested silhouette. `Tools/FollowerPacks.rb` can pack,
  unpack, or verify both files.
- If a target species does not have an overworld follower graphic, Wild Link
  uses Pikachu's overworld graphic. Unknown targets still render that fallback
  as a fully black silhouette.
