# IMPORTANT!!
# If you are using Roaming Pokémon, it is necessary to add
# next if $game_temp.overworld_encounter
# after each mention of: next if $PokemonGlobal.roamedAlready
# otherwise Overworld Encounters can trigger Roaming Battles

class VOESettings
  BLACK_LIST_MAPS = [1, 2, 3, 4, 5, 19, 20, 21, 22, 23, 24, 25, 37, 42, 43, 44, 48, 49, 50,
60, 61, 62, 63, 64, 65, 67, 68, 69, 70, 71, 73, 76, 77, 79, 80, 81,
83, 84, 85, 87, 91, 93, 95, 98, 100, 108, 109, 110, 111, 119, 120,
121, 122, 125, 130, 131, 134, 135, 136, 137, 138, 141, 149, 152,
153, 156, 167, 168, 169, 170, 176, 177, 180, 182,
183, 184, 188, 189, 190, 191, 194, 196, 199, 200, 204, 205,
206, 207, 208, 209, 212, 215, 219, 221, 226, 230, 237, 239, 241,
242, 243, 244, 245, 246, 247, 249, 250, 251, 257, 264, 268, 269,
270, 272, 273, 274, 275, 278, 280, 281, 282, 289, 292, 293, 294,
296, 297, 298, 305, 309, 310, 325, 326, 327, 329, 330, 331, 332,
334, 337, 338, 357, 359, 360, 363, 366, 367, 368, 370, 371, 377,
379, 380, 386, 387, 388, 389, 391, 392, 393, 394, 395, 405, 408,
414, 416, 419, 420, 421, 426, 430, 447, 448, 450, 451, 452, 453,
454, 458, 459, 460, 461, 462, 463, 464, 465, 466, 470, 472, 476,
477, 478, 479, 481, 482, 498, 499, 500, 501, 502, 503, 504, 510,
514, 519, 520, 521, 524, 530, 532, 541, 551, 552, 553, 567, 568,
571, 572, 574, 575, 576, 577, 579, 582, 583, 584, 611, 613, 621,
622, 623, 625, 631, 632, 643, 644, 647, 648, 649, 650, 651, 652,
653, 660, 661, 662, 663, 665, 666, 667, 668, 671, 672, 673, 674,
675, 676, 677, 696, 697, 701, 702, 703, 704, 709, 710, 711, 712,
713, 714, 716, 720, 721, 722, 723, 730, 734, 735, 736, 737, 738,
740, 744, 745, 747, 757, 758, 770, 771, 772, 786, 787, 789, 795,
807, 810, 811, 812, 813, 814, 815, 816, 820, 833, 834, 838, 839,
840, 841, 842, 843, 844, 845, 846, 847, 848, 849]
  BLACK_LIST_WATER = [96]
  REFLECTION_MAP_IDS = [70, 103, 105]

  GRASS_TILES = [
    :Grass, :TallGrass, :DeepSand, :SpringGrass, :SpringTallGrass, :SummerGrass, :SummerTallGrass,
    :AutumnGrass, :AutumnTallGrass, :WinterGrass, :WinterTallGrass, :SpringRockyGrass, :SummerRockyGrass,
    :AutumnRockyGrass, :WinterRockyGrass, :SpringForestGrass, :SummerForestGrass, :AutumnForestGrass,
    :WinterForestGrass, :Grass_alt1, :Grass_alt2, :Grass_alt3, :SootGrass, :UnderwaterGrass,
  ]
  WATER_TILES = [
    :Water, :StillWater, :DeepWater, :WaterCurrent, :Waterfall, :WaterfallCrest,
    :Dirty_Water, :SpringWater, :SummerWater, :AutumnWater, :WinterWater
  ]

  FLEE_SOUND = "Door exit"
  SHINY_SOUND = "Mining reveal"
  
  # How many encounters will be spawned on each map (mapId => numberOfEvents) (0 = default)
  MAX_PER_MAP = {
    # 42 => 0,
    # 57 => 3,
    0 => 5,
  }

  MOD_ID = "overworld_encounters"

  SETTING_MAP = {
    :DISABLE_SETTINGS        => { :key => "voe_disable_settings",        :type => :bool },
    :LOG_SPAWNS              => { :key => "voe_log_spawns",              :type => :bool },
    :SHINY_RATE              => { :key => "voe_shiny_rate",              :type => :num },
    :MAX_DISTANCE            => { :key => "voe_max_distance",            :type => :num },
    :DELETE_EVENTS           => { :key => "voe_delete_events",           :type => :bool },
    :DELETE_SHINY            => { :key => "voe_delete_shiny",            :type => :bool },
    :BRIGHT_SHINY            => { :key => "voe_brt_shiny",              :type => :bool },
    :COLORFUL_TEXT           => { :key => "voe_colorful_text",           :type => :bool },
    :WATER_SPAWNS_ONLY_SURFING => { :key => "voe_water_surf_only",      :type => :bool },
    :DIFFERENT_ENCOUNTERS    => { :key => "voe_diff_enc",                :type => :bool },
    :ENCOUNTER_TABLE         => { :key => "voe_enc_table",              :type => :num },
    :SPAWN_ANIMATION         => { :key => "voe_spawn_anim",             :type => :num },
    :SHINY_ANIMATION         => { :key => "voe_shiny_anim",             :type => :num },
    :MAX_ENCOUNTERS          => { :key => "voe_max_encounters",          :type => :num },
    :FUSION_ENCOUNTERS       => { :key => "voe_fusion_encounters",       :type => :bool },
    :FUSION_RATE             => { :key => "voe_fusion_rate",             :type => :num },
    :HORDE_BATTLES           => { :key => "voe_horde_battles",           :type => :bool },
    :HORDE_DISTANCE          => { :key => "voe_horde_distance",          :type => :num },
    :SPAWN_ON_LOAD           => { :key => "voe_spawn_on_load",           :type => :bool },
    :INITIAL_SPAWN_COUNT     => { :key => "voe_initial_spawn_count",     :type => :num },
    :OUTBREAK_ENABLED        => { :key => "voe_outbreak_enabled",        :type => :bool },
    :OUTBREAK_DURATION       => { :key => "voe_outbreak_duration",       :type => :duration },
    :OUTBREAK_TYPE           => { :key => "voe_outbreak_type",           :type => :outbreak_type },
    :OUTBREAK_SHINY_MULT     => { :key => "voe_outbreak_shiny_mult",     :type => :num },
    :OUTBREAK_NO_SHINY_DESPAWN => { :key => "voe_outbreak_no_shiny_despawn", :type => :bool },
    :OUTBREAK_SPAWN_COUNT    => { :key => "voe_outbreak_spawn_count",    :type => :num },
    :OUTBREAK_MAX_OVERRIDE   => { :key => "voe_outbreak_max_override",   :type => :num },
    :OUTBREAK_SPAWN_RATE     => { :key => "voe_outbreak_spawn_rate",     :type => :num },
    :OUTBREAK_RADIUS         => { :key => "voe_outbreak_radius",         :type => :num },
    :SHINY_PANIC_ENABLED     => { :key => "voe_outbreak_shiny_panic",    :type => :bool },
  }

  DEFAULTS = {
    :DISABLE_SETTINGS => false, :LOG_SPAWNS => false, :SHINY_RATE => 8192,
    :MAX_DISTANCE => 8, :DELETE_EVENTS => true, :DELETE_SHINY => false,
    :BRIGHT_SHINY => true, :COLORFUL_TEXT => true, :WATER_SPAWNS_ONLY_SURFING => true,
    :DIFFERENT_ENCOUNTERS => false, :ENCOUNTER_TABLE => 1, :SPAWN_ANIMATION => 2,
    :SHINY_ANIMATION => 2, :MAX_ENCOUNTERS => 5, :FUSION_ENCOUNTERS => true,
    :FUSION_RATE => 10, :HORDE_BATTLES => true, :HORDE_DISTANCE => 2,
    :SPAWN_ON_LOAD => false, :INITIAL_SPAWN_COUNT => 6,
    :OUTBREAK_ENABLED => true, :OUTBREAK_DURATION => 10, :OUTBREAK_TYPE => 0,
    :OUTBREAK_SHINY_MULT => 1, :OUTBREAK_NO_SHINY_DESPAWN => true,
    :OUTBREAK_SPAWN_COUNT => 6, :OUTBREAK_MAX_OVERRIDE => 12,
    :OUTBREAK_SPAWN_RATE => 200, :OUTBREAK_RADIUS => 15, :SHINY_PANIC_ENABLED => true,
  }

  DURATION_MAP = { "5 Minutes" => 5, "10 Minutes" => 10, "15 Minutes" => 15 }
  OUTBREAK_TYPE_MAP = { "Mixed Species" => 0, "Same Species" => 1 }

  def self._read_mm_setting(key)
    return nil unless defined?($mod_manager_settings) && $mod_manager_settings.is_a?(Hash)
    settings = $mod_manager_settings[MOD_ID]
    return nil unless settings.is_a?(Hash)
    return nil unless settings.key?(key)
    settings[key]
  end

  def self._coerce(val, type)
    case type
    when :bool
      return val == true || val == 1
    when :num
      return val if val.is_a?(Numeric)
    when :duration
      return DURATION_MAP[val] if val.is_a?(String) && DURATION_MAP[val]
      return [5, 10, 15][val] if val.is_a?(Integer) && val.between?(0, 2)
      return val if val.is_a?(Numeric)
    when :outbreak_type
      return OUTBREAK_TYPE_MAP[val] if val.is_a?(String) && OUTBREAK_TYPE_MAP.key?(val)
      return val if val.is_a?(Integer)
    end
    nil
  end

  # Dynamic Settings — checks mod manager, then legacy ModSettingsMenu, then defaults
  def self.const_missing(name)
    mapping = SETTING_MAP[name]
    if mapping
      begin
        # 1. Try mod manager settings ($mod_manager_settings)
        mm_val = _read_mm_setting(mapping[:key])
        unless mm_val.nil?
          result = _coerce(mm_val, mapping[:type])
          return result unless result.nil?
        end

        # 2. Try legacy ModSettingsMenu
        if defined?(ModSettingsMenu) && ModSettingsMenu.respond_to?(:get)
          val = ModSettingsMenu.get(mapping[:key].to_sym)
          unless val.nil?
            result = _coerce(val, mapping[:type])
            return result unless result.nil?
          end
        end
      rescue => e
        echoln "[VOE] Error accessing setting #{name}: #{e.message}" if defined?(echoln)
      end
    end

    # 3. Fallback to defaults
    return DEFAULTS[name] if DEFAULTS.key?(name)
    super
  end

  # The amount of encounters currently on the map
  def self.current_encounters
    return 0 unless $game_map

    unless @current_encounters
      count = 0
      $game_map.events.each_value do |event|
        next unless event.name[/OverworldPkmn/i]

        count += 1
      end
      @current_encounters = count
    end
    @current_encounters
  end

  # Setter for the current encounters
  class << self
    attr_writer :current_encounters
  end

  # Star sparkle management
  @sparkles ||= []
  def self.add_sparkle(sparkle); @sparkles << sparkle; end
  def self.update_sparkles
    # echoln "[VOE] Updating #{@sparkles.length} sparkles" if @sparkles.length > 0 && VOESettings::LOG_SPAWNS
    @sparkles.delete_if { |s| s.update }
  end
  def self.clear_sparkles
    @sparkles.each { |s| s.dispose }
    @sparkles.clear
  end

  # Map visit tracking (to prevent respawning if recently visited)
  @map_visit_times ||= {}
  def self.get_map_visit_time(map_id)
    @map_visit_times ||= {}
    return @map_visit_times[map_id] || 0
  end
  
  def self.set_map_visit_time(map_id, time)
    @map_visit_times ||= {}
    @map_visit_times[map_id] = time
  end
  
  def self.map_recently_visited?(map_id, seconds = 20)
    last_visit = get_map_visit_time(map_id)
    return false if last_visit == 0
    time_since_visit = Time.now.to_f - last_visit
    return time_since_visit < seconds
  end

  def self.get_max
    # Use mod settings override if available
    max = MAX_ENCOUNTERS
    return max if max > 0
    
    # Otherwise check per-map settings
    return MAX_PER_MAP[$game_map.map_id] if MAX_PER_MAP[$game_map.map_id]

    MAX_PER_MAP[0]
  end

  def self.terrain_tag_at(x, y, map = $game_map)
    return GameData::TerrainTag.get(:None) unless map
    return map.terrain_tag(x, y)
  rescue
    return GameData::TerrainTag.get(:None)
  end

  def self.water_tag?(terrain_tag)
    tag = GameData::TerrainTag.try_get(terrain_tag)
    return false unless tag
    return true if tag.can_surf || tag.waterfall || tag.waterfall_crest || tag.waterCurrent
    WATER_TILES.include?(tag.id)
  end

  def self.grass_tag?(terrain_tag)
    tag = GameData::TerrainTag.try_get(terrain_tag)
    return false unless tag
    return true if tag.land_wild_encounters || tag.deep_bush || tag.shows_grass_rustle
    GRASS_TILES.include?(tag.id)
  end

  def self.water_tile?(x, y, map = $game_map)
    water_tag?(terrain_tag_at(x, y, map))
  end

  def self.encounter_tile?(x, y, map = $game_map)
    tag = terrain_tag_at(x, y, map)
    return true if grass_tag?(tag)
    return true if water_tag?(tag)
    false
  end
