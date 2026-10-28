#==============================================================================
# Kanto Reloaded - Wild Link Map Diagnostics
#==============================================================================

module KantoReloaded
  module WildLink
    module MapData
      REPORT_PATH = File.join(
        KantoReloaded::Log::LOG_DIR, "WildLinkMapData.txt"
      )

      class << self
        def file
          unless map_ready?
            KantoReloaded.message(
              _INTL("Map data can only be gathered from the overworld."),
              :theme => :warning
            )
            return false
          end
          content = build_report
          KantoReloaded::BugReport.publish_generated(
            :display_name => _INTL("Kanto Reloaded map data"),
            :link_label => "Kanto Reloaded Map Data",
            :title => _INTL("Gathering Map Data"),
            :initial_message => _INTL("Preparing map diagnostics..."),
            :cancel_prompt => _INTL("Cancel the map data export?"),
            :open_discord => false
          ) { write_report(content) }
        rescue StandardError => e
          WildLink.log_exception("Wild Link map data export failed", e)
          KantoReloaded.message(
            _INTL(
              "Could not gather Wild Link map data.\n{1}",
              sanitized_error(e)
            ),
            :theme => :error
          )
          false
        end

        def build_report
          lines = []
          lines << "[KANTO RELOADED MAP DATA]"
          lines << "Timestamp: #{Time.now}"
          lines << "KIF Version: #{kif_version}"
          lines << "Kanto Reloaded Version: #{KantoReloaded.version}"
          lines << "Platform: #{platform_label}"
          lines << ""
          append_map(lines)
          append_map_metadata(lines)
          append_player(lines)
          append_weather(lines)
          append_wild_link(lines)
          append_field_tools(lines)
          append_terrain(lines)
          append_events(lines)
          append_encounters(lines)
          lines << "[/KANTO RELOADED MAP DATA]"
          KantoReloaded::Log.sanitize(lines.join("\n"))
        end

        def write_report(content, path = REPORT_PATH)
          directory = File.dirname(path)
          Dir.mkdir(directory) unless Dir.exist?(directory)
          temp_path = "#{path}.tmp"
          File.open(temp_path, "wb") { |file| file.write(content.to_s) }
          unless File.file?(temp_path) && File.size(temp_path).to_i > 0
            raise "Wild Link map data temp file was empty."
          end
          File.delete(path) if File.file?(path)
          File.rename(temp_path, path)
          KantoReloaded::Log.info(
            "Wild Link map data exported: #{path}", :wild_link
          )
          path
        ensure
          File.delete(temp_path) if defined?(temp_path) && File.file?(temp_path)
        end

        private

        def map_ready?
          defined?($game_map) && $game_map &&
            $game_map.respond_to?(:map_id) && $game_map.map_id.to_i > 0
        rescue StandardError
          false
        end

        def append_map(lines)
          raw_map = $game_map.instance_variable_get(:@map)
          lines << "[MAP]"
          lines << "Map ID: #{$game_map.map_id}"
          lines << "Name: #{safe_map_name}"
          lines << "Dimensions: #{$game_map.width}x#{$game_map.height}"
          lines << "Tileset ID: #{safe_value(raw_map && raw_map.tileset_id)}"
          lines << "Event Count: #{map_events.length}"
          lines << "Loaded Connected Maps: #{loaded_map_ids.join(', ')}"
          lines << ""
        rescue StandardError => e
          lines << "Map details unavailable: #{sanitized_error(e)}"
          lines << ""
        end

        def append_map_metadata(lines)
          lines << "[MAP METADATA]"
          metadata = GameData::MapMetadata.try_get($game_map.map_id)
          unless metadata
            lines << "No MapMetadata record."
            lines << ""
            return
          end
          variables = metadata.instance_variables.sort_by { |name| name.to_s }
          variables.each do |name|
            label = name.to_s.sub(/\A@/, "")
            lines << "#{label}: #{safe_value(metadata.instance_variable_get(name))}"
          end
          lines << ""
        rescue StandardError => e
          lines << "Map metadata unavailable: #{sanitized_error(e)}"
          lines << ""
        end

        def append_player(lines)
          lines << "[PLAYER MAP STATE]"
          if defined?($game_player) && $game_player
            lines << "Position: #{$game_player.x}, #{$game_player.y}"
            lines << "Direction: #{safe_value($game_player.direction)}"
            lines << "Current Terrain: #{terrain_description(current_terrain)}"
            lines << "Facing Terrain: #{terrain_description(facing_terrain)}"
          else
            lines << "Player map object unavailable."
          end
          lines << "Surfing: #{global_flag(:surfing)}"
          lines << "Diving: #{global_flag(:diving)}"
          lines << "Bicycle: #{global_flag(:bicycle)}"
          lines << ""
        rescue StandardError => e
          lines << "Player map state unavailable: #{sanitized_error(e)}"
          lines << ""
        end

        def append_weather(lines)
          lines << "[WEATHER SYSTEM]"
          unless defined?(KantoReloaded::WeatherSystem) &&
                 defined?(KantoReloaded::WeatherSystem::Simulation)
            lines << "Weather System unavailable."
            lines << ""
            return
          end
          weather = KantoReloaded::WeatherSystem
          simulation = KantoReloaded::WeatherSystem::Simulation
          map_id = $game_map.map_id.to_i
          metadata = GameData::MapMetadata.try_get(map_id) rescue nil
          outdoor = metadata && metadata.respond_to?(:outdoor_map) &&
                    !!metadata.outdoor_map
          map_override = weather.map_override(map_id)
          eligible = weather.weather_map_eligible?(map_id, metadata)
          authored = metadata && metadata.respond_to?(:weather) ?
            metadata.weather : nil
          reserved_authored = weather.reserved_authored_weather?(authored)
          replaced_authored = weather.replaceable_authored_weather?(authored)
          cell = weather.cell_map.cell_for_map(map_id)
          current = simulation.current_for_map(map_id)
          forecast = simulation.forecast_for_map(map_id)
          lines << "Enabled: #{weather.enabled?}"
          lines << "Battle Weather: #{weather.battle_weather?}"
          lines << "Custom Audio: #{weather.custom_audio?}"
          lines << "Forecast View: #{weather.forecast_view?}"
          lines << "Interval Hours: #{simulation.interval_hours}"
          lines << "Next Cycle At: #{safe_value(simulation.next_cycle_at)}"
          lines << "Updates In: #{simulation.format_remaining}"
          lines << "Outdoor Metadata: #{outdoor}"
          lines << "Map Override: #{safe_value(map_override)}"
          lines << "Override Eligible: #{safe_value(map_override[:eligible])}"
          lines << "Override Cell Group: #{safe_value(map_override[:cell_group])}"
          lines << "Override Climate: #{safe_value(map_override[:climate])}"
          lines << "Override Label: #{safe_value(map_override[:label])}"
          lines << "Authored Weather: #{safe_value(authored)}"
          lines << "Guaranteed Authored Weather: #{reserved_authored}"
          lines << "Authored Weather Replaced: #{replaced_authored}"
          lines << "Dynamic Application Eligible: #{eligible && !reserved_authored}"
          lines << "Weather Owner: #{safe_value(
            weather.instance_variable_get(:@weather_owner)
          )}"
          lines << "Owned Map ID: #{safe_value(
            weather.instance_variable_get(:@owned_map_id)
          )}"
          lines << "KR Owns Current Weather: #{weather.kr_weather_owned?}"
          lines << "External Weather Owned: #{weather.external_weather_owned?}"
          lines << "Live Screen Weather: #{screen_weather_description}"
          lines << "Current State: #{weather_state_description(current)}"
          lines << "Forecast State: #{weather_state_description(forecast)}"
          lines << "Icon Root: #{safe_value(weather.weather_icon_root)}"
          all_cells = weather.cell_map.each.to_a
          lines << "Weather Cells: #{all_cells.length}"
          lines << "Dynamic Cells: #{weather.cell_map.dynamic_cells.length}"
          if cell
            lines << "Cell Key: #{cell[:key]}"
            lines << "Cell Label: #{cell[:label]}"
            lines << "Cell Map IDs: #{safe_value(cell[:map_ids])}"
            lines << "Cell Dynamic Map IDs: #{safe_value(cell[:dynamic_map_ids])}"
            lines << "Cell Coordinates: #{safe_value(cell[:coordinates])}"
            lines << "Cell Climate: #{safe_value(cell[:climate])}"
            lines << "Cell Neighbors: #{safe_value(cell[:neighbors])}"
          else
            lines << "Cell: None"
          end
          append_weather_position_cells(lines, all_cells, metadata)
          lines << ""
        rescue StandardError => e
          lines << "Weather diagnostics unavailable: #{sanitized_error(e)}"
          lines << ""
        end

        def append_weather_position_cells(lines, cells, metadata)
          position = metadata && metadata.respond_to?(:town_map_position) ?
            Array(metadata.town_map_position) : []
          if position.length < 3
            lines << "Town Map Position Weather Cells: None"
            return
          end
          normalized = position[0, 3].map { |value| value.to_i }
          matches = Array(cells).select do |cell|
            Array(cell[:coordinates]).any? do |candidate|
              Array(candidate)[0, 3].map { |value| value.to_i } == normalized
            end
          end
          lines << "Town Map Position: #{safe_value(normalized)}"
          lines << "Town Map Position Weather Cells: #{matches.length}"
          matches.each do |cell|
            map_id = weather_map_id_at_position(cell, normalized)
            state = KantoReloaded::WeatherSystem::Simulation.current_for_map(
              map_id
            )
            lines << "- #{cell[:key]} | #{cell[:label]} | " \
                     "Map=#{map_id} | Maps=#{safe_value(cell[:map_ids])} | " \
                     "#{weather_state_description(state)}"
          end
        rescue StandardError => e
          lines << "Town Map weather cells unavailable: #{sanitized_error(e)}"
        end

        def weather_map_id_at_position(cell, position)
          map_id = Array(cell[:map_ids]).find do |candidate|
            metadata = GameData::MapMetadata.try_get(candidate) rescue nil
            map_position = metadata &&
              metadata.respond_to?(:town_map_position) ?
              Array(metadata.town_map_position)[0, 3].map { |value| value.to_i } :
              nil
            map_position == position
          end
          (map_id || Array(cell[:map_ids])[0]).to_i
        rescue StandardError
          Array(cell && cell[:map_ids])[0].to_i
        end

        def weather_state_description(state)
          value = state.is_a?(Hash) ? state : {}
          parts = [
            "Weather=#{safe_value(value[:weather])}",
            "Intensity=#{safe_value(value[:intensity])}",
            "Trend=#{safe_value(value[:trend])}",
            "Authored=#{safe_value(value[:authored])}"
          ]
          parts << "AuthoredWeather=#{safe_value(value[:authored_weather])}" if
            value.has_key?(:authored_weather)
          parts << "Chance=#{safe_value(value[:chance])}" if
            value.has_key?(:chance)
          parts << "Live=#{safe_value(value[:live])}" if
            value.has_key?(:live)
          parts.join(" | ")
        rescue StandardError
          "Unavailable"
        end

        def screen_weather_description
          return "Unavailable" unless defined?($game_screen) && $game_screen
          type = $game_screen.respond_to?(:weather_type) ?
            $game_screen.weather_type :
            $game_screen.instance_variable_get(:@weather_type)
          power = if $game_screen.respond_to?(:weather_max)
                    $game_screen.weather_max
                  else
                    $game_screen.instance_variable_get(:@weather_max)
                  end
          "Weather=#{safe_value(type)} | Power=#{safe_value(power)}"
        rescue StandardError
          "Unavailable"
        end

        def append_wild_link(lines)
          lines << "[WILD LINK ELIGIBILITY]"
          available = EncounterPools.available_methods
          lines << "Available Methods: #{method_names(available)}"
          METHOD_LABELS.each_key do |method_id|
            row = available.find { |entry| entry[:id] == method_id }
            if row
              types = Array(row[:encounter_types]).map { |id| id.to_s }
              count = EncounterPools.entries_for(row).length
              lines << "#{WildLink.method_label(method_id)}: Available | " \
                       "Sources=#{types.join(', ')} | Entries=#{count}"
            else
              lines << "#{WildLink.method_label(method_id)}: Unavailable"
            end
          end
          smash_events = matching_events(/smashrock/i)
          headbutt_events = matching_events(/headbutttree/i)
          lines << "SmashRock Events: #{smash_events.length}"
          lines << "HeadbuttTree Events: #{headbutt_events.length}"
          lines << "Authored RockSmash Table: #{encounter_type_present?(:RockSmash)}"
          rock_source = if encounter_type_present?(:RockSmash)
                          "Authored RockSmash"
                        elsif smash_events.empty?
                          "Generic fallback unavailable without a SmashRock event"
                        else
                          "Generic Geodude fallback"
                        end
          lines << "Rock Smash Source: #{rock_source}"
          if defined?(Runtime)
            lines << "Active Target: #{Runtime.active?}"
            lines << "Active Chain: #{Runtime.chain_active?}"
          end
          lines << ""
        rescue StandardError => e
          lines << "Wild Link eligibility unavailable: #{sanitized_error(e)}"
          lines << ""
        end

        def append_field_tools(lines)
          lines << "[FIELD TOOLS]"
          EncounterPools::ROD_TYPES.each do |_encounter_type, item|
            lines << "#{item}: #{bag_quantity(item)}"
          end
          lines << "SURFBOARD: #{bag_quantity(:SURFBOARD)}"
          if defined?(::Settings::BADGE_FOR_SURF)
            lines << "Surf Badge Requirement: #{::Settings::BADGE_FOR_SURF}"
          end
          lines << ""
        rescue StandardError => e
          lines << "Field tool data unavailable: #{sanitized_error(e)}"
          lines << ""
        end

        def append_terrain(lines)
          lines << "[TERRAIN]"
          counts = Hash.new(0)
          surf_tiles = 0
          fishing_tiles = 0
          encounter_tiles = 0
          $game_map.height.times do |y|
            $game_map.width.times do |x|
              tag = $game_map.terrain_tag(x, y)
              counts[terrain_id(tag)] += 1
              surf_tiles += 1 if tag && tag.respond_to?(:can_surf_freely) &&
                                 tag.can_surf_freely
              fishing_tiles += 1 if tag && tag.respond_to?(:can_fish) &&
                                    tag.can_fish
              encounter_tiles += 1 if tag &&
                                      tag.respond_to?(:land_wild_encounters) &&
                                      tag.land_wild_encounters
            rescue StandardError
              counts["Unreadable"] += 1
            end
          end
          lines << "Surfable Tiles: #{surf_tiles}"
          lines << "Fishable Tiles: #{fishing_tiles}"
          lines << "Land Encounter Tiles: #{encounter_tiles}"
          lines << "Terrain Tag Counts:"
          counts.keys.sort_by { |key| key.to_s }.each do |key|
            lines << "- #{key}: #{counts[key]}"
          end
          lines << ""
        rescue StandardError => e
          lines << "Terrain scan unavailable: #{sanitized_error(e)}"
          lines << ""
        end

        def append_events(lines)
          lines << "[MAP EVENTS]"
          events = map_events.sort_by { |event| event.id.to_i }
          if events.empty?
            lines << "No map events."
          else
            events.each do |event|
              distance = player_distance(event)
              lines << "- ID=#{event.id} | Name=#{safe_value(event.name)} | " \
                       "Position=#{event.x},#{event.y} | Distance=#{distance} | " \
                       "Erased=#{event_erased?(event)} | Through=#{event_through?(event)}"
            end
          end
          lines << ""
        rescue StandardError => e
          lines << "Map events unavailable: #{sanitized_error(e)}"
          lines << ""
        end

        def append_encounters(lines)
          lines << "[ENCOUNTER TABLES]"
          unless defined?($PokemonEncounters) && $PokemonEncounters
            lines << "Current encounter manager unavailable."
            lines << ""
            return
          end
          found = 0
          GameData::EncounterType.each do |encounter_type|
            next unless encounter_type_present?(encounter_type.id)
            found += 1
            table = Array(
              $PokemonEncounters.listPossibleEncounters(encounter_type.id)
            )
            lines << "#{encounter_type.id} | Kind=#{encounter_type.type} | " \
                     "Entries=#{table.length}"
            table.each do |record|
              lines << encounter_record_line(record)
            end
          rescue StandardError => e
            lines << "#{encounter_type.id}: #{sanitized_error(e)}"
          end
          lines << "No active encounter tables." if found == 0
          lines << ""
        rescue StandardError => e
          lines << "Encounter tables unavailable: #{sanitized_error(e)}"
          lines << ""
        end

        def encounter_record_line(record)
          return "- Invalid record: #{safe_value(record)}" unless record.is_a?(Array)
          weight = record[0].to_i
          species = record[1]
          minimum = record[2].to_i
          maximum = (record[3] || record[2]).to_i
          "- Weight=#{weight} | Species=#{species_label(species)} | " \
            "Levels=#{minimum}-#{maximum}"
        rescue StandardError
          "- Invalid record"
        end

        def encounter_type_present?(encounter_type)
          defined?($PokemonEncounters) && $PokemonEncounters &&
            $PokemonEncounters.has_encounter_type?(encounter_type)
        rescue StandardError
          false
        end

        def method_names(rows)
          names = Array(rows).map { |row| WildLink.method_label(row[:id]) }
          names.empty? ? "None" : names.join(", ")
        end

        def species_label(species)
          data = GameData::Species.get(species)
          "#{data.id} (#{data.name})"
        rescue StandardError
          safe_value(species)
        end

        def safe_map_name
          return $game_map.name.to_s if $game_map.respond_to?(:name)
          "Unknown"
        rescue StandardError
          "Unknown"
        end

        def loaded_map_ids
          return [] unless defined?($MapFactory) && $MapFactory &&
                           $MapFactory.respond_to?(:maps)
          Array($MapFactory.maps).map do |map|
            map.respond_to?(:map_id) ? map.map_id.to_i : nil
          end.compact.uniq.sort
        rescue StandardError
          []
        end

        def map_events
          return [] unless $game_map.respond_to?(:events)
          $game_map.events.values.compact
        rescue StandardError
          []
        end

        def matching_events(pattern)
          map_events.select { |event| event.name.to_s.match?(pattern) }
        rescue StandardError
          []
        end

        def player_distance(event)
          return "Unknown" unless defined?($game_player) && $game_player
          (event.x.to_i - $game_player.x.to_i).abs +
            (event.y.to_i - $game_player.y.to_i).abs
        rescue StandardError
          "Unknown"
        end

        def event_erased?(event)
          return event.erased if event.respond_to?(:erased)
          !!event.instance_variable_get(:@erased)
        rescue StandardError
          false
        end

        def event_through?(event)
          return event.through if event.respond_to?(:through)
          !!event.instance_variable_get(:@through)
        rescue StandardError
          false
        end

        def current_terrain
          return nil unless defined?($game_player) && $game_player
          return $game_player.terrain_tag if $game_player.respond_to?(:terrain_tag)
          $game_map.terrain_tag($game_player.x, $game_player.y)
        rescue StandardError
          nil
        end

        def facing_terrain
          return nil unless defined?($game_player) && $game_player
          return $game_player.pbFacingTerrainTag if
            $game_player.respond_to?(:pbFacingTerrainTag)
          nil
        rescue StandardError
          nil
        end

        def terrain_description(tag)
          return "Unavailable" unless tag
          flags = []
          flags << "Surf" if tag.respond_to?(:can_surf_freely) &&
                             tag.can_surf_freely
          flags << "Fish" if tag.respond_to?(:can_fish) && tag.can_fish
          flags << "LandEncounters" if tag.respond_to?(:land_wild_encounters) &&
                                       tag.land_wild_encounters
          suffix = flags.empty? ? "" : " [#{flags.join(', ')}]"
          "#{terrain_id(tag)}#{suffix}"
        rescue StandardError
          "Unavailable"
        end

        def terrain_id(tag)
          return tag.id.to_s if tag.respond_to?(:id)
          tag.to_s
        rescue StandardError
          "Unknown"
        end

        def bag_quantity(item)
          return 0 unless defined?($PokemonBag) && $PokemonBag
          return $PokemonBag.pbQuantity(item).to_i if
            $PokemonBag.respond_to?(:pbQuantity)
          return($PokemonBag.pbHasItem?(item) ? 1 : 0) if
            $PokemonBag.respond_to?(:pbHasItem?)
          0
        rescue StandardError
          0
        end

        def global_flag(name)
          return false unless defined?($PokemonGlobal) && $PokemonGlobal
          return false unless $PokemonGlobal.respond_to?(name)
          !!$PokemonGlobal.__send__(name)
        rescue StandardError
          false
        end

        def safe_value(value, depth = 0)
          return "..." if depth >= 3
          case value
          when NilClass
            "nil"
          when TrueClass, FalseClass, Numeric, Symbol
            value.inspect
          when String
            value
          when Array
            "[" + value.map { |entry| safe_value(entry, depth + 1) }.join(", ") + "]"
          when Hash
            pairs = value.keys.sort_by { |key| key.to_s }.map do |key|
              "#{safe_value(key, depth + 1)}=>#{safe_value(value[key], depth + 1)}"
            end
            "{" + pairs.join(", ") + "}"
          else
            value.to_s
          end
        rescue StandardError
          value.class.to_s
        end

        def kif_version
          return ::Settings::GAME_VERSION_NUMBER.to_s if
            defined?(::Settings::GAME_VERSION_NUMBER)
          return ::Settings::GAME_VERSION.to_s if
            defined?(::Settings::GAME_VERSION)
          return ::Settings::IF_VERSION.to_s if
            defined?(::Settings::IF_VERSION)
          "unknown"
        rescue StandardError
          "unknown"
        end

        def platform_label
          return KantoReloaded::Platform.label.to_s if
            defined?(KantoReloaded::Platform)
          (RUBY_PLATFORM rescue "unknown").to_s
        rescue StandardError
          "Other"
        end

        def sanitized_error(error)
          KantoReloaded::Log.sanitize("#{error.class}: #{error.message}")
        rescue StandardError
          "Unknown error"
        end
      end
    end
  end
end
