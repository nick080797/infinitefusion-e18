#========================================
# Player Housing Mod
# KIF Version: 0.20.7+
# Script Version: 1.1.0 (Robust Menu Integration)
#========================================

# Console log to confirm loading
puts "[Player Housing] Mod script initializing..."

# ============================================================================
# SECTION 1: CONSTANTS & SETTINGS
# ============================================================================
module PlayerHousingSettings
  HOUSING_MAP_ID = 999
  HOUSING_MAP_WIDTH  = 15
  HOUSING_MAP_HEIGHT = 13
  HOUSING_SPAWN_X   = 7
  HOUSING_SPAWN_Y   = 11
  HOUSING_SPAWN_DIR = 8
  EXIT_TILE_X = 7
  EXIT_TILE_Y = 12
  HOUSING_TILESET_ID = 999 # Changed to 999 to avoid conflict with standard tilesets
  MENU_LABEL = "Secret Base"
  MAP_NAME = "Player's Home"
  # Dynamic Mod Directory Resolution
  def self.base_dir
    mod_name = "GhostBase_PlayerHousing"
    if Dir.exist?("ModDev/#{mod_name}/GhostBase")
      "ModDev/#{mod_name}/GhostBase"
    elsif Dir.exist?("Mods/#{mod_name}/GhostBase")
      "Mods/#{mod_name}/GhostBase"
    else
      "Graphics/GhostBase"
    end
  end

  # Assets
  FURNITURE_ROOT = "#{base_dir()}/Furniture/"
  TILESET_ROOT   = "#{base_dir()}/Tilesets/"

  # Helper to convert stored graphic path to actual file path
  def self.resolve_path(graphic)
    if graphic.start_with?("GhostBase/")
      # Redirect legacy paths from save files
      return base_dir() + "/" + graphic.sub("GhostBase/", "")
    end
    graphic # it's completely possible the save has the absolute path already
  end

  # Helper to generate character_name / tileset_name relative jump
  def self.engine_escape_path(graphic)
    actual_path = resolve_path(graphic)
    if actual_path.start_with?("Graphics/")
      "../" + actual_path.sub("Graphics/", "")
    else
      "../../" + actual_path
    end
  end
end

# ============================================================================
# SECTION 2: CORE MODULE
# ============================================================================
module PlayerHousing
  @visiting_data = nil

  def self.set_visiting_data(data)
    @visiting_data = data
  end

  def self.current_housing_data
    @visiting_data || housing_data
  end

  def self.visit_home(data, return_point = nil)
    # Preservation logic: if entering from outside, or preserving an existing overworld return point
    unless return_point
      if $game_map.map_id != PlayerHousingSettings::HOUSING_MAP_ID || ($PokemonGlobal.respond_to?(:home_return_point) && !$PokemonGlobal.home_return_point)
        return_point = [$game_map.map_id, $game_player.x, $game_player.y, $game_player.direction]
      elsif $PokemonGlobal.respond_to?(:home_return_point)
        return_point = $PokemonGlobal.home_return_point
      end
    end

    self.set_visiting_data(data)
    ensure_map_info
    $PokemonGlobal.home_return_point = return_point if defined?($PokemonGlobal)

    if $game_map.map_id == PlayerHousingSettings::HOUSING_MAP_ID
      # Already inside a house map (999), forcing reload since transfer_player ignores same-map transfers
      $game_player.moveto(PlayerHousingSettings::HOUSING_SPAWN_X, PlayerHousingSettings::HOUSING_SPAWN_Y)
      $game_player.direction = PlayerHousingSettings::HOUSING_SPAWN_DIR
      PlayerHousing.reload_housing_map
    else
      pbFadeOutIn do
        $game_temp.player_transferring = true
        $game_temp.transition_processing = true
        $game_temp.player_new_map_id = PlayerHousingSettings::HOUSING_MAP_ID
        $game_temp.player_new_x = PlayerHousingSettings::HOUSING_SPAWN_X
        $game_temp.player_new_y = PlayerHousingSettings::HOUSING_SPAWN_Y
        $game_temp.player_new_direction = PlayerHousingSettings::HOUSING_SPAWN_DIR
        if $scene.respond_to?(:transfer_player)
          $scene.transfer_player
        end
      end
    end
  end

  def self.build_virtual_map
    ensure_map_info # Refresh dynamic tileset bitmap
    h_data = current_housing_data
    w = h_data["width"] || PlayerHousingSettings::HOUSING_MAP_WIDTH
    h = h_data["height"] || PlayerHousingSettings::HOUSING_MAP_HEIGHT
    map = RPG::Map.new(w, h)
    map.tileset_id = PlayerHousingSettings::HOUSING_TILESET_ID

    # Simple Layout: Roof = 384, Wall = 385, Floor = 386
    (0...h).each do |y|
      (0...w).each do |x|
        # Roof is outer edge, Wall is below it
        if (y == 0 || y == h - 1 || x == 0 || x == w - 1)
          map.data[x, y, 2] = 384 # Roof on Layer 2 for max depth
        elsif y == 1
          map.data[x, y, 1] = 385 # Wall on Layer 1
        else
          map.data[x, y, 0] = 386 # Floor on Layer 0
        end
      end
    end
    # Force entryway (exit door) to be floor
    # Force entryway (exit door) to be floor and clear higher layers
    map.data[PlayerHousingSettings::EXIT_TILE_X, PlayerHousingSettings::EXIT_TILE_Y, 0] = 386
    map.data[PlayerHousingSettings::EXIT_TILE_X, PlayerHousingSettings::EXIT_TILE_Y, 1] = 0
    map.data[PlayerHousingSettings::EXIT_TILE_X, PlayerHousingSettings::EXIT_TILE_Y, 2] = 0

    # 1. Exit Door Event
    ev = RPG::Event.new(PlayerHousingSettings::EXIT_TILE_X, PlayerHousingSettings::EXIT_TILE_Y)
    ev.id = 1
    ev.name = "HousingExit"
    ev.pages[0].trigger = 1  # Player Touch
    s_cmd = RPG::EventCommand.new; s_cmd.code = 355; s_cmd.indent = 0
    s_cmd.parameters = ["PlayerHousing.return_to_overworld"]
    e_cmd = RPG::EventCommand.new; e_cmd.code = 0; e_cmd.indent = 0; e_cmd.parameters = []
    ev.pages[0].list = [s_cmd, e_cmd]
    map.events[ev.id] = ev

    # 2. Saved Furniture Events
    ev_id = 2
    if h_data["furniture"]
      sorted_furniture = h_data["furniture"].sort_by do |f|
        if f["is_carpet"]
          0
        elsif f["is_desk"]
          2
        else
          1
        end
      end

      sorted_furniture.each do |f_data|
        f_ev = RPG::Event.new(f_data["x"], f_data["y"])
        f_ev.id = ev_id
        ev_name = f_data["name"] || "Furn"
        full_name = "#{f_data["id"]}_#{ev_name}"
        full_name += "[ZO:#{f_data["z_offset"]}]" if f_data["z_offset"] && f_data["z_offset"] != 0
        full_name += "[XN:#{f_data["x_nudge"]}]" if f_data["x_nudge"] && f_data["x_nudge"] != 0
        full_name += "[YN:#{f_data["y_nudge"]}]" if f_data["y_nudge"] && f_data["y_nudge"] != 0
        f_ev.name = full_name
        # Hack for engine: escape the default sprite folder using dynamic mod paths
        f_ev.pages[0].graphic.character_name = PlayerHousingSettings.engine_escape_path(f_data["graphic"])
        f_ev.pages[0].trigger = 0  # Action button
        f_ev.pages[0].direction_fix = true
        f_ev.pages[0].walk_anime = false # Single frame sprite support
        f_ev.pages[0].step_anime = false

        # Only carpets and desks are non-solid at the anchor tile.
        # Passable items ('p' flag) are solid at the base and only passable on upper tiles.
        if (f_data["is_carpet"] || f_data["is_desk"]) && !f_data["is_pc"]
          f_ev.pages[0].through = true
        end

        s_cmd = RPG::EventCommand.new; s_cmd.code = 355; s_cmd.indent = 0
        if f_data["is_pc"]
          s_cmd.parameters = ["PlayerHousing.interact_builder_pc('#{f_data["id"]}')"]
        else
          s_cmd.parameters = ["PlayerHousing.interact_furniture('#{f_data["id"]}')"]
        end
        e_cmd = RPG::EventCommand.new; e_cmd.code = 0; e_cmd.indent = 0; e_cmd.parameters = []
        f_ev.pages[0].list = [s_cmd, e_cmd]
        map.events[f_ev.id] = f_ev
        ev_id += 1

        # Add footprint dummy events
        fw = f_data["width"] || 1
        fh = f_data["height"] || 1
        # If passable ('p' flag), the upper tiles (dy >= solid_height) are skipped entirely,
        # making them passable while the bottom row(s) remain collidable.
        eff_h = f_data["solid_height"] || (f_data["passable"] ? 1 : fh)

        (0...fw).each do |dx|
          (0...eff_h).each do |dy|
            next if dx == 0 && dy == 0 # Skip primary event coordinate
            dx_pos = f_data["x"] + dx
            dy_pos = f_data["y"] - dy
            d_ev = RPG::Event.new(dx_pos, dy_pos)
            d_ev.id = ev_id
            d_ev.name = "Dummy_#{f_data["id"]}"
            # Dummy events are solid unless the item is a carpet.
            d_ev.pages[0].graphic.character_name = PlayerHousingSettings.engine_escape_path(f_data["graphic"])
            d_ev.pages[0].trigger = 0
            d_ev.pages[0].direction_fix = true
            d_ev.pages[0].through = ((f_data["is_carpet"] == true || f_data["is_desk"] == true) && !f_data["is_pc"])

            s_cmd2 = RPG::EventCommand.new; s_cmd2.code = 355; s_cmd2.indent = 0
            if f_data["is_pc"]
              s_cmd2.parameters = ["PlayerHousing.interact_builder_pc('#{f_data["id"]}')"]
            else
              s_cmd2.parameters = ["PlayerHousing.interact_furniture('#{f_data["id"]}')"]
            end
            e_cmd2 = RPG::EventCommand.new; e_cmd2.code = 0; e_cmd2.indent = 0; e_cmd2.parameters = []
            d_ev.pages[0].list = [s_cmd2, e_cmd2]
            map.events[d_ev.id] = d_ev
            ev_id += 1
          end
        end
      end
    end
    # 3. Safety: PC Check
    # (Moved to on_enter_map handler for reliable triggering)

    map
  end

  class ::Game_Event
    def name
      return @event.name if @event
      return ""
    end
  end

  # Robust custom passability: Intercept Game_Map passable? directly.
  # This ignores the underlying Tileset passage data completely for our map!
  class ::Game_Map
    alias __housing_mod_original_passable? passable? unless method_defined?(:__housing_mod_original_passable?)

    def passable?(x, y, d, self_event = nil)
      if @map_id == PlayerHousingSettings::HOUSING_MAP_ID
        # 1. Determine target coordinates
        nx = x + (d == 6 ? 1 : d == 4 ? -1 : 0)
        ny = y + (d == 2 ? 1 : d == 8 ? -1 : 0)

        # 2. Map Boundaries: Block Roof (edges) and Wall (Y=1)
        # Exception: Perfectly passable if entering the exit door tile
        is_exit = (nx == PlayerHousingSettings::EXIT_TILE_X && ny == PlayerHousingSettings::EXIT_TILE_Y)
        return true if is_exit

        # Outer boundaries
        return false if nx <= 0 || nx >= self.width - 1
        return false if ny <= 1 || ny >= self.height - 1

        # 3. Event/Furniture Collision on Target Tile
        # We manually check events because dummy events for furniture
        # need robust coordinate-based collision on this virtual map.
        self.events.each_value do |event|
          next if event == self_event
          next if event.erased || event.through
          if event.x == nx && event.y == ny
            return false
          end
        end

        # 4. Player Collision (if checked by an NPC/Pet)
        if self_event != $game_player
          if $game_player.x == nx && $game_player.y == ny && !$game_player.through
            return false
          end
        end

        return true # Everything else within floor area is passable
      end
      return __housing_mod_original_passable?(x, y, d, self_event)
    end
  end

  # ============================================================================
  # CORE ENGINE PATCHES: MAP FACTORY ISOLATION & RENDERER RESET
  # (Fixes flickering background maps due to overworld connections)
  # ============================================================================

  class ::PokemonMapFactory
    alias __housing_orig_updateMapsInternal updateMapsInternal unless method_defined?(:__housing_orig_updateMapsInternal)
    def updateMapsInternal
      # If we are on the housing map, explicitly clear any other maps.
      # This prevents connected maps from the previous overworld location from sticking around.
      if $game_map && $game_map.map_id == PlayerHousingSettings::HOUSING_MAP_ID
        if @maps.length > 1
          @maps.delete_if { |m| m && m.map_id != PlayerHousingSettings::HOUSING_MAP_ID }
          @mapIndex = getMapIndex(PlayerHousingSettings::HOUSING_MAP_ID)
        end
        return
      end
      __housing_orig_updateMapsInternal
    end
  end

  class ::TilemapRenderer
    alias __housing_orig_check_if_screen_moved check_if_screen_moved unless method_defined?(:__housing_orig_check_if_screen_moved)
    def check_if_screen_moved
      # Detect transitions to/from the Housing Map
      if @current_map_id != $game_map.map_id
        is_housing = ($game_map.map_id == PlayerHousingSettings::HOUSING_MAP_ID)
        was_housing = (@current_map_id == PlayerHousingSettings::HOUSING_MAP_ID)
        
        if is_housing || was_housing
          # Force a hard reset of camera map id to bypass relative connection shifts.
          # We zero out pixel offsets internally, but let the original script run to 
          # recalculate proper tile offsets based on display_x/display_y.
          @current_map_id = $game_map.map_id
          @pixel_offset_x = 0
          @pixel_offset_y = 0
          
          # Call original -- this will skip the map_id check (since we updated it)
          # but will run the tile offset recalibration, preventing visual decoupling.
          __housing_orig_check_if_screen_moved
          
          return true # Force full refresh
        end
      end
      return __housing_orig_check_if_screen_moved
    end
  end

  def self.ensure_map_info
    h_data = current_housing_data
    map_id = PlayerHousingSettings::HOUSING_MAP_ID
    ts_id = PlayerHousingSettings::HOUSING_TILESET_ID

    # Ensure Map Info exists in the engine's cache
    mapinfos = pbLoadMapInfos rescue nil
    if mapinfos && !mapinfos[map_id]
      info = RPG::MapInfo.new
      info.name = PlayerHousingSettings::MAP_NAME
      info.parent_id = 0
      info.order = 999
      mapinfos[map_id] = info
    end

    # Also check $data_mapinfos for older engine compatibility
    if defined?($data_mapinfos) && $data_mapinfos.is_a?(Hash) && !$data_mapinfos[map_id]
      info = RPG::MapInfo.new
      info.name, info.parent_id, info.order = PlayerHousingSettings::MAP_NAME, 0, 999
      $data_mapinfos[map_id] = info
    end

    # 2. Build Dynamic Tileset Image (Combine current r#, w#, f#)
    if defined?($data_tilesets)
      r_id = h_data["roof_id"] || 1
      w_id = h_data["wall_id"] || 1
      f_id = h_data["floor_id"] || 1

      # We create a standard 256-pixel wide tileset (8 tiles per row)
      # 384: Roof, 385: Wall, 386: Floor
      final_bmp = Bitmap.new(256, 32)

      # Load Assets from dynamic Tilesets directory
      r_path = PlayerHousingSettings::TILESET_ROOT + "r#{r_id}"
      r_bmp = pbResolveBitmap(r_path) ? AnimatedBitmap.new(r_path).bitmap : nil
      final_bmp.blt(0, 0, r_bmp, Rect.new(0, 0, 32, 32)) if r_bmp

      w_path = PlayerHousingSettings::TILESET_ROOT + "w#{w_id}"
      w_bmp = pbResolveBitmap(w_path) ? AnimatedBitmap.new(w_path).bitmap : nil
      final_bmp.blt(32, 0, w_bmp, Rect.new(0, 0, 32, 32)) if w_bmp

      f_path = PlayerHousingSettings::TILESET_ROOT + "f#{f_id}"
      f_bmp = pbResolveBitmap(f_path) ? AnimatedBitmap.new(f_path).bitmap : nil
      final_bmp.blt(64, 0, f_bmp, Rect.new(0, 0, 32, 32)) if f_bmp

      # Bypass caching with explicit mod path handling
      cache_name = "GB_Active_#{Time.now.to_i % 10000}"
      cache_path = "#{PlayerHousingSettings::TILESET_ROOT}#{cache_name}.png"
      
      # Clean up OLD dynamic tileset files
      Dir.glob("Graphics/Tilesets/GB_Active_*.png").each { |f| File.delete(f) rescue nil }
      Dir.glob("#{PlayerHousingSettings::TILESET_ROOT}GB_Active_*.png").each { |f| File.delete(f) rescue nil }

      # Create directory just in case it's missing (Dev environment safety)
      Dir.mkdir(PlayerHousingSettings::TILESET_ROOT) unless Dir.exist?(PlayerHousingSettings::TILESET_ROOT) rescue nil

      final_bmp.save_to_png(cache_path)

      # Cleanup OLD dynamic tileset from TilemapRenderer cache if it exists
      if ($scene.is_a?(Scene_Map) && $scene.respond_to?(:map_renderer) && $scene.map_renderer) || (defined?($scene.spritesetGlobal) && $scene.spritesetGlobal && $scene.spritesetGlobal.respond_to?(:map_renderer) && $scene.spritesetGlobal.map_renderer)
        renderer = $scene.respond_to?(:map_renderer) ? $scene.map_renderer : $scene.spritesetGlobal.map_renderer rescue nil
        if renderer && $data_tilesets[ts_id]
          old_ts_name = $data_tilesets[ts_id].tileset_name
          renderer.remove_tileset(old_ts_name) rescue nil
        end
      end

      ts = RPG::Tileset.new
      ts.id = ts_id
      ts.name = "GhostBase Builder"
      # Points to mod tilesets relative to Graphics/Tilesets/
      ts.tileset_name = PlayerHousingSettings.engine_escape_path("GhostBase/Tilesets/#{cache_name}")
      # Initialize Tables for RMXP engine
      ts.passages = Table.new(480)
      ts.priorities = Table.new(480)

      ts.passages[0]   = 0    # Empty tiles are passable
      ts.passages[384] = 0x0f # Impassable (Roof)
      ts.passages[385] = 0x0f # Impassable (Wall)
      ts.passages[386] = 0    # Passable (Floor)

      ts.priorities[384] = 5  # Roof renders above EVERYTHING
      ts.priorities[385] = 0  # Walls render at default background depth
      $data_tilesets[ts_id] = ts

      final_bmp.dispose
    end
  end
  def self.housing_data
    return {} unless defined?($PokemonGlobal) && $PokemonGlobal
    $PokemonGlobal.player_housing_data ||= {}
    $PokemonGlobal.player_housing_data["roof_id"]   ||= 1
    $PokemonGlobal.player_housing_data["wall_id"]   ||= 1
    $PokemonGlobal.player_housing_data["floor_id"]  ||= 1
    $PokemonGlobal.player_housing_data["furniture"] ||= []
    $PokemonGlobal.player_housing_data["inventory"] ||= []
    $PokemonGlobal.player_housing_data["width"]     ||= PlayerHousingSettings::HOUSING_MAP_WIDTH
    $PokemonGlobal.player_housing_data["height"]    ||= PlayerHousingSettings::HOUSING_MAP_HEIGHT

    # Robust Furniture Cleanup: Remove items with missing graphics.
    # This automatically clears legacy objects (Rocks/Plants) as they were removed
    # from the files, while being safer for future updates.
    cleanup = proc do |list|
      list.reject! do |item|
        graphic = item["graphic"].to_s
        name = item["name"].to_s.downcase
        # Robust graphic check backwards-compatible with old saves
        path = PlayerHousingSettings.resolve_path(graphic)
        missing = !pbResolveBitmap(path)
        # Explicit name check for user-requested items
        is_legacy = name.include?("potted plant") || name.include?("breakable rock")
        missing || is_legacy
      end
    end
    cleanup.call($PokemonGlobal.player_housing_data["furniture"])
    cleanup.call($PokemonGlobal.player_housing_data["inventory"])

    return $PokemonGlobal.player_housing_data
  end

  def self.add_to_inventory(item)
    h_data = housing_data
    h_data["inventory"] ||= []
    inv_item = (item.is_a?(Hash) ? item.dup : {
      "name" => item["name"] || item[:name],
      "graphic" => item["graphic"] || item[:graphic],
      "width" => item["width"] || item[:width] || 1,
      "height" => item["height"] || item[:height] || 1
    })
    # Strip position-specific keys but keep everything else
    ["id", "x", "y", "z_offset", "x_nudge", "y_nudge"].each { |k| inv_item.delete(k) }
    h_data["inventory"] << inv_item
  end

  def self.at_home?; $game_map && $game_map.map_id == PlayerHousingSettings::HOUSING_MAP_ID; end

    def self.open_housing_menu
      if @visiting_data
        cmds = ["Leave Home", "Cancel"]
        cmd = (respond_to?(:pbShowCommands) || Kernel.respond_to?(:pbShowCommands)) ? pbShowCommands(nil, cmds, -1) : pbMessage(_INTL("Secret Base Menu:"), cmds, -1)
        return_to_overworld if cmd == 0
        return
      end

      loop do
        commands = ["Place Furniture", "Change Room Style", "Leave Home", "Cancel"]

        cmd = (respond_to?(:pbShowCommands) || Kernel.respond_to?(:pbShowCommands)) ? pbShowCommands(nil, commands, -1) : pbMessage(_INTL("Secret Base Menu:"), commands, -1)
        break if cmd < 0 || (cmd == commands.length - 1)  # B or Cancel

        sel = commands[cmd]
        if sel == "Place Furniture"
          place_furniture_ui
        elsif sel == "Change Room Style"
          change_room_style_ui
        elsif sel == "Leave Home"
          return_to_overworld
          break
        end
      end
    end

    def self.visit_friend_ui
      return unless defined?(MultiplayerClient) && MultiplayerClient.respond_to?(:in_squad?) && MultiplayerClient.in_squad?

      squad = MultiplayerClient.squad rescue nil
      return unless squad && squad[:members].is_a?(Array)

      my_sid = MultiplayerClient.session_id.to_s
      players = []
      squad[:members].each do |m|
        sid = m[:sid].to_s
        next if sid == my_sid || sid.empty?
        players << { sid: sid, name: m[:name].to_s }
      end

      if players.empty?
        pbMessage(_INTL("No other squad members found."))
        return
      end

      cmds = players.map { |p| p[:name] }
      cmds << "Cancel"
      cmd = (respond_to?(:pbShowCommands) || Kernel.respond_to?(:pbShowCommands)) ? pbShowCommands(nil, cmds, -1) : pbMessage(_INTL("Visit who?"), cmds, -1)

      if cmd >= 0 && cmd < players.length
        target = players[cmd]

        # Send the request BEFORE any blocking UI
        PlayerHousingMP.pending_visit_target = target[:sid]
        PlayerHousingMP.pending_visit_data = nil
        PlayerHousingMP.send_visit_request(target[:sid])

        # Wait for response with timeout
        timeout = 5.0  # seconds
        start_time = Time.now

        vp = Viewport.new(0, 0, Graphics.width, Graphics.height)
        vp.z = 99999
        msgwindow = Window_AdvancedTextPokemon.newWithSize(_INTL("Requesting base data from {1}...", target[:name]), 16, Graphics.height - 96, Graphics.width - 32, 80, vp)

        # Poll until we get data or timeout
        while (Time.now - start_time) < timeout
          Graphics.update
          Input.update
          msgwindow.update
          break if PlayerHousingMP.pending_visit_data
        end

        msgwindow.dispose
        vp.dispose

        if PlayerHousingMP.pending_visit_data
          data = PlayerHousingMP.pending_visit_data
          owner_sid = target[:sid]
          PlayerHousingMP.pending_visit_data = nil
          PlayerHousingMP.pending_visit_target = nil

          # Set our instance to the host's SID and transition
          PlayerHousing.housing_instance_owner = owner_sid
          PlayerHousing.visit_home(data)
        else
          PlayerHousingMP.pending_visit_target = nil
          pbMessage(_INTL("{1}'s base is unavailable.", target[:name]))
        end
      end
    end

