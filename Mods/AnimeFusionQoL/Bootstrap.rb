#==============================================================================
# Anime Fusion QoL
# A bundle of small, additive quality-of-life changes. Everything here aliases
# existing methods or subscribes to existing hooks - no core PBS/script files
# are edited and no DATA is cleared.
#==============================================================================
module AnimeFusionQoL
  MOD_ID = "AnimeFusionQoL"

  def self.setting(key)
    settings = $mod_manager_settings && $mod_manager_settings[MOD_ID]
    return settings ? settings[key] : nil
  end

  #----------------------------------------------------------------------------
  # Feature: split added species' encounters evenly across day/dawn/dusk
  # ("dawn"/"dusk" map to this engine's LandMorning/LandEvening etc. - there's
  # no literal Dawn/Dusk encounter type). Only species registered by
  # AnimeFusionMerge are touched; vanilla wild tables are left alone. Runs
  # before enforce_min_encounter_chance so the resulting thirds also get
  # floored up to the 5% minimum.
  #----------------------------------------------------------------------------
  # GHOST/QOL: Night was missing from every family here - added (fusion)
  # species never got redistributed into it, so they never appeared at night,
  # and routes whose vanilla data has no Night table at all never got one
  # synthesized either. Added below so added species land in all 4 periods.
  TIME_SPLIT_FAMILIES = {
    :Land  => [:LandDay, :LandMorning, :LandEvening, :LandNight],
    :Cave  => [:CaveDay, :CaveMorning, :CaveEvening, :CaveNight],
    :Water => [:WaterDay, :WaterMorning, :WaterEvening, :WaterNight]
  }

  def self.split_added_species_across_times
    added = defined?(AnimeFusionMerge) ? AnimeFusionMerge.added_species : []
    return if !added || added.empty?
    added_set = {}
    added.each { |s| added_set[s] = true }
    GameData::Encounter.each do |enc|
      TIME_SPLIT_FAMILIES.each_pair do |base_type, variants|
        # GHOST/QOL: this used to only scan `variants` (the 4 Day/Morning/
        # Evening/Night keys) and never `base_type` itself - but
        # AnimeFusionMerge appends new species (e.g. Route 1's BEARTHIEF/
        # SAIBAMAN) under the plain :Land key, not a time-split one. The
        # runtime encounter resolver (find_valid_encounter_type_for_time)
        # only falls back to :Land if NONE of the time variants exist for
        # the map, so anything stuck under :Land while :LandDay etc. also
        # exist was simply never rolled - added species registered with
        # zero errors but could never spawn. Now base_type is scanned and
        # cleared right alongside the variants.
        # If the map has no time-split variants at all (a flat map, e.g. an
        # indoor/cave area with only a plain :Land table), leave added
        # species right where they are - :Land is exactly what the resolver
        # falls back to there, and forcibly splitting them into Day/Morning/
        # Evening/Night would time-gate species that used to always be
        # available.
        next unless variants.any? { |vtype| enc.types[vtype] }
        types_to_scan = variants + [base_type]
        totals = {}
        types_to_scan.each do |vtype|
          slots = enc.types[vtype]
          next if !slots
          slots.each do |slot|
            next if !added_set[slot[1]]
            key = [slot[1], slot[2], slot[3]]
            totals[key] = (totals[key] || 0) + slot[0]
          end
        end
        next if totals.empty?
        types_to_scan.each do |vtype|
          slots = enc.types[vtype]
          slots.reject! { |slot| added_set[slot[1]] } if slots
        end
        totals.each do |key, total|
          species, min_lv, max_lv = key
          share = [(total.to_f / variants.length).round, 1].max
          variants.each do |vtype|
            enc.types[vtype] ||= []
            enc.types[vtype] << [share, species, min_lv, max_lv]
          end
        end
      end
    end
    echoln("[AnimeFusionQoL] Split added species across day/morning/evening/night")
  end

  #----------------------------------------------------------------------------
  # Feature: 5% minimum wild encounter chance
  # One-time normalization pass over the compiled encounter data. Any slot
  # below 5% of its type's total is bumped up to 5%, then the type is
  # rescaled back to sum to 100 (proportionally, skipping the floored slots).
  #----------------------------------------------------------------------------
  def self.enforce_min_encounter_chance
    GameData::Encounter.each do |enc|
      enc.types.each do |_type, slots|
        next if !slots || slots.length == 0
        total = slots.sum { |s| s[0] }
        next if total <= 0
        min_chance = (total * 0.05).ceil
        floored = slots.select { |s| s[0] < min_chance }
        next if floored.empty?
        raised_total = floored.length * min_chance
        remaining_total = total - floored.sum { |s| s[0] }
        remainder_slots = slots - floored
        available = total - raised_total
        if remainder_slots.empty? || available <= 0 || remaining_total <= 0
          floored.each { |s| s[0] = min_chance }
          next
        end
        scale = available.to_f / remaining_total
        remainder_slots.each { |s| s[0] = [(s[0] * scale).round, 1].max }
        floored.each { |s| s[0] = min_chance }
      end
    end
    echoln("[AnimeFusionQoL] Enforced 5%% minimum encounter chance")
  end

  #----------------------------------------------------------------------------
  # Feature: hide caught species from wild encounters (toggleable)
  #----------------------------------------------------------------------------
  def self.caught_hidden_slots(slots)
    return slots if !setting("disable_caught_encounters")
    remaining = slots.select { |s| !$Trainer || !$Trainer.owned?(s[1]) }
    return remaining.empty? ? slots : remaining
  end

  #----------------------------------------------------------------------------
  # Feature: buy for 1, sell for regular price
  # Narrowed to just Poke Balls (per user request) - forcing every item to 1
  # while KantoReloaded's shop/economy system is loaded would silently zero
  # out its entire catalog, since that mod reads every buy price through this
  # same adapter method. Poke Balls are cheap/low-stakes enough to override
  # unconditionally even with KantoReloaded active.
  #----------------------------------------------------------------------------
  def self.buy_price(item)
    item_id = item.respond_to?(:id) ? item.id : item
    return 1 if item_id == :POKEBALL
    return nil if defined?(KantoReloaded::ReloadedShop)
    return 1
  end

  #----------------------------------------------------------------------------
  # Feature: max IVs/EVs on catch
  #----------------------------------------------------------------------------
  def self.maximize(pkmn)
    return if !pkmn
    GameData::Stat.each_main { |s| pkmn.ivMaxed[s.id] = true }
    GameData::Stat.each_main { |s| pkmn.ev[s.id] = Pokemon::EV_STAT_LIMIT }
    pkmn.calc_stats
  end

  #----------------------------------------------------------------------------
  # Feature: evolution requirements popup (Pokedex, page 1, ACTION button)
  #----------------------------------------------------------------------------
  def self.describe_evolution_method(method_id, param)
    name = method_id.to_s.gsub(/([a-z0-9])([A-Z])/, '\1 \2')
    return name if param.nil?
    if GameData::Item.exists?(param)
      return "#{name} (#{GameData::Item.get(param).name})"
    elsif GameData::Species.exists?(param)
      return "#{name} (#{GameData::Species.get(param).name})"
    else
      return "#{name} (#{param})"
    end
  end

  def self.show_evolution_requirements(species)
    return if !species || !GameData::Species.exists?(species)
    sp = GameData::Species.get(species)
    lines = []
    sp.evolutions.each do |evo|
      target, method, param, is_prevo = evo
      next if !GameData::Species.exists?(target)
      desc = describe_evolution_method(method, param)
      if is_prevo
        lines << _INTL("Evolves from {1}: {2}", GameData::Species.get(target).name, desc)
      else
        lines << _INTL("Evolves into {1}: {2}", GameData::Species.get(target).name, desc)
      end
    end
    lines = [_INTL("This Pokémon does not evolve.")] if lines.empty?
    pbMessage(lines.join("\n"))
  end

  #----------------------------------------------------------------------------
  # Feature: on-screen encounter HUD
  #----------------------------------------------------------------------------
  def self.build_encounter_text
    return nil if !$PokemonEncounters
    tables = $PokemonEncounters.encounter_tables
    # GHOST/QOL: this used to return nil (= HUD renders nothing at all) any
    # time there was no active encounter type, which is indistinguishable
    # on-screen from the HUD being broken. Standing on a decorative
    # grass/bush tile whose terrain tag isn't actually flagged as a wild
    # encounter tile is common and not a bug - now say so explicitly instead
    # of silently showing nothing, so "no spawns here" and "HUD is broken"
    # don't look identical to the player.
    return _INTL("No wild encounters on this map.") if !tables || tables.empty?
    # GHOST/QOL: used to iterate every type key present on the map (Day,
    # Morning, Evening, Night, plus the base type) all at once, which is why
    # the HUD looked "duplicated" (same species listed under near-identical
    # sections) and got cut off before reaching Night - the window has no
    # scrolling. The actual game only ever rolls ONE of those per encounter
    # (see PokemonEncounters#encounter_type), so only show that one, plus
    # the fishing rod tables (those aren't time-gated and are always
    # separately relevant near water).
    types_to_show = []
    active = $PokemonEncounters.encounter_type rescue nil
    types_to_show << active if active
    [:OldRod, :GoodRod, :SuperRod, :RockSmash].each do |t|
      types_to_show << t if $PokemonEncounters.has_encounter_type?(t)
    end
    types_to_show.uniq!
    return _INTL("Not in a wild encounter area right now.") if types_to_show.empty?
    lines = []
    types_to_show.each do |type|
      slots = tables[type]
      next if !slots || slots.length == 0
      # GHOST/QOL: the HUD used to always read the raw table, so a species
      # the "hide caught species" feature was correctly excluding from
      # actual rolls (see caught_hidden_slots) still showed up here with a
      # percentage - looking exactly like the feature wasn't working at all.
      slots = caught_hidden_slots(slots) if setting("disable_caught_encounters")
      total = slots.sum { |s| s[0] }
      next if total <= 0
      lines << _INTL("[{1}]", type.to_s)
      # Sort by chance (desc) rather than raw array order - added species get
      # appended to the end of the slots array by AnimeFusionMerge/QoL's
      # time-split logic, so a plain first(N) would always hide them.
      sorted_slots = slots.sort_by { |s| -s[0] }
      sorted_slots.first(10).each do |slot|
        pct = (slot[0].to_f / total * 100).round(1)
        name = GameData::Species.exists?(slot[1]) ? GameData::Species.get(slot[1]).name : slot[1].to_s
        lines << _INTL("{1}  {2}%", name, pct)
      end
    end
    return _INTL("No wild encounters on this map.") if lines.empty?
    lines.join("\n")
  end

  class EncounterHUD
    # Smaller font + tighter line spacing than the default (32px @lineHeight
    # is sized for full dialog text) so more slots fit before the window's
    # own height cap kicks in - the old 16px/32px combo was still clipping
    # the last encounter-type section mid-text instead of just at the screen
    # edge, since resizeToFit2 caps the window box but doesn't scroll
    # overflow content.
    HUD_FONT_SIZE = 14
    HUD_LINE_HEIGHT = 20
    HUD_TOP_Y = 16

    # persist: skip the 6-second auto-hide timer (used for the pause-menu
    # popup, which should stay up for as long as the menu is open instead of
    # vanishing mid-browse).
    def initialize(persist = false)
      @persist = persist
      text = AnimeFusionQoL.build_encounter_text
      if !text
        @sprite = nil
        return
      end
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 99998
      @window = Window_AdvancedTextPokemon.newWithSize(text, 0, 0, 32, 32, @viewport)
      @window.contents.font.size = HUD_FONT_SIZE
      @window.lineHeight(HUD_LINE_HEIGHT)
      # resizeToFit2 (unlike resizeToFit) caps both dimensions, so the box can
      # never grow past the screen. Widened from Graphics.width/3 and raised
      # from Graphics.height - 64 now that the window starts higher up
      # (HUD_TOP_Y) - "can be larger" per user, and Night was added to the
      # per-type split so there's now a 4th section needing more room.
      @window.resizeToFit2(text, (Graphics.width * 0.42).to_i, Graphics.height - HUD_TOP_Y - 8)
      @window.x = 0
      @window.y = HUD_TOP_Y
      @currentmap = $game_map.map_id
      @frames = 0
    end

    def disposed?
      @window.nil? || @window.disposed?
    end

    def dispose
      @window&.dispose
      @viewport&.dispose
    end

    def update
      return if disposed?
      if $game_temp.message_window_showing || @currentmap != $game_map.map_id
        dispose
        return
      end
      return if @persist
      @frames += 1
      dispose if @frames > Graphics.frame_rate * 6
    end
  end

  def self.install
    split_added_species_across_times
    enforce_min_encounter_chance

    Events.onMapSceneChange += proc { |_sender, e|
      scene = e[0]
      mapChanged = e[1]
      next if !scene || !scene.spriteset || !mapChanged
      next if !setting("show_encounter_hud")
      scene.spriteset.addUserSprite(EncounterHUD.new)
    }
  end
