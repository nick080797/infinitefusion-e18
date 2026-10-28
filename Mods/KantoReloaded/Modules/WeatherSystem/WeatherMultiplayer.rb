#==============================================================================
# Kanto Reloaded - Weather Multiplayer Compatibility
#==============================================================================

module KantoReloaded
  module WeatherSystem
    module MultiplayerSync
      PROTOCOL = 1
      HOST_CAPABILITY_KEY = "kanto_reloaded_weather_host"
      GUEST_CAPABILITY_KEY = "kanto_reloaded_weather_guest"
      PROTOCOL_KEY = "kanto_reloaded_weather_protocol"
      WEATHER_KEY = "kanto_reloaded_battle_weather"
      BATTLE_WEATHERS = [
        :None, :Rain, :Hail, :Sandstorm, :Sun, :StrongWinds
      ].freeze

      class << self
        def install_hooks
          install_pvp_hooks
          true
        rescue StandardError => e
          WeatherSystem.log_exception("Weather multiplayer hooks failed", e)
          false
        end

        def announce_pvp!
          return false unless pvp_session? && defined?(MultiplayerClient) &&
                              MultiplayerClient.respond_to?(:pvp_update_settings)
          battle_id = PvPBattleState.battle_id
          key = [battle_id.to_s, local_role]
          return true if @announced_pvp == key
          settings = PvPBattleState.settings.dup
          MultiplayerClient.pvp_update_settings(battle_id, settings)
          @announced_pvp = key
          true
        rescue StandardError => e
          WeatherSystem.log_exception("PvP weather capability announcement failed", e)
          false
        end

        def decorate_pvp_settings(battle_id, settings, starting = false)
          data = settings.is_a?(Hash) ? settings.dup : {}
          if local_role == :host
            data[HOST_CAPABILITY_KEY] = PROTOCOL
          else
            data[GUEST_CAPABILITY_KEY] = PROTOCOL
          end
          return data unless starting && local_role == :host
          reset_tracking_for(battle_id)
          unless peer_capable?(battle_id)
            @host_battle_weather[battle_id.to_s] = :None
            WeatherSystem.log_warning(
              "PvP peer did not confirm Weather System support; " \
              "KR battle weather was disabled"
            )
            return data
          end
          weather = local_battle_weather
          data[PROTOCOL_KEY] = PROTOCOL
          data[WEATHER_KEY] = weather.to_s
          @host_battle_weather[battle_id.to_s] = weather
          data
        rescue StandardError => e
          WeatherSystem.log_exception("PvP weather payload failed", e)
          settings.is_a?(Hash) ? settings.dup : {}
        end

        def observe_pvp_settings(settings)
          return false unless pvp_session? && settings.is_a?(Hash)
          battle_id = PvPBattleState.battle_id.to_s
          reset_tracking_for(battle_id)
          key = local_role == :host ? GUEST_CAPABILITY_KEY : HOST_CAPABILITY_KEY
          value = setting_value(settings, key).to_i
          @peer_capable[battle_id] = true if value == PROTOCOL
          true
        rescue
          false
        end

        # Returns [handled, weather]. Multiplayer battles are always handled so
        # an unsynchronized local front can never leak into only one client.
        def battle_weather
          if pvp_active?
            battle_id = PvPBattleState.battle_id.to_s
            if local_role == :host
              return [true, normalize_battle_weather(
                @host_battle_weather[battle_id]
              )]
            end
            settings = PvPBattleState.settings
            protocol = setting_value(settings, PROTOCOL_KEY).to_i
            weather = setting_value(settings, WEATHER_KEY)
            return [true, :None] unless protocol == PROTOCOL && weather
            return [true, normalize_battle_weather(weather)]
          end
          if defined?(CoopBattleState) && CoopBattleState.respond_to?(:in_coop_battle?) &&
             CoopBattleState.in_coop_battle?
            return [true, :None]
          end
          if defined?(CoopBattleTransaction) &&
             CoopBattleTransaction.respond_to?(:active?) &&
             CoopBattleTransaction.active?
            return [true, :None]
          end
          [false, nil]
        rescue StandardError => e
          WeatherSystem.log_exception("Multiplayer battle weather lookup failed", e)
          [true, :None]
        end

        private

        def install_pvp_hooks
          return true unless defined?(PvPBattleState) && defined?(MultiplayerClient)
          results = []
          if PvPBattleState.respond_to?(:update_settings)
            results << KantoReloaded::Hooks.wrap(
              PvPBattleState, :update_settings, :weather_pvp_settings_observer,
              :singleton => true
            ) do |hook, settings, *arguments|
              result = hook.call(settings, *arguments)
              KantoReloaded::WeatherSystem::MultiplayerSync.observe_pvp_settings(
                settings
              )
              result
            end
          end
          if MultiplayerClient.respond_to?(:pvp_update_settings)
            results << KantoReloaded::Hooks.wrap(
              MultiplayerClient, :pvp_update_settings, :weather_pvp_capability,
              :singleton => true
            ) do |hook, battle_id, settings, *arguments|
              payload = KantoReloaded::WeatherSystem::MultiplayerSync.
                decorate_pvp_settings(battle_id, settings, false)
              hook.call(battle_id, payload, *arguments)
            end
          end
          if MultiplayerClient.respond_to?(:pvp_start_battle)
            results << KantoReloaded::Hooks.wrap(
              MultiplayerClient, :pvp_start_battle, :weather_pvp_start,
              :singleton => true
            ) do |hook, battle_id, settings, *arguments|
              payload = KantoReloaded::WeatherSystem::MultiplayerSync.
                decorate_pvp_settings(battle_id, settings, true)
              hook.call(battle_id, payload, *arguments)
            end
          end
          if defined?(Scene_PvPSettings) &&
             Scene_PvPSettings.method_defined?(:main)
            results << KantoReloaded::Hooks.wrap(
              Scene_PvPSettings, :main, :weather_pvp_announce
            ) do |hook, *arguments|
              KantoReloaded::WeatherSystem::MultiplayerSync.announce_pvp!
              hook.call(*arguments)
            end
          end
          results.compact.all?
        end

        def pvp_active?
          defined?(PvPBattleState) &&
            PvPBattleState.respond_to?(:in_pvp_battle?) &&
            PvPBattleState.in_pvp_battle?
        rescue
          false
        end

        def pvp_session?
          defined?(PvPBattleState) &&
            PvPBattleState.respond_to?(:battle_id) &&
            !PvPBattleState.battle_id.nil?
        rescue
          false
        end

        def local_role
          return :guest unless defined?(PvPBattleState) &&
                               PvPBattleState.respond_to?(:is_initiator?)
          PvPBattleState.is_initiator? ? :host : :guest
        rescue
          :guest
        end

        def peer_capable?(battle_id)
          !!(@peer_capable && @peer_capable[battle_id.to_s])
        end

        def reset_tracking_for(battle_id)
          key = battle_id.to_s
          @peer_capable ||= {}
          @host_battle_weather ||= {}
          @peer_capable.delete_if { |stored, _value| stored != key }
          @host_battle_weather.delete_if { |stored, _value| stored != key }
          true
        end

        def local_battle_weather
          return :None unless WeatherSystem.enabled? &&
                              WeatherSystem.battle_weather? &&
                              WeatherSystem.kr_weather_owned?
          normalize_battle_weather(
            WeatherSystem.battle_weather_for(
              WeatherSystem.current_state[:weather]
            )
          )
        rescue
          :None
        end

        def setting_value(settings, key)
          settings[key] || settings[key.to_sym]
        rescue
          nil
        end

        def normalize_battle_weather(weather)
          value = weather.respond_to?(:to_sym) ? weather.to_sym : :None
          BATTLE_WEATHERS.include?(value) ? value : :None
        rescue
          :None
        end
      end
    end
  end
end