end # Close PlayerHousing

  class Game_Temp
    attr_accessor :player_housing_needs_menu
  end

  class Scene_Map
    alias __housing_mod_old_update update unless method_defined?(:__housing_mod_old_update)
    def update
      __housing_mod_old_update
      if $game_temp && $game_temp.respond_to?(:player_housing_needs_menu) && $game_temp.player_housing_needs_menu
        $game_temp.player_housing_needs_menu = false
        PlayerHousing.open_housing_menu
      end
    end
  end

  module PlayerHousing
    def self.go_home
      if at_home?
        $game_temp.player_housing_needs_menu = true
        return
      end
      ensure_map_info
      housing_data # Ensure initialized
      self.set_visiting_data(nil) # Ensure we are at OUR home
      self.housing_instance_owner = "self"

      $PokemonGlobal.home_return_point = [$game_map.map_id, $game_player.x, $game_player.y, $game_player.direction] if defined?($PokemonGlobal)
      pbFadeOutIn do
        $game_temp.player_transferring = true
        $game_temp.transition_processing = true
        $game_temp.player_new_map_id = PlayerHousingSettings::HOUSING_MAP_ID
        $game_temp.player_new_x = PlayerHousingSettings::HOUSING_SPAWN_X
        $game_temp.player_new_y = PlayerHousingSettings::HOUSING_SPAWN_Y
        $game_temp.player_new_direction = PlayerHousingSettings::HOUSING_SPAWN_DIR
        if $scene.respond_to?(:transfer_player)
          $scene.transfer_player
          check_pc_safety # Run check inside the fade block after map changes
        end
      end
    end

    def self.main_menu_interaction
      in_squad = defined?(MultiplayerClient) && MultiplayerClient.respond_to?(:in_squad?) && MultiplayerClient.in_squad?
      if in_squad
        cmds = ["Mine", "Visit Friend", "Cancel"]
        cmd = (respond_to?(:pbShowCommands) || Kernel.respond_to?(:pbShowCommands)) ? pbShowCommands(nil, cmds, -1) : pbMessage(_INTL("Secret Base:"), cmds, -1)
        if cmd == 0
          go_home
          return 2 # 2 tells bag to close
        elsif cmd == 1
          visit_friend_ui
          return 2 # 2 tells bag to close
        end
        return 0 # 0 tells bag to stay open on cancel
      else
        go_home
        return 2 # 2 tells bag to close
      end
    end

    def self.check_pc_safety
      h_data = housing_data
      has_pc = false
      h_data["furniture"].each { |f| has_pc = true if f["is_pc"] } if h_data["furniture"]
      h_data["inventory"].each { |f| has_pc = true if f["is_pc"] } if h_data["inventory"]

      unless has_pc
        h_data["inventory"] ||= []
        h_data["inventory"] << { "name" => "Secret Base PC", "graphic" => PlayerHousingSettings::FURNITURE_ROOT + "BasePC", "is_pc" => true }
        pbMessage(_INTL("Your complimentary House-PC has been shipped directly to your Furniture inventory."))
      end
    end

    def self.return_to_overworld
      self.set_visiting_data(nil) # Clear visiting state
      self.housing_instance_owner = nil
      rp = defined?($PokemonGlobal) ? $PokemonGlobal.home_return_point : nil
      unless rp && rp.is_a?(Array) && rp.length >= 3
        pbMessage(_INTL("Returning to the last heal location."))
        heal = pbGetHealingSpot rescue nil
        rp = heal ? [heal[0], heal[1], heal[2], 2] : nil
      end
      return pbMessage(_INTL("Error: No return point.")) unless rp
      pbSEPlay("Door exit", 80, 100) rescue nil

      new_x, new_y, new_dir = rp[1], rp[2], rp[3] || 2

      # Safety: Only use stepped-out coordinates if they are passable on the target map
      # (Actually, in Essentials, we usually just trust the return point + 1)

      pbFadeOutIn do
        $game_temp.player_transferring = true
        $game_temp.transition_processing = true
        $game_temp.player_new_map_id = rp[0]
        $game_temp.player_new_x = new_x
        $game_temp.player_new_y = new_y
        $game_temp.player_new_direction = new_dir
        $scene.transfer_player if $scene.respond_to?(:transfer_player)
      end
    end

    # --- Furniture Shop: Window Shopping Grid UI ---

    def self.get_category_name(item)
      w = item["width"] || 1
      h = item["height"] || 1
      if item["is_desk"]
        return "Top"
      elsif item["is_carpet"]
        return "Carpet"
      elsif w == 1 && h == 1
        return "Small"
      elsif (w == 1 && h == 2) || (w == 2 && h == 1)
        return "Medium"
      else
        return "Large"
      end
    end

    def self.get_categories(catalog)
      categories = {
        "Small"  => [],
        "Medium" => [],
        "Large"  => [],
        "Carpet" => [],
        "Top"    => []
      }
      catalog.each do |item|
        cat = get_category_name(item)
        categories[cat] << item if categories[cat]
      end
      return categories
    end

    # Constants for the grid layout
    SHOP_COLS      = 4
    SHOP_ROWS      = 2
    SHOP_PER_PAGE  = SHOP_COLS * SHOP_ROWS  # 8 items per page

    class FurnitureShop_Scene
      attr_reader :mode

      def pbStartScene(catalog)
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = 99999
        @sprites = {}
        @catalog = catalog

        # Categorization
        @categories = PlayerHousing.get_categories(catalog)
        @cat_keys = ["Small", "Medium", "Large", "Carpet", "Top"]
        @current_cat_idx = 0
        @cursor_idx = 0       # Index within current category's full item list
        @page_offset = 0      # First item index of the current page
        @mode = :category     # Current interaction mode: :category or :grid

        # Layout constants (designed for 512x384, adapts to wider)
        @cell_w = (Graphics.width - 32) / PlayerHousing::SHOP_COLS   # ~120px each
        @cell_h = 132
        @grid_x = 16
        @grid_y = 52
        @header_h = 48
        @footer_h = 64

        # --- Draw Background ---
        @sprites["bg"] = Sprite.new(@viewport)
        bg_bmp = Bitmap.new(Graphics.width, Graphics.height)
        bg_bmp.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(25, 27, 35))
        # Subtle gradient header bar
        (0...@header_h).each do |y|
          alpha = 255 - (y * 3)
          bg_bmp.fill_rect(0, y, Graphics.width, 1, Color.new(31, 177, 196, [alpha, 40].max))
        end
        @sprites["bg"].bitmap = bg_bmp

        # --- Header Overlay (drawn directly on bitmap for stability) ---
        @sprites["header_text"] = Sprite.new(@viewport)
        hdr_bmp = Bitmap.new(Graphics.width, @header_h)
        hdr_bmp.font.size = 22
        hdr_bmp.font.color = Color.new(255, 255, 255)
        hdr_bmp.draw_text(16, 6, 300, 30, "Secret Base Boutique")
        @sprites["header_text"].bitmap = hdr_bmp

        # --- Category Tabs (drawn as a sprite row) ---
        @sprites["tabs"] = Sprite.new(@viewport)
        @sprites["tabs"].y = 4

        # --- Grid cell sprites (8 slots: preview sprite + label) ---
        PlayerHousing::SHOP_PER_PAGE.times do |i|
          col = i % PlayerHousing::SHOP_COLS
          row = i / PlayerHousing::SHOP_COLS
          cx = @grid_x + col * @cell_w
          cy = @grid_y + row * @cell_h

          # Cell background (subtle card)
          @sprites["cell_bg_#{i}"] = Sprite.new(@viewport)
          cell_bmp = Bitmap.new(@cell_w - 4, @cell_h - 4)
          cell_bmp.fill_rect(0, 0, cell_bmp.width, cell_bmp.height, Color.new(40, 44, 58))
          @sprites["cell_bg_#{i}"].bitmap = cell_bmp
          @sprites["cell_bg_#{i}"].x = cx + 2
          @sprites["cell_bg_#{i}"].y = cy + 2

          # Item preview sprite
          @sprites["cell_sprite_#{i}"] = Sprite.new(@viewport)
          @sprites["cell_sprite_#{i}"].x = cx + @cell_w / 2
          @sprites["cell_sprite_#{i}"].y = cy + @cell_h - 40
          @sprites["cell_sprite_#{i}"].visible = false

          # Item label (name + cost, drawn on a bitmap)
          @sprites["cell_label_#{i}"] = Sprite.new(@viewport)
          @sprites["cell_label_#{i}"].x = cx + 2
          @sprites["cell_label_#{i}"].y = cy + @cell_h - 36
        end

        # --- Cursor highlight ---
        @sprites["cursor"] = Sprite.new(@viewport)

        # --- Footer: Money + Page Info ---
        @sprites["footer"] = Sprite.new(@viewport)
        @sprites["footer"].y = Graphics.height - @footer_h

        # --- Initial draw ---
        refresh_tabs
        refresh_grid
        refresh_cursor
        refresh_footer
      end

      # ---- Refresh Methods ----

      def refresh_tabs
        bmp = Bitmap.new(Graphics.width, 32)
        bmp.font.size = 16
        x_off = Graphics.width - 16  # Right-align tabs
        # Draw right-to-left so they pack nicely
        tab_widths = @cat_keys.map { |n| bmp.text_size(n).width + 20 }
        total_w = tab_widths.sum
        x_off = Graphics.width - total_w - 16
        @cat_keys.each_with_index do |name, i|
          tw = tab_widths[i]
          if i == @current_cat_idx
            # Add a brighter highlight if in category mode
            tab_col = (@mode == :category) ? Color.new(50, 210, 230) : Color.new(31, 177, 196)
            bmp.fill_rect(x_off, 2, tw, 26, tab_col)
            # Outline if in category mode
            if @mode == :category
              bmp.fill_rect(x_off, 2, tw, 2, Color.new(255, 255, 255))
              bmp.fill_rect(x_off, 26, tw, 2, Color.new(255, 255, 255))
              bmp.fill_rect(x_off, 2, 2, 26, Color.new(255, 255, 255))
              bmp.fill_rect(x_off + tw - 2, 2, 2, 26, Color.new(255, 255, 255))
            end
            bmp.font.color = Color.new(255, 255, 255)
          else
            bmp.fill_rect(x_off, 2, tw, 26, Color.new(55, 60, 78))
            bmp.font.color = Color.new(180, 180, 190)
          end
          bmp.draw_text(x_off, 4, tw, 22, name, 1)
          x_off += tw + 4
        end
        @sprites["tabs"].bitmap.dispose if @sprites["tabs"].bitmap && !@sprites["tabs"].bitmap.disposed?
        @sprites["tabs"].bitmap = bmp
      end

      def set_mode(m)
        @mode = m
        refresh_tabs
        refresh_cursor
        refresh_footer
      end

      def current_items
        @categories[@cat_keys[@current_cat_idx]]
      end

      def refresh_grid
        items = current_items
        PlayerHousing::SHOP_PER_PAGE.times do |i|
          item_idx = @page_offset + i
          item = items[item_idx]

          # Cell background highlight for filled vs empty
          cell_bmp = Bitmap.new(@cell_w - 4, @cell_h - 4)
          if item
            cell_bmp.fill_rect(0, 0, cell_bmp.width, cell_bmp.height, Color.new(40, 44, 58))
          else
            cell_bmp.fill_rect(0, 0, cell_bmp.width, cell_bmp.height, Color.new(30, 32, 42))
          end
          @sprites["cell_bg_#{i}"].bitmap.dispose if @sprites["cell_bg_#{i}"].bitmap && !@sprites["cell_bg_#{i}"].bitmap.disposed?
          @sprites["cell_bg_#{i}"].bitmap = cell_bmp

          # Item sprite
          if item
            filename = PlayerHousingSettings.resolve_path(item["graphic"].to_s)
            if pbResolveBitmap(filename)
              src = AnimatedBitmap.new(filename).bitmap
              @sprites["cell_sprite_#{i}"].bitmap = src
              # For animated items the spritesheet is 2x2 frames — show only frame 0 (top-left)
              if item["anim_mode"]
                frame_w = src.width / 2
                frame_h = src.height / 2
                @sprites["cell_sprite_#{i}"].src_rect = Rect.new(0, 0, frame_w, frame_h)
                @sprites["cell_sprite_#{i}"].ox = frame_w / 2
                @sprites["cell_sprite_#{i}"].oy = frame_h
                # Scale to fit cell using frame dimensions
                max_w = @cell_w - 16
                max_h = @cell_h - 50
                scale = [2.0, max_w.to_f / frame_w, max_h.to_f / frame_h].min
              else
                @sprites["cell_sprite_#{i}"].ox = src.width / 2
                @sprites["cell_sprite_#{i}"].oy = src.height
                # Scale to fit cell (max 2x, but shrink if too big)
                max_w = @cell_w - 16
                max_h = @cell_h - 50
                scale = [2.0, max_w.to_f / src.width, max_h.to_f / src.height].min
              end
              @sprites["cell_sprite_#{i}"].zoom_x = scale
              @sprites["cell_sprite_#{i}"].zoom_y = scale
              @sprites["cell_sprite_#{i}"].visible = true
            else
              @sprites["cell_sprite_#{i}"].visible = false
            end
          else
            @sprites["cell_sprite_#{i}"].visible = false
          end

          # Label (name + cost)
          label_bmp = Bitmap.new(@cell_w - 4, 34)
          label_bmp.font.size = 14
          if item
            # Name
            label_bmp.font.color = Color.new(220, 225, 240)
            display_name = item["name"].to_s
            display_name = display_name[0, 14] + ".." if display_name.length > 16
            label_bmp.draw_text(2, 0, @cell_w - 8, 16, display_name, 1)
            # Cost
            label_bmp.font.color = Color.new(120, 220, 120)
            label_bmp.draw_text(2, 16, @cell_w - 8, 16, "$#{item["cost"]}", 1)
          end
          @sprites["cell_label_#{i}"].bitmap.dispose if @sprites["cell_label_#{i}"].bitmap && !@sprites["cell_label_#{i}"].bitmap.disposed?
          @sprites["cell_label_#{i}"].bitmap = label_bmp
        end
      end

      def refresh_cursor
        if @mode == :category
          @sprites["cursor"].visible = false
          return
        end
        items = current_items
        return if items.empty?
        @sprites["cursor"].visible = true

        local_idx = @cursor_idx - @page_offset
        col = local_idx % PlayerHousing::SHOP_COLS
        row = local_idx / PlayerHousing::SHOP_COLS
        cx = @grid_x + col * @cell_w
        cy = @grid_y + row * @cell_h

        cur_bmp = Bitmap.new(@cell_w - 4, @cell_h - 4)
        # Bright border (3px)
        border_color = Color.new(31, 177, 196)
        cur_bmp.fill_rect(0, 0, cur_bmp.width, 3, border_color)
        cur_bmp.fill_rect(0, cur_bmp.height - 3, cur_bmp.width, 3, border_color)
        cur_bmp.fill_rect(0, 0, 3, cur_bmp.height, border_color)
        cur_bmp.fill_rect(cur_bmp.width - 3, 0, 3, cur_bmp.height, border_color)
        @sprites["cursor"].bitmap.dispose if @sprites["cursor"].bitmap && !@sprites["cursor"].bitmap.disposed?
        @sprites["cursor"].bitmap = cur_bmp
        @sprites["cursor"].x = cx + 2
        @sprites["cursor"].y = cy + 2
      end

      def refresh_footer
        items = current_items
        total_pages = items.empty? ? 1 : ((items.length - 1) / PlayerHousing::SHOP_PER_PAGE) + 1
        current_page = (@page_offset / PlayerHousing::SHOP_PER_PAGE) + 1

        ft_bmp = Bitmap.new(Graphics.width, @footer_h)
        ft_bmp.fill_rect(0, 0, Graphics.width, @footer_h, Color.new(20, 22, 30))
        ft_bmp.font.size = 16

        # Money (left side)
        ft_bmp.font.color = Color.new(120, 220, 120)
        ft_bmp.draw_text(16, 8, 200, 20, "Money: $#{$Trainer.money}")

        # Page indicator (center)
        ft_bmp.font.color = Color.new(180, 180, 190)
        page_str = "Page #{current_page}/#{total_pages}"
        ft_bmp.draw_text(0, 8, Graphics.width, 20, page_str, 1)

        # Controls (right side)
        ft_bmp.font.color = Color.new(140, 140, 155)
        ft_bmp.font.size = 13
        if @mode == :category
          ft_bmp.draw_text(0, 8, Graphics.width - 16, 20, "L/R: Category | C: Select", 2)
          ft_bmp.draw_text(0, 26, Graphics.width - 16, 20, "B: Exit", 2)
        else
          ft_bmp.draw_text(0, 8, Graphics.width - 16, 20, "Arrows: Nav | C: Buy", 2)
          ft_bmp.draw_text(0, 26, Graphics.width - 16, 20, "B: Back to Category", 2)
        end

        # Selected item details (bottom row)
        item = items[@cursor_idx]
        if item
          ft_bmp.font.size = 15
          ft_bmp.font.color = Color.new(31, 177, 196)
          size_str = "#{item["width"]}x#{item["height"]}"
          type_str = item["is_carpet"] ? "Carpet" : "Furniture"
          detail = "#{item["name"]}  |  $#{item["cost"]}  |  #{size_str}  |  #{type_str}"
          ft_bmp.draw_text(16, 38, Graphics.width - 32, 20, detail)
        end

        @sprites["footer"].bitmap.dispose if @sprites["footer"].bitmap && !@sprites["footer"].bitmap.disposed?
        @sprites["footer"].bitmap = ft_bmp
      end

      def pbUpdate
        # No-op (all rendering is manual bitmap draws, no window update needed)
      end

      def pbEndScene
        pbFadeOutAndHide(@sprites)
        pbDisposeSpriteHash(@sprites)
        @viewport.dispose
      end

      def current_item
        items = current_items
        return nil if items.empty? || @cursor_idx >= items.length
        return items[@cursor_idx]
      end

      def refresh_money
        refresh_footer
      end

      def switch_category(dir)
        @current_cat_idx = (@current_cat_idx + dir) % @cat_keys.length
        @cursor_idx = 0
        @page_offset = 0
        pbSEPlay("GUI menu selection", 80, 100) rescue nil
        refresh_tabs
        refresh_grid
        refresh_cursor
        refresh_footer
      end

      def move_cursor(dir)
        items = current_items
        return if items.empty?
        old_idx = @cursor_idx

        cols = PlayerHousing::SHOP_COLS
        per_page = PlayerHousing::SHOP_PER_PAGE

        case dir
        when :up
          if @cursor_idx >= cols
            @cursor_idx -= cols
          end
        when :down
          if @cursor_idx + cols < items.length
            @cursor_idx += cols
          end
        when :left
          if @cursor_idx > 0
            @cursor_idx -= 1
          end
        when :right
          if @cursor_idx < items.length - 1
            @cursor_idx += 1
          end
        end

        # Update page offset based on cursor position
        if @cursor_idx < @page_offset
          @page_offset = (@cursor_idx / per_page) * per_page
          refresh_grid
        elsif @cursor_idx >= @page_offset + per_page
          @page_offset = (@cursor_idx / per_page) * per_page
          refresh_grid
        end

        if @cursor_idx != old_idx
          pbSEPlay("GUI sel cursor", 80, 100) rescue nil
          refresh_cursor
          refresh_footer
        end
      end
    end

    class FurnitureShop_Screen
      def initialize(scene)
        @scene = scene
      end

      def pbStartScreen(catalog)
        @scene.pbStartScene(catalog)
        loop do
          Graphics.update
          Input.update
          @scene.pbUpdate
          # Handle Inputs
          if Input.trigger?(Input::B) || Input.trigger?(Input::BACK)
            if @scene.mode == :grid
              pbPlayCancelSE() rescue nil
              @scene.set_mode(:category)
            else
              pbPlayCancelSE() rescue nil
              break
            end
          elsif Input.trigger?(Input::C)
            if @scene.mode == :category
              if !@scene.current_items.empty?
                pbPlayDecisionSE() rescue nil
                @scene.set_mode(:grid)
              else
                pbPlayErrorSE() rescue nil
              end
            else
              item = @scene.current_item
              if item
                if $Trainer.money >= item["cost"]
                  if pbConfirmMessage(_INTL("Buy {1} for ${2}?", item["name"], item["cost"]))
                    $Trainer.money -= item["cost"]
                    PlayerHousing.add_to_inventory(item.clone)
                    pbMessage(_INTL("Purchased {1}!", item["name"]))
                    @scene.refresh_money
                  end
                else
                  pbMessage(_INTL("You don't have enough money!"))
                end
              end
            end
          elsif Input.trigger?(Input::LEFT)
            if @scene.mode == :category
              @scene.switch_category(-1)
            else
              @scene.move_cursor(:left)
            end
          elsif Input.trigger?(Input::RIGHT)
            if @scene.mode == :category
              @scene.switch_category(1)
            else
              @scene.move_cursor(:right)
            end
          elsif Input.trigger?(Input::UP)
            if @scene.mode == :grid
              @scene.move_cursor(:up)
            end
          elsif Input.trigger?(Input::DOWN)
            if @scene.mode == :grid
              @scene.move_cursor(:down)
            end
          end
        end
        @scene.pbEndScene
      end
    end

    # --- PC Interactivity ---
    def self.interact_builder_pc(id)
      if @visiting_data
        pbMessage(_INTL("This PC belongs to the homeowner."))
        return
      end
      interact_furniture(id)
    end

    def self.buy_furniture_ui
      catalog = get_available_furniture

      scene = FurnitureShop_Scene.new
      screen = FurnitureShop_Screen.new(scene)
      screen.pbStartScreen(catalog)
    end

    def self.pick_up_pc(id)
      if pbConfirmMessage(_INTL("Move the PC? It will be put in your inventory."))
        f_idx = housing_data["furniture"].index { |f| f["id"] == id }
        if f_idx
          f = housing_data["furniture"].delete_at(f_idx)
          add_to_inventory(f)
          pbMessage(_INTL("#{f["name"]} added to inventory!"))
          reload_housing_map
        end
      end
    end

    def self.reload_housing_map
      pbFadeOutIn do
        $MapFactory.setup(PlayerHousingSettings::HOUSING_MAP_ID)
        $game_player.center($game_player.x, $game_player.y)
        if $scene.is_a?(Scene_Map)
          if $scene.respond_to?(:disposeSpritesets)
            $scene.disposeSpritesets
            $scene.createSpritesets
          elsif $scene.instance_variable_get(:@spriteset)
            $scene.instance_variable_get(:@spriteset).dispose
            $scene.instance_variable_set(:@spriteset, Spriteset_Map.new)
          end
        end
      end
      # Broadcast update to visitors if we are the host
      if self.housing_instance_owner == "self"
        # We broadcast regardless of has_visitors to ensure squad sync is simple
        PlayerHousingMP.broadcast_housing_update
      end

      # Explicitly update follower map references to prevent camera decoupling
      if defined?($PokemonTemp) && $PokemonTemp && $PokemonTemp.dependentEvents
        events = $PokemonTemp.dependentEvents.instance_variable_get(:@realEvents) || []
        events.each { |e| e.instance_variable_set(:@map, $game_map) if e }
        $PokemonTemp.dependentEvents.instance_eval { @lastUpdate += 1 }
      end

      # Ensure PokePets are re-spawned and set to roaming on the new map
      if defined?(GhostBuddyPokePets) && GhostBuddyPokePets.respond_to?(:update_followers)
        GhostBuddyPokePets.update_followers(true)
        GhostBuddyPokePets.set_follower_roaming(true) if GhostBuddyPokePets.respond_to?(:set_follower_roaming)
      end
    end

    class FurnitureInventory_Scene
      attr_reader :mode

      def pbStartScene(inventory_grouped)
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = 99999
        @sprites = {}
        @catalog = inventory_grouped

        @categories = {
          "Small" => [], "Medium" => [], "Large" => [], "Carpet" => [], "Top" => []
        }

        full_catalog = PlayerHousing.get_available_furniture

        @catalog.each do |entry|
          item = entry[:item]
          full_meta = full_catalog.find { |f| f["name"] == item["name"] && f["graphic"] == item["graphic"] }
          item = full_meta if full_meta
          entry[:item] = item

          cat = PlayerHousing.get_category_name(item)
          @categories[cat] << entry if @categories[cat]
        end

        @cat_keys = ["Small", "Medium", "Large", "Carpet", "Top"]
        @current_cat_idx = 0
        @cat_keys.each_with_index do |k, i|
          if !@categories[k].empty?
            @current_cat_idx = i
            break
          end
        end

        @cursor_idx = 0
        @page_offset = 0
        @mode = :category

        @cell_w = (Graphics.width - 32) / PlayerHousing::SHOP_COLS
        @cell_h = 132
        @grid_x = 16
        @grid_y = 52
        @header_h = 48
        @footer_h = 64

        @sprites["bg"] = Sprite.new(@viewport)
        bg_bmp = Bitmap.new(Graphics.width, Graphics.height)
        bg_bmp.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(25, 27, 35))
        (0...@header_h).each do |y|
          alpha = 255 - (y * 3)
          bg_bmp.fill_rect(0, y, Graphics.width, 1, Color.new(31, 196, 120, [alpha, 40].max))
        end
        @sprites["bg"].bitmap = bg_bmp

        @sprites["header_text"] = Sprite.new(@viewport)
        hdr_bmp = Bitmap.new(Graphics.width, @header_h)
        hdr_bmp.font.size = 22
        hdr_bmp.font.color = Color.new(255, 255, 255)
        hdr_bmp.draw_text(16, 6, 300, 30, "Furniture Inventory")
        @sprites["header_text"].bitmap = hdr_bmp

        @sprites["tabs"] = Sprite.new(@viewport)
        @sprites["tabs"].y = 4

        PlayerHousing::SHOP_PER_PAGE.times do |i|
          col = i % PlayerHousing::SHOP_COLS
          row = i / PlayerHousing::SHOP_COLS
          cx = @grid_x + col * @cell_w
          cy = @grid_y + row * @cell_h

          @sprites["cell_bg_#{i}"] = Sprite.new(@viewport)
          cell_bmp = Bitmap.new(@cell_w - 4, @cell_h - 4)
          cell_bmp.fill_rect(0, 0, cell_bmp.width, cell_bmp.height, Color.new(40, 44, 58))
          @sprites["cell_bg_#{i}"].bitmap = cell_bmp
          @sprites["cell_bg_#{i}"].x = cx + 2
          @sprites["cell_bg_#{i}"].y = cy + 2

          @sprites["cell_sprite_#{i}"] = Sprite.new(@viewport)
          @sprites["cell_sprite_#{i}"].x = cx + @cell_w / 2
          @sprites["cell_sprite_#{i}"].y = cy + @cell_h - 40
          @sprites["cell_sprite_#{i}"].visible = false

          @sprites["cell_label_#{i}"] = Sprite.new(@viewport)
          @sprites["cell_label_#{i}"].x = cx + 2
          @sprites["cell_label_#{i}"].y = cy + @cell_h - 36
        end

        @sprites["cursor"] = Sprite.new(@viewport)
        @sprites["footer"] = Sprite.new(@viewport)
        @sprites["footer"].y = Graphics.height - @footer_h

        refresh_tabs
        refresh_grid
        refresh_cursor
        refresh_footer
      end

      def refresh_tabs
        bmp = Bitmap.new(Graphics.width, 32)
        bmp.font.size = 16
        tab_widths = @cat_keys.map { |n| bmp.text_size(n).width + 20 }
        total_w = tab_widths.sum
        x_off = Graphics.width - total_w - 16
        @cat_keys.each_with_index do |name, i|
          tw = tab_widths[i]
          if i == @current_cat_idx
            tab_col = (@mode == :category) ? Color.new(50, 230, 150) : Color.new(31, 196, 120)
            bmp.fill_rect(x_off, 2, tw, 26, tab_col)
            if @mode == :category
              bmp.fill_rect(x_off, 2, tw, 2, Color.new(255, 255, 255))
              bmp.fill_rect(x_off, 26, tw, 2, Color.new(255, 255, 255))
              bmp.fill_rect(x_off, 2, 2, 26, Color.new(255, 255, 255))
              bmp.fill_rect(x_off + tw - 2, 2, 2, 26, Color.new(255, 255, 255))
            end
            bmp.font.color = Color.new(255, 255, 255)
          else
            bmp.fill_rect(x_off, 2, tw, 26, Color.new(55, 60, 78))
            bmp.font.color = Color.new(180, 180, 190)
          end
          bmp.draw_text(x_off, 4, tw, 22, name, 1)
          x_off += tw + 4
        end
        @sprites["tabs"].bitmap.dispose if @sprites["tabs"].bitmap && !@sprites["tabs"].bitmap.disposed?
        @sprites["tabs"].bitmap = bmp
      end

      def set_mode(m)
        @mode = m
        refresh_tabs
        refresh_cursor
        refresh_footer
      end

      def current_items
        @categories[@cat_keys[@current_cat_idx]]
      end

      def refresh_grid
        items = current_items
        PlayerHousing::SHOP_PER_PAGE.times do |i|
          item_idx = @page_offset + i
          entry = items[item_idx]

          cell_bmp = Bitmap.new(@cell_w - 4, @cell_h - 4)
          if entry
            cell_bmp.fill_rect(0, 0, cell_bmp.width, cell_bmp.height, Color.new(40, 44, 58))
          else
            cell_bmp.fill_rect(0, 0, cell_bmp.width, cell_bmp.height, Color.new(30, 32, 42))
          end
          @sprites["cell_bg_#{i}"].bitmap.dispose if @sprites["cell_bg_#{i}"].bitmap && !@sprites["cell_bg_#{i}"].bitmap.disposed?
          @sprites["cell_bg_#{i}"].bitmap = cell_bmp

          if entry
            item = entry[:item]
            filename = PlayerHousingSettings.resolve_path(item["graphic"].to_s)
            if pbResolveBitmap(filename)
              src = AnimatedBitmap.new(filename).bitmap
              @sprites["cell_sprite_#{i}"].bitmap = src
              if item["anim_mode"]
                frame_w = src.width / 2
                frame_h = src.height / 2
                @sprites["cell_sprite_#{i}"].src_rect = Rect.new(0, 0, frame_w, frame_h)
                @sprites["cell_sprite_#{i}"].ox = frame_w / 2
                @sprites["cell_sprite_#{i}"].oy = frame_h
                max_w = @cell_w - 16
                max_h = @cell_h - 50
                scale = [2.0, max_w.to_f / frame_w, max_h.to_f / frame_h].min
              else
                @sprites["cell_sprite_#{i}"].ox = src.width / 2
                @sprites["cell_sprite_#{i}"].oy = src.height
                max_w = @cell_w - 16
                max_h = @cell_h - 50
                scale = [2.0, max_w.to_f / src.width, max_h.to_f / src.height].min
              end
              @sprites["cell_sprite_#{i}"].zoom_x = scale
              @sprites["cell_sprite_#{i}"].zoom_y = scale
              @sprites["cell_sprite_#{i}"].visible = true
            else
              @sprites["cell_sprite_#{i}"].visible = false
            end
          else
            @sprites["cell_sprite_#{i}"].visible = false
          end

          label_bmp = Bitmap.new(@cell_w - 4, 34)
          label_bmp.font.size = 14
          if entry
            item = entry[:item]
            label_bmp.font.color = Color.new(220, 225, 240)
            display_name = item["name"].to_s
            display_name = display_name[0, 14] + ".." if display_name.length > 16
            label_bmp.draw_text(2, 0, @cell_w - 8, 16, display_name, 1)
            label_bmp.font.color = Color.new(255, 210, 80)
            label_bmp.draw_text(2, 16, @cell_w - 8, 16, "Owned: #{entry[:count]}", 1)
          end
          @sprites["cell_label_#{i}"].bitmap.dispose if @sprites["cell_label_#{i}"].bitmap && !@sprites["cell_label_#{i}"].bitmap.disposed?
          @sprites["cell_label_#{i}"].bitmap = label_bmp
        end
      end

      def refresh_cursor
        if @mode == :category
          @sprites["cursor"].visible = false
          return
        end
        items = current_items
        return if items.empty?
        @sprites["cursor"].visible = true

        local_idx = @cursor_idx - @page_offset
        col = local_idx % PlayerHousing::SHOP_COLS
        row = local_idx / PlayerHousing::SHOP_COLS
        cx = @grid_x + col * @cell_w
        cy = @grid_y + row * @cell_h

        cur_bmp = Bitmap.new(@cell_w - 4, @cell_h - 4)
        border_color = Color.new(31, 196, 120)
        cur_bmp.fill_rect(0, 0, cur_bmp.width, 3, border_color)
        cur_bmp.fill_rect(0, cur_bmp.height - 3, cur_bmp.width, 3, border_color)
        cur_bmp.fill_rect(0, 0, 3, cur_bmp.height, border_color)
        cur_bmp.fill_rect(cur_bmp.width - 3, 0, 3, cur_bmp.height, border_color)
        @sprites["cursor"].bitmap.dispose if @sprites["cursor"].bitmap && !@sprites["cursor"].bitmap.disposed?
        @sprites["cursor"].bitmap = cur_bmp
        @sprites["cursor"].x = cx + 2
        @sprites["cursor"].y = cy + 2
      end

      def refresh_footer
        items = current_items
        total_pages = items.empty? ? 1 : ((items.length - 1) / PlayerHousing::SHOP_PER_PAGE) + 1
        current_page = (@page_offset / PlayerHousing::SHOP_PER_PAGE) + 1

        ft_bmp = Bitmap.new(Graphics.width, @footer_h)
        ft_bmp.fill_rect(0, 0, Graphics.width, @footer_h, Color.new(20, 22, 30))
        ft_bmp.font.size = 16

        ft_bmp.font.color = Color.new(180, 180, 190)
        page_str = "Page #{current_page}/#{total_pages}"
        ft_bmp.draw_text(0, 8, Graphics.width, 20, page_str, 1)

        ft_bmp.font.color = Color.new(140, 140, 155)
        ft_bmp.font.size = 13
        if @mode == :category
          ft_bmp.draw_text(0, 8, Graphics.width - 16, 20, "L/R: Category | C: Select", 2)
          ft_bmp.draw_text(0, 26, Graphics.width - 16, 20, "B: Exit", 2)
        else
          ft_bmp.draw_text(0, 8, Graphics.width - 16, 20, "Arrows: Nav | C: Place", 2)
          ft_bmp.draw_text(0, 26, Graphics.width - 16, 20, "B: Back to Category", 2)
        end

        entry = items[@cursor_idx]
        if entry
          item = entry[:item]
          ft_bmp.font.size = 15
          ft_bmp.font.color = Color.new(31, 196, 120)
          size_str = "#{item["width"]}x#{item["height"]}"
          type_str = item["is_carpet"] ? "Carpet" : "Furniture"
          detail = "#{item["name"]}  |  Qty: #{entry[:count]}  |  #{size_str}  |  #{type_str}"
          ft_bmp.draw_text(16, 38, Graphics.width - 32, 20, detail)
        end

        @sprites["footer"].bitmap.dispose if @sprites["footer"].bitmap && !@sprites["footer"].bitmap.disposed?
        @sprites["footer"].bitmap = ft_bmp
      end

      def pbUpdate
      end

      def pbEndScene
        pbFadeOutAndHide(@sprites)
        pbDisposeSpriteHash(@sprites)
        @viewport.dispose
      end

      def current_item
        items = current_items
        return nil if items.empty? || @cursor_idx >= items.length
        return items[@cursor_idx][:item]
      end

      def switch_category(dir)
        @current_cat_idx = (@current_cat_idx + dir) % @cat_keys.length
        @cursor_idx = 0
        @page_offset = 0
        pbSEPlay("GUI menu selection", 80, 100) rescue nil
        refresh_tabs
        refresh_grid
        refresh_cursor
        refresh_footer
      end

      def move_cursor(dir)
        items = current_items
        return if items.empty?
        old_idx = @cursor_idx
        cols = PlayerHousing::SHOP_COLS
        per_page = PlayerHousing::SHOP_PER_PAGE

        case dir
        when :up
          if @cursor_idx >= cols
            @cursor_idx -= cols
          end
        when :down
          if @cursor_idx + cols < items.length
            @cursor_idx += cols
          end
        when :left
          if @cursor_idx > 0
            @cursor_idx -= 1
          end
        when :right
          if @cursor_idx < items.length - 1
            @cursor_idx += 1
          end
        end

        if @cursor_idx < @page_offset
          @page_offset = (@cursor_idx / per_page) * per_page
          refresh_grid
        elsif @cursor_idx >= @page_offset + per_page
          @page_offset = (@cursor_idx / per_page) * per_page
          refresh_grid
        end

        if @cursor_idx != old_idx
          pbSEPlay("GUI sel cursor", 80, 100) rescue nil
          refresh_cursor
          refresh_footer
        end
      end
    end

    class FurnitureInventory_Screen
      def initialize(scene)
        @scene = scene
      end

      def pbStartScreen(inventory_grouped)
        @scene.pbStartScene(inventory_grouped)
        selected_item = nil
        loop do
          Graphics.update
          Input.update
          @scene.pbUpdate
          if Input.trigger?(Input::B) || Input.trigger?(Input::BACK)
            if @scene.mode == :grid
              pbPlayCancelSE() rescue nil
              @scene.set_mode(:category)
            else
              pbPlayCancelSE() rescue nil
              break
            end
          elsif Input.trigger?(Input::C)
            if @scene.mode == :category
              if !@scene.current_items.empty?
                pbPlayDecisionSE() rescue nil
                @scene.set_mode(:grid)
              else
                pbPlayErrorSE() rescue nil
              end
            else
              item = @scene.current_item
              if item
                selected_item = item
                pbPlayDecisionSE() rescue nil
                break
              end
            end
          elsif Input.trigger?(Input::LEFT)
            if @scene.mode == :category
              @scene.switch_category(-1)
            else
              @scene.move_cursor(:left)
            end
          elsif Input.trigger?(Input::RIGHT)
            if @scene.mode == :category
              @scene.switch_category(1)
            else
              @scene.move_cursor(:right)
            end
          elsif Input.trigger?(Input::UP)
            if @scene.mode == :grid
              @scene.move_cursor(:up)
            end
          elsif Input.trigger?(Input::DOWN)
            if @scene.mode == :grid
              @scene.move_cursor(:down)
            end
          end
        end
        @scene.pbEndScene
        return selected_item
      end
    end

    def self.refresh_style_preview
      ensure_map_info # Re-bakes the tileset bitmap
      # Re-setup the map so it picks up the new tileset data
      $MapFactory.setup(PlayerHousingSettings::HOUSING_MAP_ID)
      $game_player.center($game_player.x, $game_player.y)
      if $scene.is_a?(Scene_Map)
        # Force reload of tileset graphic without full fade for a 'live' feel
        if $scene.respond_to?(:disposeSpritesets)
          $scene.disposeSpritesets
          $scene.createSpritesets
        elsif $scene.instance_variable_get(:@spriteset)
          $scene.instance_variable_get(:@spriteset).dispose
          $scene.instance_variable_set(:@spriteset, Spriteset_Map.new)
        end
      end
    end

    def self.place_furniture_ui(direct_item = nil)
      h_data = housing_data

      item_to_place = direct_item
      loop do
        inv = h_data["inventory"] ||= []
        is_creative = (ModSettingsMenu.get(:player_housing_creative_mode) == 1 rescue false)

        item = item_to_place
        item_to_place = nil # Use direct_item only once
        unless item
          if inv.empty? && !is_creative
            pbMessage(_INTL("(Empty) - You have no furniture in your inventory!"))
            break
          end

          # ... (grouping remains)
          grouped = {}
          if is_creative
            PlayerHousing.get_available_furniture.each do |cat_item|
              grouped[cat_item["name"]] = { item: cat_item, count: "∞" }
            end
          else
            inv.each do |inv_item|
              key = inv_item["name"]
              grouped[key] ||= { item: inv_item, count: 0 }
              grouped[key][:count] += 1
            end
          end

          scene = FurnitureInventory_Scene.new
          screen = FurnitureInventory_Screen.new(scene)
          item = screen.pbStartScreen(grouped.values)
        end

        break if !item

        fw = item["width"] || 1
        fh = item["height"] || 1

        # Base placement tile (1 tile in front of player)
        dir = $game_player.direction
        base_tx = $game_player.x + (dir == 6 ? 1 : dir == 4 ? -1 : 0)
        base_ty = $game_player.y + (dir == 2 ? 1 : dir == 8 ? -1 : 0)

        # Pre-build occupied sets

        occupied_solid  = {}
        occupied_carpet = {}
        occupied_desk   = {}
        placed_furniture = h_data["furniture"] || []

        placed_furniture.each do |f|
          ffw = f["width"] || 1
          ffh = f["height"] || 1
          f_solid_h = f["solid_height"] || (f["passable"] ? 1 : ffh)
          (0...ffw).each do |fdx|
            (0...ffh).each do |fdy|
              coord = "#{f["x"] + fdx},#{f["y"] - fdy}"
              if f["is_desk"]
                occupied_desk[coord] = true
              elsif f["is_carpet"]
                occupied_carpet[coord] = true
              else
                occupied_solid[coord] = true if fdy < f_solid_h
              end
            end
          end
        end

        # Helper: check bounds + collision, returns :ok / :bounds / :overlap
        check_placement = lambda do |tx, ty|
          (0...fw).each do |dx|
            (0...fh).each do |dy|
              cx = tx + dx; cy = ty - dy
              if cx <= 0 || cx >= PlayerHousingSettings::HOUSING_MAP_WIDTH - 1 ||
                  cy <= 0 || cy >= PlayerHousingSettings::HOUSING_MAP_HEIGHT - 1
                return :bounds
              end
            end
          end
          (0...fw).each do |dx|
            (0...fh).each do |dy|
              cx = tx + dx; cy = ty - dy
              coord = "#{cx},#{cy}"
              if item["is_desk"]
                # Desk/Top items overlap everything. User requested stacking them on a single tile.
                # return :overlap if occupied_desk[coord] # Removed to allow stacking
              elsif item["is_carpet"]
                return :overlap if occupied_carpet[coord]
              else
                item_solid_h = item["solid_height"] || (item["passable"] ? 1 : fh)
                if dy < item_solid_h # Passable portions skip collision testing
                  return :overlap if cx == $game_player.x && cy == $game_player.y
                  return :overlap if occupied_solid[coord]
                end
              end
            end
          end
          :ok
        end

        # Helper: create/update a preview sprite at (tx, ty). Disposes old sprite if given.
        update_preview = lambda do |old_spr, tx, ty|
          old_spr.dispose if old_spr && !old_spr.disposed?
          vp = (defined?($scene) && $scene.respond_to?(:spriteset) && $scene.spriteset) ? $scene.spriteset.viewport1 : nil
          spr = Sprite.new(vp)
          spr.z = item["is_carpet"] ? 10 : 99999
          begin
            filename = PlayerHousingSettings.resolve_path(item["graphic"].to_s)
            if pbResolveBitmap(filename)
              bmp = AnimatedBitmap.new(filename).bitmap
              spr.bitmap = bmp
              spr.src_rect = Rect.new(0, 0, bmp.width, bmp.height)
              spr.ox = 16
              spr.oy = bmp.height
              spr.x = (tx * 128 - $game_map.display_x + 64) / 4
              spr.y = (ty * 128 - $game_map.display_y + 128) / 4
            end
          rescue
          end
          spr
        end

        # --- Real-time Placement loop ---
        # Preview appears immediately at the base position.
        current_tx = base_tx
        current_ty = base_ty
        preview_spr = update_preview.call(nil, current_tx, current_ty)

        # Simple instructions window
        viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        viewport.z = 99999
        help_window = Window_AdvancedTextPokemon.newWithSize(_INTL("Arrows: Move | C: Place | B: Cancel"), 16, Graphics.height - 96, Graphics.width - 32, 80, viewport)

        loop do
          Graphics.update
          Input.update
          help_window.update

          if Input.trigger?(Input::B) || Input.trigger?(Input::BACK)
            preview_spr.dispose if preview_spr && !preview_spr.disposed?
            if direct_item
              add_to_inventory(direct_item)
              pbMessage(_INTL("Move cancelled. Item returned to inventory."))
            end
            break
          elsif Input.trigger?(Input::C) || Input.trigger?(Input::USE)
            result = check_placement.call(current_tx, current_ty)
            if result == :bounds
              pbPlayBuzzerSE() rescue nil
            elsif result == :overlap
              pbPlayBuzzerSE() rescue nil
            else
              # Final Confirmation Menu
              placement_done = false
              cmd = pbMessage(_INTL("Placement:"), [_INTL("Place"), _INTL("Nudge"), _INTL("Cancel")], 2)
              if cmd == 0 # Place
                placement_done = true
              elsif cmd == 1 # Nudge
                @current_xn, @current_yn, confirmed = self.pbNudgeLoop(preview_spr, @current_xn, @current_yn, current_tx, current_ty)
                placement_done = confirmed # If they pressed C to finish nudging, place it immediately.
              end

              if placement_done
                preview_spr.dispose if preview_spr && !preview_spr.disposed?
                # Calculate Z-offset for Desk items based on overlapping furniture AND stacking count
                z_offset = 0
                if item["is_desk"]
                  y_diff_max = 0
                  existing_count = 0
                  placed_furniture.each do |f|
                    if f["x"] == current_tx && f["y"] == current_ty && f["is_desk"]
                      existing_count += 1
                    end
                    next if f["is_carpet"] || f["is_desk"]
                    fw_tmp = f["width"] || 1
                    fh_tmp = f["height"] || 1
                    intersects = false
                    (0...fw_tmp).each do |dx|
                      (0...fh_tmp).each do |dy|
                        cx = f["x"] + dx
                        cy = f["y"] - dy
                        intersects = true if cx == current_tx && cy == current_ty
                      end
                    end
                    if intersects
                      diff = f["y"] - current_ty
                      y_diff_max = diff if diff > y_diff_max
                    end
                  end
                  
                  # Height difference corresponds to 32 Z-index per tile. Add count offset for micro-layering.
                  z_offset = (y_diff_max * 32) + (existing_count * 2)
                end

                # Start with a copy of the original item to preserve any custom keys
                # (e.g. factory-specific: station_name, is_workstation, is_bed)
                placed = item.dup
                placed.merge!({
                  "id"        => "furn_#{Time.now.to_i}",
                  "x"         => current_tx,
                  "y"         => current_ty,
                  "width"     => fw,
                  "height"    => fh,
                  "z_offset"  => z_offset,
                  "x_nudge"   => @current_xn || 0,
                  "y_nudge"   => @current_yn || 0
                })
                h_data["furniture"] << placed
                unless is_creative
                  idx = inv.index { |i| i["name"] == item["name"] && i["graphic"] == item["graphic"] }
                  inv.delete_at(idx) if idx
                end
                pbSEPlay("Pkmn exp full", 80, 100) rescue nil
                @current_xn = 0; @current_yn = 0
                reload_housing_map
                break
              end
            end
          elsif Input.trigger?(Input::UP)
            current_ty -= 1
            @current_xn = 0; @current_yn = 0
            preview_spr = update_preview.call(preview_spr, current_tx, current_ty)
          elsif Input.trigger?(Input::DOWN)
            current_ty += 1
            @current_xn = 0; @current_yn = 0
            preview_spr = update_preview.call(preview_spr, current_tx, current_ty)
          elsif Input.trigger?(Input::LEFT)
            current_tx -= 1
            @current_xn = 0; @current_yn = 0
            preview_spr = update_preview.call(preview_spr, current_tx, current_ty)
          elsif Input.trigger?(Input::RIGHT)
            current_tx += 1
            @current_xn = 0; @current_yn = 0
            preview_spr = update_preview.call(preview_spr, current_tx, current_ty)
          end
        end

        help_window.dispose
        viewport.dispose
        return if direct_item
      end # End of overall placement flow loop
    end

    def self.change_room_style_ui
      h_data = housing_data
      viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      viewport.z = 99999

      # Store initial state for revert
      old_styles = {
        "roof_id" => h_data["roof_id"] || 1,
        "wall_id" => h_data["wall_id"] || 1,
        "floor_id" => h_data["floor_id"] || 1
      }

      # Simple instructions window
      help_window = Window_AdvancedTextPokemon.newWithSize(_INTL("Arrows: Adjust | C: Save | B: Cancel"), 16, Graphics.height - 96, Graphics.width - 32, 80, viewport)

      # Command window
      cmd_window = Window_CommandPokemon.new([])
      cmd_window.viewport = viewport
      cmd_window.x = 16
      cmd_window.y = Graphics.height - 240
      cmd_window.width = 320
      cmd_window.height = 140

      refresh_cmds = proc {
        cmd_window.commands = [
                               "Roof Style: (ID #{h_data["roof_id"] || 1})",
                               "Wall Style: (ID #{h_data["wall_id"] || 1})",
                               "Floor Style: (ID #{h_data["floor_id"] || 1})",
                               "Save & Exit"
                              ]
      }

      refresh_cmds.call

      loop do
        Graphics.update
        Input.update
        cmd_window.update
        help_window.update

        if Input.trigger?(Input::B) || Input.trigger?(Input::BACK)
          # Revert
          h_data["roof_id"] = old_styles["roof_id"]
          h_data["wall_id"] = old_styles["wall_id"]
          h_data["floor_id"] = old_styles["floor_id"]
          refresh_style_preview
          break
        elsif Input.trigger?(Input::LEFT)
          case cmd_window.index
          when 0; h_data["roof_id"] = [1, (h_data["roof_id"] || 1) - 1].max
          when 1; h_data["wall_id"] = [1, (h_data["wall_id"] || 1) - 1].max
          when 2; h_data["floor_id"] = [1, (h_data["floor_id"] || 1) - 1].max
          end
          refresh_cmds.call
          refresh_style_preview
        elsif Input.trigger?(Input::RIGHT)
          case cmd_window.index
          when 0; h_data["roof_id"] = (h_data["roof_id"] || 1) + 1
          when 1; h_data["wall_id"] = (h_data["wall_id"] || 1) + 1
          when 2; h_data["floor_id"] = (h_data["floor_id"] || 1) + 1
          end
          refresh_cmds.call
          refresh_style_preview
        elsif Input.trigger?(Input::USE)
          break if cmd_window.index == 3
          refresh_style_preview # Explicit refresh
        end
      end

      cmd_window.dispose
      help_window.dispose
      viewport.dispose

      # Broadcast layout changes to visitors when done editing
      if !@visiting_data && @has_visitors && housing_instance_owner == "self"
        PlayerHousingMP.broadcast_housing_update
      end
    end

    # No longer used in simplified system
    def self.apply_live_style(f_tile, w_tile); end

      def self.interact_furniture(triggered_id = nil)
        # Prevent multiple interaction calls in quick succession (stacked items)
        # We check if we are already in an interaction or just finished one.
        return if @interact_lock && (Graphics.frame_count - @interact_lock).abs < 3
        @interact_lock = Graphics.frame_count

        # Block interactions for visitors
        if @visiting_data
          id = triggered_id || (pbGetSelfEvent.name.split('_')[1] rescue nil)
          item = @visiting_data["furniture"].find { |f| f["id"] == id } if id
          name = item ? item["name"] : "furniture"
          pbMessage(_INTL("It's a nice {1}. This PC belongs to the homeowner.", name)) if item && item["is_pc"]
          pbMessage(_INTL("It's a nice {1}.", name)) if item && !item["is_pc"]
          return
        end
        h_data = housing_data

        # Determine the tile in front of the player
        tx = $game_player.x + ($game_player.direction == 6 ? 1 : $game_player.direction == 4 ? -1 : 0)
        ty = $game_player.y + ($game_player.direction == 2 ? 1 : $game_player.direction == 8 ? -1 : 0)

        # Check the tile the player is currently standing on (primarily for carpets)
        px = $game_player.x
        py = $game_player.y

        candidates = []

        (h_data["furniture"] || []).each do |f|
          next unless f

          # Use metadata for footprints
          fw = f["width"] || 1
          fh = f["height"] || 1

          occupies_target = false
          occupies_player = false

          (0...fw).each do |dx|
            (0...fh).each do |dy|
              cx = f["x"] + dx
              cy = f["y"] - dy
              occupies_target = true if cx == tx && cy == ty
              occupies_player = true if cx == px && cy == py
            end
          end

          # Include if it occupies the target tile, OR if it occupies the player's tile AND is a carpet
          if occupies_target || (occupies_player && f["is_carpet"])
            candidates << f unless candidates.any? { |c| c["id"] == f["id"] }
          end
        end

        # Fallback to triggered event if coordinate math somehow misses it
        if triggered_id
          f = (h_data["furniture"] || []).find { |fi| fi["id"] == triggered_id }
          candidates << f if f && !candidates.any? { |c| c["id"] == f["id"] }
        end

        return if candidates.empty?

        # Interaction Menu Logic
        # Sort to ensure PC ("Use Home PC") is always at the top
        candidates.sort_by! { |c| c["is_pc"] ? 0 : 1 }

        sel_f = nil
        if candidates.size == 1
          sel_f = candidates.first
        else
          cmds = candidates.map { |c| c["is_pc"] ? "Use Home PC" : c["name"] }
          cmds << "Cancel"
          sel = (respond_to?(:pbShowCommands) || Kernel.respond_to?(:pbShowCommands)) ? pbShowCommands(nil, cmds, -1) : pbMessage(_INTL("Which item?"), cmds, -1)
          if sel < 0 || sel >= candidates.length # Cancel Choice or B button
            Input.update
            @interact_lock = Graphics.frame_count # Update lock on exit
            return
          end
          sel_f = candidates[sel]
        end

        return unless sel_f

        Input.update # Clear buffer before management loop
        loop do
          is_pc = sel_f["is_pc"]
          if is_pc
            cmds = ["Furniture Shop", "Move PC", "Cancel"]
            msg = "Home PC:"
          else
            cmds = ["Move", "Nudge", "Pick Up", "Cancel"]
            msg = "#{sel_f["name"]}:"
          end

          cmd = (respond_to?(:pbShowCommands) || Kernel.respond_to?(:pbShowCommands)) ? pbShowCommands(nil, cmds, -1) : pbMessage(_INTL(msg), cmds, -1)

          if cmd < 0 || (is_pc && cmd == 2) || (!is_pc && cmd == 3) # Cancel / B button
            Input.update
            break
          end

          case cmd
          when 0
            if is_pc
              buy_furniture_ui
              Input.update
              break
            else # Move
              f_idx = h_data["furniture"].index { |fi| fi["id"] == sel_f["id"] }
              if f_idx
                item_data = h_data["furniture"].delete_at(f_idx)
                reload_housing_map
                Input.update
                place_furniture_ui(item_data)
              end
              break
            end
          when 1
            if is_pc # Move PC
              f_idx = h_data["furniture"].index { |fi| fi["id"] == sel_f["id"] }
              if f_idx
                item_data = h_data["furniture"].delete_at(f_idx)
                reload_housing_map
                Input.update
                place_furniture_ui(item_data)
              end
              break
            else # Nudge
              # Search for event starting with ID or containing it wrapped in separators
              relevant_events = $game_map.events.values.select { |e| e.name.start_with?(sel_f["id"]) || e.name.include?("Dummy_#{sel_f["id"]}") }
              if relevant_events.empty?
                # Final fallback logic: just finding ANY event with the ID in the name
                relevant_events = $game_map.events.values.select { |e| e.name.include?(sel_f["id"]) }
              end

              if !relevant_events.empty?
                vp = (defined?($scene) && $scene.respond_to?(:spriteset) && $scene.spriteset) ? $scene.spriteset.viewport1 : nil
                temp_spr = Sprite.new(vp)
                filename = PlayerHousingSettings.resolve_path(sel_f["graphic"].to_s)
                if pbResolveBitmap(filename)
                  bmp = AnimatedBitmap.new(filename).bitmap
                  temp_spr.bitmap = bmp; temp_spr.ox = 16; temp_spr.oy = bmp.height
                  temp_spr.z = 99999
                end
                if defined?($scene) && $scene.respond_to?(:spriteset) && $scene.spriteset
                  $scene.spriteset.character_sprites.each do |s|
                    c = s.instance_variable_get(:@character)
                    s.visible = false if relevant_events.include?(c)
                  end rescue nil
                end

                initial_xn = sel_f["x_nudge"] || 0
                initial_yn = sel_f["y_nudge"] || 0
                @current_xn, @current_yn, confirmed = self.pbNudgeLoop(temp_spr, initial_xn, initial_yn, sel_f["x"], sel_f["y"])
                if confirmed
                  sel_f["x_nudge"] = @current_xn
                  sel_f["y_nudge"] = @current_yn
                  reload_housing_map
                else
                  # Put sprites back if cancelled
                  if defined?($scene) && $scene.respond_to?(:spriteset) && $scene.spriteset
                    $scene.spriteset.character_sprites.each { |s| s.visible = true } rescue nil
                  end
                end
                temp_spr.dispose
                Input.update
              else
                pbMessage(_INTL("Item not found for nudging. Try moving it instead."))
              end
            end
          when 2
            # Pick Up (Furniture only, PC cmd 2 is Cancel)
            if pbConfirmMessage(_INTL("Pick up {1}?", sel_f["name"]))
              f_idx = h_data["furniture"].index { |fi| fi["id"] == sel_f["id"] }
              if f_idx
                h_data["furniture"].delete_at(f_idx)
                add_to_inventory(sel_f)
                pbMessage(_INTL("{1} picked up!", sel_f["name"]))
                reload_housing_map
                Input.update
              end
              break
            end
          end
        end
        Input.update
        @interact_lock = Graphics.frame_count
      end

      def self.pbNudgeLoop(spr, initial_xn, initial_yn, tx, ty)
        xn = initial_xn || 0
        yn = initial_yn || 0
        loop do
          Graphics.update
          Input.update
          if Input.trigger?(Input::C) || Input.trigger?(Input::USE)
            pbPlayDecisionSE() rescue nil
            return [xn, yn, true]
          elsif Input.trigger?(Input::B) || Input.trigger?(Input::BACK)
            pbPlayCancelSE() rescue nil
            return [initial_xn || 0, initial_yn || 0, false]
          elsif Input.repeat?(Input::UP); yn -= 1
          elsif Input.repeat?(Input::DOWN); yn += 1
          elsif Input.repeat?(Input::LEFT); xn -= 1
          elsif Input.repeat?(Input::RIGHT); xn += 1
          end
          spr.x = (tx * 128 - $game_map.display_x + 64) / 4 + xn
          spr.y = (ty * 128 - $game_map.display_y + 128) / 4 + yn
        end
      end

      def self.get_available_furniture
        furniture_dir = PlayerHousingSettings::FURNITURE_ROOT
        
        # Backward compatibility / safety catch for development
        furniture_dir = furniture_dir.chomp("/") if furniture_dir.end_with?("/")
        return [] unless File.directory?(furniture_dir)

        catalog = []

        Dir.foreach(furniture_dir) do |file|
          next if file == '.' || file == '..'
          next unless file.downcase.end_with?(".png")

          basename = File.basename(file, ".png")
          # Format: [Price]_[SizeModifier]_[ItemName]
          parts = basename.split('_', 3)
          next unless parts.length >= 3

          tier, size_mod, name_part = parts

          # Parse Price (raw number)
          cost = tier.to_i

          # Parse Size and Properties Modifier (Format: W H + modifiers)
          # e.g., '11', '22', '12d', '22p', '22c'
          sm = size_mod.downcase
          width = sm[0,1].to_i
          width = 1 if width < 1
          height = sm[1,1].to_i
          height = 1 if height < 1

          mods      = sm[2..-1] || ""
          is_carpet = mods.include?("c")
          is_desk   = mods.include?("d")
          passable  = mods.include?("p")

          solid_height = height
          if mods =~ /p(\d+)/
              solid_height = $1.to_i
          elsif passable
            solid_height = 1
          end

          # Parse Animation Mode (check BEFORE converting name to display string)
          anim_mode = nil
          if name_part.end_with?("_ap")
            anim_mode = :pingpong
            name_part = name_part[0...-3]
          elsif name_part.end_with?("_al")
            anim_mode = :loop
            name_part = name_part[0...-3]
          elsif name_part.end_with?("_a")
            anim_mode = :loop
            name_part = name_part[0...-2]
          end

          # Parse Name (Split CamelCase to space padding, convert underscores to spaces)
          name = name_part.gsub(/([a-z])([A-Z])/, '\1 \2').gsub('_', ' ')

          catalog << {
            "name"      => name,
            "graphic"   => PlayerHousingSettings::FURNITURE_ROOT + basename,
            "cost"      => cost,
            "width"     => width,
            "height"    => height,
            "solid_height" => solid_height,
            "passable"  => passable,
            "is_carpet" => is_carpet,
            "is_desk"   => is_desk,
            "anim_mode" => anim_mode   # nil = static, :loop, :pingpong
          }
        end

        # Ensure the Base PC always exists in the master list so it gets correct metadata universally.
        unless catalog.any? { |i| i["is_pc"] }
          catalog << {
            "name"      => "Secret Base PC",
            "graphic"   => PlayerHousingSettings::FURNITURE_ROOT + "BasePC",
            "cost"      => 1,
            "width"     => 1,
            "height"    => 1,
            "solid_height" => 1,
            "passable"  => false,
            "is_carpet" => false,
            "is_desk"   => true,
            "is_pc"     => true,
            "anim_mode" => nil
          }
        end

        # Sort catalog by price, then name
        catalog.sort_by { |item| [item["cost"], item["name"]] }
      end
  end

