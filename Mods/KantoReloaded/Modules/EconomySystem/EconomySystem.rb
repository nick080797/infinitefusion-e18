#==============================================================================
# Kanto Reloaded - Economy System
#==============================================================================

module KantoReloaded
  module EconomySystem
    SETTINGS_ACTION = :economy_system_settings
    ENABLED_SETTING = :economy_system_enabled
    MART_EVENTS_SETTING = :economy_market_events
    MARKET_SETTING = MART_EVENTS_SETTING
    STARTING_MONEY_VALUE = :economy_starting_money
    BATTLE_MONEY_SETTING = :economy_battle_money_enabled
    BATTLE_MONEY_VALUE = :economy_battle_money_multiplier
    RESET_EV_SETTING = :economy_reset_evs
    RESET_EV_PRICE = :economy_reset_evs_price
    FRIENDSHIP_SETTING = :economy_friendship_boost
    FRIENDSHIP_PRICE = :economy_friendship_price
    MART_LOCATION_NAMES = {
      :PEWTER => "Pewter City",
      :VIRIDIAN => "Viridian City",
      :CERULEAN => "Cerulean City",
      :VERMILLION => "Vermilion City",
      :LAVENDER => "Lavender Town",
      :CELADON => "Celadon City",
      :FUCHSIA => "Fuchsia City",
      :SAFFRON => "Saffron City",
      :CINNABAR => "Cinnabar Island",
      :LEAGUE => "Pokemon League",
      :CHERRYGROVE => "Cherrygrove City",
      :VIOLET => "Violet City",
      :AZALEA => "Azalea Town",
      :AZALEA_FLOODED => "Azalea Town",
      :GOLDENROD => "Goldenrod City",
      :ECRUTEAK => "Ecruteak City",
      :MAHOGANY => "Mahogany Town",
      :BLACKTHORN => "Blackthorn City",
      :OLIVINE => "Olivine City",
      :CIANWOOD => "Cianwood City",
      :KNOTISLAND => "Knot Island",
      :BOONISLAND => "Boon Island",
      :KINISLAND => "Kin Island",
      :CHRONOISLAND => "Chrono Island",
      :CRIMSON => "Crimson City"
    }.freeze
    MART_COUNTER_LABELS = {
      [432, 23] => "Celadon Dept. Store 1F - General Items",
      [432, 25] => "Celadon Dept. Store 1F - Specialty",
      [433, 4]  => "Celadon Dept. Store 2F - Battle Items",
      [433, 5]  => "Celadon Dept. Store 2F - TMs",
      [433, 9]  => "Celadon Dept. Store 2F - Vitamins",
      [435, 4]  => "Celadon Dept. Store 4F - Evolution Items",
      [435, 5]  => "Celadon Dept. Store 4F - Gifts"
    }.freeze

    class << self
      def install
        return true if @installed
        settings = register_settings
        hooks = register_hooks
        actions = register_pc_actions
        overworld = register_overworld_menu
        @installed = settings && hooks && actions && overworld
        KantoReloaded::Log.info(
          "Economy System installed settings=#{settings} hooks=#{hooks} " +
          "pc=#{actions} overworld=#{overworld}",
          :modules
        ) if defined?(KantoReloaded::Log)
        @installed
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "Economy System installation failed", e, :channel => :economy_system
        ) if defined?(KantoReloaded::Log)
        false
      end

      def enabled?
        toggle(ENABLED_SETTING, true)
      end

      def mart_events?
        enabled? && toggle(MART_EVENTS_SETTING, true)
      end

      def regular_shop_context(stock, options = {})
        map_id = defined?($game_map) && $game_map ? $game_map.map_id.to_i : 0
        event_id = current_event_id
        signature = stock_signature(stock)
        stock_key = "mart:#{map_id}:stock:#{signature}"
        mart_identity = current_mart_identity
        label = mart_counter_label(map_id, event_id)
        department = !label.empty?
        if department
          key = "mart:#{map_id}:event:#{event_id}"
        elsif mart_identity && shared_pokemart_map?(map_id)
          key = "mart:location:#{mart_identity.to_s.downcase}"
        else
          key = "mart:#{map_id}"
        end
        unless department
          label = current_mart_location_name(mart_identity)
          label = town_map_location_name(map_id) if label.empty?
          label = map_name(map_id) if label.empty?
          label = "" if generic_mart_name?(label)
          label = _INTL("{1} Mart", label.empty? ? _INTL("Local") : label)
        end
        context = {
          :key => key, :label => label, :kind => :regular,
          :randomized_stock => options[:randomized_stock] == true
        }
        MartEvents.consolidate_shop_records(
          context, legacy_shop_keys(map_id, event_id, signature, mart_identity,
                                    department)
        )
        context
      end

      def mart_event_label_for_key(key, fallback = "")
        match = key.to_s.match(/\Amart:(\d+):event:(\d+)\z/)
        return fallback.to_s unless match
        label = mart_counter_label(match[1], match[2])
        label.empty? ? fallback.to_s : label
      rescue StandardError
        fallback.to_s
      end

      def reloaded_shop_context
        { :key => "rld_shop", :label => _INTL("RLD Shop"), :kind => :reloaded_shop }
      end

      def mart_event_apply(context, entries, notify = true)
        MartEvents.apply(context, entries, notify)
      end

      def prepare_mart_event_context(context, entries)
        MartEvents.register_shop(context, entries)
      end

      def current_mart_event_context
        MartEvents.current_context
      end

      def current_mart_event
        MartEvents.current_event
      end

      def force_mart_event(type, scope = :items, percent = nil)
        MartEvents.force_current(type, scope, percent)
      end

      def reroll_mart_event
        MartEvents.reroll_current
      end

      def expire_mart_event
        MartEvents.expire_current
      end

      def clear_mart_event
        MartEvents.clear_current
      end

      alias market_events? mart_events?
      alias market_label_for_key mart_event_label_for_key
      alias market_apply mart_event_apply
      alias prepare_market_context prepare_mart_event_context
      alias current_market_context current_mart_event_context
      alias current_market_event current_mart_event
      alias force_market_event force_mart_event
      alias reroll_market_event reroll_mart_event
      alias expire_market_event expire_mart_event
      alias clear_market_event clear_mart_event

      def reset_ev_price
        setting(RESET_EV_PRICE, 1000).to_i
      end

      def friendship_price
        setting(FRIENDSHIP_PRICE, 5000).to_i
      end

      private

      def register_settings
        return false unless defined?(KantoReloaded::Settings)
        action = KantoReloaded::Settings.register(SETTINGS_ACTION, {
          :name => "Economy System",
          :description => "Configure markets, money progression, and paid services.",
          :type => :button, :category => :economy,
          :owner => :kanto_reloaded, :priority => 1000,
          :on_press => proc {
            KantoReloaded::SettingsUI.open_module(
              :economy_system, :title => "Economy System"
            )
          }
        })
        visible = proc do |context|
          value = context.is_a?(Hash) &&
            (context[:module] || context["module"] || context[:owner] || context["owner"])
          value && value.to_sym == :economy_system
        rescue StandardError
          false
        end
        enabled = proc { KantoReloaded::EconomySystem.enabled? }
        mart_events = proc { KantoReloaded::EconomySystem.mart_events? }
        rows = [
          [ENABLED_SETTING, "Economy System", "Enable Kanto Reloaded economy features.", :toggle, 1, 10, {}],
          [MART_EVENTS_SETTING, "Mart Events", "Enable shop-local sales and shortages lasting three in-game days.", :toggle, 1, 20, { :enabled_if => enabled }],
          [:economy_events_status, "Mart Events", "View all discovered Mart Events that are still active.", :button, nil, 40, { :enabled_if => mart_events, :on_press => proc { EconomyUI.open_status } }],
          [STARTING_MONEY_VALUE, "Starting Money", "Set the money assigned to a newly created Trainer.", :number, 3000, 100, {
            :min => 0, :max => 9999999, :step => 100, :scope => :global,
            :enabled_if => enabled,
            :metadata => {
              :popup_picker => true, :digits => 7,
              :picker_label => "New-game money", :value_prefix => "$"
            }
          }],
          [BATTLE_MONEY_SETTING, "Battle Money", "Apply a multiplier to native battle payouts.", :toggle, 1, 120, { :enabled_if => enabled }],
          [BATTLE_MONEY_VALUE, "Battle Multiplier", "Multiply the money awarded by the completed native payout.", :number, 1, 130, { :min => 1, :max => 10, :step => 1, :enabled_if => proc { enabled? && toggle(BATTLE_MONEY_SETTING, true) } }],
          [RESET_EV_SETTING, "Reset EVs", "Offer a paid EV reset action in Reloaded PC.", :toggle, 1, 200, { :enabled_if => enabled }],
          [RESET_EV_PRICE, "Reset EV Price", "Set the price of the Reloaded PC EV reset service.", :number, 1000, 210, {
            :min => 0, :max => 999999, :step => 100,
            :enabled_if => proc { enabled? && toggle(RESET_EV_SETTING, true) },
            :metadata => {
              :popup_picker => true, :digits => 6,
              :picker_label => "EV reset price", :value_prefix => "$"
            }
          }],
          [FRIENDSHIP_SETTING, "Friendship Boost", "Offer a paid +50 friendship action in Reloaded PC.", :toggle, 1, 220, { :enabled_if => enabled }],
          [FRIENDSHIP_PRICE, "Friendship Price", "Set the price of the Reloaded PC friendship service.", :number, 5000, 230, {
            :min => 0, :max => 999999, :step => 100,
            :enabled_if => proc { enabled? && toggle(FRIENDSHIP_SETTING, true) },
            :metadata => {
              :popup_picker => true, :digits => 6,
              :picker_label => "Friendship service price", :value_prefix => "$"
            }
          }]
        ]
        created = rows.map do |key, name, description, type, default, priority, extra|
          KantoReloaded::Settings.register(key, {
            :name => name, :description => description, :type => type,
            :default => default, :priority => priority,
            :category => :economy, :owner => :economy_system,
            :value_style => :integer, :visible_if => visible
          }.merge(extra))
        end
        !action.nil? && created.all? { |entry| !entry.nil? }
      end

      def register_hooks
        return false unless defined?(KantoReloaded::Hooks)
        results = []
        if defined?(Game) && Game.respond_to?(:start_new)
          results << KantoReloaded::Hooks.wrap(
            Game, :start_new, :economy_starting_money, :singleton => true
          ) do |hook, *arguments|
            result = hook.call(*arguments)
            KantoReloaded::EconomySystem.send(:apply_starting_money)
            result
          end
        end
        if defined?(PokeBattle_Battle)
          results << KantoReloaded::Hooks.wrap(
            PokeBattle_Battle, :pbGainMoney, :economy_battle_money
          ) do |hook, *arguments|
            before = (pbPlayer.money.to_i rescue 0)
            result = hook.call(*arguments)
            KantoReloaded::EconomySystem.send(
              :apply_battle_money_bonus, self, before
            )
            result
          end
        end
        if defined?(Scene_Map)
          results << KantoReloaded::Hooks.wrap(
            Scene_Map, :update, :economy_mart_event_update
          ) do |hook, *arguments|
            result = hook.call(*arguments)
            KantoReloaded::EconomySystem::MartEvents.update
            result
          end
        end
        !results.empty? && results.all?
      end

      def register_pc_actions
        return true unless defined?(KantoReloaded::PCOrganization)
        return false unless KantoReloaded::PCOrganization.respond_to?(:register_pokemon_action)
        reset = KantoReloaded::PCOrganization.register_pokemon_action(
          :economy_reset_evs,
          :label => _INTL("Reset EVs"), :priority => 410,
          :group => :reloaded_actions,
          :group_label => _INTL("Reloaded Actions"), :group_priority => 100,
          :return_to_group => true,
          :enabled => proc { |_access, pokemon, _locations| reset_ev_available?(pokemon) }
        ) do |scene, pokemon, _locations|
          perform_reset_evs(scene, pokemon)
        end
        friendship = KantoReloaded::PCOrganization.register_pokemon_action(
          :economy_friendship_boost,
          :label => _INTL("Friendship Boost"), :priority => 420,
          :group => :reloaded_actions,
          :group_label => _INTL("Reloaded Actions"), :group_priority => 100,
          :return_to_group => true,
          :enabled => proc { |_access, pokemon, _locations| friendship_available?(pokemon) }
        ) do |scene, pokemon, _locations|
          perform_friendship_boost(scene, pokemon)
        end
        reset && friendship
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "Economy PC actions failed", e, :channel => :economy_system
        ) if defined?(KantoReloaded::Log)
        false
      end

      def register_overworld_menu
        return false unless defined?(OverworldMenu) &&
                            OverworldMenu.respond_to?(:register)
        OverworldMenu.register(
          :events_status,
          :label => "Mart Events",
          :priority => 33,
          :default_enabled => false,
          :status => proc {
            count = MartEvents.known_active_events.length
            count > 0 ? _INTL("{1} Active", count) : _INTL("None")
          },
          :condition => proc { enabled? && mart_events? },
          :handler => proc { |screen|
            screen.run_with_overlay_hidden { EconomyUI.open_status }
            nil
          }
        )
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "Economy Overworld Menu registration failed", e,
          :channel => :economy_system
        ) if defined?(KantoReloaded::Log)
        false
      end

      def apply_starting_money
        return false unless enabled?
        return false unless defined?($Trainer) && $Trainer
        $Trainer.money = setting(STARTING_MONEY_VALUE, 3000).to_i
        true
      rescue StandardError
        false
      end

      def apply_battle_money_bonus(battle, before)
        return 0 unless enabled? && toggle(BATTLE_MONEY_SETTING, true)
        multiplier = setting(BATTLE_MONEY_VALUE, 1).to_i
        return 0 if multiplier <= 1
        player = battle.send(:pbPlayer) rescue nil
        return 0 unless player
        native_gain = player.money.to_i - before.to_i
        return 0 if native_gain <= 0
        old_money = player.money.to_i
        player.money += native_gain * (multiplier - 1)
        bonus = player.money.to_i - old_money
        battle.send(
          :pbDisplayPaused,
          _INTL("Economy bonus: ${1}!", bonus.to_i.to_s_formatted)
        ) if bonus > 0
        bonus
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "Battle money bonus failed", e, :channel => :economy_system
        ) if defined?(KantoReloaded::Log)
        0
      end

      def reset_ev_available?(pokemon)
        return false unless enabled? && toggle(RESET_EV_SETTING, true)
        return false unless pokemon && !(pokemon.egg? rescue false)
        values = pokemon.ev rescue {}
        values.respond_to?(:values) && values.values.any? { |value| value.to_i > 0 }
      rescue StandardError
        false
      end

      def friendship_available?(pokemon)
        enabled? && toggle(FRIENDSHIP_SETTING, true) && pokemon &&
          !(pokemon.egg? rescue false) && pokemon.happiness.to_i < 255
      rescue StandardError
        false
      end

      def perform_reset_evs(scene, pokemon)
        price = reset_ev_price
        return insufficient_money if trainer_money < price
        return false unless KantoReloaded::PopupWindow.confirm(
          _INTL("Reset every EV on {1} for ${2}?", pokemon.name,
                price.to_i.to_s_formatted), :default => true
        )
        snapshot = Marshal.load(Marshal.dump(pokemon.ev)) rescue pokemon.ev.dup
        saved_snapshot = if pokemon.respond_to?(:saved_ev) && pokemon.saved_ev
                           Marshal.load(Marshal.dump(pokemon.saved_ev)) rescue pokemon.saved_ev.dup
                         end
        pokemon.ev.each_key { |stat| pokemon.ev[stat] = 0 }
        pokemon.saved_ev.each_key { |stat| pokemon.saved_ev[stat] = 0 } if
          pokemon.respond_to?(:saved_ev) && pokemon.saved_ev.respond_to?(:each_key)
        pokemon.calc_stats if pokemon.respond_to?(:calc_stats)
        return rollback_evs(pokemon, snapshot, saved_snapshot) unless charge(price)
        refresh_pc(scene)
        KantoReloaded::Toast.success(_INTL("{1}'s EVs were reset.", pokemon.name))
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("EV reset service failed", e,
          :channel => :economy_system) if defined?(KantoReloaded::Log)
        false
      end

      def perform_friendship_boost(scene, pokemon)
        price = friendship_price
        return insufficient_money if trainer_money < price
        old = pokemon.happiness.to_i
        boosted = [old + 50, 255].min
        return false unless KantoReloaded::PopupWindow.confirm(
          _INTL(
            "{1}'s friendship is {2}/255 (after: {3}/255).\nApply the boost for ${4}?",
            pokemon.name, old, boosted, price.to_i.to_s_formatted
          ), :default => true
        )
        pokemon.happiness = boosted
        unless charge(price)
          pokemon.happiness = old
          return false
        end
        refresh_pc(scene)
        KantoReloaded::Toast.success(
          _INTL("{1}'s friendship rose to {2}.", pokemon.name, pokemon.happiness)
        )
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Friendship service failed", e,
          :channel => :economy_system) if defined?(KantoReloaded::Log)
        false
      end

      def rollback_evs(pokemon, snapshot, saved_snapshot = nil)
        snapshot.each { |stat, value| pokemon.ev[stat] = value }
        if saved_snapshot && pokemon.respond_to?(:saved_ev) && pokemon.saved_ev
          saved_snapshot.each { |stat, value| pokemon.saved_ev[stat] = value }
        end
        pokemon.calc_stats if pokemon.respond_to?(:calc_stats)
        false
      end

      def refresh_pc(scene)
        scene.kr_refresh if scene && scene.respond_to?(:kr_refresh)
      rescue StandardError
        nil
      end

      def insufficient_money
        KantoReloaded::PopupWindow.message(
          _INTL("You don't have enough money."), :theme => :error
        )
        false
      end

      def charge(amount)
        return false unless defined?($Trainer) && $Trainer
        return false if $Trainer.money.to_i < amount.to_i
        $Trainer.money -= amount.to_i
        true
      end

      def trainer_money
        defined?($Trainer) && $Trainer ? $Trainer.money.to_i : 0
      end

      def current_event_id
        interpreter = defined?(pbMapInterpreter) ? pbMapInterpreter : nil
        if !interpreter && defined?($game_system) && $game_system &&
           $game_system.respond_to?(:map_interpreter)
          interpreter = $game_system.map_interpreter
        end
        event_id = interpreter ? interpreter.instance_variable_get(:@event_id).to_i : 0
        return event_id if event_id > 0
        return 0 unless defined?($game_player) && $game_player &&
                        $game_player.respond_to?(:pbFacingEvent)
        event = $game_player.pbFacingEvent(true)
        event && event.respond_to?(:id) ? event.id.to_i : 0
      rescue StandardError
        0
      end

      def map_name(map_id)
        return $game_map.name.to_s if defined?($game_map) && $game_map &&
          $game_map.map_id.to_i == map_id.to_i
        data = pbLoadMapInfos[map_id.to_i] rescue nil
        data ? data.name.to_s : ""
      rescue StandardError
        ""
      end

      def current_mart_identity
        return nil unless Object.const_defined?(:VAR_CURRENT_MART)
        variable = Object.const_get(:VAR_CURRENT_MART)
        value = if defined?(pbGet)
                  pbGet(variable)
                elsif defined?($game_variables) && $game_variables
                  $game_variables[variable]
                end
        value.is_a?(Symbol) ? value : nil
      rescue StandardError
        nil
      end

      def shared_pokemart_map?(map_id)
        shared_id = if Object.const_defined?(:POKEMART_MAP_ID)
                      Object.const_get(:POKEMART_MAP_ID).to_i
                    else
                      357
                    end
        map_id.to_i == shared_id
      rescue StandardError
        map_id.to_i == 357
      end

      def mart_counter_label(map_id, event_id)
        label = MART_COUNTER_LABELS[[map_id.to_i, event_id.to_i]]
        label ? _INTL(label) : ""
      rescue StandardError
        ""
      end

      def legacy_shop_keys(map_id, event_id, signature, identity, department)
        map_prefix = "mart:#{map_id.to_i}"
        keys = ["#{map_prefix}:stock:#{signature}"]
        keys << "#{map_prefix}:event:#{event_id.to_i}" if event_id.to_i > 0
        keys << map_prefix if primary_legacy_counter?(map_id, event_id)
        if identity
          location_prefix = "mart:location:#{identity.to_s.downcase}"
          keys << "#{location_prefix}:stock:#{signature}"
          keys << "#{location_prefix}:event:#{event_id.to_i}" if event_id.to_i > 0
        end
        unless department || department_store_map?(map_id)
          shops = MartEvents.state["shops"] rescue {}
          Array(shops && shops.keys).each do |candidate|
            value = candidate.to_s
            keys << value if value =~ /\A#{Regexp.escape(map_prefix)}:(?:event|stock):/
            if identity
              prefix = "mart:location:#{identity.to_s.downcase}"
              keys << value if value =~ /\A#{Regexp.escape(prefix)}:(?:event|stock):/
            end
          end
        end
        keys.compact.uniq
      rescue StandardError
        keys || []
      end

      def department_store_map?(map_id)
        MART_COUNTER_LABELS.keys.any? { |key| key[0].to_i == map_id.to_i }
      rescue StandardError
        false
      end

      def primary_legacy_counter?(map_id, event_id)
        map_id.to_i == 432 && event_id.to_i == 23
      rescue StandardError
        false
      end

      def current_mart_location_name(identity = nil)
        key = identity || current_mart_identity
        return "" unless key
        MART_LOCATION_NAMES[key] || key.to_s.split("_").map do |word|
          word.capitalize
        end.join(" ")
      rescue StandardError
        ""
      end

      def town_map_location_name(map_id)
        metadata = GameData::MapMetadata.try_get(map_id.to_i) rescue nil
        position = metadata && metadata.town_map_position
        return "" unless position && position.length >= 3
        map_data = pbLoadTownMapData rescue nil
        region = map_data && map_data[position[0].to_i]
        locations = region && region[2]
        point = Array(locations).find do |entry|
          entry && entry[0].to_i == position[1].to_i &&
            entry[1].to_i == position[2].to_i
        end
        return "" unless point
        name = point[2].to_s
        if defined?(pbGetMessageFromHash) && defined?(MessageTypes::PlaceNames)
          name = pbGetMessageFromHash(MessageTypes::PlaceNames, point[2]).to_s
        end
        name.strip
      rescue StandardError
        ""
      end

      def generic_mart_name?(name)
        normalized = name.to_s.downcase.gsub(/[^a-z]/, "")
        ["mart", "pokmart", "pokemart"].include?(normalized)
      rescue StandardError
        false
      end

      def stock_signature(stock)
        hash = 2_166_136_261
        Array(stock).each do |item|
          data = GameData::Item.try_get(item) rescue nil
          (data ? data.id.to_s : item.to_s).each_byte do |byte|
            hash ^= byte
            hash = (hash * 16_777_619) & 0xffffffff
          end
        end
        hash.to_s(16)
      end

      def setting(key, fallback)
        KantoReloaded::Settings.get(key, fallback)
      rescue StandardError
        fallback
      end

      def toggle(key, fallback)
        value = setting(key, fallback ? 1 : 0)
        value == true || value.to_i == 1
      rescue StandardError
        fallback
      end
    end
  end
end

KantoReloaded::EconomySystem.install
