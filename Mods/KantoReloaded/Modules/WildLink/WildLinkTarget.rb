#==============================================================================
# Kanto Reloaded - Wild Link Overworld Targets
#==============================================================================

module KantoReloaded
  module WildLink
    class TargetEvent < Game_Event
      attr_reader :wild_link_target

      def initialize(map_id, event, map, target, interactive)
        @wild_link_target = target
        @wild_link_interactive = interactive
        @wild_link_starting = false
        super(map_id, event, map)
      end

      def start
        return unless @wild_link_interactive
        return if @wild_link_starting
        @wild_link_starting = true
        KantoReloaded::WildLink::Runtime.engage(self)
      ensure
        @wild_link_starting = false
      end

      def update
        super
        if @wild_link_interactive
          KantoReloaded::WildLink::Runtime.update_target_event(self)
        end
      end
    end

    class TargetSprite < Sprite_Character
      def initialize(viewport, event, target)
        @wild_link_asset = target[:asset_path]
        @wild_link_target = target
        super(viewport, event)
        apply_wild_link_style
      end

      def updateCharacterBitmap
        if @wild_link_asset
          loaded = AnimatedBitmap.new(@wild_link_asset)
          return loaded if drawable_wild_link_asset?(loaded)
          loaded.dispose
          @wild_link_asset = nil
          @wild_link_target[:fusion_asset] = false
        end
        super
      rescue StandardError
        @wild_link_asset = nil
        @wild_link_target[:fusion_asset] = false if @wild_link_target
        super
      end

      def update
        super
        apply_wild_link_style
      end

      private

      def apply_wild_link_style
        return unless @wild_link_target
        if @wild_link_target[:unknown]
          self.color = Color.new(0, 0, 0, 255)
          self.opacity = wild_link_opacity(255)
        elsif @wild_link_target[:pokemon] &&
           @wild_link_target[:pokemon].shiny?
          self.color = Color.new(255, 225, 90, 72)
          self.opacity = wild_link_opacity(255)
        elsif @wild_link_target[:fusion_asset]
          self.color = Color.new(0, 0, 0, 0)
          self.opacity = wild_link_opacity(235)
        elsif @wild_link_target[:fusion] || @wild_link_target[:indicator]
          self.color = Color.new(0, 0, 0, 190)
          opacity = @wild_link_target[:indicator] ? 185 : 235
          self.opacity = wild_link_opacity(opacity)
        else
          self.color = Color.new(0, 0, 0, 0)
          self.opacity = wild_link_opacity(255)
        end
      rescue StandardError
        nil
      end

      def wild_link_opacity(maximum)
        value = @wild_link_target[:visual_opacity]
        return maximum if value.nil?
        [[value.to_i, 0].max, maximum].min
      end

      def drawable_wild_link_asset?(animated)
        bitmap = animated.bitmap
        bitmap && bitmap.width >= 64 && bitmap.height >= 64
      rescue StandardError
        false
      end
    end

    class CenteredFieldAnimationSprite < AnimationSprite
      def setCoords
        super
        self.y -= Game_Map::TILE_HEIGHT / 2
      end
    end

    class TreeRustleAnimationSprite < AnimationSprite
      def initialize(animation_id, map, tile_x, tile_y, viewport,
                     source_sprite, tinting = true, height = 1)
        @source_sprite = source_sprite
        super(
          animation_id, map, tile_x, tile_y, viewport, tinting, height
        )
      end

      def setCoords
        unless @source_sprite && !@source_sprite.disposed?
          super
          return
        end
        self.x = @source_sprite.x
        frame_height = @source_sprite.src_rect.height.to_i
        frame_height = Game_Map::TILE_HEIGHT if frame_height <= 0
        self.y = @source_sprite.y - (frame_height * 2 / 3)
      end

      def update
        super
        return if disposed?
        self.visible = @source_sprite && !@source_sprite.disposed? &&
          !!@source_sprite.visible
      rescue StandardError
        self.visible = false unless disposed?
      end
    end

    class RockIndicatorSprite < Sprite
      PADDING = 2
      OUTLINE_RADIUS = 2
      COLOR = Color.new(255, 255, 255, 255)

      def initialize(viewport, source_sprite)
        super(viewport)
        @source_sprite = source_sprite
        @frame_signature = nil
        update
      end

      def update
        super
        return hide unless active_source?
        redraw_outline if frame_signature != @frame_signature
        follow_source
        frame = Graphics.frame_count rescue 0
        pulse = Math.sin(frame * Math::PI / 20.0) * 0.5 + 0.5
        maximum = @source_sprite.opacity.to_i
        self.opacity = [150 + (pulse * 105).to_i, maximum].min
        self.visible = !!@source_sprite.visible
      rescue StandardError
        hide
      end

      def dispose
        return if disposed?
        self.bitmap.dispose if self.bitmap && !self.bitmap.disposed?
        super
      end

      private

      def active_source?
        @source_sprite && !@source_sprite.disposed? &&
          @source_sprite.bitmap && !@source_sprite.bitmap.disposed? &&
          @source_sprite.src_rect.width.to_i > 0 &&
          @source_sprite.src_rect.height.to_i > 0
      end

      def hide
        self.visible = false
      end

      def frame_signature
        rect = @source_sprite.src_rect
        [
          @source_sprite.bitmap.object_id,
          rect.x, rect.y, rect.width, rect.height
        ]
      end

      def redraw_outline
        source = @source_sprite.bitmap
        rect = @source_sprite.src_rect
        width = rect.width.to_i
        height = rect.height.to_i
        old_bitmap = self.bitmap
        self.bitmap = Bitmap.new(width + PADDING * 2, height + PADDING * 2)
        old_bitmap.dispose if old_bitmap && !old_bitmap.disposed?
        opaque = Array.new(width) { Array.new(height, false) }
        width.times do |x|
          height.times do |y|
            opaque[x][y] = source.get_pixel(rect.x + x, rect.y + y).alpha > 0
          end
        end
        width.times do |x|
          height.times do |y|
            next unless opaque[x][y]
            (-OUTLINE_RADIUS..OUTLINE_RADIUS).each do |offset_x|
              (-OUTLINE_RADIUS..OUTLINE_RADIUS).each do |offset_y|
                next if offset_x == 0 && offset_y == 0
                next if offset_x * offset_x + offset_y * offset_y >
                        OUTLINE_RADIUS * OUTLINE_RADIUS
                target_x = x + offset_x
                target_y = y + offset_y
                next if target_x >= 0 && target_x < width &&
                        target_y >= 0 && target_y < height &&
                        opaque[target_x][target_y]
                self.bitmap.set_pixel(
                  x + PADDING + offset_x,
                  y + PADDING + offset_y,
                  COLOR
                )
              end
            end
          end
        end
        transparent = Color.new(0, 0, 0, 0)
        width.times do |x|
          height.times do |y|
            next unless opaque[x][y]
            self.bitmap.set_pixel(x + PADDING, y + PADDING, transparent)
          end
        end
        @frame_signature = frame_signature
      end

      def follow_source
        self.x = @source_sprite.x
        self.y = @source_sprite.y
        self.z = @source_sprite.z + 1
        self.ox = @source_sprite.ox + PADDING
        self.oy = @source_sprite.oy + PADDING
        self.zoom_x = @source_sprite.zoom_x
        self.zoom_y = @source_sprite.zoom_y
        self.angle = @source_sprite.angle
        self.mirror = @source_sprite.mirror
      end
    end

    module Runtime
      FIELD_METHODS = [:surf, :fishing, :headbutt, :rock_smash].freeze
      DIRECT_METHODS = [:land, :cave].freeze
      UPDATE_INTERVAL = 8
      MOVEMENT_INTERVAL = UPDATE_INTERVAL * 2
      CONTINUE_DELAY = 8
      REACTION_ANIMATIONS = {
        :curious => 4,
        :aggressive => 24,
        :territorial => 24,
        :skittish => 3,
        :elusive => 3
      }.freeze
      FLEE_OPACITIES = [210, 150, 90, 35].freeze
      FLEE_STEP_INTERVAL = 8

      class << self
        def install
          return true if @installed
          hooks = []
          hooks << install_encounter_suppression
          hooks << install_field_encounter_hook
          hooks << install_headbutt_hook
          hooks << install_rock_smash_hook
          hooks << install_radar_hook
          hooks << install_trainer_battle_hook
          install_events
          @installed = hooks.compact.all?
        rescue StandardError => e
          WildLink.log_exception("Wild Link runtime install failed", e)
          @installed = false
        end

        def active?
          !!WildLink.runtime.target
        end

        def chain_active?
          WildLink.runtime.chain.to_i > 0
        end

        def target
          WildLink.runtime.target
        end

        def start_search(entry, method)
          return false unless entry && method
          if entry[:signal] && !entry[:unlocked]
            pbPlayBuzzerSE rescue nil
            WildLink.message(
              _INTL("See every standard {1} Pokemon on this map to unlock the Rare Signal.",
                    method[:label]),
              :theme => :warning
            )
            return false
          end
          return false unless replace_active_target?
          return false unless cancel_native_radar?

          built = Bonuses.build(entry, method[:id])
          unless built
            WildLink.message(
              _INTL("Wild Link could not resolve that signal."),
              :theme => :warning
            )
            return false
          end
          location = find_location(method[:id])
          unless location
            WildLink.message(
              location_failure_message(method[:id]),
              :theme => :warning,
              :force => true
            )
            return false
          end

          built[:method_id] = method[:id]
          built[:method_label] = method[:label]
          built[:encounter_types] = Array(method[:encounter_types]).dup
          built[:map_id] = WildLink.current_map_id
          built[:x] = location[:x]
          built[:y] = location[:y]
          built[:source_event] = location[:event]
          built[:indicator] = FIELD_METHODS.include?(method[:id])
          built[:fusion] = fusion?(built[:species])
          built[:asset_path] = target_asset_path(built)
          built[:fusion_asset] = built[:fusion] && !!built[:asset_path]
          built[:behavior_state] = :roaming
          built[:visual_opacity] = nil
          WildLink.runtime.target = built

          unless spawn_visual(built)
            WildLink.runtime.target = nil
            WildLink.message(
              _INTL("Wild Link found the signal, but could not display its target."),
              :theme => :warning
            )
            return false
          end
          WildLink.begin_chain(built[:species], method[:id])
          WildLink.runtime.pending_continue = nil
          WildLink.runtime.stable_map_updates = 0
          pbPlayDecisionSE rescue nil
          WildLink.toast(:success, target_found_message(built))
          true
        rescue StandardError => e
          WildLink.log_exception("Wild Link search failed", e)
          clear_target(:error, false)
          false
        end

        def engage(event = nil)
          current = target
          return false unless current
          return false if @engaging
          if event && @target_event && event != @target_event
            return false
          end
          @engaging = true
          @launching_target = true
          pokemon = current[:pokemon]
          dispose_visual
          pokemon_temp = $PokemonTemp
          old_force_single = pokemon_temp.forceSingleBattle if pokemon_temp
          old_encounter_type = pokemon_temp.encounterType if pokemon_temp
          pokemon_temp.forceSingleBattle = true if pokemon_temp
          pokemon_temp.encounterType = encounter_type_for(current) if pokemon_temp
          decision = global_call(:pbWildBattleCore, pokemon)
          if defined?(::Events) && ::Events.respond_to?(:onWildBattleEnd)
            ::Events.onWildBattleEnd.trigger(
              nil, pokemon.species, pokemon.level, decision
            )
          end
          finish_target(current, decision)
          true
        rescue StandardError => e
          WildLink.log_exception("Wild Link target battle failed", e)
          clear_target(:battle_error, true)
          false
        ensure
          @launching_target = false
          @engaging = false
          if pokemon_temp
            pokemon_temp.encounterType = old_encounter_type
            pokemon_temp.forceSingleBattle = old_force_single
          end
        end

        def update_target_event(event)
          current = target
          return unless current && event == @target_event
          return if current[:method_id] == :surf
          return unless map_scene_ready?
          frame = Graphics.frame_count rescue 0
          return if @last_behavior_frame &&
                    frame - @last_behavior_frame < UPDATE_INTERVAL
          @last_behavior_frame = frame
          return if menu_open?

          distance = distance_to_player(event)
          if distance > 14 && target_can_despawn?(current) &&
             target_grace_elapsed?(current)
            WildLink.toast(:warning, _INTL("The Wild Link signal faded."))
            clear_target(:distance, true)
            return
          end

          if current[:behavior_state] == :fleeing
            update_flee(event, current, frame)
            return
          end

          radius = detection_radius(current[:search_level])
          notice_radius = notice_radius_for(current[:temperament], radius)
          if distance <= notice_radius
            notice_target(event, current, frame)
          else
            return_target_to_roaming(event, current)
          end

          if current[:behavior_state] == :noticed
            update_noticed_behavior(event, current, distance, radius, frame)
          else
            update_roaming_behavior(event, current, frame)
          end
        rescue StandardError => e
          WildLink.log_exception("Wild Link target update failed", e)
        end

        def clear_target(reason = :cancelled, break_chain = false)
          dispose_visual
          WildLink.runtime.target = nil
          WildLink.runtime.pending_continue = nil
          WildLink.runtime.stable_map_updates = 0
          WildLink.break_chain if break_chain
          log_debug("Wild Link target cleared: #{reason}")
          true
        rescue StandardError => e
          WildLink.log_exception("Wild Link target cleanup failed", e)
          false
        end

        def reset_session
          dispose_visual
          WildLink.runtime.reset
          purge_stale_target_events
          true
        rescue StandardError
          WildLink.runtime.reset
          false
        end

        def purge_stale_target_events
          removed = 0
          loaded_maps.each do |map|
            next unless map && map.respond_to?(:events) && map.events
            stale = map.events.select do |_event_id, event|
              event.is_a?(KantoReloaded::WildLink::TargetEvent) &&
                !(active? && @target_event && event.equal?(@target_event))
            end
            stale.each do |event_id, event|
              remove_event_sprites(map, event)
              if map.events[event_id].equal?(event)
                map.events.delete(event_id)
                removed += 1
              end
            end
          end
          log_debug("Purged #{removed} stale Wild Link target event(s)") if
            removed > 0
          true
        rescue StandardError => e
          WildLink.log_exception("Wild Link stale target cleanup failed", e)
          false
        end

        def target_summary_lines(current = target)
          return [] unless current
          level = current[:search_level].to_i
          pokemon = current[:pokemon]
          lines = []
          lines << _INTL("Level {1}", pokemon.level) if level >= 1
          if level >= 5
            lines << _INTL(
              "Temperament: {1}",
              Bonuses.temperament_label(current[:temperament])
            )
          end
          lines << signal_location_line(current) if level >= 50
          if level >= 10 && !WildLink.caught?(current[:species])
            lines << _INTL(
              "Catch this Pokemon to unlock advanced scan details."
            )
            return lines
          end
          if level >= 10
            stars = Bonuses.perfect_iv_count(pokemon)
            lines << _INTL("Perfect IVs: {1}/6", stars)
          end
          if level >= 15
            item = pokemon.item
            lines << _INTL("Item: {1}", item ? item.name : _INTL("None"))
          end
          if level >= 20
            lines.concat(ability_summary_lines(pokemon))
          end
          if level >= 25
            moves = Array(current[:egg_moves]).map do |move|
              GameData::Move.get(move).name
            rescue StandardError
              move.to_s
            end
            lines << _INTL(
              "Egg Moves: {1}", moves.empty? ? _INTL("None") : moves.join(", ")
            )
          end
          lines
        rescue StandardError
          []
        end

        def update_continuation
          pending = WildLink.runtime.pending_continue
          return unless pending
          unless continuation_scene_ready?
            WildLink.runtime.stable_map_updates = 0
            return
          end
          WildLink.runtime.stable_map_updates += 1
          return if WildLink.runtime.stable_map_updates < CONTINUE_DELAY
          WildLink.runtime.pending_continue = nil
          WildLink.runtime.stable_map_updates = 0
          process_continuation(pending)
        rescue StandardError => e
          WildLink.log_exception("Wild Link continuation failed", e)
          WildLink.runtime.pending_continue = nil
        end

        def update_field_indicator
          current = target
          return unless current
          return unless map_scene_ready?
          return if menu_open?
          case current[:method_id]
          when :surf
            update_water_indicator(current)
          when :fishing
            update_water_indicator(current)
          when :headbutt
            update_headbutt_indicator(current)
          end
        rescue StandardError => e
          WildLink.log_exception("Wild Link field indicator failed", e)
        end

        def update_water_indicator(current)
          set = current_spriteset
          return unless set && set.respond_to?(:addUserSprite)
          if @water_ripple_spriteset != set
            dispose_water_ripple
            @water_ripple_spriteset = set
          end
          return if @water_ripple_sprite &&
                    !@water_ripple_sprite.disposed?
          animation_id = defined?(PUDDLE_ANIMATION_ID) ?
            PUDDLE_ANIMATION_ID : 22
          @water_ripple_sprite = CenteredFieldAnimationSprite.new(
            animation_id, $game_map, current[:x], current[:y],
            target_viewport, true, 0
          )
          set.addUserSprite(@water_ripple_sprite)
        rescue StandardError => e
          WildLink.log_exception("Wild Link water indicator failed", e)
          @water_ripple_sprite = nil
        end

        def update_headbutt_indicator(current)
          set = current_spriteset
          return unless set && set.respond_to?(:addUserSprite)
          if @headbutt_rustle_spriteset != set
            dispose_headbutt_rustle
            @headbutt_rustle_spriteset = set
          end
          return if @headbutt_rustle_sprite &&
                    !@headbutt_rustle_sprite.disposed?
          source = @headbutt_source_sprite ||
            character_sprite_for(current[:source_event])
          return unless source
          @headbutt_source_sprite = source
          animation_id = if defined?(::Settings::RUSTLE_NORMAL_ANIMATION_ID)
                           ::Settings::RUSTLE_NORMAL_ANIMATION_ID
                         elsif defined?(::Settings::GRASS_ANIMATION_ID)
                           ::Settings::GRASS_ANIMATION_ID
                         else
                           1
                         end
          @headbutt_rustle_sprite = TreeRustleAnimationSprite.new(
            animation_id, $game_map, current[:x], current[:y],
            target_viewport, source, true, 1
          )
          set.addUserSprite(@headbutt_rustle_sprite)
        rescue StandardError => e
          WildLink.log_exception("Wild Link Headbutt indicator failed", e)
          @headbutt_rustle_sprite = nil
        end

        def field_encounter?(encounter_type)
          current = target
          return false unless current
          matching_type = case current[:method_id]
                          when :fishing
                            [:OldRod, :GoodRod, :SuperRod].include?(encounter_type)
                          when :headbutt
                            [:HeadbuttLow, :HeadbuttHigh].include?(encounter_type)
                          else
                            false
                          end
          matching_type && facing_target_tile?(current)
        end

        def rock_smash_target?
          current = target
          current && current[:method_id] == :rock_smash &&
            facing_target_tile?(current)
        end

        def headbutt_target?(event = nil)
          current = target
          return false unless current && current[:method_id] == :headbutt
          event ||= $game_player.pbFacingEvent(true)
          return false unless event
          source = current[:source_event]
          same_event = source && event.equal?(source)
          same_tile = event.respond_to?(:x) && event.respond_to?(:y) &&
            event.x.to_i == current[:x].to_i &&
            event.y.to_i == current[:y].to_i
          (same_event || same_tile) && facing_target_tile?(current)
        rescue StandardError
          false
        end

        private

        def ability_summary_lines(pokemon)
          if defined?(KantoReloaded::DoubleAbilities) &&
             KantoReloaded::DoubleAbilities.respond_to?(:eligible_pokemon?) &&
             KantoReloaded::DoubleAbilities.eligible_pokemon?(pokemon)
            first = KantoReloaded::DoubleAbilities.primary_id(pokemon)
            second = KantoReloaded::DoubleAbilities.secondary_id(pokemon)
            return [
              _INTL(
                "Ability 1: {1}",
                first ?
                  KantoReloaded::DoubleAbilities.ability_name(first) :
                  _INTL("None")
              ),
              _INTL(
                "Ability 2: {1}",
                second ?
                  KantoReloaded::DoubleAbilities.ability_name(second) :
                  _INTL("None")
              )
            ]
          end
          ability = pokemon.ability
          [_INTL("Ability: {1}", ability ? ability.name : _INTL("None"))]
        rescue StandardError
          ability = pokemon.ability
          [_INTL("Ability: {1}", ability ? ability.name : _INTL("None"))]
        end

        def install_encounter_suppression
          return false unless defined?(PokemonEncounters)
          KantoReloaded::Hooks.wrap(
            PokemonEncounters,
            :encounter_triggered?,
            :wild_link_target_suppression,
            :required => true
          ) do |hook, encounter_type, repel_active = false, triggered_by_step = true|
            if triggered_by_step && KantoReloaded::WildLink::Runtime.active?
              false
            else
              hook.call(encounter_type, repel_active, triggered_by_step)
            end
          end
        end

        def install_field_encounter_hook
          KantoReloaded::Hooks.wrap(
            Object, :pbEncounter, :wild_link_field_encounter,
            :required => true
          ) do |hook, encounter_type|
            if KantoReloaded::WildLink::Runtime.field_encounter?(encounter_type)
              KantoReloaded::WildLink::Runtime.engage
            else
              hook.call(encounter_type)
            end
          end
        end

        def install_headbutt_hook
          KantoReloaded::Hooks.wrap(
            Object, :pbHeadbuttEffect, :wild_link_headbutt_effect,
            :required => true
          ) do |hook, *arguments|
            runtime = KantoReloaded::WildLink::Runtime
            event = arguments[0]
            if runtime.headbutt_target?(event)
              runtime.engage(event)
            else
              hook.call(*arguments)
            end
          end
        end

        def install_rock_smash_hook
          methods = [
            :pbRockSmashRandomEncounter,
            :pbRockSmashRandomEncounterSpecial,
            :pbRockSmashRandomEncounterDive
          ]
          methods.all? do |method_name|
            next true unless global_method?(method_name)
            KantoReloaded::Hooks.wrap(
              Object, method_name, :"wild_link_#{method_name}"
            ) do |hook, *arguments|
              runtime = KantoReloaded::WildLink::Runtime
              if runtime.rock_smash_target?
                runtime.engage
              else
                hook.call(*arguments)
              end
            end
          end
        end

        def install_radar_hook
          KantoReloaded::Hooks.wrap(
            Object, :pbUsePokeRadar, :wild_link_native_radar
          ) do |hook, *arguments|
            runtime = KantoReloaded::WildLink::Runtime
            if runtime.active? || runtime.chain_active?
              proceed = KantoReloaded::WildLink.confirm(
                _INTL("Using the Poke Radar will end the current Wild Link target and chain. Continue?"),
                :default => false, :serious => true, :theme => :warning
              )
              next false unless proceed
              if runtime.active?
                runtime.clear_target(:native_radar, true)
              else
                KantoReloaded::WildLink.break_chain
              end
            end
            hook.call(*arguments)
          end
        end

        def install_trainer_battle_hook
          KantoReloaded::Hooks.wrap(
            Object, :pbTrainerBattleCore, :wild_link_trainer_battle
          ) do |hook, *arguments|
            runtime = KantoReloaded::WildLink::Runtime
            if runtime.active?
              runtime.clear_target(:trainer_battle, true)
            elsif runtime.chain_active?
              KantoReloaded::WildLink.break_chain
            end
            hook.call(*arguments)
          end
        end

        def install_events
          return if @events_installed
          if defined?(::Events)
            ::Events.onMapChange += proc do |_sender, _event|
              runtime = KantoReloaded::WildLink::Runtime
              if runtime.active?
                runtime.clear_target(:map_change, true)
              elsif runtime.chain_active?
                KantoReloaded::WildLink.break_chain
              end
              runtime.purge_stale_target_events
            end
            ::Events.onMapSceneChange += proc do |_sender, _event|
              KantoReloaded::WildLink::Runtime.purge_stale_target_events
            end
            ::Events.onMapUpdate += proc do |_sender, _event|
              runtime = KantoReloaded::WildLink::Runtime
              runtime.update_continuation
              runtime.update_field_indicator
            end
          end
          if defined?(KantoReloaded::Events)
            KantoReloaded::Events.on(
              :kanto_reloaded_save_loaded, :wild_link_runtime_reset,
              priority: 180
            ) { |_context| KantoReloaded::WildLink::Runtime.reset_session }
            KantoReloaded::Events.on(
              :kanto_reloaded_save_new_game, :wild_link_runtime_reset,
              priority: 180
            ) { |_context| KantoReloaded::WildLink::Runtime.reset_session }
          end
          @events_installed = true
        end

        def replace_active_target?
          return true unless active?
          proceed = WildLink.confirm(
            _INTL("Replace the current Wild Link target? This will break its chain."),
            :default => false, :serious => true, :theme => :warning
          )
          clear_target(:replaced, true) if proceed
          proceed
        end

        def cancel_native_radar?
          return true unless $PokemonTemp && $PokemonTemp.pokeradar
          proceed = WildLink.confirm(
            _INTL("Starting Wild Link will end the active Poke Radar chain. Continue?"),
            :default => false, :serious => true, :theme => :warning
          )
          return false unless proceed
          global_call(:pbPokeRadarCancel) if global_method?(:pbPokeRadarCancel)
          true
        end

        def find_location(method_id)
          case method_id.to_sym
          when :headbutt
            event_location(/headbutttree/i)
          when :rock_smash
            event_location(/smashrock/i)
          when :fishing
            fishing_location
          when :surf
            surf_location
          when :land
            tile_location(:land, 3, 8)
          else
            tile_location(:cave, 3, 8)
          end
        end

        def event_location(pattern)
          events = EncounterPools.nearby_named_events(pattern)
          return nil if events.empty?
          event = events.min_by do |candidate|
            (candidate.x - $game_player.x).abs + (candidate.y - $game_player.y).abs
          end
          { :x => event.x, :y => event.y, :event => event }
        end

        def fishing_location
          return nil if $PokemonGlobal && $PokemonGlobal.surfing
          start_x = $game_player.x
          start_y = $game_player.y
          start_terrain = $game_map.terrain_tag(start_x, start_y)
          return nil if start_terrain.can_surf_freely

          directions = {
            2 => [0, 1],
            4 => [-1, 0],
            6 => [1, 0],
            8 => [0, -1]
          }
          queue = [[start_x, start_y, 0]]
          visited = { [start_x, start_y] => true }
          candidates = {}
          index = 0
          while index < queue.length
            x, y, distance = queue[index]
            index += 1
            directions.each do |direction, offset|
              water_x = x + offset[0]
              water_y = y + offset[1]
              next unless fishable_from_shore?(
                x, y, direction, water_x, water_y
              )
              key = [water_x, water_y]
              signal_distance = distance + 1
              existing = candidates[key]
              next if existing &&
                      existing[:distance].to_i <= signal_distance
              candidates[key] = {
                :x => water_x,
                :y => water_y,
                :event => nil,
                :distance => signal_distance
              }
            end
            next if distance >= 8
            directions.each do |direction, offset|
              next_x = x + offset[0]
              next_y = y + offset[1]
              key = [next_x, next_y]
              next if visited[key]
              next unless walkable_shore_step?(x, y, direction, next_x, next_y)
              visited[key] = true
              queue << [next_x, next_y, distance + 1]
            end
          end

          rows = candidates.values
          return nil if rows.empty?
          preferred = rows.select { |row| row[:distance].to_i >= 2 }
          rows = preferred unless preferred.empty?
          selected = rows[rand(rows.length)].dup
          selected.delete(:distance)
          selected
        rescue StandardError
          nil
        end

        def surf_location
          tile_location(:water, 3, 8) || tile_location(:water, 1, 8)
        end

        def fishable_from_shore?(shore_x, shore_y, direction, water_x, water_y)
          return false unless $game_map.valid?(water_x, water_y)
          return false if occupied_tile?(water_x, water_y)
          terrain = $game_map.terrain_tag(water_x, water_y)
          return false unless terrain.can_fish
          $game_map.passable?(
            shore_x, shore_y, direction, $game_player
          )
        rescue StandardError
          false
        end

        def walkable_shore_step?(x, y, direction, next_x, next_y)
          return false unless $game_map.valid?(next_x, next_y)
          return false if $game_map.terrain_tag(next_x, next_y).can_surf_freely
          $game_player.passable?(x, y, direction)
        rescue StandardError
          false
        end

        def occupied_tile?(x, y)
          $game_map.events.values.any? do |event|
            event && event.x == x && event.y == y &&
              !(event.respond_to?(:erased) && event.erased)
          end
        rescue StandardError
          true
        end

        def tile_location(kind, minimum_distance, maximum_distance)
          candidates = []
          x_min = [$game_player.x - maximum_distance, 0].max
          x_max = [$game_player.x + maximum_distance, $game_map.width - 1].min
          y_min = [$game_player.y - maximum_distance, 0].max
          y_max = [$game_player.y + maximum_distance, $game_map.height - 1].min
          (x_min..x_max).each do |x|
            (y_min..y_max).each do |y|
              distance = (x - $game_player.x).abs + (y - $game_player.y).abs
              next if distance < minimum_distance || distance > maximum_distance
              next unless suitable_tile?(x, y, kind)
              candidates << [x, y]
            end
          end
          return nil if candidates.empty?
          x, y = candidates[rand(candidates.length)]
          { :x => x, :y => y, :event => nil }
        end

        def suitable_tile?(x, y, kind)
          return false unless $game_map.valid?(x, y)
          return false if $game_map.events.values.any? do |event|
            event && event.x == x && event.y == y &&
              !(event.respond_to?(:erased) && event.erased)
          end
          terrain = $game_map.terrain_tag(x, y, kind == :water)
          case kind
          when :water
            return false unless terrain.can_surf_freely
          when :land
            return false unless terrain.land_wild_encounters
          else
            return false if terrain.can_surf_freely
          end
          [2, 4, 6, 8].any? { |direction| $game_map.passable?(x, y, direction) }
        rescue StandardError
          false
        end

        def spawn_visual(current)
          return spawn_water_visual(current) if
            [:surf, :fishing].include?(current[:method_id])
          return spawn_headbutt_visual(current) if
            current[:method_id] == :headbutt
          return spawn_rock_smash_visual(current) if
            current[:method_id] == :rock_smash

          interactive = DIRECT_METHODS.include?(current[:method_id])
          event_id = next_event_id
          rpg_event = RPG::Event.new(current[:x], current[:y])
          rpg_event.id = event_id
          rpg_event.name = "Wild Link Target update"
          page = rpg_event.pages[0]
          page.graphic.character_name = follower_character(current[:species])
          page.graphic.direction = 2
          page.graphic.pattern = 1
          page.move_type = 0
          page.move_speed = movement_speed(current[:temperament])
          page.move_frequency = 3
          page.walk_anime = true
          page.step_anime = !!current[:indicator]
          page.direction_fix = false
          page.through = !interactive
          page.always_on_top = !!current[:indicator]
          page.trigger = interactive ? 2 : 0
          event = TargetEvent.new(
            $game_map.map_id, rpg_event, $game_map, current, interactive
          )
          event.moveto(current[:x], current[:y])
          $game_map.events[event_id] = event if interactive
          sprite = TargetSprite.new(target_viewport, event, current)
          sprites = character_sprites
          sprites << sprite
          @target_sprite_collection = sprites
          @target_event = event
          @target_sprite = sprite
          @target_event_id = interactive ? event_id : nil
          current[:spawn_frame] = Graphics.frame_count rescue 0
          true
        end

        def spawn_headbutt_visual(current)
          event = current[:source_event]
          return false unless event
          source_sprite = character_sprite_for(event)
          return false unless source_sprite
          @target_event = nil
          @target_sprite = nil
          @target_event_id = nil
          @headbutt_source_sprite = source_sprite
          @headbutt_rustle_sprite = nil
          @headbutt_rustle_spriteset = nil
          current[:spawn_frame] = Graphics.frame_count rescue 0
          update_field_indicator
          true
        end

        def spawn_rock_smash_visual(current)
          event = current[:source_event]
          return false unless event
          source_sprite = character_sprite_for(event)
          return false unless source_sprite
          @target_event = nil
          @target_sprite = nil
          @target_event_id = nil
          set = current_spriteset
          return false unless set && set.respond_to?(:addUserSprite)
          @rock_indicator_sprite = RockIndicatorSprite.new(
            target_viewport, source_sprite
          )
          set.addUserSprite(@rock_indicator_sprite)
          @rock_indicator_spriteset = set
          current[:spawn_frame] = Graphics.frame_count rescue 0
          true
        end

        def spawn_water_visual(current)
          @target_event = nil
          @target_sprite = nil
          @target_event_id = nil
          return false if current[:method_id] == :surf &&
                          !spawn_surf_trigger(current)
          @water_ripple_sprite = nil
          @water_ripple_spriteset = nil
          current[:spawn_frame] = Graphics.frame_count rescue 0
          update_field_indicator
          true
        end

        def spawn_surf_trigger(current)
          event_id = next_event_id
          rpg_event = RPG::Event.new(current[:x], current[:y])
          rpg_event.id = event_id
          rpg_event.name = "Wild Link Surf Signal"
          page = rpg_event.pages[0]
          page.graphic.character_name = ""
          page.move_type = 0
          page.walk_anime = false
          page.step_anime = false
          page.direction_fix = true
          page.through = true
          page.always_on_top = false
          page.trigger = 1
          event = TargetEvent.new(
            $game_map.map_id, rpg_event, $game_map, current, true
          )
          event.moveto(current[:x], current[:y])
          $game_map.events[event_id] = event
          @target_event = event
          @target_event_id = event_id
          true
        rescue StandardError => e
          WildLink.log_exception("Wild Link Surf trigger failed", e)
          false
        end

        def dispose_visual
          dispose_water_ripple
          dispose_headbutt_rustle
          dispose_owned_user_sprite(
            @rock_indicator_spriteset, @rock_indicator_sprite
          )
          dispose_owned_sprite(@target_sprite_collection, @target_sprite)
          if @target_event_id && $game_map && $game_map.events
            event = $game_map.events[@target_event_id]
            $game_map.events.delete(@target_event_id) if event == @target_event
          end
          @target_sprite = nil
          @target_event = nil
          @target_event_id = nil
          @target_sprite_collection = nil
          @rock_indicator_sprite = nil
          @rock_indicator_spriteset = nil
          @headbutt_source_sprite = nil
          @headbutt_rustle_sprite = nil
          @headbutt_rustle_spriteset = nil
          @last_behavior_frame = nil
          @water_ripple_sprite = nil
          @water_ripple_spriteset = nil
        rescue StandardError => e
          WildLink.log_exception("Wild Link visual cleanup failed", e)
          @target_sprite = nil
          @target_event = nil
          @target_event_id = nil
          @target_sprite_collection = nil
          @rock_indicator_sprite = nil
          @rock_indicator_spriteset = nil
          @headbutt_source_sprite = nil
          @headbutt_rustle_sprite = nil
          @headbutt_rustle_spriteset = nil
          @water_ripple_sprite = nil
          @water_ripple_spriteset = nil
        end

        def dispose_water_ripple
          return unless @water_ripple_sprite
          dispose_owned_user_sprite(
            @water_ripple_spriteset, @water_ripple_sprite
          )
        rescue StandardError
          nil
        ensure
          @water_ripple_sprite = nil
          @water_ripple_spriteset = nil
        end

        def dispose_headbutt_rustle
          return unless @headbutt_rustle_sprite
          dispose_owned_user_sprite(
            @headbutt_rustle_spriteset, @headbutt_rustle_sprite
          )
        rescue StandardError
          nil
        ensure
          @headbutt_rustle_sprite = nil
          @headbutt_rustle_spriteset = nil
        end

        def dispose_owned_sprite(collection, sprite)
          return unless sprite
          collection.delete(sprite) if collection.respond_to?(:delete)
          sprite.dispose unless sprite.disposed?
        rescue StandardError
          nil
        end

        def dispose_owned_user_sprite(spriteset, sprite)
          return unless sprite
          users = spriteset.instance_variable_get(:@usersprites) if spriteset
          users.delete(sprite) if users.respond_to?(:delete)
          sprite.dispose unless sprite.disposed?
        rescue StandardError
          nil
        end

        def target_viewport
          set = current_spriteset
          return set.viewport1 if set && set.respond_to?(:viewport1)
          return Spriteset_Map.viewport if Spriteset_Map.respond_to?(:viewport)
          nil
        end

        def character_sprites
          set = current_spriteset
          return set.character_sprites if set && set.respond_to?(:character_sprites)
          []
        end

        def character_sprite_for(event)
          character_sprites.find do |sprite|
            sprite.respond_to?(:character) && sprite.character.equal?(event)
          end
        rescue StandardError
          nil
        end

        def current_spriteset
          return nil unless $scene
          if $scene.respond_to?(:spritesets) && $scene.spritesets
            set = $scene.spritesets[$game_map.map_id]
            return set if set
          end
          $scene.respond_to?(:spriteset) ? $scene.spriteset : nil
        rescue StandardError
          nil
        end

        def loaded_maps
          maps = []
          if $MapFactory && $MapFactory.respond_to?(:maps)
            maps.concat(Array($MapFactory.maps))
          end
          maps << $game_map if $game_map
          maps.compact.uniq
        rescue StandardError
          $game_map ? [$game_map] : []
        end

        def remove_event_sprites(map, event)
          return unless $scene
          set = nil
          if $scene.respond_to?(:spritesets) && $scene.spritesets
            set = $scene.spritesets[map.map_id]
          elsif map.equal?($game_map) && $scene.respond_to?(:spriteset)
            set = $scene.spriteset
          end
          return unless set
          sprites = if set.respond_to?(:character_sprites)
                      set.character_sprites
                    else
                      set.instance_variable_get(:@character_sprites)
                    end
          return unless sprites.respond_to?(:delete_if)
          sprites.delete_if do |sprite|
            next false unless sprite.respond_to?(:character) &&
                              sprite.character.equal?(event)
            sprite.dispose unless sprite.disposed?
            true
          rescue StandardError
            false
          end
        rescue StandardError
          nil
        end

        def next_event_id
          (($game_map.events.keys.max || 0) + 1)
        end

        def follower_character(species)
          data = GameData::Species.get(species)
          source = if data.respond_to?(:is_fusion) && data.is_fusion
                     GameData::Species.get(data.get_body_species)
                   else
                     data
                   end
          character = "Followers/#{source.id}"
          return character if pbResolveBitmap(
            "Graphics/Characters/#{character}"
          )
          "Followers/PIKACHU"
        rescue StandardError
          "Followers/PIKACHU"
        end

        def target_asset_path(current)
          return nil unless current[:fusion]
          data = GameData::Species.get(current[:species])
          body = GameData::Species.get(data.get_body_species).id.to_s
          folder = "Fusions"
          folder += "/Shiny" if current[:pokemon].shiny?
          [body, "#{body}_fly"].each do |name|
            relative = "#{folder}/#{name}.png"
            path = if defined?(KantoReloaded::AssetPacks)
                     KantoReloaded::AssetPacks.ensure_follower(relative)
                   end
            unless path && File.file?(path)
              legacy = File.join(
                KantoReloaded::ROOT, "Graphics", "Characters", "Followers",
                relative
              )
              path = legacy if File.file?(legacy)
            end
            return runtime_asset_path(path) if path && File.file?(path)
          end
          nil
        rescue StandardError
          nil
        end

        def runtime_asset_path(path)
          game_root = File.expand_path(
            File.join(KantoReloaded::ROOT, "..", "..")
          )
          expanded = File.expand_path(path)
          prefix = game_root + File::SEPARATOR
          return expanded.tr("\\", "/") unless expanded.start_with?(prefix)
          expanded[prefix.length..-1].tr("\\", "/")
        end

        def fusion?(species)
          data = GameData::Species.get(species)
          data.respond_to?(:is_fusion) && !!data.is_fusion
        rescue StandardError
          false
        end

        def encounter_method_id
          return nil unless $PokemonTemp
          encounter_type = $PokemonTemp.encounterType
          return nil unless encounter_type
          id = encounter_type.to_sym
          return :fishing if [:OldRod, :GoodRod, :SuperRod].include?(id)
          return :headbutt if [:HeadbuttLow, :HeadbuttHigh].include?(id)
          return :rock_smash if id == :RockSmash
          data = GameData::EncounterType.get(id)
          case data.type
          when :land then :land
          when :cave then :cave
          when :water then :surf
          else nil
          end
        rescue StandardError
          nil
        end

        def movement_speed(temperament)
          return 4 if [:aggressive, :skittish, :elusive].include?(temperament)
          3
        end

        def distance_to_player(event)
          (event.x - $game_player.x).abs + (event.y - $game_player.y).abs
        end

        def detection_radius(search_level)
          radius = 6
          radius -= 1 if search_level.to_i >= 50
          radius -= 1 if search_level.to_i >= 200
          [radius, 2].max
        end

        def notice_radius_for(temperament, radius)
          return radius + 2 if temperament == :aggressive
          return [radius, 3].min if temperament == :territorial
          radius
        end

        def notice_target(event, current, frame)
          return if current[:behavior_state] == :noticed
          current[:behavior_state] = :noticed
          current[:noticed_frame] = frame
          current.delete(:flee_started)
          play_reaction(event, current[:temperament])
          event.turn_toward_player if event.respond_to?(:turn_toward_player)
        end

        def return_target_to_roaming(event, current)
          return unless current[:behavior_state] == :noticed
          current[:behavior_state] = :roaming
          current.delete(:noticed_frame)
          current.delete(:flee_started)
          current.delete(:curious_idle_frame)
          if [:skittish, :elusive].include?(current[:temperament]) &&
             event.respond_to?(:turn_toward_player)
            event.turn_toward_player
          end
        end

        def update_roaming_behavior(event, current, frame)
          return if event.respond_to?(:moving?) && event.moving?
          return unless behavior_movement_ready?(current, frame)
          case current[:temperament]
          when :curious
            if rand(5).zero? && event.respond_to?(:turn_random)
              event.turn_random
            elsif rand(4).zero?
              event.move_random
            end
          when :calm
            if rand(4).zero?
              event.move_random
            elsif rand(5).zero? && event.respond_to?(:turn_random)
              event.turn_random
            end
          else
            event.move_random if rand(4).zero?
          end
        end

        def update_noticed_behavior(event, current, distance, radius, frame)
          return if event.respond_to?(:moving?) && event.moving?
          return unless behavior_movement_ready?(current, frame)
          case current[:temperament]
          when :aggressive
            event.move_toward_player
          when :territorial
            event.move_toward_player if distance <= [radius, 3].min
          when :curious
            update_curious(event, current, distance, frame)
          when :skittish
            update_skittish(event, current, frame)
          when :elusive
            event.move_away_from_player
          else
            event.turn_toward_player if event.respond_to?(:turn_toward_player)
          end
        end

        def behavior_movement_ready?(current, frame)
          last = current[:last_behavior_move_frame]
          return false if last && frame - last.to_i < MOVEMENT_INTERVAL
          current[:last_behavior_move_frame] = frame
          true
        end

        def update_curious(event, current, distance, frame)
          if distance > 1
            event.move_toward_player
            return
          end
          event.turn_toward_player if event.respond_to?(:turn_toward_player)
          last = current[:curious_idle_frame].to_i
          frame_rate = Graphics.frame_rate rescue 40
          return if frame - last < frame_rate
          current[:curious_idle_frame] = frame
          if rand(3).zero? && event.respond_to?(:jump)
            event.jump(0, 0)
          elsif event.respond_to?(:turn_random)
            event.turn_random
          end
        end

        def update_skittish(event, current, frame)
          event.move_away_from_player
          return if current[:pokemon].shiny?
          current[:flee_started] ||= frame
          warning = Graphics.frame_rate / 2 rescue 20
          warning += Graphics.frame_rate / 2 if current[:search_level].to_i >= 100
          if frame - current[:flee_started].to_i >
             warning + (Graphics.frame_rate * 2 rescue 80)
            begin_flee(event, current, frame)
          end
        end

        def play_reaction(event, temperament)
          animation_id = REACTION_ANIMATIONS[temperament]
          return unless animation_id
          return if defined?($data_animations) &&
                    (!$data_animations || !$data_animations[animation_id])
          global_call(:playAnimation, animation_id, event.x, event.y)
        rescue StandardError => e
          WildLink.log_exception("Wild Link reaction animation failed", e)
        end

        def begin_flee(event, current, frame)
          return if current[:behavior_state] == :fleeing
          current[:behavior_state] = :fleeing
          current[:flee_step] = 0
          current[:flee_next_frame] = frame
          current[:visual_opacity] = 255
          event.through = true if event.respond_to?(:through=)
          global_call(:playCry, current[:species])
          global_call(:pbSEPlay, "Flee")
        rescue StandardError => e
          WildLink.log_exception("Wild Link flee start failed", e)
          clear_target(:fled, true)
        end

        def update_flee(event, current, frame)
          return if frame < current[:flee_next_frame].to_i
          return if event.respond_to?(:moving?) && event.moving?
          step = current[:flee_step].to_i
          if step >= FLEE_OPACITIES.length
            WildLink.toast(:warning, _INTL("The Wild Link target fled."))
            clear_target(:fled, true)
            return
          end
          current[:visual_opacity] = FLEE_OPACITIES[step]
          event.move_away_from_player
          current[:flee_step] = step + 1
          current[:flee_next_frame] = frame + FLEE_STEP_INTERVAL
        end

        def target_grace_elapsed?(current)
          frame_rate = Graphics.frame_rate rescue 40
          (Graphics.frame_count rescue 0) - current[:spawn_frame].to_i >=
            frame_rate * 3
        end

        def target_can_despawn?(current)
          return false if current[:pokemon].shiny?
          current[:search_level].to_i < 500
        end

        def menu_open?
          $game_temp && $game_temp.respond_to?(:in_menu) && $game_temp.in_menu
        rescue StandardError
          false
        end

        def map_scene_ready?
          defined?(Scene_Map) && $scene.is_a?(Scene_Map) &&
            $game_map && $game_player
        rescue StandardError
          false
        end

        def continuation_scene_ready?
          return false unless map_scene_ready?
          return false if active?
          return false if menu_open?
          if $game_temp && $game_temp.respond_to?(:message_window_showing)
            return false if $game_temp.message_window_showing
          end
          interpreter = $game_map.interpreter rescue nil
          return false if interpreter && interpreter.respond_to?(:running?) &&
                          interpreter.running?
          true
        end

        def finish_target(current, decision)
          WildLink.runtime.target = nil
          case decision.to_i
          when 4
            WildLink.increment_search_level(current[:species], 2)
            WildLink.advance_chain(current[:species], current[:method_id])
            WildLink.toast(
              :success,
              _INTL("Wild Link capture complete. Search Level +2.")
            )
            queue_continuation(current)
          when 1
            WildLink.increment_search_level(current[:species], 1)
            WildLink.advance_chain(current[:species], current[:method_id])
            WildLink.toast(
              :success,
              _INTL("Wild Link search complete. Search Level +1.")
            )
            queue_continuation(current)
          else
            WildLink.break_chain
            WildLink.toast(:warning, _INTL("The Wild Link chain ended."))
          end
        end

        def queue_continuation(current)
          return if WildLink.continue_mode == CONTINUE_OFF
          WildLink.runtime.pending_continue = {
            :species => current[:species],
            :method_id => current[:method_id],
            :map_id => current[:map_id]
          }
          WildLink.runtime.stable_map_updates = 0
        end

        def process_continuation(pending)
          return unless pending[:map_id].to_i == WildLink.current_map_id
          if WildLink.continue_mode == CONTINUE_PROMPT
            proceed = KantoReloaded::PopupWindow.confirm(
              _INTL("Continue searching for {1}?",
                    GameData::Species.get(pending[:species]).name),
              :default => true
            )
            unless proceed
              WildLink.break_chain
              return
            end
          end
          entry = EncounterPools.find_entry(
            pending[:method_id], pending[:species]
          )
          method = EncounterPools.available_methods.find do |row|
            row[:id] == pending[:method_id]
          end
          unless entry && method
            WildLink.break_chain
            WildLink.toast(
              :warning,
              _INTL("That Wild Link signal is no longer available.")
            )
            return
          end
          start_search(entry, method)
        end

        def facing_target_tile?(current)
          x, y = facing_coordinates
          x == current[:x] && y == current[:y]
        end

        def facing_coordinates
          x = $game_player.x
          y = $game_player.y
          case $game_player.direction
          when 2 then y += 1
          when 4 then x -= 1
          when 6 then x += 1
          when 8 then y -= 1
          end
          [x, y]
        end

        def encounter_type_for(current)
          case current[:method_id]
          when :surf
            Array(current[:encounter_types])[0] || :Water
          when :fishing then :SuperRod
          when :headbutt then :HeadbuttHigh
          when :rock_smash then :RockSmash
          else
            $PokemonEncounters.encounter_type rescue nil
          end
        end

        def target_found_message(current)
          name = current[:unknown] ? _INTL("Rare Signal") :
            GameData::Species.get(current[:species]).name
          if FIELD_METHODS.include?(current[:method_id])
            action = case current[:method_id]
                     when :surf then _INTL("Surf to the ripple.")
                     when :fishing then _INTL("Use a fishing rod at the signal.")
                     when :headbutt then _INTL("Use Headbutt on the marked tree.")
                     else _INTL("Use Rock Smash on the marked rock.")
                     end
            return _INTL("{1} located. {2}", name, action)
          end
          _INTL("{1} located nearby.", name)
        end

        def signal_location_line(current)
          dx = current[:x].to_i - $game_player.x.to_i
          dy = current[:y].to_i - $game_player.y.to_i
          vertical = dy < 0 ? _INTL("North") : (dy > 0 ? _INTL("South") : nil)
          horizontal = dx < 0 ? _INTL("West") : (dx > 0 ? _INTL("East") : nil)
          direction = [vertical, horizontal].compact.join("-")
          direction = _INTL("Here") if direction.empty?
          distance = dx.abs + dy.abs
          unit = distance == 1 ? _INTL("tile") : _INTL("tiles")
          _INTL("Signal: {1}, {2} {3}", direction, distance, unit)
        rescue StandardError
          _INTL("Signal location unavailable")
        end

        def location_failure_message(method_id)
          case method_id
          when :surf
            _INTL("No reachable Surf signal could be placed in nearby water.")
          when :fishing
            _INTL("No reachable fishing signal could be placed nearby.")
          when :headbutt
            _INTL("No Headbutt tree is close enough for this signal.")
          when :rock_smash
            _INTL("No breakable rock is close enough for this signal.")
          else
            _INTL("No reachable target position was found nearby.")
          end
        end

        def global_call(name, *args)
          Object.new.__send__(name, *args)
        end

        def global_method?(name)
          Object.private_method_defined?(name) || Object.method_defined?(name)
        end

        def log_debug(message)
          KantoReloaded::Log.debug(message, :wild_link) if defined?(KantoReloaded::Log)
        rescue StandardError
          nil
        end
      end
    end
  end
end