# ============================================================================
# SECTION 3: LOAD_DATA INTERCEPTION
# ============================================================================
PLAYER_HOUSING_MAP_FILE = sprintf("Map%03d", PlayerHousingSettings::HOUSING_MAP_ID)
alias __housing_mod_original_load_data load_data unless defined?(__housing_mod_original_load_data)
def load_data(f); (f.is_a?(String) && f.include?(PLAYER_HOUSING_MAP_FILE)) ? PlayerHousing.build_virtual_map : __housing_mod_original_load_data(f); end

# ============================================================================
# SECTION 4: DATA PERSISTENCE
# ============================================================================
class PokemonGlobalMetadata
  attr_accessor :player_housing_data, :home_return_point
  alias __housing_mod_original_initialize initialize unless method_defined?(:__housing_mod_original_initialize)
  def initialize
    __housing_mod_original_initialize
    @player_housing_data ||= {}
    @player_housing_data["style"] ||= { "floor" => 384, "wall" => 392 }
    @player_housing_data["furniture"] ||= []
    @home_return_point ||= nil
  end
end

# ============================================================================
# SECTION 5: SECRET BASE HOUSE KEY & KURAY SHOP INTEGRATION
# ============================================================================

GHOST_ITEM_HOUSE_KEY_ID = 1060

