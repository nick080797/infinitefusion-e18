#==============================================================================
# Kanto Reloaded - Economy System Mart Events
#==============================================================================

module KantoReloaded
  module EconomySystem
    module MartEvents
      SAVE_OWNER = :economy_system
      EVENT_SECONDS = 3 * 24 * 60 * 60
      UPDATE_CHECK_FRAMES = 60
      EVENT_CHANCE = 65
      SCOPE_WEIGHTS = [[:items, 70], [:category, 25], [:shopwide, 5]].freeze
      RANDOMIZED_SCOPE_WEIGHTS = [[:category, 25], [:shopwide, 5]].freeze
      TYPE_WEIGHTS = [[:sale, 70], [:markup, 30]].freeze
      STRENGTH_RANGES = {
        :sale => (10..30), :markup => (5..20)
      }.freeze

      @current_context = nil
      @current_entries = []
      @update_frames = 0

      class << self
        def state
          bucket = if defined?(KantoReloaded::SaveData)
                     KantoReloaded::SaveData.module_data(SAVE_OWNER)
                   else
                     @fallback ||= {}
                   end
          normalize_state!(bucket)
          bucket
        end

        def apply(context, entries, notify = true)
          rows = Array(entries).map { |entry| entry.dup }
          data = normalize_context(context)
          if excluded_context?(data)
            remove_context(data)
            return rows
          end
          register_shop(context, rows)
          return rows unless mart_events_enabled?
          record = shop_record(context)
          event, _created = ensure_event(record, rows)
          rows.map { |entry| apply_event(entry, event) }
        rescue StandardError => e
          log_exception("Mart Event pricing failed", e)
          Array(entries).map { |entry| entry.dup }
        end

        def set_current_context(context, entries = nil)
          @current_context = normalize_context(context)
          @current_entries = Array(entries).map { |entry| entry.dup } if entries
          @current_context
        end

        def register_shop(context, entries)
          data = normalize_context(context)
          if excluded_context?(data)
            remove_context(data)
            return data
          end
          set_current_context(context, entries)
          return @current_context unless mart_events_enabled?
          record = shop_record(@current_context)
          snapshot = snapshot_entries(entries)
          record["entries"] = snapshot
          resolve_pending_targets(record, snapshot) unless snapshot.empty?
          record.delete("stockless_fallback") unless snapshot.empty?
          initialize_schedule(record)
          process_record_if_due(record)
          @current_context
        rescue StandardError => e
          log_exception("Mart Event shop registration failed", e)
          @current_context
        end

        def update(force = false)
          return false unless mart_events_enabled?
          unless force
            @update_frames = @update_frames.to_i + 1
            return false if @update_frames < UPDATE_CHECK_FRAMES
          end
          @update_frames = 0
          process_due_shops
          true
        rescue StandardError => e
          @update_frames = 0
          log_exception("Mart Event schedule update failed", e)
          false
        end

        def clear_current_context
          @current_context = nil
          @current_entries = []
          true
        end

        def current_context
          @current_context ? @current_context.dup : nil
        end

        def current_event
          context = @current_context
          return nil unless context
          record = state["shops"][context[:key].to_s]
          active_event(record)
        end

        def migrate_shop_record(old_key, context)
          data = normalize_context(context)
          source_key = old_key.to_s
          target_key = data[:key].to_s
          return false if source_key.empty? || target_key.empty? ||
                          source_key == target_key
          shops = state["shops"]
          source = shops[source_key]
          target = shops[target_key]
          if !target.is_a?(Hash) && source.is_a?(Hash)
            shops[target_key] = source
            target = source
          end
          shops.delete(source_key)
          if target.is_a?(Hash)
            target["label"] = data[:label] unless data[:label].empty?
            target["kind"] = data[:kind].to_s
            target["randomized_stock"] = data[:randomized_stock]
          end
          true
        rescue StandardError => e
          log_exception("Mart Event shop identity migration failed", e)
          false
        end

        def consolidate_shop_records(context, source_keys)
          data = normalize_context(context)
          target_key = data[:key].to_s
          return false if target_key.empty?
          shops = state["shops"]
          keys = (Array(source_keys).map(&:to_s) + [target_key]).uniq
          candidates = keys.each_with_object([]) do |key, rows|
            record = shops[key]
            rows << [key, record] if record.is_a?(Hash)
          end
          unless candidates.empty?
            _source_key, preferred = candidates.max_by do |_key, record|
              record_schedule_time(record)
            end
            merged = deep_copy(preferred)
            if !merged["entries"].is_a?(Array) || merged["entries"].empty?
              cached = candidates.map { |_key, record| record["entries"] }.
                find { |entries| entries.is_a?(Array) && !entries.empty? }
              merged["entries"] = deep_copy(cached) if cached
            end
            shops[target_key] = merged
          end
          keys.each { |key| shops.delete(key) unless key == target_key }
          record = shops[target_key]
          if record.is_a?(Hash)
            record["label"] = data[:label] unless data[:label].empty?
            record["kind"] = data[:kind].to_s
            record["randomized_stock"] = data[:randomized_stock]
          end
          true
        rescue StandardError => e
          log_exception("Mart Event shop records could not be consolidated", e)
          false
        end

        def known_active_events
          now_value = now
          state["shops"].each_with_object([]) do |(key, record), rows|
            next unless record.is_a?(Hash)
            event = record["event"]
            next unless active_event?(event, now_value)
            next if event["type"].to_s == "none"
            label = record["label"].to_s
            if defined?(KantoReloaded::EconomySystem) &&
               KantoReloaded::EconomySystem.respond_to?(:mart_event_label_for_key)
              label = KantoReloaded::EconomySystem.mart_event_label_for_key(key, label)
              record["label"] = label unless label.empty?
            end
            rows << {
              :key => key,
              :label => label,
              :event => deep_copy(event),
              :current => @current_context && @current_context[:key].to_s == key
            }
          end.sort_by { |entry| [entry[:current] ? 0 : 1, entry[:label].downcase] }
        rescue StandardError
          []
        end

        def force_current(type, scope = :items, percent = nil)
          return false unless @current_context && !@current_entries.empty?
          record = shop_record(@current_context)
          event = build_forced_event(type, scope, percent, @current_entries)
          return false unless event
          record["previous_signature"] = event_signature(record["event"])
          record["event"] = event
          record["next_roll_at"] = event["expires_at"].to_i
          record["label"] = @current_context[:label].to_s
          true
        rescue StandardError => e
          log_exception("Forced Mart Event failed", e)
          false
        end

        def reroll_current
          return false unless @current_context && !@current_entries.empty?
          record = shop_record(@current_context)
          previous = record["event"]
          record["previous_signature"] = event_signature(previous)
          record["event"] = generate_event(@current_entries, record, true)
          record["next_roll_at"] = record["event"]["expires_at"].to_i
          true
        rescue StandardError => e
          log_exception("Mart Event reroll failed", e)
          false
        end

        def expire_current
          return false unless @current_context
          record = shop_record(@current_context)
          event = record["event"]
          return false unless event.is_a?(Hash)
          event["expires_at"] = now - 1
          record["next_roll_at"] = now
          true
        rescue StandardError
          false
        end

        def clear_current
          return false unless @current_context
          record = shop_record(@current_context)
          record["previous_signature"] = event_signature(record["event"])
          record["event"] = none_event
          record["next_roll_at"] = record["event"]["expires_at"].to_i
          true
        rescue StandardError
          false
        end

        def summary(event)
          data = event.is_a?(Hash) ? event : {}
          type = data["type"].to_s
          return _INTL("No Mart Event") if type.empty? || type == "none"
          percent = data["percent"].to_i
          name = type == "sale" ? _INTL("Sale") : _INTL("Shortage")
          scope = scope_label(data)
          _INTL("{1}: {2}% {3} ({4})", name, percent,
                type == "sale" ? _INTL("off") : _INTL("markup"), scope)
        rescue StandardError
          _INTL("Mart Event")
        end

        def remaining_text(event)
          seconds = event.is_a?(Hash) ? event["expires_at"].to_i - now : 0
          seconds = 0 if seconds < 0
          days = seconds / 86_400
          hours = (seconds % 86_400) / 3_600
          minutes = (seconds % 3_600) / 60
          return _INTL("{1}d {2}h", days, hours) if days > 0
          return _INTL("{1}h {2}m", hours, minutes) if hours > 0
          _INTL("{1}m", minutes)
        rescue StandardError
          ""
        end

        def event_for_entry(entry, event = nil)
          data = event || current_event
          return nil unless data.is_a?(Hash)
          return nil if data["type"].to_s == "none"
          return nil unless eligible_entry?(entry)
          case data["scope"].to_s
          when "items"
            return nil unless Array(data["targets"]).include?(entry[:id].to_s)
          when "category"
            return nil unless data["category"].to_s == entry[:category].to_s
          when "shopwide"
          else
            return nil
          end
          data
        rescue StandardError
          nil
        end

        private

        def normalize_state!(bucket)
          bucket["schema_version"] = 2
          bucket["shops"] = {} unless bucket["shops"].is_a?(Hash)
          bucket["shops"].delete_if do |key, record|
            key.to_s == "rld_shop" ||
              (record.is_a?(Hash) && record["kind"].to_s == "reloaded_shop")
          end
          bucket
        end

        def normalize_context(context)
          data = context.is_a?(Hash) ? context : {}
          {
            :key => data[:key].to_s,
            :label => data[:label].to_s,
            :kind => (data[:kind] || :regular).to_sym,
            :randomized_stock => data[:randomized_stock] == true
          }
        end

        def excluded_context?(context)
          data = context.is_a?(Hash) ? context : normalize_context(context)
          data[:kind].to_sym == :reloaded_shop || data[:key].to_s == "rld_shop"
        rescue StandardError
          false
        end

        def remove_context(context)
          data = context.is_a?(Hash) ? context : normalize_context(context)
          state["shops"].delete(data[:key].to_s)
          if @current_context && @current_context[:key].to_s == data[:key].to_s
            clear_current_context
          end
          true
        rescue StandardError
          false
        end

        def shop_record(context)
          data = normalize_context(context)
          key = data[:key].empty? ? "unknown" : data[:key]
          record = state["shops"][key]
          unless record.is_a?(Hash)
            record = {}
            state["shops"][key] = record
          end
          record["label"] = data[:label] unless data[:label].empty?
          record["kind"] = data[:kind].to_s
          record["randomized_stock"] = data[:randomized_stock]
          record
        end

        def ensure_event(record, entries)
          event = record["event"]
          normalize_randomized_event!(event, entries) if record["randomized_stock"]
          initialize_schedule(record)
          created = process_record_if_due(record)
          [record["event"], created]
        end

        def active_event(record)
          return nil unless record.is_a?(Hash)
          event = record["event"]
          active_event?(event) && event["type"].to_s != "none" ? deep_copy(event) : nil
        end

        def active_event?(event, time_value = nil)
          event.is_a?(Hash) && event["expires_at"].to_i > (time_value || now)
        end

        def initialize_schedule(record)
          return record if record["next_roll_at"].to_i > 0
          event = record["event"]
          event_time = event.is_a?(Hash) ? event["expires_at"].to_i : 0
          current_time = now
          record["discovered_at"] = current_time if record["discovered_at"].to_i <= 0
          record["next_roll_at"] = event_time > 0 ? event_time : current_time
          record
        end

        def process_due_shops
          state["shops"].each_value do |record|
            next unless record.is_a?(Hash)
            initialize_schedule(record)
            process_record_if_due(record)
          end
          true
        end

        def process_record_if_due(record)
          return false if record["next_roll_at"].to_i > now
          entries = Array(record["entries"])
          previous = record["event"]
          record["previous_signature"] = event_signature(previous) if previous
          if entries.empty?
            event = generate_stockless_event(record)
            record["stockless_fallback"] = true
          else
            event = generate_event(entries, record)
          end
          record["event"] = event
          record["next_roll_at"] = event["expires_at"].to_i
          true
        end

        def snapshot_entries(entries)
          Array(entries).select { |entry| entry.is_a?(Hash) }.map do |entry|
            {
              :id => entry[:id].to_s,
              :buy_price => entry[:buy_price].to_i,
              :mart_event_eligible => mart_event_eligible?(entry),
              :custom_price => entry[:custom_price] == true,
              :important => entry[:important] == true,
              :category => entry[:category].to_s,
              :category_name => entry[:category_name].to_s
            }
          end
        end

        def record_schedule_time(record)
          event = record["event"]
          expires_at = event.is_a?(Hash) ? event["expires_at"].to_i : 0
          next_roll_at = record["next_roll_at"].to_i
          next_roll_at = expires_at if next_roll_at <= 0
          [next_roll_at, expires_at,
           event.is_a?(Hash) ? event["created_at"].to_i : 0]
        rescue StandardError
          [0, 0, 0]
        end

        def generate_event(entries, record, force = false)
          eligible = Array(entries).select { |entry| eligible_entry?(entry) }
          return none_event if eligible.empty?
          return none_event unless force || rand(100) < EVENT_CHANCE
          previous = record["previous_signature"].to_s
          event = nil
          8.times do
            event = random_event(eligible, record["randomized_stock"])
            break if event_signature(event) != previous
          end
          if event && event_signature(event) == previous
            alternate = event["type"].to_s == "sale" ? :markup : :sale
            event["type"] = alternate.to_s
            event["percent"] = rand(STRENGTH_RANGES[alternate])
          end
          event || none_event
        end

        def generate_stockless_event(record)
          return none_event unless rand(100) < EVENT_CHANCE
          previous = record["previous_signature"].to_s
          event = nil
          8.times do
            type = weighted_choice(TYPE_WEIGHTS)
            weights = record["randomized_stock"] ?
              RANDOMIZED_SCOPE_WEIGHTS : SCOPE_WEIGHTS
            scope = weighted_choice(weights)
            event = {
              "type" => type.to_s,
              "scope" => scope.to_s,
              "percent" => rand(STRENGTH_RANGES[type]),
              "created_at" => now,
              "expires_at" => now + EVENT_SECONDS,
              "targets" => []
            }
            if scope == :items
              event["pending_targets"] = true
            elsif scope == :category
              event["pending_targets"] = true
              event["category_name"] = _INTL("Item Category")
            end
            break if event_signature(event) != previous
          end
          if event && event_signature(event) == previous
            alternate = event["type"].to_s == "sale" ? :markup : :sale
            event["type"] = alternate.to_s
            event["percent"] = rand(STRENGTH_RANGES[alternate])
          end
          event || none_event
        end

        def resolve_pending_targets(record, entries)
          event = record["event"]
          return false unless active_event?(event)
          return false unless event["pending_targets"]
          eligible = Array(entries).select { |entry| eligible_entry?(entry) }
          return false if eligible.empty?
          case event["scope"].to_s
          when "items"
            count = [rand(2..8), eligible.length].min
            event["targets"] = eligible.shuffle.first(count).map do |entry|
              entry[:id].to_s
            end
          when "category"
            categories = eligible.group_by { |entry| entry[:category].to_s }
            category = categories.keys.reject(&:empty?).sample
            unless category
              event["scope"] = "items"
              count = [rand(2..8), eligible.length].min
              event["targets"] = eligible.shuffle.first(count).map do |entry|
                entry[:id].to_s
              end
              event.delete("category")
              event.delete("category_name")
              event.delete("pending_targets")
              return true
            end
            event["category"] = category
            sample = categories[category].first
            event["category_name"] =
              (sample[:category_name] || category).to_s
          end
          event.delete("pending_targets")
          true
        end

        def random_event(eligible, randomized_stock = false)
          type = weighted_choice(TYPE_WEIGHTS)
          weights = randomized_stock ? RANDOMIZED_SCOPE_WEIGHTS : SCOPE_WEIGHTS
          scope = weighted_choice(weights)
          categories = eligible.group_by { |entry| entry[:category].to_s }
          scope = :items if scope == :category && categories.empty?
          event = {
            "type" => type.to_s,
            "scope" => scope.to_s,
            "percent" => rand(STRENGTH_RANGES[type]),
            "created_at" => now,
            "expires_at" => now + EVENT_SECONDS,
            "targets" => []
          }
          case scope
          when :items
            count = [rand(2..8), eligible.length].min
            event["targets"] = eligible.shuffle.first(count).map { |entry| entry[:id].to_s }
          when :category
            category = categories.keys.sample
            event["category"] = category
            sample = categories[category].first
            event["category_name"] = (sample[:category_name] || category).to_s
          end
          event
        end

        def normalize_randomized_event!(event, entries)
          return event unless active_event?(event)
          eligible = Array(entries).select { |entry| eligible_entry?(entry) }
          return event if eligible.empty?
          scope = event["scope"].to_s
          if scope == "items"
            available = eligible.map { |entry| entry[:id].to_s }.uniq
            targets = Array(event["targets"]).map(&:to_s) & available
            desired = [Array(event["targets"]).length, 2].max
            desired = [[desired, 8].min, available.length].min
            if targets.length < desired
              targets.concat(
                (available - targets).shuffle.first(desired - targets.length)
              )
            end
            event["targets"] = targets
            return event
          elsif scope == "category"
            category = event["category"].to_s
            categories = eligible.group_by { |entry| entry[:category].to_s }
            category_present = !category.empty? && categories.has_key?(category)
            return event if category_present
            replacement = categories.keys.reject(&:empty?).sample
            if replacement
              event["category"] = replacement
              sample = categories[replacement].first
              event["category_name"] =
                (sample[:category_name] || replacement).to_s
              return event
            end
            event["scope"] = "items"
            count = [rand(2..8), eligible.length].min
            event["targets"] = eligible.shuffle.first(count).map do |entry|
              entry[:id].to_s
            end
            event.delete("category")
            event.delete("category_name")
          end
          event
        end

        def build_forced_event(type, scope, percent, entries)
          normalized_type = type.to_sym rescue :none
          return none_event if normalized_type == :none
          return nil unless [:sale, :markup].include?(normalized_type)
          eligible = Array(entries).select { |entry| eligible_entry?(entry) }
          return nil if eligible.empty?
          normalized_scope = scope.to_sym rescue :items
          normalized_scope = :items unless [:items, :category, :shopwide].include?(normalized_scope)
          value = percent.nil? ? STRENGTH_RANGES[normalized_type].max : percent.to_i
          value = [[value, 1].max, 90].min
          event = {
            "type" => normalized_type.to_s,
            "scope" => normalized_scope.to_s,
            "percent" => value,
            "created_at" => now,
            "expires_at" => now + EVENT_SECONDS,
            "targets" => []
          }
          if normalized_scope == :items
            count = [rand(2..8), eligible.length].min
            event["targets"] = eligible.shuffle.first(count).map { |entry| entry[:id].to_s }
          elsif normalized_scope == :category
            category = eligible.first[:category].to_s
            event["category"] = category
            event["category_name"] = (eligible.first[:category_name] || category).to_s
          end
          event
        end

        def none_event
          {
            "type" => "none", "scope" => "none", "percent" => 0,
            "created_at" => now, "expires_at" => now + EVENT_SECONDS,
            "targets" => []
          }
        end

        def apply_event(entry, event)
          row = entry.dup
          row[:base_buy_price] = row[:buy_price].to_i
          applied = event_for_entry(row, event)
          return row unless applied
          percent = applied["percent"].to_i
          base = row[:base_buy_price].to_i
          adjusted = if applied["type"].to_s == "sale"
                       (base * (100 - percent) / 100.0).floor
                     else
                       (base * (100 + percent) / 100.0).ceil
                     end
          adjusted = 1 if base > 0 && adjusted < 1
          row[:buy_price] = adjusted
          row[:mart_event] = deep_copy(applied)
          row[:market_event] = row[:mart_event]
          row
        end

        def eligible_entry?(entry)
          entry.is_a?(Hash) && entry[:buy_price].to_i > 0 &&
            mart_event_eligible?(entry) && !entry[:custom_price]
        rescue StandardError
          false
        end

        def mart_event_eligible?(entry)
          return false unless entry.is_a?(Hash)
          eligible = if entry.key?(:mart_event_eligible)
                       entry[:mart_event_eligible] != false
                     elsif entry.key?(:market_eligible)
                       entry[:market_eligible] != false
                     else
                       entry[:important] != true
                     end
          return false unless eligible
          return true unless entry[:important] == true
          data = GameData::Item.try_get(entry[:id].to_sym) rescue nil
          data && data.is_TM?
        rescue StandardError
          false
        end

        def weighted_choice(rows)
          total = rows.inject(0) { |sum, row| sum + row[1].to_i }
          roll = rand([total, 1].max)
          rows.each do |row|
            return row[0] if roll < row[1].to_i
            roll -= row[1].to_i
          end
          rows.first[0]
        end

        def event_signature(event)
          return "" unless event.is_a?(Hash)
          [event["type"], event["scope"], event["percent"],
           event["category"], Array(event["targets"]).sort.join(",")].join("|")
        end

        def scope_label(event)
          case event["scope"].to_s
          when "items" then _INTL("selected items")
          when "category" then event["category_name"].to_s
          when "shopwide" then _INTL("shopwide")
          else _INTL("unknown scope")
          end
        end

        def mart_events_enabled?
          defined?(KantoReloaded::EconomySystem) &&
            KantoReloaded::EconomySystem.enabled? &&
            KantoReloaded::EconomySystem.mart_events?
        rescue StandardError
          false
        end

        def now
          defined?(pbGetTimeNow) ? pbGetTimeNow.to_i : Time.now.to_i
        rescue StandardError
          Time.now.to_i
        end

        def deep_copy(value)
          Marshal.load(Marshal.dump(value))
        rescue StandardError
          value.dup rescue value
        end

        def log_exception(message, error)
          KantoReloaded::Log.exception(
            message, error, :channel => :economy_system
          ) if defined?(KantoReloaded::Log)
        rescue StandardError
          nil
        end
      end
    end

    # Compatibility for integrations built against the pre-rename API.
    MarketEvents = MartEvents unless const_defined?(:MarketEvents, false)
  end
end
