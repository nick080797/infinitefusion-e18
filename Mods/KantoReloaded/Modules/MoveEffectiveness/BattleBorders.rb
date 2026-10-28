#==============================================================================
# Kanto Reloaded - Move Effectiveness Battle Borders
#==============================================================================

module KantoReloaded
  module MoveEffectiveness
    module BattleBorders
      CONTEXT_IVAR = :@kanto_reloaded_move_effectiveness_context
      EBDX_FIGHT_BORDER_IVAR = :@kanto_reloaded_move_effectiveness_border
      EBDX_FIGHT_SIGNATURE_IVAR = :@kanto_reloaded_move_effectiveness_signature
      EBDX_TARGET_BORDERS_IVAR = :@kanto_reloaded_move_effectiveness_borders
      EBDX_TARGET_BORDER_SIZES_IVAR = :@kanto_reloaded_move_effectiveness_border_sizes
      EBDX_TARGET_VISIBLE_IVAR = :@kanto_reloaded_move_effectiveness_target_visible
      EBDX_TARGET_TEXTS_IVAR = :@kanto_reloaded_move_effectiveness_target_texts
      NATIVE_FIGHT_BORDER_KEY = "kr_move_effectiveness_border"
      NATIVE_TARGET_BORDER_PREFIX = "kr_move_effectiveness_target_"

      BorderSprite = KantoReloaded::BattleUI::BorderSprite

      class << self
        def install
          return true if @installed
          scene = install_scene_context_hook
          ebdx = install_ebdx_hooks
          @installed = scene && ebdx
          @installed
        rescue StandardError => e
          log_exception("Battle border hooks failed to install", e)
          false
        end

        def with_target_context(scene, idx_user)
          windows = target_windows(scene)
          context = if KantoReloaded::MoveEffectiveness.enabled?
                      build_target_context(scene, idx_user)
                    end
          windows.each { |window| window.instance_variable_set(CONTEXT_IVAR, context) }
          yield
        ensure
          Array(windows).each do |window|
            window.instance_variable_set(CONTEXT_IVAR, nil) if window
          end
        end

        def setup_native_fight(window, viewport)
          buttons = window.instance_variable_get(:@buttons)
          button = Array(buttons).compact.first
          return false unless button
          border = BorderSprite.new(
            viewport, button.src_rect.width, button.src_rect.height,
            :padding => 2, :radius => 7, :border_width => 2, :pulse => true
          )
          border.z = window.z + 4
          sprites = window.instance_variable_get(:@sprites)
          visibility = window.instance_variable_get(:@visibility)
          sprites[NATIVE_FIGHT_BORDER_KEY] = border
          visibility[NATIVE_FIGHT_BORDER_KEY] = false
          true
        rescue StandardError => e
          log_exception("Native fight border setup failed", e)
          false
        end

        def refresh_native_fight(window)
          border = native_sprite(window, NATIVE_FIGHT_BORDER_KEY)
          return false unless border
          unless KantoReloaded::MoveEffectiveness.enabled?
            return set_native_visibility(window, NATIVE_FIGHT_BORDER_KEY, false)
          end
          buttons = window.instance_variable_get(:@buttons)
          index = window.index.to_i
          button = Array(buttons)[index]
          battler = window.battler
          move = battler && battler.moves[index]
          effectiveness_class = KantoReloaded::MoveEffectiveness.best_opposing_class(
            battler && battler.battle, battler, move
          )
          color = KantoReloaded::MoveEffectiveness.border_color(
            effectiveness_class
          )
          unless button && color && border.apply(color)
            return set_native_visibility(window, NATIVE_FIGHT_BORDER_KEY, false)
          end
          border.z = button.z + 1
          border.follow(button)
          set_native_visibility(window, NATIVE_FIGHT_BORDER_KEY, true)
        rescue StandardError => e
          log_exception("Native fight border refresh failed", e)
          false
        end

        def update_native_fight(window)
          border = native_sprite(window, NATIVE_FIGHT_BORDER_KEY)
          return false unless border && border.active
          button = Array(window.instance_variable_get(:@buttons))[window.index.to_i]
          border.follow(button)
          border.update_pulse
          true
        rescue StandardError
          false
        end

        def setup_native_targets(window, viewport)
          buttons = window.instance_variable_get(:@buttons)
          sprites = window.instance_variable_get(:@sprites)
          visibility = window.instance_variable_get(:@visibility)
          Array(buttons).each_with_index do |button, index|
            next unless button
            key = "#{NATIVE_TARGET_BORDER_PREFIX}#{index}"
            border = BorderSprite.new(
              viewport, button.src_rect.width, button.src_rect.height,
              :padding => 2, :radius => 7, :border_width => 2
            )
            border.z = window.z + 4
            sprites[key] = border
            visibility[key] = false
          end
          true
        rescue StandardError => e
          log_exception("Native target border setup failed", e)
          false
        end

        def refresh_native_targets(window, texts = nil)
          context = window.instance_variable_get(CONTEXT_IVAR)
          buttons = window.instance_variable_get(:@buttons)
          Array(buttons).each_with_index do |button, index|
            key = "#{NATIVE_TARGET_BORDER_PREFIX}#{index}"
            border = native_sprite(window, key)
            next unless border
            if texts && Array(texts)[index].nil?
              set_native_visibility(window, key, false)
              next
            end
            color = target_color(context, index)
            unless button && color && border.apply(color)
              set_native_visibility(window, key, false)
              next
            end
            border.z = button.z + 1
            border.follow(button)
            set_native_visibility(window, key, true)
          end
          true
        rescue StandardError => e
          log_exception("Native target border refresh failed", e)
          false
        end

        def setup_ebdx_fight(window, viewport)
          border = BorderSprite.new(
            viewport, 198, 74,
            :padding => 0, :radius => 6, :border_width => 4, :pulse => true
          )
          border.z = 198
          window.instance_variable_set(EBDX_FIGHT_BORDER_IVAR, border)
          window.instance_variable_set(EBDX_FIGHT_SIGNATURE_IVAR, nil)
          true
        rescue StandardError => e
          log_exception("EBDX fight border setup failed", e)
          false
        end

        def invalidate_ebdx_fight(window)
          window.instance_variable_set(EBDX_FIGHT_SIGNATURE_IVAR, nil)
          refresh_ebdx_fight(window)
        end

        def refresh_ebdx_fight(window)
          border = window.instance_variable_get(EBDX_FIGHT_BORDER_IVAR)
          return false unless border
          effectiveness_enabled = KantoReloaded::MoveEffectiveness.enabled?
          cursor_enabled = reloaded_cursor?
          unless effectiveness_enabled || cursor_enabled
            border.deactivate
            return false
          end
          suppress_ebdx_selector(window) if cursor_enabled
          buttons = window.instance_variable_get(:@button)
          battler = window.instance_variable_get(:@battler)
          index = window.index.to_i
          button = buttons.is_a?(Hash) ? buttons[index.to_s] : nil
          move = battler && battler.moves[index]
          base_signature = [
            battler ? battler.object_id : 0,
            move ? move.object_id : 0,
            index,
            effectiveness_enabled,
            cursor_enabled
          ]
          previous = window.instance_variable_get(EBDX_FIGHT_SIGNATURE_IVAR)
          if previous && previous[0, base_signature.length] == base_signature
            allowed_indices = previous[base_signature.length]
            signature = previous
          else
            allowed_indices = ebdx_selectable_target_indices(
              window, battler, move
            )
            signature = base_signature + [allowed_indices]
          end
          if signature != previous
            effectiveness_class = effectiveness_enabled ?
              KantoReloaded::MoveEffectiveness.best_opposing_class(
                battler && battler.battle, battler, move, allowed_indices
              ) : nil
            color = KantoReloaded::MoveEffectiveness.border_color(
              effectiveness_class
            )
            color ||= KantoReloaded::BattleUI.cursor_border_color if cursor_enabled
            border.apply(color)
            window.instance_variable_set(EBDX_FIGHT_SIGNATURE_IVAR, signature)
          end
          if border.active && button
            border.z = 198
            border.follow(button)
            border.y -= 2
            border.update_pulse
          end
          border.active
        rescue StandardError => e
          log_exception("EBDX fight border refresh failed", e)
          border.deactivate if border
          false
        end

        def hide_ebdx_fight(window)
          border = window.instance_variable_get(EBDX_FIGHT_BORDER_IVAR)
          border.visible = false if border
          true
        rescue StandardError
          false
        end

        def dispose_ebdx_fight(window)
          border = window.instance_variable_get(EBDX_FIGHT_BORDER_IVAR)
          border.dispose if border && !border.disposed?
          window.instance_variable_set(EBDX_FIGHT_BORDER_IVAR, nil)
          true
        rescue StandardError
          false
        end

        def refresh_ebdx_targets(window, texts = nil)
          window.instance_variable_set(EBDX_TARGET_TEXTS_IVAR, Array(texts))
          context = window.instance_variable_get(CONTEXT_IVAR)
          effectiveness_enabled = context &&
            KantoReloaded::MoveEffectiveness.enabled?
          cursor_enabled = reloaded_cursor?
          unless effectiveness_enabled || cursor_enabled
            hide_ebdx_target_borders(window)
            return false
          end
          buttons = window.instance_variable_get(:@buttons)
          return false unless buttons.is_a?(Hash)
          borders = window.instance_variable_get(EBDX_TARGET_BORDERS_IVAR)
          borders = {} unless borders.is_a?(Hash)
          sizes = window.instance_variable_get(EBDX_TARGET_BORDER_SIZES_IVAR)
          sizes = {} unless sizes.is_a?(Hash)
          used = {}
          buttons.each do |key, button|
            index = key.to_i
            key = key.to_s
            if Array(texts)[index].nil?
              borders[key].visible = false if borders[key]
              next
            end
            color = effectiveness_enabled ? target_color(context, index) : nil
            color ||= KantoReloaded::BattleUI.cursor_border_color if cursor_enabled
            next unless button && color
            size = [button.src_rect.width.to_i, button.src_rect.height.to_i]
            border = borders[key]
            if border && sizes[key] != size
              border.dispose unless border.disposed?
              border = nil
            end
            unless border
              border = BorderSprite.new(
                window.instance_variable_get(:@viewport),
                size[0], size[1],
                :padding => 0, :radius => 4,
                :border_width => 3, :pulse => true
              )
              borders[key] = border
              sizes[key] = size
            end
            border.z = button.z + 1
            border.apply(color)
            border.follow(button)
            border.y -= 2
            border.visible = false
            used[key] = true
          end
          borders.each do |key, border|
            border.visible = false unless used[key]
          end
          window.instance_variable_set(EBDX_TARGET_BORDERS_IVAR, borders)
          window.instance_variable_set(EBDX_TARGET_BORDER_SIZES_IVAR, sizes)
          true
        rescue StandardError => e
          log_exception("EBDX target borders refresh failed", e)
          false
        end

        def show_ebdx_target_borders(window)
          window.instance_variable_set(EBDX_TARGET_VISIBLE_IVAR, true)
          update_ebdx_target_borders(window)
        rescue StandardError
          false
        end

        def hide_ebdx_target_borders(window)
          window.instance_variable_set(EBDX_TARGET_VISIBLE_IVAR, false)
          borders = window.instance_variable_get(EBDX_TARGET_BORDERS_IVAR)
          Array(borders && borders.values).each { |border| border.visible = false }
          true
        rescue StandardError
          false
        end

        def dispose_ebdx_target_borders(window)
          borders = window.instance_variable_get(EBDX_TARGET_BORDERS_IVAR)
          Array(borders && borders.values).each do |border|
            border.dispose if border && !border.disposed?
          end
          window.instance_variable_set(EBDX_TARGET_BORDERS_IVAR, {})
          window.instance_variable_set(EBDX_TARGET_BORDER_SIZES_IVAR, {})
          true
        rescue StandardError
          false
        end

        def update_ebdx_target_borders(window)
          borders = window.instance_variable_get(EBDX_TARGET_BORDERS_IVAR)
          buttons = window.instance_variable_get(:@buttons)
          return false unless borders.is_a?(Hash) && buttons.is_a?(Hash)
          return hide_ebdx_target_borders(window) unless
            window.instance_variable_get(EBDX_TARGET_VISIBLE_IVAR)
          cursor_enabled = reloaded_cursor?
          effectiveness_enabled =
            KantoReloaded::MoveEffectiveness.enabled? &&
            window.instance_variable_get(CONTEXT_IVAR)
          suppress_ebdx_selector(window) if cursor_enabled
          selected = window.index.to_i
          borders.each do |key, border|
            button = buttons[key]
            index = key.to_i
            visible = index == selected &&
              (!!effectiveness_enabled || cursor_enabled)
            unless button && visible
              border.visible = false
              next
            end
            border.follow(button)
            border.y -= 2
            if cursor_enabled && index == selected
              border.update_pulse
            else
              border.opacity = button.opacity
            end
          end
          true
        rescue StandardError
          false
        end

        def suppress_ebdx_selector(window)
          selector = window.instance_variable_get(:@sel)
          selector.visible = false if selector
          true
        rescue StandardError
          false
        end

        private

        def install_scene_context_hook
          return false unless defined?(KantoReloaded::Hooks)
          targets = []
          if defined?(PokeBattle_SceneEBDX)
            targets << [PokeBattle_SceneEBDX, :ebdx]
          end
          return false if targets.empty?
          targets.uniq.all? do |target, id|
            KantoReloaded::Hooks.wrap(
              target,
              :pbChooseTarget,
              :"move_effectiveness_target_context_#{id}"
            ) do |hook, idx_user, *_arguments|
              KantoReloaded::MoveEffectiveness::BattleBorders.with_target_context(
                self, idx_user
              ) { hook.call }
            end
          end
        end

        def install_native_hooks
          return false unless defined?(KantoReloaded::Hooks)
          return false unless defined?(FightMenuDisplay) &&
                              defined?(TargetMenuDisplay)
          results = []
          results << KantoReloaded::Hooks.wrap(
            FightMenuDisplay, :initialize, :move_effectiveness_native_fight_init
          ) do |hook, viewport, *_arguments|
            result = hook.call
            KantoReloaded::MoveEffectiveness::BattleBorders.setup_native_fight(
              self, viewport
            )
            result
          end
          results << KantoReloaded::Hooks.wrap(
            FightMenuDisplay, :refresh, :move_effectiveness_native_fight_refresh
          ) do |hook, *_arguments|
            result = hook.call
            KantoReloaded::MoveEffectiveness::BattleBorders.refresh_native_fight(
              self
            )
            result
          end
          results << KantoReloaded::Hooks.wrap(
            FightMenuDisplay, :update, :move_effectiveness_native_fight_update
          ) do |hook, *_arguments|
            result = hook.call
            KantoReloaded::MoveEffectiveness::BattleBorders.update_native_fight(
              self
            )
            result
          end
          results << KantoReloaded::Hooks.wrap(
            TargetMenuDisplay, :initialize, :move_effectiveness_native_target_init
          ) do |hook, viewport, *_arguments|
            result = hook.call
            KantoReloaded::MoveEffectiveness::BattleBorders.setup_native_targets(
              self, viewport
            )
            result
          end
          results << KantoReloaded::Hooks.wrap(
            TargetMenuDisplay, :setDetails, :move_effectiveness_native_target_refresh
          ) do |hook, texts, *_arguments|
            result = hook.call
            KantoReloaded::MoveEffectiveness::BattleBorders.refresh_native_targets(
              self, texts
            )
            result
          end
          results.all?
        end

        def install_ebdx_hooks
          return false unless defined?(KantoReloaded::Hooks)
          return false unless defined?(FightWindowEBDX) &&
                              defined?(TargetWindowEBDX)
          results = []
          results << KantoReloaded::Hooks.wrap(
            FightWindowEBDX, :initialize, :move_effectiveness_ebdx_fight_init
          ) do |hook, viewport, *_arguments|
            result = hook.call
            KantoReloaded::MoveEffectiveness::BattleBorders.setup_ebdx_fight(
              self, viewport
            )
            result
          end
          results << KantoReloaded::Hooks.wrap(
            FightWindowEBDX, :generateButtons, :move_effectiveness_ebdx_fight_generate
          ) do |hook, *_arguments|
            result = hook.call
            KantoReloaded::MoveEffectiveness::BattleBorders.invalidate_ebdx_fight(
              self
            )
            result
          end
          results << KantoReloaded::Hooks.wrap(
            FightWindowEBDX, :showPlay, :move_effectiveness_ebdx_fight_show
          ) do |hook, *_arguments|
            KantoReloaded::MoveEffectiveness::BattleBorders.hide_ebdx_fight(self)
            result = hook.call
            KantoReloaded::MoveEffectiveness::BattleBorders.refresh_ebdx_fight(
              self
            )
            result
          end
          results << KantoReloaded::Hooks.wrap(
            FightWindowEBDX, :hidePlay, :move_effectiveness_ebdx_fight_hide
          ) do |hook, *_arguments|
            KantoReloaded::MoveEffectiveness::BattleBorders.hide_ebdx_fight(self)
            hook.call
          end
          results << KantoReloaded::Hooks.wrap(
            FightWindowEBDX, :update, :move_effectiveness_ebdx_fight_update
          ) do |hook, *_arguments|
            result = hook.call
            KantoReloaded::MoveEffectiveness::BattleBorders.refresh_ebdx_fight(
              self
            )
            result
          end
          results << KantoReloaded::Hooks.wrap(
            FightWindowEBDX, :dispose, :move_effectiveness_ebdx_fight_dispose
          ) do |hook, *_arguments|
            begin
              hook.call
            ensure
              KantoReloaded::MoveEffectiveness::BattleBorders.dispose_ebdx_fight(
                self
              )
            end
          end
          results << KantoReloaded::Hooks.wrap(
            TargetWindowEBDX, :refresh, :move_effectiveness_ebdx_target_refresh
          ) do |hook, texts, *_arguments|
            result = hook.call
            KantoReloaded::MoveEffectiveness::BattleBorders.refresh_ebdx_targets(
              self, texts
            )
            result
          end
          results << KantoReloaded::Hooks.wrap(
            TargetWindowEBDX, :showPlay, :move_effectiveness_ebdx_target_show
          ) do |hook, *_arguments|
            KantoReloaded::MoveEffectiveness::BattleBorders.hide_ebdx_target_borders(
              self
            )
            result = hook.call
            KantoReloaded::MoveEffectiveness::BattleBorders.show_ebdx_target_borders(
              self
            )
            result
          end
          results << KantoReloaded::Hooks.wrap(
            TargetWindowEBDX, :hidePlay, :move_effectiveness_ebdx_target_hide
          ) do |hook, *_arguments|
            KantoReloaded::MoveEffectiveness::BattleBorders.hide_ebdx_target_borders(
              self
            )
            hook.call
          end
          results << KantoReloaded::Hooks.wrap(
            TargetWindowEBDX, :update, :move_effectiveness_ebdx_target_update
          ) do |hook, *_arguments|
            result = hook.call
            KantoReloaded::MoveEffectiveness::BattleBorders.update_ebdx_target_borders(
              self
            )
            result
          end
          results << KantoReloaded::Hooks.wrap(
            TargetWindowEBDX, :dispose, :move_effectiveness_ebdx_target_dispose
          ) do |hook, *_arguments|
            begin
              hook.call
            ensure
              KantoReloaded::MoveEffectiveness::BattleBorders.dispose_ebdx_target_borders(
                self
              )
            end
          end
          results.all?
        end

        def target_windows(scene)
          windows = []
          windows << scene.instance_variable_get(:@targetWindow)
          sprites = scene.instance_variable_get(:@sprites)
          windows << sprites["targetWindow"] if sprites.is_a?(Hash)
          windows.compact.uniq
        rescue StandardError
          []
        end

        def build_target_context(scene, idx_user)
          battle = scene.instance_variable_get(:@battle)
          return nil unless battle
          user = battle.battlers[idx_user.to_i]
          choice = battle.choices[idx_user.to_i] rescue nil
          move = choice && choice[0] == :UseMove ? choice[2] : nil
          return nil unless user && move
          classes = {}
          KantoReloaded::MoveEffectiveness.valid_targets(
            battle, user, move
          ).each do |target|
            classes[target.index] =
              KantoReloaded::MoveEffectiveness.class_against(
                battle, user, move, target
              )
          end
          {
            :battle => battle,
            :user => user,
            :move => move,
            :classes => classes
          }
        rescue StandardError
          nil
        end

        def target_color(context, index)
          return nil unless context.is_a?(Hash)
          return nil unless KantoReloaded::MoveEffectiveness.enabled?
          classes = context[:classes]
          return nil unless classes.is_a?(Hash)
          effectiveness_class = classes[index.to_i]
          KantoReloaded::MoveEffectiveness.border_color(effectiveness_class)
        rescue StandardError
          nil
        end

        def ebdx_selectable_target_indices(window, user, move)
          return nil unless window && user && move
          scene = window.instance_variable_get(:@scene)
          return nil unless scene && scene.respond_to?(:pbCreateTargetTexts)
          target_data = move.pbTarget(user)
          texts = scene.pbCreateTargetTexts(user.index, target_data)
          indices = []
          Array(texts).each_with_index do |text, index|
            indices << index unless text.nil?
          end
          indices
        rescue StandardError => e
          log_exception("Could not read EBDX selectable targets", e)
          nil
        end

        def reloaded_cursor?
          defined?(KantoReloaded::BattleUI) &&
            KantoReloaded::BattleUI.cursor_replacement?
        rescue StandardError
          false
        end

        def native_sprite(window, key)
          sprites = window.instance_variable_get(:@sprites)
          sprites.is_a?(Hash) ? sprites[key] : nil
        end

        def set_native_visibility(window, key, visible)
          visibility = window.instance_variable_get(:@visibility)
          sprite = native_sprite(window, key)
          visibility[key] = !!visible if visibility.is_a?(Hash)
          parent_visible = window.respond_to?(:visible) ? window.visible : true
          sprite.visible = !!visible && parent_visible if sprite
          !!visible
        end

        def log_exception(message, error)
          KantoReloaded::Log.exception(
            message, error, :channel => :move_effectiveness
          ) if defined?(KantoReloaded::Log)
        end
      end
    end
  end
end

KantoReloaded::MoveEffectiveness.boot
