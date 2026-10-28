def pbInteractOverworldEncounter
  return if $PokemonGlobal.bridge > 0
  $game_temp.overworld_encounter = true
  evt = pbMapInterpreter.get_self
  evt.lock
  pkmn = evt.variable[0]
  return pbDestroyOverworldEncounter(evt, false, false, true) if pkmn.nil?
  
  # Check for nearby encounters for horde battle (up to 2 nearby neighbors for 3v1 support)
  nearby_encounters = []
  nearby_events = []
  nearby_event_ids = []  # Store IDs to prevent race conditions
  
  if VOESettings::HORDE_BATTLES
    horde_dist = VOESettings::HORDE_DISTANCE
    # Use .to_a to safely iterate (prevents issues if events are modified)
    $game_map.events.values.to_a.each do |event|
      next if event.nil?  # Safety check
      next if event.id == evt.id  # Skip self
      next unless event.name[/OverworldPkmn/i] rescue next
      next if event.variable.nil?
      next if event.variable[0].nil?
      next if event.lock?  # Skip if event is already locked (being processed)
      
      # Check true distance between encounters (Euclidean)
      dx = event.x - evt.x
      dy = event.y - evt.y
      true_distance = Math.sqrt(dx * dx + dy * dy)
      if true_distance <= horde_dist
        nearby_encounters << event.variable[0]
        nearby_events << event
        nearby_event_ids << event.id  # Store ID for validation
        echoln "[VOE] Horde! Found nearby #{event.variable[0].name} at distance #{true_distance.round(1)}" if VOESettings::LOG_SPAWNS
        break if nearby_encounters.length >= 2 # Cap at 3 Pokémon total (Self + 2 Neighbors)
      end
    end
  end
  
  # Lock nearby events to prevent race conditions (other encounters trying to interact with them)
  nearby_events.each do |event|
    event.lock if event && !event.lock?
  end
  
  # Validate that nearby events still exist and have valid Pokémon (race condition check)
  valid_nearby_encounters = []
  valid_nearby_events = []
  nearby_encounters.each_with_index do |encounter, idx|
    event = nearby_events[idx]
    event_id = nearby_event_ids[idx]
    # Verify event still exists in map and has valid data
    if event && $game_map.events[event_id] == event && event.variable && event.variable[0] == encounter
      valid_nearby_encounters << encounter
      valid_nearby_events << event
    else
      echoln "[VOE] Warning: Nearby event #{event_id} became invalid, skipping" if VOESettings::LOG_SPAWNS
    end
  end
  nearby_encounters = valid_nearby_encounters
  nearby_events = valid_nearby_events
  
  GameData::Species.play_cry_from_pokemon(pkmn)
  name = pkmn.name
  name_half = (name.length.to_f / 2).ceil
  textcol = VOESettings::COLORFUL_TEXT ? ((pkmn.genderless?) ? "" : (pkmn.male?) ? "\\b" : "\\r") : ""
  
  # Fusion check logic
  fused_pkmn = nil
  remaining_pkmn = []
  
  if nearby_encounters.length > 0 && VOESettings::FUSION_ENCOUNTERS && rand(VOESettings::FUSION_RATE) <= 1
    # Collect all candidates (self + nearby)
    all_candidates = [pkmn] + nearby_encounters
    
    # Ensure everyone involved is a base form Pokémon (not already fused)
    all_base = all_candidates.all? { |p| getDexNumberForSpecies(p.species) <= Settings::NB_POKEMON }
    
    if all_base
      # Randomly pick 2 from the group to fuse
      all_indices = (0...all_candidates.length).to_a
      idx1, idx2 = all_indices.sample(2)
      p1 = all_candidates[idx1]
      p2 = all_candidates[idx2]
      
      # Get dex numbers for fusion
      body_dex = getDexNumberForSpecies(p1.species)
      head_dex = getDexNumberForSpecies(p2.species)
      
      # Create fusion
      fusion_species = getFusedPokemonIdFromDexNum(body_dex, head_dex)
      avg_level = ((p1.level + p2.level) / 2.0).round
      fused_pkmn = Pokemon.new(fusion_species, avg_level)
      
      # Initialize fusion properly
      fused_pkmn.calc_stats
      fused_pkmn.reset_moves
      
      # Preserve shiny status - if either was shiny, fusion is shiny
      if p1.shiny? || p2.shiny?
        if fused_pkmn.respond_to?(:makeShiny)
          fused_pkmn.makeShiny
        else
          fused_pkmn.shiny = true
        end
      end
      
      # Determine who is left over (for 2v1 battles when 3 Pokémon were present)
      all_indices.each { |i| remaining_pkmn << all_candidates[i] if i != idx1 && i != idx2 }
      
      # Play sound effect and show message
      pbSEPlay("Voltorb Flip Point")
      pbMessage(_INTL("Wait! {1} and {2} are fusing!", p1.name, p2.name))
      
      echoln "[VOE] Fusion occurred! #{p1.name} + #{p2.name} = #{fused_pkmn.name}" if VOESettings::LOG_SPAWNS
    end
  end
  
  # Battle execution
  decision = nil
  
  if fused_pkmn
    if remaining_pkmn.length > 0
      # 2v1 Battle: Fused Pokémon + Remaining Single vs Player
      GameData::Species.play_cry_from_pokemon(remaining_pkmn[0])
      pbMessage(_INTL("{1}{2} and {3} appeared together!", textcol, fused_pkmn.name, remaining_pkmn[0].name))
      setBattleRule("double")
      decision = pbWildBattleCore(fused_pkmn, remaining_pkmn[0])
    else
      # 1v1 Battle: Resulting Fusion vs Player
      fused_name = fused_pkmn.name
      fused_name_half = (fused_name.length.to_f / 2).ceil
      pbMessage(_INTL("{1}{2}!", textcol, fused_name[0, fused_name_half] + fused_name[fused_name_half] + fused_name[fused_name_half]))
      decision = pbWildBattleCore(fused_pkmn)
    end
  else
    # No fusion occurred: Standard Triple, Double, or Single Battle
    if nearby_encounters.length == 2
      # Triple Battle (3v1)
      GameData::Species.play_cry_from_pokemon(nearby_encounters[0])
      GameData::Species.play_cry_from_pokemon(nearby_encounters[1])
      pbMessage(_INTL("{1}{2}, {3} and {4} appeared together!", textcol, name, nearby_encounters[0].name, nearby_encounters[1].name))
      setBattleRule("3v1")
      decision = pbWildBattleCore(pkmn, nearby_encounters[0], nearby_encounters[1])
    elsif nearby_encounters.length == 1
      # Double Battle (2v1)
      GameData::Species.play_cry_from_pokemon(nearby_encounters[0])
      pbMessage(_INTL("{1}{2} and {3} appeared together!", textcol, name, nearby_encounters[0].name))
      setBattleRule("double")
      decision = pbWildBattleCore(pkmn, nearby_encounters[0])
    else
      # Single battle
      pbMessage(_INTL("{1}{2}!", textcol, name[0, name_half] + name[name_half] + name[name_half]))
      decision = pbWildBattleCore(pkmn)
    end
  end
  
  # FORCE destroy ALL encounters after ANY battle outcome (catch, defeat, or run)
  # We no longer allow shiny protection after a battle - the encounter is consumed
  echoln "[VOE] Battle ended with decision #{decision}, force-destroying all events" if VOESettings::LOG_SPAWNS
  
  # Destroy all nearby events (validate they still exist to prevent race conditions)
  nearby_events.each do |event|
    next unless event  # Skip if nil
    # Verify event still exists in map before destroying
    if $game_map.events[event.id] == event
      pbDestroyOverworldEncounter(event, decision == 4, false, true) # force=true
    else
      echoln "[VOE] Warning: Nearby event #{event.id} no longer exists, skipping cleanup" if VOESettings::LOG_SPAWNS
    end
  end
  
  # Destroy main event (validate it still exists)
  if $game_map.events[evt.id] == evt
    pbDestroyOverworldEncounter(evt, decision == 4, decision != 4, true) # force=true
  else
    echoln "[VOE] Warning: Main event #{evt.id} no longer exists, skipping cleanup" if VOESettings::LOG_SPAWNS
  end
  
  $game_temp.overworld_encounter = false
