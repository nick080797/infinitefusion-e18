#==============================================================================
# Kanto Reloaded - Move Effectiveness
#==============================================================================

module KantoReloaded
  module MoveEffectiveness
    MODULE_ID = :move_effectiveness
    SETTINGS_ACTION = :move_effectiveness_settings
    ENABLED_SETTING = :"move_effectiveness.enabled"
    NEUTRAL_COLOR_SETTING = :"move_effectiveness.neutral_color"
    QUAD_COLOR_SETTING = :"move_effectiveness.quad_color"
    SUPER_COLOR_SETTING = :"move_effectiveness.super_color"
    RESISTED_COLOR_SETTING = :"move_effectiveness.resisted_color"
    QUARTER_COLOR_SETTING = :"move_effectiveness.quarter_color"

    PALETTE = [
      { :id => :green,  :name => "Green",  :rgb => [64, 220, 96] },
      { :id => :cyan,   :name => "Cyan",   :rgb => [64, 216, 232] },
      { :id => :orange, :name => "Orange", :rgb => [248, 160, 64] },
      { :id => :red,    :name => "Red",    :rgb => [240, 72, 72] },
      { :id => :yellow, :name => "Yellow", :rgb => [240, 224, 88] },
      { :id => :blue,   :name => "Blue",   :rgb => [88, 160, 248] },
      { :id => :purple, :name => "Purple", :rgb => [184, 120, 232] },
      { :id => :pink,   :name => "Pink",   :rgb => [248, 128, 192] },
      { :id => :white,  :name => "White",  :rgb => [240, 240, 240] },
      { :id => :gray,   :name => "Gray",   :rgb => [152, 158, 168] },
      { :id => :black,  :name => "Black",  :rgb => [16, 16, 20] }
    ].freeze

    DEFAULT_NEUTRAL_COLOR = 1
    DEFAULT_QUAD_COLOR = 0
    DEFAULT_SUPER_COLOR = 4
    DEFAULT_RESISTED_COLOR = 2
    DEFAULT_QUARTER_COLOR = 3
    IMMUNE_COLOR = [152, 158, 168].freeze

    EFFECTIVENESS_RANKS = {
      :immune => 0,
      :quarter => 1,
      :resisted => 2,
      :neutral => 3,
      :super => 4,
      :quad => 5
    }.freeze

    class ColorOption < EnumOption
      def initialize(setting_key)
        @setting_key = setting_key
        definition = KantoReloaded::Settings.definition(setting_key)
        super(
          _INTL(definition[:name]),
          KantoReloaded::MoveEffectiveness.palette_names,
          proc {
            KantoReloaded::Settings.get(
              setting_key, definition[:default]
            ).to_i
          },
          proc { |value| KantoReloaded::Settings.set(setting_key, value.to_i) },
          _INTL(definition[:description])
        )
      end

      def swatch_color(index = nil)
        value = index.nil? ? get : index
        KantoReloaded::MoveEffectiveness.palette_color(value)
      end

      def disabled?
        if @setting_key == NEUTRAL_COLOR_SETTING &&
           defined?(KantoReloaded::BattleUI) &&
           KantoReloaded::BattleUI.cursor_replacement?
          return false
        end
        !KantoReloaded::MoveEffectiveness.enabled?
      end

      def non_interactive?
        disabled?
      end
    end

    class FixedColorOption < EnumOption
      def initialize(name, color, description)
        @fixed_color = color
        super(
          _INTL(name),
          [_INTL("Gray")],
          proc { 0 },
          proc { |_value| },
          _INTL(description)
        )
      end

      def swatch_color(_index = nil)
        @fixed_color
      end

      def non_interactive?
        true
      end
    end

    class SettingsScene < KantoReloaded::SettingsUI::BaseScene
      def scene_title
        "Move Effectiveness"
      end

      def scene_description
        "Configure battle-menu borders that preview move effectiveness."
      end

      def pbGetOptions(_inloadscreen = false)
        rows = []
        rows << setting_row(ENABLED_SETTING)
        rows << ColorOption.new(NEUTRAL_COLOR_SETTING)
        rows << ColorOption.new(QUAD_COLOR_SETTING)
        rows << ColorOption.new(SUPER_COLOR_SETTING)
        rows << ColorOption.new(RESISTED_COLOR_SETTING)
        rows << ColorOption.new(QUARTER_COLOR_SETTING)
        rows << FixedColorOption.new(
          _INTL("x0 Border"),
          Color.new(IMMUNE_COLOR[0], IMMUNE_COLOR[1], IMMUNE_COLOR[2]),
          _INTL("Type immunities always use a gray border.")
        )
        rows << KantoReloaded::Options::ActionButton.new(
          _INTL("Reset Module"),
          proc { reset_module },
          _INTL("Restore all Move Effectiveness settings to their defaults.")
        )
        rows.compact
      end

      private

      def setting_row(key)
        definition = KantoReloaded::Settings.definition(key)
        return nil unless definition
        KantoReloaded::SettingsUI::RowFactory.build(
          definition,
          :scene => self, :move_effectiveness => true
        )
      end

      def reset_module
        return unless KantoReloaded::PopupWindow.confirm(
          _INTL("Reset all Move Effectiveness settings to their defaults?"),
          :default => false
        )
        KantoReloaded::Settings.reset_module(MODULE_ID)
        sync_window_values
        KantoReloaded::Toast.success(
          _INTL("Move Effectiveness settings reset.")
        )
      end
    end

    class << self
      def boot
        return true if @booted
        settings_ready = register_settings
        hooks_ready = defined?(BattleBorders) && BattleBorders.install
        @booted = settings_ready && hooks_ready
        if defined?(KantoReloaded::Log)
          state = @booted ? "ready" : "partial"
          KantoReloaded::Log.info(
            "Move Effectiveness integration #{state}", :move_effectiveness
          )
        end
        @booted
      rescue StandardError => e
        @booted = false
        log_exception("Move Effectiveness failed to boot", e)
        false
      end

      def enabled?
        truthy?(KantoReloaded::Settings.get(ENABLED_SETTING, false))
      rescue StandardError
        false
      end

      def palette_names
        PALETTE.map { |entry| _INTL(entry[:name]) }
      end

      def palette_color(index)
        normalized = index.to_i
        normalized = 0 unless PALETTE[normalized]
        @palette_color_cache ||= {}
        return @palette_color_cache[normalized] if
          @palette_color_cache[normalized]
        entry = PALETTE[normalized]
        rgb = entry[:rgb]
        @palette_color_cache[normalized] = Color.new(rgb[0], rgb[1], rgb[2])
      end

      def border_color(effectiveness_class)
        case effectiveness_class
        when :neutral
          setting_color(NEUTRAL_COLOR_SETTING, DEFAULT_NEUTRAL_COLOR)
        when :quad
          setting_color(QUAD_COLOR_SETTING, DEFAULT_QUAD_COLOR)
        when :super
          setting_color(SUPER_COLOR_SETTING, DEFAULT_SUPER_COLOR)
        when :resisted
          setting_color(RESISTED_COLOR_SETTING, DEFAULT_RESISTED_COLOR)
        when :quarter
          setting_color(QUARTER_COLOR_SETTING, DEFAULT_QUARTER_COLOR)
        when :immune
          @immune_color ||= Color.new(
            IMMUNE_COLOR[0], IMMUNE_COLOR[1], IMMUNE_COLOR[2]
          )
        else
          nil
        end
      rescue StandardError
        nil
      end

      def best_opposing_class(battle, user, move, allowed_indices = nil)
        return nil unless enabled?
        return nil unless damaging_move?(move)
        targets = valid_targets(battle, user, move).select do |target|
          battle.opposes?(target.index, user.index)
        end
        if allowed_indices
          allowed = Array(allowed_indices).map { |index| index.to_i }
          targets.select! { |target| allowed.include?(target.index.to_i) }
        end
        return nil if targets.empty?
        targets.inject(:immune) do |best, target|
          current = class_against(battle, user, move, target)
          rank(current) > rank(best) ? current : best
        end
      rescue StandardError => e
        log_exception("Could not calculate move border", e)
        nil
      end

      def class_against(battle, user, move, target)
        return :neutral unless enabled?
        return :neutral unless battle && user && move && target
        return :neutral unless damaging_move?(move)
        return :neutral if target.respond_to?(:fainted?) && target.fainted?
        value = type_modifier(move, user, target)
        classify(value)
      rescue StandardError => e
        log_exception("Could not calculate target border", e)
        :neutral
      end

      def valid_targets(battle, user, move)
        return [] unless battle && user && move
        target_data = move.pbTarget(user)
        Array(battle.battlers).compact.select do |target|
          next false if target.respond_to?(:fainted?) && target.fainted?
          battle.pbMoveCanTarget?(user.index, target.index, target_data)
        end
      rescue StandardError
        []
      end

      def classify(value)
        return :neutral if value.nil?
        return :immune if value.to_f <= 0
        normal = Effectiveness::NORMAL_EFFECTIVE.to_f
        multiplier = normal <= 0 ? 1.0 : value.to_f / normal
        return :quad if multiplier >= 4.0
        return :super if multiplier > 1.0
        return :quarter if multiplier <= 0.25
        return :resisted if multiplier < 1.0
        :neutral
      rescue StandardError
        :neutral
      end

      def rank(effectiveness_class)
        EFFECTIVENESS_RANKS[effectiveness_class] ||
          EFFECTIVENESS_RANKS[:neutral]
      end

      private

      def register_settings
        visible = proc do |context|
          context.is_a?(Hash) && !!(
            context[:move_effectiveness] || context["move_effectiveness"]
          )
        end
        enabled = proc { KantoReloaded::MoveEffectiveness.enabled? }
        neutral_enabled = proc do
          KantoReloaded::MoveEffectiveness.enabled? ||
            (
              defined?(KantoReloaded::BattleUI) &&
              KantoReloaded::BattleUI.cursor_replacement?
            )
        end

        action = KantoReloaded::Settings.register(SETTINGS_ACTION, {
          :name => "Move Effectiveness",
          :description => "Configure effectiveness borders for battle move and target selection.",
          :type => :button,
          :category => :interface,
          :owner => :kanto_reloaded,
          :priority => 85,
          :metadata => { "after" => "battle_ui.reloaded_ebdx_cursor" },
          :on_press => proc {
            pbFadeOutIn {
              PokemonOptionScreen.new(
                KantoReloaded::MoveEffectiveness::SettingsScene.new
              ).pbStartScreen
            }
          }
        })

        definitions = [
          [ENABLED_SETTING, {
            :name => "Move Effectiveness",
            :description => "Show effectiveness-colored borders in battle move and target menus.",
            :type => :toggle,
            :default => false,
            :priority => 10
          }],
          [NEUTRAL_COLOR_SETTING, color_definition(
            "Neutral Border", "Cursor border used when no effectiveness preview applies.",
            DEFAULT_NEUTRAL_COLOR, 20, neutral_enabled
          )],
          [QUAD_COLOR_SETTING, color_definition(
            "4x Border", "Border used for 4x and stronger effectiveness.",
            DEFAULT_QUAD_COLOR, 30, enabled
          )],
          [SUPER_COLOR_SETTING, color_definition(
            "2x Border", "Border used for 2x effectiveness.",
            DEFAULT_SUPER_COLOR, 40, enabled
          )],
          [RESISTED_COLOR_SETTING, color_definition(
            "x1/2 Border", "Border used for x1/2 effectiveness.",
            DEFAULT_RESISTED_COLOR, 50, enabled
          )],
          [QUARTER_COLOR_SETTING, color_definition(
            "x1/4 Border", "Border used for x1/4 and weaker effectiveness.",
            DEFAULT_QUARTER_COLOR, 60, enabled
          )]
        ]

        registered = definitions.map do |key, options|
          KantoReloaded::Settings.register(key, options.merge(
            :category => :interface,
            :scope => :global,
            :owner => MODULE_ID,
            :visible_if => visible
          ))
        end
        !action.nil? && registered.none?(&:nil?)
      end

      def color_definition(name, description, default, priority, enabled)
        {
          :name => name,
          :description => description,
          :type => :enum,
          :values => PALETTE.map { |entry| entry[:name] },
          :default => default,
          :priority => priority,
          :enabled_if => enabled
        }
      end

      def setting_color(key, fallback)
        index = KantoReloaded::Settings.get(key, fallback).to_i
        palette_color(index)
      end

      def damaging_move?(move)
        return move.damagingMove? if move.respond_to?(:damagingMove?)
        return move.pbDamagingMove? if move.respond_to?(:pbDamagingMove?)
        false
      rescue StandardError
        false
      end

      def type_modifier(move, user, target)
        power_boost_defined = move.instance_variable_defined?(:@powerBoost)
        power_boost = move.instance_variable_get(:@powerBoost) if power_boost_defined
        move_type = move.respond_to?(:pbCalcType) ?
          move.pbCalcType(user) : move.type
        return nil unless move_type
        if move.respond_to?(:pbCalcTypeMod)
          move.pbCalcTypeMod(move_type, user, target)
        else
          target_types = target.respond_to?(:pbTypes) ?
            target.pbTypes(true) : [target.type1, target.type2]
          Effectiveness.calculate(move_type, *Array(target_types))
        end
      ensure
        if power_boost_defined
          move.instance_variable_set(:@powerBoost, power_boost)
        elsif move && move.instance_variable_defined?(:@powerBoost)
          move.remove_instance_variable(:@powerBoost)
        end
      end

      def truthy?(value)
        value == true || (value.respond_to?(:to_i) && value.to_i == 1)
      rescue StandardError
        false
      end

      def log_exception(message, error)
        KantoReloaded::Log.exception(
          message, error, :channel => :move_effectiveness
        ) if defined?(KantoReloaded::Log)
      end
    end
  end
end