end

AnimeFusionQoL.install

#==============================================================================
# Aliases (kept minimal, each wraps a single existing method)
#==============================================================================
class PokemonEncounters
  attr_reader :encounter_tables

  alias animefusionqol_choose_wild_pokemon choose_wild_pokemon
  def choose_wild_pokemon(enc_type, chance_rolls = 1)
    old_slots = @encounter_tables[enc_type]
    if old_slots && AnimeFusionQoL.setting("disable_caught_encounters")
      @encounter_tables[enc_type] = AnimeFusionQoL.caught_hidden_slots(old_slots)
    end
    ret = animefusionqol_choose_wild_pokemon(enc_type, chance_rolls)
    @encounter_tables[enc_type] = old_slots if old_slots
    ret
  end
end

class PokemonPauseMenu_Scene
  # Feature: show the encounter-odds HUD while the pause menu is open, so the
  # player can check current spawn rates on demand instead of only getting a
  # brief popup on map entry. $scene stays the live Scene_Map for the whole
  # nested pause-menu loop (see pbUpdateSceneMap in 001_UI_PauseMenu.rb), so
  # its spriteset is reachable and still ticking here.
  alias animefusionqol_pbStartScene pbStartScene
  def pbStartScene
    animefusionqol_pbStartScene
    @animefusionqol_hud = nil
    if AnimeFusionQoL.setting("show_encounter_hud") && $scene && $scene.respond_to?(:spriteset) && $scene.spriteset
      @animefusionqol_hud = AnimeFusionQoL::EncounterHUD.new(true)
      $scene.spriteset.addUserSprite(@animefusionqol_hud)
    end
  end

  alias animefusionqol_pbEndScene pbEndScene
  def pbEndScene
    @animefusionqol_hud.dispose if @animefusionqol_hud && !@animefusionqol_hud.disposed?
    animefusionqol_pbEndScene
  end
end

class PokemonMartAdapter
  alias animefusionqol_getPrice getPrice
  def getPrice(item, selling = false)
    return animefusionqol_getPrice(item, selling) if selling
    forced = AnimeFusionQoL.buy_price(item)
    return forced if forced
    return animefusionqol_getPrice(item, selling)
  end
end

module PokeBattle_BattleCommon
  alias animefusionqol_pbRecordAndStoreCaughtPokemon pbRecordAndStoreCaughtPokemon
  def pbRecordAndStoreCaughtPokemon
    @caughtPokemon.each { |pkmn| AnimeFusionQoL.maximize(pkmn) } if @caughtPokemon
    animefusionqol_pbRecordAndStoreCaughtPokemon
  end
end

class PokemonPokedexInfo_Scene
  alias animefusionqol_pbUpdate pbUpdate
  def pbUpdate
    animefusionqol_pbUpdate
    if @page == 1 && Input.trigger?(Input::ACTION)
      pbPlayDecisionSE
      AnimeFusionQoL.show_evolution_requirements(@species)
    end
  end
end