end

def pbTrainersSeePkmn(evt)
  result = false
  # If event is running
  return result if $game_system.map_interpreter.running?
  # All event loops
  $game_map.events.each_value do |event|
    next if !event.name[/trainer\((\d+)\)/i] && !event.name[/sight\((\d+)\)/i]
    distance = $~[1].to_i
    next if !pbEventCanReachPlayer?(event, evt, distance)
    next if event.jumping? || event.over_trigger?
    result = true
  end
  return result
end

def get_grass_tile(full_map = false)
  possible_tiles = []
  
  if full_map
    # Search the entire map for initial spawns using random sampling
    max_attempts = 800  # More attempts for better coverage
    terrain_tiles = []  # Tiles with proper terrain tags
    passable_tiles = [] # Fallback: any passable tile
    
    max_attempts.times do
      # Random coordinates across the map
      x = rand($game_map.width)
      y = rand($game_map.height)
      
      # Skip player position
      next if x == $game_player.x && y == $game_player.y
      
      # Check terrain tag
      terrain_tag = VOESettings.terrain_tag_at(x, y)
      next if terrain_tag.id == :Rock
      
      # Check passability
      is_water = VOESettings.water_tag?(terrain_tag)
      next if !$game_map.passable?(x, y, 0) && !is_water
      
      # Skip if an event is there
      has_event = ($game_map.event_at_position(x, y) rescue false)
      next if has_event
      
      # Check if this is a proper encounter tile
      is_terrain_tile = VOESettings.encounter_tile?(x, y) ||
                        $PokemonEncounters.has_cave_encounters?
      
      if is_terrain_tile
        terrain_tiles.push([x, y])
      else
        passable_tiles.push([x, y])
      end
      
      # Stop early if we have enough terrain tiles
      break if terrain_tiles.length >= 50
    end
    
    # Prefer terrain tiles, but use passable tiles as fallback for cave maps
    possible_tiles = terrain_tiles.any? ? terrain_tiles : passable_tiles
  else
    # Original behavior: search near player
    possible_distance = (VOESettings::MAX_DISTANCE * 0.75).round
    if defined?(VOEOutbreak) && VOEOutbreak.active?
      possible_distance = VOESettings::OUTBREAK_RADIUS
    end
    (($game_player.x - possible_distance)..($game_player.x + possible_distance)).each do |x|
      # Don't check if out of bounds
      next if x < 0 || x >= $game_map.width
      (($game_player.y - possible_distance)..($game_player.y + possible_distance)).each do |y|
        # Don't check if out of bounds
        next if y < 0 || y >= $game_map.height
        # Don't check if on top of the player
        next if x == $game_player.x && y == $game_player.y
        
        terrain_tag = VOESettings.terrain_tag_at(x, y)
        # Returning by Tile Ids
        next if terrain_tag.id == :Rock
        
        # Don't spawn on impassable tiles
        is_water = VOESettings.water_tag?(terrain_tag)
        next if !$game_map.passable?(x, y, 0) && !is_water
        
        # Don't spawn if on top of an event
        on_top = false
        $game_map.events.each_value do |event|
          next unless event.at_coordinate?(x, y)
          on_top = true
          break
        end

        next if on_top

        # Don't spawn if a trainer can see it
        next if pbTrainersSeePkmn(Temp_Event.new(x, y, $game_map.map_id))
        # Spawn only if on an encounter tile

        next unless VOESettings.encounter_tile?(x, y) || $PokemonEncounters.has_cave_encounters?

        # Add to possible tiles
        possible_tiles.push([x, y])
      end
    end
  end

  # While surfing, only spawn on surfable water tiles.
  if $PokemonGlobal && $PokemonGlobal.surfing
    possible_tiles.delete_if { |tile| !VOESettings.water_tile?(tile[0], tile[1]) }
  elsif VOESettings::WATER_SPAWNS_ONLY_SURFING
    possible_tiles.delete_if { |tile| VOESettings.water_tile?(tile[0], tile[1]) }
  end

  if VOESettings::BLACK_LIST_WATER.include?($game_map.map_id)
    possible_tiles.delete_if { |tile| VOESettings.water_tile?(tile[0], tile[1]) }
  end
  
  return (possible_tiles.empty? ? [] : possible_tiles.sample)
