#==============================================================================
# Kanto Reloaded - Dynamic Pokemon
#==============================================================================

module KantoReloaded
  module Randomizer
    module DynamicPokemon
      class << self
        def install
          return true if @installed
          hooks = [
            install_wild_hook,
            install_gift_hook,
            install_static_hook
          ]
          @installed = hooks.all?
        end

        def transform_encounter(encounter)
          return encounter if suppressed?
          return encounter unless KantoReloaded::Randomizer.dynamic_pokemon?
          return encounter unless encounter.is_a?(Array) && encounter.length >= 2
          replacement = select_species(encounter[0])
          # AnimeFusionQoL: this substitution happens AFTER the caught-species
          # filter already ran on the original encounter table, so it can
          # silently reintroduce an already-caught species when "Hide Caught
          # Species" is on. Skip the swap in that case rather than bypass it.
          if defined?(AnimeFusionQoL) && AnimeFusionQoL.setting("disable_caught_encounters") &&
             $Trainer && $Trainer.owned?(replacement)
            return encounter
          end
          result = encounter.dup
          result[0] = replacement
          result
        rescue StandardError => e
          log_exception("Dynamic wild encounter failed", e)
          encounter
        end

        def transform_species(species)
          return species if suppressed?
          return species unless KantoReloaded::Randomizer.dynamic_pokemon?
          select_species(species)
        rescue StandardError => e
          log_exception("Dynamic Pokemon selection failed", e)
          species
        end

        def transform_gift(pokemon, source_species, dont_randomize, result)
          return result if suppressed?
          return result unless dynamic_gift?(pokemon, dont_randomize)
          replacement = transform_species(source_species)
          finalize_abilities!(pokemon) if apply_species!(pokemon, replacement)
          result
        rescue StandardError => e
          log_exception("Dynamic gift Pokemon failed", e)
          result
        end

        def transform_static(species, result)
          return result if suppressed?
          return result unless dynamic_static?(species)
          transform_species(species)
        rescue StandardError => e
          log_exception("Dynamic static encounter failed", e)
          result
        end

        def without_dynamic_randomization
          @suppression_depth = @suppression_depth.to_i + 1
          yield
        ensure
          @suppression_depth = [@suppression_depth.to_i - 1, 0].max
        end

        def suppressed?
          @suppression_depth.to_i > 0
        end

        private

        def install_wild_hook
          return true unless defined?(PokemonEncounters)
          KantoReloaded::Hooks.wrap(
            PokemonEncounters,
            :choose_wild_pokemon,
            :randomizer_dynamic_pokemon_wild,
            :required => true
          ) do |hook, *_arguments|
            encounter = hook.call
            KantoReloaded::Randomizer::DynamicPokemon.transform_encounter(
              encounter
            )
          end
        end

        def install_gift_hook
          return true unless object_method_available?(:tryRandomizeGiftPokemon)
          KantoReloaded::Hooks.wrap(
            Object,
            :tryRandomizeGiftPokemon,
            :randomizer_dynamic_pokemon_gift,
            :required => true
          ) do |hook, pokemon, dont_randomize = false, *_arguments|
            source_species = pokemon.species if pokemon.respond_to?(:species)
            result = hook.call
            KantoReloaded::Randomizer::DynamicPokemon.transform_gift(
              pokemon,
              source_species,
              dont_randomize,
              result
            )
          end
        end

        def install_static_hook
          return true unless object_method_available?(:pbKurayRandomize)
          KantoReloaded::Hooks.wrap(
            Object,
            :pbKurayRandomize,
            :randomizer_dynamic_pokemon_static,
            :required => true
          ) do |hook, species, *_arguments|
            result = hook.call
            KantoReloaded::Randomizer::DynamicPokemon.transform_static(
              species,
              result
            )
          end
        end

        def dynamic_gift?(pokemon, dont_randomize)
          return false unless KantoReloaded::Randomizer.dynamic_pokemon?
          return false unless base_switch(:SWITCH_RANDOM_GIFT_POKEMON)
          return false if dont_randomize
          return false if base_switch(:SWITCH_CHOOSING_STARTER)
          pokemon && pokemon.respond_to?(:species)
        rescue StandardError
          false
        end

        def dynamic_static?(species)
          return false unless KantoReloaded::Randomizer.dynamic_pokemon?
          return false unless base_switch(:SWITCH_RANDOM_STATIC_ENCOUNTERS)
          return false unless native_static_species?(species)
          return false if pokeradar_active?
          true
        rescue StandardError
          false
        end

        def select_species(source_species)
          replacement = KantoReloaded::Randomizer::Pools.choose_species(
            source_species,
            KantoReloaded::Randomizer.recent_species
          )
          return source_species if replacement.nil?
          KantoReloaded::Randomizer.remember_species(replacement)
          replacement
        end

        def apply_species!(pokemon, species)
          return false unless pokemon && pokemon.respond_to?(:species=)
          return false if species.nil?
          pokemon.species = species
          pokemon.kuraycustomfile = nil if pokemon.respond_to?(:kuraycustomfile=)
          true
        rescue StandardError => e
          log_exception("Dynamic gift Pokemon replacement failed", e)
          false
        end

        def finalize_abilities!(pokemon)
          if defined?(KantoReloaded::Randomizer::DynamicAbilities) &&
             KantoReloaded::Randomizer.dynamic_abilities?
            KantoReloaded::Randomizer::DynamicAbilities.randomize!(
              pokemon,
              :force => true,
              :reason => :dynamic_gift_species
            )
          elsif defined?(KantoReloaded::DoubleAbilities)
            KantoReloaded::DoubleAbilities.initialize_generated!(
              pokemon,
              :reason => :dynamic_gift_species
            )
          end
          true
        rescue StandardError => e
          log_exception("Dynamic gift ability finalization failed", e)
          false
        end

        def native_static_species?(species)
          data = GameData::Species.get(species)
          return false unless data
          return true unless defined?(NB_POKEMON)
          data.id_number.to_i <= NB_POKEMON.to_i
        rescue StandardError
          false
        end

        def pokeradar_active?
          return false unless $PokemonTemp
          return false unless $PokemonTemp.respond_to?(:pokeradar)
          !$PokemonTemp.pokeradar.nil?
        rescue StandardError
          false
        end

        def object_method_available?(method_name)
          Object.private_method_defined?(method_name) ||
            Object.protected_method_defined?(method_name) ||
            Object.method_defined?(method_name)
        end

        def base_switch(name)
          return false unless Object.const_defined?(name) && $game_switches
          !!$game_switches[Object.const_get(name)]
        rescue StandardError
          false
        end

        def log_exception(message, error)
          KantoReloaded::Log.exception(
            message,
            error,
            channel: :randomizer
          ) if defined?(KantoReloaded::Log)
        end
      end
    end

    DynamicWildPokemon = DynamicPokemon unless const_defined?(:DynamicWildPokemon)
  end
end
