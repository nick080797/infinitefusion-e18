#==============================================================================
# Kanto Reloaded - Wild Link
#==============================================================================

module KantoReloaded
  module WildLink
    class << self
      def boot
        return true if @booted
        register_settings
        register_overworld_menu
        runtime_ready = Runtime.install
        @booted = !!runtime_ready
        state = @booted ? "ready" : "partial"
        KantoReloaded::Log.info(
          "Wild Link integration #{state}", :wild_link
        ) if defined?(KantoReloaded::Log)
        @booted
      rescue StandardError => e
        @booted = false
        WildLink.log_exception("Wild Link failed to boot", e)
        false
      end

      def open
        unless available_context?
          WildLink.message(
            _INTL("Wild Link is unavailable during this map or battle context."),
            :theme => :warning
          )
          return false
        end
        UI.open
      end

      def available_context?
        return false unless $Trainer && $game_map && $PokemonEncounters
        return false unless defined?(Scene_Map) && $scene.is_a?(Scene_Map)
        return false if global_boolean(:pbInSafari?)
        return false if global_boolean(:pbInBugContest?)
        return false if $PokemonGlobal && $PokemonGlobal.partner
        true
      rescue StandardError
        false
      end

      def overworld_status
        current = Runtime.target
        return _INTL("Ready") unless current
        name = current[:unknown] ? _INTL("Rare Signal") :
          EncounterPools.species_name(current[:species])
        _INTL("{1} / Chain {2}", name, WildLink.runtime.chain)
      rescue StandardError
        _INTL("Ready")
      end

      private

      def register_settings
        KantoReloaded::Settings.register(SETTINGS_ACTION, {
          :name => "Wild Link",
          :description => "Configure targeted overworld Pokemon searches and progression.",
          :type => :button,
          :category => :gameplay,
          :owner => :kanto_reloaded,
          :priority => 1510,
          :on_press => proc {
            pbFadeOutIn {
              PokemonOptionScreen.new(
                KantoReloaded::WildLink::SettingsScene.new
              ).pbStartScreen
            }
          }
        })
        KantoReloaded::Settings.register(MAP_DATA_ACTION, {
          :name => "Gather Map Data",
          :description => "Create and upload map, encounter, Wild Link, and weather diagnostics.",
          :type => :button,
          :category => :utility,
          :owner => :kanto_reloaded,
          :priority => 15,
          :searchable => [
            "map", "metadata", "encounters", "wild link", "weather",
            "diagnostics", "export"
          ],
          :on_press => proc { KantoReloaded::WildLink::MapData.file }
        })
        KantoReloaded::Settings.register(CONTINUE_SETTING, {
          :name => "Continue Search",
          :description => "Choose what happens after a successful Wild Link battle.",
          :type => :enum,
          :values => ["Prompt", "Automatic", "Off"],
          :default => CONTINUE_PROMPT,
          :category => :gameplay,
          :owner => MODULE_ID,
          :priority => 10
        })
        KantoReloaded::Settings.register(SPRITES_SETTING, {
          :name => "Sprites",
          :description => "Show Pokemon icons or full battle sprites in Wild Link previews.",
          :type => :enum,
          :values => ["Icons", "Full Sprites"],
          :default => SPRITES_FULL,
          :category => :gameplay,
          :owner => MODULE_ID,
          :scope => :global,
          :priority => 20
        })
        KantoReloaded::Settings.register(MESSAGES_SETTING, {
          :name => "Messages",
          :description => "Show optional Wild Link prompts, warnings, and notifications.",
          :type => :toggle,
          :default => 1,
          :category => :gameplay,
          :owner => MODULE_ID,
          :priority => 30
        })
        KantoReloaded::Settings.register_on_change(
          SPRITES_SETTING, :wild_link_preview_cache,
          :owner => MODULE_ID
        ) do |_value, _old_value, _definition|
          KantoReloaded::WildLink::UI::PreviewCache.clear
        end
        true
      end

      def register_overworld_menu
        return false unless defined?(OverworldMenu) &&
                            OverworldMenu.respond_to?(:register)
        OverworldMenu.register(
          :wild_link,
          :label => "Wild Link",
          :priority => 35,
          :default_enabled => true,
          :status => proc { KantoReloaded::WildLink.overworld_status },
          :condition => proc {
            KantoReloaded::WildLink.available_context?
          },
          :handler => proc { |screen|
            result = screen.run_with_overlay_hidden do
              KantoReloaded::WildLink.open
            end
            result == :target_started ? :exit_menu : nil
          }
        )
      end

      def global_boolean(name)
        return false unless Object.private_method_defined?(name) ||
                            Object.method_defined?(name)
        !!Object.new.__send__(name)
      rescue StandardError
        false
      end
    end
  end
end

KantoReloaded::WildLink.boot
