#==============================================================================
# Kanto Reloaded - Wild Link Data
#==============================================================================

module KantoReloaded
  module WildLink
    MODULE_ID = :wild_link
    STATE_KEY = :state
    SETTINGS_ACTION = :wild_link_settings
    MAP_DATA_ACTION = :gather_map_data
    MESSAGES_SETTING = :"wild_link.messages"
    CONTINUE_SETTING = :"wild_link.continue_search"
    SPRITES_SETTING = :"wild_link.sprites"

    CONTINUE_PROMPT = 0
    CONTINUE_AUTOMATIC = 1
    CONTINUE_OFF = 2
    SPRITES_ICONS = 0
    SPRITES_FULL = 1
    SEARCH_LEVEL_CAP = 999

    METHOD_LABELS = {
      :land => "Land",
      :cave => "Cave",
      :surf => "Surf",
      :fishing => "Fishing",
      :headbutt => "Headbutt",
      :rock_smash => "Rock Smash"
    }.freeze

    class RuntimeState
      attr_accessor :target
      attr_accessor :chain
      attr_accessor :chain_key
      attr_accessor :pending_continue
      attr_accessor :stable_map_updates

      def initialize
        @target = nil
        @chain = 0
        @chain_key = nil
        @pending_continue = nil
        @stable_map_updates = 0
      end

      def reset
        @target = nil
        @chain = 0
        @chain_key = nil
        @pending_continue = nil
        @stable_map_updates = 0
      end
    end

    class << self
      def runtime
        @runtime ||= RuntimeState.new
      end

      def state
        stored = KantoReloaded::SaveData.get(
          MODULE_ID, STATE_KEY, {}, section: :modules
        )
        stored = {} unless stored.is_a?(Hash)
        stored["version"] = 3
        stored["search_levels"] = {} unless stored["search_levels"].is_a?(Hash)
        stored.delete("discovered_fusions")
        stored
      rescue StandardError
        @fallback_state ||= {
          "version" => 3,
          "search_levels" => {}
        }
      end

      def save_state(value)
        @fallback_state = value
        KantoReloaded::SaveData.set(
          MODULE_ID, STATE_KEY, value, section: :modules
        )
        true
      rescue StandardError => e
        log_exception("Wild Link state save failed", e)
        false
      end

      def species_key(species)
        return species.to_i.to_s if species.is_a?(Integer)
        text = species.to_s
        match = text.match(/\AB(\d+)H(\d+)\z/)
        if match
          maximum = defined?(::Settings::NB_POKEMON) ?
            ::Settings::NB_POKEMON.to_i : 0
          return (
            (match[1].to_i * maximum) + match[2].to_i
          ).to_s if maximum > 0
        end
        data = GameData::Species.try_get(species)
        data ? data.id.to_s : species.to_s
      rescue StandardError
        species.to_s
      end

      def search_level(species)
        state["search_levels"][species_key(species)].to_i.clamp(
          0, SEARCH_LEVEL_CAP
        )
      rescue StandardError
        0
      end

      def increment_search_level(species, amount)
        data = state
        key = species_key(species)
        value = (data["search_levels"][key].to_i + amount.to_i).clamp(
          0, SEARCH_LEVEL_CAP
        )
        data["search_levels"][key] = value
        save_state(data)
        value
      end

      def reset_search_levels
        data = state
        data["search_levels"] = {}
        save_state(data)
      end

      def chain_key(species, method_id, map_id = current_map_id)
        [species_key(species), method_id.to_s, map_id.to_i].join("|")
      end

      def begin_chain(species, method_id, map_id = current_map_id)
        key = chain_key(species, method_id, map_id)
        if runtime.chain_key != key
          runtime.chain = 0
          runtime.chain_key = key
        end
        runtime.chain
      end

      def advance_chain(species, method_id, map_id = current_map_id)
        begin_chain(species, method_id, map_id)
        runtime.chain = runtime.chain.to_i + 1
      end

      def break_chain
        runtime.chain = 0
        runtime.chain_key = nil
        runtime.pending_continue = nil
        runtime.stable_map_updates = 0
        true
      end

      def chain_for(species, method_id, map_id = current_map_id)
        return 0 unless runtime.chain_key == chain_key(species, method_id, map_id)
        runtime.chain.to_i
      end

      def continue_mode
        KantoReloaded::Settings.get(
          CONTINUE_SETTING, CONTINUE_PROMPT
        ).to_i
      rescue StandardError
        CONTINUE_PROMPT
      end

      def sprite_mode
        value = KantoReloaded::Settings.get(
          SPRITES_SETTING, SPRITES_FULL
        ).to_i
        [SPRITES_ICONS, SPRITES_FULL].include?(value) ?
          value : SPRITES_FULL
      rescue StandardError
        SPRITES_FULL
      end

      def full_sprites?
        sprite_mode == SPRITES_FULL
      end

      def messages_enabled?
        KantoReloaded::Settings.get(MESSAGES_SETTING, 1).to_i == 1
      rescue StandardError
        true
      end

      def message(text, options = {})
        popup_options = options.dup
        force = !!popup_options.delete(:force)
        return false unless force || messages_enabled?
        KantoReloaded::PopupWindow.message(text, popup_options)
      end

      def confirm(text, options = {})
        return true unless messages_enabled?
        KantoReloaded::PopupWindow.confirm(text, options)
      end

      def toast(theme, text)
        return false unless messages_enabled?
        return false unless defined?(KantoReloaded::Toast)
        KantoReloaded::Toast.__send__(theme, text)
      rescue StandardError
        false
      end

      def seen?(species)
        pokedex = player_pokedex
        pokedex ? !!pokedex.seen?(species) : false
      rescue StandardError
        false
      end

      def caught?(species)
        pokedex = player_pokedex
        pokedex ? !!pokedex.owned?(species) : false
      rescue StandardError
        false
      end

      def method_label(method_id)
        _INTL(METHOD_LABELS[method_id.to_sym] || method_id.to_s)
      rescue StandardError
        method_id.to_s
      end

      def current_map_id
        $game_map ? $game_map.map_id.to_i : 0
      rescue StandardError
        0
      end

      def player_pokedex
        return nil unless $Trainer
        return $Trainer.pokedex if $Trainer.respond_to?(:pokedex)
        $Trainer
      end

      def log_exception(message, error)
        KantoReloaded::Log.exception(
          message, error, channel: :wild_link
        ) if defined?(KantoReloaded::Log)
      rescue StandardError
        nil
      end
    end
  end
end
