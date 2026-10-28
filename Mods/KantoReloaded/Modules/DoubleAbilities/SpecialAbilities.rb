#==============================================================================
# Kanto Reloaded Double Abilities - Narrow Special-Case Adaptations
#==============================================================================

module KantoReloaded
  module DoubleAbilities
    module SpecialAbilities
      class << self
        def install
          results = []
          results << install_transform_hook
          results << install_trace_hook
          results << install_replacement_move(
            defined?(::PokeBattle_Move_063) ? ::PokeBattle_Move_063 : nil,
            :SIMPLE,
            :simple_beam
          )
          results << install_replacement_move(
            defined?(::PokeBattle_Move_064) ? ::PokeBattle_Move_064 : nil,
            :INSOMNIA,
            :worry_seed
          )
          results << install_role_play_hook
          results << install_entrainment_hook
          results << install_skill_swap_validation
          results << install_ai_scoring_hook
          results << install_scrappy_type_hooks
          results << install_native_secondary_form_hooks
          results << install_stance_change_hooks
          results << install_disguise_hook
          results << install_neutralizing_gas_hooks
          results << install_ability_change_cleanup_hook
          results << install_illusion_preview_hooks
          results << install_illusion_message_hook
          results << install_battler_utility_hooks
          results << install_overworld_ability_hooks
          results.all?
        rescue StandardError => e
          KantoReloaded::Log.exception(
            "Double Abilities special-case install failed",
            e,
            channel: :modules
          ) if defined?(KantoReloaded::Log)
          false
        end

        private

        def install_transform_hook
          return true unless defined?(::PokeBattle_Battler)
          KantoReloaded::Hooks.wrap(
            ::PokeBattle_Battler,
            :pbTransform,
            :double_abilities_transform
          ) do |hook, target|
            result = hook.call
            runtime = KantoReloaded::DoubleAbilities::BattleRuntime
            next result unless KantoReloaded::DoubleAbilities.enabled?
            next result if target.is_a?(Integer)
            next result if KantoReloaded::DoubleAbilities.family_pokemon?(
              respond_to?(:pokemon) ? pokemon : nil
            )

            copied = runtime.secondary_id(target)
            if copied
              instance_variable_set(:@ability2_id, copied)
              instance_variable_set(:@kr_double_abilities_transformed, true)
              runtime.invalidate_battler_cache(self)
              runtime.refresh_eligibility_cache(self)
              runtime.validate_battle_pair(self)
            else
              instance_variable_set(:@ability2_id, nil)
              instance_variable_set(:@kr_double_abilities_transformed, nil)
              runtime.invalidate_battler_cache(self)
              runtime.refresh_eligibility_cache(self)
            end
            result
          end
        end

        def install_trace_hook
          return true unless defined?(::PokeBattle_Battler)
          KantoReloaded::Hooks.wrap(
            ::PokeBattle_Battler,
            :pbContinualAbilityChecks,
            :double_abilities_trace_slot
          ) do |hook, *arguments|
            runtime = KantoReloaded::DoubleAbilities::BattleRuntime
            family = KantoReloaded::DoubleAbilities.family_pokemon?(
              respond_to?(:pokemon) ? pokemon : nil
            )
            next hook.call if family
            trace_slot = if runtime.ability_at(self, 1) == :TRACE
                           1
                         elsif runtime.eligible_battler?(self) &&
                               runtime.ability_at(self, 2) == :TRACE
                           2
                         end
            choices =
              KantoReloaded::DoubleAbilities::SpecialAbilities.trace_choices(
                self,
                trace_slot
              )
            custom = trace_slot &&
                     (trace_slot == 2 ||
                      choices.any? { |entry| entry[:slot] == 2 })
            next hook.call unless custom

            key = trace_slot == 2 ? :@ability2_id : :@ability_id
            old_trace = instance_variable_get(key)
            instance_variable_set(key, nil)
            result = hook.call
            instance_variable_set(key, old_trace)
            next result if choices.empty?

            battle = respond_to?(:battle) ? self.battle : nil
            index = battle && battle.respond_to?(:pbRandom) ?
              battle.pbRandom(choices.length) :
              rand(choices.length)
            selected = choices[index]
            runtime.with_slot(self, trace_slot) do
              battle.pbShowAbilitySplash(self)
            end
            assigned = if runtime.eligible_battler?(self)
                         runtime.assign_battle_slot!(
                           self,
                           trace_slot,
                           selected[:ability]
                         )
                       else
                         self.ability = selected[:ability]
                         true
                       end
            if assigned
              battle.pbDisplay(
                _INTL(
                  "{1} traced {2}'s {3}!",
                  pbThis,
                  selected[:battler].pbThis(true),
                  KantoReloaded::DoubleAbilities.ability_name(
                    selected[:ability]
                  )
                )
              )
              battle.pbHideAbilitySplash(self)
              copied = GameData::Ability.try_get(selected[:ability])
              if copied && !arguments[0] &&
                 (unstoppableAbility?(copied.id) || abilityActive?)
                BattleHandlers.triggerAbilityOnSwitchIn(copied, self, battle)
              end
            else
              battle.pbHideAbilitySplash(self)
            end
            result
          ensure
            if defined?(key) && key && defined?(old_trace) && old_trace &&
               instance_variable_get(key).nil?
              instance_variable_set(key, old_trace)
            end
          end
        end

        def install_replacement_move(target_class, replacement, hook_id)
          return true unless target_class
          fail_hook = KantoReloaded::Hooks.wrap(
            target_class,
            :pbFailsAgainstTarget?,
            :"double_abilities_#{hook_id}_failure"
          ) do |hook, user, target|
            runtime = KantoReloaded::DoubleAbilities::BattleRuntime
            slots = runtime.legal_replacement_slots(target, replacement)
            slots.empty? ? hook.call : false
          end
          effect_hook = KantoReloaded::Hooks.wrap(
            target_class,
            :pbEffectAgainstTarget,
            :"double_abilities_#{hook_id}_effect"
          ) do |hook, user, target|
            runtime = KantoReloaded::DoubleAbilities::BattleRuntime
            slots = runtime.legal_replacement_slots(target, replacement)
            next hook.call if slots.empty?
            battle = instance_variable_get(:@battle)
            index = if battle && battle.respond_to?(:pbRandom)
                      battle.pbRandom(slots.length)
                    else
                      rand(slots.length)
                    end
            slot = slots[index]
            old_ability = GameData::Ability.try_get(runtime.ability_at(target, slot))
            runtime.with_slot(target, slot) do
              battle.pbShowAbilitySplash(target, true, false)
              runtime.assign_battle_slot!(target, slot, replacement)
              battle.pbReplaceAbilitySplash(target)
              battle.pbDisplay(
                _INTL(
                  "{1}'s Ability {2} became {3}!",
                  target.pbThis,
                  slot,
                  KantoReloaded::DoubleAbilities.ability_name(replacement)
                )
              )
              battle.pbHideAbilitySplash(target)
            end
            target.pbOnAbilityChanged(old_ability) if old_ability
            nil
          end
          fail_hook && effect_hook
        end

        def install_skill_swap_validation
          return true unless defined?(::PokeBattle_Move_067)
          KantoReloaded::Hooks.wrap(
            ::PokeBattle_Move_067,
            :pbFailsAgainstTarget?,
            :double_abilities_skill_swap_validation
          ) do |hook, user, target|
            failed = hook.call
            next failed if failed
            runtime = KantoReloaded::DoubleAbilities::BattleRuntime
            next false unless runtime.eligible_battler?(user) ||
                              runtime.eligible_battler?(target)
            user_new = runtime.ability_at(target, 1)
            target_new = runtime.ability_at(user, 1)
            user_second = runtime.ability_at(user, 2)
            target_second = runtime.ability_at(target, 2)
            legal =
              KantoReloaded::DoubleAbilities.pair_legal?(user_new, user_second) &&
              KantoReloaded::DoubleAbilities.pair_legal?(target_new, target_second)
            unless legal
              battle = instance_variable_get(:@battle)
              battle.pbDisplay(_INTL("But the resulting ability pair is not allowed!"))
            end
            !legal
          end
        end

        def install_ai_scoring_hook
          return true unless defined?(::PokeBattle_AI)
          KantoReloaded::Hooks.wrap(
            ::PokeBattle_AI,
            :pbGetMoveScoreFunctionCode,
            :double_abilities_move_effect_scoring
          ) do |hook, score, move, user, target, *arguments|
            result = hook.call
            skill = arguments.empty? ? 100 : arguments[0]
            KantoReloaded::DoubleAbilities::SpecialAbilities.adjust_ai_score(
              result,
              move,
              user,
              target,
              skill
            )
          end
        end

        def install_scrappy_type_hooks
          targets = []
          targets << ::PokeBattle_Move if defined?(::PokeBattle_Move)
          targets << ::PokeBattle_AI if defined?(::PokeBattle_AI)
          single_hooks = targets.all? do |target_class|
            hook_id = target_class == ::PokeBattle_Move ?
              :double_abilities_scrappy_move_type :
              :double_abilities_scrappy_ai_type
            KantoReloaded::Hooks.wrap(
              target_class,
              :pbCalcTypeModSingle,
              hook_id
            ) do |hook, move_type, defense_type, user, target|
              result = hook.call
              next result unless defense_type == :GHOST
              next result unless Effectiveness.ineffective_type?(
                move_type,
                defense_type
              )
              helper = KantoReloaded::DoubleAbilities::SpecialAbilities
              next result unless helper.scrappy_active?(user)
              Effectiveness::NORMAL_EFFECTIVE_ONE
            end
          end
          total_hooks = targets.all? do |target_class|
            hook_id = target_class == ::PokeBattle_Move ?
              :double_abilities_scrappy_move_type_total :
              :double_abilities_scrappy_ai_type_total
            KantoReloaded::Hooks.wrap(
              target_class,
              :pbCalcTypeMod,
              hook_id
            ) do |hook, move_type, user, target|
              result = hook.call
              next result unless Effectiveness.ineffective?(result)
              next result unless [:NORMAL, :FIGHTING].include?(move_type)
              types = target.pbTypes(true)
              next result unless types.include?(:GHOST)
              helper = KantoReloaded::DoubleAbilities::SpecialAbilities
              next result unless helper.scrappy_active?(user)
              type_mods = [
                Effectiveness::NORMAL_EFFECTIVE_ONE,
                Effectiveness::NORMAL_EFFECTIVE_ONE,
                Effectiveness::NORMAL_EFFECTIVE_ONE
              ]
              types.each_with_index do |type, index|
                type_mods[index] = if type == :GHOST
                                     Effectiveness::NORMAL_EFFECTIVE_ONE
                                   else
                                     pbCalcTypeModSingle(
                                       move_type,
                                       type,
                                       user,
                                       target
                                     )
                                   end
              end
              type_mods.inject(1) { |total, modifier| total * modifier }
            end
          end
          single_hooks && total_hooks
        end

        def install_native_secondary_form_hooks
          return true unless defined?(::PokeBattle_Battler)
          hooks = []
          hooks << KantoReloaded::Hooks.wrap(
            ::PokeBattle_Battler,
            :pbCheckForm,
            :double_abilities_direct_form_checks
          ) do |hook, *arguments|
            result = hook.call
            runtime = KantoReloaded::DoubleAbilities::BattleRuntime
            secondary = runtime.secondary_id(self)
            supported = [
              :SHIELDSDOWN,
              :SCHOOLING,
              :POWERCONSTRUCT
            ]
            if supported.include?(secondary) &&
               runtime.secondary_active?(self, true) &&
               runtime.ability_at(self, 1) != secondary
              KantoReloaded::DoubleAbilities::SpecialAbilities.with_temporary_primary(
                self,
                secondary
              ) { hook.call }
            end
            KantoReloaded::DoubleAbilities::SpecialAbilities.apply_fusion_zen_mode(
              self
            )
            result
          end
          if ::PokeBattle_Battler.method_defined?(:checkHPRelatedFormChange)
            hooks << KantoReloaded::Hooks.wrap(
              ::PokeBattle_Battler,
              :checkHPRelatedFormChange,
              :double_abilities_shields_down_battle_form
            ) do |hook, *arguments|
              result = hook.call
              runtime = KantoReloaded::DoubleAbilities::BattleRuntime
              if runtime.secondary_matches?(self, :SHIELDSDOWN, true) &&
                 runtime.ability_at(self, 1) != :SHIELDSDOWN
                KantoReloaded::DoubleAbilities::SpecialAbilities.with_temporary_primary(
                  self,
                  :SHIELDSDOWN
                ) { hook.call }
              end
              result
            end
          end
          if defined?(::Pokemon) &&
             ::Pokemon.method_defined?(:checkHPRelatedFormChange)
            hooks << KantoReloaded::Hooks.wrap(
              ::Pokemon,
              :checkHPRelatedFormChange,
              :double_abilities_shields_down_storage_form
            ) do |hook, *arguments|
              result = hook.call
              pair = KantoReloaded::DoubleAbilities.active_pair(self)
              if pair.include?(:SHIELDSDOWN) &&
                 KantoReloaded::DoubleAbilities.primary_id(self) != :SHIELDSDOWN
                KantoReloaded::DoubleAbilities::SpecialAbilities.with_temporary_pokemon_ability(
                  self,
                  :SHIELDSDOWN
                ) { hook.call }
              end
              result
            end
          end
          hooks.all?
        end

        def install_stance_change_hooks
          return true unless defined?(::PokeBattle_Battler)
          hooks = []
          hooks << KantoReloaded::Hooks.wrap(
            ::PokeBattle_Battler,
            :pbUseMove,
            :double_abilities_stance_change_context
          ) do |hook, *arguments|
            runtime = KantoReloaded::DoubleAbilities::BattleRuntime
            KantoReloaded::DoubleAbilities::SpecialAbilities.show_secondary_aerilate(
              self,
              arguments[0]
            )
            eligible = runtime.secondary_matches?(self, :STANCECHANGE, true) &&
                       runtime.ability_at(self, 1) != :STANCECHANGE
            instance_variable_set(:@kr_secondary_stance_pending, eligible)
            hook.call
          ensure
            instance_variable_set(:@kr_secondary_stance_pending, nil)
          end
          hooks << KantoReloaded::Hooks.wrap(
            ::PokeBattle_Battler,
            :pbTryUseMove,
            :double_abilities_stance_change_special_use
          ) do |hook, choice, move, special_usage, skip_accuracy|
            result = hook.call
            if result && special_usage
              KantoReloaded::DoubleAbilities::SpecialAbilities.apply_secondary_stance_change(
                self,
                move
              )
            end
            result
          end
          hooks << KantoReloaded::Hooks.wrap(
            ::PokeBattle_Battler,
            :pbReducePP,
            :double_abilities_stance_change_after_pp
          ) do |hook, move|
            result = hook.call
            if result
              KantoReloaded::DoubleAbilities::SpecialAbilities.apply_secondary_stance_change(
                self,
                move
              )
            end
            result
          end
          hooks.all?
        end

        def install_disguise_hook
          return true unless defined?(::PokeBattle_Move)
          hooks = []
          hooks << KantoReloaded::Hooks.wrap(
            ::PokeBattle_Move,
            :pbCheckDamageAbsorption,
            :double_abilities_disguise
          ) do |hook, user, target|
            result = hook.call
            next result if target.damageState.substitute ||
                           target.damageState.disguise
            runtime = KantoReloaded::DoubleAbilities::BattleRuntime
            if !instance_variable_get(:@battle).moldBreaker &&
               target.isFusionOf(:MIMIKYU) &&
               target.form == 0 &&
               runtime.secondary_matches?(target, :DISGUISE)
              target.damageState.disguise = true
            end
            result
          end
          hooks << KantoReloaded::Hooks.wrap(
            ::PokeBattle_Move,
            :pbEndureKOMessage,
            :double_abilities_disguise_splash
          ) do |hook, target|
            runtime = KantoReloaded::DoubleAbilities::BattleRuntime
            pending = target.damageState.disguise &&
                      runtime.secondary_matches?(target, :DISGUISE, true) &&
                      runtime.ability_at(target, 1) != :DISGUISE
            runtime.mark_pending_splash(target, :DISGUISE, 2) if pending
            hook.call
          ensure
            runtime.clear_pending_splash(target) if pending
          end
          hooks.all?
        end

        def install_neutralizing_gas_hooks
          return true unless defined?(::PokeBattle_Battler)
          hooks = []
          hooks << KantoReloaded::Hooks.wrap(
            ::PokeBattle_Battler,
            :abilityActive?,
            :double_abilities_neutralizing_gas
          ) do |hook, ignore_fainted = false|
            result = hook.call
            runtime = KantoReloaded::DoubleAbilities::BattleRuntime
            if KantoReloaded::DoubleAbilities::SpecialAbilities.raw_gas_holder?(
              self,
              ignore_fainted
            )
              next true
            end
            next false unless result
            battle = respond_to?(:battle) ? battle() : nil
            next result unless battle && battle.respond_to?(:battlers)
            suppressed = battle.battlers.any? do |battler|
              battler && battler != self &&
                KantoReloaded::DoubleAbilities::SpecialAbilities.raw_gas_holder?(
                  battler,
                  false
                )
            end
            suppressed ? false : result
          end
          hooks << KantoReloaded::Hooks.wrap(
            ::PokeBattle_Battler,
            :pbAbilitiesOnSwitchOut,
            :double_abilities_neutralizing_gas_switch_out
          ) do |hook, *arguments|
            secondary_gas =
              KantoReloaded::DoubleAbilities::SpecialAbilities.secondary_gas_holder?(
                self,
                true
              )
            result = hook.call
            if secondary_gas
              KantoReloaded::DoubleAbilities::SpecialAbilities.restore_after_gas(
                self,
                false
              )
            end
            result
          end
          hooks << KantoReloaded::Hooks.wrap(
            ::PokeBattle_Battler,
            :pbFaint,
            :double_abilities_neutralizing_gas_faint
          ) do |hook, *arguments|
            was_fainted = fainted?
            secondary_gas =
              KantoReloaded::DoubleAbilities::SpecialAbilities.secondary_gas_holder?(
                self,
                true
              )
            result = hook.call
            if secondary_gas && !was_fainted && fainted?
              KantoReloaded::DoubleAbilities::SpecialAbilities.restore_after_gas(
                self,
                true
              )
            end
            result
          end
          hooks.all?
        end

        def install_ability_change_cleanup_hook
          return true unless defined?(::PokeBattle_Battler)
          KantoReloaded::Hooks.wrap(
            ::PokeBattle_Battler,
            :pbOnAbilityChanged,
            :double_abilities_slow_start_cleanup
          ) do |hook, *arguments|
            effects = instance_variable_get(:@effects)
            old_slow_start = effects[PBEffects::SlowStart] if effects
            had_illusion = effects && effects[PBEffects::Illusion]
            old_ability = GameData::Ability.try_get(arguments[0])
            result = hook.call
            runtime = KantoReloaded::DoubleAbilities::BattleRuntime
            if effects &&
               runtime.ability_at(self, 2) == :SLOWSTART &&
               runtime.ability_at(self, 1) != :SLOWSTART
              effects[PBEffects::SlowStart] = old_slow_start
            end
            if had_illusion &&
               effects[PBEffects::Illusion] &&
               old_ability &&
               old_ability.id == :ILLUSION &&
               ![
                 runtime.ability_at(self, 1),
                 runtime.ability_at(self, 2)
               ].include?(:ILLUSION)
              effects[PBEffects::Illusion] = nil
              unless effects[PBEffects::Transform]
                battle = respond_to?(:battle) ? self.battle : nil
                battle.scene.pbChangePokemon(self, pokemon)
                battle.pbDisplay(
                  _INTL(
                    "{1}'s {2} wore off!",
                    pbThis,
                    KantoReloaded::DoubleAbilities.ability_name(:ILLUSION)
                  )
                )
                battle.pbSetSeen(self)
              end
            end
            result
          end
        end

        def install_illusion_message_hook
          return true unless defined?(::PokeBattle_Battle)
          KantoReloaded::Hooks.wrap(
            ::PokeBattle_Battle,
            :pbMessagesOnReplace,
            :double_abilities_illusion_send_out_name
          ) do |hook, idx_battler, idx_party|
            party = pbParty(idx_battler)
            pokemon = party && party[idx_party]
            if KantoReloaded::DoubleAbilities.eligible_pokemon?(pokemon) &&
               KantoReloaded::DoubleAbilities.primary_id(pokemon) != :ILLUSION &&
               KantoReloaded::DoubleAbilities.secondary_id(pokemon) == :ILLUSION
              next KantoReloaded::DoubleAbilities::SpecialAbilities.with_temporary_pokemon_ability(
                pokemon,
                :ILLUSION
              ) { hook.call }
            end
            hook.call
          end
        end

        def install_illusion_preview_hooks
          return true unless defined?(::PokeBattle_Battle)
          return true unless defined?(::Pokemon)
          eor_hook = KantoReloaded::Hooks.wrap(
            ::PokeBattle_Battle,
            :pbEORSwitch,
            :double_abilities_illusion_preview_scope
          ) do |hook, *arguments|
            helper = KantoReloaded::DoubleAbilities::SpecialAbilities
            helper.begin_illusion_preview(self)
            hook.call
          ensure
            helper.end_illusion_preview(self) if defined?(helper) && helper
          end
          choice_hook = KantoReloaded::Hooks.wrap(
            ::PokeBattle_Battle,
            :pbSwitchInBetween,
            :double_abilities_illusion_preview_choice
          ) do |hook, idx_battler, *arguments|
            idx_party = hook.call
            KantoReloaded::DoubleAbilities::SpecialAbilities.note_illusion_preview(
              self,
              idx_battler,
              idx_party
            )
            idx_party
          end
          ability_hook = KantoReloaded::Hooks.wrap(
            ::Pokemon,
            :ability,
            :double_abilities_illusion_preview_ability
          ) do |hook|
            helper = KantoReloaded::DoubleAbilities::SpecialAbilities
            if helper.consume_illusion_preview(self)
              next GameData::Ability.try_get(:ILLUSION)
            end
            hook.call
          end
          eor_hook && choice_hook && ability_hook
        end

        def install_battler_utility_hooks
          return true unless defined?(::PokeBattle_Battler)
          hooks = []
          hooks << KantoReloaded::Hooks.wrap(
            ::PokeBattle_Battler,
            :unlosableItem?,
            :double_abilities_unlosable_item
          ) do |hook, check_item|
            result = hook.call
            next true if result
            runtime = KantoReloaded::DoubleAbilities::BattleRuntime
            secondary = runtime.secondary_ability(self)
            next result unless secondary && check_item
            GameData::Item.get(check_item).unlosable?(
              instance_variable_get(:@species),
              secondary
            )
          end
          hooks << KantoReloaded::Hooks.wrap(
            ::PokeBattle_Battler,
            :canChangeType?,
            :double_abilities_component_type_lock
          ) do |hook, *arguments|
            result = hook.call
            positions =
              KantoReloaded::DoubleAbilities::SpecialAbilities.type_lock_positions(
                self
              )
            next result if positions.empty?
            positions.length < 2
          end
          hooks << KantoReloaded::Hooks.wrap(
            ::PokeBattle_Battler,
            :pbChangeTypes,
            :double_abilities_component_type_change
          ) do |hook, *arguments|
            positions =
              KantoReloaded::DoubleAbilities::SpecialAbilities.type_lock_positions(
                self
              )
            saved = {}
            positions.each do |key|
              saved[key] = instance_variable_get(key)
            end
            hook.call
          ensure
            saved.each do |key, value|
              instance_variable_set(key, value)
            end if saved
          end
          hooks.all?
        end

        def install_overworld_ability_hooks
          return true unless Object.private_method_defined?(:pbFishing) ||
                             Object.method_defined?(:pbFishing)
          KantoReloaded::Hooks.wrap(
            Object,
            :pbFishing,
            :double_abilities_fishing_lead
          ) do |hook, *arguments|
            trainer = defined?($Trainer) ? $Trainer : nil
            lead = trainer && trainer.respond_to?(:first_pokemon) ?
              trainer.first_pokemon :
              nil
            secondary = KantoReloaded::DoubleAbilities.secondary_id(lead)
            if KantoReloaded::DoubleAbilities.eligible_pokemon?(lead) &&
               [:STICKYHOLD, :SUCTIONCUPS].include?(secondary) &&
               ![:STICKYHOLD, :SUCTIONCUPS].include?(
                 KantoReloaded::DoubleAbilities.primary_id(lead)
               )
              next KantoReloaded::DoubleAbilities::SpecialAbilities.with_temporary_pokemon_ability(
                lead,
                secondary
              ) { hook.call }
            end
            hook.call
          end
        end

        def install_role_play_hook
          return true unless defined?(::PokeBattle_Move_065)
          fail_hook = KantoReloaded::Hooks.wrap(
            ::PokeBattle_Move_065,
            :pbFailsAgainstTarget?,
            :double_abilities_role_play_failure
          ) do |hook, user, target|
            runtime = KantoReloaded::DoubleAbilities::BattleRuntime
            next hook.call unless runtime.eligible_battler?(user)
            choices = KantoReloaded::DoubleAbilities::SpecialAbilities.copy_choices(
              target,
              user,
              1,
              [:POWEROFALCHEMY, :RECEIVER, :TRACE, :WONDERGUARD]
            )
            choices.empty? ? hook.call : false
          end
          effect_hook = KantoReloaded::Hooks.wrap(
            ::PokeBattle_Move_065,
            :pbEffectAgainstTarget,
            :double_abilities_role_play
          ) do |hook, user, target|
            runtime = KantoReloaded::DoubleAbilities::BattleRuntime
            next hook.call unless runtime.eligible_battler?(user)
            choices = KantoReloaded::DoubleAbilities::SpecialAbilities.copy_choices(
              target,
              user,
              1,
              [:POWEROFALCHEMY, :RECEIVER, :TRACE, :WONDERGUARD]
            )
            next hook.call if choices.empty?
            copied = KantoReloaded::DoubleAbilities::SpecialAbilities.choose_battle_ability(
              user,
              choices,
              "Role Play - Copy which ability?"
            )
            next nil unless copied
            battle = instance_variable_get(:@battle)
            old_ability = user.ability
            battle.pbShowAbilitySplash(user, true, false)
            runtime.assign_battle_slot!(user, 1, copied)
            battle.pbReplaceAbilitySplash(user)
            battle.pbDisplay(
              _INTL(
                "{1} copied {2}'s {3}!",
                user.pbThis,
                target.pbThis(true),
                KantoReloaded::DoubleAbilities.ability_name(copied)
              )
            )
            battle.pbHideAbilitySplash(user)
            user.pbOnAbilityChanged(old_ability)
            user.pbEffectsOnSwitchIn
            nil
          end
          fail_hook && effect_hook
        end

        def install_entrainment_hook
          return true unless defined?(::PokeBattle_Move_066)
          move_fail_hook = KantoReloaded::Hooks.wrap(
            ::PokeBattle_Move_066,
            :pbMoveFailed?,
            :double_abilities_entrainment_move_failure
          ) do |hook, user, targets|
            target = Array(targets)[0]
            runtime = KantoReloaded::DoubleAbilities::BattleRuntime
            next hook.call unless target && runtime.eligible_battler?(target)
            choices = KantoReloaded::DoubleAbilities::SpecialAbilities.copy_choices(
              user,
              target,
              1,
              [:POWEROFALCHEMY, :RECEIVER, :TRACE]
            )
            choices.empty? ? hook.call : false
          end
          target_fail_hook = KantoReloaded::Hooks.wrap(
            ::PokeBattle_Move_066,
            :pbFailsAgainstTarget?,
            :double_abilities_entrainment_target_failure
          ) do |hook, user, target|
            runtime = KantoReloaded::DoubleAbilities::BattleRuntime
            next hook.call unless runtime.eligible_battler?(target)
            choices = KantoReloaded::DoubleAbilities::SpecialAbilities.copy_choices(
              user,
              target,
              1,
              [:POWEROFALCHEMY, :RECEIVER, :TRACE]
            )
            choices.empty? ? hook.call : false
          end
          effect_hook = KantoReloaded::Hooks.wrap(
            ::PokeBattle_Move_066,
            :pbEffectAgainstTarget,
            :double_abilities_entrainment
          ) do |hook, user, target|
            runtime = KantoReloaded::DoubleAbilities::BattleRuntime
            next hook.call unless runtime.eligible_battler?(target)
            choices = KantoReloaded::DoubleAbilities::SpecialAbilities.copy_choices(
              user,
              target,
              1,
              [:POWEROFALCHEMY, :RECEIVER, :TRACE]
            )
            next hook.call if choices.empty?
            copied = KantoReloaded::DoubleAbilities::SpecialAbilities.choose_battle_ability(
              user,
              choices,
              "Entrainment - Pass which ability?"
            )
            next nil unless copied
            battle = instance_variable_get(:@battle)
            old_ability = target.ability
            battle.pbShowAbilitySplash(target, true, false)
            runtime.assign_battle_slot!(target, 1, copied)
            battle.pbReplaceAbilitySplash(target)
            battle.pbDisplay(
              _INTL(
                "{1} acquired {2}!",
                target.pbThis,
                KantoReloaded::DoubleAbilities.ability_name(copied)
              )
            )
            battle.pbHideAbilitySplash(target)
            target.pbOnAbilityChanged(old_ability)
            target.pbEffectsOnSwitchIn
            nil
          end
          move_fail_hook && target_fail_hook && effect_hook
        end

      end

      def self.adjust_ai_score(score, move, user, target, skill)
        function = move && move.respond_to?(:function) ? move.function : nil
        return score unless ["063", "064", "065", "066", "067", "068"].include?(
          function
        )
        runtime = KantoReloaded::DoubleAbilities::BattleRuntime
        case function
        when "063"
          adjust_ai_replacement_score(
            score,
            target,
            skill,
            :SIMPLE,
            [:TRUANT, :SIMPLE]
          )
        when "064"
          adjust_ai_replacement_score(
            score,
            target,
            skill,
            :INSOMNIA,
            [:TRUANT, :INSOMNIA]
          )
        when "065"
          adjust_ai_role_play_score(score, user, target, skill)
        when "066"
          adjust_ai_entrainment_score(score, user, target, skill)
        when "067"
          adjust_ai_skill_swap_score(score, user, target, skill)
        when "068"
          adjust_ai_gastro_acid_score(score, target, skill)
        else
          score
        end
      rescue
        score
      end

      def self.adjust_ai_replacement_score(
        score,
        target,
        skill,
        replacement,
        primary_blocked
      )
        runtime = KantoReloaded::DoubleAbilities::BattleRuntime
        return score unless runtime.eligible_battler?(target)
        return score unless skill >= PBTrainerAI.mediumSkill
        return score if target.effects[PBEffects::Substitute] > 0
        primary = runtime.ability_at(target, 1)
        base_failed = target.unstoppableAbility? ||
                      primary_blocked.include?(primary)
        desired_failed = runtime.legal_replacement_slots(
          target,
          replacement
        ).empty?
        score + ai_failure_adjustment(desired_failed) -
          ai_failure_adjustment(base_failed)
      rescue
        score
      end

      def self.adjust_ai_role_play_score(score, user, target, skill)
        runtime = KantoReloaded::DoubleAbilities::BattleRuntime
        return score unless runtime.eligible_battler?(user)
        return score unless skill >= PBTrainerAI.mediumSkill
        primary_user = runtime.ability_at(user, 1)
        primary_target = runtime.ability_at(target, 1)
        blocked = [
          :FLOWERGIFT,
          :FORECAST,
          :ILLUSION,
          :IMPOSTER,
          :MULTITYPE,
          :RKSSYSTEM,
          :TRACE,
          :WONDERGUARD,
          :ZENMODE
        ]
        base_failed = primary_target.nil? ||
                      primary_user == primary_target ||
                      [:MULTITYPE, :RKSSYSTEM].include?(primary_user) ||
                      blocked.include?(primary_target)
        choices = copy_choices(
          target,
          user,
          1,
          [:POWEROFALCHEMY, :RECEIVER, :TRACE, :WONDERGUARD]
        )
        desired_failed = user.unstoppableAbility? || choices.empty?
        base_adjustment = ai_failure_adjustment(base_failed)
        desired_adjustment = ai_failure_adjustment(desired_failed)
        if skill >= PBTrainerAI.highSkill && user.opposes?(target)
          base_adjustment -= 90 if [:TRUANT, :SLOWSTART].include?(
            primary_target
          )
          unless desired_failed
            desired_adjustment += ai_average_adjustment(
              choices,
              [:TRUANT, :SLOWSTART],
              -90
            )
          end
        end
        score + desired_adjustment - base_adjustment
      rescue
        score
      end

      def self.adjust_ai_entrainment_score(score, user, target, skill)
        runtime = KantoReloaded::DoubleAbilities::BattleRuntime
        return score unless runtime.eligible_battler?(target)
        return score unless skill >= PBTrainerAI.mediumSkill
        return score if target.effects[PBEffects::Substitute] > 0
        primary_user = runtime.ability_at(user, 1)
        primary_target = runtime.ability_at(target, 1)
        user_blocked = [
          :FLOWERGIFT,
          :FORECAST,
          :ILLUSION,
          :IMPOSTER,
          :MULTITYPE,
          :RKSSYSTEM,
          :TRACE,
          :ZENMODE
        ]
        base_failed = primary_user.nil? ||
                      primary_user == primary_target ||
                      [:MULTITYPE, :RKSSYSTEM, :TRUANT].include?(
                        primary_target
                      ) ||
                      user_blocked.include?(primary_user)
        choices = copy_choices(
          user,
          target,
          1,
          [:POWEROFALCHEMY, :RECEIVER, :TRACE]
        )
        desired_failed = choices.empty?
        base_adjustment = ai_failure_adjustment(base_failed)
        desired_adjustment = ai_failure_adjustment(desired_failed)
        if skill >= PBTrainerAI.highSkill && user.opposes?(target)
          base_adjustment += 90 if [:TRUANT, :SLOWSTART].include?(primary_user)
          unless desired_failed
            desired_adjustment += ai_average_adjustment(
              choices,
              [:TRUANT, :SLOWSTART],
              90
            )
          end
        end
        score + desired_adjustment - base_adjustment
      rescue
        score
      end

      def self.adjust_ai_skill_swap_score(score, user, target, skill)
        runtime = KantoReloaded::DoubleAbilities::BattleRuntime
        return score unless runtime.eligible_battler?(user) ||
                            runtime.eligible_battler?(target)
        return score unless skill >= PBTrainerAI.mediumSkill
        primary_user = runtime.ability_at(user, 1)
        primary_target = runtime.ability_at(target, 1)
        blocked = [:ILLUSION, :MULTITYPE, :RKSSYSTEM, :WONDERGUARD]
        base_failed = (primary_user.nil? && primary_target.nil?) ||
                      primary_user == primary_target ||
                      blocked.include?(primary_user) ||
                      blocked.include?(primary_target)
        legal = KantoReloaded::DoubleAbilities.pair_legal?(
          primary_target,
          runtime.ability_at(user, 2)
        ) && KantoReloaded::DoubleAbilities.pair_legal?(
          primary_user,
          runtime.ability_at(target, 2)
        )
        desired_failed = base_failed || !legal
        score + ai_failure_adjustment(desired_failed) -
          ai_failure_adjustment(base_failed)
      rescue
        score
      end

      def self.adjust_ai_gastro_acid_score(score, target, skill)
        runtime = KantoReloaded::DoubleAbilities::BattleRuntime
        return score unless runtime.eligible_battler?(target)
        return score unless skill >= PBTrainerAI.highSkill
        return score if target.effects[PBEffects::Substitute] > 0
        return score if target.effects[PBEffects::GastroAcid]
        blocked = [:MULTITYPE, :RKSSYSTEM, :SLOWSTART, :TRUANT]
        primary_penalty = blocked.include?(runtime.ability_at(target, 1))
        pair_penalty = runtime.active_ids(target).any? do |ability|
          blocked.include?(ability)
        end
        score + ai_failure_adjustment(pair_penalty) -
          ai_failure_adjustment(primary_penalty)
      rescue
        score
      end

      def self.ai_failure_adjustment(failed)
        failed ? -90 : 0
      end

      def self.ai_average_adjustment(choices, matching, amount)
        values = Array(choices)
        return 0 if values.empty?
        count = values.count { |ability| matching.include?(ability) }
        ((amount * count).to_f / values.length).round
      end

      def self.scrappy_active?(battler)
        return false unless battler
        active = battler.hasActiveAbility?(:SCRAPPY)
        if active
          KantoReloaded::DoubleAbilities::BattleRuntime.clear_pending_splash(
            battler
          )
        end
        active
      rescue
        false
      end

      def self.begin_illusion_preview(battle)
        @illusion_preview_contexts ||= []
        @illusion_preview_contexts << {
          :battle => battle,
          :pokemon => nil
        }
        true
      rescue
        false
      end

      def self.end_illusion_preview(battle)
        contexts = @illusion_preview_contexts
        return false unless contexts
        index = contexts.rindex { |entry| entry[:battle].equal?(battle) }
        contexts.delete_at(index) if index
        true
      rescue
        false
      end

      def self.note_illusion_preview(battle, idx_battler, idx_party)
        contexts = @illusion_preview_contexts
        return false unless contexts && idx_party && idx_party >= 0
        context = contexts.reverse.find do |entry|
          entry[:battle].equal?(battle)
        end
        return false unless context
        return false if battle.pbOwnedByPlayer?(idx_battler)
        party = battle.pbParty(idx_battler)
        pokemon = party && party[idx_party]
        runtime = KantoReloaded::DoubleAbilities::BattleRuntime
        valid = runtime.eligible_pokemon?(pokemon) &&
                KantoReloaded::DoubleAbilities.primary_id(pokemon) != :ILLUSION &&
                KantoReloaded::DoubleAbilities.secondary_id(pokemon) == :ILLUSION
        context[:pokemon] = valid ? pokemon : nil
        valid
      rescue
        false
      end

      def self.consume_illusion_preview(pokemon)
        contexts = @illusion_preview_contexts
        return false unless contexts
        context = contexts.reverse.find do |entry|
          entry[:pokemon] && entry[:pokemon].equal?(pokemon)
        end
        return false unless context
        context[:pokemon] = nil
        true
      rescue
        false
      end

      def self.with_temporary_primary(battler, ability)
        old_ability = battler.instance_variable_get(:@ability_id)
        battler.instance_variable_set(:@ability_id, ability)
        yield
      ensure
        battler.instance_variable_set(:@ability_id, old_ability)
      end

      def self.with_temporary_pokemon_ability(pokemon, ability)
        old_ability = pokemon.instance_variable_get(:@ability)
        pokemon.instance_variable_set(:@ability, ability)
        yield
      ensure
        pokemon.instance_variable_set(:@ability, old_ability)
      end

      def self.apply_secondary_stance_change(battler, move)
        return false unless battler.instance_variable_get(
          :@kr_secondary_stance_pending
        )
        return false unless move
        attacking = move.damagingMove?
        return false unless attacking || move.id == :KINGSSHIELD
        battler.instance_variable_set(:@kr_secondary_stance_pending, false)
        BattleRuntime.with_slot(battler, 2) do
          battler.stanceChangeEffect(battler, attacking)
        end
        true
      rescue
        false
      end

      def self.show_secondary_aerilate(battler, choice)
        runtime = KantoReloaded::DoubleAbilities::BattleRuntime
        return false unless runtime.secondary_matches?(
          battler,
          :AERILATE,
          true
        )
        return false if runtime.ability_at(battler, 1) == :AERILATE
        move = Array(choice)[2]
        return false unless move &&
                            !move.callsAnotherMove? &&
                            !move.snatched &&
                            move.type == :NORMAL &&
                            GameData::Type.exists?(:FLYING)
        battle = battler.respond_to?(:battle) ? battler.battle : nil
        return false unless battle
        runtime.with_slot(battler, 2) do
          battle.pbShowAbilitySplash(battler)
        end
        battle.pbDisplay(
          _INTL(
            "{1}'s Aerilate turned the Normal-type move into a Flying-type move!",
            battler.pbThis
          )
        )
        battle.pbHideAbilitySplash(battler)
        true
      rescue
        false
      end

      def self.dispatch_battle_bond(ability, user, targets, move, battle)
        data = GameData::Ability.try_get(ability)
        return [false, nil] unless data && data.id == :BATTLEBOND
        native = BattleHandlers::UserAbilityEndOfMove[data.id] rescue nil
        return [false, nil] if native

        runtime = KantoReloaded::DoubleAbilities::BattleRuntime
        native_owner = (user.isSpecies?(:GRENINJA) rescue false) &&
                       !(user.isFusion? rescue false)
        return [false, nil] if native_owner
        return [true, nil] if user.fainted?
        return [true, nil] if user.effects[PBEffects::Transform]
        return [true, nil] if battle.pbAllFainted?(user.idxOpposingSide)
        return [true, nil] unless Array(targets).any? do |target|
          target && target.damageState.fainted
        end

        side = user.index & 1
        party_index = user.pokemonIndex
        return [true, nil] if battle.battleBond[side][party_index]
        battle.battleBond[side][party_index] = true

        slot = runtime.triggering_slot(user) == 2 ? 2 : 1
        runtime.with_slot(user, slot) do
          battle.pbShowAbilitySplash(user)
        end
        show_animation = true
        [:ATTACK, :SPECIAL_ATTACK, :SPEED].each do |stat|
          next unless user.pbCanRaiseStatStage?(stat, user)
          if user.pbRaiseStatStage(stat, 1, user, show_animation)
            show_animation = false
          end
        end
        battle.pbHideAbilitySplash(user)
        [true, nil]
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "Double Abilities Battle Bond fallback failed",
          e,
          channel: :modules
        ) if defined?(KantoReloaded::Log)
        [true, nil]
      end

      def self.apply_fusion_zen_mode(battler)
        runtime = KantoReloaded::DoubleAbilities::BattleRuntime
        return false unless runtime.eligible_battler?(battler)
        return false if battler.fainted?
        effects = battler.instance_variable_get(:@effects)
        return false if effects && effects[PBEffects::Transform]
        pokemon = battler.respond_to?(:pokemon) ? battler.pokemon : nil
        return false unless pokemon && pokemon.respond_to?(:isFusion?) &&
                            pokemon.isFusion?

        slot = nil
        if runtime.ability_at(battler, 1) == :ZENMODE &&
           battler.abilityActive?(true)
          slot = 1
        elsif runtime.secondary_matches?(battler, :ZENMODE, true)
          slot = 2
        end
        return false unless slot

        below_half = battler.hp <= battler.totalhp / 2
        pairs = if below_half
                  [
                    [:DARMANITAN, :DARMANITAN_1],
                    [:DARMANITAN_2, :DARMANITAN_3]
                  ]
                else
                  [
                    [:DARMANITAN_1, :DARMANITAN],
                    [:DARMANITAN_3, :DARMANITAN_2]
                  ]
                end
        change = pairs.find { |old_form, _new_form| pokemon.isFusionOf(old_form) }
        return false unless change

        runtime.with_slot(battler, slot) do
          battler.battle.pbShowAbilitySplash(battler, true)
        end
        battler.battle.pbHideAbilitySplash(battler)
        pokemon.changeFormSpecies(change[0], change[1])
        battler.pbUpdate(true)
        battler.battle.pbDisplay(
          _INTL("{1} changed form with Zen Mode!", battler.pbThis)
        )
        true
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "Double Abilities Zen Mode component change failed",
          e,
          channel: :modules
        ) if defined?(KantoReloaded::Log)
        false
      end

      def self.type_lock_positions(battler)
        runtime = KantoReloaded::DoubleAbilities::BattleRuntime
        return [] unless runtime.eligible_battler?(battler)
        pokemon = battler.respond_to?(:pokemon) ? battler.pokemon : nil
        components = KantoReloaded::DoubleAbilities.component_data(pokemon)
        return [] if components.length < 2
        positions = []
        [1, 2].each do |slot|
          ability = runtime.ability_at(battler, slot)
          next unless [:MULTITYPE, :RKSSYSTEM].include?(ability)
          source = KantoReloaded::DoubleAbilities.source_index_for(
            pokemon,
            slot
          )
          if components.length > 2 || source > 1
            positions.concat([:@type1, :@type2])
          else
            positions << (source == 0 ? :@type2 : :@type1)
          end
        end
        positions.uniq
      rescue
        []
      end

      def self.raw_gas_holder?(battler, ignore_fainted = false)
        return false unless battler
        return false if battler.fainted? && !ignore_fainted
        effects = battler.instance_variable_get(:@effects)
        return false if effects && effects[PBEffects::GastroAcid]
        runtime = KantoReloaded::DoubleAbilities::BattleRuntime
        return true if runtime.ability_at(battler, 1) == :NEUTRALIZINGGAS
        runtime.eligible_battler?(battler) &&
          runtime.ability_at(battler, 2) == :NEUTRALIZINGGAS
      rescue
        false
      end

      def self.secondary_gas_holder?(battler, ignore_fainted = false)
        runtime = KantoReloaded::DoubleAbilities::BattleRuntime
        runtime.eligible_battler?(battler) &&
          runtime.ability_at(battler, 1) != :NEUTRALIZINGGAS &&
          runtime.ability_at(battler, 2) == :NEUTRALIZINGGAS &&
          raw_gas_holder?(battler, ignore_fainted)
      rescue
        false
      end

      def self.restore_after_gas(leaving, show_message)
        battle = leaving.respond_to?(:battle) ? leaving.battle : nil
        return false unless battle && battle.respond_to?(:battlers)
        remaining = battle.battlers.any? do |battler|
          battler && battler != leaving && raw_gas_holder?(battler, false)
        end
        return false if remaining
        battle.pbDisplay(_INTL("The neutralizing gas faded away!")) if show_message
        battle.pbPriority(true).each do |battler|
          battler.pbEffectsOnSwitchIn(false) unless battler.fainted?
        end
        true
      rescue
        false
      end

      def self.trace_choices(holder, trace_slot)
        return [] unless trace_slot
        return [] unless holder.hasActiveAbility?(:TRACE)
        battle = holder.respond_to?(:battle) ? holder.battle : nil
        return [] unless battle
        runtime = KantoReloaded::DoubleAbilities::BattleRuntime
        choices = []
        battle.eachOtherSideBattler(holder.index) do |source|
          source_ids = if runtime.eligible_battler?(source)
                         runtime.active_ids(source)
                       else
                         [runtime.ability_at(source, 1)]
                       end
          source_ids.compact.uniq.each_with_index do |ability, index|
            next if [:POWEROFALCHEMY, :RECEIVER, :TRACE].include?(ability)
            next if source.ungainableAbility?(ability)
            if runtime.eligible_battler?(holder)
              first = trace_slot == 1 ? ability : runtime.ability_at(holder, 1)
              second = trace_slot == 2 ? ability : runtime.ability_at(holder, 2)
              next unless KantoReloaded::DoubleAbilities.pair_legal?(
                first,
                second
              )
            end
            choices << {
              :battler => source,
              :ability => ability,
              :slot => index + 1
            }
          end
        end
        choices
      rescue
        []
      end

      def self.dispatch_faint_copy(ability, battler, fainted, battle)
        data = GameData::Ability.try_get(ability)
        id = data ? data.id : nil
        return [false, nil] unless [:POWEROFALCHEMY, :RECEIVER].include?(id)
        runtime = KantoReloaded::DoubleAbilities::BattleRuntime
        return [false, nil] unless runtime.eligible_battler?(fainted)
        source_ids = runtime.active_ids(fainted).compact.uniq
        return [false, nil] unless source_ids.length > 1
        return [true, nil] if battler.opposes?(fainted)
        return [false, nil] if KantoReloaded::DoubleAbilities.family_pokemon?(
          battler.respond_to?(:pokemon) ? battler.pokemon : nil
        )

        destination_slot = runtime.triggering_slot(battler) == 2 ? 2 : 1
        choices = source_ids.reject do |source_id|
          fainted.ungainableAbility?(source_id) ||
            [:POWEROFALCHEMY, :RECEIVER, :TRACE, :WONDERGUARD].include?(
              source_id
            ) ||
            (runtime.eligible_battler?(battler) &&
              !legal_copy_for_slot?(battler, destination_slot, source_id))
        end
        return [true, nil] if choices.empty?

        index = battle.respond_to?(:pbRandom) ?
          battle.pbRandom(choices.length) :
          rand(choices.length)
        copied = choices[index]
        runtime.with_slot(battler, destination_slot) do
          battle.pbShowAbilitySplash(battler, true)
        end
        assigned = if runtime.eligible_battler?(battler)
                     runtime.assign_battle_slot!(
                       battler,
                       destination_slot,
                       copied
                     )
                   else
                     battler.ability = copied
                     true
                   end
        if assigned
          battle.pbReplaceAbilitySplash(battler)
          battle.pbDisplay(
            _INTL(
              "{1}'s {2} was taken over!",
              fainted.pbThis,
              KantoReloaded::DoubleAbilities.ability_name(copied)
            )
          )
        end
        battle.pbHideAbilitySplash(battler)
        [true, nil]
      rescue
        [false, nil]
      end

      def self.legal_copy_for_slot?(battler, slot, ability)
        runtime = KantoReloaded::DoubleAbilities::BattleRuntime
        first = slot == 1 ? ability : runtime.ability_at(battler, 1)
        second = slot == 2 ? ability : runtime.ability_at(battler, 2)
        KantoReloaded::DoubleAbilities.pair_legal?(first, second)
      rescue
        false
      end

      def self.dispatch_contact_ability(ability, user, target, move, battle)
        runtime = KantoReloaded::DoubleAbilities::BattleRuntime
        data = GameData::Ability.try_get(ability)
        id = data ? data.id : nil
        return [false, nil] unless [
          :MUMMY,
          :LINGERINGAROMA,
          :WANDERINGSPIRIT
        ].include?(id)
        return [false, nil] unless runtime.eligible_battler?(target)
        return [false, nil] unless runtime.eligible_battler?(user)
        return [false, nil] unless move.pbContactMove?(user)
        return [false, nil] if user.fainted?
        return [false, nil] unless user.affectedByContactEffect?(
          PokeBattle_SceneConstants::USE_ABILITY_SPLASH
        )

        result = if id == :WANDERINGSPIRIT
                   apply_wandering_spirit(user, target, battle)
                 else
                   apply_contact_replacement(user, target, id, battle)
                 end
        [true, result]
      rescue
        [false, nil]
      end

      def self.copy_choices(source, destination, destination_slot, blocked)
        runtime = KantoReloaded::DoubleAbilities::BattleRuntime
        source_ids = if runtime.eligible_battler?(source)
                       runtime.active_ids(source)
                     else
                       [source.instance_variable_get(:@ability_id)]
                     end
        source_ids.compact.uniq.reject do |id|
          blocked.include?(id) ||
            source.ungainableAbility?(id) ||
            !runtime.legal_replacement_slots(destination, id).include?(destination_slot)
        end
      rescue
        []
      end

      def self.choose_battle_ability(user, choices, title)
        values = Array(choices).compact.uniq
        return nil if values.empty?
        return values[0] if values.length == 1
        if user.respond_to?(:pbOwnedByPlayer?) &&
           user.pbOwnedByPlayer? &&
           defined?(KantoReloaded::DoubleAbilities::Integration)
          return KantoReloaded::DoubleAbilities::Integration.choose_ability(
            title,
            values,
            values[0]
          )
        end
        battle = user.respond_to?(:battle) ? user.battle : nil
        index = battle && battle.respond_to?(:pbRandom) ?
          battle.pbRandom(values.length) :
          rand(values.length)
        values[index]
      rescue
        values && values[0]
      end

      def self.apply_contact_replacement(user, target, replacement, battle)
        runtime = KantoReloaded::DoubleAbilities::BattleRuntime
        slots = runtime.legal_replacement_slots(user, replacement)
        return false if slots.empty?
        index = battle.respond_to?(:pbRandom) ? battle.pbRandom(slots.length) : rand(slots.length)
        slot = slots[index]
        old_ability = GameData::Ability.try_get(runtime.ability_at(user, slot))
        target_slot = runtime.ability_at(target, 2) == replacement ? 2 : 1
        runtime.with_slot(target, target_slot) do
          battle.pbShowAbilitySplash(target) if user.opposes?(target)
        end
        runtime.with_slot(user, slot) do
          battle.pbShowAbilitySplash(user, true, false) if user.opposes?(target)
          runtime.assign_battle_slot!(user, slot, replacement)
          battle.pbReplaceAbilitySplash(user) if user.opposes?(target)
          battle.pbDisplay(
            _INTL(
              "{1}'s Ability {2} became {3}!",
              user.pbThis,
              slot,
              KantoReloaded::DoubleAbilities.ability_name(replacement)
            )
          )
          battle.pbHideAbilitySplash(user) if user.opposes?(target)
        end
        battle.pbHideAbilitySplash(target) if user.opposes?(target)
        user.pbOnAbilityChanged(old_ability) if old_ability
        true
      rescue
        false
      end

      def self.apply_wandering_spirit(user, target, battle)
        runtime = KantoReloaded::DoubleAbilities::BattleRuntime
        user_slots = runtime.legal_replacement_slots(user, :WANDERINGSPIRIT)
        return false if user_slots.empty?
        user_slot = user_slots[
          battle.respond_to?(:pbRandom) ? battle.pbRandom(user_slots.length) : rand(user_slots.length)
        ]
        target_slot = runtime.ability_at(target, 2) == :WANDERINGSPIRIT ? 2 : 1
        old_user = runtime.ability_at(user, user_slot)
        target_first = target_slot == 1 ? old_user : runtime.ability_at(target, 1)
        target_second = target_slot == 2 ? old_user : runtime.ability_at(target, 2)
        return false unless KantoReloaded::DoubleAbilities.pair_legal?(
          target_first,
          target_second
        )

        battle.pbShowAbilitySplash(target) if user.opposes?(target)
        battle.pbShowAbilitySplash(user, true, false) if user.opposes?(target)
        runtime.assign_battle_slot!(user, user_slot, :WANDERINGSPIRIT)
        runtime.assign_battle_slot!(target, target_slot, old_user)
        battle.pbReplaceAbilitySplash(user) if user.opposes?(target)
        battle.pbReplaceAbilitySplash(target) if user.opposes?(target)
        battle.pbDisplay(
          _INTL("{1}'s and {2}'s Abilities were swapped!", user.pbThis, target.pbThis(true))
        )
        battle.pbHideAbilitySplash(user) if user.opposes?(target)
        battle.pbHideAbilitySplash(target) if user.opposes?(target)
        user.pbOnAbilityChanged(GameData::Ability.try_get(old_user))
        target.pbOnAbilityChanged(GameData::Ability.try_get(:WANDERINGSPIRIT))
        true
      rescue
        false
      end
    end
  end
end

KantoReloaded::DoubleAbilities::SpecialAbilities.install