def ghost_base_register_items
  GameData::Item.register({
    :id               => :SECRETBASEKEY,
    :id_number        => GHOST_ITEM_HOUSE_KEY_ID,
    :name             => "House Key",
    :name_plural      => "House Keys",
    :pocket           => 8,
    :price            => 5000,
    :description      => "A magical key that grants access to and control over a secret base.",
    :field_use        => 2,
    :battle_use       => 0,
    :type             => 6,
    :move             => nil
  })

  MessageTypes.set(MessageTypes::Items,            GHOST_ITEM_HOUSE_KEY_ID, "House Key")
  MessageTypes.set(MessageTypes::ItemPlurals,      GHOST_ITEM_HOUSE_KEY_ID, "House Keys")
  MessageTypes.set(MessageTypes::ItemDescriptions, GHOST_ITEM_HOUSE_KEY_ID, "A magical key that grants access to and control over a secret base.")
end

# Hook into GameData.load_all
module GameData
  class << self
    unless method_defined?(:ghost_base_original_load_all)
      alias ghost_base_original_load_all load_all
      def load_all
        ghost_base_original_load_all
        ghost_base_register_items
      end
    end
  end
end

ghost_base_register_items

module PBItems
  SECRETBASEKEY = GHOST_ITEM_HOUSE_KEY_ID unless const_defined?(:SECRETBASEKEY)
