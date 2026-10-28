#==============================================================================
# Kanto Reloaded - Weather Simulation
#==============================================================================

module KantoReloaded
  module WeatherSystem
    module Simulation
      STATE_VERSION = 1
      NEW_FRONT_BASE_CHANCE = 4
      MINIMUM_FRONT_PERCENT = 4
      MINIMUM_FRONT_FLOOR = 3
      MINIMUM_FRONT_CAP = 6
      MAX_CATCH_UP_CYCLES = 64

      class Generator
        attr_reader :seed

        def initialize(seed)
          @seed = seed.to_i & 0x7fffffff
          @seed = 1 if @seed == 0
        end

        def next_int(maximum)
          maximum = maximum.to_i
          return 0 if maximum <= 1
          @seed = ((@seed * 1_103_515_245) + 12_345) & 0x7fffffff
          @seed % maximum
        end

        def chance?(percent)
          next_int(100) < percent.to_i
        end

        def choose(values)
          list = Array(values)
          list.empty? ? nil : list[next_int(list.length)]
        end

        def weighted(weights)
          pairs = weights.to_a.select { |_value, weight| weight.to_i > 0 }
          total = pairs.inject(0) { |sum, pair| sum + pair[1].to_i }
          return nil if total <= 0
          roll = next_int(total)
          pairs.each do |value, weight|
            return value if roll < weight.to_i
            roll -= weight.to_i
          end
          pairs[-1][0]
        end
      end

      class << self
        def ensure_state!
          bucket = storage
          initialize_state(bucket) unless valid_state?(bucket)
          normalize_state!(bucket)
          advance_due_cycles!(bucket) if WeatherSystem.enabled?
          bucket
        rescue StandardError => e
          WeatherSystem.log_exception("Weather state initialization failed", e)
          fallback_state
        end

        def suspend!
          bucket = ensure_state_without_advance
          bucket["paused_at"] = time_now.to_i
          true
        end

        def resume!
          bucket = ensure_state_without_advance
          bucket.delete("paused_at")
          bucket["next_cycle_at"] = time_now.to_i + interval_seconds
          true
        end

        def reschedule!
          bucket = ensure_state_without_advance
          bucket["next_cycle_at"] = time_now.to_i + interval_seconds
          true
        end

        def regenerate!
          initialize_state(storage)
          true
        rescue StandardError => e
          WeatherSystem.log_exception("Weather regeneration failed", e)
          false
        end

        def current_snapshot
          deep_copy(ensure_state!["current"] || {})
        end

        def forecast_snapshot
          deep_copy(ensure_state!["forecast"] || {})
        end

        def current_for_map(map_id)
          state_for_map(map_id, current_snapshot, :current)
        end

        def forecast_for_map(map_id)
          state_for_map(map_id, forecast_snapshot, :forecast)
        end

        def state_for_cell(cell_key, mode = :current, snapshot = nil)
          snapshot ||= mode.to_sym == :forecast ?
            forecast_snapshot : current_snapshot
          normalize_cell_state(snapshot[cell_key.to_s])
        end

        def set_front_for_map!(map_id, weather, intensity = 3)
          bucket = ensure_state_without_advance
          cell = WeatherSystem.cell_map.cell_for_map(map_id)
          return false unless cell
          key = cell[:key].to_s
          type = WeatherSystem.normalize_weather(weather)
          power = type == :None ? 0 : [[intensity.to_i, 1].max, 10].min
          backups = bucket["admin_front_backups"] ||= {}
          unless backups.has_key?(key)
            backups[key] = {
              "current" => deep_copy(bucket["current"][key]),
              "forecast" => deep_copy(bucket["forecast"][key])
            }
          end
          current = serialize_state(
            :weather => type, :intensity => power,
            :trend => :admin, :admin_forced => true
          )
          forecast = serialize_state(
            :weather => type, :intensity => power,
            :trend => :steady, :admin_forced => true
          )
          bucket["current"][key] = current
          bucket["forecast"][key] = forecast
          normalize_state!(bucket)
          true
        rescue StandardError => e
          WeatherSystem.log_exception("Weather front creation failed", e)
          false
        end

        def restore_front_for_map!(map_id)
          bucket = ensure_state_without_advance
          cell = WeatherSystem.cell_map.cell_for_map(map_id)
          return false unless cell
          key = cell[:key].to_s
          backups = bucket["admin_front_backups"]
          return false unless backups.is_a?(Hash) && backups.has_key?(key)
          backup = backups.delete(key)
          restore_snapshot_entry(bucket["current"], key, backup["current"])
          restore_snapshot_entry(bucket["forecast"], key, backup["forecast"])
          bucket.delete("admin_front_backups") if backups.empty?
          normalize_state!(bucket)
          true
        rescue StandardError => e
          WeatherSystem.log_exception("Weather front restoration failed", e)
          false
        end

        def admin_front_for_map?(map_id)
          cell = WeatherSystem.cell_map.cell_for_map(map_id)
          return false unless cell
          state = state_for_cell(cell[:key], :current)
          !!state[:admin_forced]
        rescue
          false
        end

        def next_cycle_at
          ensure_state!["next_cycle_at"].to_i
        end

        def seconds_remaining
          [next_cycle_at - time_now.to_i, 0].max
        end

        def interval_hours
          index = KantoReloaded::Settings.get(INTERVAL_SETTING, 1).to_i
          INTERVAL_HOURS[index] || 6
        rescue
          6
        end

        def interval_seconds
          interval_hours * 60 * 60
        end

        def advance_due_cycles!(bucket = storage)
          now = time_now.to_i
          due = bucket["next_cycle_at"].to_i
          if due <= 0
            bucket["next_cycle_at"] = now + interval_seconds
            return false
          end
          previous_current = deep_copy(bucket["current"] || {})
          cycles = 0
          while now >= bucket["next_cycle_at"].to_i &&
                cycles < MAX_CATCH_UP_CYCLES
            promote_forecast!(bucket)
            bucket["next_cycle_at"] = bucket["next_cycle_at"].to_i + interval_seconds
            cycles += 1
          end
          if now >= bucket["next_cycle_at"].to_i
            bucket["next_cycle_at"] = now + interval_seconds
          end
          WeatherSystem.on_cycle_advanced(cycles, previous_current) if cycles > 0 &&
            WeatherSystem.respond_to?(:on_cycle_advanced)
          cycles > 0
        end

        def format_remaining(seconds = seconds_remaining)
          total = [seconds.to_i, 0].max
          hours = total / 3600
          minutes = (total % 3600) / 60
          return _INTL("{1}h {2}m", hours, minutes) if hours > 0
          _INTL("{1}m", [minutes, 1].max)
        end

        private

        def ensure_state_without_advance
          bucket = storage
          initialize_state(bucket) unless valid_state?(bucket)
          normalize_state!(bucket)
          bucket
        end

        def storage
          if defined?(KantoReloaded::SaveData)
            return KantoReloaded::SaveData.module_data(MODULE_ID)
          end
          @fallback_storage ||= {}
        end

        def fallback_state
          @fallback_storage ||= {}
          initialize_state(@fallback_storage) unless valid_state?(@fallback_storage)
          @fallback_storage
        end

        def valid_state?(bucket)
          bucket.is_a?(Hash) &&
            bucket["version"].to_i == STATE_VERSION &&
            bucket["current"].is_a?(Hash) &&
            bucket["forecast"].is_a?(Hash)
        end

        def initialize_state(bucket)
          bucket.clear
          generator = Generator.new(initial_seed)
          current = generate_snapshot({}, generator)
          forecast = generate_snapshot(current, generator)
          now = time_now.to_i
          bucket["version"] = STATE_VERSION
          bucket["seed"] = generator.seed
          bucket["current"] = current
          bucket["forecast"] = forecast
          bucket["last_cycle_at"] = now
          bucket["next_cycle_at"] = now + interval_seconds
          bucket
        end

        def normalize_state!(bucket)
          cells = WeatherSystem.cell_map.dynamic_cells
          valid_keys = cells.map { |cell| cell[:key] }
          bucket["current"] = normalize_snapshot(bucket["current"], valid_keys)
          bucket["forecast"] = normalize_snapshot(bucket["forecast"], valid_keys)
          bucket["seed"] = initial_seed if bucket["seed"].to_i <= 0
          generator = Generator.new(bucket["seed"])
          repaired = ensure_minimum_fronts(cells, bucket["current"], generator)
          repaired += ensure_minimum_fronts(cells, bucket["forecast"], generator)
          if repaired > 0
            bucket["current"] = normalize_snapshot(bucket["current"], valid_keys)
            bucket["forecast"] = normalize_snapshot(bucket["forecast"], valid_keys)
            bucket["seed"] = generator.seed
          end
          bucket["next_cycle_at"] = time_now.to_i + interval_seconds if
            bucket["next_cycle_at"].to_i <= 0
          bucket
        end

        def normalize_snapshot(snapshot, valid_keys)
          source = snapshot.is_a?(Hash) ? snapshot : {}
          result = {}
          valid_keys.each do |key|
            state = normalize_cell_state(source[key])
            if state[:weather] != :None || state[:admin_forced]
              result[key] = serialize_state(state)
            end
          end
          result
        end

        def promote_forecast!(bucket)
          current = normalize_snapshot(
            bucket["forecast"], WeatherSystem.cell_map.dynamic_cells.map { |cell| cell[:key] }
          )
          generator = Generator.new(bucket["seed"])
          forecast = generate_snapshot(current, generator)
          bucket["current"] = current
          bucket["forecast"] = forecast
          bucket["seed"] = generator.seed
          bucket["last_cycle_at"] = bucket["next_cycle_at"].to_i
        end

        def generate_snapshot(source, generator)
          cells = WeatherSystem.cell_map.dynamic_cells
          current = {}
          cells.each do |cell|
            state = normalize_cell_state(source[cell[:key]])
            current[cell[:key]] = state unless state[:weather] == :None
          end
          result = evolve_existing(cells, current, generator)
          spread_fronts(cells, current, result, generator)
          create_fronts(cells, result, generator)
          ensure_minimum_fronts(cells, result, generator)
          serialized = {}
          result.each do |key, state|
            normalized = normalize_cell_state(state)
            next if normalized[:weather] == :None
            previous = normalize_cell_state(current[key])
            normalized[:trend] = trend_for(previous, normalized)
            serialized[key] = serialize_state(normalized)
          end
          serialized
        end

        def evolve_existing(cells, current, generator)
          result = {}
          cells.each do |cell|
            state = normalize_cell_state(current[cell[:key]])
            next if state[:weather] == :None
            strengthen = 30
            weaken = 30
            climate_weights = CLIMATE_WEIGHTS[cell[:climate]] || {}
            if !WeatherSystem.random_weather_selection? &&
               climate_weights.has_key?(base_weather(state[:weather]))
              strengthen += 6
              weaken -= 6
            end
            matching = Array(cell[:neighbors]).count do |neighbor_key|
              neighbor = normalize_cell_state(current[neighbor_key])
              base_weather(neighbor[:weather]) == base_weather(state[:weather])
            end
            strengthen += [matching * 3, 9].min
            weaken -= [matching, 4].min
            case state[:intensity]
            when 10
              strengthen -= 20
              weaken += 28
            when 9
              strengthen -= 14
              weaken += 20
            when 8
              strengthen -= 8
              weaken += 12
            when 7
              strengthen -= 4
              weaken += 6
            end
            strengthen = [[strengthen, 5].max, 80].min
            weaken = [[weaken, 5].max, 85].min
            steady = [100 - weaken - strengthen, 0].max
            roll = generator.next_int(100)
            delta = if roll < weaken
                      -1
                    elsif roll < weaken + steady
                      0
                    else
                      1
                    end
            intensity = state[:intensity] + delta
            next if intensity < 1
            weather = escalated_weather(state[:weather], intensity, generator)
            weather, intensity = weakened_weather(weather, intensity)
            result[cell[:key]] = {
              :weather => weather,
              :intensity => [[intensity, 1].max, 10].min,
              :trend => :steady
            }
          end
          result
        end

        def spread_fronts(cells, current, result, generator)
          by_key = {}
          cells.each { |cell| by_key[cell[:key]] = cell }
          arrived = {}
          current.keys.sort.each do |source_key|
            next if arrived[source_key] || !result.has_key?(source_key)
            state = normalize_cell_state(result[source_key])
            next if state[:weather] == :None || state[:intensity] < 4
            chance = [10 + state[:intensity] * 5, 65].min
            next unless generator.chance?(chance)
            source_cell = by_key[source_key]
            candidates = Array(source_cell && source_cell[:neighbors]).select do |key|
              by_key[key] && by_key[key][:dynamic]
            end
            target_key = generator.choose(candidates.sort)
            next unless target_key
            target_cell = by_key[target_key]
            incoming = {
              :weather => converted_weather(state[:weather], target_cell[:climate], generator),
              :intensity => [state[:intensity] - 1, 1].max,
              :trend => :moving
            }
            existing = normalize_cell_state(result[target_key])
            result.delete(source_key)
            result[target_key] = collide(existing, incoming, generator)
            arrived[target_key] = true
          end
        end

        def create_fronts(cells, result, generator)
          coverage = cells.empty? ? 0.0 : result.length.to_f / cells.length
          chance = if coverage < 0.20
                     NEW_FRONT_BASE_CHANCE
                   elsif coverage < 0.30
                     2
                   elsif coverage < 0.35
                     1
                   else
                     0
                   end
          return if chance <= 0
          cells.each do |cell|
            next if result[cell[:key]]
            next unless generator.chance?(chance)
            weather = select_weather(cell, generator)
            result[cell[:key]] = {
              :weather => weather || :Rain,
              :intensity => 2 + generator.next_int(3),
              :trend => :building
            }
          end
        end

        def ensure_minimum_fronts(cells, result, generator)
          added = 0
          cells.group_by { |cell| weather_region_for(cell) }.each do |region, group|
            next if region.nil?
            required = minimum_front_count(group.length)
            active = group.count do |cell|
              normalize_cell_state(result[cell[:key]])[:weather] != :None
            end
            missing = required - active
            next if missing <= 0
            available = group.reject do |cell|
              state = normalize_cell_state(result[cell[:key]])
              state[:weather] != :None || state[:admin_forced]
            end
            region_added = 0
            while region_added < missing && !available.empty?
              cell = available.delete_at(generator.next_int(available.length))
              weather = select_weather(cell, generator)
              result[cell[:key]] = {
                :weather => weather || :Rain,
                :intensity => 2 + generator.next_int(3),
                :trend => :building
              }
              region_added += 1
              added += 1
            end
          end
          added
        end

        def weather_region_for(cell)
          position = Array(cell && cell[:coordinates]).find do |candidate|
            Array(candidate).length >= 3
          end
          position ? position[0].to_i : nil
        rescue
          nil
        end

        def minimum_front_count(cell_count)
          count = cell_count.to_i
          return 0 if count <= 0
          percentage = (count * MINIMUM_FRONT_PERCENT / 100.0).ceil
          minimum = [percentage, MINIMUM_FRONT_FLOOR].max
          [[minimum, MINIMUM_FRONT_CAP].min, count].min
        end

        def collide(existing, incoming, generator)
          return incoming if existing[:weather] == :None
          if base_weather(existing[:weather]) == base_weather(incoming[:weather])
            return {
              :weather => stronger_variant(existing[:weather], incoming[:weather]),
              :intensity => [existing[:intensity], incoming[:intensity]].max,
              :trend => :building
            }
          end
          existing_base = base_weather(existing[:weather])
          incoming_base = base_weather(incoming[:weather])
          if [existing_base, incoming_base].include?(:Rain) &&
             [existing_base, incoming_base].include?(:Sunny)
            return {
              :weather => :Fog,
              :intensity => [[existing[:intensity], incoming[:intensity]].max - 1, 1].max,
              :trend => :moving
            }
          end
          if [existing_base, incoming_base].include?(:Rain) &&
             [existing_base, incoming_base].include?(:Storm)
            return {
              :weather => :Storm,
              :intensity => [existing[:intensity], incoming[:intensity]].max,
              :trend => :building
            }
          end
          return incoming if incoming[:intensity] > existing[:intensity]
          return existing if existing[:intensity] > incoming[:intensity]
          generator.chance?(50) ? incoming : existing
        end

        def converted_weather(weather, climate, generator)
          return weather if WeatherSystem.random_weather_selection?
          base = base_weather(weather)
          return :Snow if climate == :cold && base == :Rain
          return :Blizzard if climate == :cold && base == :Storm
          return :Rain if climate != :cold && [:Snow, :Blizzard].include?(weather)
          return :Sunny if weather == :Sandstorm && climate != :arid
          weather
        end

        def select_weather(cell, generator)
          if WeatherSystem.random_weather_selection?
            return generator.choose(RANDOM_WEATHER_TYPES)
          end
          weights = CLIMATE_WEIGHTS[cell[:climate]] || CLIMATE_WEIGHTS[:temperate]
          generator.weighted(weights)
        end

        def escalated_weather(weather, intensity, generator)
          base = base_weather(weather)
          return :HeavyRain if base == :Rain && intensity >= 8
          if base == :Storm && intensity >= 8
            return generator.chance?(50) ? :HeavyRain : :StrongWinds
          end
          return :Blizzard if base == :Snow && intensity >= 8
          weather
        end

        def weakened_weather(weather, intensity)
          return [:Rain, [intensity, 7].min] if weather == :HeavyRain && intensity < 8
          return [:Storm, [intensity, 7].min] if weather == :StrongWinds && intensity < 8
          return [:Snow, [intensity, 7].min] if weather == :Blizzard && intensity < 8
          [weather, intensity]
        end

        def base_weather(weather)
          case weather
          when :HeavyRain then :Rain
          when :StrongWinds then :Storm
          when :Blizzard then :Snow
          else weather
          end
        end

        def stronger_variant(left, right)
          priority = [:None, :Rain, :Snow, :Storm, :Blizzard, :HeavyRain, :StrongWinds]
          priority.index(left).to_i >= priority.index(right).to_i ? left : right
        end

        def trend_for(previous, current)
          return :building if previous[:weather] == :None
          return :moving if base_weather(previous[:weather]) != base_weather(current[:weather])
          return :building if current[:intensity] > previous[:intensity]
          return :weakening if current[:intensity] < previous[:intensity]
          :steady
        end

        def state_for_map(map_id, snapshot, mode)
          cell = WeatherSystem.cell_map.cell_for_map(map_id)
          return clear_state unless cell
          state = normalize_cell_state(snapshot[cell[:key]])
          if state[:admin_forced]
            return state.merge(
              :cell_key => cell[:key],
              :cell => cell,
              :authored => false
            )
          end
          authored = authored_weather_for(cell, map_id, mode)
          return authored if authored
          state.merge(
            :cell_key => cell[:key],
            :cell => cell,
            :authored => false
          )
        end

        def authored_weather_for(cell, map_id, mode)
          pair = Array(cell[:authored_weather]).find { |entry| entry[0].to_i == map_id.to_i }
          return nil unless pair
          return nil unless WeatherSystem.reserved_authored_weather?(pair[1])
          weather_data = Array(pair[1])
          authored_weather = WeatherSystem.normalize_weather(weather_data[0])
          weather = authored_weather
          chance = weather_data[1].to_i
          live = false
          if mode == :current && defined?($game_map) && $game_map &&
             $game_map.map_id.to_i == map_id.to_i && defined?($game_screen) &&
             $game_screen
            weather = WeatherSystem.normalize_weather($game_screen.weather_type)
            live = true
          end
          {
            :weather => weather,
            :intensity => weather == :None ? 0 : 3,
            :trend => :authored,
            :cell_key => cell[:key],
            :cell => cell,
            :authored => true,
            :authored_weather => authored_weather,
            :chance => chance,
            :live => live
          }
        end

        def normalize_cell_state(value)
          data = value.is_a?(Hash) ? value : {}
          weather = WeatherSystem.normalize_weather(data["weather"] || data[:weather])
          intensity = (data["intensity"] || data[:intensity] || 0).to_i
          trend = (data["trend"] || data[:trend] || :steady).to_sym rescue :steady
          admin_forced = data["admin_forced"] == true ||
                         data[:admin_forced] == true
          intensity = 0 if weather == :None
          {
            :weather => weather,
            :intensity => [[intensity, 0].max, 10].min,
            :trend => trend,
            :admin_forced => admin_forced
          }
        end

        def serialize_state(state)
          result = {
            "weather" => state[:weather].to_s,
            "intensity" => state[:intensity].to_i,
            "trend" => state[:trend].to_s
          }
          result["admin_forced"] = true if state[:admin_forced]
          result
        end

        def restore_snapshot_entry(snapshot, key, value)
          if value.nil?
            snapshot.delete(key)
          else
            snapshot[key] = deep_copy(value)
          end
        end

        def clear_state
          { :weather => :None, :intensity => 0, :trend => :steady,
            :cell_key => nil, :cell => nil, :authored => false }
        end

        def initial_seed
          value = time_now.to_i ^ ((defined?(Graphics) ? Graphics.frame_count : 0) rescue 0)
          value &= 0x7fffffff
          value == 0 ? 1 : value
        end

        def time_now
          defined?(pbGetTimeNow) ? pbGetTimeNow : Time.now
        rescue
          Time.now
        end

        def deep_copy(value)
          Marshal.load(Marshal.dump(value))
        rescue
          value.dup rescue value
        end
      end
    end
  end
end
