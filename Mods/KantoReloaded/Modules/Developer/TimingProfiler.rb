#==============================================================================
# Kanto Reloaded - Battle Timing Profiler
#==============================================================================
# Developer-only, opt-in profiler. Measurements stay in memory during a battle
# and are appended to one report after the battle has fully torn down.
#==============================================================================

module KantoReloaded
  module TimingProfiler
    MODULE_ID = :timing_profiler
    ENABLED_SETTING = :"timing_profiler.enabled"
    REPORT_PATH = File.join(
      KantoReloaded::ROOT, "Logging", "TimingProfile.txt"
    )
    STALL_16_MS = 1.0 / 60.0
    STALL_33_MS = 1.0 / 30.0
    STALL_50_MS = 0.050
    METRIC_ORDER = [
      "Battle Total",
      "Battle Command Phase",
      "Battle Attack Phase",
      "Battle End-of-Round Phase",
      "EBDX Frame Work",
      "Native Frame Work",
      "EBDX Command Refresh",
      "EBDX Fight Refresh",
      "EBDX Bag Refresh",
      "EBDX Target Refresh",
      "KR Battle Menu Draw",
      "KR Command Cursor Refresh",
      "KR Bag Cursor Refresh",
      "KR Move Layer Refresh",
      "KR Target Icon Prewarm",
      "KR Target Icon Redraw",
      "KR Fight Border Refresh",
      "KR Target Border Refresh",
      "KR Target Border Update",
      "KR Double Ability Handler"
    ].freeze

    class << self
      def install
        return true if @installed
        return false unless defined?(KantoReloaded::Settings)
        return false unless defined?(KantoReloaded::Hooks)
        register_setting
        install_battle_hooks
        install_scene_hooks
        install_ebdx_window_hooks
        install_kanto_hooks
        @installed = true
      rescue StandardError => e
        log_exception("Timing Profiler failed to install", e)
        false
      end

      def enabled?
        value = KantoReloaded::Settings.get(ENABLED_SETTING, 0)
        value == true || (value.respond_to?(:to_i) && value.to_i == 1)
      rescue StandardError
        false
      end

      def active?
        !@session.nil?
      end

      def begin_battle(battle)
        return false unless enabled?
        return false if active?
        @session = {
          :started_at => Time.now,
          :started_clock => monotonic_time,
          :battle_class => class_name(battle),
          :scene_class => class_name(safe_ivar(battle, :@scene)),
          :battle_kind => battle_kind(battle),
          :network_mode => network_mode,
          :map_id => current_map_id,
          :side_sizes => Array(safe_ivar(battle, :@sideSizes)),
          :metrics => {}
        }
        true
      rescue StandardError => e
        @session = nil
        log_exception("Timing Profiler could not start a battle session", e)
        false
      end

      def finish_battle(battle, result = nil, exception = nil)
        session = @session
        return false unless session
        session[:finished_at] = Time.now
        session[:elapsed] = monotonic_time - session[:started_clock].to_f
        session[:turns] = safe_ivar(battle, :@turnCount)
        decision = result
        decision = safe_ivar(battle, :@decision) if decision.nil?
        session[:decision] = decision
        session[:exception] = if exception
                                "#{exception.class}: #{exception.message}"
                              end
        @session = nil
        append_report(session)
      rescue StandardError => e
        @session = nil
        log_exception("Timing Profiler could not finish a battle session", e)
        false
      end

      def measure(label)
        return yield unless active?
        started = monotonic_time
        begin
          yield
        ensure
          record(label, monotonic_time - started)
        end
      end

      private

      def register_setting
        KantoReloaded::Settings.register(ENABLED_SETTING, {
          :name => "Timing Profiler",
          :description => "Append detailed battle timing data after each completed battle.",
          :type => :toggle,
          :category => :utility,
          :scope => :global,
          :owner => MODULE_ID,
          :value_style => :integer,
          :default => false,
          :priority => 20
        })
      end

      def install_battle_hooks
        return false unless defined?(PokeBattle_Battle)
        KantoReloaded::Hooks.wrap(
          PokeBattle_Battle, :pbStartBattle, :timing_profiler_battle
        ) do |hook, *_arguments|
          started = KantoReloaded::TimingProfiler.begin_battle(self)
          next hook.call unless started
          result = nil
          begin
            result = KantoReloaded::TimingProfiler.measure("Battle Total") do
              hook.call
            end
          ensure
            KantoReloaded::TimingProfiler.finish_battle(self, result, $!)
          end
          result
        end
        install_instance_measurement(
          PokeBattle_Battle, :pbCommandPhase,
          :timing_profiler_command_phase, "Battle Command Phase"
        )
        install_instance_measurement(
          PokeBattle_Battle, :pbAttackPhase,
          :timing_profiler_attack_phase, "Battle Attack Phase"
        )
        install_instance_measurement(
          PokeBattle_Battle, :pbEndOfRoundPhase,
          :timing_profiler_end_of_round, "Battle End-of-Round Phase"
        )
        true
      end

      def install_scene_hooks
        if defined?(PokeBattle_Scene)
          install_instance_measurement(
            PokeBattle_Scene, :pbFrameUpdate,
            :timing_profiler_native_frame, "Native Frame Work"
          )
        end
        if defined?(PokeBattle_SceneEBDX)
          install_instance_measurement(
            PokeBattle_SceneEBDX, :pbFrameUpdate,
            :timing_profiler_ebdx_frame, "EBDX Frame Work"
          )
        end
        true
      end

      def install_ebdx_window_hooks
        install_instance_measurement(
          CommandWindowEBDX, :refreshCommands,
          :timing_profiler_ebdx_command_refresh, "EBDX Command Refresh"
        ) if defined?(CommandWindowEBDX)
        install_instance_measurement(
          FightWindowEBDX, :generateButtons,
          :timing_profiler_ebdx_fight_refresh, "EBDX Fight Refresh"
        ) if defined?(FightWindowEBDX)
        install_instance_measurement(
          BagWindowEBDX, :refresh,
          :timing_profiler_ebdx_bag_refresh, "EBDX Bag Refresh"
        ) if defined?(BagWindowEBDX)
        install_instance_measurement(
          TargetWindowEBDX, :refresh,
          :timing_profiler_ebdx_target_refresh, "EBDX Target Refresh"
        ) if defined?(TargetWindowEBDX)
        true
      end

      def install_kanto_hooks
        install_instance_measurement(
          BattleMenuScene, :draw,
          :timing_profiler_battle_menu_draw, "KR Battle Menu Draw"
        ) if defined?(BattleMenuScene)
        if defined?(KantoReloaded::BattleUI)
          target = KantoReloaded::BattleUI
          install_singleton_measurement(
            target, :refresh_ebdx_command_cursor,
            :timing_profiler_command_cursor, "KR Command Cursor Refresh"
          )
          install_singleton_measurement(
            target, :refresh_ebdx_bag_cursor,
            :timing_profiler_bag_cursor, "KR Bag Cursor Refresh"
          )
          install_singleton_measurement(
            target, :refresh_ebdx_move_layers,
            :timing_profiler_move_layers, "KR Move Layer Refresh"
          )
          install_singleton_measurement(
            target, :prewarm_ebdx_target_icons,
            :timing_profiler_target_prewarm, "KR Target Icon Prewarm"
          )
          install_singleton_measurement(
            target, :redraw_ebdx_target_icons,
            :timing_profiler_target_icons, "KR Target Icon Redraw"
          )
        end
        if defined?(KantoReloaded::MoveEffectiveness::BattleBorders)
          target = KantoReloaded::MoveEffectiveness::BattleBorders
          install_singleton_measurement(
            target, :refresh_ebdx_fight,
            :timing_profiler_fight_border, "KR Fight Border Refresh"
          )
          install_singleton_measurement(
            target, :refresh_ebdx_targets,
            :timing_profiler_target_borders, "KR Target Border Refresh"
          )
          install_singleton_measurement(
            target, :update_ebdx_target_borders,
            :timing_profiler_target_border_update, "KR Target Border Update"
          )
        end
        if defined?(KantoReloaded::DoubleAbilities::BattleDispatch)
          install_singleton_measurement(
            KantoReloaded::DoubleAbilities::BattleDispatch, :invoke_handler,
            :timing_profiler_double_ability, "KR Double Ability Handler"
          )
        end
        true
      end

      def install_instance_measurement(target, method_name, hook_id, label)
        KantoReloaded::Hooks.wrap(target, method_name, hook_id) do |hook, *_arguments|
          KantoReloaded::TimingProfiler.measure(label) { hook.call }
        end
      end

      def install_singleton_measurement(target, method_name, hook_id, label)
        KantoReloaded::Hooks.wrap(
          target, method_name, hook_id, :singleton => true
        ) do |hook, *_arguments|
          KantoReloaded::TimingProfiler.measure(label) { hook.call }
        end
      end

      def record(label, duration)
        session = @session
        return false unless session
        metric = session[:metrics][label] ||= {
          :calls => 0,
          :total => 0.0,
          :peak => 0.0,
          :over_16 => 0,
          :over_33 => 0,
          :over_50 => 0
        }
        elapsed = [duration.to_f, 0.0].max
        metric[:calls] += 1
        metric[:total] += elapsed
        metric[:peak] = elapsed if elapsed > metric[:peak]
        metric[:over_16] += 1 if elapsed > STALL_16_MS
        metric[:over_33] += 1 if elapsed > STALL_33_MS
        metric[:over_50] += 1 if elapsed > STALL_50_MS
        true
      rescue StandardError
        false
      end

      def append_report(session)
        ensure_directory(File.dirname(REPORT_PATH))
        File.open(REPORT_PATH, "a") do |file|
          file.write(render_report(session))
        end
        true
      end

      def render_report(session)
        lines = []
        lines << "=" * 100
        lines << "KANTO RELOADED BATTLE TIMING PROFILE"
        lines << "=" * 100
        lines << "Started:       #{format_time(session[:started_at])}"
        lines << "Finished:      #{format_time(session[:finished_at])}"
        lines << format("Elapsed:       %.3f s", session[:elapsed].to_f)
        lines << "Battle:        #{session[:battle_kind]}"
        lines << "Battle class:  #{session[:battle_class]}"
        lines << "Scene class:   #{session[:scene_class]}"
        lines << "Network mode:  #{session[:network_mode]}"
        lines << "Map ID:        #{session[:map_id]}"
        lines << "Side sizes:    #{session[:side_sizes].inspect}"
        lines << "Turns:         #{session[:turns]}"
        lines << "Decision:      #{session[:decision]}"
        lines << "Exception:     #{session[:exception]}" if session[:exception]
        lines << ""
        lines << format(
          "%-34s %8s %12s %12s %12s %9s %9s %9s",
          "Section", "Calls", "Total ms", "Average ms", "Peak ms",
          ">16.7", ">33.3", ">50"
        )
        lines << "-" * 112
        ordered_metrics(session[:metrics]).each do |label, metric|
          calls = metric[:calls].to_i
          average = calls > 0 ? metric[:total].to_f / calls : 0.0
          lines << format(
            "%-34s %8d %12.3f %12.3f %12.3f %9d %9d %9d",
            label, calls, metric[:total].to_f * 1000.0,
            average * 1000.0, metric[:peak].to_f * 1000.0,
            metric[:over_16].to_i, metric[:over_33].to_i,
            metric[:over_50].to_i
          )
        end
        lines << ""
        lines << "Notes:"
        lines << "- Nested sections overlap and must not be added together."
        lines << "- Battle Total and command phases include player/network wait time."
        lines << "- Frame Work excludes Graphics.update frame limiting and focuses on scene work."
        lines << "- Measurements are accumulated in memory and written once at battle teardown."
        lines << ""
        lines.join("\n")
      end

      def ordered_metrics(metrics)
        source = metrics || {}
        ordered = []
        METRIC_ORDER.each do |label|
          ordered << [label, source[label]] if source[label]
        end
        remaining = source.keys.reject { |label| METRIC_ORDER.include?(label) }
        remaining.sort.each { |label| ordered << [label, source[label]] }
        ordered
      end

      def battle_kind(battle)
        return "Trainer" if safe_boolean_call(battle, :trainerBattle?)
        return "Wild" if safe_boolean_call(battle, :wildBattle?)
        "Other"
      end

      def network_mode
        if defined?(CoopBattleState) &&
           CoopBattleState.respond_to?(:in_coop_battle?) &&
           CoopBattleState.in_coop_battle?
          return "Co-op"
        end
        if defined?(MultiplayerClient) &&
           MultiplayerClient.respond_to?(:pvp_active?) &&
           MultiplayerClient.pvp_active?
          return "PvP"
        end
        "Solo"
      rescue StandardError
        "Unknown"
      end

      def safe_boolean_call(receiver, method_name)
        receiver.respond_to?(method_name, true) &&
          !!receiver.__send__(method_name)
      rescue StandardError
        false
      end

      def safe_ivar(receiver, name)
        receiver.instance_variable_get(name)
      rescue StandardError
        nil
      end

      def current_map_id
        return "Unavailable" unless defined?($game_map) && $game_map
        $game_map.map_id
      rescue StandardError
        "Unavailable"
      end

      def class_name(object)
        object ? object.class.to_s : "Unavailable"
      rescue StandardError
        "Unavailable"
      end

      def format_time(value)
        value.respond_to?(:strftime) ?
          value.strftime("%Y-%m-%d %H:%M:%S") : value.to_s
      end

      def monotonic_time
        if Process.respond_to?(:clock_gettime) &&
           defined?(Process::CLOCK_MONOTONIC)
          return Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
        Time.now.to_f
      rescue StandardError
        Time.now.to_f
      end

      def ensure_directory(path)
        return true if File.directory?(path)
        parent = File.dirname(path)
        ensure_directory(parent) unless parent == path || File.directory?(parent)
        Dir.mkdir(path) unless File.directory?(path)
        true
      end

      def log_exception(message, error)
        return unless defined?(KantoReloaded::Log)
        KantoReloaded::Log.exception(
          message, error, :channel => :timing_profiler
        )
      rescue StandardError
        nil
      end
    end
  end
end

KantoReloaded::TimingProfiler.install
