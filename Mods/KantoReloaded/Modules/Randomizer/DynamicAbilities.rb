#==============================================================================
# Kanto Reloaded - Dynamic Ability Randomizer
#==============================================================================
# Applies registered abilities at generation boundaries without rebuilding
# mappings or rewriting existing Pokemon.
#==============================================================================

module KantoReloaded
  module Randomizer
    module DynamicAbilities
      DATA_VERSION = 1

      class << self
        def install
          return false unless defined?(KantoReloaded::Hooks)
          results = []
          results << install_pokemon_hooks
          results << install_trainer_hook
          results << install_fusion_hook
          results << install_evolution_hook
          results << install_unfusion_hook
          results.all?
        rescue StandardError => e
          log_exception("Dynamic Abilities integration failed", e)
          false
        end

        def randomize!(pokemon, options = {})
          return false unless KantoReloaded::Randomizer.dynamic_abilities?
          return false unless pokemon
          return false if family_pokemon?(pokemon)
          return false unless pokemon.respond_to?(:species)
          return true if !options[:force] && applied_to_current_species?(pokemon)

          success = if double_ability_target?(pokemon)
                      assign_random_pair(pokemon)
                    else
                      assign_random_primary(pokemon)
                    end
          mark_applied!(pokemon) if success
          success
        rescue StandardError => e
          log_exception("Dynamic ability assignment failed", e)
          false
        end

        def fusion?(pokemon)
          return false unless pokemon
          if defined?(KantoReloaded::DoubleAbilities)
            return KantoReloaded::DoubleAbilities.component_data(pokemon).length >= 2
          end
          pokemon.respond_to?(:isFusion?) && pokemon.isFusion?
        rescue StandardError
          false
        end

        private

        def install_pokemon_hooks
          return false unless defined?(::Pokemon)
          hooks = []
          hooks << KantoReloaded::Hooks.wrap(
            ::Pokemon,
            :initialize,
            :randomizer_dynamic_ability_generation
          ) do |hook, *arguments|
            result = hook.call
            KantoReloaded::Randomizer::DynamicAbilities.randomize!(
              self,
              :reason => :pokemon_created
            )
            result
          end
          hooks << KantoReloaded::Hooks.wrap(
            ::Pokemon,
            :species=,
            :randomizer_dynamic_ability_fusion_transition
          ) do |hook, species|
            was_fusion =
              KantoReloaded::Randomizer::DynamicAbilities.fusion?(self)
            result = hook.call
            is_fusion =
              KantoReloaded::Randomizer::DynamicAbilities.fusion?(self)
            if !was_fusion && is_fusion
              KantoReloaded::Randomizer::DynamicAbilities.randomize!(
                self,
                :reason => :fusion_species_created
              )
            end
            result
          end
          hooks << KantoReloaded::Hooks.wrap(
            ::Pokemon,
            :as_json,
            :randomizer_dynamic_ability_json_save
          ) do |hook, *arguments|
            json = hook.call
            if json.is_a?(Hash)
              json["kr_dynamic_ability_version"] =
                instance_variable_get(:@kr_dynamic_ability_version)
              json["kr_dynamic_ability_species"] =
                instance_variable_get(:@kr_dynamic_ability_species)
              json["kr_randomized_wonder_guard"] =
                !!instance_variable_get(:@kr_randomized_wonder_guard)
            end
            json
          end
          hooks << KantoReloaded::Hooks.wrap(
            ::Pokemon,
            :load_json,
            :randomizer_dynamic_ability_json_load,
            :reattach => true
          ) do |hook, *arguments|
            result = hook.call
            data = arguments[0].is_a?(Hash) ? arguments[0] : {}
            version = data["kr_dynamic_ability_version"] ||
                      data[:kr_dynamic_ability_version]
            species = data["kr_dynamic_ability_species"] ||
                      data[:kr_dynamic_ability_species]
            species = species.to_sym if species.respond_to?(:to_sym)
            wonder_guard = data["kr_randomized_wonder_guard"]
            wonder_guard = data[:kr_randomized_wonder_guard] if wonder_guard.nil?
            instance_variable_set(
              :@kr_dynamic_ability_version,
              version.to_i
            )
            instance_variable_set(
              :@kr_dynamic_ability_species,
              species
            )
            instance_variable_set(
              :@kr_randomized_wonder_guard,
              wonder_guard == true ||
                (wonder_guard.respond_to?(:to_i) && wonder_guard.to_i == 1)
            )
            result
          end
          hooks.all?
        end

        def install_trainer_hook
          return true unless defined?(GameData::Trainer)
          KantoReloaded::Hooks.wrap(
            GameData::Trainer,
            :to_trainer,
            :randomizer_dynamic_ability_trainer_generation
          ) do |hook, *arguments|
            trainer = hook.call
            party = trainer && trainer.respond_to?(:party) ? trainer.party : []
            Array(party).each do |pokemon|
              KantoReloaded::Randomizer::DynamicAbilities.randomize!(
                pokemon,
                :force => true,
                :reason => :trainer_generated
              )
            end
            trainer
          end
        end

        def install_fusion_hook
          return true unless defined?(::PokemonFusionScene)
          KantoReloaded::Hooks.wrap(
            ::PokemonFusionScene,
            :pbChooseAbility,
            :randomizer_dynamic_ability_fusion_choice
          ) do |hook, *arguments|
            pokemon = instance_variable_get(:@pokemon1)
            if KantoReloaded::Randomizer.dynamic_abilities? &&
               KantoReloaded::Randomizer::DynamicAbilities.randomize!(
                 pokemon,
                 :reason => :fusion_finalized
               )
              next true
            end
            hook.call
          end
        end

        def install_evolution_hook
          return true unless defined?(::PokemonEvolutionScene)
          KantoReloaded::Hooks.wrap(
            ::PokemonEvolutionScene,
            :pbEvolutionSuccess,
            :randomizer_dynamic_ability_reversal
          ) do |hook, reversing = false|
            result = hook.call
            if reversing
              pokemon = instance_variable_get(:@pokemon)
              KantoReloaded::Randomizer::DynamicAbilities.randomize!(
                pokemon,
                :force => true,
                :reason => :fusion_reversed
              )
            end
            result
          end
        end

        def install_unfusion_hook
          return true unless Object.private_method_defined?(:pbUnfuse) ||
                             Object.method_defined?(:pbUnfuse)
          KantoReloaded::Hooks.wrap(
            Object,
            :pbUnfuse,
            :randomizer_dynamic_ability_unfusion
          ) do |hook, pokemon, *arguments|
            result = hook.call
            if result
              KantoReloaded::Randomizer::DynamicAbilities.randomize!(
                pokemon,
                :force => true,
                :reason => :fusion_separated
              )
            end
            result
          end
        end

        def double_ability_target?(pokemon)
          return false unless defined?(KantoReloaded::DoubleAbilities)
          return false unless KantoReloaded::DoubleAbilities.enabled?
          return false unless fusion?(pokemon)
          unless KantoReloaded::DoubleAbilities.initialized?(pokemon)
            KantoReloaded::DoubleAbilities.initialize_generated!(
              pokemon,
              :reason => :ability_randomizer
            )
          end
          KantoReloaded::DoubleAbilities.eligible_pokemon?(pokemon)
        rescue StandardError
          false
        end

        def assign_random_pair(pokemon)
          components = KantoReloaded::DoubleAbilities.component_data(pokemon)
          return false if components.length < 2
          sources = normalized_component_sources(pokemon, components.length)
          pair = KantoReloaded::Randomizer::Pools.choose_ability_pair(
            components[sources[0]],
            components[sources[1]]
          )
          return false unless pair
          KantoReloaded::DoubleAbilities.assign_pair!(
            pokemon,
            pair[0],
            pair[1],
            sources
          )
        end

        def assign_random_primary(pokemon)
          ability = KantoReloaded::Randomizer::Pools.choose_ability_for_species(
            primary_owner_data(pokemon)
          )
          return false unless ability
          pokemon.ability = ability
          pokemon.instance_variable_set(:@ability_index, nil)
          pokemon.calc_stats if pokemon.respond_to?(:calc_stats)
          true
        rescue StandardError
          false
        end

        def primary_owner_data(pokemon)
          components = if defined?(KantoReloaded::DoubleAbilities)
                         KantoReloaded::DoubleAbilities.component_data(pokemon)
                       else
                         []
                       end
          unless components.empty?
            return components[rand(components.length)]
          end
          pokemon.respond_to?(:species_data) ? pokemon.species_data : nil
        rescue StandardError
          nil
        end

        def normalized_component_sources(pokemon, component_count)
          first = KantoReloaded::DoubleAbilities.source_index_for(pokemon, 1)
          second = KantoReloaded::DoubleAbilities.source_index_for(pokemon, 2)
          first = 0 unless first >= 0 && first < component_count
          unless second >= 0 && second < component_count && second != first
            second = (0...component_count).find { |index| index != first }
          end
          [first, second || first]
        rescue StandardError
          [0, [1, component_count.to_i - 1].min]
        end

        def family_pokemon?(pokemon)
          if defined?(KantoReloaded::DoubleAbilities)
            return KantoReloaded::DoubleAbilities.family_pokemon?(pokemon)
          end
          pokemon.respond_to?(:has_family?) && pokemon.has_family?
        rescue StandardError
          false
        end

        def applied_to_current_species?(pokemon)
          version =
            pokemon.instance_variable_get(:@kr_dynamic_ability_version).to_i
          species =
            pokemon.instance_variable_get(:@kr_dynamic_ability_species)
          version == DATA_VERSION && species == pokemon.species
        rescue StandardError
          false
        end

        def mark_applied!(pokemon)
          pokemon.instance_variable_set(
            :@kr_dynamic_ability_version,
            DATA_VERSION
          )
          pokemon.instance_variable_set(
            :@kr_dynamic_ability_species,
            pokemon.species
          )
          abilities = if defined?(KantoReloaded::DoubleAbilities)
                        KantoReloaded::DoubleAbilities.active_pair(pokemon)
                      elsif pokemon.respond_to?(:ability_id)
                        [pokemon.ability_id]
                      else
                        []
                      end
          pokemon.instance_variable_set(
            :@kr_randomized_wonder_guard,
            abilities.include?(:WONDERGUARD)
          )
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
  end
end
