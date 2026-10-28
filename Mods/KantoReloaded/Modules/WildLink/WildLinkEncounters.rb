#==============================================================================
# Kanto Reloaded - Wild Link Encounter Pools and Bonuses
#==============================================================================

module KantoReloaded
  module WildLink
    module EncounterPools
      ROD_TYPES = [
        [:OldRod, :OLDROD],
        [:GoodRod, :GOODROD],
        [:SuperRod, :SUPERROD]
      ].freeze
      ROCK_SMASH_FALLBACK = :WildLinkRockSmashFallback
      FALLBACK_RARE_CANDIDATE_COUNT = 12
      FALLBACK_RARE_BST_BONUS = 50
      TIME_SUFFIXES = [
        "Morning", "Afternoon", "Evening", "Day", "Night"
      ].freeze

      class << self
        def available_methods
          rows = []
          rows << method_row(:land, encounter_types_for(:land)) if land_available?
          rows << method_row(:cave, encounter_types_for(:cave)) if cave_available?
          rows << method_row(:surf, encounter_types_for(:water)) if surf_available?
          fishing = available_rod_types
          rows << method_row(:fishing, fishing) unless fishing.empty?
          headbutt = [:HeadbuttLow, :HeadbuttHigh].select do |id|
            has_effective_type?(id)
          end
          rows << method_row(:headbutt, headbutt) if !headbutt.empty? && nearby_event?(/headbutttree/i)
          rock = rock_smash_encounter_types
          rows << method_row(:rock_smash, rock) if !rock.empty? && nearby_event?(/smashrock/i)
          rows
        rescue StandardError => e
          WildLink.log_exception("Wild Link method scan failed", e)
          []
        end

        def entries_for(method)
          return [] unless method
          records = encounter_records(Array(method[:encounter_types]))
          entries = merge_records(records)
          add_rare_signal(entries, method) if method[:id] == :land
          entries.sort_by do |entry|
            status = entry[:signal] ? 3 : (WildLink.seen?(entry[:species]) ? 0 : 2)
            [status, entry_name(entry).downcase]
          end
        rescue StandardError => e
          WildLink.log_exception("Wild Link encounter roster failed", e)
          []
        end

        def entry_name(entry)
          return _INTL("Rare Signal") if entry[:signal]
          return _INTL("Unknown Pokemon") unless WildLink.seen?(entry[:species])
          species_name(entry[:species])
        rescue StandardError
          _INTL("Unknown Pokemon")
        end

        def species_name(species)
          number = fusion_number(species)
          return fusion_name(number) if number
          GameData::Species.get(species).name
        rescue StandardError
          _INTL("Unknown Pokemon")
        end

        def choose_target(entry)
          return nil unless entry
          if entry[:signal]
            candidate = weighted_rare_record(Array(entry[:rare_records]))
            return nil unless candidate
            species = rare_record_species(candidate)
            level = random_level(candidate[3], candidate[4] || candidate[3])
            return {
              :species => species,
              :level => level,
              :unknown => !WildLink.seen?(species),
              :rare_signal => true
            }
          end
          record = weighted_record(Array(entry[:records]))
          return nil unless record
          {
            :species => entry[:species],
            :level => random_level(record[2], record[3]),
            :unknown => !WildLink.seen?(entry[:species]),
            :rare_signal => !!entry[:rare]
          }
        rescue StandardError => e
          WildLink.log_exception("Wild Link target choice failed", e)
          nil
        end

        def find_entry(method_id, species)
          method = available_methods.find { |row| row[:id] == method_id.to_sym }
          return nil unless method
          entries_for(method).find do |entry|
            !entry[:signal] && WildLink.species_key(entry[:species]) ==
              WildLink.species_key(species)
          end
        end

        def signal_species(entry)
          return [] unless entry && entry[:signal]
          found = {}
          Array(entry[:rare_records]).each do |record|
            species = rare_record_species(record)
            found[WildLink.species_key(species)] ||= species if species
          end
          found.values
        rescue StandardError
          []
        end

        def standard_seen_for_method?(entries)
          standards = entries.reject do |entry|
            entry[:signal] || entry[:rare]
          end
          !standards.empty? && standards.all? { |entry| WildLink.seen?(entry[:species]) }
        end

        def nearby_named_events(pattern, maximum_distance = nil)
          return [] unless $game_map && $game_player
          $game_map.events.values.select do |event|
            next false unless event && event.name.to_s.match?(pattern)
            next false if event.respond_to?(:erased) && event.erased
            next true unless maximum_distance
            distance = (event.x - $game_player.x).abs + (event.y - $game_player.y).abs
            distance <= maximum_distance
          end
        rescue StandardError
          []
        end

        private

        def method_row(id, encounter_types)
          {
            :id => id,
            :label => WildLink.method_label(id),
            :encounter_types => encounter_types
          }
        end

        def land_available?
          encounter_types_for(:land).any? && !$PokemonGlobal.surfing
        rescue StandardError
          false
        end

        def cave_available?
          encounter_types_for(:cave).any? && !$PokemonGlobal.surfing
        rescue StandardError
          false
        end

        def surf_available?
          return false unless encounter_types_for(:water).any?
          return true if $PokemonGlobal && $PokemonGlobal.surfing
          surf_access?
        rescue StandardError
          false
        end

        def surf_access?
          return true if bag_has?(:SURFBOARD)
          return false unless defined?(::Settings::BADGE_FOR_SURF)
          return false unless hidden_move_badge?(::Settings::BADGE_FOR_SURF)
          return true if defined?($DEBUG) && $DEBUG
          return false unless $Trainer &&
                              $Trainer.respond_to?(:get_pokemon_with_move)
          !!$Trainer.get_pokemon_with_move(:SURF)
        rescue StandardError
          false
        end

        def hidden_move_badge?(badge)
          method_name = :pbCheckHiddenMoveBadge
          return false unless Object.private_method_defined?(method_name) ||
                              Object.method_defined?(method_name)
          !!Object.new.__send__(method_name, badge, false)
        rescue StandardError
          false
        end

        def encounter_types_for(kind)
          return [] unless $PokemonEncounters
          time = current_encounter_time
          bases = all_encounter_types_for(kind).map do |encounter_type|
            base_encounter_type(encounter_type)
          end
          bases.uniq.each_with_object([]) do |base_type, rows|
            resolved = effective_encounter_type_for_time(base_type, time)
            rows << resolved if resolved && !rows.include?(resolved)
          end
        rescue StandardError
          []
        end

        def all_encounter_types_for(kind)
          rows = []
          GameData::EncounterType.each do |encounter_type|
            next unless encounter_type.type == kind
            next if encounter_type.id == :BugContest
            rows << encounter_type.id if has_effective_type?(encounter_type.id)
          end
          rows
        rescue StandardError
          []
        end

        def base_encounter_type(encounter_type)
          id = encounter_type.to_sym
          text = id.to_s
          TIME_SUFFIXES.each do |suffix|
            next unless text.end_with?(suffix)
            base_text = text[0, text.length - suffix.length]
            next if base_text.empty?
            base_id = base_text.to_sym
            return base_id if GameData::EncounterType.exists?(base_id)
          end
          id
        rescue StandardError
          encounter_type
        end

        def effective_encounter_type_for_time(base_type, time)
          if PBDayNight.isDay?(time)
            timed = if PBDayNight.isMorning?(time)
                      "#{base_type}Morning".to_sym
                    elsif PBDayNight.isAfternoon?(time)
                      "#{base_type}Afternoon".to_sym
                    elsif PBDayNight.isEvening?(time)
                      "#{base_type}Evening".to_sym
                    end
            return timed if timed && has_effective_type?(timed)
            day_type = "#{base_type}Day".to_sym
            return day_type if has_effective_type?(day_type)
          else
            night_type = "#{base_type}Night".to_sym
            return night_type if has_effective_type?(night_type)
          end
          has_effective_type?(base_type) ? base_type : nil
        rescue StandardError
          has_effective_type?(base_type) ? base_type : nil
        end

        def current_encounter_time
          method_name = :pbGetTimeNow
          if Object.private_method_defined?(method_name) ||
             Object.method_defined?(method_name)
            return Object.new.__send__(method_name)
          end
          Time.now
        rescue StandardError
          Time.now
        end

        def available_rod_types
          ROD_TYPES.each_with_object([]) do |pair, rows|
            encounter_type, item = pair
            next unless has_effective_type?(encounter_type)
            next unless bag_has?(item)
            rows << encounter_type
          end
        end

        def rock_smash_encounter_types
          return [:RockSmash] if has_effective_type?(:RockSmash)
          [ROCK_SMASH_FALLBACK]
        rescue StandardError
          []
        end

        def bag_has?(item)
          return false unless $PokemonBag
          return $PokemonBag.pbHasItem?(item) if $PokemonBag.respond_to?(:pbHasItem?)
          $PokemonBag.pbQuantity(item).to_i > 0
        rescue StandardError
          false
        end

        def has_type?(encounter_type)
          $PokemonEncounters &&
            $PokemonEncounters.has_encounter_type?(encounter_type)
        rescue StandardError
          false
        end

        def has_effective_type?(encounter_type)
          return true if has_type?(encounter_type)
          return false unless area_mapping_enabled?
          table = randomized_area_table(encounter_type)
          table.is_a?(Array) && !table.empty?
        rescue StandardError
          false
        end

        def nearby_event?(pattern)
          !nearby_named_events(pattern).empty?
        end

        def encounter_records(encounter_types)
          records = []
          encounter_types.each do |encounter_type|
            if encounter_type == ROCK_SMASH_FALLBACK
              species = static_mapped_species(mapped_species(:GEODUDE))
              records << [
                100, species, 5, 14, ROCK_SMASH_FALLBACK
              ] if valid_species_reference?(species)
              next
            end
            table = effective_encounter_table(encounter_type)
            Array(table).each do |record|
              next unless record.is_a?(Array) && record.length >= 4
              species = effective_table_species(record[1])
              next unless valid_species_reference?(species)
              records << [
                record[0].to_i, species, record[2].to_i, record[3].to_i,
                encounter_type
              ]
            end
          end
          records
        end

        def effective_table_species(species)
          static_mapped_species(mapped_species(species))
        end

        def static_mapped_species(source_species)
          species = canonical_species_reference(source_species)
          return nil unless species
          return species unless static_randomization_enabled?
          return species if fusion_number(species)
          return species if $PokemonTemp && $PokemonTemp.pokeradar
          dex_number = getDexNumberForSpecies(species)
          maximum = defined?(::Settings::NB_POKEMON) ?
            ::Settings::NB_POKEMON.to_i : 0
          return species if dex_number.to_i <= 0 ||
                            dex_number.to_i > maximum
          method_name = :getRandomizedTo
          available = Object.private_method_defined?(method_name) ||
                      Object.protected_method_defined?(method_name) ||
                      Object.method_defined?(method_name)
          return species unless available
          mapped = Object.new.__send__(method_name, species)
          canonical_species_reference(mapped) || species
        rescue StandardError => e
          WildLink.log_exception(
            "Wild Link static encounter mapping failed", e
          )
          species || source_species
        end

        def static_randomization_enabled?
          return false unless $game_switches
          return false unless Object.const_defined?(
            :SWITCH_RANDOM_STATIC_ENCOUNTERS
          )
          !!$game_switches[
            Object.const_get(:SWITCH_RANDOM_STATIC_ENCOUNTERS)
          ]
        rescue StandardError
          false
        end

        def effective_encounter_table(encounter_type)
          live_table = live_encounter_table(encounter_type)
          if area_mapping_enabled?
            area_table = randomized_area_table(encounter_type)
            return live_table if area_table_covered_by_live?(
              area_table, live_table
            )
            return area_table unless area_table.nil?
          end
          live_table
        rescue StandardError => e
          WildLink.log_exception(
            "Wild Link effective encounter table failed", e
          )
          []
        end

        def live_encounter_table(encounter_type)
          return [] unless $PokemonEncounters
          Array($PokemonEncounters.listPossibleEncounters(encounter_type))
        rescue StandardError
          []
        end

        def area_table_covered_by_live?(area_table, live_table)
          return false unless area_table.is_a?(Array)
          return Array(live_table).empty? if area_table.empty?
          available = Hash.new(0)
          Array(live_table).each do |record|
            available[encounter_record_key(record)] += 1
          end
          area_table.all? do |record|
            key = encounter_record_key(record)
            next false if available[key] <= 0
            available[key] -= 1
            true
          end
        rescue StandardError
          false
        end

        def encounter_record_key(record)
          return record unless record.is_a?(Array)
          species = GameData::Species.get(record[1]).id
          [record[0].to_f, species, record[2].to_i, record[3].to_i]
        rescue StandardError
          record
        end

        def randomized_area_table(encounter_type)
          return nil unless defined?(GameData::EncounterRandom)
          version = if defined?($PokemonGlobal) && $PokemonGlobal &&
                       $PokemonGlobal.respond_to?(:encounter_version)
                      $PokemonGlobal.encounter_version
                    end
          data = GameData::EncounterRandom.get(
            WildLink.current_map_id, version
          )
          return nil unless data && data.respond_to?(:types)
          data.types[encounter_type]
        rescue StandardError => e
          WildLink.log_exception(
            "Wild Link area encounter table failed", e
          )
          nil
        end

        def merge_records(records)
          merged = {}
          records.each do |record|
            key = WildLink.species_key(record[1])
            merged[key] ||= {
              :species => record[1],
              :weight => 0,
              :min_level => record[2],
              :max_level => record[3],
              :records => []
            }
            entry = merged[key]
            entry[:weight] += record[0].to_i
            entry[:min_level] = [entry[:min_level], record[2]].min
            entry[:max_level] = [entry[:max_level], record[3]].max
            entry[:records] << [record[0], record[1], record[2], record[3], record[4]]
          end
          merged.values
        end

        def add_rare_signal(entries, method)
          map_entries = map_wide_land_entries
          rare = rare_records(map_entries)
          return entries if rare.empty?
          return entries unless standard_seen_for_method?(entries)
          rare.each do |record|
            species = rare_record_species(record)
            next unless WildLink.seen?(species)
            existing = entries.find do |entry|
              WildLink.species_key(entry[:species]) == WildLink.species_key(species)
            end
            if existing
              existing[:rare] = true
              next
            end
            entries << {
              :species => species,
              :weight => record[1].to_i,
              :min_level => record[3].to_i,
              :max_level => (record[4] || record[3]).to_i,
              :records => [[record[1], species, record[3], record[4] || record[3], :RareSignal]],
              :rare => true
            }
          end
          unseen = rare.reject do |record|
            WildLink.seen?(rare_record_species(record))
          end
          return entries if unseen.empty?
          entries << {
            :species => rare_record_species(unseen[0]),
            :signal => true,
            :unlocked => true,
            :rare_records => unseen,
            :min_level => unseen.map { |record| record[3].to_i }.min,
            :max_level => unseen.map { |record| (record[4] || record[3]).to_i }.max
          }
          entries
        end

        def rare_records(entries = [])
          authored = authored_rare_records
          return authored unless authored.empty?
          fallback = fallback_rare_record(entries)
          fallback ? [fallback] : []
        rescue StandardError
          []
        end

        def authored_rare_records
          return [] unless defined?(::Settings::POKE_RADAR_ENCOUNTERS)
          records = Array(::Settings::POKE_RADAR_ENCOUNTERS).select do |record|
            record.is_a?(Array) &&
              record[0].to_i == WildLink.current_map_id &&
              !GameData::Species.try_get(record[2]).nil?
          end
          live_species = live_pokeradar_rare_species
          return records if live_species.empty?
          records.each_with_index.map do |record, index|
            data = GameData::Species.try_get(live_species[index])
            next record unless data
            effective = record.dup
            effective[2] = data.id
            effective
          end
        rescue StandardError
          []
        end

        def live_pokeradar_rare_species
          method_name = :listPokeradarRareEncounters
          available = Object.private_method_defined?(method_name) ||
                      Object.protected_method_defined?(method_name) ||
                      Object.method_defined?(method_name)
          return [] unless available
          Array(Object.new.__send__(method_name)).select do |species|
            !GameData::Species.try_get(species).nil?
          end
        rescue StandardError
          []
        end

        def map_wide_land_entries
          records = encounter_records(all_encounter_types_for(:land))
          merge_records(records)
        rescue StandardError
          []
        end

        def rare_record_species(record)
          canonical_species_reference(record[2])
        rescue StandardError
          nil
        end

        def fallback_rare_record(entries)
          rows = Array(entries).reject { |entry| entry[:signal] || entry[:rare] }
          average = fallback_average_bst(rows)
          return nil unless average
          target_bst = average + FALLBACK_RARE_BST_BONUS
          route_species = {}
          rows.each do |entry|
            route_species[WildLink.species_key(entry[:species])] = true
          end
          candidates = fallback_species_pool.reject do |row|
            route_species[WildLink.species_key(row[0])]
          end
          return nil if candidates.empty?
          candidates.sort_by! { |row| [(row[1] - target_bst).abs, row[2]] }
          count = [FALLBACK_RARE_CANDIDATE_COUNT, candidates.length].min
          candidate = candidates[fallback_rare_seed(rows, target_bst) % count]
          minimum = rows.map { |entry| entry[:min_level].to_i }.
            select { |level| level > 0 }.min || 1
          maximum = rows.map { |entry| entry[:max_level].to_i }.
            select { |level| level > 0 }.max || minimum
          [
            WildLink.current_map_id, 1, candidate[0],
            minimum, [maximum, minimum].max, :wild_link_effective
          ]
        rescue StandardError => e
          WildLink.log_exception("Wild Link fallback rare selection failed", e)
          nil
        end

        def fallback_average_bst(entries)
          total = 0
          weight_total = 0
          Array(entries).each do |entry|
            bst = fallback_species_bst(entry[:species])
            next unless bst
            weight = [entry[:weight].to_i, 1].max
            total += bst * weight
            weight_total += weight
          end
          return nil if weight_total <= 0
          (total.to_f / weight_total).round
        rescue StandardError
          nil
        end

        def fallback_species_pool
          return @fallback_species_pool if @fallback_species_pool
          maximum = if defined?(::Settings::NB_POKEMON)
                      ::Settings::NB_POKEMON.to_i
                    elsif defined?(NB_POKEMON)
                      NB_POKEMON.to_i
                    else
                      0
                    end
          values = []
          1.upto(maximum) do |number|
            data = GameData::Species.try_get(number)
            next unless data
            next if fallback_legendary?(number)
            bst = fallback_species_bst(data.id)
            values << [data.id, bst, number] if bst
          end
          @fallback_species_pool = values.freeze
        rescue StandardError => e
          WildLink.log_exception("Wild Link fallback rare pool failed", e)
          @fallback_species_pool = [].freeze
        end

        def fallback_species_bst(species)
          @fallback_species_bst ||= {}
          key = WildLink.species_key(species)
          return @fallback_species_bst[key] if
            @fallback_species_bst.has_key?(key)
          number = fusion_number(species)
          if number
            @fallback_species_bst[key] = fusion_bst(number)
            return @fallback_species_bst[key]
          end
          stats = GameData::Species.get(species).base_stats
          total = [
            :HP, :ATTACK, :DEFENSE,
            :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED
          ].inject(0) { |sum, stat| sum + stats[stat].to_i }
          @fallback_species_bst[key] = total > 0 ? total : nil
        rescue StandardError
          @fallback_species_bst[key] = nil if key
          nil
        end

        def fusion_bst(number)
          body_number = getBodyID(number)
          head_number = getHeadID(number, body_number)
          body = GameData::Species.get(body_number).base_stats
          head = GameData::Species.get(head_number).base_stats
          head_dominant = [:HP, :SPECIAL_ATTACK, :SPECIAL_DEFENSE]
          body_dominant = [:ATTACK, :DEFENSE, :SPEED]
          total = 0
          head_dominant.each do |stat|
            total += fused_stat(head[stat], body[stat])
          end
          body_dominant.each do |stat|
            total += fused_stat(body[stat], head[stat])
          end
          total
        rescue StandardError
          nil
        end

        def fused_stat(dominant, other)
          ((2 * dominant.to_i) / 3) + (other.to_i / 3).floor
        end

        def fallback_legendary?(species)
          @fallback_legendary ||= {}
          data = GameData::Species.get(species)
          number = data.id_number.to_i
          return @fallback_legendary[number] if
            @fallback_legendary.has_key?(number)
          @fallback_legendary[number] =
            fallback_legendary_species.has_key?(data.id)
        rescue StandardError
          @fallback_legendary[number] = false if number
          false
        end

        def fallback_legendary_species
          return @fallback_legendary_species if @fallback_legendary_species
          values = {}
          source = defined?(::LEGENDARIES_LIST) ? ::LEGENDARIES_LIST : []
          Array(source).each do |species|
            data = GameData::Species.try_get(species)
            values[data.id] = true if data
          end
          @fallback_legendary_species = values.freeze
        rescue StandardError
          @fallback_legendary_species = {}.freeze
        end

        def fallback_rare_seed(entries, average)
          value = 2_166_136_261
          source = [
            WildLink.current_map_id,
            average,
            Array(entries).map do |entry|
              WildLink.species_key(entry[:species])
            end.sort.join(",")
          ].join("|")
          source.each_byte do |byte|
            value = ((value ^ byte) * 16_777_619) & 0xFFFFFFFF
          end
          value
        rescue StandardError
          WildLink.current_map_id.to_i
        end

        def mapped_species(species)
          id = canonical_species_reference(species)
          return nil unless id
          return id unless global_mapping_enabled?
          receiver = Object.new
          mapped = receiver.__send__(:getRandomizedTo, id)
          canonical_species_reference(mapped) || id
        rescue StandardError
          id || species
        end

        def canonical_species_reference(species)
          return nil if species.nil?
          number = fusion_number(species)
          return number if number
          data = GameData::Species.try_get(species)
          data && data.id
        rescue StandardError
          nil
        end

        def valid_species_reference?(species)
          return false if species.nil?
          number = fusion_number(species)
          if number
            body_number = getBodyID(number)
            head_number = getHeadID(number, body_number)
            return false if body_number <= 0 || head_number <= 0
            return !GameData::Species.try_get(body_number).nil? &&
                   !GameData::Species.try_get(head_number).nil?
          end
          !GameData::Species.try_get(species).nil?
        rescue StandardError
          false
        end

        def fusion_number(species)
          maximum = defined?(::Settings::NB_POKEMON) ?
            ::Settings::NB_POKEMON.to_i : 0
          return nil if maximum <= 0
          if species.is_a?(Integer)
            return nil if species <= maximum
            return nil if isTripleFusion?(species)
            return species
          end
          match = species.to_s.match(/\AB(\d+)H(\d+)\z/)
          return nil unless match
          (match[1].to_i * maximum) + match[2].to_i
        rescue StandardError
          nil
        end

        def fusion_name(number)
          body_number = getBodyID(number)
          head_number = getHeadID(number, body_number)
          mapping = defined?(GameData::NAT_DEX_MAPPING) ?
            GameData::NAT_DEX_MAPPING : {}
          split_names = defined?(GameData::SPLIT_NAMES) ?
            GameData::SPLIT_NAMES : {}
          body_dex = mapping[body_number] || body_number
          head_dex = mapping[head_number] || head_number
          prefix = Array(split_names[head_dex])[0]
          suffix = Array(split_names[body_dex])[1]
          if prefix && suffix
            prefix = prefix[0...-1] if prefix[-1] == suffix[0]
            return prefix + suffix
          end
          head = GameData::Species.get(head_number).name
          body = GameData::Species.get(body_number).name
          "#{head}/#{body}"
        rescue StandardError
          _INTL("Unknown Pokemon")
        end

        def global_mapping_enabled?
          return false unless base_randomization_enabled?
          return false if area_mapping_enabled?
          if Object.const_defined?(:SWITCH_WILD_RANDOM_GLOBAL)
            return false unless $game_switches[
              Object.const_get(:SWITCH_WILD_RANDOM_GLOBAL)
            ]
          end
          Object.private_method_defined?(:getRandomizedTo) ||
            Object.method_defined?(:getRandomizedTo)
        rescue StandardError
          false
        end

        def area_mapping_enabled?
          return false unless base_randomization_enabled?
          return false unless Object.const_defined?(:SWITCH_RANDOM_WILD_AREA)
          !!$game_switches[Object.const_get(:SWITCH_RANDOM_WILD_AREA)]
        rescue StandardError
          false
        end

        def base_randomization_enabled?
          return false unless $game_switches
          return false unless Object.const_defined?(:SWITCH_RANDOM_WILD)
          !!$game_switches[Object.const_get(:SWITCH_RANDOM_WILD)]
        rescue StandardError
          false
        end

        def weighted_record(records)
          rows = records.compact
          return nil if rows.empty?
          total = rows.inject(0) { |sum, row| sum + [row[0].to_i, 1].max }
          roll = rand(total)
          rows.each do |row|
            roll -= [row[0].to_i, 1].max
            return row if roll < 0
          end
          rows[-1]
        end

        def weighted_rare_record(records)
          rows = records.compact
          return nil if rows.empty?
          total = rows.inject(0) { |sum, row| sum + [row[1].to_i, 1].max }
          roll = rand(total)
          rows.each do |row|
            roll -= [row[1].to_i, 1].max
            return row if roll < 0
          end
          rows[-1]
        end

        def random_level(minimum, maximum)
          low = [minimum.to_i, 1].max
          high = [maximum.to_i, low].max
          rand(low..high)
        end
      end
    end

    module Bonuses
      STATS = [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK,
               :SPECIAL_DEFENSE, :SPEED].freeze

      class << self
        def build(entry, method_id)
          choice = EncounterPools.choose_target(entry)
          return nil unless choice
          species = choice[:species]
          search_level = WildLink.search_level(species)
          chain = WildLink.chain_for(species, method_id)
          level = boosted_level(choice[:level], search_level)
          pokemon = global_call(:pbGenerateWildPokemon, species, level)
          return nil unless pokemon
          temperament = temperament_for(species)
          apply_shiny_rolls(pokemon, search_level, chain)
          apply_perfect_ivs(pokemon, search_level, chain)
          apply_hidden_ability(pokemon, search_level, chain)
          egg_moves = apply_egg_moves(pokemon, search_level, chain)
          apply_held_item(pokemon, search_level, chain)
          pokemon.calc_stats if pokemon.respond_to?(:calc_stats)
          pokemon.instance_variable_set(:@wild_link_egg_moves, egg_moves)
          pokemon.instance_variable_set(:@wild_link_temperament, temperament)
          choice.merge(
            :pokemon => pokemon,
            :level => pokemon.level,
            :search_level => search_level,
            :chain => chain,
            :temperament => temperament,
            :egg_moves => egg_moves
          )
        rescue StandardError => e
          WildLink.log_exception("Wild Link Pokemon generation failed", e)
          nil
        end

        def temperament_for(species)
          data = GameData::Species.get(species)
          stats = data.base_stats
          attack = [stats[:ATTACK].to_i, stats[:SPECIAL_ATTACK].to_i].max
          defense = [stats[:DEFENSE].to_i, stats[:SPECIAL_DEFENSE].to_i].max
          speed = stats[:SPEED].to_i
          choices = [:calm, :curious]
          choices.concat([:aggressive, :territorial]) if attack >= defense
          choices.concat([:territorial, :calm]) if defense > attack
          choices.concat([:skittish, :elusive]) if speed >= 80
          choices[data.id_number.to_i % choices.length]
        rescue StandardError
          :calm
        end

        def temperament_label(value)
          value.to_s.split("_").map { |part| part.capitalize }.join(" ")
        end

        def perfect_iv_count(pokemon)
          STATS.count { |stat| pokemon.iv[stat].to_i >= 31 }
        rescue StandardError
          0
        end

        def bonus_preview(search_level, chain, species = nil)
          level = search_level.to_i
          chain_value = chain.to_i
          level_range = level_bonus_range(level)
          availability = bonus_availability(species)
          {
            :shiny_rolls => [
              search_shiny_rolls(level) + chain_shiny_rolls(chain_value), 8
            ].min,
            :level_bonus => [level_range.begin, level_range.end],
            :perfect_ivs => perfect_iv_preview_label(level, chain_value),
            :hidden_ability => if availability[:hidden_ability]
                                 [
                                   hidden_ability_base(level) +
                                     hidden_ability_chain(chain_value),
                                   50
                                 ].min
                               end,
            :first_egg_move => if availability[:egg_move_count] >= 1
                                 [
                                   first_egg_base(level) +
                                     first_egg_chain(chain_value),
                                   90
                                 ].min
                               end,
            :second_egg_move => second_egg_move_preview(
              level, chain_value, availability[:egg_move_count]
            ),
            :held_item => if availability[:held_item]
                            [
                              item_base(level) + item_chain(chain_value), 60
                            ].min
                          end
          }
        end

        private

        def bonus_availability(species)
          return {
            :hidden_ability => true,
            :egg_move_count => 2,
            :held_item => true
          } if species.nil?
          data = GameData::Species.get(species)
          items = [
            data.wild_item_common,
            data.wild_item_uncommon,
            data.wild_item_rare
          ].compact.uniq
          {
            :hidden_ability => !Array(data.hidden_abilities).compact.empty?,
            :egg_move_count => Array(data.egg_moves).compact.uniq.length,
            :held_item => !items.empty?
          }
        rescue StandardError
          {
            :hidden_ability => false,
            :egg_move_count => 0,
            :held_item => false
          }
        end

        def second_egg_move_preview(search_level, chain, egg_move_count)
          return nil if egg_move_count.to_i < 2
          return :locked unless search_level.to_i >= 100 || chain.to_i >= 50
          [
            second_egg_base(search_level) + second_egg_chain(chain), 65
          ].min
        end

        def boosted_level(level, search_level)
          range = level_bonus_range(search_level)
          maximum = if defined?(GameData::GrowthRate) &&
                       GameData::GrowthRate.respond_to?(:max_level)
                      GameData::GrowthRate.max_level
                    else
                      100
                    end
          [level.to_i + rand(range), maximum.to_i].min
        rescue StandardError
          level.to_i
        end

        def level_bonus_range(search_level)
          case search_level.to_i
          when 0..9 then 0..0
          when 10..24 then 0..1
          when 25..49 then 0..2
          when 50..99 then 1..2
          when 100..199 then 1..3
          when 200..499 then 2..4
          else 3..5
          end
        end

        def perfect_iv_preview_label(search_level, chain)
          minimum = case search_level.to_i
                    when 0..49 then 0
                    when 50..199 then 1
                    else 2
                    end
          minimum = [minimum, 4].max if chain.to_i >= 150
          minimum = [minimum, 3].max if chain.to_i.between?(100, 149)
          minimum = [minimum, 2].max if chain.to_i.between?(50, 99)
          chances = []
          if search_level.to_i.between?(25, 49) && minimum < 1
            chances << "15%"
          elsif search_level.to_i.between?(100, 199) && minimum < 2
            chances << "20%"
          elsif search_level.to_i >= 500 && minimum < 3
            chances << "20%"
          end
          if chain.to_i.between?(30, 49) && minimum < 4
            chances << "50%"
          end
          label = _INTL("{1} min", minimum)
          label += " | +#{chances.join('/+')}" unless chances.empty?
          label
        end

        def apply_shiny_rolls(pokemon, search_level, chain)
          return if pokemon.shiny?
          rolls = search_shiny_rolls(search_level) + chain_shiny_rolls(chain)
          rolls = [rolls, 8].min
          rolls.times do
            pokemon.personalID = rand(2**16) | (rand(2**16) << 16)
            pokemon.shiny = nil
            break if pokemon.shiny?
          end
        end

        def search_shiny_rolls(level)
          case level.to_i
          when 0..24 then 0
          when 25..99 then 1
          when 100..199 then 2
          when 200..499 then 3
          else 4
          end
        end

        def chain_shiny_rolls(chain)
          case chain.to_i
          when 0..9 then 0
          when 10..19 then 1
          when 20..49 then 2
          when 50..149 then 3
          else 4
          end
        end

        def apply_perfect_ivs(pokemon, search_level, chain)
          target = search_iv_target(search_level)
          if chain.to_i.between?(30, 49) && rand(100) < 50
            target += 1
          elsif chain.to_i >= 150
            target = [target, 4].max
          elsif chain.to_i >= 100
            target = [target, 3].max
          elsif chain.to_i >= 50
            target = [target, 2].max
          end
          target = [target, 4].min
          available = STATS.reject { |stat| pokemon.iv[stat].to_i >= 31 }
          while perfect_iv_count(pokemon) < target && !available.empty?
            stat = available.delete_at(rand(available.length))
            pokemon.iv[stat] = 31
          end
        end

        def search_iv_target(level)
          case level.to_i
          when 0..24 then 0
          when 25..49 then rand(100) < 15 ? 1 : 0
          when 50..99 then 1
          when 100..199 then 1 + (rand(100) < 20 ? 1 : 0)
          when 200..499 then 2
          else 2 + (rand(100) < 20 ? 1 : 0)
          end
        end

        def apply_hidden_ability(pokemon, search_level, chain)
          hidden = Array(pokemon.species_data.hidden_abilities).compact
          return if hidden.empty?
          chance = [hidden_ability_base(search_level) +
                    hidden_ability_chain(chain), 50].min
          return unless rand(100) < chance
          if defined?(KantoReloaded::DoubleAbilities) &&
             KantoReloaded::DoubleAbilities.respond_to?(:eligible_pokemon?) &&
             KantoReloaded::DoubleAbilities.eligible_pokemon?(pokemon)
            choices = KantoReloaded::DoubleAbilities.hidden_slot_choices(
              pokemon, 1
            ).compact.uniq
            return if choices.empty?
            selected = choices[rand(choices.length)]
            return unless KantoReloaded::DoubleAbilities.assign_slot!(
              pokemon, 1, selected
            )
            return KantoReloaded::DoubleAbilities.primary_id(pokemon)
          end
          index = rand(hidden.length)
          pokemon.ability_index = index + 2
          pokemon.ability = nil
          pokemon.ability_id
        end

        def hidden_ability_base(level)
          case level.to_i
          when 0..9 then 0
          when 10..24 then 2
          when 25..49 then 5
          when 50..99 then 8
          when 100..199 then 12
          when 200..499 then 18
          else 25
          end
        end

        def hidden_ability_chain(chain)
          case chain.to_i
          when 0..9 then 0
          when 10..19 then 5
          when 20..49 then 10
          when 50..99 then 15
          when 100..149 then 20
          else 25
          end
        end

        def apply_egg_moves(pokemon, search_level, chain)
          pool = Array(pokemon.species_data.egg_moves).compact.uniq
          return [] if pool.empty?
          learned = []
          first_chance = [first_egg_base(search_level) +
                          first_egg_chain(chain), 90].min
          return learned unless rand(100) < first_chance
          learned << pool.delete_at(rand(pool.length))
          second_unlocked = search_level.to_i >= 100 || chain.to_i >= 50
          if second_unlocked && !pool.empty?
            second_chance = [second_egg_base(search_level) +
                             second_egg_chain(chain), 65].min
            learned << pool.delete_at(rand(pool.length)) if rand(100) < second_chance
          end
          learned.each { |move| pokemon.learn_move(move) }
          pokemon.record_first_moves if pokemon.respond_to?(:record_first_moves)
          learned
        end

        def first_egg_base(level)
          case level.to_i
          when 0..9 then 0
          when 10..24 then 10
          when 25..49 then 20
          when 50..99 then 30
          when 100..199 then 40
          when 200..499 then 55
          else 70
          end
        end

        def first_egg_chain(chain)
          case chain.to_i
          when 0..9 then 0
          when 10..19 then 5
          when 20..49 then 10
          when 50..99 then 15
          when 100..149 then 20
          else 25
          end
        end

        def second_egg_base(level)
          case level.to_i
          when 0..99 then 0
          when 100..199 then 10
          when 200..499 then 20
          else 30
          end
        end

        def second_egg_chain(chain)
          case chain.to_i
          when 0..49 then 0
          when 50..99 then 15
          when 100..149 then 25
          else 35
          end
        end

        def apply_held_item(pokemon, search_level, chain)
          chance = [item_base(search_level) + item_chain(chain), 60].min
          return unless rand(100) < chance
          items = Array(pokemon.wildHoldItems)
          candidates = item_candidates(items, search_level, chain)
          return if candidates.empty?
          chosen = candidates[rand(candidates.length)]
          current_rank = item_rank(pokemon.item_id, items)
          chosen_rank = item_rank(chosen, items)
          pokemon.item = chosen if !pokemon.item_id || chosen_rank > current_rank
        end

        def item_candidates(items, search_level, chain)
          common, uncommon, rare = items
          score = [search_level.to_i / 10 + chain.to_i, 200].min
          rare_weight = [5 + score / 5, 40].min
          uncommon_weight = [25 + score / 4, 55].min
          rows = []
          rows.concat(Array.new(rare_weight, rare)) if rare
          rows.concat(Array.new(uncommon_weight, uncommon)) if uncommon
          rows.concat(Array.new([100 - rare_weight - uncommon_weight, 10].max, common)) if common
          rows.compact
        end

        def item_rank(item, items)
          return -1 unless item
          return 2 if item == items[2]
          return 1 if item == items[1]
          0
        end

        def item_base(level)
          case level.to_i
          when 0..9 then 0
          when 10..24 then 5
          when 25..49 then 10
          when 50..99 then 15
          when 100..199 then 20
          when 200..499 then 25
          else 30
          end
        end

        def item_chain(chain)
          case chain.to_i
          when 0..9 then 0
          when 10..19 then 5
          when 20..49 then 10
          when 50..99 then 15
          when 100..149 then 20
          else 30
          end
        end

        def global_call(name, *args)
          Object.new.__send__(name, *args)
        end
      end
    end
  end
end