end

def pbDestroyOverworldEncounter(event, animation = true, play_sound = false, force = false)
  return if $scene.is_a?(Scene_Intro) || $scene.is_a?(Scene_DebugIntro)
  return if event.nil?
  
  # Get pokemon data before we potentially clear it
  pkmn = event.variable.is_a?(Array) ? event.variable[0] : nil
  pkmn_name = pkmn ? pkmn.name : "Unknown"
  is_shiny = pkmn ? pkmn.shiny? : false
  
  # If variable is nil, skip the shiny check but still cleanup the event shell
  if event.variable.nil?
    echoln "[VOE] Destroying event with nil variable (ghost cleanup)" if VOESettings::LOG_SPAWNS
    # Fall through to cleanup
  elsif !force
    # Only apply shiny protection for NON-FORCE (natural despawn) calls
    # Battle outcomes ALWAYS use force=true, so shiny protection won't apply
    unless $game_variables[1] == 1 || $game_variables[1] == 4
      if is_shiny
        if VOESettings::DELETE_SHINY == false
          echoln "[VOE] Blocking despawn of shiny #{pkmn_name} (DELETE_SHINY=false)" if VOESettings::LOG_SPAWNS
          return
        end
        if defined?(VOEOutbreak) && VOEOutbreak.block_shiny_despawn?
          echoln "[VOE] Blocking despawn of shiny #{pkmn_name} (Outbreak shiny protection)" if VOESettings::LOG_SPAWNS
          return
        end
      end
    end
  end
  
  echoln "[VOE] Despawning #{pkmn_name} (force=#{force}, shiny=#{is_shiny})" if VOESettings::LOG_SPAWNS
  
  if play_sound && pkmn
    dist = (((event.x - $game_player.x).abs + (event.y - $game_player.y).abs) / 4).floor
    pbSEPlay(VOESettings::FLEE_SOUND, [75, 65, 55, 40, 27, 22, 15][dist], 150) if dist && dist <= 6 && dist >= 0
  end
  
  spriteset = $scene.respond_to?(:spriteset) ? $scene.spriteset : nil
  spriteset&.addUserAnimation(VOESettings::SPAWN_ANIMATION, event.x, event.y, true, 1) if animation && spriteset
  
  # Store event ID before cleanup
  event_id = event.id
  rf_data = event.variable.is_a?(Array) ? event.variable[1] : nil
  
  # IMMEDIATELY make the event non-interactive to prevent race conditions
  begin
    event.setVariable(nil) rescue nil
    event.through = true rescue nil
    event.character_name = "" rescue nil
    # Mark as erased to prevent any further processing
    event.instance_variable_set(:@erased, true) rescue nil
  rescue => e
    echoln "[VOE] Error clearing event data: #{e.message}" if VOESettings::LOG_SPAWNS
  end
  
  # Now fully delete the event
  begin
    # First clear the sprite
    spriteset&.delete_character(event)
    
    # Remove from map events hash using stored ID
    $game_map.events.delete(event_id) if $game_map&.events
    
    # Also try the Rf method if available
    Rf.delete_event(rf_data) rescue nil if rf_data
  rescue => e
    echoln "[VOE] Error deleting event #{event_id}: #{e.message}" if VOESettings::LOG_SPAWNS
  end
  
  # Only decrement counter if we had a valid pokemon
  # Also ensure counter never goes below 0
  if pkmn
    VOESettings.current_encounters -= 1
    VOESettings.current_encounters = 0 if VOESettings.current_encounters < 0
    echoln "[VOE] Encounter count now: #{VOESettings.current_encounters}" if VOESettings::LOG_SPAWNS
  end
  $game_variables[1] = 0
