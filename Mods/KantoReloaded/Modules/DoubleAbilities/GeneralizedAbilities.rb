#==============================================================================
# Kanto Reloaded Double Abilities - Generalized Signature Abilities
#==============================================================================
# Extends species-specific abilities only where their native mechanics can be
# preserved without changing forms or replacing KIF/NPT implementations.
#==============================================================================

module KantoReloaded
  module DoubleAbilities
    module GeneralizedAbilities
      PLATE_TYPES = {
        :FISTPLATE => :FIGHTING,
        :FIGHTINIUMZ => :FIGHTING,
        :SKYPLATE => :FLYING,
        :FLYINIUMZ => :FLYING,
        :TOXICPLATE => :POISON,
        :POISONIUMZ => :POISON,
        :EARTHPLATE => :GROUND,
        :GROUNDIUMZ => :GROUND,
        :STONEPLATE => :ROCK,
        :ROCKIUMZ => :ROCK,
        :INSECTPLATE => :BUG,
        :BUGINIUMZ => :BUG,
        :SPOOKYPLATE => :GHOST,
        :GHOSTIUMZ => :GHOST,
        :IRONPLATE => :STEEL,
        :STEELIUMZ => :STEEL,
        :FLAMEPLATE => :FIRE,
        :FIRIUMZ => :FIRE,
        :SPLASHPLATE => :WATER,
        :WATERIUMZ => :WATER,
        :MEADOWPLATE => :GRASS,
        :GRASSIUMZ => :GRASS,
        :ZAPPLATE => :ELECTRIC,
        :ELECTRIUMZ => :ELECTRIC,
        :MINDPLATE => :PSYCHIC,
        :PSYCHIUMZ => :PSYCHIC,
        :ICICLEPLATE => :ICE,
        :ICIUMZ => :ICE,
        :DRACOPLATE => :DRAGON,
        :DRAGONIUMZ => :DRAGON,
        :DREADPLATE => :DARK,
        :DARKINIUMZ => :DARK,
        :PIXIEPLATE => :FAIRY,
        :FAIRIUMZ => :FAIRY
      }.freeze

      MEMORY_TYPES = {
        :FIGHTINGMEMORY => :FIGHTING,
        :FLYINGMEMORY => :FLYING,
        :POISONMEMORY => :POISON,
        :GROUNDMEMORY => :GROUND,
        :ROCKMEMORY => :ROCK,
        :BUGMEMORY => :BUG,
        :GHOSTMEMORY => :GHOST,
        :STEELMEMORY => :STEEL,
        :FIREMEMORY => :FIRE,
        :WATERMEMORY => :WATER,
        :GRASSMEMORY => :GRASS,
        :ELECTRICMEMORY => :ELECTRIC,
        :PSYCHICMEMORY => :PSYCHIC,
        :ICEMEMORY => :ICE,
        :DRAGONMEMORY => :DRAGON,
        :DARKMEMORY => :DARK,
        :FAIRYMEMORY => :FAIRY
      }.freeze

      class << self
        def install
          results = []
          results << install_pokemon_type_hooks
          results << install_unlosable_item_hook
          results.all?
        rescue StandardError => e
          log_exception("Generalized ability integration failed", e)
          false
        end

        def apply_commander(ability, battler, battle)
          data = GameData::Ability.try_get(ability)
          return false unless data && data.id == :COMMANDER
          return false unless battler && battle
          return false if battler.fainted?
          return false unless battler.respond_to?(:npt_inside_commander?)
          return true if battler.npt_inside_commander?
          return false unless battle.respond_to?(:eachSameSideBattler)

          host = nil
          battle.eachSameSideBattler(battler.index) do |ally|
            next if ally.index == battler.index
            next if ally.fainted?
            is_dondozo = (ally.isSpecies?(:DONDOZO) rescue false) ||
                         (ally.isFusionOf(:DONDOZO) rescue false)
            next unless is_dondozo
            next unless ally.respond_to?(:npt_has_commander_rider?)
            next if ally.npt_has_commander_rider?
            host = ally
            break
          end
          return false unless host

          battler.npt_commander_host = host.index
          host.npt_commander_rider = battler.index
          battle.pbShowAbilitySplash(battler)
          battle.pbDisplay(
            _INTL(
              "{1} went inside {2}!",
              battler.pbThis,
              host.pbThis(true)
            )
          )
          battle.pbHideAbilitySplash(battler)
          hide_commander_battler(battler, battle)
          [
            :ATTACK,
            :DEFENSE,
            :SPECIAL_ATTACK,
            :SPECIAL_DEFENSE,
            :SPEED
          ].each do |stat|
            next unless host.pbCanRaiseStatStage?(stat, battler)
            host.pbRaiseStatStage(stat, 2, battler, false)
          end
          true
        rescue StandardError => e
          log_exception("Generalized Commander activation failed", e)
          false
        end

        def type_for_position(pokemon, position, original)
          item = pokemon.respond_to?(:item_id) ? pokemon.item_id : nil
          return original unless item
          ability_slots(pokemon).each do |slot, ability|
            type = item_type(ability, item)
            next unless type
            next unless type_positions(pokemon, slot).include?(position.to_i)
            return type
          end
          original
        rescue StandardError
          original
        end

        def controlling_item?(pokemon, item)
          return false unless pokemon && item
          ability_slots(pokemon).any? do |_slot, ability|
            !item_type(ability, item).nil?
          end
        rescue StandardError
          false
        end

        private

        def install_pokemon_type_hooks
          return true unless defined?(::Pokemon)
          hooks = []
          hooks << KantoReloaded::Hooks.wrap(
            ::Pokemon,
            :type1,
            :double_abilities_generalized_type1,
            :reattach => true
          ) do |hook|
            original = hook.call
            KantoReloaded::DoubleAbilities::GeneralizedAbilities.type_for_position(
              self,
              0,
              original
            )
          end
          hooks << KantoReloaded::Hooks.wrap(
            ::Pokemon,
            :type2,
            :double_abilities_generalized_type2,
            :reattach => true
          ) do |hook|
            original = hook.call
            KantoReloaded::DoubleAbilities::GeneralizedAbilities.type_for_position(
              self,
              1,
              original
            )
          end
          hooks << KantoReloaded::Hooks.wrap(
            ::Pokemon,
            :types,
            :double_abilities_generalized_types,
            :reattach => true
          ) do |hook|
            hook.call
            first = type1
            second = type2
            values = [first]
            values << second if second && second != first
            values
          end
          hooks.all?
        end

        def install_unlosable_item_hook
          return true unless defined?(::PokeBattle_Battler)
          KantoReloaded::Hooks.wrap(
            ::PokeBattle_Battler,
            :unlosableItem?,
            :double_abilities_generalized_type_item,
            :reattach => true
          ) do |hook, check_item|
            result = hook.call
            next true if result
            pokemon = respond_to?(:pokemon) ? self.pokemon : nil
            KantoReloaded::DoubleAbilities::GeneralizedAbilities.controlling_item?(
              pokemon,
              check_item
            )
          end
        end

        def ability_slots(pokemon)
          first = if defined?(KantoReloaded::DoubleAbilities)
                    KantoReloaded::DoubleAbilities.primary_id(pokemon)
                  elsif pokemon.respond_to?(:ability_id)
                    pokemon.ability_id
                  end
          values = [[1, first]]
          if defined?(KantoReloaded::DoubleAbilities) &&
             KantoReloaded::DoubleAbilities.eligible_pokemon?(pokemon)
            values << [
              2,
              KantoReloaded::DoubleAbilities.secondary_id(pokemon)
            ]
          end
          values.reject { |_slot, ability| ability.nil? }
        rescue StandardError
          []
        end

        def type_positions(pokemon, slot)
          if defined?(KantoReloaded::DoubleAbilities) &&
             KantoReloaded::DoubleAbilities.eligible_pokemon?(pokemon)
            components = KantoReloaded::DoubleAbilities.component_data(pokemon)
            if components.length >= 2
              source = KantoReloaded::DoubleAbilities.source_index_for(
                pokemon,
                slot
              )
              return [1] if source == 0
              return [0] if source == 1
              return [0, 1]
            end
          end
          data = pokemon.respond_to?(:species_data) ? pokemon.species_data : nil
          if data && (!data.type2 || data.type2 == data.type1)
            [0, 1]
          else
            [0]
          end
        rescue StandardError
          [0]
        end

        def item_type(ability, item)
          data = GameData::Ability.try_get(ability)
          item_data = GameData::Item.try_get(item)
          return nil unless data && item_data
          case data.id
          when :MULTITYPE
            PLATE_TYPES[item_data.id]
          when :RKSSYSTEM
            MEMORY_TYPES[item_data.id]
          end
        rescue StandardError
          nil
        end

        def hide_commander_battler(battler, battle)
          scene = battle.respond_to?(:scene) ? battle.scene : nil
          sprites = scene && scene.respond_to?(:sprites) ? scene.sprites : nil
          return unless sprites
          index = battler.index
          sprite = sprites["pokemon_#{index}"] rescue nil
          if sprite
            sprite.visible = false
            sprite.instance_variable_set(:@spriteVisible, false)
          end
          shadow = sprites["shadow_#{index}"] rescue nil
          shadow.visible = false if shadow
          data_box = sprites["dataBox_#{index}"] rescue nil
          data_box.visible = false if data_box
        rescue StandardError
          nil
        end

        def log_exception(message, error)
          KantoReloaded::Log.exception(
            message,
            error,
            channel: :modules
          ) if defined?(KantoReloaded::Log)
        end
      end
    end
  end
end

KantoReloaded::DoubleAbilities::GeneralizedAbilities.install