end

# Inject into Kuray Shop
class PokemonMart_Scene
  unless method_defined?(:ghost_base_original_pbStartBuyOrSellScene)
    alias ghost_base_original_pbStartBuyOrSellScene pbStartBuyOrSellScene
    def pbStartBuyOrSellScene(buying, stock, adapter)
      if $game_temp && $game_temp.respond_to?(:fromkurayshop) && $game_temp.fromkurayshop
        has_key = stock.any? { |s| s == GHOST_ITEM_HOUSE_KEY_ID || s == :SECRETBASEKEY }
        unless has_key
          stock.push(GHOST_ITEM_HOUSE_KEY_ID)
          $game_temp.mart_prices[GHOST_ITEM_HOUSE_KEY_ID] = [5000, 0] if $game_temp.respond_to?(:mart_prices) && $game_temp.mart_prices
        end
      end
      ghost_base_original_pbStartBuyOrSellScene(buying, stock, adapter)
    end
  end
end

# Override Graphic
module GameData
  class Item
    class << self
      unless method_defined?(:ghost_base_original_icon_filename)
        alias ghost_base_original_icon_filename icon_filename
        def icon_filename(item)
          item_id = GameData::Item.try_get(item)&.id
          return "Graphics/Items/BEDROOMKEY" if item_id == :SECRETBASEKEY
          return ghost_base_original_icon_filename(item)
        end
        
        alias ghost_base_original_held_icon_filename held_icon_filename
        def held_icon_filename(item)
          item_id = GameData::Item.try_get(item)&.id
          return "Graphics/Items/BEDROOMKEY" if item_id == :SECRETBASEKEY
          return ghost_base_original_held_icon_filename(item)
        end
      end
    end
  end