end

def pbDistanceToPlayer(evt)
  return if !evt
  dx = evt.x - $game_player.x
  dy = evt.y - $game_player.y
  return Math.sqrt(dx * dx + dy * dy).round
end


def pbRepelCheck(event)
  return false if !$PokemonGlobal || !$PokemonGlobal.repel || $PokemonGlobal.repel <= 0
  return true
end

def pbRepelFlee(event)
  return if event.lock?
  return if !pbRepelCheck(event)
  
  # Check distance
  dist = pbDistanceToPlayer(event)
  return if dist > 6 # Only flee if active range
  
  event.move_away_from_player
end

def pbPokemonIdle(evt)
  return if rand(3) == 1
  return if !evt
  return if evt.lock?
  return pbDestroyOverworldEncounter(evt) if evt.variable.nil?
  
  # Only do random/terrain despawns very rarely
  if rand(1000) == 1  # Very rare random despawn
    unless evt.variable[0].shiny?
      pbDestroyOverworldEncounter(evt)
      return
    end
  end
  
  evt.move_random
  
  # Only despawn by distance if DELETE_EVENTS is enabled
  if VOESettings::DELETE_EVENTS
    dist = pbDistanceToPlayer(evt)
    if dist > VOESettings::MAX_DISTANCE && !evt.variable[0].shiny?
      pbDestroyOverworldEncounter(evt)
      return
    end
  end
  
  # Play cry occasionally
  dist = (((evt.x - $game_player.x).abs + (evt.y - $game_player.y).abs) / 4).floor
  GameData::Species.play_cry_from_pokemon(evt.variable[0], [75, 65, 55, 40, 27, 22, 15][dist]) if dist <= 6 && dist >= 0 && rand(20) == 1 unless dist.nil?
