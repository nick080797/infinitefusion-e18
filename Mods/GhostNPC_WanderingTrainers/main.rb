#===============================================================================
# Wandering Trainers Mod 7.6 (Spawn Path Validation)
#===============================================================================

class Game_Character
  attr_accessor :step_anime unless method_defined?(:step_anime=)
  attr_accessor :move_type unless method_defined?(:move_type)
  attr_accessor :ghostnpc_shiny
  def ghostnpc_move_toward(target)
    return if !target
    sx = @x - target.x; sy = @y - target.y
    return if sx == 0 && sy == 0
    if sx.abs > sy.abs
      (sx > 0) ? move_left : move_right
    else
      (sy > 0) ? move_up : move_down
    end
  end
end

class Game_Event
  alias ghostnpc_wt_start_v74 start unless method_defined?(:ghostnpc_wt_start_v74)
  def start
    if (@id >= 8000 && @id <= 8015) || (@id >= 7000 && @id <= 7015)
      WanderingTrainersMod.interact(@id)
      return
    end
    ghostnpc_wt_start_v74
  end
end

class Spriteset_Map
  alias ghostnpc_wt_update_v74 update unless method_defined?(:ghostnpc_wt_update_v74)
  def update
    ghostnpc_wt_update_v74
    update_wt_duo_sprites
  end

  def update_wt_duo_sprites
    return unless $game_map
    @ghostnpc_wt_sprites ||= {}
    @ghostnpc_wt_sprites_changed = false
    active_ids = WanderingTrainersMod.spawned_ids
    active_ids.each do |id|
      next if @ghostnpc_wt_sprites[id]
      event = $game_map.events[id]
      if event && !event.erased
        sprite = Sprite_Character.new(@@viewport1, event)
        sprite.update rescue nil
        @character_sprites.push(sprite)
        @ghostnpc_wt_sprites[id] = sprite
        @ghostnpc_wt_sprites_changed = true
      end
    end
    @ghostnpc_wt_sprites.delete_if do |id, sprite|
      event = $game_map.events[id]
      if !event || event.erased || !active_ids.include?(id)
        sprite.dispose if sprite; @character_sprites.delete(sprite)
        @ghostnpc_wt_sprites_changed = true
        true
      else false end
    end
    if @ghostnpc_wt_sprites_changed
      @ghostnpc_wt_sprites_changed = false
    end
  end
end