end

# Removed MenuHandlers.add

class Spriteset_Map
  alias voe_update  update unless method_defined?(:voe_update)
  alias voe_dispose dispose unless method_defined?(:voe_dispose)
  
  def dispose
    VOESettings.clear_sparkles
    voe_dispose
  end

  def update
    begin
      voe_update
    rescue => e
      # Swallow animation errors
    end
    
    VOESettings.update_sparkles

    @character_sprites.each do |sprite|
      next unless sprite&.character
      
      # Apply dark silhouette to fusion encounters (nearly black)
      if sprite.character.name&.include?("(Fusion)")
        sprite.tone.set(-255, -255, -255, 255) rescue nil  # Nearly black silhouette
        next  # Skip other processing for fusions
      end
      
      # Bright shinies (unaffected by day/night)
      next unless VOESettings::BRIGHT_SHINY
      if sprite.character.name&.include?("(Shiny)")
        sprite.tone.set(0, 0, 0, 0) rescue nil
      end
    end
  end
end

class PokemonSystem
  attr_accessor :owpkmnenabled # Whether Overworld Pokémon appear (0=on, 1=off)

  def owpkmnenabled=(val); @owpkmnenabled = val; end
  def owpkmnenabled; @owpkmnenabled; end
end

class PokemonOption_Scene
  alias owpkmn_pbEndScene pbEndScene unless method_defined?(:owpkmn_pbEndScene)

  def pbEndScene
    owpkmn_pbEndScene
    # Use VOESettings::DISABLE_SETTINGS which maps to ModSettings
    if VOESettings::DISABLE_SETTINGS
      $game_map.events.each_value do |event|
        next unless event.name[/OverworldPkmn/i]

        pbDestroyOverworldEncounter(event, true, false)
      end
    end
  end