end

ItemHandlers::UseInField.add(:SECRETBASEKEY, proc { |item|
  next PlayerHousing.main_menu_interaction
})
# ============================================================================
# SECTION 6: MOD SETTINGS
# ============================================================================
# (Settings registration moved to end of file for consolidation)

puts "[Player Housing] Mod initialized successfully."

# ============================================================================
# SECTION 7: SPRITE RENDERING OVERRIDES (NO 4x4 SPLIT, CORRECT Z-INDEXING)
# ============================================================================
class Sprite_Character
  alias __housing_sprite_update update unless method_defined?(:__housing_sprite_update)

  def update
    __housing_sprite_update

    # Custom rendering rules for furniture
    if @character && @character.character_name && @character.character_name.include?("GhostBase/Furniture")
      # Fix for relative paths and standalone sprites:
      # If the bitmap is nil, manually load it from the absolute path.
      if !self.bitmap || self.bitmap.disposed?
        begin
          path = @character.character_name.gsub("../", "")
          self.bitmap = AnimatedBitmap.new(path).bitmap
        rescue
        end
      end

      # 1. Hide dummies visually (they exist only for collision/interaction)
      is_dummy = false
      begin
        is_dummy = true if @character.is_a?(Game_Event) && @character.name.start_with?("Dummy")
      rescue
      end
      if is_dummy
        self.visible = false
        return
      end

      if self.bitmap && !self.bitmap.disposed?
        char_name = @character.character_name

        # Detect animation mode from filename suffix
        anim_mode = nil
        if char_name.end_with?("_ap")
          anim_mode = :pingpong
        elsif char_name.end_with?("_al") || char_name.end_with?("_a")
          anim_mode = :loop
        end

        if anim_mode
          # Animated furniture: spritesheet is a 2-column x 2-row grid of frames.
          frame_w = self.bitmap.width / 2
          frame_h = self.bitmap.height / 2

          @housing_anim_frame ||= 0
          @housing_anim_timer ||= 0
          @housing_anim_dir   ||= 1

          @housing_anim_timer += 1
          if @housing_anim_timer >= 30
            @housing_anim_timer = 0
            if anim_mode == :pingpong
              @housing_anim_frame += @housing_anim_dir
              if @housing_anim_frame >= 3
                @housing_anim_frame = 3
                @housing_anim_dir = -1
              elsif @housing_anim_frame <= 0
                @housing_anim_frame = 0
                @housing_anim_dir = 1
              end
            else  # :loop
              @housing_anim_frame = (@housing_anim_frame + 1) % 4
            end
          end

          row = @housing_anim_frame / 2
          col = @housing_anim_frame % 2
          self.src_rect.set(col * frame_w, row * frame_h, frame_w, frame_h)
          self.ox = 16
          self.oy = frame_h
        else
          # Static furniture: use the full bitmap as a single frame
          self.src_rect.set(0, 0, self.bitmap.width, self.bitmap.height)
          self.ox = 16
          self.oy = self.bitmap.height
        end

        # Hide shadow for furniture
        @shadow.visible = false if @shadow
      end

      # 2. Render layering correction (placed items metadata check)
      # In the Housing Map, we use a Fixed-Layer system to satisfy the "Roof Priority"
      # and "Coordinate Independence" requirements.
      is_housing_map = ($game_map.map_id == PlayerHousingSettings::HOUSING_MAP_ID)

      z_off_meta = 0
      x_nudge = 0
      y_nudge = 0
      target_obj = (@character.is_a?(Game_Event) ? @character : nil)
      if target_obj
        if target_obj.name.include?("[ZO:") && target_obj.name =~ /\[ZO:(-?\d+)\]/
            z_off_meta = $1.to_i
        end
        if target_obj.name.include?("[XN:") && target_obj.name =~ /\[XN:(-?\d+)\]/
            x_nudge = $1.to_i
        end
        if target_obj.name.include?("[YN:") && target_obj.name =~ /\[YN:(-?\d+)\]/
            y_nudge = $1.to_i
        end
      end

      # Apply nudges (absolute screen coordinates prevent 'gliding' offscreen)
      self.x = @character.screen_x + x_nudge
      self.y = @character.screen_y + y_nudge

      if is_housing_map
        # Use native screen_y as the base to preserve natural row-based depth sorting.
        # This ensures South items (Higher Y) correctly layer OVER North entities.
        base_z = @character.screen_y

        char_name_lc = @character.character_name.downcase
        if @character.is_a?(Game_Player) || (defined?(Game_Follower) && @character.is_a?(Game_Follower)) || char_name_lc.include?("trainer") || (@character.respond_to?(:id) && @character.id == 9000)
          # Player/Followers are on top of furniture on the SAME row
          self.z = base_z + 4
        elsif char_name_lc.include?("basepc")
          self.z = base_z + 2 + z_off_meta
        else
          basename = File.basename(char_name_lc, ".png")
          parts = basename.split('_')
          if parts.length >= 3
            size_mod = parts[1]
            if size_mod.include?("c")
              self.z = 10 # Carpets: always at the absolute bottom
            elsif size_mod.include?("d")
              self.z = base_z + 2 + z_off_meta # Desk items: above furniture but below player on same row
            else
              self.z = base_z # Standard Furniture
            end
          else
            self.z = base_z
          end
        end
      else
        # Standard Y-sorting for all other maps
        char_name_lc = @character.character_name.downcase
        if char_name_lc.include?("basepc")
          self.z = @character.screen_y + 1
        else
          basename = File.basename(char_name_lc, ".png")
          parts = basename.split('_')
          if parts.length >= 3
            size_mod = parts[1]
            is_carpet = size_mod.include?("c")
            is_desk = size_mod.include?("d")

            if is_carpet
              self.z = 10
            elsif is_desk
              self.z = @character.screen_y + 1
            end
          end
        end
        self.z += z_off_meta if z_off_meta != 0
      end
    end
  end
