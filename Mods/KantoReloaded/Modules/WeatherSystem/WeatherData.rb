#==============================================================================
# Kanto Reloaded - Weather System Data
#==============================================================================

module KantoReloaded
  module WeatherSystem
    MODULE_ID = :weather_system
    SETTINGS_ACTION = :weather_system_settings
    ENABLED_SETTING = :"weather_system.enabled"
    INTERVAL_SETTING = :"weather_system.interval"
    SELECTION_SETTING = :"weather_system.selection"
    BATTLE_SETTING = :"weather_system.battle_weather"
    ALERTS_SETTING = :"weather_system.alerts"
    AUDIO_SETTING = :"weather_system.custom_audio"
    RAIN_AUDIO_SETTING = :"weather_system.rain_audio"
    THUNDER_AUDIO_SETTING = :"weather_system.thunder_audio"
    LEGACY_RAIN_VOLUME_SETTING = :"weather_system.audio_volume"
    LEGACY_THUNDER_VOLUME_SETTING = :"weather_system.thunder_volume"
    FORECAST_VIEW_SETTING = :forecast_view
    SAVE_RESTORE_UPDATE_DELAY = 12

    INTERVAL_HOURS = [3, 6, 12, 24].freeze
    WEATHER_SELECTION_MODES = [:climate, :random].freeze
    WEATHER_TYPES = [
      :None, :Rain, :Storm, :Sunny, :Fog, :Snow, :Blizzard,
      :Sandstorm, :HeavyRain, :StrongWinds
    ].freeze
    RANDOM_WEATHER_TYPES = [
      :Rain, :Storm, :Sunny, :Fog, :Snow, :Sandstorm
    ].freeze

    WEATHER_NAMES = {
      :None => "Clear",
      :Rain => "Rain",
      :Storm => "Storm",
      :Sunny => "Sunny",
      :Fog => "Fog",
      :Snow => "Snow",
      :Blizzard => "Blizzard",
      :Sandstorm => "Sandstorm",
      :HeavyRain => "Heavy Rain",
      :StrongWinds => "Strong Winds"
    }.freeze

    BATTLE_WEATHER_BY_CATEGORY = {
      :Rain => :Rain,
      :Hail => :Hail,
      :Sandstorm => :Sandstorm,
      :Sun => :Sun,
      :StrongWinds => :StrongWinds
    }.freeze

    CLIMATE_WEIGHTS = {
      :temperate => {
        :Rain => 45, :Sunny => 25, :Fog => 20, :Storm => 10
      },
      :coastal => {
        :Rain => 45, :Fog => 20, :Storm => 20, :Sunny => 15
      },
      :mountain => {
        :Snow => 30, :Rain => 25, :Fog => 25, :Storm => 15, :Sunny => 5
      },
      :cold => {
        :Snow => 60, :Fog => 20, :Rain => 10, :Sunny => 10
      },
      :arid => {
        :Sunny => 55, :Sandstorm => 30, :Rain => 10, :Fog => 5
      }
    }.freeze

    CLIMATE_NAMES = {
      :temperate => "Temperate",
      :coastal => "Coastal",
      :mountain => "Mountain",
      :cold => "Cold",
      :arid => "Arid"
    }.freeze
    WEATHER_ICON_PARTS = [
      "Graphics", "Pictures", "Weather"
    ].freeze

    # These groups are intentionally data-only. Add split outdoor maps here
    # only when their direct connections and names cannot identify them.
    EXPLICIT_CELL_GROUPS = [].freeze

    # Map-specific exceptions belong here instead of in simulation logic.
    # Supported keys:
    #   :eligible   - include or exclude the map from dynamic weather
    #   :cell_group - merge maps carrying the same group token into one cell
    #   :climate    - one of the keys in CLIMATE_WEIGHTS
    #   :label      - forecast label for the resulting cell
    MAP_OVERRIDES = {
      # 123 => { :eligible => true, :climate => :coastal,
      #          :cell_group => :example_route, :label => "Example Route" }
    }.freeze

    COLD_NAME_TOKENS = [
      "ice", "icy", "snow", "frost", "frozen", "glacier", "seafloor cavern"
    ].freeze
    ARID_NAME_TOKENS = [
      "desert", "canyon", "badlands", "dunes", "volcano", "volcanic"
    ].freeze
    MOUNTAIN_NAME_TOKENS = [
      "mount", "mt.", "mountain", "peak", "summit", "rock tunnel",
      "victory road", "cliff", "cave"
    ].freeze
    COASTAL_NAME_TOKENS = [
      "island", "sea", "ocean", "beach", "coast", "shore", "cape",
      "port", "harbor", "harbour", "cove", "bay"
    ].freeze

    # Explicit outdoor-map classifications keep the regional mix varied while
    # preserving Kanto and Johto's predominantly temperate geography.
    CLIMATE_LABEL_OVERRIDES = {
      :cold => [
        "mahoganytown", "route43", "route44", "blackthorncity",
        "mtsilver", "mtsilversummit", "seafoamislandsold"
      ],
      :arid => [
        "route9", "route10", "cinnabarisland", "kindleroad"
      ],
      :mountain => [
        "route3", "route4", "route26", "route27", "route33", "route42",
        "route46"
      ]
    }.freeze

    class CellMap
      attr_reader :cells

      def initialize
        @cells = {}
        @map_to_cell = {}
        @mixed_outdoor_names = nil
        @built = false
      end

      def build!
        return self if @built
        metadata = outdoor_metadata
        parents = {}
        metadata.each_key { |map_id| parents[map_id] = map_id }
        merge_matching_connections(metadata, parents)
        merge_explicit_groups(metadata, parents)
        merge_override_groups(metadata, parents)
        grouped = {}
        metadata.each_key do |map_id|
          root = find_parent(parents, map_id)
          grouped[root] ||= []
          grouped[root] << map_id
        end
        grouped.each_value { |map_ids| add_cell(map_ids, metadata) }
        add_adjacency(metadata)
        @built = true
        self
      rescue StandardError => e
        WeatherSystem.log_exception("Weather cell map build failed", e)
        @built = true
        self
      end

      def rebuild!
        @cells.clear
        @map_to_cell.clear
        @mixed_outdoor_names = nil
        @built = false
        build!
      end

      def cell_for_map(map_id)
        build!
        key = @map_to_cell[map_id.to_i]
        key ? @cells[key] : nil
      end

      def cell(key)
        build!
        @cells[key.to_s]
      end

      def each
        build!
        return enum_for(:each) unless block_given?
        @cells.values.sort_by { |entry| entry[:sort_key] }.each { |entry| yield entry }
      end

      def keys
        build!
        @cells.keys.sort
      end

      def dynamic_cells
        each.select { |entry| entry[:dynamic] }
      end

      private

      def outdoor_metadata
        result = {}
        metadata_values.each do |entry|
          next unless entry
          map_id = entry.id.to_i
          next unless map_id > 0
          next unless WeatherSystem.weather_map_eligible?(map_id, entry)
          result[map_id] = entry
        end
        result
      end

      def metadata_values
        if defined?(GameData::MapMetadata) &&
           GameData::MapMetadata.respond_to?(:each)
          values = []
          GameData::MapMetadata.each { |entry| values << entry }
          return values
        end
        if defined?(GameData::MapMetadata::DATA)
          return GameData::MapMetadata::DATA.values
        end
        []
      rescue
        []
      end

      def merge_matching_connections(metadata, parents)
        connection_rows.each do |row|
          left = row[0].to_i
          right = row[3].to_i
          next unless metadata[left] && metadata[right]
          next unless normalized_name(left) == normalized_name(right)
          union(parents, left, right)
        end
      end

      def merge_explicit_groups(metadata, parents)
        EXPLICIT_CELL_GROUPS.each do |group|
          ids = Array(group).map(&:to_i).select { |map_id| metadata[map_id] }
          next if ids.length < 2
          ids[1..-1].each { |map_id| union(parents, ids[0], map_id) }
        end
      end

      def merge_override_groups(metadata, parents)
        groups = {}
        metadata.each_key do |map_id|
          token = WeatherSystem.map_override(map_id)[:cell_group]
          next if token.nil? || token.to_s.empty?
          groups[token.to_s] ||= []
          groups[token.to_s] << map_id
        end
        groups.each_value do |ids|
          ids.sort!
          next if ids.length < 2
          ids[1..-1].each { |map_id| union(parents, ids[0], map_id) }
        end
      end

      def add_cell(map_ids, metadata)
        ids = map_ids.sort
        key = "cell:#{ids[0]}"
        names = ids.map { |map_id| map_name(map_id) }.reject(&:empty?).uniq
        label_override = ids.map do |map_id|
          WeatherSystem.map_override(map_id)[:label]
        end.compact.find { |value| !value.to_s.empty? }
        label = label_override.to_s
        label = names[0] || "Map #{ids[0]}" if label.empty?
        label = clean_forecast_label(label)
        label = "#{label} (Outdoor)" if mixed_outdoor_name?(ids[0])
        coordinates = ids.map do |map_id|
          position = metadata[map_id].town_map_position rescue nil
          normalize_position(position)
        end.compact.uniq
        authored = ids.map do |map_id|
          weather = metadata[map_id].weather rescue nil
          if weather && WeatherSystem.reserved_authored_weather?(weather)
            [map_id, weather]
          end
        end.compact
        dynamic_ids = ids.reject { |map_id| authored.any? { |pair| pair[0] == map_id } }
        climate_override = ids.map do |map_id|
          WeatherSystem.map_override(map_id)[:climate]
        end.compact.find do |value|
          CLIMATE_WEIGHTS.has_key?(value.to_sym) rescue false
        end
        climate = climate_override ? climate_override.to_sym :
          climate_for(label, metadata[ids[0]])
        cell = {
          :key => key,
          :map_ids => ids,
          :dynamic_map_ids => dynamic_ids,
          :authored_weather => authored,
          :dynamic => !dynamic_ids.empty?,
          :label => label,
          :climate => climate,
          :coordinates => coordinates,
          :position => coordinates[0],
          :neighbors => [],
          :sort_key => [position_region(coordinates[0]), position_y(coordinates[0]),
                        position_x(coordinates[0]), label, ids[0]]
        }
        @cells[key] = cell
        ids.each { |map_id| @map_to_cell[map_id] = key }
      end

      def add_adjacency(metadata)
        connection_rows.each do |row|
          connect_cells(@map_to_cell[row[0].to_i], @map_to_cell[row[3].to_i])
        end
        values = @cells.values
        values.each_with_index do |left, index|
          values[(index + 1)..-1].to_a.each do |right|
            next unless geographically_adjacent?(left, right)
            connect_cells(left[:key], right[:key])
          end
        end
        @cells.each_value { |cell| cell[:neighbors].sort! }
      end

      def geographically_adjacent?(left, right)
        Array(left[:coordinates]).any? do |a|
          Array(right[:coordinates]).any? do |b|
            next false unless a[0] == b[0]
            ((a[1] - b[1]).abs + (a[2] - b[2]).abs) == 1
          end
        end
      end

      def connect_cells(left_key, right_key)
        return if !left_key || !right_key || left_key == right_key
        left = @cells[left_key]
        right = @cells[right_key]
        return unless left && right
        left[:neighbors] << right_key unless left[:neighbors].include?(right_key)
        right[:neighbors] << left_key unless right[:neighbors].include?(left_key)
      end

      def connection_rows
        return [] unless defined?(MapFactoryHelper) &&
                         MapFactoryHelper.respond_to?(:getMapConnections)
        data = MapFactoryHelper.getMapConnections
        rows = []
        lists = data.is_a?(Hash) ? data.values : Array(data)
        lists.each do |list|
          next unless list
          if connection_row?(list)
            rows << list
          else
            Array(list).each do |row|
              rows << row if connection_row?(row)
            end
          end
        end
        rows.uniq
      rescue
        []
      end

      def connection_row?(row)
        row.is_a?(Array) && row.length >= 6 &&
          !row[0].is_a?(Array) && !row[3].is_a?(Array)
      end

      def climate_for(label, metadata)
        name = label.to_s.downcase
        normalized = name.sub(/\s+\(outdoor\)\z/, "").gsub(/[^a-z0-9]+/, "")
        CLIMATE_LABEL_OVERRIDES.each do |climate, labels|
          return climate if labels.include?(normalized)
        end
        return :cold if includes_any?(name, COLD_NAME_TOKENS)
        return :arid if includes_any?(name, ARID_NAME_TOKENS)
        return :mountain if includes_any?(name, MOUNTAIN_NAME_TOKENS)
        return :coastal if includes_any?(name, COASTAL_NAME_TOKENS)
        environment = metadata.battle_environment rescue nil
        return :mountain if [:Cave, :Rock, :CaveWater].include?(environment)
        return :coastal if [:MovingWater, :StillWater, :Underwater].include?(environment)
        :temperate
      end

      def includes_any?(text, tokens)
        tokens.any? { |token| text.include?(token) }
      end

      def clean_forecast_label(value)
        value.to_s.sub(/\s*-\s*old\z/i, "").strip
      end

      def map_name(map_id)
        info = map_infos[map_id.to_i]
        info ? info.name.to_s.strip : ""
      rescue
        ""
      end

      def normalized_name(map_id)
        map_name(map_id).downcase.gsub(/[^a-z0-9]+/, "")
      end

      def mixed_outdoor_name?(map_id)
        mixed_outdoor_names.include?(normalized_name(map_id))
      rescue
        false
      end

      def mixed_outdoor_names
        return @mixed_outdoor_names if @mixed_outdoor_names
        states = {}
        metadata_values.each do |entry|
          next unless entry
          name = normalized_name(entry.id.to_i)
          next if name.empty?
          states[name] ||= { :outdoor => false, :indoor => false }
          if entry.respond_to?(:outdoor_map) && entry.outdoor_map
            states[name][:outdoor] = true
          else
            states[name][:indoor] = true
          end
        end
        @mixed_outdoor_names = states.select do |_name, state|
          state[:outdoor] && state[:indoor]
        end.keys
      rescue
        @mixed_outdoor_names = []
      end

      def map_infos
        @map_infos ||= defined?(pbLoadMapInfos) ? pbLoadMapInfos : {}
      rescue
        {}
      end

      def normalize_position(position)
        values = Array(position)
        return nil unless values.length >= 3
        [values[0].to_i, values[1].to_i, values[2].to_i]
      end

      def position_region(position)
        position ? position[0].to_i : 99
      end

      def position_x(position)
        position ? position[1].to_i : 999
      end

      def position_y(position)
        position ? position[2].to_i : 999
      end

      def find_parent(parents, value)
        parents[value] = value unless parents.has_key?(value)
        while parents[value] != value
          parents[value] = parents[parents[value]]
          value = parents[value]
        end
        value
      end

      def union(parents, left, right)
        left_root = find_parent(parents, left)
        right_root = find_parent(parents, right)
        return if left_root == right_root
        keep, merge = [left_root, right_root].sort
        parents[merge] = keep
      end
    end

    class << self
      def cell_map
        @cell_map ||= CellMap.new
      end

      def map_override(map_id)
        value = MAP_OVERRIDES[map_id.to_i]
        value.is_a?(Hash) ? value : {}
      rescue
        {}
      end

      def weather_map_eligible?(map_id, metadata = nil)
        override = map_override(map_id)
        return !!override[:eligible] if override.has_key?(:eligible)
        metadata ||= if defined?(GameData::MapMetadata)
                       GameData::MapMetadata.try_get(map_id.to_i)
                     end
        metadata && metadata.respond_to?(:outdoor_map) && !!metadata.outdoor_map
      rescue
        false
      end

      def weather_name(weather)
        WEATHER_NAMES[normalize_weather(weather)] || weather.to_s
      end

      def climate_name(climate)
        CLIMATE_NAMES[climate.to_sym] || climate.to_s.capitalize
      rescue
        climate.to_s
      end

      def normalize_weather(weather)
        value = weather.respond_to?(:to_sym) ? weather.to_sym : :None
        WEATHER_TYPES.include?(value) ? value : :None
      rescue
        :None
      end

      def battle_weather_for(overworld_weather)
        weather = normalize_weather(overworld_weather)
        data = GameData::Weather.try_get(weather) if defined?(GameData::Weather)
        category = data && data.respond_to?(:category) ? data.category : nil
        BATTLE_WEATHER_BY_CATEGORY[category] || :None
      rescue
        :None
      end

      def replaceable_authored_weather?(weather)
        return false unless weather
        data = Array(weather)
        return false if data.length < 2
        data[1].to_i < 100
      rescue
        false
      end

      def reserved_authored_weather?(weather)
        !!weather && !replaceable_authored_weather?(weather)
      rescue
        false
      end

      def icon_path(weather, intensity = 0)
        type = normalize_weather(weather)
        root = weather_icon_root
        case type
        when :Rain
          suffix = intensity.to_i >= 7 ? "heavy" : (intensity.to_i >= 4 ? "medium" : "light")
          "#{root}/mapRain_#{suffix}"
        when :Storm
          suffix = intensity.to_i >= 7 ? "heavy" : (intensity.to_i >= 4 ? "medium" : "light")
          "#{root}/mapStorm_#{suffix}"
        when :Sunny
          suffix = intensity.to_i >= 7 ? "heavy" : (intensity.to_i >= 4 ? "medium" : "light")
          "#{root}/mapSun_#{suffix}"
        when :Fog
          suffix = intensity.to_i >= 7 ? "heavy" : (intensity.to_i >= 4 ? "medium" : "light")
          "#{root}/mapFog_#{suffix}"
        when :Snow then "#{root}/mapSnow"
        when :Blizzard then "#{root}/mapBlizzard"
        when :Sandstorm then "#{root}/mapSand"
        when :HeavyRain then "#{root}/mapHeavyRain"
        when :StrongWinds then "#{root}/mapStrongWinds"
        else "#{root}/mapClear"
        end
      end

      def weather_icon_root
        cached = @weather_icon_root
        return cached if cached && weather_icon_root_valid?(cached)
        candidates = []
        game_root = File.expand_path(".")
        candidates << File.join(
          game_root, "ModDev", "KantoReloaded", *WEATHER_ICON_PARTS
        )
        candidates << File.join(
          game_root, "Mods", "KantoReloaded", *WEATHER_ICON_PARTS
        )
        candidates << File.join(game_root, *WEATHER_ICON_PARTS)
        candidates << File.join(KantoReloaded::ROOT, *WEATHER_ICON_PARTS)
        if defined?(ModManager) && ModManager.respond_to?(:get_mod)
          info = ModManager.get_mod("KantoReloaded") rescue nil
          if info && info.respond_to?(:folder_path)
            candidates << File.join(
              info.folder_path.to_s, *WEATHER_ICON_PARTS
            )
          end
        end
        selected = candidates.find do |path|
          weather_icon_root_valid?(path)
        end
        @weather_icon_root = runtime_asset_path(
          selected || File.join(*WEATHER_ICON_PARTS)
        )
      rescue
        File.join(*WEATHER_ICON_PARTS)
      end

      def weather_icon_root_valid?(path)
        File.file?(File.join(path.to_s, "mapClear.png"))
      rescue
        false
      end

      def runtime_asset_path(path)
        expanded = File.expand_path(path.to_s)
        game_root = File.expand_path(".")
        prefix = game_root + File::SEPARATOR
        return expanded.tr("\\", "/") unless expanded.start_with?(prefix)
        expanded[prefix.length..-1].tr("\\", "/")
      rescue
        path.to_s.tr("\\", "/")
      end

      def log_exception(message, error)
        KantoReloaded::Log.exception(
          message, error, :channel => :weather_system
        ) if defined?(KantoReloaded::Log)
      rescue
        nil
      end
    end
  end
end