end

# --------------------------------------------------------
# Method from Followers EX Plugin
# --------------------------------------------------------
def pbOWSpriteFilename(species, form = 0, gender = 0, shiny = false, shadow = false, swimming = false)
  species_data = GameData::Species.try_get(species)
  return nil unless species_data
  species_name = species_data.species.to_s
  species_id = species_data.id_number  # Numeric ID like 19 for Rattata
  
  # Build possible folders to check (standard Essentials locations)
  folders_to_check = []
  
  if swimming
    folders_to_check << (shiny ? "Swimming Shiny/" : "Swimming/")
    folders_to_check << (shiny ? "Levitates Shiny/" : "Levitates/")
  end
  folders_to_check << (shiny ? "Followers shiny/" : "Followers/")
  folders_to_check << "Followers/"  # Fallback to non-shiny
  
  # Check standard Graphics/Characters/<folder>/ location with species NAME
  folders_to_check.each do |folder|
    if form > 0
      std_path = "Graphics/Characters/#{folder}#{species_name}_#{form}"
      return "Graphics/Characters/#{folder}#{species_name}_#{form}" if pbResolveBitmap(std_path)
    end
    std_path = "Graphics/Characters/#{folder}#{species_name}"
    return "Graphics/Characters/#{folder}#{species_name}" if pbResolveBitmap(std_path)
  end
  
  # Try with numeric ID format (e.g., 019.png, 019s.png for shiny)
  id_str = format("%03d", species_id)
  id_str_shiny = "#{id_str}s"
  
  path = shiny ? "Graphics/Characters/#{id_str_shiny}" : "Graphics/Characters/#{id_str}"
  return path if pbResolveBitmap(path)
  
  # Non-shiny fallback for numeric
  path = "Graphics/Characters/#{id_str}"
  return path if pbResolveBitmap(path)
  
  # Last resort - just return base path (may fail if sprite doesn't exist)
  return "Graphics/Characters/Followers/#{species_name}"