end

def pbChangeEventSprite(event, pkmn, water = false)
  shiny = pkmn.shiny?
  shiny = pkmn.superVariant if (pkmn.respond_to?(:superVariant) && !pkmn.superVariant.nil? && pkmn.super_shiny?)

  fname = nil
  
  # Check if this is a fusion (marked in event name)
  is_fusion = event.name.include?("(Fusion)")
  
  begin
    if is_fusion && defined?(isSpeciesFusion) && isSpeciesFusion(pkmn.species)
      # For fusions, show BODY species sprite as silhouette
      body_species = get_body_species_from_symbol(pkmn.species)
      fname = pbOWSpriteFilename(body_species, 0, 0, false, false, water)
      
      # If body sprite not found, try to use a generic Pokemon sprite
      if nil_or_empty?(fname) || !pbResolveBitmap(fname)
        echoln "[VOE] Warning: No sprite found for fusion body #{body_species}, trying head" if VOESettings::LOG_SPAWNS
        head_species = get_head_species_from_symbol(pkmn.species)
        fname = pbOWSpriteFilename(head_species, 0, 0, false, false, water)
      end
    else
      fname = pbOWSpriteFilename(pkmn.species, pkmn.form, pkmn.gender, shiny, pkmn.shadow, water)
      fname = pbOWSpriteFilename(pkmn.species, 0, pkmn.gender, shiny, pkmn.shadow, water) if pkmn.species == :MINIOR
    end
  rescue => e
    echoln "[VOE] Error getting sprite for #{pkmn.species}: #{e.message}" if VOESettings::LOG_SPAWNS
    fname = nil
  end

  # If no sprite found, use a fallback (return early to prevent visibility issues)
  if nil_or_empty?(fname) || !pbResolveBitmap(fname)
    echoln "[VOE] Warning: No sprite found for #{pkmn.species}, trying fallback" if VOESettings::LOG_SPAWNS
    # Try to use a common sprite as fallback
    fname = pbOWSpriteFilename(:PIDGEY, 0, 0, false, false, false)
    if nil_or_empty?(fname) || !pbResolveBitmap(fname)
      # Last resort - use a simple known sprite path
      fname = "Graphics/Characters/Followers/PIDGEY"
      if !pbResolveBitmap(fname)
        echoln "[VOE] Error: Cannot find any fallback sprite!" if VOESettings::LOG_SPAWNS
        return  # Give up, can't display sprite
      end
    end
  end
  
  fname.gsub!("Graphics/Characters/", "")
  
  # Ensure the character name is not empty
  if nil_or_empty?(fname)
    fname = "Followers/PIDGEY"  # Hard fallback
  end
  
  event.character_name = fname
  
  if event.move_route_forcing
    hue = pkmn.respond_to?(:superHue) && pkmn.super_shiny? ? pkmn.superHue : 0
    event.character_hue = hue
  end
  
  # Apply dark silhouette effect for fusions (but not on shiny reveal)
  if is_fusion && !shiny
    event.character_hue = 0  # Reset hue
    # Mark for dark tone application (handled in Spriteset_Map update)
  end
end

class Game_Temp
  attr_accessor :overworld_encounter
  attr_accessor :frames_updated
  attr_accessor :pending_initial_spawns
  attr_accessor :spawn_frame_counter

  def overworld_encounter
    @overworld_encounter = false if !@overworld_encounter
    return @overworld_encounter
  end

  def overworld_encounter=(val)
    @overworld_encounter = val
  end

  def frames_updated
    @frames_updated = 0 if !@frames_updated
    return @frames_updated
  end

  def frames_updated=(val)
    @frames_updated = val
  end

  def pending_initial_spawns
    @pending_initial_spawns = 0 if !@pending_initial_spawns
    return @pending_initial_spawns
  end

  def pending_initial_spawns=(val)
    @pending_initial_spawns = val
  end

  def spawn_frame_counter
    @spawn_frame_counter = 0 if !@spawn_frame_counter
    return @spawn_frame_counter
  end

  def spawn_frame_counter=(val)
    @spawn_frame_counter = val
  end
end

# Added map_id attr to be compatible with pbEventCanReachPlayer at v21.1 Bug Fixes
class Temp_Event
  attr_reader :x, :y, :map_id

  def initialize(x, y, map_id)
    @x = x
    @y = y
    @map_id = map_id
  end
end
