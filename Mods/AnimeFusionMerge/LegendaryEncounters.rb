#==============================================================================
# Anime Fusion Merge - per-game "legendary gate" overworld encounters
#
# Each source game's legendaries unlock SEQUENTIALLY, not all at once: sorted
# by their own Pokedex ID (used as a stand-in "power/chronology" ordering,
# since that's how the merged dex itself is already organized), then spread
# evenly across that game's 13-boss ladder (8 gyms + 4 Elite Four + Champion,
# see GymBossPlacement::GAME_BOSS_IDS) - e.g. with 14 DBZ legendaries across
# 13 bosses, beating boss #1 unlocks the first legendary, boss #2 the next,
# and so on (one boss along the way unlocks two at once since 14 doesn't
# divide evenly into 13). See compute_legendary_thresholds! below - this is
# computed generically from whatever's in LEGENDARY_NPCS, not hardcoded, so
# adding/removing a species just re-spreads the thresholds automatically.
#
# Each legendary is a fixed-position overworld NPC (classic Zapdos/Articuno/
# Moltres/Mewtwo style): interact with it, pbWildBattle fires (catch it,
# beat it, or flee - ordinary wild-battle rules, no special escape handling
# needed since it's already a normal, non-trainer wild encounter). After
# that first encounter it can keep randomly reappearing on the same map on
# later visits (LEGENDARY_RESPAWN_CHANCE per map load) for a rematch/another
# catch attempt, per the confirmed design.
#
# NOTE on how the repeat-encounter mechanic works: an earlier version of this
# tried to add a permanent low-chance slot into GameData::Encounter (the
# normal wild-encounter table) so the species would turn up via ordinary
# step-based encounters. That was dropped - it silently does nothing on any
# map whose tiles aren't actually tagged with matching encounter terrain
# (checked against this project's own PBS/encounters.txt: Pokemon Tower F7,
# Birth Island and the Champion's room all have ZERO vanilla wild data,
# meaning no confirmed grass/cave terrain to trigger on), and verifying
# real terrain per map would mean inspecting all 15+ tilesets directly.
# Instead, every legendary here just re-spawns its own NPC event directly
# (via Events.onMapCreate, same as GymBossPlacement's corner bosses) - fully
# terrain-independent, so it works identically indoors or outdoors.
#
# DBZ's list and every one of its BASE locations come from DBZ Infinite
# Fusion's own official "Legendary Fighters" guide (user-supplied), remapped
# onto this base game's real Kanto map IDs (Data/MapInfos.rxdata) and then
# swapped to a nearby SIBLING map ID wherever the guide's exact floor turned
# out to have no vanilla wild-encounter data of its own (Mt. Ember: 774->752,
# Cerulean Cave: 324->323, Diglett's Cave: 398/399 don't really exist as
# separate wild floors -> both legendaries share the real cave, 140,
# Shenron's Pokemon Tower floor: 469->403) - each was cross-checked against
# PBS/encounters.txt to confirm the substituted floor is a real, populated
# encounter map, not a story-only room.
# Six Island / Seven Island / the "Null Realm" don't exist as real maps in
# this base game at all (no Sevii Islands here) - those got a thematic
# substitute per the user's go-ahead ("for the others I'd say pick a
# thematic spot"): Black + Zamasu -> Victory Road (two floors), Omega
# Shenron -> Diglett's Cave, and the Champa/Vados/Daishinkan/Zeno chain
# (was: sequentially unlocked in the "Null Realm") -> the Champion's room,
# where their own individual dex-order thresholds already keep them
# unlocking in that same relative order, so no extra chain logic is needed.
# "Super Shenron" (Lvl 70, mid-chain in the guide) does NOT exist anywhere
# in this mod's pokemon.txt - checked every "Shenron"-named entry (11 total:
# base Shenron + the 10 Shadow Dragons) and every "Super *"/"*Dragon" name
# in the whole 674-species file. It isn't skipped by mistake - it just isn't
# in this dex under any name, so it's left out.
#
# Animon's list has no equivalent guide - it's the 7 species the user named
# directly, placed at the real Kanto locations the user described ("end of
# Route 12", "mountain peak" -> Mt. Ember (shared with Broly), "lost cave/
# Route 15 dungeon equivalent" -> Diglett's Cave (shared with Omega
# Shenron), "haki cave near Route 15 equivalent" -> Victory Road (shared
# with Black/Zamasu's floor)). Levels are my own estimate EXCEPT Saitama's
# (Lvl 80), sourced from Animon's own LOCATIONS.csv ("LV 80 SAITAMA
# REPLACING MEWTWO").
# Beerus moved here from the DBZ list (was going to be an 8th, redundant DBZ
# entry sharing Cerulean Cave with Saitama anyway) - Beerus only exists as a
# single DBZ-dex-block species (691) with no separate Animon entry, but
# putting it on the Animon side breaks a tie that otherwise had two DBZ
# legendaries (Whis/Goku Black) both unlocking at boss #7, and gives Animon
# a nice low-dex "first legendary" slot instead. Same map, same spot.
#
# No overworld sprite exists anywhere in this project for any of these 22
# species (checked both this mod's and DBZ Infinite Fusion's own Graphics
# folders - only battle sprites exist, no walking character sheets). Every
# entry below uses the base game's own generic Graphics/Characters/shadow.png
# as a stand-in "sensed but not yet seen" placeholder until real art exists;
# swap :graphic per entry any time without touching the rest of this file.
#
# Placement coordinates are NOT hand-verified against each map's passability
# data (that would mean opening and walking all these tilemaps) - every NPC
# spawns at its map's center tile, offset by :dx/:dy where two legendaries
# share a map so they don't stack on the same tile. Set :x/:y on an entry
# to override the auto-centered position once you know the real spot.
#==============================================================================
#------------------------------------------------------------------------------
# "The player can always succeed at escaping these battles" - checked the
# actual engine code (Data/Scripts/011_Battle/003_Battle/008_Battle_Action_
# Running.rb): running from an ordinary wild battle is NOT a flat guarantee
# by default, it's a speed-ratio roll (rate = playerSpeed*128/enemySpeed,
# +30 per repeated attempt this battle) - against a level-45-80 legendary
# that could take a couple of tries, so it needed an actual fix, not just an
# ordinary wild encounter left as-is.
# pbWildBattle already supports a "cannotRun" rule (allow/disallow running
# at all), but setBattleRule's rule names are a closed whitelist (see
# recordBattleRule in 001_Overworld_BattleStarting.rb - anything not on the
# list raises "Battle rule does not exist"), so there's no way to smuggle a
# custom "always succeeds" flag through it. Using a plain $PokemonGlobal
# flag instead, set true immediately before the battle and always reset in
# an ensure block right after (never left dangling onto some later,
# unrelated battle). pbRun is aliased so a legendary battle short-circuits
# straight to the normal "You got away safely!" success path, before the
# speed check ever runs.
#------------------------------------------------------------------------------
# `afm_guaranteed_run` was read/written below but never declared as an
# accessor on PokemonGlobalMetadata - crashed with NoMethodError the instant
# ANY battle's Run command was pressed (not just legendary ones, since pbRun
# is aliased on PokeBattle_Battle globally), found via a live playtest crash.
class PokemonGlobalMetadata
  attr_accessor :afm_guaranteed_run
  alias afm_original_initialize initialize unless method_defined?(:afm_original_initialize)
  def initialize
    afm_original_initialize
    @afm_guaranteed_run = false
  end