end

def pbChooseWildPokemonByVersion(map_ID, enc_type, version)
  # Get the encounter table
  encounter_data = GameData::Encounter.get(map_ID, version)
  enc_list = encounter_data.types[enc_type]

  # Calculate the total probability value
  chance_total = 0

  return [:DITTO, 69] if enc_list.nil?
  enc_list.each { |a| chance_total += a[0] }

  # Escolhe o Pokémon aleatoriamente a partir da Tabela de Encontro
  rnd = rand(chance_total)
  encounter = nil
  enc_list.each do |enc|
    rnd -= enc[0]
    next if rnd >= 0

    encounter = enc
    break
  end

  # Return [species, level]
  level = rand(encounter[2]..encounter[3])
  [encounter[1], level]
end

def pbGetTileID(map_id, x, y)
  return 0 if (x == 0 || y == 0) || (x.nil? || y.nil?)
  debug = false

  echoln "[getTileID] #{map_id}, #{x}, #{y}" if debug
  return 0 unless $map_factory
  thistile = $map_factory.getRealTilePos(map_id, x, y)
  map = $map_factory.getMap(thistile[0])
  tile_id = map.data[thistile[1], thistile[2], 0]

  echoln "[getTileID] #{tile_id}" if debug
  return 0 if tile_id == nil
  return GameData::TerrainTag.try_get(map.terrain_tags[tile_id]).id
end

def pbConvertMoveCommands(list)
  list.map do |entry|
    if entry.is_a?(Symbol)
      # Ex: :move_down
      code = VOE_MOVE_COMMANDS[entry]
      RPG::MoveCommand.new(code)
    elsif entry.is_a?(Array)
      # Ex: [:wait, 30] ou [:jump, 1, -1]
      cmd, *params = entry
      code = VOE_MOVE_COMMANDS[cmd]
      RPG::MoveCommand.new(code, params)
    elsif entry.is_a?(Hash)
      # Ex: { :switch_on => 5 }
      cmd = entry.keys.first
      args = [entry[cmd]].flatten
      code = VOE_MOVE_COMMANDS[cmd]
      RPG::MoveCommand.new(code, args)
    else
      entry
    end
  end
end

VOE_MOVE_COMMANDS = {
  move_down: 1,
  move_left: 2,
  move_right: 3,
  move_up: 4,

  move_lower_left: 5,
  move_lower_right: 6,
  move_upper_left: 7,
  move_upper_right: 8,

  move_random: 9,
  move_toward_player: 10,
  move_away_from_player: 11,
  move_forward: 12,
  move_backward: 13,

  jump: 14,                  # Ex: [:jump, 2, 1]
  wait: 15,                  # Ex: [:wait, 60]

  turn_down: 16,
  turn_left: 17,
  turn_right: 18,
  turn_up: 19,

  turn_right_90: 20,
  turn_left_90: 21,
  turn_180: 22,
  turn_90_random: 23,

  turn_random: 24,
  turn_toward_player: 25,
  turn_away_from_player: 26,

  switch_on: 27,             # Ex: { switch_on: "A" }
  switch_off: 28,            # Ex: { switch_off: "A" }
  change_speed: 29,          # Ex: [:change_speed, 4]
  change_freq: 30,           # Ex: [:change_freq, 3]

  walk_anime_on: 31,
  walk_anime_off: 32,
  step_anime_on: 33,
  step_anime_off: 34,
  direction_fix_on: 35,
  direction_fix_off: 36,
  through_on: 37,
  through_off: 38,
  always_on_top_on: 39,
  always_on_top_off: 40,

  change_graphic: 41,        # Ex: [:change_graphic, "Trainer", 2, 1]
  change_opacity: 42,        # Ex: [:change_opacity, 128]
  change_blend: 43,          # Ex: [:change_blend, 1]
  play_se: 44,               # Ex: [:play_se, RPG::AudioFile.new("Jump", 80, 100)]

  script: 45,                # Ex: [:script, "echoln('test!')"]
  end: 0,
}