module WanderingTrainersMod
  @spawned_ids = []
  @trainer_data = {}
  @spawn_cooldown = 0
  @last_spawned_map = 0
  @noticed_player = {}
  @sprite_path_cache = {}
  @spawn_queue = []  # Staggered spawning: one trainer per update tick
  @interacted_trainer_id = nil
  @scanning_team = false

      def self.spawned_ids; @spawned_ids; end
      def self.is_scanning?; @scanning_team; end

        FORBIDDEN_SPECIES_IDS = [
          144..146, 150..151, 243..245, 249..251, 377..386, 480..494,
          638..649, 716..721, 772..773, 785..809, 888..898, 905..1025
        ]

        FORBIDDEN_KEYWORDS = [
          "ARTICUNO", "ZAPDOS", "MOLTRES", "MEWTWO", "MEW", "RAIKOU", "ENTEI",
          "SUICUNE", "LUGIA", "HOOH", "CELEBI", "REGIROCK", "REGICE", "REGISTEEL",
          "LATIAS", "LATIOS", "KYOGRE", "GROUDON", "RAYQUAZA", "JIRACHI", "DEOXYS",
          "UXIE", "MESPRIT", "AZELF", "DIALGA", "PALKIA", "HEATRAN", "REGIGIGAS",
          "GIRATINA", "CRESSELIA", "PHIONE", "MANAPHY", "DARKRAI", "SHAYMIN",
          "ARCEUS", "VICTINI", "COBALION", "TERRAKION", "VIRIZION", "TORNADUS",
          "THUNDURUS", "RESHIRAM", "ZEKROM", "LANDORUS", "KYUREM", "KELDEO",
          "MELOETTA", "GENESECT", "XERNEAS", "YVELTAL", "ZYGARDE", "DIANCIE",
          "HOOPA", "VOLCANION", "TYPENULL", "SILVALLY", "TAPU_KOKO", "TAPU_LELE",
          "TAPU_BULU", "TAPU_FINI", "COSMOG", "COSMOEM", "SOLGALEO", "LUNALA",
          "NIHILEGO", "BUZZWOLE", "PHEROMOSA", "XURKITREE", "CELESTEELA", "KARTANA",
          "GUZZLORD", "NECROZMA", "MAGEARNA", "MARSHADOW", "POIPOLE", "NAGANADEL",
          "STAKATAKA", "BLACEPHALON", "ZERAORA", "MELTAN", "MELMETAL", "ZACIAN",
          "ZAMAZENTA", "ETERNATUS", "KUBFU", "URSHIFU", "ZARUDE", "REGIELEKI",
          "REGIDRAGO", "GLASTRIER", "SPECTRIER", "CALYREX", "ENAMORUS", "WOCHIEN",
          "CHIENPAO", "TINGLU", "CHIYU", "KORAIDON", "MIRAIDON", "OKIDOGI",
          "MUNKIDORI", "FEZANDIPITI", "OGERPON", "PECHARUNT", "GOUGING_FIRE",
          "RAGING_BOLT", "IRON_CROWN", "IRON_BOULDER", "IRON_TREADS", "IRON_BUNDLE",
          "IRON_HANDS", "IRON_JUGULIS", "IRON_MOTH", "IRON_LEAVES", "TERAPAGOS",
          "GREAT_TUSK", "SCREAM_TAIL", "BRUTE_BONNET", "FLUTTER_MANE",
          "SLITHER_WING", "SANDY_SHOCKS", "ROARING_MOON", "WALKING_WAKE",
          "GIMMIGHOUL", "GHOLDENGO"
        ]

        ALLOWED_TAGS = [0, 2, 3, 4, 10, 13, 14, 24, 25, 26]

  def self.is_forbidden?(id)
    return false if !id
    species = GameData::Species.get(id) rescue nil
    return false if !species

    # 1. Keyword Check (Strongest Protection)
    # Checks internal symbol (e.g. :GIRATINA, :HOPPIP_GIRATINA)
    sym_str = species.id.to_s.upcase
    return true if FORBIDDEN_KEYWORDS.any? { |k| sym_str.include?(k) }

    # 2. ID Range Check (Safety Layer)
    id_num = species.id_number
    return true if FORBIDDEN_SPECIES_IDS.any? { |r| r.include?(id_num) }

    # 3. Recursive Fusion Attribute Check (Backup)
    # Check standard GameData attributes for head/body
    if species.respond_to?(:head_pokemon) && species.head_pokemon
      return true if is_forbidden?(species.head_pokemon)
    end
    if species.respond_to?(:body_pokemon) && species.body_pokemon
      return true if is_forbidden?(species.body_pokemon)
    end

    return false
  end

  def self.get_pkmn_sprite(pkmn_or_id, shiny = false)
    species_id = pkmn_or_id
    is_shiny = shiny
    if pkmn_or_id.is_a?(Pokemon)
      species_id = pkmn_or_id.species
      is_shiny = pkmn_or_id.shiny?
    end

    if species_id.is_a?(Symbol); species_id = GameData::Species.get(species_id).id_number rescue 1; end

    cache_key = "#{species_id}_#{is_shiny ? 's' : 'n'}"
    return @sprite_path_cache[cache_key] if @sprite_path_cache[cache_key]

    id_str = species_id.to_s; id_3 = sprintf("%03d", species_id.to_i) rescue id_str
    raw_name = ""; begin; raw_name = GameData::Species.get(species_id).id.to_s; rescue; end
    clean_name = raw_name.gsub(/[^A-Za-z0-9]/, "").upcase
    s = is_shiny ? "s" : ""
    patterns = [clean_name + s, clean_name, id_str + s + "_0", id_3 + s + "_0", id_str + s, id_3 + s]
    folders = ["Followers/", "Overworld/", ""]
    folders.each do |f|
      patterns.each do |p|
        next if p == ""
        path = f + p
        if pbResolveBitmap("Graphics/Characters/" + path)
          @sprite_path_cache[cache_key] = path
          return path
        end
      end
    end
    res = id_3 + s
    @sprite_path_cache[cache_key] = res
    return res
  end

  def self.generate_smart_pkmn(level)
    loop do
      if rand(100) < 50
        head = rand(Settings::NB_POKEMON) + 1; body = rand(Settings::NB_POKEMON) + 1
        next if is_forbidden?(head) || is_forbidden?(body)
        fused_id = defined?(getSpeciesIdForFusion) ? getSpeciesIdForFusion(head, body) : (body * Settings::NB_POKEMON) + head rescue head
        pkmn = Pokemon.new(fused_id, level)
      else
        species = rand(Settings::NB_POKEMON) + 1
        next if is_forbidden?(species)
        pkmn = Pokemon.new(species, level)
      end
      shiny_rate = ModSettingsMenu.get(:wt_shiny_rate) rescue 0
      if shiny_rate && shiny_rate > 0
        if rand(100) < shiny_rate
          begin; pkmn.shiny = true; rescue; end
          begin; pkmn.debug_shiny = true; rescue; end
        end
      elsif rand(100) < 10
        begin; pkmn.shiny = true; rescue; end
        begin; pkmn.debug_shiny = true; rescue; end
      end
      return pkmn
    end
  end

  def self.update
    return unless true
    if @spawn_cooldown > 0; @spawn_cooldown -= 1
    elsif @spawn_cooldown == 0; self.setup_map_spawn; end
    # Process staggered spawn queue: one trainer per update tick
    if !@spawn_queue.empty?
      idx = @spawn_queue.shift
      self.spawn_duo(idx)
    end
    self.maintain_trainer_persistence if $game_player && Graphics.frame_count % 30 == 0
    self.update_despawning_trainers
  end

              def self.maintain_trainer_persistence
                return unless $game_map
                
                @spawned_ids.each do |id|
                  next if id < 8000
                  data = @trainer_data[id]; next if !data || data[:despawning]
                  event = $game_map.events[id]
                  # Re-materialize if lost (e.g. map re-init)
                  if (!event || event.erased) && !self.is_map_blocked?
                    new_ev = self.create_virtual_event(id, data[:x] || $game_player.x, data[:y] || $game_player.y, data[:t_sprite], 1)
                    $game_map.events[id] = new_ev
                    event = new_ev
                  end
                  # Nudge: Ensure they are wandering
                  # Skip nudge if this trainer (or their pet) is currently being interacted with
                  pet_id = data[:p_id]
                  is_interacted = (@interacted_trainer_id == id || (pet_id && @interacted_trainer_id == pet_id))
                  if event.move_type == 0 && !is_interacted # Fixed/Zero
                    event.move_type = 1 # Random
                    event.move_speed = 3
                    event.move_frequency = 3
                  end
                  # Update current coords for re-materialization safety
                  data[:x] = event.x; data[:y] = event.y

                  # Re-materialize pokemon companion if lost
                  p_id = data[:p_id]
                  if p_id && (!$game_map.events[p_id] || $game_map.events[p_id].erased)
                    p_sprite = data[:p_sprite] || self.get_pkmn_sprite(data[:lead_species], data[:p_shiny])
                    p_ev = self.create_virtual_event(p_id, event.x, event.y, p_sprite, 0)
                    p_ev.through = true
                    p_ev.ghostnpc_shiny = true if data[:p_shiny]
                    $game_map.events[p_id] = p_ev
                  end
                end
              end

              def self.update_despawning_trainers
                @trainer_data.each do |t_id, data|
                  next unless data[:despawning]
                  event = $game_map.events[t_id]
                  if !event || event.erased
                    self.remove_trainer(t_id)
                    next
                  end
                  dist = (event.x - $game_player.x).abs + (event.y - $game_player.y).abs
                  if dist >= 12
                    self.remove_trainer(t_id)
                    next
                  end

                  data[:despawn_timeout] = (data[:despawn_timeout] || 0) + 1
                  if data[:despawn_timeout] > 150 # ~4-5 seconds
                    self.remove_trainer(t_id)
                    next
                  end

                  # Track movement to detect actual sticking
                  if event.x != data[:last_exit_x] || event.y != data[:last_exit_y]
                    data[:stuck_count] = 0
                    data[:last_exit_x] = event.x; data[:last_exit_y] = event.y
                  end

                  # Smart flee logic: check all 4 directions and pick the passable one that maximizes distance
                  if !event.moving?
                    best_dirs = []
                    max_dist = -1
                    [[2, 0, 1], [4, -1, 0], [6, 1, 0], [8, 0, -1]].each do |d, dx, dy|
                      next unless $game_map.passable?(event.x, event.y, d, event)
                      new_dist = (event.x + dx - $game_player.x).abs + (event.y + dy - $game_player.y).abs
                      if new_dist > max_dist
                        max_dist = new_dist
                        best_dirs = [d]
                      elsif new_dist == max_dist
                        best_dirs << d
                      end
                    end

                    if !best_dirs.empty?
                      dir = best_dirs.sample
                      case dir
                      when 2 then event.move_down
                      when 4 then event.move_left
                      when 6 then event.move_right
                      when 8 then event.move_up
                      end

                      # Increment stuck count if we are in the same tile while trying to move
                      data[:stuck_count] = (data[:stuck_count] || 0) + 1
                      if data[:stuck_count] > 8 # Grace period: ~80 frames / 2 seconds
                        self.remove_trainer(t_id)
                      end
                    else
                      # Truly stuck (no passable neighbors)
                      self.remove_trainer(t_id)
                    end
                  end
                end
              end

              def self.check_player_proximity
                return unless $game_map && $scene.is_a?(Scene_Map) && $scene.spriteset
                @spawned_ids.each do |id|
                  next if id < 8000
                  event = $game_map.events[id]
                  next if !event || event.erased || @noticed_player[id]
                  dist = (event.x - $game_player.x).abs + (event.y - $game_player.y).abs
                  if dist <= 3
                    @noticed_player[id] = true
                    $scene.spriteset.addUserAnimation(3, event.x, event.y, true, 3) rescue nil
                    pbSEPlay("Notice") rescue nil
                  end
                end
              end

              def self.is_map_blocked?
                return true unless $game_map
                map_name = $game_map.name rescue ""
                # Avoid blocking "Gate" maps as they are often used for route connections
                # Only block major indoor hubs
                is_indoor = ["Center", "Mart", "Gym", "Lab", "Elevator"].any? { |s| map_name.include?(s) }
                # Relaxed size check - allow routes and narrow maps
                is_too_small = ($game_map.width < 10 || $game_map.height < 10)

                is_at_home = (defined?(PlayerHousing) && PlayerHousing.at_home?)
                is_secret_base = false
                is_secret_base = true if defined?(SecretBaseSettings) && $game_map.map_id == SecretBaseSettings::SECRET_BASE_MAP
                is_factory = (defined?(PetWorkerSettings) && $game_map.map_id == PetWorkerSettings::FACTORY_MAP_ID)

                return is_indoor || is_too_small || is_at_home || is_secret_base || is_factory
              end

              #--- MODIFIED SPAWN LOGIC ---
              def self.setup_map_spawn
                return unless $game_map

                # Active Orphan Sweeper: Clean up map once per check before determining new spawns
                $game_map.events.keys.each do |id|
                  if (id >= 7000 && id <= 7015) || (id >= 8000 && id <= 8015)
                    unless @spawned_ids.include?(id)
                      $game_map.events[id].erase
                      $game_map.events.delete(id)
                    end
                  end
                end

                if self.is_map_blocked?
                  if @last_spawned_map != $game_map.map_id
                    self.clear_all_spawns
                    @last_spawned_map = $game_map.map_id
                  end
                  return
                end

                if @last_spawned_map != $game_map.map_id
                  self.clear_all_spawns

                  roll = rand(100) # 0-99 range
                  num_to_spawn = 0

                  if roll < 45        # 45% chance (0-44)
                    num_to_spawn = 0
                  elsif roll < 85     # 40% chance (45-84)
                    num_to_spawn = 1
                  elsif roll < 95     # 10% chance (85-94)
                    num_to_spawn = 2
                  else                # 5% chance (95-99)
                    num_to_spawn = 3
                  end

                  # Staggered: queue spawns instead of doing them all at once
                  num_to_spawn.times { |i| @spawn_queue << i }
                  @last_spawned_map = $game_map.map_id
                  @spawn_cooldown = 100 # Reset cooldown after map entry check
                end
              end

  def self.spawn_duo(index)
    spawn_pos = self.find_spawn_point; return unless spawn_pos
    t_sprite = ["LASS_blue", "YOUNGSTER_LeagueHat", "BWHiker", "BW001", "BW002", "BW003", "BW010", "BW015"].sample
    t_id = 8000 + index; t_event = self.create_virtual_event(t_id, spawn_pos[0], spawn_pos[1], t_sprite, 1); $game_map.events[t_id] = t_event; @spawned_ids.push(t_id)
    avg_level = ($Trainer.party.map{|p| p.level}.sum / $Trainer.party.size rescue 10)

    # Lazy Team Generation
    team_data = []; has_shiny = false; lead_species = nil; lead_shiny = false
    (1 + rand(3)).times do |ti|
      species = 1
      is_fusion = false
      loop do
        if rand(100) < 50
          head = rand(Settings::NB_POKEMON) + 1; body = rand(Settings::NB_POKEMON) + 1
          next if is_forbidden?(head) || is_forbidden?(body)
          species = defined?(getSpeciesIdForFusion) ? getSpeciesIdForFusion(head, body) : (body * Settings::NB_POKEMON) + head rescue head
          is_fusion = true
        else
          species = rand(Settings::NB_POKEMON) + 1
          next if is_forbidden?(species)
          is_fusion = false
        end
        break
      end
      shiny_rate = ModSettingsMenu.get(:wt_shiny_rate) rescue 0
      if shiny_rate && shiny_rate > 0
        shiny = (rand(100) < shiny_rate)
      else
        shiny = (rand(1000) < 1)
      end
      has_shiny = true if shiny
      team_data << { :species => species, :level => avg_level, :shiny => shiny, :fusion => is_fusion }
      if ti == 0; lead_species = species; lead_shiny = shiny; end
    end

    display_species = lead_species
    if team_data[0][:fusion]
      body_id = GameData::Species.get(lead_species).body_pokemon.id_number rescue (lead_species / Settings::NB_POKEMON)
      display_species = body_id
    end
    char_name = self.get_pkmn_sprite(display_species, lead_shiny)
    tx = spawn_pos[0]; ty = spawn_pos[1]; p_x = tx; p_y = ty
    candidate_positions = [[tx, ty - 1], [tx, ty + 1], [tx - 1, ty], [tx + 1, ty]]
    candidate_positions.each do |cx, cy|
      next unless $game_map.valid?(cx, cy); next unless $game_map.passable?(cx, cy, 0, $game_player)
      tag = $game_map.terrain_tag(cx, cy) rescue nil
      tag_id = tag.is_a?(Integer) ? tag : (tag.id_number rescue 0); next unless ALLOWED_TAGS.include?(tag_id)
      p_x = cx; p_y = cy; break
    end
    p_id = 7000 + index; p_event = self.create_virtual_event(p_id, p_x, p_y, char_name, 0); p_event.through = true
    p_event.ghostnpc_shiny = true if lead_shiny
    $game_map.events[p_id] = p_event; @spawned_ids.push(p_id)
    @trainer_data[t_id] = { 
      :name => ["Alex", "Logan", "Jordan", "Terry", "Kim", "Sam"].sample, 
      :team_data => team_data, :team => nil, :p_id => p_id, 
      :has_shiny => has_shiny, :lead_species => lead_species, 
      :t_sprite => t_sprite, :p_sprite => char_name, :p_shiny => lead_shiny,
      :x => tx, :y => ty 
    }

    # Force 2 steps toward player upon spawn to escape wall tiles safely
    2.times do
      # Calculate distance before moving
      dx = (t_event.x - $game_player.x).abs
      dy = (t_event.y - $game_player.y).abs
      
      # Determine step direction for valid pathing
      target_dir = 0
      if dx > dy
        target_dir = t_event.x > $game_player.x ? 4 : 6
      else
        target_dir = t_event.y > $game_player.y ? 8 : 2
      end
      
      if $game_map.passable?(t_event.x, t_event.y, target_dir)
        t_event.move_generic(target_dir, true)
        p_event.move_generic(target_dir, true) if p_event
      end
    end
    @trainer_data[t_id][:x] = t_event.x
    @trainer_data[t_id][:y] = t_event.y
  end

                def self.create_virtual_event(id, x, y, char_name, move_type)
                  rpg_event = RPG::Event.new(x, y); rpg_event.id = id
                  page = RPG::Event::Page.new; page.graphic.character_name = char_name
                  page.move_type = move_type; page.move_frequency = 3; page.move_speed = 3; page.trigger = 0
                  rpg_event.pages = [page]
                  ev = Game_Event.new($game_map.map_id, rpg_event, $game_map); ev.character_name = char_name; ev.set_opacity(255)
                  return ev
                end

                def self.reachable_from_player?(sx, sy)
                  px = $game_player.x; py = $game_player.y
                  visited = { [sx, sy] => true }
                  queue = [[sx, sy]]
                  budget = 250
                  while !queue.empty? && budget > 0
                    cx, cy = queue.shift
                    budget -= 1
                    return true if (cx - px).abs + (cy - py).abs <= 2
                    [[0,1],[0,-1],[1,0],[-1,0]].each do |dx, dy|
                      nx = cx + dx; ny = cy + dy
                      next if visited[[nx, ny]]
                      next unless $game_map.valid?(nx, ny)
                      dir = (dx == 1 ? 6 : dx == -1 ? 4 : dy == 1 ? 2 : 8)
                      next unless $game_map.passable?(nx, ny, dir, $game_player)
                      visited[[nx, ny]] = true
                      queue.push([nx, ny])
                    end
                  end
                  false
                end

                def self.find_spawn_point
                  return nil unless $game_map
                  100.times do
                    rx = rand($game_map.width); ry = rand($game_map.height)
                    next unless $game_map.valid?(rx, ry)
                    # Support for spawning off-screen: Minimum 12 tiles Manhattan distance
                    next if (rx - $game_player.x).abs + (ry - $game_player.y).abs < 12
                    tag = $game_map.terrain_tag(rx, ry) rescue nil
                    tag_id = tag.is_a?(Integer) ? tag : (tag.id_number rescue 0)
                    next unless $game_map.passable?(rx, ry, 0, $game_player)
                    next unless ALLOWED_TAGS.include?(tag_id)
                    passable_neighbors = 0
                    [2, 4, 6, 8].each { |d| passable_neighbors += 1 if $game_map.passable?(rx, ry, d, $game_player) }
                    next if passable_neighbors < 2
                    next unless self.reachable_from_player?(rx, ry)
                    return [rx, ry]
                  end
                  return nil
                end

                def self.clear_all_spawns(full_reset = true)
                  return unless $game_map
                  
                  # Hard Sweep: Erase all events in our allocated IDs from the map directly
                  $game_map.events.keys.each do |id|
                    if (id >= 7000 && id <= 7015) || (id >= 8000 && id <= 8015)
                      $game_map.events[id].erase
                      $game_map.events.delete(id)
                    end
                  end

                  if full_reset
                    @spawned_ids = []
                    @trainer_data = {}
                    @noticed_player = {}
                    @spawn_queue = []
                  end
                end

  def self.materialize_team(data)
    return data[:team] if data[:team]
    team = []
    data[:team_data].each do |td|
      pkmn = Pokemon.new(td[:species], td[:level])
      if td[:shiny]
        begin; pkmn.shiny = true; rescue; end
        begin; pkmn.debug_shiny = true; rescue; end
      end
      team << pkmn
    end
    data[:team] = team
    return team
  end

  def self.scan_team(team)
    @scanning_team = true
    scene = PokemonParty_Scene.new
    screen = PokemonPartyScreen.new(scene, team)
    screen.pbPokemonScreen
    @scanning_team = false
  end

  def self.interact(id)
    t_id = (id >= 7000 && id <= 7015) ? id + 1000 : id; data = @trainer_data[t_id]; return if !data
    return if data[:despawning]
    @interacted_trainer_id = id
    
    trainer_event = $game_map.events[t_id]
    pet_event = data[:p_id] ? $game_map.events[data[:p_id]] : nil
    
    old_move_type = nil
    old_pet_move_type = nil

    if trainer_event
      old_move_type = trainer_event.move_type
      trainer_event.move_type = 0
      trainer_event.turn_toward_player if trainer_event.respond_to?(:turn_toward_player)
    end

    if pet_event
      old_pet_move_type = pet_event.move_type
      pet_event.move_type = 0
      pet_event.turn_toward_player if pet_event.respond_to?(:turn_toward_player)
    end

    team = self.materialize_team(data)
    pbPlayCry(team[0]) if id < 8000
    commands = [_INTL("Challenge Trainer"), _INTL("Scan Team"), _INTL("Please move"), _INTL("Cancel")]
    choice = pbMessage(_INTL("{1}\n{2}", data[:name], data[:has_shiny] ? "Wow! They have a shiny!" : ""), commands, 4)
    case choice
    when 0 then self.trigger_battle(data, t_id)
    when 1
      pbMessage(_INTL("Scanning {1}'s team...", data[:name]))
      self.scan_team(team)
    when 2
      self.please_move(t_id, data)
    end

    # Restore movement
    if choice != 2
      if trainer_event && !data[:despawning] && old_move_type
        trainer_event.move_type = old_move_type
      end
      if pet_event && !data[:despawning] && old_pet_move_type
        pet_event.move_type = old_pet_move_type
      end
    end
    @interacted_trainer_id = nil
  end

  def self.please_move(t_id, data)
    event = $game_map.events[t_id]
    return if !event || !data
    
    px = $game_player.x
    py = $game_player.y
    tx = event.x
    ty = event.y
    
    # Calculate preferred target (reflection)
    target_x = px + (px - tx)
    target_y = py + (py - ty)
    
    final_x = -1
    final_y = -1
    
    if $game_map.passable?(target_x, target_y, 0, event)
      final_x = target_x
      final_y = target_y
    else
      # Try other adjacent tiles to the player
      [[px+1, py], [px-1, py], [px, py+1], [px, py-1]].each do |cx, cy|
        next if cx == tx && cy == ty
        if $game_map.passable?(cx, cy, 0, event)
          final_x = cx
          final_y = cy
          break
        end
      end
    end
    
    if final_x != -1
      pbMessage(_INTL("Oh, sorry! Let me get out of your way."))
      
      # Perform the move
      old_through = event.through
      event.through = true
      
      # Step onto player
      event.move_speed = 4 # Walk a bit faster
      dx = px - tx
      dy = py - ty
      if dx != 0
        dx > 0 ? event.move_right : event.move_left
      elsif dy != 0
        dy > 0 ? event.move_down : event.move_up
      end
      
      while event.moving?; Graphics.update; Input.update; $scene.update; end
      
      # Step to final position
      dx = final_x - px
      dy = final_y - py
      if dx != 0
        dx > 0 ? event.move_right : event.move_left
      elsif dy != 0
        dy > 0 ? event.move_down : event.move_up
      end
      
      while event.moving?; Graphics.update; Input.update; $scene.update; end
      
      # Optional: Try one more step away in the same direction
      # This addresses "B) Take an additional step away from the player"
      extra_x = final_x + dx
      extra_y = final_y + dy
      if $game_map.passable?(extra_x, extra_y, 0, event)
        if dx != 0
          dx > 0 ? event.move_right : event.move_left
        elsif dy != 0
          dy > 0 ? event.move_down : event.move_up
        end
        while event.moving?; Graphics.update; Input.update; $scene.update; end
      end
      
      event.through = old_through
      
      # Update companion pet position immediately
      if data[:p_id] && $game_map.events[data[:p_id]]
        pet = $game_map.events[data[:p_id]]
        pet.moveto(event.x, event.y)
      end
      
      # Briefly pause to let the player pass
      event.move_type = 0
    else
      pbMessage(_INTL("Sorry, I'm a bit boxed in here!"))
    end
  end

  def self.trigger_battle(data, t_id)
    team = self.materialize_team(data)
    trainer = NPCTrainer.new(data[:name], :YOUNGSTER)
    team.each { |pkmn| trainer.party.push(pkmn) }
    decision = pbTrainerBattleCore(trainer)
    if decision == 1 # Victory
      self.start_despawn_sequence(t_id)
      pbMessage(_INTL("I better go to the Pokemon Center!"))
    end
  end

  def self.start_despawn_sequence(t_id)
    data = @trainer_data[t_id]; return if !data
    self.remove_pet(t_id)
    data[:despawning] = true
    data[:last_exit_x] = -1; data[:last_exit_y] = -1 # Init for stuck check
    data[:stuck_count] = 0
    event = $game_map.events[t_id]
    if event
      event.move_speed = 3.5
      event.move_frequency = 5
      event.walk_anime = true
    end
  end

  def self.remove_pet(t_id)
    data = @trainer_data[t_id]; return if !data
    p_id = data[:p_id]
    if p_id
      @spawned_ids.delete(p_id)
      if $game_map.events[p_id]
        if $scene.is_a?(Scene_Map) && $scene.spriteset
          $scene.spriteset.addUserAnimation(2, $game_map.events[p_id].x, $game_map.events[p_id].y, true, 2) rescue nil
        end
        $game_map.events[p_id].erase if $game_map.events[p_id]
        $game_map.events.delete(p_id)
      end
    end
  end

  def self.remove_trainer(t_id)
    if $game_map.events[t_id]
      if $scene.is_a?(Scene_Map) && $scene.spriteset
        $scene.spriteset.addUserAnimation(2, $game_map.events[t_id].x, $game_map.events[t_id].y, true, 2) rescue nil
      end
      $game_map.events[t_id].erase if $game_map.events[t_id]
      $game_map.events.delete(t_id)
    end
    @spawned_ids.delete(t_id)
    @trainer_data.delete(t_id)
  end