end

class PokeBattle_Battle
  alias_method :afm_original_pbRun, :pbRun unless method_defined?(:afm_original_pbRun)
  def pbRun(idxBattler, duringBattle = false)
    if $PokemonGlobal.afm_guaranteed_run
      pbSEPlay("Battle flee")
      pbDisplayPaused(_INTL("You got away safely!"))
      @decision = 3
      return 1
    end
    afm_original_pbRun(idxBattler, duringBattle)
  end
end

module AnimeFusionMerge
  LEGENDARY_RESPAWN_CHANCE = 20 # % chance per map visit, after the first encounter

  LEGENDARY_NPCS = {
    752 => [ # Mt. Ember (Moltres spot / "mountain peak")
      { id: :dbz_leg_broly, game: :dbz, species: :BROLY, level: 45 },
      { id: :animon_leg_minato, game: :animon, species: :MINATO, level: 60, dx: 1 },
    ],
    808 => [ # Seafoam Islands B1 (Articuno spot)
      { id: :dbz_leg_bojack, game: :dbz, species: :BOJACK, level: 45 },
      { id: :animon_leg_obelisk, game: :animon, species: :OBELISK, level: 60, dx: 1 },
    ],
    144 => [ # Power Plant (Zapdos spot)
      { id: :dbz_leg_hatchiyack, game: :dbz, species: :HATCHIYACK, level: 45 },
    ],
    437 => [ # Route 13 pier (Snorlax-adjacent spot)
      { id: :dbz_leg_hirudegarn, game: :dbz, species: :HIRUDEGARN, level: 45 },
    ],
    403 => [ # Pokemon Tower F4 (God's Tower / Dragonballs spot - moved off F7, no wild data there)
      { id: :dbz_leg_shenron, game: :dbz, species: :SHENRON, level: 60 },
    ],
    # The 9 Shadow Dragons (the rest of the Dragon Balls' one-star through
    # seven-star + the two "evil energy" dragons), per the user's original
    # DBZ scope call ("include shadow dragons, but not villains") - these
    # were confirmed present in pokemon.txt but never actually got placed as
    # encounters until now. No guide gives them individual locations/levels
    # (DBZIF's own guide only calls out Shenron and Omega Shenron by name),
    # so they're clustered thematically near Shenron's own floor - two more
    # proven-wild-data Pokemon Tower floors that nothing else here uses yet -
    # with my own estimated levels stepping up from Shenron(60) to just
    # under Omega Shenron(70).
    402 => [ # Pokemon Tower F3 (Shadow Dragons cluster #1)
      { id: :dbz_leg_sushenron, game: :dbz, species: :SUSHENRON, level: 61, dx: -2 },
      { id: :dbz_leg_sanshenron, game: :dbz, species: :SANSHENRON, level: 62, dx: -1 },
      { id: :dbz_leg_lishenron, game: :dbz, species: :LISHENRON, level: 63 },
      { id: :dbz_leg_spshenron, game: :dbz, species: :SPSHENRON, level: 64, dx: 1 },
      { id: :dbz_leg_hzeshenron, game: :dbz, species: :HZESHENRON, level: 65, dx: 2 },
    ],
    467 => [ # Pokemon Tower F5 (Shadow Dragons cluster #2)
      { id: :dbz_leg_blshenron, game: :dbz, species: :BLSHENRON, level: 66, dx: -2 },
      { id: :dbz_leg_naturonshenron, game: :dbz, species: :NATURONSHENRON, level: 67, dx: -1 },
      { id: :dbz_leg_eisshenron, game: :dbz, species: :EISSHENRON, level: 68 },
      { id: :dbz_leg_nuovashenron, game: :dbz, species: :NUOVASHENRON, level: 69, dx: 1 },
    ],
    306 => [ # Victory Road (Six Island/Gowasu spot #1)
      { id: :dbz_leg_black, game: :dbz, species: :GOKUBLACK, level: 60 },
    ],
    307 => [ # Victory Road, other floor (Six Island/Gowasu spot #2)
      { id: :dbz_leg_zamasu, game: :dbz, species: :ZAMASU, level: 60 },
      { id: :animon_leg_shanks, game: :animon, species: :SHANKS, level: 60, dx: 1 },
    ],
    323 => [ # Cerulean Cave (Mewtwo spot - moved off the innermost floor, no wild data there)
      { id: :animon_leg_beerus, game: :animon, species: :BEERUS, level: 70 },
      { id: :animon_leg_saitama, game: :animon, species: :SAITAMA, level: 80, dx: 1 },
    ],
    607 => [ # Birth Island (Aurora Ticket puzzle spot)
      { id: :dbz_leg_whis, game: :dbz, species: :WHIS, level: 70 },
    ],
    140 => [ # Diglett's Cave (Seven Island/Dancing Man spot + Animon's "lost cave")
      { id: :dbz_leg_omegashenron, game: :dbz, species: :OMEGASHENRON, level: 70 },
      { id: :animon_leg_rageshield, game: :animon, species: :RAGESHIELD, level: 60, dx: 1 },
    ],
    159 => [ # Route 12 (end of route)
      { id: :animon_leg_itachi, game: :animon, species: :ITACHI, level: 60 },
    ],
    468 => [ # Pokemon Tower F6 ("king of heroes" spot)
      { id: :animon_leg_gilgamesh, game: :animon, species: :GILGAMESH, level: 60 },
    ],
    16  => [ # Route 6 (post-League Broly R rematch spot)
      { id: :dbz_leg_brolyr, game: :dbz, species: :BROLYR, level: 45 },
    ],
    # Champion's room - the relocated "Null Realm" chain. Their dex-order
    # unlock thresholds (763/764/765/766, all late in the DBZ list) already
    # keep them appearing in Champa -> Vados -> Daishinkan -> Zeno order,
    # same as the original guide's own sequential chain.
    328 => [
      { id: :dbz_leg_champa, game: :dbz, species: :CHAMPA, level: 70 },
      { id: :dbz_leg_vados, game: :dbz, species: :VADOS, level: 75, dx: 1 },
      { id: :dbz_leg_daishinkan, game: :dbz, species: :DAISHINKAN, level: 80, dx: -1 },
      { id: :dbz_leg_zeno, game: :dbz, species: :ZENOH, level: 80, dx: 2 },
    ],
  }.freeze

  def self.legendary_lookup
    return @legendary_lookup if @legendary_lookup
    @legendary_lookup = {}
    LEGENDARY_NPCS.each_value { |list| list.each { |d| @legendary_lookup[d[:id]] = d } }
    @legendary_lookup
  end

  # Sorts each game's legendaries by their own Pokedex ID and spreads them
  # evenly across that game's 13-boss ladder: entry i (0-indexed) of N
  # unlocks once ceil((i+1)*13/N) of that game's bosses have been beaten.
  # Mutates each entry hash in place (:unlock_at) - runs once, right after
  # LEGENDARY_NPCS is defined, since GameData::Species is already fully
  # loaded by the time this mod's own scripts run (Bootstrap.rb's
  # AnimeFusionMerge.install call happens before this file loads at all).
  def self.compute_legendary_thresholds!
    by_game = Hash.new { |h, k| h[k] = [] }
    legendary_lookup.each_value { |d| by_game[d[:game]] << d }
    total_bosses = 13
    by_game.each_value do |list|
      list.sort_by! { |d| GameData::Species.exists?(d[:species]) ? GameData::Species.get(d[:species]).id_number : 0 }
      n = list.length
      list.each_with_index do |d, i|
        d[:unlock_at] = ((i + 1) * total_bosses.to_f / n).ceil
      end
    end
  end
  compute_legendary_thresholds!

  # Called by GymBossPlacement.trigger_boss_battle right after a win changes
  # that game's beaten-boss count, so newly-crossed thresholds get a flavor
  # message instead of the legendary just silently appearing next time the
  # player happens to walk onto its map.
  def self.announce_new_legendary_unlocks(game, before_count, after_count)
    legendary_lookup.each_value do |d|
      next unless d[:game] == game
      next unless d[:unlock_at] > before_count && d[:unlock_at] <= after_count
      name = GameData::Species.exists?(d[:species]) ? GameData::Species.get(d[:species]).name : d[:species].to_s
      pbMessage(_INTL("A powerful presence stirs somewhere out there... ({1} has awakened)", name))
    end
  end

  def self.trigger_legendary_encounter(id)
    data = legendary_lookup[id]
    return unless data
    return unless GameData::Species.exists?(data[:species])
    $PokemonGlobal.afm_guaranteed_run = true # see the PokeBattle_Battle#pbRun override above
    begin
      pbWildBattle(data[:species], data[:level])
    ensure
      $PokemonGlobal.afm_guaranteed_run = false
    end
    $PokemonGlobal.afm_legendary_seen ||= {}
    $PokemonGlobal.afm_legendary_seen[id] = true
  end

  def self.make_legendary_event(event_id, x, y, data)
    event = RPG::Event.new(x, y)
    event.id = event_id
    event.name = "AFM_#{data[:id]}"
    page = event.pages[0]
    page.trigger = 0 # Action Button
    page.graphic.character_name = data[:graphic] || "shadow"
    page.graphic.character_hue = 0
    page.graphic.direction = 2
    page.move_type = 0
    page.through = false
    page.list = [
      RPG::EventCommand.new(355, 0, ["AnimeFusionMerge.trigger_legendary_encounter(:#{data[:id]})"]),
      RPG::EventCommand.new(0, 0, []),
    ]
    event
  end

  def self.inject_legendary_npcs(map_id, map)
    list = LEGENDARY_NPCS[map_id]
    return unless list
    $PokemonGlobal.afm_legendary_seen ||= {}
    next_id = (map.events.keys.max || 0)
    cx = (map.width || 20) / 2
    cy = (map.height || 20) / 2
    list.each do |data|
      next unless boss_beaten_count(data[:game]) >= data[:unlock_at]
      seen = $PokemonGlobal.afm_legendary_seen[data[:id]]
      next if seen && rand(100) >= LEGENDARY_RESPAWN_CHANCE
      x = data[:x] || (cx + (data[:dx] || 0))
      y = data[:y] || (cy + (data[:dy] || 0))
      x = 1 if x < 0
      y = 1 if y < 0
      x = map.width - 2 if map.width && x >= map.width
      y = map.height - 2 if map.height && y >= map.height
      next_id += 1
      map.events[next_id] = make_legendary_event(next_id, x, y, data)
    end
  end
end

Events.onMapCreate += proc { |_sender, e|
  map_id, map = e[0], e[1]
  AnimeFusionMerge.inject_legendary_npcs(map_id, map)
}