# ==============================================================================
# OUTBREAK EVENT SYSTEM
# ==============================================================================
module VOEOutbreak
  # Outbreak state
  @active = false
  @end_time = nil
  @locked_species = nil  # For same-species outbreak
  @map_id = nil
  @shiny_mult = 1
  @shiny_panic_end_time = nil
  @next_trigger_time = nil # Time when the next outbreak can occur
  @panic_cleanup_done = false  # Track if shiny panic cleanup already ran
  
  # UI sprites
  @info_sprite = nil
  @timer_sprite = nil
  @timer_bg = nil
  
  class << self
    attr_reader :active, :shiny_mult
    
    def locked_species(enc_type = nil)
      return nil unless @locked_species
      return @locked_species if @locked_species.is_a?(Symbol)
      
      category = :Land
      if [:Water, :WaterDay, :WaterNight, :OldRod, :GoodRod, :SuperRod].include?(enc_type)
        category = :Water
      elsif [:Cave, :CaveDay, :CaveNight].include?(enc_type)
        category = :Cave
      end
      return @locked_species[category] || @locked_species[:Land]
    end
    
    # Base shiny chance as "X out of 65536", matching Kuray's core shiny system.
    def base_shiny_chance_out_of_65536
      if defined?($PokemonSystem) && $PokemonSystem && $PokemonSystem.respond_to?(:shinyodds)
        odds = $PokemonSystem.shinyodds
        return odds.to_i.clamp(1, 65_536) if odds.is_a?(Numeric)
      end
      if defined?(Settings) && Settings.const_defined?(:SHINY_POKEMON_CHANCE)
        odds = Settings::SHINY_POKEMON_CHANCE
        return odds.to_i.clamp(1, 65_536) if odds.is_a?(Numeric)
      end
      # Legacy fallback for projects that use a 1/X denominator setting.
      denom = VOESettings::SHINY_RATE
      denom = 1 if !denom.is_a?(Numeric) || denom < 1
      return (65_536.0 / denom).round.clamp(1, 65_536)
    end

    # Effective shiny chance as "X out of 65536".
    def get_effective_shiny_chance
      return 65_536 if shiny_panic_active?
      chance = base_shiny_chance_out_of_65536
      chance = (chance * @shiny_mult).to_i if @active
      return chance.clamp(1, 65_536)
    end

    # Compatibility helper for older code paths expecting a 1/X denominator.
    def get_effective_shiny_rate
      chance = get_effective_shiny_chance
      return 1 if chance >= 65_536
      return [(65_536.0 / chance).round, 1].max
    end

    def shiny_panic_active?
      return false unless @shiny_panic_end_time
      Time.now.to_f < @shiny_panic_end_time
    end

    def start_shiny_panic
      return if shiny_panic_active?
      @shiny_panic_end_time = Time.now.to_f + 60 # 1 minute
      echoln "[VOE] SHINY PANIC STARTED!" if VOESettings::LOG_SPAWNS
      pbSEPlay("Ice Beam", 100, 150) rescue nil
      
      # Turn all existing outbreak Pokemon on the map shiny immediately
      if $game_map && $game_map.events
        $game_map.events.each_value do |event|
          next unless event.name&.include?("(Outbreak)")
          next unless event.variable && event.variable[0].is_a?(Pokemon)
          pkmn = event.variable[0]
          next if pkmn.shiny?
          
          # Force shiny status
          if pkmn.respond_to?(:makeShiny)
            pkmn.makeShiny
          else
            pkmn.shiny = true
          end
          
          # Update event name and sprite
          if event.instance_variable_get(:@event)
            event.instance_variable_get(:@event).name += " (Shiny)" unless event.name.include?("(Shiny)")
          end
          water = VOESettings.water_tile?(event.x, event.y)
          pbChangeEventSprite(event, pkmn, water)
          pbVOESparkle(event) if $scene.respond_to?(:spriteset) && $scene.spriteset
        end
      end
    end
    
    def active?
      return false unless @active
      return false if $game_map && @map_id != $game_map.map_id
      true
    end
    
    def cooldown_passed?
      return true if @next_trigger_time.nil?  # No cooldown set, allow outbreak
      Time.now.to_f >= @next_trigger_time
    end
    
    # Queue an outbreak to start after a delay (in seconds)
    def queue_delayed_outbreak(delay_seconds)
      @delayed_outbreak_time = Time.now.to_f + delay_seconds
      @delayed_outbreak_map_id = $game_map.map_id  # Remember which map triggered it
    end
    
    # Check if a delayed outbreak is ready to trigger
    def check_delayed_outbreak
      return unless @delayed_outbreak_time
      return if @active  # Don't trigger if already active
      
      # Cancel if player left the map that triggered the outbreak
      if $game_map.nil? || $game_map.map_id != @delayed_outbreak_map_id
        echoln "[VOE] Delayed outbreak cancelled - player left map" if VOESettings::LOG_SPAWNS
        @delayed_outbreak_time = nil
        @delayed_outbreak_map_id = nil
        return
      end
      
      # Cancel if now on blacklisted map
      if VOESettings::BLACK_LIST_MAPS.include?($game_map.map_id) || $game_map.map_id < 2
        echoln "[VOE] Delayed outbreak cancelled - blacklisted map" if VOESettings::LOG_SPAWNS
        @delayed_outbreak_time = nil
        @delayed_outbreak_map_id = nil
        return
      end
      
      # Check if it's time to trigger
      if Time.now.to_f >= @delayed_outbreak_time
        echoln "[VOE] Delayed outbreak triggering now!" if VOESettings::LOG_SPAWNS
        @delayed_outbreak_time = nil
        @delayed_outbreak_map_id = nil
        
        global_species = get_random_species_from_any_map
        start_outbreak(global_species) if global_species
      end
    end
    
    def time_remaining
      return 0 unless @end_time
      remaining = @end_time - Time.now.to_f
      remaining > 0 ? remaining : 0
    end
    
    def formatted_time
      seconds = time_remaining.to_i
      mins = seconds / 60
      secs = seconds % 60
      format("%d:%02d", mins, secs)
    end
    
    def outbreak_type_text
      VOESettings::OUTBREAK_TYPE == 0 ? "Mixed Species" : "Same Species"
    end
    
    def shiny_text
      "Shiny: #{@shiny_mult}x"
    end
    
    # Start an outbreak on the current map
    def start_outbreak(species = nil)
      return unless VOESettings::OUTBREAK_ENABLED
      return if active?
      return unless $game_map
      
      # Blacklist Check
      if VOESettings::BLACK_LIST_MAPS.include?($game_map.map_id) || $game_map.map_id < 2
        echoln "[VOE] Cannot start outbreak on blacklisted map #{$game_map.map_id}" if VOESettings::LOG_SPAWNS
        return
      end
      
      @active = true
      @map_id = $game_map.map_id
      duration_minutes = VOESettings::OUTBREAK_DURATION
      @end_time = Time.now.to_f + (duration_minutes * 60)
      @shiny_mult = VOESettings::OUTBREAK_SHINY_MULT
      @next_trigger_time = nil
      
      # Determine species if not provided
      if species.nil?
        species = get_random_species_from_any_map
      end
      
      # Lock species if same-species mode
      if VOESettings::OUTBREAK_TYPE == 1
        @locked_species = {}
        # If a specific species was provided (e.g. debug), use it as the Land rep
        @locked_species[:Land] = species || get_random_species_from_any_map(:Land)
        @locked_species[:Water] = get_random_species_from_any_map(:Water)
        @locked_species[:Cave] = get_random_species_from_any_map(:Cave)
        
        # Ensure we have at least one valid species
        @locked_species[:Land] ||= :PIDGEY
      else
        @locked_species = nil
      end
      
      echoln "[VOE] OUTBREAK STARTED! Duration: #{duration_minutes}min, Type: #{outbreak_type_text}, Shiny: #{@shiny_mult}x" if VOESettings::LOG_SPAWNS
      
      # Play announcement sound
      pbSEPlay("Choose", 80, 100) rescue nil
      
      # Show location window with outbreak message
      if $scene.is_a?(Scene_Map) && defined?(LocationWindow)
        $scene.spriteset.addUserSprite(LocationWindow.new(_INTL("Outbreak Started!"))) rescue nil
      end
      
      # Create UI
      create_ui
      
      # Spawn initial outbreak Pokemon
      spawn_outbreak_pokemon
    end
    
    def end_outbreak
      return unless @active
      
      echoln "[VOE] Outbreak ended" if VOESettings::LOG_SPAWNS
      
      # Try to cleanup events from the ORIGINAL outbreak map (stored in @map_id)
      # This works even if we're now on a different/blacklisted map
      cleanup_map = nil
      cleanup_map_id = @map_id  # The map where the outbreak started
      
      if cleanup_map_id && cleanup_map_id > 0
        # If we're still on the outbreak map, use $game_map directly
        if $game_map && $game_map.map_id == cleanup_map_id
          cleanup_map = $game_map
        else
          # Try to get the old map from map factory
          begin
            map_factory = defined?($MapFactory) ? $MapFactory : (defined?($map_factory) ? $map_factory : nil)
            if map_factory
              cleanup_map = map_factory.getMapNoAdd(cleanup_map_id) rescue nil
            end
          rescue => e
            echoln "[VOE] Could not access old map #{cleanup_map_id}: #{e.message}" if VOESettings::LOG_SPAWNS
          end
        end
      end
      
      # Cleanup events from the outbreak map
      if cleanup_map && cleanup_map.events
        echoln "[VOE] Cleaning up outbreak encounters on map #{cleanup_map_id}" if VOESettings::LOG_SPAWNS
        # Use .to_a to safely iterate while deleting
        cleanup_map.events.values.to_a.each do |event|
          next if event.nil?
          next unless event.name[/OverworldPkmn/i] rescue next
          
          is_outbreak = event.name.include?("(Outbreak)") rescue false
          if is_outbreak
            echoln "[VOE] Destroying outbreak event: #{event.name} (ID: #{event.id})" if VOESettings::LOG_SPAWNS
            if defined?(pbDestroyOverworldEncounter)
              pbDestroyOverworldEncounter(event, true, true, true)
            else
              # Manual cleanup if function not available
              begin
                event.character_name = ""
                event.through = true
                cleanup_map.events.delete(event.id)
              rescue
              end
            end
          end
        end
      else
        echoln "[VOE] Could not access outbreak map #{cleanup_map_id} for cleanup" if VOESettings::LOG_SPAWNS
      end
      
      @active = false
      @end_time = nil
      @locked_species = nil
      @map_id = nil
      @shiny_mult = 1
      @shiny_panic_end_time = nil
      @panic_cleanup_done = false
      
      # Set cooldown timer for next outbreak (20-60 minutes from now)
      @next_trigger_time = Time.now.to_f + (20 * 60) + rand(40 * 60)
      echoln "[VOE] Next outbreak possible in #{((@next_trigger_time - Time.now.to_f) / 60).round(1)} minutes" if VOESettings::LOG_SPAWNS
      
      # Force a recount of encounters
      VOESettings.current_encounters = nil
      
      dispose_ui
    end
    
    def spawn_outbreak_pokemon
      return unless active?
      
      count = VOESettings::OUTBREAK_SPAWN_COUNT
      echoln "[VOE] Spawning #{count} outbreak Pokemon burst" if VOESettings::LOG_SPAWNS
      
      # Immediate burst spawn
      count.times do
        # We call the global generator. We use full_map=false to respect the player-radius logic.
        if defined?(pbGenerateOverworldEncounters)
          pbGenerateOverworldEncounters(false, false)
        end
      end
    end
    
    # Get max encounters (override during outbreak)
    def get_outbreak_max
      active? ? VOESettings::OUTBREAK_MAX_OVERRIDE : VOESettings.get_max
    end
    

    
    # Block shiny despawn if setting is enabled
    def block_shiny_despawn?
      return false if shiny_panic_active? # During Panic, let them despawn to cycle spawns
      active? && VOESettings::OUTBREAK_NO_SHINY_DESPAWN
    end
    
    # Get current spawn rate
    def spawn_rate_threshold
      active? ? VOESettings::OUTBREAK_SPAWN_RATE : 600
    end
    
    # Get a random species from ANY map encounter table
    def get_random_species_from_any_map(preferred_type = nil)
      return :PIDGEY unless $PokemonEncounters
      
      # STRICT: Default to Land types only (not all types)
      target_types = [:Land, :Grass, :LandDay, :LandNight]
      is_water_spawn = false
      
      if preferred_type
        # Map specific encounter types to general categories
        if [:Water, :WaterDay, :WaterNight, :OldRod, :GoodRod, :SuperRod].include?(preferred_type)
          target_types = [:Water, :WaterDay, :WaterNight, :OldRod, :GoodRod, :SuperRod]
          is_water_spawn = true
        elsif [:Cave, :CaveDay, :CaveNight].include?(preferred_type)
          target_types = [:Cave, :CaveDay, :CaveNight]
        else
          target_types = [:Land, :Grass, :LandDay, :LandNight]
        end
      end
      
      if defined?(GameData::Encounter)
        all_encounters = GameData::Encounter::DATA.values
        if all_encounters && !all_encounters.empty?
          # Try up to 50 times to find a valid species
          50.times do
            enc_data = all_encounters.sample
            next unless enc_data && enc_data.types && !enc_data.types.empty?
            
            # Filter types that match our target categories
            available_target_types = enc_data.types.keys.select { |k| target_types.include?(k) }
            next if available_target_types.empty?
            
            random_type_key = available_target_types.sample
            random_type = enc_data.types[random_type_key]
            next unless random_type && !random_type.empty?
            
            species_entry = random_type.sample
            next unless species_entry
            
            # Get species (index 1 in encounter data)
            candidate = species_entry[1] rescue species_entry[0]
            next unless candidate
            
            # SECONDARY CHECK: Reject pure Water types for land spawns
            unless is_water_spawn
              begin
                sp_data = GameData::Species.try_get(candidate)
                if sp_data
                  types = [sp_data.types].flatten.compact
                  # Pure Water type check
                  if types.include?(:WATER)
                    other_types = types - [:WATER]
                    # Allow Water/Flying, Water/Ground etc. but not pure Water
                    if other_types.empty? || other_types == [:ICE]
                      next  # Skip pure water types
                    end
                  end
                end
              rescue
              end
            end
            
            return candidate
          end
        end
      end
      
      # Fallback: Use current map's encounter table
      begin
        fallback_type = :Land
        if [:Water, :WaterDay, :WaterNight, :OldRod, :GoodRod, :SuperRod].include?(preferred_type)
          fallback_type = :Water
        elsif [:Cave, :CaveDay, :CaveNight].include?(preferred_type)
          fallback_type = :Cave
        end
        
        enc_type = $PokemonEncounters.find_valid_encounter_type_for_time(fallback_type, pbGetTimeNow)
        pkmn_data = $PokemonEncounters.choose_wild_pokemon_for_map($game_map.map_id, enc_type)
        return pkmn_data[0] if pkmn_data
      rescue
      end
      
      return :PIDGEY
    end
    
    # ------------------
    # UI METHODS
    # ------------------
    def create_ui
      dispose_ui  # Clean up any existing UI
      
      return unless $scene.is_a?(Scene_Map)
      
      viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      viewport.z = 99999
      
      # Info bar (top-left): "Mixed Species | Shiny: 10x"
      @info_sprite = Sprite.new(viewport)
      @info_sprite.bitmap = Bitmap.new(220, 24)
      @info_sprite.bitmap.font.name = "Power Green"
      @info_sprite.bitmap.font.size = 18
      @info_sprite.x = 8
      @info_sprite.y = 4
      @info_sprite.z = 99999
      
      # Timer box (top-right): "OUTBREAK 4:57"
      @timer_bg = Sprite.new(viewport)
      @timer_bg.bitmap = Bitmap.new(100, 40)
      @timer_bg.bitmap.fill_rect(0, 0, 100, 40, Color.new(32, 32, 32, 200))
      # Border
      @timer_bg.bitmap.fill_rect(0, 0, 100, 2, Color.new(80, 80, 80))
      @timer_bg.bitmap.fill_rect(0, 38, 100, 2, Color.new(80, 80, 80))
      @timer_bg.bitmap.fill_rect(0, 0, 2, 40, Color.new(80, 80, 80))
      @timer_bg.bitmap.fill_rect(98, 0, 2, 40, Color.new(80, 80, 80))
      @timer_bg.x = Graphics.width - 108
      @timer_bg.y = 4
      @timer_bg.z = 99998
      
      @timer_sprite = Sprite.new(viewport)
      @timer_sprite.bitmap = Bitmap.new(96, 36)
      @timer_sprite.bitmap.font.name = "Power Green"
      @timer_sprite.bitmap.font.size = 14
      @timer_sprite.x = Graphics.width - 106
      @timer_sprite.y = 6
      @timer_sprite.z = 99999
      
      update_ui
    end
    
    def update_ui
      return unless active?
      return unless @info_sprite && @timer_sprite
      
      # Update info bar
      @info_sprite.bitmap.clear
      info_text = "#{outbreak_type_text} | #{shiny_text}"
      @info_sprite.bitmap.font.color = Color.new(255, 255, 255)
      @info_sprite.bitmap.draw_text(0, 0, 220, 24, info_text)
      
      # Update timer
      @timer_sprite.bitmap.clear
      @timer_sprite.bitmap.font.color = Color.new(255, 200, 100)
      @timer_sprite.bitmap.font.size = 12
      @timer_sprite.bitmap.draw_text(0, 0, 96, 16, shiny_panic_active? ? "PANIC!" : "OUTBREAK", 1)
      @timer_sprite.bitmap.font.size = 18
      @timer_sprite.bitmap.font.color = shiny_panic_active? ? Color.new(255, 100, 255) : Color.new(255, 255, 255)
      @timer_sprite.bitmap.draw_text(0, 14, 96, 22, shiny_panic_active? ? format(":%02d", (@shiny_panic_end_time - Time.now.to_f).to_i) : formatted_time, 1)
    end
    
    def dispose_ui
      if @info_sprite
        @info_sprite.bitmap&.dispose
        @info_sprite.dispose
        @info_sprite = nil
      end
      if @timer_sprite
        @timer_sprite.bitmap&.dispose
        @timer_sprite.dispose
        @timer_sprite = nil
      end
      if @timer_bg
        @timer_bg.bitmap&.dispose
        @timer_bg.dispose
        @timer_bg = nil
      end
    end
    
    # Called every frame
    def update
      # Check for delayed outbreak trigger (5 second delay after map entry)
      check_delayed_outbreak
      
      # Handle timer for next outbreak if none active globally
      if !@active && VOESettings::OUTBREAK_ENABLED
        @next_trigger_time = Time.now.to_f + (20 * 60) + rand(40 * 60) if @next_trigger_time.nil?
        
        # Check if it's time for a new outbreak
        if Time.now.to_f >= @next_trigger_time
          # Only trigger if map is valid (not blacklisted)
          if $game_map && !VOESettings::BLACK_LIST_MAPS.include?($game_map.map_id) && $game_map.map_id >= 2
            # Use global species variety for the outbreak species
            global_species = get_random_species_from_any_map
            start_outbreak(global_species) if global_species
          else
            # On invalid map, delay check by 1 minute
            @next_trigger_time = Time.now.to_f + 60
          end
        end
        return
      end
      
      return unless @active
      
      # If on blacklisted map, end the outbreak immediately
      if $game_map && (VOESettings::BLACK_LIST_MAPS.include?($game_map.map_id) || $game_map.map_id < 2)
        echoln "[VOE] Entered blacklisted map - ending outbreak" if VOESettings::LOG_SPAWNS
        end_outbreak
        return
      end
      
      # Check if outbreak should end (Time expired or Map left)
      if (Time.now.to_f >= @end_time) || ($game_map && @map_id != $game_map.map_id)
        end_outbreak
        return
      end

      # Shiny Panic Trigger (1/8096 chance every second)
      if VOESettings::SHINY_PANIC_ENABLED && !shiny_panic_active? && (Graphics.frame_count % Graphics.frame_rate == 0)
        # Check if we just exited panic (cleanup needed)
        if @shiny_panic_end_time && Time.now.to_f >= @shiny_panic_end_time && !@panic_cleanup_done
          echoln "[VOE] Shiny Panic ENDED - cleaning up panic shinies" if VOESettings::LOG_SPAWNS
          @panic_cleanup_done = true
          
          # Cleanup all shinies that were made shiny during panic (they have both Outbreak and Shiny tags)
          # Only clean if DELETE_SHINY is enabled, otherwise let them stay
          if VOESettings::DELETE_SHINY && $game_map && $game_map.events
            $game_map.events.values.to_a.each do |event|
              next if event.nil?
              next unless (event.name.include?("(Outbreak)") && event.name.include?("(Shiny)")) rescue false
              echoln "[VOE] Despawning panic shiny: #{event.name}" if VOESettings::LOG_SPAWNS
              pbDestroyOverworldEncounter(event, true, false, true) rescue nil
            end
          end
          
          @shiny_panic_end_time = nil
        elsif rand(8096) == 0
          @panic_cleanup_done = false  # Reset cleanup flag for next panic
          start_shiny_panic
        end
      end
      
      # Only update UI if we are on the outbreak map
      update_ui if active?
    end
  end
end

# Hook into Spriteset_Map update to update outbreak UI
class Spriteset_Map
  alias voe_outbreak_update update
  def update
    voe_outbreak_update
    VOEOutbreak.update
  end
  
  alias voe_outbreak_dispose dispose
  def dispose
    VOEOutbreak.dispose_ui
    voe_outbreak_dispose
  end
end

# Add pending_outbreak_spawns to Game_Temp
class Game_Temp
  attr_accessor :pending_outbreak_spawns
  attr_accessor :outbreak_frame_counter
  attr_accessor :map_location_window_text
  attr_accessor :outbreak_debug_start_queued
  attr_accessor :outbreak_debug_panic_queued
  attr_accessor :outbreak_debug_end_queued
end
