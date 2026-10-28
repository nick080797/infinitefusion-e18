# Kanto Reloaded Weather System

## SUMMARY

The Weather System creates persistent regional weather fronts without replacing
authored map weather or scripted weather events. It is enabled by default and
can be configured from the Gameplay category.

The system stores one exact current snapshot and one exact next-cycle snapshot
in the save file. When a weather cycle advances, the displayed forecast becomes
the current weather and a new forecast is generated. Reloading a save does not
reroll either snapshot.

The Overworld Menu can open the full Weather Forecast. Its Features menu also
contains an optional compact Forecast View, which is disabled by default.

## SETTINGS

### Weather System

- On by default.
- Pauses the simulation while disabled.
- Resumes with a fresh interval rather than processing disabled time as
  catch-up cycles.

### Update Interval

- Supports 3, 6, 12, or 24 in-game hours.
- Defaults to 6 in-game hours.
- Runtime checks are throttled to approximately once per second.

### Weather Selection

- Defaults to Climates.
- Climates uses the current cell's weighted weather pool and adapts moving
  fronts to their destination climate.
- Random gives Rain, Storm, Sunny, Fog, Snow, and Sandstorm equal selection
  weight. Climate persistence bonuses and climate conversion are disabled.
- Changing modes regenerates the current and next-cycle snapshots immediately.

### Battle Weather

- On by default.
- Carries Kanto Reloaded-owned overworld weather into battles.
- Does not override an explicit battle weather rule.
- Converts Rain, Storm, and Heavy Rain to battle Rain; Snow and Blizzard to
  battle Hail; Sunny to battle Sun; and Sandstorm or Strong Winds to their
  matching battle weather. Clear and Fog do not create battle weather.
- PvP settings exchange a Kanto Reloaded weather capability before battle.
  Initiator weather is synchronized only after both clients confirm the same
  protocol; otherwise Kanto Reloaded battle weather is disabled for that match.
- Co-op does not expose a safe mod-capability exchange before every battle.
  Kanto Reloaded therefore suppresses local battle weather in co-op rather than
  risk giving clients different deterministic battle states.

### Weather Alerts

- On by default.
- Shows a non-pausing upper-left alert when the current map's simulated weather
  changes after a weather cycle or an Admin Control change.
- Does not take input, stop map graphics, or appear merely because a save or map
  was loaded.

### Audio

- Opens the dedicated Weather Audio settings page.
- Contains Custom Audio plus separate Rain Audio and Thunder Audio toggles.

### Custom Audio

- Global setting, enabled by default.
- Continuously loops Kanto Reloaded-owned rain, storm, and heavy-rain ambience
  for as long as that weather remains active.
- Uses thunder every 6 to 14 seconds during storms and every 10 to 20 seconds
  during heavy rain. Each interval begins after the previous thunder finishes.
- Relinquishes audio ownership when another script starts, stops, or fades BGS.

### Rain Audio

- Global toggle, enabled by default.
- Controls continuous rain, storm, and heavy-rain ambience.
- Remains disabled while Custom Audio is Off.

### Thunder Audio

- Global toggle, enabled by default.
- Controls randomized thunder independently from rain ambience.
- Remains disabled while Custom Audio is Off.

### Forecast View

- Per-save Overworld Menu feature, disabled by default.
- Displays the current and next weather below Party View when Party View is
  enabled.
- Uses the upper-left companion-panel position when Party View is disabled.

## WEATHER

Supported weather:

- Clear
- Rain
- Storm
- Sunny
- Fog
- Snow
- Blizzard
- Sandstorm
- Heavy Rain
- Strong Winds

Heavy Rain, Strong Winds, and Blizzard are escalation states reached by fronts
at intensity 8 or higher. They return to their normal weather when their
intensity weakens below 8.

## CLIMATES

Outdoor maps are grouped into persistent weather cells. Directly connected map
parts with the same normalized map name share a cell. Town Map coordinates are
used for adjacency and forecast placement, not as the sole cell identity.

Climate is inferred from map name and battle environment:

- Temperate
- Coastal
- Mountain
- Cold
- Arid

Climate weights used by Climates mode:

| Climate | Weather weights |
| --- | --- |
| Temperate | Rain 45, Sunny 25, Fog 20, Storm 10 |
| Coastal | Rain 45, Fog 20, Storm 20, Sunny 15 |
| Mountain | Snow 30, Rain 25, Fog 25, Storm 15, Sunny 5 |
| Cold | Snow 60, Fog 20, Rain 10, Sunny 10 |
| Arid | Sunny 55, Sandstorm 30, Rain 10, Fog 5 |

## FRONTS

Existing fronts strengthen, hold, weaken, move into adjacent cells, and collide.
Movement transfers a front out of its source cell instead of duplicating it.
Matching neighboring weather slightly favors strengthening and persistence,
while intensity 7 through 10 adds increasing dissipation pressure so severe
weather cannot permanently saturate the forecast.

New-front chance is evaluated for each clear dynamic cell:

| Current coverage | Chance |
| --- | --- |
| Below 20% | 4% |
| 20% to below 30% | 2% |
| 30% to below 35% | 1% |
| 35% or higher | 0% |

After normal evolution, spreading, and new-front generation, the simulation
guarantees active dynamic weather in approximately 4% of weather cells within
each mapped Town Map region. Every region has a minimum floor of 3 active cells,
and the percentage-based guarantee is capped at 6 cells per region. Natural
generation and spreading can exceed that guarantee. Missing fronts use the
active Weather Selection mode and begin at intensity 2 through 4. Existing
saves below a regional floor are repaired without rerolling their other current
or forecast weather.

Rain meeting sun can form fog. Rain meeting storms favors a stronger storm.
In Climates mode, cold cells convert rain to snow and storms to blizzards, and
arid sandstorms weaken into sun when they leave arid climates.

## MAP OVERRIDES

`WeatherData.rb` contains the data-only `MAP_OVERRIDES` registry for maps whose
metadata cannot represent the intended Weather System behavior. Entries can:

- Include or exclude a map with `:eligible`
- Merge related map parts with a shared `:cell_group`
- Assign a supported `:climate`
- Replace the generated forecast label with `:label`

The cell builder applies these values before grouping and climate inference.
No simulation or map-hook patch is required for a new exception.

## ADMIN CONTROL

The separately managed `AdminControl` mod includes a Current Map Weather tool.
It can create any supported weather and intensity as a real front in the
current outdoor map's weather cell. The front is written to both the saved
current and next-cycle snapshots, updates the forecast immediately, survives
save reloads, and takes precedence over authored weather while it is marked as
an Admin Control front. `Restore Simulated Weather` restores the exact current
and forecast entries that existed before the first Admin Control change.

## OWNERSHIP

Weather precedence:

1. Explicit battle weather
2. Scripted overworld weather
3. Saved Admin Control fronts
4. Guaranteed authored map weather
5. Kanto Reloaded dynamic weather

Kanto Reloaded applies dynamic weather to outdoor maps without guaranteed
authored weather. Authored weather below a 100% map-entry chance is replaced by
the persistent regional simulation; authored weather at 100% remains protected.
Calls to `Game_Screen#weather` made outside the module immediately release Kanto
Reloaded ownership for the current map. Ownership is reconsidered after the next
map change.

All native integration uses idempotent `KantoReloaded::Hooks.wrap` wrappers or
appended event handlers. The module does not replace native weather, battle, or
audio implementations.

## FORECAST

The full forecast uses the existing KIF Town Map graphic and map coordinates.
It supports:

- Current and next-cycle views
- Directional panning
- Current-location recentering
- Mouse hover inspection
- Weather, intensity, climate, trend, and authored-weather details

When independent weather cells share one Town Map tile, the current map's cell
is preferred at the player's location. Elsewhere, one stable canonical cell is
used for both the map marker and detail panel so their weather cannot disagree.
Outdoor map parts that share a name with excluded interiors are labeled
`(Outdoor)`.

Guaranteed authored weather is displayed as authored. Probabilistic authored
weather below 100% is replaced by Kanto Reloaded weather and is displayed as a
normal dynamic cell.

The forecast does not alter encounter tables. There are no weather-specific
encounter tables in this module.

`Gather Map Data` under `Developer / Utility` includes Weather System settings,
raw outdoor metadata, effective map eligibility, configured map overrides,
authored and live weather, ownership, cell membership, current and next-cycle
states, icon resolution, and all weather cells sharing the current Town Map
position.
