#==============================================================================
# Kanto Reloaded - Battle UI
#==============================================================================

module KantoReloaded
  module BattleUI
    RELOADED_CURSOR_SETTING = :"battle_ui.reloaded_ebdx_cursor"
    DEFAULT_RELOADED_CURSOR = 1
    EBDX_MOVE_Z = 102
    EBDX_SELECTED_MOVE_Z = 104
    EBDX_TYPE_INDICATOR_Z = 105
    EBDX_TARGET_ICON_SIZE = 36
    EBDX_CURSOR_PADDING = 2
    EBDX_LAYER_SIGNATURE_IVAR = :@kanto_reloaded_ebdx_move_layer_signature
    EBDX_COMMAND_BORDER_IVAR = :@kanto_reloaded_ebdx_command_border
    EBDX_COMMAND_BORDER_SIZE_IVAR = :@kanto_reloaded_ebdx_command_border_size
    EBDX_COMMAND_VISIBLE_IVAR = :@kanto_reloaded_ebdx_command_visible
    EBDX_BAG_BORDER_IVAR = :@kanto_reloaded_ebdx_bag_border
    EBDX_BAG_BORDER_SIZE_IVAR = :@kanto_reloaded_ebdx_bag_border_size
    EBDX_BAG_BACK_BOUNDS_IVAR = :@kanto_reloaded_ebdx_bag_back_bounds
    EBDX_BAG_VISIBLE_IVAR = :@kanto_reloaded_ebdx_bag_visible
    EBDX_BAG_OWNER_IVAR = :@kanto_reloaded_ebdx_bag_owner
    EBDX_TARGET_ICON_CACHE_IVAR = :@kanto_reloaded_ebdx_target_icon_cache
    EBDX_TARGET_ICON_NEXT_SCAN_IVAR = :@kanto_reloaded_ebdx_target_icon_next_scan

    class BorderSprite < Sprite
      attr_reader :active

      def initialize(viewport, width, height, options = {})
        super(viewport)
        @border_width = [options[:border_width].to_i, 2].max
        @radius = [options[:radius].to_i, 2].max
        @padding = options[:padding].to_i
        @pulse = !!options[:pulse]
        @active = false
        @color_signature = nil
        self.bitmap = Bitmap.new(
          [width.to_i + @padding * 2, 1].max,
          [height.to_i + @padding * 2, 1].max
        )
        self.visible = false
      end

      def apply(color)
        unless color
          deactivate
          return false
        end
        signature = [color.red, color.green, color.blue]
        redraw(color) if signature != @color_signature
        @color_signature = signature
        @active = true
        self.visible = true
        true
      end

      def deactivate
        @active = false
        self.visible = false
        false
      end

      def follow(sprite)
        return deactivate unless sprite && !sprite.disposed?
        self.x = sprite.x - sprite.ox - @padding
        self.y = sprite.y - sprite.oy - @padding
        self.opacity = sprite.opacity if sprite.respond_to?(:opacity)
        self.visible = @active && sprite.visible
        true
      rescue StandardError
        deactivate
      end

      def update_pulse
        return unless @active && @pulse
        frame = Graphics.frame_count rescue 0
        pulse = Math.sin(frame * Math::PI / 20.0) * 0.5 + 0.5
        self.opacity = 180 + (pulse * 75).to_i
      rescue StandardError
        self.opacity = 255
      end

      def dispose
        self.bitmap.dispose if self.bitmap && !self.bitmap.disposed?
        super
      end

      private

      def redraw(color)
        bitmap = self.bitmap
        bitmap.clear
        width = bitmap.width
        height = bitmap.height
        transparent = Color.new(0, 0, 0, 0)
        KantoReloaded::UI::Draw.rounded_rect(
          bitmap, 0, 0, width, height, @radius, color
        )
        inner_width = width - @border_width * 2
        inner_height = height - @border_width * 2
        return if inner_width <= 0 || inner_height <= 0
        KantoReloaded::UI::Draw.rounded_rect(
          bitmap,
          @border_width,
          @border_width,
          inner_width,
          inner_height,
          [@radius - @border_width, 0].max,
          transparent
        )
      end
    end

    class TargetIconSprite < PokemonIconSprite
      def use_big_icon?
        false
      end
    end

    class << self
      def install
        return true if @installed
        return false unless defined?(KantoReloaded::Hooks)
        return false unless defined?(KantoReloaded::Settings)
        return false unless defined?(CommandWindowEBDX)
        return false unless defined?(FightWindowEBDX)
        return false unless defined?(TargetWindowEBDX)
        return false unless defined?(BagWindowEBDX)
        return false unless defined?(SelectorSprite)
        settings = register_settings
        commands = install_command_cursor_hooks
        bags = install_bag_cursor_hooks
        generated = KantoReloaded::Hooks.wrap(
          FightWindowEBDX, :generateButtons, :ebdx_selected_move_layers_generate
        ) do |hook, *_arguments|
          result = hook.call
          KantoReloaded::BattleUI.invalidate_ebdx_move_layers(self)
          result
        end
        updated = KantoReloaded::Hooks.wrap(
          FightWindowEBDX, :update, :ebdx_selected_move_layers_update
        ) do |hook, *_arguments|
          result = hook.call
          KantoReloaded::BattleUI.refresh_ebdx_move_layers(self)
          result
        end
        target_icons = KantoReloaded::Hooks.wrap(
          TargetWindowEBDX, :refresh, :ebdx_pokemon_target_icons
        ) do |hook, texts, *_arguments|
          result = hook.call
          KantoReloaded::BattleUI.redraw_ebdx_target_icons(self, texts)
          result
        end
        target_cache = install_target_icon_cache_hooks
        @installed = settings && commands && bags &&
          generated && updated && target_icons && target_cache
      rescue StandardError => e
        log_exception("EBDX battle UI failed to install", e)
        false
      end

      def cursor_replacement?
        value = KantoReloaded::Settings.get(
          RELOADED_CURSOR_SETTING, DEFAULT_RELOADED_CURSOR
        )
        value == true || (value.respond_to?(:to_i) && value.to_i == 1)
      rescue StandardError
        true
      end

      def cursor_border_color
        if defined?(KantoReloaded::MoveEffectiveness) &&
           KantoReloaded::MoveEffectiveness.respond_to?(:border_color)
          color = KantoReloaded::MoveEffectiveness.border_color(:neutral)
          return color if color
        end
        Color.new(64, 216, 232)
      rescue StandardError
        Color.new(64, 216, 232)
      end

      def show_ebdx_command_cursor(window)
        window.instance_variable_set(EBDX_COMMAND_VISIBLE_IVAR, true)
        refresh_ebdx_command_cursor(window)
      end

      def hide_ebdx_command_cursor(window)
        window.instance_variable_set(EBDX_COMMAND_VISIBLE_IVAR, false)
        border = window.instance_variable_get(EBDX_COMMAND_BORDER_IVAR)
        border.visible = false if border
        true
      rescue StandardError
        false
      end

      def refresh_ebdx_command_cursor(window)
        border = window.instance_variable_get(EBDX_COMMAND_BORDER_IVAR)
        unless cursor_replacement? &&
               window.instance_variable_get(EBDX_COMMAND_VISIBLE_IVAR)
          border.deactivate if border
          return false
        end
        sprites = window.instance_variable_get(:@sprites)
        return false unless sprites.is_a?(Hash)
        button = sprites["b#{window.index.to_i}"]
        return false unless button && button.src_rect
        border = ensure_ebdx_command_border(window, button)
        return false unless border && border.apply(cursor_border_color)
        selector = sprites["sel"]
        selector.visible = false if selector
        border.z = 98
        border.follow(button)
        border.y -= 2
        border.update_pulse
        true
      rescue StandardError => e
        log_exception("EBDX command cursor failed to refresh", e)
        false
      end

      def dispose_ebdx_command_cursor(window)
        border = window.instance_variable_get(EBDX_COMMAND_BORDER_IVAR)
        border.dispose if border && !border.disposed?
        window.instance_variable_set(EBDX_COMMAND_BORDER_IVAR, nil)
        window.instance_variable_set(EBDX_COMMAND_BORDER_SIZE_IVAR, nil)
        true
      rescue StandardError
        false
      end

      def show_ebdx_bag_cursor(window)
        window.instance_variable_set(EBDX_BAG_VISIBLE_IVAR, true)
        refresh_ebdx_bag_cursor(window)
      end

      def hide_ebdx_bag_cursor(window)
        window.instance_variable_set(EBDX_BAG_VISIBLE_IVAR, false)
        border = window.instance_variable_get(EBDX_BAG_BORDER_IVAR)
        border.visible = false if border
        suppress_ebdx_bag_selector(window) if cursor_replacement?
        true
      rescue StandardError
        false
      end

      def refresh_ebdx_bag_cursor(window)
        border = window.instance_variable_get(EBDX_BAG_BORDER_IVAR)
        unless cursor_replacement?
          border.deactivate if border
          return false
        end
        selector = ebdx_bag_selector(window)
        selector.visible = false if selector
        unless window.instance_variable_get(EBDX_BAG_VISIBLE_IVAR)
          border.visible = false if border
          return false
        end
        anchor = selector && selector.anchor
        return false unless anchor && anchor.src_rect
        bounds = ebdx_bag_anchor_bounds(window, anchor)
        border = ensure_ebdx_bag_border(window, anchor, bounds)
        return false unless border && border.apply(cursor_border_color)
        border.z = 99_998
        border.follow(anchor)
        if ebdx_bag_back_anchor?(window, anchor)
          border.x = anchor.x - anchor.ox + bounds.x
          border.y = anchor.y - anchor.oy + bounds.y - 2
        else
          border.y -= 2
        end
        border.update_pulse
        true
      rescue StandardError => e
        log_exception("EBDX bag cursor failed to refresh", e)
        false
      end

      def dispose_ebdx_bag_cursor(window)
        border = window.instance_variable_get(EBDX_BAG_BORDER_IVAR)
        border.dispose if border && !border.disposed?
        window.instance_variable_set(EBDX_BAG_BORDER_IVAR, nil)
        window.instance_variable_set(EBDX_BAG_BORDER_SIZE_IVAR, nil)
        window.instance_variable_set(EBDX_BAG_BACK_BOUNDS_IVAR, nil)
        true
      rescue StandardError
        false
      end

      def invalidate_ebdx_move_layers(window)
        window.instance_variable_set(EBDX_LAYER_SIGNATURE_IVAR, nil)
        refresh_ebdx_move_layers(window)
      end

      def refresh_ebdx_move_layers(window)
        buttons = window.instance_variable_get(:@button)
        return false unless buttons.is_a?(Hash)
        selected_index = window.index.to_i
        signature = [buttons.object_id, selected_index]
        return true if window.instance_variable_get(EBDX_LAYER_SIGNATURE_IVAR) == signature
        buttons.each do |key, button|
          next unless button
          next if button.respond_to?(:disposed?) && button.disposed?
          button.z = key.to_i == selected_index ?
            EBDX_SELECTED_MOVE_Z : EBDX_MOVE_Z
        end
        type_indicator = window.instance_variable_get(:@typeInd)
        if type_indicator &&
           !(type_indicator.respond_to?(:disposed?) && type_indicator.disposed?)
          type_indicator.z = EBDX_TYPE_INDICATOR_Z
        end
        window.instance_variable_set(EBDX_LAYER_SIGNATURE_IVAR, signature)
        true
      rescue StandardError => e
        log_exception("EBDX selected move layering failed", e)
        false
      end

      def redraw_ebdx_target_icons(window, texts)
        buttons = window.instance_variable_get(:@buttons)
        battle = window.instance_variable_get(:@battle)
        return false unless buttons.is_a?(Hash) && battle
        overrides = []
        buttons.each do |key, button|
          index = key.to_i
          next unless button && button.bitmap
          next if Array(texts)[index].nil?
          battler = Array(battle.battlers)[index]
          next unless battler && battler.hp.to_i > 0
          pokemon = battler.displayPokemon
          next unless pokemon && target_icon_override_needed?(pokemon)
          overrides << [button, pokemon]
        end
        return true if overrides.empty?
        path = window.instance_variable_get(:@path).to_s
        image = window.instance_variable_get(:@btnImg).to_s
        background = pbBitmap(path + image)
        overrides.each do |button, pokemon|
          button.bitmap.clear
          button.bitmap.blt(0, 0, background, background.rect)
          draw_ebdx_target_icon(button.bitmap, pokemon, window)
        end
        true
      rescue StandardError => e
        log_exception("EBDX target icons failed to render", e)
        false
      ensure
        background.dispose if background && !background.disposed?
      end

      private

      def register_settings
        definition = KantoReloaded::Settings.register(
          RELOADED_CURSOR_SETTING, {
            :name => "Reloaded EBDX Cursor",
            :description => "Replace EBDX corner selectors with rounded Kanto Reloaded borders.",
            :type => :toggle,
            :category => :interface,
            :scope => :global,
            :owner => :kanto_reloaded,
            :value_style => :integer,
            :default => DEFAULT_RELOADED_CURSOR,
            :priority => 81
          }
        )
        !definition.nil?
      end

      def install_command_cursor_hooks
        results = []
        results << KantoReloaded::Hooks.wrap(
          CommandWindowEBDX, :initialize, :reloaded_ebdx_command_cursor_init
        ) do |hook, *_arguments|
          result = hook.call
          self.instance_variable_set(EBDX_COMMAND_VISIBLE_IVAR, false)
          result
        end
        results << KantoReloaded::Hooks.wrap(
          CommandWindowEBDX, :refreshCommands, :reloaded_ebdx_command_cursor_refresh
        ) do |hook, *_arguments|
          result = hook.call
          KantoReloaded::BattleUI.refresh_ebdx_command_cursor(self)
          result
        end
        results << KantoReloaded::Hooks.wrap(
          CommandWindowEBDX, :showPlay, :reloaded_ebdx_command_cursor_show
        ) do |hook, *_arguments|
          result = hook.call
          KantoReloaded::BattleUI.show_ebdx_command_cursor(self)
          result
        end
        results << KantoReloaded::Hooks.wrap(
          CommandWindowEBDX, :hidePlay, :reloaded_ebdx_command_cursor_hide
        ) do |hook, *_arguments|
          KantoReloaded::BattleUI.hide_ebdx_command_cursor(self)
          hook.call
        end
        results << KantoReloaded::Hooks.wrap(
          CommandWindowEBDX, :update, :reloaded_ebdx_command_cursor_update
        ) do |hook, *_arguments|
          result = hook.call
          KantoReloaded::BattleUI.refresh_ebdx_command_cursor(self)
          result
        end
        results << KantoReloaded::Hooks.wrap(
          CommandWindowEBDX, :dispose, :reloaded_ebdx_command_cursor_dispose
        ) do |hook, *_arguments|
          begin
            hook.call
          ensure
            KantoReloaded::BattleUI.dispose_ebdx_command_cursor(self)
          end
        end
        results.all?
      end

      def install_bag_cursor_hooks
        results = []
        results << KantoReloaded::Hooks.wrap(
          BagWindowEBDX, :initialize, :reloaded_ebdx_bag_cursor_init
        ) do |hook, *_arguments|
          result = hook.call
          self.instance_variable_set(EBDX_BAG_VISIBLE_IVAR, false)
          selector = KantoReloaded::BattleUI.send(
            :ebdx_bag_selector, self
          )
          selector.instance_variable_set(EBDX_BAG_OWNER_IVAR, self) if selector
          result
        end
        results << KantoReloaded::Hooks.wrap(
          BagWindowEBDX, :show, :reloaded_ebdx_bag_cursor_show
        ) do |hook, *_arguments|
          result = hook.call
          KantoReloaded::BattleUI.show_ebdx_bag_cursor(self)
          result
        end
        results << KantoReloaded::Hooks.wrap(
          BagWindowEBDX, :hide, :reloaded_ebdx_bag_cursor_hide
        ) do |hook, *_arguments|
          KantoReloaded::BattleUI.hide_ebdx_bag_cursor(self)
          hook.call
        end
        results << KantoReloaded::Hooks.wrap(
          BagWindowEBDX, :visible=, :reloaded_ebdx_bag_cursor_visibility
        ) do |hook, value, *_arguments|
          result = hook.call
          if value
            KantoReloaded::BattleUI.show_ebdx_bag_cursor(self)
          else
            KantoReloaded::BattleUI.hide_ebdx_bag_cursor(self)
          end
          result
        end
        results << KantoReloaded::Hooks.wrap(
          BagWindowEBDX, :clearSel, :reloaded_ebdx_bag_cursor_clear
        ) do |hook, *_arguments|
          result = hook.call
          KantoReloaded::BattleUI.hide_ebdx_bag_cursor(self)
          result
        end
        results << KantoReloaded::Hooks.wrap(
          BagWindowEBDX, :dispose, :reloaded_ebdx_bag_cursor_dispose
        ) do |hook, *_arguments|
          begin
            hook.call
          ensure
            KantoReloaded::BattleUI.dispose_ebdx_bag_cursor(self)
          end
        end
        results << KantoReloaded::Hooks.wrap(
          SelectorSprite, :update, :reloaded_ebdx_bag_selector_update
        ) do |hook, *_arguments|
          result = hook.call
          owner = self.instance_variable_get(EBDX_BAG_OWNER_IVAR)
          KantoReloaded::BattleUI.refresh_ebdx_bag_cursor(owner) if owner
          result
        end
        results.all?
      end

      def install_target_icon_cache_hooks
        return false unless defined?(PokeBattle_SceneEBDX)
        results = []
        results << KantoReloaded::Hooks.wrap(
          PokeBattle_SceneEBDX,
          :pbUpdate,
          :ebdx_target_icon_cache_prewarm
        ) do |hook, *_arguments|
          result = hook.call
          KantoReloaded::BattleUI.send(
            :prewarm_ebdx_target_icons, self
          )
          result
        end
        results << KantoReloaded::Hooks.wrap(
          TargetWindowEBDX,
          :dispose,
          :ebdx_target_icon_cache_dispose
        ) do |hook, *_arguments|
          begin
            hook.call
          ensure
            KantoReloaded::BattleUI.send(
              :dispose_ebdx_target_icon_cache, self
            )
          end
        end
        results.all?
      end

      def ensure_ebdx_command_border(window, button)
        size = [button.src_rect.width.to_i, button.src_rect.height.to_i]
        border = window.instance_variable_get(EBDX_COMMAND_BORDER_IVAR)
        stored_size = window.instance_variable_get(EBDX_COMMAND_BORDER_SIZE_IVAR)
        if border && stored_size != size
          border.dispose unless border.disposed?
          border = nil
        end
        unless border
          border = BorderSprite.new(
            window.instance_variable_get(:@viewport),
            size[0], size[1],
            :padding => EBDX_CURSOR_PADDING,
            :radius => 8,
            :border_width => 4,
            :pulse => true
          )
          window.instance_variable_set(EBDX_COMMAND_BORDER_IVAR, border)
          window.instance_variable_set(EBDX_COMMAND_BORDER_SIZE_IVAR, size)
        end
        border
      end

      def ensure_ebdx_bag_border(window, anchor, bounds)
        back = ebdx_bag_back_anchor?(window, anchor)
        padding = back ? 0 : EBDX_CURSOR_PADDING
        size = [bounds.width.to_i, bounds.height.to_i, padding]
        border = window.instance_variable_get(EBDX_BAG_BORDER_IVAR)
        stored_size = window.instance_variable_get(EBDX_BAG_BORDER_SIZE_IVAR)
        if border && stored_size != size
          border.dispose unless border.disposed?
          border = nil
        end
        unless border
          border = BorderSprite.new(
            window.instance_variable_get(:@viewport),
            size[0], size[1],
            :padding => padding,
            :radius => 8,
            :border_width => 4,
            :pulse => true
          )
          window.instance_variable_set(EBDX_BAG_BORDER_IVAR, border)
          window.instance_variable_set(EBDX_BAG_BORDER_SIZE_IVAR, size)
        end
        border
      end

      def ebdx_bag_selector(window)
        sprites = window && window.instance_variable_get(:@sprites)
        sprites.is_a?(Hash) ? sprites["sel"] : nil
      end

      def ebdx_bag_back_anchor?(window, anchor)
        sprites = window && window.instance_variable_get(:@sprites)
        sprites.is_a?(Hash) && sprites["pocket5"].equal?(anchor)
      end

      def ebdx_bag_anchor_bounds(window, anchor)
        source = anchor.src_rect
        full = Rect.new(0, 0, source.width.to_i, source.height.to_i)
        return full unless ebdx_bag_back_anchor?(window, anchor)
        bitmap = anchor.bitmap
        return full unless bitmap && !bitmap.disposed?
        signature = [
          bitmap.object_id,
          source.x.to_i, source.y.to_i,
          source.width.to_i, source.height.to_i
        ]
        cached = window.instance_variable_get(EBDX_BAG_BACK_BOUNDS_IVAR)
        return cached[1] if cached && cached[0] == signature
        min_x = source.width.to_i
        min_y = source.height.to_i
        max_x = -1
        max_y = -1
        source.height.to_i.times do |y|
          source.width.to_i.times do |x|
            color = bitmap.get_pixel(source.x.to_i + x, source.y.to_i + y)
            next if color.alpha.to_i <= 0
            min_x = x if x < min_x
            min_y = y if y < min_y
            max_x = x if x > max_x
            max_y = y if y > max_y
          end
        end
        bounds = max_x >= min_x && max_y >= min_y ?
          Rect.new(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1) :
          full
        window.instance_variable_set(
          EBDX_BAG_BACK_BOUNDS_IVAR, [signature, bounds]
        )
        bounds
      rescue StandardError => e
        log_exception("EBDX bag Back bounds could not be measured", e)
        full || Rect.new(0, 0, 1, 1)
      end

      def suppress_ebdx_bag_selector(window)
        selector = ebdx_bag_selector(window)
        selector.visible = false if selector
        true
      rescue StandardError
        false
      end

      def prewarm_ebdx_target_icons(scene)
        window = scene.instance_variable_get(:@targetWindow)
        return false unless window && window.is_a?(TargetWindowEBDX)
        battle = window.instance_variable_get(:@battle)
        return false unless battle
        frame = Graphics.frame_count rescue 0
        next_scan = window.instance_variable_get(
          EBDX_TARGET_ICON_NEXT_SCAN_IVAR
        ).to_i
        return false if frame < next_scan
        Array(battle.battlers).compact.each do |battler|
          pokemon = battler.displayPokemon rescue nil
          next unless pokemon && target_icon_override_needed?(pokemon)
          key = target_icon_cache_key(pokemon)
          cache = target_icon_cache(window)
          next if cache[key] && !cache[key].disposed?
          target_icon_bitmap(window, pokemon)
          window.instance_variable_set(
            EBDX_TARGET_ICON_NEXT_SCAN_IVAR, frame + 15
          )
          return true
        end
        window.instance_variable_set(
          EBDX_TARGET_ICON_NEXT_SCAN_IVAR, frame + 15
        )
        false
      rescue StandardError => e
        log_exception("EBDX target icon prewarm failed", e)
        false
      end

      def dispose_ebdx_target_icon_cache(window)
        cache = window.instance_variable_get(EBDX_TARGET_ICON_CACHE_IVAR)
        cache.each_value do |bitmap|
          bitmap.dispose if bitmap && !bitmap.disposed?
        end if cache.is_a?(Hash)
        window.instance_variable_set(EBDX_TARGET_ICON_CACHE_IVAR, {})
        window.instance_variable_set(EBDX_TARGET_ICON_NEXT_SCAN_IVAR, 0)
        true
      rescue StandardError
        false
      end

      def draw_ebdx_target_icon(bitmap, pokemon, window)
        icon_bitmap = target_icon_bitmap(window, pokemon)
        return false unless icon_bitmap && !icon_bitmap.disposed?
        source = icon_bitmap.rect
        maximum_size = [
          EBDX_TARGET_ICON_SIZE,
          bitmap.width - 4,
          bitmap.height - 4
        ].min
        scale = [
          maximum_size.to_f / source.width,
          maximum_size.to_f / source.height
        ].min
        width = [(source.width * scale).round, 1].max
        height = [(source.height * scale).round, 1].max
        destination = Rect.new(
          (bitmap.width - width) / 2,
          (bitmap.height - height) / 2,
          width,
          height
        )
        bitmap.stretch_blt(destination, icon_bitmap, source, 216)
        true
      end

      def target_icon_bitmap(window, pokemon)
        cache = target_icon_cache(window)
        key = target_icon_cache_key(pokemon)
        cached = cache[key]
        return cached if cached && !cached.disposed?
        icon = TargetIconSprite.new(pokemon)
        source = icon.src_rect
        return nil unless icon.bitmap && source &&
                          source.width > 0 && source.height > 0
        cached = Bitmap.new(source.width, source.height)
        cached.blt(0, 0, icon.bitmap, source)
        cache[key] = cached
      ensure
        icon.dispose if icon && !icon.disposed?
      end

      def target_icon_cache(window)
        cache = window.instance_variable_get(EBDX_TARGET_ICON_CACHE_IVAR)
        unless cache.is_a?(Hash)
          cache = {}
          window.instance_variable_set(EBDX_TARGET_ICON_CACHE_IVAR, cache)
        end
        cache
      end

      def target_icon_cache_key(pokemon)
        [
          pokemon.object_id,
          pokemon.species,
          (pokemon.form rescue 0),
          (pokemon.spriteform_head rescue nil),
          (pokemon.spriteform_body rescue nil),
          (pokemon.shiny? rescue false),
          (pokemon.shinyValue? rescue nil),
          (pokemon.kuraycustomfile? rescue nil)
        ]
      end

      def target_icon_override_needed?(pokemon)
        return true if pokemon.respond_to?(:isFusion?) && pokemon.isFusion?
        filename = GameData::Species.icon_filename_from_pokemon(pokemon)
        return true if filename.nil?
        filename.to_s.downcase.include?("icondna")
      rescue
        true
      end

      def log_exception(message, error)
        KantoReloaded::Log.exception(
          message, error, :channel => :battle_ui
        ) if defined?(KantoReloaded::Log)
      end
    end
  end
end

KantoReloaded::BattleUI.install