end

Events.onMapUpdate += proc { |_sender, e|
  WanderingTrainersMod.update
  if $game_map
    WanderingTrainersMod.spawned_ids.each do |id|
      if id >= 7000 && id <= 7015
        t_id = id + 1000; t = $game_map.events[t_id]; p = $game_map.events[id]
        if p && t && !p.erased && !t.erased
          # Skip move toward logic if we are interacting with this pair
          unless WanderingTrainersMod.instance_variable_get(:@interacted_trainer_id) == id || 
                 WanderingTrainersMod.instance_variable_get(:@interacted_trainer_id) == t_id
            p.ghostnpc_move_toward(t) if (t.x - p.x).abs > 1 || (t.y - p.y).abs > 1
          end
        end
      end
    end
  end
}

Events.onMapSceneChange += proc { |_sender, e|
  # Keep trainer data across battles/menus, only clear if we actually changed maps
  if $game_map && WanderingTrainersMod.instance_variable_get(:@last_spawned_map) != $game_map.map_id
    WanderingTrainersMod.clear_all_spawns(true)
  end
  WanderingTrainersMod.instance_variable_set(:@spawn_cooldown, 40)
}

class Game_Player
  alias ghostnpc_wt_v74_check check_event_trigger_there unless method_defined?(:ghostnpc_wt_v74_check)
  def check_event_trigger_there(triggers)
    result = ghostnpc_wt_v74_check(triggers)
    return result if result
    return false if $game_system.map_interpreter.running?
    new_x = @x + (@direction == 6 ? 1 : @direction == 4 ? -1 : 0); new_y = @y + (@direction == 2 ? 1 : @direction == 8 ? -1 : 0)
    $game_map.events.values.each do |event|
      next if !event || event.erased
      if event && ((event.id >= 8000 && event.id <= 8015) || (event.id >= 7000 && event.id <= 7015))
        if event.at_coordinate?(new_x, new_y) || ((event.real_x / 128.0 - new_x).abs < 0.8 && (event.real_y / 128.0 - new_y).abs < 0.8)
          WanderingTrainersMod.interact(event.id); return true
        end
      end
    end
    return false
  end