end

# ============================================================================
# SECTION 8: MULTIPLAYER VISITATION (KIFM PURE CLIENT-SIDE RELAY)
# ============================================================================
module PlayerHousing
  @has_visitors = false
  @housing_instance_owner = nil # nil = not in housing, "self" = own base, "SID123" = visiting

  class << self
    attr_accessor :has_visitors
    attr_accessor :housing_instance_owner
  end
end

module PlayerHousingMP
  @pending_visit_target = nil
  @pending_visit_data = nil

  class << self
    attr_accessor :pending_visit_target, :pending_visit_data
  end

  # --- Packet Handling (called from the network thread) ---
  def self.handle_packet(from_sid, raw)
    begin
      if raw.start_with?("HOUSING_REQ:")
        # Another player wants to visit us — auto-respond with our data
        PlayerHousing.has_visitors = true
        send_housing_data(from_sid)

      elsif raw.start_with?("HOUSING_DAT:")
        json_hex = raw.sub("HOUSING_DAT:", "")
        json_str = [json_hex].pack("H*")
        data = MiniJSON.parse(json_str) rescue nil
        if data
          # Store it for the polling loop in visit_friend_ui
          @pending_visit_data = data
        end

      elsif raw.start_with?("HOUSING_UPD:")
        json_hex = raw.sub("HOUSING_UPD:", "")
        json_str = [json_hex].pack("H*")
        data = MiniJSON.parse(json_str) rescue nil
        if data && PlayerHousing.housing_instance_owner == from_sid
          PlayerHousing.set_visiting_data(data)
          # Schedule a reload on the main thread
          $game_temp.player_housing_needs_reload = true if $game_temp
        end
      end
    rescue => e
      puts "[PlayerHousingMP] Packet error: #{e.message}"
    end
  end

  # Helper to get current house data as hex-encoded JSON
  def self.get_my_house_hex
    data = PlayerHousing.housing_data
    json = MiniJSON.dump(data)
    json.unpack("H*")[0] rescue ""
  end

  # --- Data Broadcasting ---
  def self.send_housing_data(target_sid)
    return unless defined?(MultiplayerClient) && MultiplayerClient.respond_to?(:send_data)
    data = PlayerHousing.housing_data
    json = MiniJSON.dump(data)
    json_hex = json.unpack("H*")[0]
    MultiplayerClient.send_data("COOP_PARTY_PUSH_HEX:HOUSING_DAT:#{json_hex}")
  rescue => e
    puts "[PlayerHousingMP] send_housing_data error: #{e.message}"
  end

  def self.broadcast_housing_update
    return unless defined?(MultiplayerClient) && MultiplayerClient.respond_to?(:send_data)
    data = PlayerHousing.housing_data
    json = MiniJSON.dump(data)
    json_hex = json.unpack("H*")[0]
    MultiplayerClient.send_data("COOP_PARTY_PUSH_HEX:HOUSING_UPD:#{json_hex}")
  rescue => e
    puts "[PlayerHousingMP] broadcast_housing_update error: #{e.message}"
  end

  def self.send_visit_request(target_sid)
    return unless defined?(MultiplayerClient) && MultiplayerClient.respond_to?(:send_data)
    # Option 4: Isolated Settings Sync
    # This uses the engine's built-in global relay for JSON data.
    MultiplayerClient.send_data("MP_SETTINGS_REQUEST:#{target_sid}|HOUSING")
    puts "[PlayerHousingMP] Requested housing data from #{target_sid} via Settings Sync."
  rescue => e
    puts "[PlayerHousingMP] send_visit_request error: #{e.message}"
  end

  # Hook into MultiplayerSettingsSync to handle our custom "HOUSING" type
  def self.handle_settings_request(requester_sid, sync_type)
    if sync_type == "HOUSING"
      house_hex = get_my_house_hex
      # We send it back as a settings response which is relayed globally by the server
      MultiplayerClient.send_data("MP_SETTINGS_RESPONSE:#{requester_sid}|HOUSING|#{house_hex}")
      return true # Intercepted
    end
    false
  end

  def self.handle_settings_response(sync_type, hex_data)
    if sync_type == "HOUSING"
      begin
        json_str = [hex_data].pack("H*")
        data = MiniJSON.parse(json_str) rescue nil
        if data
          @pending_visit_data = data
        end
      rescue => e
        puts "[PlayerHousingMP] Failed to parse housing sync: #{e.message}"
      end
      return true # Intercepted
    end
    false
  end
