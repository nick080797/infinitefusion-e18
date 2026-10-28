#==============================================================================
# Kanto Reloaded Double Abilities - UI and Gameplay Integration
#==============================================================================

module KantoReloaded
  module DoubleAbilities
    module Integration
      class << self
        def install
          results = []
          results << install_fusion_hook
          results << install_item_hook
          results << install_ball_hook
          results << install_summary_hooks
          results << install_debug_hook
          results.all?
        rescue StandardError => e
          KantoReloaded::Log.exception(
            "Double Abilities integration install failed",
            e,
            channel: :modules
          ) if defined?(KantoReloaded::Log)
          false
        end

        def choose_fusion_pair(scene, ability1_id, ability2_id)
          pokemon = scene.instance_variable_get(:@pokemon1)
          partner = scene.instance_variable_get(:@pokemon2)
          components = KantoReloaded::DoubleAbilities.component_data(pokemon)
          return false if components.length < 2

          first_id = normalize_ability(ability1_id)
          second_id = normalize_ability(ability2_id)
          first_source = matching_source(components, first_id, nil)
          second_source = matching_source(components, second_id, first_source)
          second_source ||= ((first_source || 0) + 1) % components.length
          first_source ||= (second_source + 1) % components.length

          first_pool = source_pool(components[first_source], first_id)
          selected_first = choose_ability(
            "Choose Ability 1 - #{components[first_source].name}",
            first_pool,
            first_id
          )
          selected_first ||= first_id

          second_pool = source_pool(components[second_source], second_id).select do |id|
            KantoReloaded::DoubleAbilities.pair_legal?(selected_first, id)
          end
          selected_second = choose_ability(
            "Choose Ability 2 - #{components[second_source].name}",
            second_pool,
            second_id
          )
          selected_second ||= second_pool.first

          unless KantoReloaded::DoubleAbilities.pair_legal?(
            selected_first,
            selected_second
          )
            selected_second = second_pool.find do |id|
              KantoReloaded::DoubleAbilities.pair_legal?(selected_first, id)
            end
          end

          if pokemon.respond_to?(:body_original_ability_index=)
            pokemon.body_original_ability_index = pokemon.ability_index
          end
          if pokemon.respond_to?(:head_original_ability_index=) &&
             partner.respond_to?(:ability_index)
            pokemon.head_original_ability_index = partner.ability_index
          end
          run_native_nature_and_nickname_flow(scene, pokemon, partner)
          KantoReloaded::DoubleAbilities.assign_pair!(
            pokemon,
            selected_first,
            selected_second,
            [first_source, selected_second ? second_source : nil]
          )
        rescue StandardError => e
          KantoReloaded::Log.exception(
            "Double Abilities fusion chooser failed",
            e,
            channel: :modules
          ) if defined?(KantoReloaded::Log)
          false
        end

        def use_ability_item(item, pokemon, scene)
          if KantoReloaded::DoubleAbilities.family_pokemon?(pokemon)
            display(scene, "Family Pokemon abilities cannot be changed here.")
            return false
          end
          return nil unless KantoReloaded::DoubleAbilities.eligible_pokemon?(pokemon)

          hidden = item == :SECRETCAPSULE
          slots = [1, 2].select do |slot|
            !choices_for_item(pokemon, slot, hidden).empty?
          end
          if slots.empty?
            display(scene, "It won't have any effect.")
            return false
          end

          slot = slots.length == 1 ? slots[0] : choose_slot(pokemon, slots)
          return false unless slot
          choices = choices_for_item(pokemon, slot, hidden)
          current = slot == 1 ?
            KantoReloaded::DoubleAbilities.primary_id(pokemon) :
            KantoReloaded::DoubleAbilities.secondary_id(pokemon)
          ability = choose_ability(
            hidden ? "Choose a hidden ability" : "Choose an ability",
            choices,
            current
          )
          return false unless ability
          return false unless KantoReloaded::DoubleAbilities.assign_slot!(
            pokemon,
            slot,
            ability
          )

          refresh_scene(scene)
          display(
            scene,
            "#{pokemon.name}'s Ability #{slot} changed to " \
            "#{KantoReloaded::DoubleAbilities.ability_name(ability)}!"
          )
          true
        end

        def apply_ability_ball(pokemon)
          return false unless KantoReloaded::DoubleAbilities.eligible_pokemon?(pokemon)
          slots = [1, 2].select do |slot|
            !KantoReloaded::DoubleAbilities.hidden_slot_choices(pokemon, slot).empty?
          end
          return false if slots.empty?
          slot = slots.length == 1 ? slots[0] : choose_slot(pokemon, slots)
          return false unless slot
          choices = KantoReloaded::DoubleAbilities.hidden_slot_choices(pokemon, slot)
          selected = choices.length == 1 ?
            choices[0] :
            choose_ability("Ability Ball - Ability #{slot}", choices, choices[0])
          selected && KantoReloaded::DoubleAbilities.assign_slot!(pokemon, slot, selected)
        rescue
          false
        end

        def debug_edit_slot(pokemon, pokemon_index, screen, slot)
          if KantoReloaded::DoubleAbilities.family_pokemon?(pokemon)
            display(screen, "Family Pokemon abilities are read-only.")
            return false
          end
          return nil unless KantoReloaded::DoubleAbilities.eligible_pokemon?(pokemon)
          choices = KantoReloaded::DoubleAbilities.component_pools(
            pokemon,
            true
          ).flatten.uniq.select do |id|
            other = slot == 1 ?
              KantoReloaded::DoubleAbilities.secondary_id(pokemon) :
              KantoReloaded::DoubleAbilities.primary_id(pokemon)
            slot == 1 ?
              KantoReloaded::DoubleAbilities.pair_legal?(id, other) :
              KantoReloaded::DoubleAbilities.pair_legal?(other, id)
          end
          current = slot == 1 ?
            KantoReloaded::DoubleAbilities.primary_id(pokemon) :
            KantoReloaded::DoubleAbilities.secondary_id(pokemon)
          selected = choose_ability("Set Ability #{slot}", choices, current)
          return false unless selected
          if KantoReloaded::DoubleAbilities.assign_slot!(pokemon, slot, selected)
            screen.pbRefreshSingle(pokemon_index) if screen.respond_to?(:pbRefreshSingle)
          end
          false
        end

        def choose_ability(title, choices, current)
          values = Array(choices).compact.uniq
          return nil if values.empty?
          return values[0] if values.length == 1
          start_index = values.index(current) || 0

          if defined?(KantoReloaded::PopupWindow) &&
             KantoReloaded::PopupWindow.respond_to?(:paged_summary)
            pages = values.map do |id|
              ability = GameData::Ability.try_get(id)
              {
                :label => ability ? ability.name : id.to_s,
                :details => ability_description_lines(ability),
                :value => id
              }
            end
            result = KantoReloaded::PopupWindow.paged_summary(
              title,
              pages,
              :start_index => start_index,
              :width => 360
            )
            return result == -1 ? nil : result
          end

          rows = values.map do |id|
            {
              :label => KantoReloaded::DoubleAbilities.ability_name(id),
              :value => id
            }
          end
          result = KantoReloaded::PopupWindow.choice(
            title,
            rows,
            :start_index => start_index
          )
          result == -1 ? nil : result
        rescue
          nil
        end

        private

        def install_fusion_hook
          return true unless defined?(::PokemonFusionScene)
          KantoReloaded::Hooks.wrap(
            ::PokemonFusionScene,
            :pbChooseAbility,
            :double_abilities_fusion_chooser,
            :reattach => true
          ) do |hook, ability1_id, ability2_id|
            pokemon = instance_variable_get(:@pokemon1)
            if !KantoReloaded::DoubleAbilities.enabled? ||
               KantoReloaded::DoubleAbilities.family_pokemon?(pokemon)
              next hook.call
            end
            success =
              KantoReloaded::DoubleAbilities::Integration.choose_fusion_pair(
                self,
                ability1_id,
                ability2_id
              )
            success ? true : hook.call
          end
        end

        def install_item_hook
          return true unless defined?(ItemHandlers)
          KantoReloaded::Hooks.wrap(
            ItemHandlers,
            :triggerUseOnPokemon,
            :double_abilities_ability_items,
            :singleton => true
          ) do |hook, item, pokemon, scene|
            item_data = GameData::Item.try_get(item)
            item_id = item_data ? item_data.id : item
            if KantoReloaded::DoubleAbilities.enabled? &&
               [:ABILITYCAPSULE, :SECRETCAPSULE].include?(item_id)
              result = KantoReloaded::DoubleAbilities::Integration.use_ability_item(
                item_id,
                pokemon,
                scene
              )
              next result unless result.nil?
            end
            hook.call
          end
        end

        def install_ball_hook
          return true unless defined?(BallHandlers)
          KantoReloaded::Hooks.wrap(
            BallHandlers,
            :onCatch,
            :double_abilities_ability_ball,
            :singleton => true
          ) do |hook, ball, battle, pokemon|
            ball_data = GameData::Item.try_get(ball)
            ball_id = ball_data ? ball_data.id : ball
            unless KantoReloaded::DoubleAbilities.enabled? &&
                   ball_id == :ABILITYBALL
              next hook.call
            end
            if KantoReloaded::DoubleAbilities.family_pokemon?(pokemon)
              next nil
            end
            unless KantoReloaded::DoubleAbilities.eligible_pokemon?(pokemon)
              next hook.call
            end

            old_primary = pokemon.instance_variable_get(:@ability)
            old_index = pokemon.instance_variable_get(:@ability_index)
            result = hook.call
            pokemon.instance_variable_set(:@ability, old_primary)
            pokemon.instance_variable_set(:@ability_index, old_index)
            KantoReloaded::DoubleAbilities::Integration.apply_ability_ball(pokemon)
            result
          end
        end

        def install_summary_hooks
          return true unless defined?(::PokemonSummary_Scene)
          hooks = []
          hooks << KantoReloaded::Hooks.wrap(
            ::PokemonSummary_Scene,
            :pbStartScene,
            :double_abilities_summary_start
          ) do |hook, *arguments|
            instance_variable_set(:@kr_double_abilities_summary_slot, 1)
            party = arguments[0]
            index = arguments[1].to_i
            pokemon = party[index] if party.respond_to?(:[])
            KantoReloaded::DoubleAbilities.repair_invalid_pair!(
              pokemon,
              :summary_opened
            ) if pokemon
            hook.call
          end
          hooks << KantoReloaded::Hooks.wrap(
            ::PokemonSummary_Scene,
            :pbUpdate,
            :double_abilities_summary_input
          ) do |hook, *arguments|
            result = hook.call
            pokemon = instance_variable_get(:@pokemon)
            page = instance_variable_get(:@page).to_i
            frame = Graphics.frame_count if defined?(Graphics)
            last_frame = instance_variable_get(:@kr_double_abilities_action_frame)
            if page == 3 &&
               KantoReloaded::DoubleAbilities.eligible_pokemon?(pokemon) &&
               defined?(Input) &&
               Input.trigger?(Input::ACTION) &&
               frame != last_frame
              current = instance_variable_get(:@kr_double_abilities_summary_slot).to_i
              instance_variable_set(
                :@kr_double_abilities_summary_slot,
                current == 2 ? 1 : 2
              )
              instance_variable_set(:@kr_double_abilities_action_frame, frame)
              drawPage(3)
            end
            result
          end
          hooks << KantoReloaded::Hooks.wrap(
            ::PokemonSummary_Scene,
            :drawPageThree,
            :double_abilities_summary_draw,
            :reattach => true
          ) do |hook, *arguments|
            result = hook.call
            pokemon = instance_variable_get(:@pokemon)
            next result unless KantoReloaded::DoubleAbilities.eligible_pokemon?(pokemon)
            slot = instance_variable_get(:@kr_double_abilities_summary_slot).to_i
            slot = 1 unless slot == 2
            ability = slot == 2 ?
              KantoReloaded::DoubleAbilities.secondary_ability(pokemon) :
              pokemon.ability
            next result unless ability
            sprites = instance_variable_get(:@sprites)
            overlay_sprite = sprites && sprites["overlay"]
            overlay = overlay_sprite && overlay_sprite.bitmap
            next result unless overlay
            overlay.fill_rect(220, 274, 292, 108, Color.new(0, 0, 0, 0))
            base = Color.new(248, 248, 248)
            shadow = Color.new(104, 104, 104)
            pbDrawTextPositions(overlay, [
              [_INTL("Ability {1}", slot), 224, 278, 0, base, shadow],
              [ability.name, 362, 278, 0,
               Color.new(64, 64, 64), Color.new(176, 176, 176)]
            ])
            drawTextEx(
              overlay,
              224,
              320,
              282,
              2,
              ability.description,
              Color.new(64, 64, 64),
              Color.new(176, 176, 176)
            )
            result
          end
          hooks.all?
        end

        def install_debug_hook
          return true unless defined?(PokemonDebugMenuCommands)
          KantoReloaded::Hooks.wrap(
            PokemonDebugMenuCommands,
            :call,
            :double_abilities_debug_slots,
            :singleton => true
          ) do |hook, function, option, *arguments|
            if KantoReloaded::DoubleAbilities.enabled? &&
               function.to_s == "effect" &&
               ["setability", "setability2"].include?(option.to_s)
              pokemon = arguments[0]
              if KantoReloaded::DoubleAbilities.family_pokemon?(pokemon) ||
                 KantoReloaded::DoubleAbilities.eligible_pokemon?(pokemon)
                slot = option.to_s == "setability2" ? 2 : 1
                next KantoReloaded::DoubleAbilities::Integration.debug_edit_slot(
                  pokemon,
                  arguments[1],
                  arguments[4],
                  slot
                )
              end
            end
            hook.call
          end
        end

        def source_pool(data, preferred)
          values =
            KantoReloaded::DoubleAbilities.normal_abilities(data) +
            KantoReloaded::DoubleAbilities.hidden_abilities(data)
          values.unshift(preferred) if preferred
          values.compact.uniq
        end

        def matching_source(components, ability, excluded)
          matches = []
          components.each_with_index do |data, index|
            next if index == excluded
            matches << index if source_pool(data, nil).include?(ability)
          end
          matches[0]
        end

        def run_native_nature_and_nickname_flow(scene, pokemon, partner)
          natures = [pokemon.nature, partner.nature]
          scene.send(:clearUIForMoves)
          option_scene = FusionSelectOptionsScene.new(nil, natures, pokemon, partner)
          PokemonOptionScreen.new(option_scene).pbStartScreen
          pokemon.nature = option_scene.selectedNature
          pokemon.name = option_scene.nickname if option_scene.hasNickname
        end

        def choices_for_item(pokemon, slot, hidden)
          choices = hidden ?
            KantoReloaded::DoubleAbilities.hidden_slot_choices(pokemon, slot) :
            KantoReloaded::DoubleAbilities.legal_slot_choices(pokemon, slot, false)
          current = slot == 1 ?
            KantoReloaded::DoubleAbilities.primary_id(pokemon) :
            KantoReloaded::DoubleAbilities.secondary_id(pokemon)
          choices.reject { |id| id == current }
        end

        def choose_slot(pokemon, slots)
          rows = slots.map do |slot|
            current = slot == 1 ?
              KantoReloaded::DoubleAbilities.primary_id(pokemon) :
              KantoReloaded::DoubleAbilities.secondary_id(pokemon)
            {
              :label => "Ability #{slot} - " \
                        "#{KantoReloaded::DoubleAbilities.ability_name(current)}",
              :value => slot
            }
          end
          result = KantoReloaded::PopupWindow.choice("Choose an ability slot", rows)
          result == -1 ? nil : result
        rescue
          nil
        end

        def normalize_ability(value)
          data = GameData::Ability.try_get(value)
          data ? data.id : nil
        rescue
          nil
        end

        def display(scene, text)
          if scene && scene.respond_to?(:pbDisplay)
            scene.pbDisplay(_INTL(text))
          elsif defined?(KantoReloaded::PopupWindow)
            KantoReloaded::PopupWindow.message(text)
          end
        rescue
          nil
        end

        def refresh_scene(scene)
          if scene && scene.respond_to?(:pbHardRefresh)
            scene.pbHardRefresh
          elsif scene && scene.respond_to?(:pbRefresh)
            scene.pbRefresh
          end
        rescue
          nil
        end

        def ability_description_lines(ability)
          text = ability && ability.respond_to?(:description) ?
            ability.description.to_s :
            ""
          text = _INTL("No ability description is available.") if text.empty?
          if defined?(Bitmap) &&
             defined?(KantoReloaded::UI::Draw) &&
             KantoReloaded::UI::Draw.respond_to?(:wrap_lines)
            bitmap = Bitmap.new(1, 1)
            pbSetSmallFont(bitmap) if defined?(pbSetSmallFont)
            lines = KantoReloaded::UI::Draw.wrap_lines(bitmap, text, 310)
            bitmap.dispose unless bitmap.disposed?
            return lines.first(6)
          end
          text.scan(/.{1,44}(?:\s+|\z)/).map { |line| line.strip }.first(6)
        rescue
          [text.to_s]
        ensure
          bitmap.dispose if defined?(bitmap) && bitmap &&
            bitmap.respond_to?(:disposed?) && !bitmap.disposed?
        end
      end
    end
  end
end

KantoReloaded::DoubleAbilities::Integration.install