end


# ============================================================================
# UI Monkey-patches for Wandering Trainers Scan Mode
# ============================================================================

# Hook into the background creation to apply the tint IMMEDIATELY.
# This prevents the 1-2 frame flicker of the original background.
alias ghostnpc_scan_addBackgroundPlane addBackgroundPlane
def addBackgroundPlane(sprites, planename, background, viewport = nil)
  ghostnpc_scan_addBackgroundPlane(sprites, planename, background, viewport)
  if WanderingTrainersMod.is_scanning? && planename == "partybg"
    # Hue 45 is Orange. Hue 140 was the previous blue/purple tint.
    if sprites[planename].respond_to?(:setBitmap)
      sprites[planename].setBitmap("Graphics/Pictures/#{background}", 45)
    end
  end
end

class PokemonParty_Scene
  alias ghostnpc_scan_pbSummary pbSummary unless method_defined?(:ghostnpc_scan_pbSummary)
  def pbSummary(pkmnid, inbattle = false)
    # If scanning, force inbattle = true to disable interaction menu in Summary
    inbattle = true if WanderingTrainersMod.is_scanning?
    ghostnpc_scan_pbSummary(pkmnid, inbattle)
  end
end

class PokemonPartyScreen
  alias ghostnpc_scan_pbPokemonScreen pbPokemonScreen unless method_defined?(:ghostnpc_scan_pbPokemonScreen)
  def pbPokemonScreen
    return ghostnpc_scan_pbPokemonScreen if !WanderingTrainersMod.is_scanning?
    
    # Restricted version of the party screen for scanning
    @scene.pbStartScene(@party, _INTL("Scanning team..."), nil)
    loop do
      @scene.pbSetHelpText(_INTL("Choose a Pokémon."))
      # pbChoosePokemon(switching, initialsel, canswitch)
      # canswitch = 2 disables the ACTION button switch shortcut
      pkmnid = @scene.pbChoosePokemon(false, -1, 2)
      break if pkmnid < 0
      
      pkmn = @party[pkmnid]
      commands = []
      cmdSummary = -1
      
      commands[cmdSummary = commands.length] = _INTL("Summary")
      commands[commands.length] = _INTL("Cancel")
      
      command = @scene.pbShowCommands(_INTL("Do what with {1}?", pkmn.name), commands)
      if cmdSummary >= 0 && command == cmdSummary
        @scene.pbSummary(pkmnid) {
          @scene.pbSetHelpText(_INTL("Choose a Pokémon."))
        }
      end
    end
    @scene.pbEndScene
  end