end

# --- Game_Temp extensions for thread-safe main-thread scheduling ---
class Game_Temp
  attr_accessor :player_housing_needs_reload
end

# --- Scene_Map hook: process housing events on main thread ---
class Scene_Map
  alias __housing_mp_update update unless method_defined?(:__housing_mp_update)
  def update
    __housing_mp_update
    if $game_temp
      if $game_temp.respond_to?(:player_housing_needs_reload) && $game_temp.player_housing_needs_reload
        $game_temp.player_housing_needs_reload = false
        PlayerHousing.reload_housing_map if PlayerHousing.at_home?
      end
    end
  end
end

# --- Hook go_home to set instance owner to "self" ---
module PlayerHousing
  class << self
    alias __housing_mp_go_home go_home unless method_defined?(:__housing_mp_go_home)
  end

  def self.go_home
    self.housing_instance_owner = "self"
    __housing_mp_go_home
  end

  # --- Hook return_to_overworld to reset instance ---
  class << self
    alias __housing_mp_return_to_overworld return_to_overworld unless method_defined?(:__housing_mp_return_to_overworld)
  end

  def self.return_to_overworld
    __housing_mp_return_to_overworld
    self.housing_instance_owner = nil
    self.has_visitors = false
  end

  # --- Hook reload_housing_map to broadcast updates to visitors ---
  class << self
    alias __housing_mp_reload reload_housing_map unless method_defined?(:__housing_mp_reload)
  end

  def self.reload_housing_map
    __housing_mp_reload
    # If we're at home in our OWN base (not visiting) and have visitors, broadcast
    if !@visiting_data && @has_visitors && housing_instance_owner == "self"
      PlayerHousingMP.broadcast_housing_update
    end
  end
end

# --- KIFM Engine Hook: Intercept MultiplayerSettingsSync for isolated HOUSING type ---
if defined?(MultiplayerSettingsSync)
  module MultiplayerSettingsSync
    class << self
      unless method_defined?(:__housing_orig_handle_req)
        alias __housing_orig_handle_req handle_settings_request
        alias __housing_orig_handle_res handle_settings_response
      end

      def handle_settings_request(requester_sid, sync_type)
        # Try to handle as housing first
        return if PlayerHousingMP.handle_settings_request(requester_sid, sync_type)
        # Fallback to original
        __housing_orig_handle_req(requester_sid, sync_type)
      end

      def handle_settings_response(sync_type, json_data)
        # Try to handle as housing first
        return if PlayerHousingMP.handle_settings_response(sync_type, json_data)
        # Fallback to original
        __housing_orig_handle_res(sync_type, json_data)
      end
    end
  end
  puts "[Player Housing] Settings Sync hooks installed (Cross-Map Visitation)."
end

# --- KIFM Engine Hook: Intercept COOP_PARTY_PUSH_HEX packets (Legacy/Broadcast) ---
if defined?(MultiplayerClient) && MultiplayerClient.respond_to?(:_handle_coop_party_push_hex)
  module MultiplayerClient
    class << self
      unless method_defined?(:__housing_orig_handle_party)
        alias __housing_orig_handle_party _handle_coop_party_push_hex
      end

      def _handle_coop_party_push_hex(from_sid, hex)
        if hex.to_s.start_with?("HOUSING_")
          PlayerHousingMP.handle_packet(from_sid, hex)
          return
        end
        __housing_orig_handle_party(from_sid, hex)
      end
    end
  end
  puts "[Player Housing] Multiplayer packet hook installed."
end

# --- KIFM Engine Hook: Add hinst field to SYNC snapshot ---
if defined?(MultiplayerClient) && MultiplayerClient.respond_to?(:local_trainer_snapshot)
  module MultiplayerClient
    class << self
      unless method_defined?(:__housing_orig_snapshot)
        alias __housing_orig_snapshot local_trainer_snapshot
      end

      def local_trainer_snapshot
        snapshot = __housing_orig_snapshot
        return snapshot unless snapshot.is_a?(Hash)
        # Add housing instance info as a key in the hash
        hinst = PlayerHousing.housing_instance_owner || "0"
        if hinst == "self"
          hinst = (MultiplayerClient.session_id || "0").to_s
        end
        snapshot[:hinst] = hinst
        snapshot
      end
    end
  end
  puts "[Player Housing] Multiplayer SYNC snapshot hook installed."
end

# --- KIFM Engine Hook: Instance-aware remote player visibility ---
if defined?(Sprite_RemotePlayer)
  class Sprite_RemotePlayer
    unless method_defined?(:__housing_orig_update_with_data)
      alias __housing_orig_update_with_data update_with_data
    end

    def update_with_data(data)
      __housing_orig_update_with_data(data)

      # Filter visibility based on housing instance when on the housing map
      if PlayerHousing.at_home?
        my_hinst = PlayerHousing.housing_instance_owner || "0"
        if my_hinst == "self" && defined?(MultiplayerClient)
          my_hinst = (MultiplayerClient.session_id || "0").to_s
        end

        # data is a hash with symbol or string keys depending on how KIFM parses it
        remote_hinst = (data[:hinst] || data["hinst"] || "0").to_s

        # Hide if not in the same instance
        if my_hinst != remote_hinst
          self.visible = false
          @name_sprite.visible = false if @name_sprite
          @shadow.visible = false if @shadow
          @surf_base.visible = false if @surf_base
        end
      end
    end
  end
  puts "[Player Housing] Multiplayer sprite instancing hook installed."
end

# --- Visitor furniture interaction flavor text ---
module PlayerHousing
  class << self
    unless method_defined?(:__housing_mp_interact_furniture)
      alias __housing_mp_interact_furniture interact_furniture
    end
  end

  def self.interact_furniture(triggered_id = nil)
    if @visiting_data
      # Show flavor text instead of silent return
      h_data = current_housing_data
      tx = $game_player.x + ($game_player.direction == 6 ? 1 : $game_player.direction == 4 ? -1 : 0)
      ty = $game_player.y + ($game_player.direction == 2 ? 1 : $game_player.direction == 8 ? -1 : 0)
      (h_data["furniture"] || []).each do |f|
        next unless f
        fw = f["width"] || 1
        fh = f["height"] || 1
        (0...fw).each do |dx|
          (0...fh).each do |dy|
            if (f["x"] + dx) == tx && (f["y"] - dy) == ty
              if f["is_pc"]
                pbMessage(_INTL("It's a nice {1}. This PC belongs to the homeowner.", f["name"]))
              else
                pbMessage(_INTL("It's a nice {1}.", f["name"]))
              end
              return
            end
          end
        end
      end
      return
    end
    __housing_mp_interact_furniture(triggered_id)
  end
end

# --- Global Hook for pbLoadMapInfos to prevent name-related crashes ---
alias __housing_orig_pbLoadMapInfos pbLoadMapInfos unless defined?(__housing_orig_pbLoadMapInfos)
def pbLoadMapInfos
  infos = __housing_orig_pbLoadMapInfos
  if infos && !infos[PlayerHousingSettings::HOUSING_MAP_ID]
    info = RPG::MapInfo.new
    info.name = PlayerHousingSettings::MAP_NAME
    info.parent_id = 0
    info.order = 999
    infos[PlayerHousingSettings::HOUSING_MAP_ID] = info
  end
  return infos
end

puts "[Player Housing] Multiplayer visitation system initialized."

#====================================================
# GhostBase Housing Safety Warning
# Separated from PokePet system to standalone Housing.
#====================================================

class PokemonSaveScreen
  unless method_defined?(:ghostbase_housing_pbSaveScreen)
    alias ghostbase_housing_pbSaveScreen pbSaveScreen
    def pbSaveScreen
      if defined?(PlayerHousing) && PlayerHousing.at_home?
        pbMessage(_INTL("\\c[1]!!! EMERGENCY WARNING !!!\\c[0]"))
        pbMessage(_INTL("You are attempting to save while inside a \\c[2]Secret Base\\c[0]."))
        pbMessage(_INTL("Saving here may lead to \\c[1]SAVE FILE CORRUPTION\\c[0] if the mod is updated or disabled!"))
        pbMessage(_INTL("It is \\c[1]HIGHLY RECOMMENDED\\c[0] that you leave the house and save in a standard area."))
        if !pbConfirmMessageSerious(_INTL("Do you understand the risks and wish to proceed anyway?"))
          return false
        end
      end
      return ghostbase_housing_pbSaveScreen
    end
  end
end

unless respond_to?(:ghostbase_housing_pbConfirmMessage)
  alias ghostbase_housing_pbConfirmMessage pbConfirmMessage
  def pbConfirmMessage(message, &block)
    if defined?(PlayerHousing) && PlayerHousing.at_home?
      if message.include?("quit the game and return to the main menu")
        pbMessage(_INTL("\\c[1]!!! DANGER !!!\\c[0]"))
        pbMessage(_INTL("Quitting to the title screen from a \\c[2]Secret Base\\c[0] involves an automatic save."))
        pbMessage(_INTL("This could \\c[1]CORRUPT YOUR SAVE FILE\\c[0] if anything goes wrong with the map loading!"))
        if !pbConfirmMessageSerious(_INTL("Are you ABSOLUTELY sure you want to risk it?"))
          return false
        end
      end
    end
    return ghostbase_housing_pbConfirmMessage(message, &block)
  end
end


# ============================================================================
# SECTION 9: UNINSTALL SANITIZATION
# ============================================================================
module PlayerHousing
  def self.sanitize_for_uninstall
    if pbConfirmMessageSerious(_INTL("This will permanently delete your housing layout, inventory, and teleport you to safety so you can uninstall the mod. Proceed?"))
      # 1. Evacuate the player to prevent the Map 999 ENOENT crash
      if at_home?
        pbMessage(_INTL("Evacuating from the Secret Base..."))
        return_to_overworld
      end

      # 2. Scrub the injected global variables to clean the save file payload
      if defined?($PokemonGlobal)
        $PokemonGlobal.player_housing_data = nil
        $PokemonGlobal.home_return_point = nil
      end

      # 3. Clear the dynamic tileset from the global array
      if defined?($data_tilesets)
        $data_tilesets[PlayerHousingSettings::HOUSING_TILESET_ID] = nil
      end

      pbMessage(_INTL("Housing data wiped. You can now save your game normally and delete the mod script safely."))
    end
  end
end


# Inject into the Mod Settings Menu
module PlayerHousing
  def self.register_settings
    return unless defined?(ModSettingsMenu)

    unless ModSettingsMenu.categories.any? { |c| c[:name] == "Ghost Settings" }
      ModSettingsMenu.categories << {
        name: "Ghost Settings",
        priority: 85,
        description: "Settings for GhostXYZ mods",
        collapsed: true
      }
    end

    ModSettingsMenu.register(:player_housing_creative_mode, {
      name: "Housing: Creative Mode",
      type: :toggle,
      default: 0,
      category: "Ghost Settings"
    }) rescue nil

    ModSettingsMenu.register(:player_housing_uninstall_prep, {
      name: "Base: Housing Uninstall Prep",
      type: :button,
      category: "Ghost Settings",
      description: "Wipes all housing data and evacuates the player to prepare for mod removal.",
      on_press: proc {
        PlayerHousing.sanitize_for_uninstall
      }
    })

    # Ensure defaults on save load
    EventHandlers.add(:on_load_save_file, :ghost_housing_ensure_defaults) do |save_data|
      if ModSettingsMenu.get(:player_housing_creative_mode).nil?
        ModSettingsMenu.set(:player_housing_creative_mode, 0)
      end
    end if defined?(EventHandlers)
  end
end

# Initialize if ModSettingsMenu is available. If not, queue for when it loads.
if defined?(ModSettingsMenu)
  PlayerHousing.register_settings
else
  $MOD_SETTINGS_PENDING_REGISTRATIONS ||= []
  $MOD_SETTINGS_PENDING_REGISTRATIONS << proc { PlayerHousing.register_settings }
end