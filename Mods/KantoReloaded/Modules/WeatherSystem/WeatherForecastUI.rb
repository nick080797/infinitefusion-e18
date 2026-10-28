#==============================================================================
# Kanto Reloaded - Weather Forecast UI
#==============================================================================

module KantoReloaded
  module WeatherSystem
    module Forecast
      SCREEN_W = 512
      SCREEN_H = 384
      MAP_X = 6
      MAP_Y = 42
      MAP_W = 332
      MAP_H = 316
      DETAIL_X = 344
      DETAIL_Y = 42
      DETAIL_W = 162
      DETAIL_H = 316
      TILE_SIZE = 16
      CURSOR_DELAY = 12
      CURSOR_MARGIN = 32

      C_BG = Color.new(10, 12, 30, 255)
      C_PANEL = Color.new(16, 20, 38, 245)
      C_BORDER = Color.new(55, 75, 160, 255)
      C_WHITE = Color.new(255, 255, 255)
      C_GRAY = Color.new(166, 171, 196)
      C_DIM = Color.new(94, 100, 130)
      C_GREEN = Color.new(80, 230, 150)
      C_GOLD = Color.new(235, 192, 62)
      C_BLUE = Color.new(104, 184, 255)
      C_SHADOW = Color.new(0, 0, 0, 0)

      class << self
        def open
          Scene.new.main
        rescue StandardError => e
          WeatherSystem.log_exception("Weather Forecast failed to open", e)
          KantoReloaded::PopupWindow.message(
            _INTL("The Weather Forecast could not be opened."),
            :theme => :error
          ) if defined?(KantoReloaded::PopupWindow)
          false
        end

        def draw_compact(scene, sprite, bounds)
          bitmap = sprite.bitmap
          bitmap.clear
          width = bounds[:width].to_i
          height = bounds[:height].to_i
          KantoReloaded::UI::QuickMenuStyle.draw_panel(
            bitmap, width, height, "FORECAST"
          )
          current = WeatherSystem.current_state
          future = WeatherSystem.forecast_state
          draw_icon(bitmap, current[:weather], current[:intensity], 9, 34, 28)
          draw_icon(bitmap, future[:weather], future[:intensity],
                    width / 2 + 1, 34, 28)
          pbSetSmallFont(bitmap)
          bitmap.font.size = 12
          pbDrawShadowText(bitmap, 42, 28, width / 2 - 45, 16,
                           _INTL("NOW"), C_DIM, C_SHADOW)
          pbDrawShadowText(bitmap, width / 2 + 34, 28, width / 2 - 39, 16,
                           _INTL("NEXT"), C_DIM, C_SHADOW)
          bitmap.font.size = 15
          pbDrawShadowText(
            bitmap, 42, 43, width / 2 - 45, 18,
            WeatherSystem.weather_name(current[:weather]), C_WHITE, C_SHADOW
          )
          pbDrawShadowText(
            bitmap, width / 2 + 34, 43, width / 2 - 39, 18,
            WeatherSystem.weather_name(future[:weather]), C_WHITE, C_SHADOW
          )
          bitmap.font.size = 12
          pbDrawShadowText(
            bitmap, 10, height - 24, width - 20, 16,
            _INTL("Updates in {1}", Simulation.format_remaining),
            C_GREEN, C_SHADOW, 1
          )
          true
        rescue StandardError => e
          OverworldMenu.log_exception("Weather Forecast panel failed", e) if
            defined?(OverworldMenu)
          false
        end

        def draw_icon(bitmap, weather, intensity, x, y, size = 24)
          source = scaled_icon_bitmap(weather, intensity, size)
          return false unless source && !source.disposed?
          bitmap.blt(x, y, source, source.rect)
          true
        rescue StandardError => e
          log_icon_error("draw", WeatherSystem.icon_path(weather, intensity), e)
          false
        end

        def scaled_icon_bitmap(weather, intensity, size)
          source = icon_bitmap(weather, intensity)
          return nil unless source && !source.disposed?
          dimension = [size.to_i, 1].max
          return source if source.width == dimension &&
                           source.height == dimension
          path = WeatherSystem.icon_path(weather, intensity)
          key = "#{path}|#{dimension}"
          @scaled_icon_cache ||= {}
          cached = @scaled_icon_cache[key]
          return cached if cached && !cached.disposed?
          scaled = Bitmap.new(dimension, dimension)
          scaled.stretch_blt(
            scaled.rect, source,
            Rect.new(0, 0, source.width, source.height)
          )
          @scaled_icon_cache[key] = scaled
        rescue StandardError => e
          log_icon_error("scale", path, e)
          nil
        end

        def icon_bitmap(weather, intensity)
          path = WeatherSystem.icon_path(weather, intensity)
          @icon_cache ||= {}
          cached = @icon_cache[path]
          return cached if cached && !cached.disposed?
          resolved = direct_icon_path(path)
          resolved ||= pbResolveBitmap(path) rescue nil
          unless resolved
            log_missing_icon(path)
            return nil
          end
          @icon_cache[path] = Bitmap.new(resolved)
        rescue StandardError => e
          log_icon_error("load", path, e)
          nil
        end

        def direct_icon_path(path)
          [path.to_s, "#{path}.png", "#{path}.gif"].each do |candidate|
            exists = File.file?(candidate)
            exists ||= safeExists?(candidate) if defined?(safeExists?)
            return candidate if exists
          end
          nil
        rescue
          nil
        end

        def log_missing_icon(path)
          @missing_icons ||= {}
          return if @missing_icons[path]
          @missing_icons[path] = true
          KantoReloaded::Log.warning(
            "Missing weather forecast icon: #{path}",
            :weather_system
          ) if defined?(KantoReloaded::Log)
        rescue
          nil
        end

        def log_icon_error(action, path, error)
          @icon_errors ||= {}
          key = "#{action}|#{path}|#{error.class}|#{error.message}"
          return if @icon_errors[key]
          @icon_errors[key] = true
          KantoReloaded::Log.exception(
            "Weather forecast icon #{action} failed for #{path}",
            error,
            :channel => :weather_system
          ) if defined?(KantoReloaded::Log)
        rescue
          nil
        end
      end

      class Scene
        def main
          start
          update_loop
          true
        ensure
          dispose
        end

        private

        def start
          @mode = :current
          @viewport = Viewport.new(0, 0, SCREEN_W, SCREEN_H)
          @viewport.z = 99999
          @map_overlay_viewport = Viewport.new(MAP_X, MAP_Y, MAP_W, MAP_H)
          @map_overlay_viewport.z = @viewport.z + 1
          @background = Sprite.new(@viewport)
          @map_sprite = Sprite.new(@viewport)
          @detail_sprite = Sprite.new(@viewport)
          @background.bitmap = Bitmap.new(SCREEN_W, SCREEN_H)
          @map_sprite.bitmap = Bitmap.new(MAP_W, MAP_H)
          @detail_sprite.bitmap = Bitmap.new(DETAIL_W, DETAIL_H)
          @map_sprite.x = MAP_X
          @map_sprite.y = MAP_Y
          @detail_sprite.x = DETAIL_X
          @detail_sprite.y = DETAIL_Y
          @cell_positions_cache = {}
          build_position_cell_index
          load_world_map
          create_cursor
          choose_initial_cell
          center_on_selected
          draw_all
          Input.update
        end

        def update_loop
          loop do
            Graphics.update
            Input.update
            update_cursor_animation
            changed = handle_mouse
            changed = move_cursor(-1, 0) || changed if input_repeat?(:LEFT)
            changed = move_cursor(1, 0) || changed if input_repeat?(:RIGHT)
            changed = move_cursor(0, -1) || changed if input_repeat?(:UP)
            changed = move_cursor(0, 1) || changed if input_repeat?(:DOWN)
            if input_trigger?(:L)
              @mode = :current
              changed = true
            elsif input_trigger?(:R)
              @mode = :forecast
              changed = true
            elsif input_trigger?(:ACTION)
              choose_initial_cell
              center_on_selected
              changed = true
            elsif input_trigger?(:BACK)
              pbPlayCancelSE
              break
            end
            if changed
              clamp_offsets
              draw_all
              pbPlayCursorSE
            end
          end
        end

        def draw_all
          @display_snapshot = @mode == :forecast ?
            Simulation.forecast_snapshot : Simulation.current_snapshot
          draw_background
          draw_map
          draw_detail
          update_cursor_sprite
          Graphics.update
        end

        def draw_background
          bitmap = @background.bitmap
          bitmap.clear
          bitmap.fill_rect(0, 0, SCREEN_W, SCREEN_H, C_BG)
          pbSetSmallFont(bitmap)
          bitmap.font.size = 18
          bitmap.font.bold = true
          pbDrawShadowText(bitmap, 0, 7, SCREEN_W, 22,
                           _INTL("WEATHER FORECAST"), C_WHITE,
                           Color.new(0, 0, 0, 160), 1)
          bitmap.font.bold = false
          current_color = @mode == :current ? C_GREEN : C_DIM
          forecast_color = @mode == :forecast ? C_GREEN : C_DIM
          bitmap.font.size = 13
          pbDrawShadowText(bitmap, 10, 26, 98, 15,
                           _INTL("CURRENT"), current_color, C_SHADOW)
          pbDrawShadowText(bitmap, 108, 26, 98, 15,
                           _INTL("NEXT"), forecast_color, C_SHADOW)
        end

        def draw_map
          bitmap = @map_sprite.bitmap
          bitmap.clear
          bitmap.fill_rect(0, 0, MAP_W, MAP_H, C_PANEL)
          if @world_map && !@world_map.disposed?
            source = Rect.new(
              @map_offset_x, @map_offset_y,
              [MAP_W, @world_map.width].min,
              [MAP_H, @world_map.height].min
            )
            bitmap.blt(0, 0, @world_map, source)
          end
          @hit_cells = []
          hit_positions = {}
          WeatherSystem.cell_map.each do |cell|
            positions = map_positions_for_cell(cell)
            positions.each do |position|
              next unless position[0].to_i == current_region
              x = position[1].to_i * TILE_SIZE - @map_offset_x
              y = position[2].to_i * TILE_SIZE - @map_offset_y
              next if x <= -TILE_SIZE || y <= -TILE_SIZE ||
                      x >= MAP_W || y >= MAP_H
              display_cell = display_cell_for_position(position)
              next unless display_cell &&
                          display_cell[:key] == cell[:key]
              key = position_key(position)
              next if hit_positions[key]
              hit_positions[key] = true
              @hit_cells << [
                Rect.new(MAP_X + x, MAP_Y + y, TILE_SIZE, TILE_SIZE),
                cell,
                position
              ]
            end
            position = icon_position_for_cell(cell, positions)
            next unless position && position[0].to_i == current_region
            display_cell = display_cell_for_position(position)
            next unless display_cell && display_cell[:key] == cell[:key]
            state = state_for_cell(cell, position)
            next if WeatherSystem.normalize_weather(state[:weather]) == :None
            x = position[1].to_i * TILE_SIZE - @map_offset_x - 4
            y = position[2].to_i * TILE_SIZE - @map_offset_y - 4
            next if x < -24 || y < -24 || x >= MAP_W || y >= MAP_H
            Forecast.draw_icon(
              bitmap, state[:weather], state[:intensity], x, y, 24
            )
          end
          draw_current_location(bitmap)
          draw_frame(bitmap, MAP_W, MAP_H)
        end

        def draw_current_location(bitmap)
          position = current_map_position
          return unless position && position[0].to_i == current_region
          x = position[1].to_i * TILE_SIZE - @map_offset_x
          y = position[2].to_i * TILE_SIZE - @map_offset_y
          return if x <= -TILE_SIZE || y <= -TILE_SIZE ||
                    x >= MAP_W || y >= MAP_H
          if @player_icon && !@player_icon.disposed?
            destination = Rect.new(x, y, TILE_SIZE, TILE_SIZE)
            bitmap.stretch_blt(destination, @player_icon, @player_icon.rect)
          else
            bitmap.fill_rect(x + 5, y + 5, 6, 6, C_GREEN)
            bitmap.fill_rect(x + 6, y + 6, 4, 4, C_WHITE)
          end
        rescue
          nil
        end

        def draw_detail
          bitmap = @detail_sprite.bitmap
          bitmap.clear
          bitmap.fill_rect(0, 0, DETAIL_W, DETAIL_H, C_PANEL)
          draw_frame(bitmap, DETAIL_W, DETAIL_H)
          cell = @selected_cell
          unless cell
            pbSetSmallFont(bitmap)
            bitmap.font.size = 13
            draw_wrapped(
              bitmap, _INTL("No forecast data is available here."),
              10, 18, DETAIL_W - 20, C_GRAY, 3
            )
            return
          end
          state = state_for_cell(cell, @cursor_position)
          pbSetSmallFont(bitmap)
          bitmap.font.size = 15
          bitmap.font.bold = true
          draw_wrapped(bitmap, cell[:label], 9, 12, DETAIL_W - 18,
                       C_WHITE, 2)
          bitmap.font.bold = false
          Forecast.draw_icon(
            bitmap, state[:weather], state[:intensity],
            (DETAIL_W - 48) / 2, 60, 48
          )
          bitmap.font.size = 16
          pbDrawShadowText(
            bitmap, 8, 112, DETAIL_W - 16, 20,
            weather_display_name(state),
            weather_color(state), C_SHADOW, 1
          )
          bitmap.font.size = 13
          y = 143
          y = draw_pair(bitmap, _INTL("Intensity"),
                        state[:weather] == :None ? "-" : state[:intensity], y)
          y = draw_pair(bitmap, _INTL("Climate"),
                        WeatherSystem.climate_name(cell[:climate]), y)
          trend = if state[:authored]
                    state[:live] ? _INTL("Authored Roll") :
                      _INTL("Authored Chance")
                  else
                    state[:trend].to_s.capitalize
                  end
          y = draw_pair(bitmap, _INTL("Trend"), trend, y)
          if state[:authored] && state[:chance].to_i > 0
            y = draw_pair(bitmap, _INTL("Map Chance"),
                          "#{state[:chance]}%", y)
          end
          bitmap.font.size = 12
          pbDrawShadowText(
            bitmap, 8, DETAIL_H - 46, DETAIL_W - 16, 16,
            @mode == :forecast ? _INTL("NEXT CYCLE") :
              _INTL("CURRENT WEATHER"),
            @mode == :forecast ? C_BLUE : C_GREEN, C_SHADOW, 1
          )
          pbDrawShadowText(
            bitmap, 8, DETAIL_H - 28, DETAIL_W - 16, 16,
            _INTL("Updates in {1}", Simulation.format_remaining),
            C_GRAY, C_SHADOW, 1
          )
        end

        def draw_pair(bitmap, label, value, y)
          bitmap.font.size = 12
          pbDrawShadowText(bitmap, 8, y, DETAIL_W - 16, 16,
                           label.to_s, C_DIM, C_SHADOW)
          bitmap.font.size = 13
          pbDrawShadowText(bitmap, 8, y + 13, DETAIL_W - 16, 17,
                           value.to_s, C_WHITE, C_SHADOW, 2)
          y + 34
        end

        def draw_wrapped(bitmap, text, x, y, width, color, max_lines)
          lines = KantoReloaded::UI::Draw.wrap_lines(bitmap, text, width) rescue
            [text.to_s]
          lines.first(max_lines).each_with_index do |line, index|
            pbDrawShadowText(bitmap, x, y + index * 18, width, 18,
                             line, color, C_SHADOW, 1)
          end
        end

        def draw_frame(bitmap, width, height)
          bitmap.fill_rect(0, 0, width, 1, C_BORDER)
          bitmap.fill_rect(0, height - 1, width, 1, C_BORDER)
          bitmap.fill_rect(0, 0, 1, height, C_BORDER)
          bitmap.fill_rect(width - 1, 0, 1, height, C_BORDER)
        end

        def state_for_cell(cell, position = nil)
          Simulation.state_for_cell(
            cell[:key], @mode, @display_snapshot
          ).merge(
            :cell => cell,
            :authored => false
          ).tap do |state|
            unless state[:admin_forced]
              authored = authored_state(cell, position)
              state.replace(authored) if authored
            end
          end
        end

        def authored_state(cell, position = nil)
          pairs = Array(cell[:authored_weather])
          return nil if pairs.empty?
          authored_ids = pairs.map { |pair| pair[0].to_i }
          map_ids = matching_map_ids(cell, position)
          current_id = defined?($game_map) && $game_map ?
            $game_map.map_id.to_i : 0
          map_id = current_id if map_ids.include?(current_id) &&
                                 authored_ids.include?(current_id)
          map_id ||= map_ids.find { |id| authored_ids.include?(id) }
          map_id ||= authored_ids[0] if Array(cell[:dynamic_map_ids]).empty?
          return nil unless map_id
          pair = pairs.find { |entry| entry[0].to_i == map_id.to_i }
          return nil unless pair
          Simulation.state_for_map(map_id, {}, @mode)
        rescue
          nil
        end

        def matching_map_ids(cell, position)
          return [] unless cell && position
          Array(cell[:map_ids]).select do |map_id|
            metadata = GameData::MapMetadata.try_get(map_id) rescue nil
            map_positions_for_metadata(metadata).any? do |candidate|
              candidate[0].to_i == position[0].to_i &&
                candidate[1].to_i == position[1].to_i &&
                candidate[2].to_i == position[2].to_i
            end
          end
        rescue
          []
        end

        def choose_initial_cell
          map_id = defined?($game_map) && $game_map ? $game_map.map_id : 0
          position = current_map_position
          @selected_cell = WeatherSystem.cell_map.cell_for_map(map_id)
          @selected_cell ||= cell_at_position(position)
          @selected_cell ||= nearest_cell(position)
          @selected_cell ||= WeatherSystem.cell_map.each.first
          @cursor_position = position || icon_position_for_cell(@selected_cell)
          @focus_position = @cursor_position
        end

        def center_on_selected
          position = @focus_position || @cursor_position ||
                     icon_position_for_cell(@selected_cell)
          if position
            @map_offset_x = position[1].to_i * TILE_SIZE - MAP_W / 2
            @map_offset_y = position[2].to_i * TILE_SIZE - MAP_H / 2
          else
            @map_offset_x = 0
            @map_offset_y = 0
          end
          clamp_offsets
        end

        def move_cursor(delta_x, delta_y)
          return false unless @cursor_position
          max_x = [(@world_map ? @world_map.width : MAP_W) / TILE_SIZE - 1, 0].max
          max_y = [(@world_map ? @world_map.height : MAP_H) / TILE_SIZE - 1, 0].max
          next_x = [[@cursor_position[1].to_i + delta_x, 0].max, max_x].min
          next_y = [[@cursor_position[2].to_i + delta_y, 0].max, max_y].min
          return false if next_x == @cursor_position[1].to_i &&
                          next_y == @cursor_position[2].to_i
          @cursor_position = [current_region, next_x, next_y]
          @selected_cell = cell_at_position(@cursor_position)
          ensure_cursor_visible
          true
        end

        def ensure_cursor_visible
          return unless @cursor_position
          pixel_x = @cursor_position[1].to_i * TILE_SIZE
          pixel_y = @cursor_position[2].to_i * TILE_SIZE
          visible_x = pixel_x - @map_offset_x.to_i
          visible_y = pixel_y - @map_offset_y.to_i
          if visible_x < CURSOR_MARGIN
            @map_offset_x = pixel_x - CURSOR_MARGIN
          elsif visible_x + TILE_SIZE > MAP_W - CURSOR_MARGIN
            @map_offset_x = pixel_x + TILE_SIZE -
                            (MAP_W - CURSOR_MARGIN)
          end
          if visible_y < CURSOR_MARGIN
            @map_offset_y = pixel_y - CURSOR_MARGIN
          elsif visible_y + TILE_SIZE > MAP_H - CURSOR_MARGIN
            @map_offset_y = pixel_y + TILE_SIZE -
                            (MAP_H - CURSOR_MARGIN)
          end
          clamp_offsets
        end

        def clamp_offsets
          max_x = [(@world_map ? @world_map.width : MAP_W) - MAP_W, 0].max
          max_y = [(@world_map ? @world_map.height : MAP_H) - MAP_H, 0].max
          @map_offset_x = [[@map_offset_x.to_i, 0].max, max_x].min
          @map_offset_y = [[@map_offset_y.to_i, 0].max, max_y].min
        end

        def load_world_map
          filename = (defined?(isPostgame?) && isPostgame?) ?
                     "map_postgame" : "map"
          path = "Graphics/Pictures/map/#{filename}"
          resolved = pbResolveBitmap(path) rescue nil
          @world_map = Bitmap.new(resolved) if resolved
          player_path = pbResolveBitmap(
            "Graphics/Pictures/map/location_icon"
          ) rescue nil
          @player_icon = Bitmap.new(player_path) if player_path
        rescue
          @world_map = nil
          @player_icon = nil
        end

        def create_cursor
          path = pbResolveBitmap("Graphics/Pictures/mapCursor") rescue nil
          return unless path
          @cursor_sprite = Sprite.new(@map_overlay_viewport)
          @cursor_sprite.bitmap = Bitmap.new(path)
          @cursor_frame_width = @cursor_sprite.bitmap.height
          @cursor_frame_count = [
            @cursor_sprite.bitmap.width / @cursor_frame_width, 1
          ].max
          @cursor_sprite.src_rect = Rect.new(
            0, 0, @cursor_frame_width, @cursor_sprite.bitmap.height
          )
          @cursor_sprite.ox = (@cursor_frame_width - TILE_SIZE) / 2
          @cursor_sprite.oy = (@cursor_sprite.bitmap.height - TILE_SIZE) / 2
          @cursor_frame = 0
          @cursor_frame_tick = Graphics.frame_count
        rescue
          @cursor_sprite = nil
        end

        def update_cursor_animation
          return unless @cursor_sprite && @cursor_frame_count.to_i > 1
          elapsed = Graphics.frame_count - @cursor_frame_tick.to_i
          return if elapsed < CURSOR_DELAY
          @cursor_frame = (@cursor_frame.to_i + 1) % @cursor_frame_count
          @cursor_sprite.src_rect.x = @cursor_frame * @cursor_frame_width
          @cursor_frame_tick = Graphics.frame_count
        rescue
          nil
        end

        def update_cursor_sprite
          return unless @cursor_sprite
          unless @cursor_position &&
                 @cursor_position[0].to_i == current_region
            @cursor_sprite.visible = false
            return
          end
          x = @cursor_position[1].to_i * TILE_SIZE - @map_offset_x
          y = @cursor_position[2].to_i * TILE_SIZE - @map_offset_y
          @cursor_sprite.visible = x >= 0 && y >= 0 &&
                                   x < MAP_W && y < MAP_H
          @cursor_sprite.x = x
          @cursor_sprite.y = y
        rescue
          @cursor_sprite.visible = false if @cursor_sprite
        end

        def handle_mouse
          position = KantoReloaded::MouseInput.active_position rescue nil
          return false unless position
          hit = @hit_cells.find do |entry|
            rect = entry[0]
            position[0] >= rect.x && position[0] < rect.x + rect.width &&
              position[1] >= rect.y && position[1] < rect.y + rect.height
          end
          return false unless hit
          same_cell = @selected_cell &&
                      @selected_cell[:key] == hit[1][:key]
          same_position = @cursor_position &&
                          @cursor_position[0, 3] == hit[2][0, 3]
          return false if same_cell && same_position
          @selected_cell = hit[1]
          @cursor_position = hit[2]
          @focus_position = nil
          true
        end

        def map_positions_for_cell(cell)
          return [] unless cell
          key = cell[:key].to_s
          cached = @cell_positions_cache[key]
          return cached if cached
          positions = []
          Array(cell[:map_ids]).each do |map_id|
            metadata = GameData::MapMetadata.try_get(map_id) rescue nil
            positions.concat(map_positions_for_metadata(metadata))
          end
          positions = Array(cell[:coordinates]) if positions.empty?
          @cell_positions_cache[key] = positions.compact.uniq
        rescue
          Array(cell && cell[:coordinates]).compact
        end

        def map_positions_for_metadata(metadata)
          position = metadata && metadata.town_map_position
          return [] unless position
          base = [position[0].to_i, position[1].to_i, position[2].to_i]
          size = metadata.town_map_size rescue nil
          return [base] unless size && size[0].to_i > 0 &&
                               size[1] && !size[1].to_s.empty?
          width = size[0].to_i
          shape = size[1].to_s
          height = (shape.length.to_f / width).ceil
          positions = []
          width.times do |x|
            height.times do |y|
              next unless shape[x + y * width, 1].to_i > 0
              positions << [base[0], base[1] + x, base[2] + y]
            end
          end
          positions.empty? ? [base] : positions
        rescue
          []
        end

        def build_position_cell_index
          @position_cells = {}
          WeatherSystem.cell_map.each do |cell|
            map_positions_for_cell(cell).each do |position|
              key = position_key(position)
              @position_cells[key] ||= []
              @position_cells[key] << cell unless
                @position_cells[key].any? { |entry| entry[:key] == cell[:key] }
            end
          end
          @position_cells
        rescue
          @position_cells = {}
        end

        def position_key(position)
          return nil unless position
          [position[0].to_i, position[1].to_i, position[2].to_i]
        end

        def display_cell_for_position(position)
          candidates = Array(@position_cells[position_key(position)])
          return nil if candidates.empty?
          current_position = current_map_position
          if current_position &&
             position_key(current_position) == position_key(position)
            current_map_id = defined?($game_map) && $game_map ?
              $game_map.map_id.to_i : 0
            current_cell = WeatherSystem.cell_map.cell_for_map(current_map_id)
            return current_cell if current_cell && candidates.any? do |cell|
              cell[:key] == current_cell[:key]
            end
          end
          candidates[0]
        rescue
          candidates && candidates[0]
        end

        def icon_position_for_cell(cell, positions = nil)
          return nil unless cell
          positions ||= map_positions_for_cell(cell)
          current = current_map_position
          return current if position_in_cell?(cell, current)
          Array(positions).find { |position|
            position[0].to_i == current_region
          } || Array(positions).first || cell[:position]
        rescue
          cell && cell[:position]
        end

        def position_in_cell?(cell, position)
          return false unless cell && position
          map_positions_for_cell(cell).any? do |candidate|
            candidate[0].to_i == position[0].to_i &&
              candidate[1].to_i == position[1].to_i &&
              candidate[2].to_i == position[2].to_i
          end
        rescue
          false
        end

        def cell_at_position(position)
          return nil unless position
          display_cell_for_position(position)
        rescue
          nil
        end

        def nearest_cell(position)
          return nil unless position
          candidates = WeatherSystem.cell_map.each.map do |cell|
            coordinates = map_positions_for_cell(cell).select do |candidate|
              candidate[0].to_i == position[0].to_i
            end
            next nil if coordinates.empty?
            distance = coordinates.map do |candidate|
              (candidate[1].to_i - position[1].to_i).abs +
                (candidate[2].to_i - position[2].to_i).abs
            end.min
            [distance, cell]
          end.compact
          entry = candidates.min_by { |candidate| candidate[0] }
          entry && entry[1]
        rescue
          nil
        end

        def current_map_position
          metadata = current_metadata
          position = metadata && metadata.town_map_position
          return nil unless position
          result = [
            position[0].to_i, position[1].to_i, position[2].to_i
          ]
          size = metadata.town_map_size rescue nil
          if size && size[0].to_i > 0 && size[1] &&
             defined?($game_player) && $game_player &&
             defined?($game_map) && $game_map
            width = size[0].to_i
            height = (size[1].to_s.length.to_f / width).ceil
            if width > 1 && $game_map.width.to_i > 0
              result[1] += (
                $game_player.x.to_i * width / $game_map.width.to_i
              ).floor
            end
            if height > 1 && $game_map.height.to_i > 0
              result[2] += (
                $game_player.y.to_i * height / $game_map.height.to_i
              ).floor
            end
          end
          result
        rescue
          nil
        end

        def weather_color(state)
          return C_DIM if state[:weather] == :None
          return C_BLUE if [:Rain, :Snow, :Fog].include?(state[:weather])
          return C_GOLD if [:Sunny, :Sandstorm].include?(state[:weather])
          C_GREEN
        end

        def weather_display_name(state)
          weather = state[:weather]
          if state[:authored] && !state[:live] &&
             state[:chance].to_i > 0 && state[:chance].to_i < 100
            authored = state[:authored_weather] || weather
            return _INTL(
              "{1} Chance", WeatherSystem.weather_name(authored)
            )
          end
          WeatherSystem.weather_name(weather)
        rescue
          WeatherSystem.weather_name(state[:weather])
        end

        def current_metadata
          return nil unless defined?(GameData::MapMetadata) &&
                            defined?($game_map) && $game_map
          GameData::MapMetadata.try_get($game_map.map_id)
        rescue
          nil
        end

        def current_region
          position = current_metadata && current_metadata.town_map_position
          position ? position[0].to_i : 0
        rescue
          0
        end

        def input_trigger?(name)
          return false unless Input.const_defined?(name)
          Input.trigger?(Input.const_get(name))
        rescue
          false
        end

        def input_repeat?(name)
          return false unless Input.const_defined?(name)
          Input.repeat?(Input.const_get(name))
        rescue
          false
        end

        def dispose
          [@background, @map_sprite, @detail_sprite].compact.each do |sprite|
            sprite.bitmap.dispose rescue nil
            sprite.dispose rescue nil
          end
          if @cursor_sprite
            @cursor_sprite.bitmap.dispose rescue nil
            @cursor_sprite.dispose rescue nil
          end
          @world_map.dispose rescue nil
          @player_icon.dispose rescue nil
          @map_overlay_viewport.dispose rescue nil
          @viewport.dispose rescue nil
          Input.update rescue nil
        end
      end
    end
  end
end