end

# SECTION: UNINSTALL SANITIZATION
# ============================================================================
module WanderingTrainersMod
  def self.sanitize_for_uninstall
    if pbConfirmMessageSerious(_INTL("This will permanently delete all wandering trainers from your current map to prepare for mod removal. Proceed?"))
      if $game_map
        # Target and delete the specific injected ID blocks
        $game_map.events.keys.each do |id|
          if (id >= 7000 && id <= 7015) || (id >= 8000 && id <= 8015)
            # Optional: Play the despawn animation for visual feedback
            if $scene.is_a?(Scene_Map) && $scene.spriteset
              $scene.spriteset.addUserAnimation(2, $game_map.events[id].x, $game_map.events[id].y, true, 2) rescue nil
            end
            $game_map.events[id].erase if $game_map.events[id]
            $game_map.events.delete(id)
          end
        end
        
        # Clear the internal arrays to prevent immediate respawning before saving
        @spawned_ids = []
        @trainer_data = {}
        @spawn_queue = []
        @spawn_cooldown = 9999 # Lock out new spawns
      end
      pbMessage(_INTL("Wandering Trainers have been wiped from the map. You can now save your game normally and delete the mod script safely."))
    end
  end
end

# Inject into the Mod Settings Menu
if defined?(ModSettingsMenu)
  unless ModSettingsMenu.categories.any? { |c| c[:name] == "Ghost Settings" }
    ModSettingsMenu.categories << {
      name: "Ghost Settings",
      priority: 85,
      description: "Settings for GhostXYZ mods",
      collapsed: true
    }
  end

  ModSettingsMenu.register(:wt_shiny_rate, {
    name: "NPC: Shiny Spawn Rate (Debug)",
    type: :slider,
    category: "Ghost Settings",
    save_key: "wt_shiny_rate",
    min: 0,
    max: 100,
    interval: 5,
    default: 0,
    description: "Adjust shiny odds for wandering trainers. 0% uses standard odds (0.1%)."
  })

  ModSettingsMenu.register(:wt_uninstall_prep, {
    name: "NPC: Wandering Trainers Uninstall Prep",
    type: :button,
    category: "Ghost Settings",
    description: "Clears all wandering trainers from the current map to prepare for mod removal.",
    on_press: proc {
      WanderingTrainersMod.sanitize_for_uninstall
    }
  })

end