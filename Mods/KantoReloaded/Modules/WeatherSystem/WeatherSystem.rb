#==============================================================================
# Kanto Reloaded - Weather System
#==============================================================================

module KantoReloaded
  module WeatherSystem
    class AudioSettingsScene < KantoReloaded::SettingsUI::BaseScene
      def scene_title
        "Weather Audio"
      end

      def scene_description
        "Configure continuous weather ambience and randomized thunder audio."
      end

      def pbGetOptions(_inloadscreen = false)
        [
          setting_row(AUDIO_SETTING),
          setting_row(RAIN_AUDIO_SETTING),
          setting_row(THUNDER_AUDIO_SETTING)
        ].compact
      end

      private

      def setting_row(key)
        definition = KantoReloaded::Settings.definition(key)
        return nil unless definition
        KantoReloaded::SettingsUI::RowFactory.build(
          definition, :scene => self, :weather_audio => true
        )
      end
    end

    class SettingsScene < KantoReloaded::SettingsUI::BaseScene
      def scene_title
        "Weather System"
      end

      def scene_description
        "Configure persistent regional weather patterns and forecasting."
      end

      def pbGetOptions(_inloadscreen = false)
        rows = []
        rows << KantoReloaded::Options::ActionButton.new(
          _INTL("Open Forecast"),
          proc { open_forecast },
          _INTL("View current and next-cycle weather across the world map.")
        )
        rows << setting_row(ENABLED_SETTING)
        rows << setting_row(SELECTION_SETTING)
        rows << setting_row(INTERVAL_SETTING)
        rows << setting_row(BATTLE_SETTING)
        rows << setting_row(ALERTS_SETTING)
        rows << KantoReloaded::Options::ActionButton.new(
          _INTL("Audio"),
          proc { open_audio_settings },
          _INTL("Configure weather ambience and thunder audio.")
        )
        rows << KantoReloaded::Options::TextDisplayOption.new(
          _INTL("Current Location"),
          proc { WeatherSystem.current_summary },
          _INTL("Weather currently active at the player's location.")
        )
        rows << KantoReloaded::Options::TextDisplayOption.new(
          _INTL("Next Update"),
          proc { Simulation.format_remaining },
          _INTL("In-game time remaining before the forecast becomes current.")
        )
        rows << KantoReloaded::Options::ActionButton.new(
          _INTL("Reset Module"),
          proc { reset_module },
          _INTL("Restore Weather System settings and regenerate its forecasts.")
        )
        rows.compact
      end

      private

      def setting_row(key)
        definition = KantoReloaded::Settings.definition(key)
        return nil unless definition
        KantoReloaded::SettingsUI::RowFactory.build(
          definition, :scene => self, :weather_system => true
        )
      end

      def open_forecast
        pbFadeOutIn { KantoReloaded::WeatherSystem::Forecast.open }
      end

      def open_audio_settings
        pbFadeOutIn do
          PokemonOptionScreen.new(
            KantoReloaded::WeatherSystem::AudioSettingsScene.new
          ).pbStartScreen
        end
      end

      def reset_module
        return unless KantoReloaded::PopupWindow.confirm(
          _INTL("Reset Weather System settings and regenerate all weather?"),
          :default => false, :serious => true, :theme => :warning
        )
        KantoReloaded::Settings.reset_module(MODULE_ID)
        KantoReloaded::SaveData.delete(
          MODULE_ID, nil, :section => :modules
        ) if defined?(KantoReloaded::SaveData)
        WeatherSystem.cell_map.rebuild!
        Simulation.ensure_state!
        Alerts.dispose
        WeatherSystem.apply_current_weather
        sync_window_values
        KantoReloaded::Toast.success(_INTL("Weather System reset."))
      end
    end

    class << self
      def boot
        return true if @booted
        register_settings
        migrate_audio_toggle_settings!
        register_events
        register_overworld_menu
        hooks = install_hooks
        Simulation.ensure_state!
        @booted = hooks.all?
        apply_current_weather if enabled?
        state = @booted ? "ready" : "partial"
        log_info("Weather System integration #{state}")
        @booted
      rescue StandardError => e
        @booted = false
        log_exception("Weather System failed to boot", e)
        false
      end

      def enabled?
        truthy_setting(ENABLED_SETTING, false)
      end

      def battle_weather?
        truthy_setting(BATTLE_SETTING, true)
      end

      def alerts?
        truthy_setting(ALERTS_SETTING, true)
      end

      def custom_audio?
        truthy_setting(AUDIO_SETTING, false)
      end

      def random_weather_selection?
        index = KantoReloaded::Settings.get(SELECTION_SETTING, 0).to_i
        WEATHER_SELECTION_MODES[index] == :random
      rescue
        false
      end

      def rain_audio?
        truthy_setting(RAIN_AUDIO_SETTING, true)
      end

      def thunder_audio?
        truthy_setting(THUNDER_AUDIO_SETTING, true)
      end

      def migrate_audio_toggle_settings!
        return true unless defined?(KantoReloaded::GlobalSettings)
        pairs = {
          RAIN_AUDIO_SETTING => LEGACY_RAIN_VOLUME_SETTING,
          THUNDER_AUDIO_SETTING => LEGACY_THUNDER_VOLUME_SETTING
        }
        pairs.each do |setting, legacy_setting|
          next unless KantoReloaded::GlobalSettings.stored?(legacy_setting)
          migrated = KantoReloaded::GlobalSettings.stored?(setting)
          unless migrated
            legacy = KantoReloaded::GlobalSettings.get(legacy_setting, 50)
            result = KantoReloaded::Settings.set(
              setting, truthy?(legacy), :notify => false
            )
            migrated = !result.nil?
          end
          KantoReloaded::GlobalSettings.delete(legacy_setting) if migrated
        end
        true
      rescue StandardError => e
        log_exception("Failed to migrate weather audio toggles", e)
        false
      end

      def forecast_view?
        return false unless defined?(KantoReloaded::SaveData)
        !!KantoReloaded::SaveData.get(
          :overworld_menu, FORECAST_VIEW_SETTING, false, :section => :systems
        )
      rescue
        false
      end

      def forecast_view=(value)
        normalized = value == true || value.to_i == 1 rescue false
        KantoReloaded::SaveData.set(
          :overworld_menu, FORECAST_VIEW_SETTING, normalized,
          :section => :systems
        ) if defined?(KantoReloaded::SaveData)
        normalized
      end

      def current_state
        return clear_state unless defined?($game_map) && $game_map
        Simulation.current_for_map($game_map.map_id)
      rescue
        clear_state
      end

      def forecast_state
        return clear_state unless defined?($game_map) && $game_map
        Simulation.forecast_for_map($game_map.map_id)
      rescue
        clear_state
      end

      def current_summary
        return _INTL("Disabled") unless enabled?
        state = current_state
        _INTL("{1} / Intensity {2}",
              weather_name(state[:weather]), state[:intensity])
      rescue
        _INTL("Unavailable")
      end

      def set_current_weather_front(weather, intensity = 3)
        return false unless enabled?
        map_id = current_map_id
        metadata = map_metadata(map_id)
        return false unless map_id > 0 &&
                            weather_map_eligible?(map_id, metadata)
        previous = current_state
        return false unless Simulation.set_front_for_map!(
          map_id, weather, intensity
        )
        @weather_owner = nil
        apply_current_weather
        WeatherAudio.map_changed!
        Alerts.show_change(previous, current_state)
        true
      rescue StandardError => e
        log_exception("Current-map weather front failed", e)
        false
      end

      def restore_current_weather_front(reapply = true)
        previous = current_state
        restored = Simulation.restore_front_for_map!(current_map_id)
        return false unless restored
        return true unless reapply
        @weather_owner = nil
        apply_current_weather
        WeatherAudio.map_changed!
        Alerts.show_change(previous, current_state)
        true
      rescue StandardError => e
        log_exception("Current-map weather front restoration failed", e)
        false
      end

      alias set_current_weather_override set_current_weather_front
      alias clear_current_weather_override restore_current_weather_front

      def kr_weather_owned?
        @weather_owner == :kanto_reloaded &&
          @owned_map_id.to_i == current_map_id
      end

      def external_weather_owned?
        @weather_owner == :external &&
          @owned_map_id.to_i == current_map_id
      end

      def apply_current_weather
        unless enabled?
          clear_owned_weather
          return false
        end
        map_id = current_map_id
        return false if map_id <= 0
        metadata = map_metadata(map_id)
        unless weather_map_eligible?(map_id, metadata)
          clear_owned_weather
          return false
        end
        state = Simulation.current_for_map(map_id)
        if state[:admin_forced]
          apply_weather(state[:weather], state[:intensity])
          @weather_owner = :kanto_reloaded
          @owned_map_id = map_id
          WeatherAudio.weather_changed!
          return true
        end
        weather_data = metadata && metadata.respond_to?(:weather) ?
          metadata.weather : nil
        if reserved_authored_weather?(weather_data)
          relinquish_weather!(:authored_map)
          WeatherAudio.sync
          return false
        end
        return false if external_weather_owned?
        apply_weather(state[:weather], state[:intensity])
        @weather_owner = :kanto_reloaded
        @owned_map_id = map_id
        WeatherAudio.weather_changed!
        true
      rescue StandardError => e
        log_exception("Weather application failed", e)
        false
      end

      def clear_owned_weather
        if kr_weather_owned? && defined?($game_screen) && $game_screen
          apply_weather(:None, 0)
        end
        relinquish_weather!(:clear)
        WeatherAudio.stop!
        true
      rescue
        false
      end

      def on_cycle_advanced(cycles, previous_snapshot = nil)
        log_debug("Advanced #{cycles} weather cycle(s)")
        map_id = current_map_id
        cell = cell_map.cell_for_map(map_id)
        previous = if cell && previous_snapshot.is_a?(Hash)
                     Simulation.state_for_cell(
                       cell[:key], :current, previous_snapshot
                     )
                   else
                     clear_state
                   end
        applied = apply_current_weather
        current = current_state
        Alerts.show_change(previous, current) if applied && !current[:authored]
        true
      end

      def on_map_change
        Alerts.dispose
        @weather_owner = nil
        @owned_map_id = current_map_id
        Simulation.ensure_state! if enabled?
        apply_current_weather
        WeatherAudio.map_changed!
        true
      rescue StandardError => e
        log_exception("Weather map-change update failed", e)
        false
      end

      def begin_map_change
        @map_change_depth = @map_change_depth.to_i + 1
        @map_change_weather_types = [] if @map_change_depth == 1
        true
      end

      def finish_map_change
        @map_change_depth = [@map_change_depth.to_i - 1, 0].max
        return true if @map_change_depth > 0
        calls = Array(@map_change_weather_types)
        @map_change_weather_types = nil
        metadata = map_metadata(current_map_id)
        weather_data = metadata && metadata.respond_to?(:weather) ?
          metadata.weather : nil
        authored = reserved_authored_weather?(weather_data)
        replaced_authored = replaceable_authored_weather?(weather_data)
        scripted = calls.reverse.find do |weather|
          normalize_weather(weather) != :None
        end
        if scripted && !authored && !replaced_authored
          @weather_owner = :external
          @owned_map_id = current_map_id
          WeatherAudio.stop!
          log_debug(
            "Preserved scripted map-change weather #{normalize_weather(scripted)}"
          )
          return true
        end
        on_map_change
      rescue StandardError => e
        log_exception("Weather map-change finalization failed", e)
        false
      end

      def abort_map_change
        @map_change_depth = 0
        @map_change_weather_types = nil
        true
      end

      def map_change_in_progress?
        @map_change_depth.to_i > 0
      end

      def update
        Alerts.update
        restore_pending_save_weather
        return false unless tick_due?
        Simulation.advance_due_cycles! if enabled?
        WeatherAudio.sync
        true
      rescue StandardError => e
        log_exception("Weather update failed", e)
        false
      end

      def schedule_save_weather_restore
        Alerts.dispose
        @pending_save_weather_restore = true
        @pending_save_restore_map_id = nil
        @pending_save_restore_updates = 0
        @weather_owner = nil
        @owned_map_id = nil
        WeatherAudio.stop!
        true
      rescue
        false
      end

      def restore_pending_save_weather
        return false unless @pending_save_weather_restore
        map_id = current_map_id
        return false if map_id <= 0 || !defined?($game_screen) || !$game_screen
        return false unless overworld_weather_restore_ready?
        if @pending_save_restore_map_id != map_id
          @pending_save_restore_map_id = map_id
          @pending_save_restore_updates = 0
          return false
        end
        @pending_save_restore_updates = @pending_save_restore_updates.to_i + 1
        return false if @pending_save_restore_updates < SAVE_RESTORE_UPDATE_DELAY
        @weather_owner = nil
        @owned_map_id = map_id
        state = current_state
        expected = saved_weather_restore_expected?(map_id, state)
        applied = expected ? apply_current_weather : false
        return false if expected && !applied
        @pending_save_weather_restore = false
        @pending_save_restore_map_id = nil
        @pending_save_restore_updates = 0
        log_debug(
          "Restored saved weather after #{SAVE_RESTORE_UPDATE_DELAY} overworld " \
          "updates: map=#{map_id}, weather=#{state[:weather]}, " \
          "intensity=#{state[:intensity]}, expected=#{expected}, applied=#{applied}"
        )
        true
      rescue StandardError => e
        log_exception("Saved weather restoration failed", e)
        false
      end

      def overworld_weather_restore_ready?
        return false unless defined?($scene) && defined?(Scene_Map) &&
                            $scene.is_a?(Scene_Map)
        return true unless defined?($game_temp) && $game_temp
        return false if $game_temp.respond_to?(:player_transferring) &&
                        $game_temp.player_transferring
        return false if $game_temp.respond_to?(:transition_processing) &&
                        $game_temp.transition_processing
        true
      rescue
        false
      end

      def saved_weather_restore_expected?(map_id, state)
        return false unless enabled?
        metadata = map_metadata(map_id)
        return false unless weather_map_eligible?(map_id, metadata)
        return true if state[:admin_forced]
        weather_data = metadata.respond_to?(:weather) ? metadata.weather : nil
        !reserved_authored_weather?(weather_data)
      rescue
        false
      end

      def observe_weather_call(type, _power, _duration)
        return if internal_weather_call?
        if map_change_in_progress?
          @map_change_weather_types ||= []
          @map_change_weather_types << type
          return
        end
        @weather_owner = :external
        @owned_map_id = current_map_id
        WeatherAudio.stop!
        log_debug("Relinquished weather ownership to an external caller")
      rescue
        nil
      end

      def after_prepare_battle(battle)
        return unless battle
        return if explicit_battle_weather?
        handled, synchronized = MultiplayerSync.battle_weather
        if handled
          battle.defaultWeather = synchronized
          return
        end
        return unless kr_weather_owned?
        battle.defaultWeather = if battle_weather?
                                  battle_weather_for(current_state[:weather])
                                else
                                  :None
                                end
      rescue StandardError => e
        log_exception("Battle weather integration failed", e)
      end

      def interval_changed
        return true if restoring_saved_settings?
        Simulation.reschedule!
        true
      end

      def selection_changed
        return true if restoring_saved_settings?
        Simulation.regenerate!
        apply_current_weather
        true
      end

      def enabled_changed(value)
        return true if restoring_saved_settings?
        if truthy?(value)
          Simulation.resume!
          apply_current_weather
        else
          Simulation.suspend!
          clear_owned_weather
        end
        true
      end

      def restoring_saved_settings?
        defined?(KantoReloaded::Settings) &&
          KantoReloaded::Settings.respond_to?(:callback_application_reason) &&
          KantoReloaded::Settings.callback_application_reason == :save_loaded
      rescue
        false
      end

      def custom_audio_changed
        if custom_audio?
          WeatherAudio.map_changed!
        else
          WeatherAudio.stop!
        end
        true
      end

      def alerts_changed(value)
        Alerts.dispose unless truthy?(value)
        true
      end

      def rain_audio_changed
        if rain_audio?
          WeatherAudio.rain_audio_changed!
        else
          WeatherAudio.stop!
        end
        true
      end

      def thunder_audio_changed
        WeatherAudio.thunder_audio_changed!
        true
      end

      def log_info(message)
        KantoReloaded::Log.info(message, :weather_system) if defined?(KantoReloaded::Log)
      rescue
        nil
      end

      def log_debug(message)
        KantoReloaded::Log.debug(message, :weather_system) if defined?(KantoReloaded::Log)
      rescue
        nil
      end

      def log_warning(message)
        KantoReloaded::Log.warning(message, :weather_system) if defined?(KantoReloaded::Log)
      rescue
        nil
      end

      def log_saved_fronts(action, state)
        bucket = state.is_a?(Hash) ? state : {}
        current = bucket["current"]
        forecast = bucket["forecast"]
        log_debug(
          "#{action} weather fronts: current=#{current.is_a?(Hash) ? current.length : 0}, " \
          "forecast=#{forecast.is_a?(Hash) ? forecast.length : 0}, " \
          "next_cycle_at=#{bucket["next_cycle_at"].to_i}"
        )
      rescue
        nil
      end

      private

      def register_settings
        KantoReloaded::Settings.register(SETTINGS_ACTION, {
          :name => "Weather System",
          :description => "Configure persistent regional weather and forecasting.",
          :type => :button,
          :category => :gameplay,
          :owner => :kanto_reloaded,
          :priority => 1520,
          :on_press => proc {
            pbFadeOutIn {
              PokemonOptionScreen.new(
                KantoReloaded::WeatherSystem::SettingsScene.new
              ).pbStartScreen
            }
          }
        })
        module_visible = proc do |context|
          context.is_a?(Hash) &&
            !!(context[:weather_system] || context["weather_system"] ||
               context[:weather_audio] || context["weather_audio"])
        end
        KantoReloaded::Settings.register(ENABLED_SETTING, {
          :name => "Weather System",
          :description => "Enable persistent random weather fronts and regional patterns.",
          :type => :toggle,
          :default => true,
          :category => :gameplay,
          :owner => MODULE_ID,
          :priority => 10,
          :visible_if => module_visible
        })
        KantoReloaded::Settings.register(INTERVAL_SETTING, {
          :name => "Update Interval",
          :description => "Choose how many in-game hours pass between weather cycles.",
          :type => :enum,
          :values => ["3 Hours", "6 Hours", "12 Hours", "24 Hours"],
          :default => 1,
          :category => :gameplay,
          :owner => MODULE_ID,
          :priority => 30,
          :visible_if => module_visible
        })
        KantoReloaded::Settings.register(SELECTION_SETTING, {
          :name => "Weather Selection",
          :description => "Use climate-weighted weather or choose every base weather equally.",
          :type => :enum,
          :values => ["Climates", "Random"],
          :default => 0,
          :category => :gameplay,
          :owner => MODULE_ID,
          :priority => 20,
          :visible_if => module_visible
        })
        KantoReloaded::Settings.register(BATTLE_SETTING, {
          :name => "Battle Weather",
          :description => "Carry Kanto Reloaded overworld weather into battles.",
          :type => :toggle,
          :default => true,
          :category => :gameplay,
          :owner => MODULE_ID,
          :priority => 40,
          :visible_if => module_visible
        })
        KantoReloaded::Settings.register(ALERTS_SETTING, {
          :name => "Weather Alerts",
          :description => "Show a non-pausing alert when local weather changes.",
          :type => :toggle,
          :default => true,
          :category => :gameplay,
          :owner => MODULE_ID,
          :priority => 45,
          :visible_if => module_visible
        })
        KantoReloaded::Settings.register(AUDIO_SETTING, {
          :name => "Custom Audio",
          :description => "Use dedicated rain and storm ambience for Kanto Reloaded weather.",
          :type => :toggle,
          :default => true,
          :scope => :global,
          :category => :gameplay,
          :owner => MODULE_ID,
          :priority => 50,
          :visible_if => module_visible
        })
        KantoReloaded::Settings.register(RAIN_AUDIO_SETTING, {
          :name => "Rain Audio",
          :description => "Play continuous rain and storm ambience.",
          :type => :toggle,
          :default => true,
          :scope => :global,
          :category => :gameplay,
          :owner => MODULE_ID,
          :priority => 60,
          :visible_if => module_visible,
          :enabled_if => proc { WeatherSystem.custom_audio? }
        })
        KantoReloaded::Settings.register(THUNDER_AUDIO_SETTING, {
          :name => "Thunder Audio",
          :description => "Play randomized thunder during storms.",
          :type => :toggle,
          :default => true,
          :scope => :global,
          :category => :gameplay,
          :owner => MODULE_ID,
          :priority => 70,
          :visible_if => module_visible,
          :enabled_if => proc { WeatherSystem.custom_audio? }
        })
        KantoReloaded::Settings.register_on_change(
          ENABLED_SETTING, :weather_system_enabled, :owner => MODULE_ID
        ) { |value, _old, _definition| WeatherSystem.enabled_changed(value) }
        KantoReloaded::Settings.register_on_change(
          INTERVAL_SETTING, :weather_system_interval, :owner => MODULE_ID
        ) { |_value, _old, _definition| WeatherSystem.interval_changed }
        KantoReloaded::Settings.register_on_change(
          SELECTION_SETTING, :weather_system_selection, :owner => MODULE_ID
        ) { |_value, _old, _definition| WeatherSystem.selection_changed }
        KantoReloaded::Settings.register_on_change(
          ALERTS_SETTING, :weather_system_alerts, :owner => MODULE_ID
        ) { |value, _old, _definition| WeatherSystem.alerts_changed(value) }
        KantoReloaded::Settings.register_on_change(
          AUDIO_SETTING, :weather_system_audio, :owner => MODULE_ID
        ) { |_value, _old, _definition| WeatherSystem.custom_audio_changed }
        KantoReloaded::Settings.register_on_change(
          RAIN_AUDIO_SETTING, :weather_system_rain_audio,
          :owner => MODULE_ID
        ) { |_value, _old, _definition| WeatherSystem.rain_audio_changed }
        KantoReloaded::Settings.register_on_change(
          THUNDER_AUDIO_SETTING, :weather_system_thunder_audio,
          :owner => MODULE_ID
        ) { |_value, _old, _definition| WeatherSystem.thunder_audio_changed }
        true
      end

      def register_events
        if defined?(KantoReloaded::Events)
          KantoReloaded::Events.on(
            :kanto_reloaded_save_loaded, :weather_system_load, :priority => 220
          ) do |_context|
            KantoReloaded::WeatherSystem.cell_map.rebuild!
            state = KantoReloaded::WeatherSystem::Simulation.ensure_state!
            KantoReloaded::WeatherSystem.log_saved_fronts(
              "Loaded", state
            )
            KantoReloaded::WeatherSystem.schedule_save_weather_restore
          end
          KantoReloaded::Events.on(
            :kanto_reloaded_save_new_game, :weather_system_new_game,
            :priority => 220
          ) do |_context|
            KantoReloaded::WeatherSystem.cell_map.rebuild!
            KantoReloaded::WeatherSystem::Simulation.ensure_state!
            KantoReloaded::WeatherSystem.schedule_save_weather_restore
          end
        end
        true
      end

      def register_overworld_menu
        return false unless defined?(OverworldMenu) &&
                            OverworldMenu.respond_to?(:register)
        OverworldMenu.register(
          :weather_forecast,
          :label => "Weather Forecast",
          :priority => 30,
          :default_enabled => true,
          :status => proc { WeatherSystem.current_status },
          :condition => proc { WeatherSystem.enabled? },
          :handler => proc { |screen|
            screen.run_with_overlay_hidden do
              KantoReloaded::WeatherSystem::Forecast.open
            end
            nil
          }
        )
        if OverworldMenu.respond_to?(:register_feature)
          OverworldMenu.register_feature(
            :weather_forecast_view,
            :label => "Forecast View",
            :priority => 20,
            :condition => proc { WeatherSystem.enabled? },
            :get => proc { WeatherSystem.forecast_view? },
            :set => proc { |value| WeatherSystem.forecast_view = value }
          )
        end
        if OverworldMenu.respond_to?(:register_companion_panel)
          OverworldMenu.register_companion_panel(
            :weather_forecast,
            :priority => 20,
            :height => 100,
            :condition => proc {
              WeatherSystem.enabled? && WeatherSystem.forecast_view?
            },
            :draw => proc { |scene, sprite, bounds|
              Forecast.draw_compact(scene, sprite, bounds)
            }
          )
        end
        true
      end

      def install_hooks
        results = []
        scene_update_hook = false
        if defined?(Scene_Map)
          scene_update_hook = KantoReloaded::Hooks.wrap(
            Scene_Map, :update, :weather_system_scene_update
          ) do |hook, *arguments|
            result = hook.call(*arguments)
            KantoReloaded::WeatherSystem.update
            result
          end
          if Scene_Map.method_defined?(:dispose) ||
             Scene_Map.private_method_defined?(:dispose)
            results << KantoReloaded::Hooks.wrap(
              Scene_Map, :dispose, :weather_system_alert_dispose
            ) do |hook, *arguments|
              KantoReloaded::WeatherSystem::Alerts.dispose
              hook.call(*arguments)
            end
          end
        end
        results << (scene_update_hook || register_map_update_fallback)
        map_change_hook = false
        if defined?(PokemonMapFactory)
          map_change_hook = KantoReloaded::Hooks.wrap(
            PokemonMapFactory, :setMapChanged, :weather_system_map_change
          ) do |hook, *arguments|
            KantoReloaded::WeatherSystem.begin_map_change
            result = hook.call(*arguments)
            KantoReloaded::WeatherSystem.finish_map_change
            result
          ensure
            if KantoReloaded::WeatherSystem.map_change_in_progress?
              KantoReloaded::WeatherSystem.abort_map_change
            end
          end
          results << map_change_hook
        end
        register_map_change_fallback unless map_change_hook
        results << KantoReloaded::Hooks.wrap(
          Game_Screen, :weather, :weather_system_ownership
        ) do |hook, type, power, duration|
          result = hook.call
          KantoReloaded::WeatherSystem.observe_weather_call(type, power, duration)
          result
        end if defined?(Game_Screen)
        results << KantoReloaded::Hooks.wrap(
          Object, :pbPrepareBattle, :weather_system_battle
        ) do |hook, battle, *arguments|
          result = hook.call(battle, *arguments)
          KantoReloaded::WeatherSystem.after_prepare_battle(battle)
          result
        end
        if defined?(Game_System)
          results << KantoReloaded::Hooks.wrap(
            Game_System, :bgs_play, :weather_system_audio_play
          ) do |hook, bgs|
            result = hook.call
            KantoReloaded::WeatherSystem::WeatherAudio.observe_external_change(
              :play, bgs
            )
            result
          end
          results << KantoReloaded::Hooks.wrap(
            Game_System, :bgs_stop, :weather_system_audio_stop
          ) do |hook|
            result = hook.call
            KantoReloaded::WeatherSystem::WeatherAudio.observe_external_change(
              :stop
            )
            result
          end
          results << KantoReloaded::Hooks.wrap(
            Game_System, :bgs_fade, :weather_system_audio_fade
          ) do |hook, time|
            result = hook.call
            KantoReloaded::WeatherSystem::WeatherAudio.observe_external_change(
              :fade, time
            )
            result
          end
          results << KantoReloaded::Hooks.wrap(
            Game_System, :bgs_pause, :weather_system_battle_audio
          ) do |hook, *arguments|
            if KantoReloaded::WeatherSystem::WeatherAudio.continue_in_battle?
              nil
            else
              KantoReloaded::WeatherSystem::WeatherAudio.with_internal do
                hook.call(*arguments)
              end
            end
          end
        end
        results << MultiplayerSync.install_hooks
        results.compact
      end

      def register_map_update_fallback
        return false unless defined?(Events) &&
                            Events.respond_to?(:onMapUpdate)
        return true if $KANTO_RELOADED_WEATHER_MAP_UPDATE
        Events.onMapUpdate += proc { |_sender, _event|
          KantoReloaded::WeatherSystem.update
        }
        $KANTO_RELOADED_WEATHER_MAP_UPDATE = true
        log_warning(
          "Using fallback Weather System map-update event integration"
        )
        true
      rescue StandardError => e
        log_exception("Weather map-update fallback failed", e)
        false
      end

      def register_map_change_fallback
        return false unless defined?(Events) &&
                            Events.respond_to?(:onMapChange)
        return true if $KANTO_RELOADED_WEATHER_MAP_CHANGE
        Events.onMapChange += proc { |_sender, _event|
          KantoReloaded::WeatherSystem.on_map_change
        }
        $KANTO_RELOADED_WEATHER_MAP_CHANGE = true
        log_warning(
          "Using fallback Weather System map-change event integration"
        )
        true
      rescue StandardError => e
        log_exception("Weather map-change fallback failed", e)
        false
      end

      def current_status
        state = current_state
        weather_name(state[:weather])
      rescue
        ""
      end

      def apply_weather(weather, intensity)
        return false unless defined?($game_screen) && $game_screen
        @internal_weather_depth = @internal_weather_depth.to_i + 1
        power = weather == :None ? 0 : [[intensity.to_i, 1].max, 9].min
        $game_screen.weather(weather, power, 20)
        true
      ensure
        @internal_weather_depth = [@internal_weather_depth.to_i - 1, 0].max
      end

      def internal_weather_call?
        @internal_weather_depth.to_i > 0
      end

      def relinquish_weather!(reason)
        @weather_owner = nil
        @owned_map_id = current_map_id
        log_debug("Weather ownership released: #{reason}")
      end

      def explicit_battle_weather?
        return false unless defined?($PokemonTemp) && $PokemonTemp &&
                            $PokemonTemp.respond_to?(:battleRules)
        rules = $PokemonTemp.battleRules
        rules && !rules["defaultWeather"].nil?
      rescue
        false
      end

      def tick_due?
        frame = defined?(Graphics) ? Graphics.frame_count.to_i : 0
        return false if frame < @next_tick_frame.to_i
        rate = defined?(Graphics) ? Graphics.frame_rate.to_i : 40
        @next_tick_frame = frame + [rate, 1].max
        true
      rescue
        true
      end

      def truthy_setting(key, fallback)
        truthy?(KantoReloaded::Settings.get(key, fallback))
      rescue
        fallback
      end

      def truthy?(value)
        value == true || (value.is_a?(Numeric) && value.to_i != 0) ||
          ["true", "on", "yes", "enabled", "1"].include?(value.to_s.downcase)
      end

      def current_map_id
        defined?($game_map) && $game_map ? $game_map.map_id.to_i : 0
      rescue
        0
      end

      def map_metadata(map_id)
        return nil unless defined?(GameData::MapMetadata)
        GameData::MapMetadata.try_get(map_id)
      rescue
        nil
      end

      def clear_state
        { :weather => :None, :intensity => 0, :trend => :steady,
          :cell => nil, :cell_key => nil, :authored => false }
      end
    end
  end
end

KantoReloaded::WeatherSystem.boot
