#==============================================================================
# Kanto Reloaded - Wild Link UI
#==============================================================================

module KantoReloaded
  module WildLink
    module UI
      module PreviewCache
        CACHE_VERSION = 3
        DESKTOP_LIMIT = 128
        JOIPLAY_LIMIT = 64
        FULL_SPRITE_SIZE = 64
        class Entry
          attr_reader :frame_width
          attr_reader :frame_height
          attr_reader :frame_count
          attr_reader :offset_x
          attr_reader :offset_y

          def initialize(animated_bitmap, frame_width, frame_height,
                         frame_count, offset_x, offset_y)
            @animated_bitmap = animated_bitmap
            @frame_width = frame_width
            @frame_height = frame_height
            @frame_count = frame_count
            @offset_x = offset_x
            @offset_y = offset_y
            @references = 0
            @evicted = false
          end

          def bitmap
            @animated_bitmap && @animated_bitmap.bitmap
          end

          def update
            @animated_bitmap.update if @animated_bitmap
          end

          def acquire
            @references += 1
            self
          end

          def release
            @references -= 1 if @references > 0
            dispose if @evicted && @references <= 0
          end

          def evict
            @evicted = true
            dispose if @references <= 0
          end

          def disposed?
            !@animated_bitmap || @animated_bitmap.disposed?
          rescue StandardError
            true
          end

          def dispose
            return if disposed?
            @animated_bitmap.dispose
            @animated_bitmap = nil
          rescue StandardError
            @animated_bitmap = nil
          end
        end

        class << self
          def fetch(species, context_signature)
            @entries ||= {}
            @order ||= []
            key = [WildLink.species_key(species), context_signature]
            entry = @entries[key]
            if entry && !entry.disposed?
              touch(key)
              return entry
            end
            @entries.delete(key)
            @order.delete(key)
            entry = build_entry(species, context_signature[1])
            return nil unless entry
            @entries[key] = entry
            touch(key)
            trim
            entry
          end

          def context_signature
            variables = defined?($game_variables) ? $game_variables : nil
            global = defined?($PokemonGlobal) ? $PokemonGlobal : nil
            substitutions = if global &&
                               global.respond_to?(:alt_sprite_substitutions)
                              global.alt_sprite_substitutions
                            end
            [
              CACHE_VERSION,
              WildLink.sprite_mode,
              variables && defined?(VAR_FUSION_ICON_STYLE) ?
                variables[VAR_FUSION_ICON_STYLE].to_i : 0,
              substitution_signature(substitutions)
            ]
          rescue StandardError
            [CACHE_VERSION, SPRITES_FULL, 0, ""]
          end

          def clear
            (@entries || {}).each_value(&:evict)
            @entries = {}
            @order = []
          rescue StandardError
            @entries = {}
            @order = []
          end

          private

          def build_entry(species, sprite_mode)
            if sprite_mode.to_i == SPRITES_FULL
              full_sprite = build_full_sprite_entry(species)
              return full_sprite if full_sprite
            end
            dex_number = fusion_dex_number(species)
            return build_fusion_species_entry(dex_number) if dex_number
            data = GameData::Species.try_get(species)
            return nil unless data
            build_regular_species_entry(data)
          end

          def build_full_sprite_entry(species)
            dex_number = fusion_dex_number(species)
            unless dex_number
              data = GameData::Species.try_get(species)
              return nil unless data
              dex_number = data.id_number
            end
            source = GameData::Species.sprite_bitmap_from_pokemon_id(
              dex_number
            )
            return nil unless source && source.bitmap
            bounds = visible_bounds(source.bitmap)
            width = [bounds[2].to_i, 1].max
            height = [bounds[3].to_i, 1].max
            scale = [
              FULL_SPRITE_SIZE.to_f / width,
              FULL_SPRITE_SIZE.to_f / height,
              2.0
            ].min
            target_width = [(width * scale).round, 1].max
            target_height = [(height * scale).round, 1].max
            result = Bitmap.new(target_width, target_height)
            result.stretch_blt(
              Rect.new(0, 0, target_width, target_height),
              source.bitmap,
              Rect.new(bounds[0], bounds[1], width, height)
            )
            animated = AnimatedBitmap.from_bitmap(result)
            Entry.new(
              animated, target_width, target_height, 1, 0, 0
            )
          rescue StandardError => e
            result.dispose if result && !result.disposed?
            WildLink.log_exception(
              "Wild Link full sprite loading failed", e
            )
            nil
          ensure
            source.dispose if source && !source.disposed?
          end

          def visible_bounds(bitmap)
            width = bitmap.width.to_i
            height = bitmap.height.to_i
            return [0, 0, width, height] if width <= 0 || height <= 0
            step = [[width, height].max / 96, 1].max
            min_x = width
            min_y = height
            max_x = -1
            max_y = -1
            y = 0
            while y < height
              x = 0
              while x < width
                if bitmap.get_pixel(x, y).alpha.to_i > 0
                  min_x = x if x < min_x
                  min_y = y if y < min_y
                  max_x = x if x > max_x
                  max_y = y if y > max_y
                end
                x += step
              end
              y += step
            end
            return [0, 0, width, height] if max_x < 0 || max_y < 0
            left = [min_x - step, 0].max
            top = [min_y - step, 0].max
            right = [max_x + step, width - 1].min
            bottom = [max_y + step, height - 1].min
            [left, top, right - left + 1, bottom - top + 1]
          rescue StandardError
            [0, 0, bitmap.width.to_i, bitmap.height.to_i]
          end

          def build_regular_species_entry(data)
            path = GameData::Species.icon_filename(
              data.species, data.form, nil, false, false, false
            )
            build_path_entry(path)
          end

          def build_fusion_species_entry(dex_number)
            path = exact_fusion_icon_path(dex_number)
            return build_path_entry(path) if path
            build_composite_fusion_entry(dex_number)
          end

          def exact_fusion_icon_path(dex_number)
            if isTripleFusion?(dex_number)
              return pbResolveBitmap(
                sprintf("Graphics/Icons/icon%d", dex_number)
              ) || pbResolveBitmap("Graphics/Icons/iconDNA")
            end
            custom = custom_fusion_icon_path(dex_number)
            return custom if custom
            generated = pbResolveBitmap(
              sprintf("Graphics/Icons/icon%03d", dex_number)
            )
            return generated if generated
            cached = pbResolveBitmap(
              sprintf(
                "Graphics/Pokemon/FusionIcons/icon%03d",
                dex_number
              )
            )
            return cached if cached
            nil
          rescue StandardError
            nil
          end

          def build_path_entry(path)
            return nil unless path
            animated = AnimatedBitmap.new(path)
            unless animated.bitmap
              animated.dispose
              return nil
            end
            frame_height = [animated.bitmap.height.to_i, 1].max
            frame_width = frame_height
            frame_count = [
              animated.bitmap.width.to_i / frame_width, 1
            ].max
            Entry.new(
              animated, frame_width, frame_height, frame_count, 0, 0
            )
          rescue StandardError => e
            animated.dispose if animated && !animated.disposed?
            WildLink.log_exception("Wild Link icon loading failed", e)
            nil
          end

          def build_composite_fusion_entry(dex_number)
            body_number = getBodyID(dex_number)
            head_number = getHeadID(dex_number, body_number)
            body_species = GameData::Species.get(body_number).species
            head_species = GameData::Species.get(head_number).species
            head = AnimatedBitmap.new(
              GameData::Species.icon_filename(head_species, 0)
            )
            body = AnimatedBitmap.new(
              GameData::Species.icon_filename(body_species, 0)
            )
            return nil unless head.bitmap && body.bitmap
            width = head.bitmap.width.to_i
            height = head.bitmap.height.to_i
            return nil if width <= 0 || height <= 0
            result = Bitmap.new(width, height)
            result.blt(0, 0, head.bitmap, Rect.new(0, 0, width, height))
            start_y = height / 2
            start_y += ::Settings::FUSION_ICON_SPRITE_OFFSET.to_i if
              defined?(::Settings::FUSION_ICON_SPRITE_OFFSET)
            copy_width = [width, body.bitmap.width.to_i].min
            copy_height = [
              height - start_y, body.bitmap.height.to_i - start_y
            ].min
            result.fill_rect(
              0, start_y, width, height - start_y,
              Color.new(0, 0, 0, 0)
            ) if start_y >= 0 && start_y < height
            if copy_width > 0 && copy_height > 0
              result.blt(
                0, start_y, body.bitmap,
                Rect.new(0, start_y, copy_width, copy_height)
              )
            end
            animated = AnimatedBitmap.from_bitmap(result)
            frame_width = [height, 1].max
            Entry.new(
              animated, frame_width, height,
              [width / frame_width, 1].max, 0, 0
            )
          rescue StandardError
            result.dispose if result && !result.disposed?
            nil
          ensure
            head.dispose if head && !head.disposed?
            body.dispose if body && !body.disposed?
          end

          def fusion_dex_number(species)
            maximum = defined?(::Settings::NB_POKEMON) ?
              ::Settings::NB_POKEMON.to_i : 0
            return nil if maximum <= 0
            return species if species.is_a?(Integer) && species > maximum
            match = species.to_s.match(/\AB(\d+)H(\d+)\z/)
            return nil unless match
            (match[1].to_i * maximum) + match[2].to_i
          rescue StandardError
            nil
          end

          def custom_fusion_icon_path(dex_number)
            resolver = PokemonIconSprite.allocate
            path = resolver.send(:customIcons, dex_number)
            resolve_source_path(path)
          rescue StandardError
            nil
          end

          def resolve_source_path(path)
            return nil if path.to_s.empty?
            resolved = pbResolveBitmap(path.to_s) rescue nil
            candidate = resolved || path.to_s
            return candidate if File.file?(candidate)
            png = candidate + ".png"
            File.file?(png) ? png : nil
          rescue StandardError
            nil
          end

          def substitution_signature(substitutions)
            return "" unless substitutions.is_a?(Hash)
            substitutions.keys.sort_by { |key| key.to_s }.map do |key|
              "#{canonical_value(key)}=#{canonical_value(substitutions[key])}"
            end.join("|")
          rescue StandardError
            ""
          end

          def canonical_value(value)
            case value
            when Array
              "[" + value.map { |entry| canonical_value(entry) }.join(",") + "]"
            when Hash
              keys = value.keys.sort_by { |key| key.to_s }
              "{" + keys.map do |key|
                "#{canonical_value(key)}=#{canonical_value(value[key])}"
              end.join(",") + "}"
            else
              value.to_s
            end
          end

          def touch(key)
            @order.delete(key)
            @order << key
          end

          def trim
            while @entries.length > cache_limit
              key = @order.shift
              break unless key
              entry = @entries.delete(key)
              entry.evict if entry
            end
          end

          def cache_limit
            if defined?(KantoReloaded::Platform) &&
               KantoReloaded::Platform.respond_to?(:joiplay?) &&
               KantoReloaded::Platform.joiplay?
              JOIPLAY_LIMIT
            else
              DESKTOP_LIMIT
            end
          rescue StandardError
            JOIPLAY_LIMIT
          end
        end
      end

      class PreviewIconSprite < Sprite
        def initialize(entry, viewport)
          super(viewport)
          @entry = entry.acquire
          @counter = 0
          @current_frame = 0
          self.bitmap = @entry.bitmap
          self.src_rect.width = @entry.frame_width
          self.src_rect.height = @entry.frame_height
        end

        def update
          super
          return unless @entry
          @entry.update
          self.bitmap = @entry.bitmap
          limit = [
            (Graphics.frame_rate / 4) / [@entry.frame_count, 1].max, 1
          ].max
          @counter += 1
          if @counter >= limit
            @current_frame = (@current_frame + 1) % @entry.frame_count
            @counter = 0
          end
          self.src_rect.x = @entry.frame_width * @current_frame
        end

        def dispose
          return if disposed?
          self.bitmap = nil
          super
          @entry.release if @entry
          @entry = nil
        rescue StandardError
          @entry.release if @entry
          @entry = nil
        end
      end

      class << self
        def open
          opened = false
          return false unless graphics_available?
          return false if @opening
          @opening = true
          opened = true
          result = nil
          KantoReloaded::UI::Modal.with_modal do
            result = Scene.new.main
          end
          result
        rescue StandardError => e
          WildLink.log_exception("Wild Link UI failed", e)
          false
        ensure
          if opened
            KantoReloaded::UI::Modal.drain_input if
              defined?(KantoReloaded::UI::Modal)
            @opening = false
          end
        end

        private

        def graphics_available?
          defined?(Graphics) && defined?(Input) && defined?(Viewport) &&
            defined?(BitmapSprite) && defined?(PokemonIconSprite) &&
            defined?(KantoReloaded::ListState)
        end
      end

      class Scene
        SCREEN_W = 512
        SCREEN_H = 384
        HEADER_H = 72
        FOOTER_H = 28
        ROW_H = 25
        LIST_X = 8
        LIST_Y = HEADER_H + 4
        LIST_W = 310
        LIST_H = SCREEN_H - LIST_Y - FOOTER_H - 4
        DETAIL_X = LIST_X + LIST_W + 8
        DETAIL_W = SCREEN_W - DETAIL_X - 8
        VISIBLE_ROWS = (LIST_H - 12) / ROW_H
        ICON_CACHE_LIMIT = 40
        JOIPLAY_ICON_CACHE_LIMIT = 24
        BACKGROUND_Z = 0
        PANEL_Z = 1
        CURSOR_Z = 2
        CONTENT_Z = 3
        ICON_Z = 4
        BG = Color.new(16, 20, 31)
        PANEL = Color.new(26, 32, 48)
        BORDER = Color.new(56, 79, 126)
        WHITE = Color.new(255, 255, 255)
        GRAY = Color.new(174, 181, 201)
        DIM = Color.new(104, 112, 138)
        BLUE = Color.new(112, 191, 255)
        GREEN = Color.new(102, 224, 158)
        GOLD = Color.new(240, 202, 82)
        RED = Color.new(235, 98, 116)

        def initialize
          @method_index = 0
          @detail_page = :search_level
          @result = false
          @detail_icon_key = nil
          @detail_icons = {}
          @detail_icon_order = []
          @active_detail_icon = nil
          @active_detail_icon_cache_key = nil
          @pending_detail_icon_entry = nil
          @pending_detail_icon_frame = nil
          @pending_detail_icon_key = nil
          @row_presentations = {}
          @icon_context_signature = PreviewCache.context_signature
        end

        def main
          setup
          KantoReloaded::UI::Modal.drain_input if
            defined?(KantoReloaded::UI::Modal)
          loop do
            Graphics.update
            Input.update
            @active_detail_icon.update if @active_detail_icon
            result = handle_input
            break if result == :close
            process_pending_detail_icon
            draw_list_cursor if ((Graphics.frame_count rescue 0) % 4).zero?
          end
          @result
        ensure
          dispose
        end

        private

        def setup
          @viewport = Viewport.new(0, 0, SCREEN_W, SCREEN_H)
          @viewport.z = 999_999
          @viewport.visible = false
          @background = Sprite.new(@viewport)
          @background.bitmap = Bitmap.new(SCREEN_W, SCREEN_H)
          @background.bitmap.fill_rect(0, 0, SCREEN_W, SCREEN_H, BG)
          @background.z = BACKGROUND_Z
          @header_sprite = BitmapSprite.new(SCREEN_W, HEADER_H, @viewport)
          @list_panel_sprite = BitmapSprite.new(LIST_W, LIST_H, @viewport)
          @list_cursor_sprite = BitmapSprite.new(
            LIST_W - 14, ROW_H - 3, @viewport
          )
          @list_sprite = BitmapSprite.new(LIST_W, LIST_H, @viewport)
          @detail_sprite = BitmapSprite.new(DETAIL_W, LIST_H, @viewport)
          @footer_sprite = BitmapSprite.new(SCREEN_W, FOOTER_H, @viewport)
          @list_panel_sprite.x = LIST_X
          @list_panel_sprite.y = LIST_Y
          @header_sprite.z = PANEL_Z
          @list_panel_sprite.z = PANEL_Z
          @list_cursor_sprite.z = CURSOR_Z
          @list_sprite.x = LIST_X
          @list_sprite.y = LIST_Y
          @list_sprite.z = CONTENT_Z
          @detail_sprite.x = DETAIL_X
          @detail_sprite.y = LIST_Y
          @detail_sprite.z = PANEL_Z
          @footer_sprite.y = SCREEN_H - FOOTER_H
          @footer_sprite.z = PANEL_Z
          draw_list_panel
          started_at = Time.now.to_f
          load_methods
          elapsed = Time.now.to_f - started_at
          if elapsed >= 0.25 && defined?(KantoReloaded::Log)
            KantoReloaded::Log.warning(
              format(
                "Wild Link roster loading took %.3fs on map %d",
                elapsed, WildLink.current_map_id
              ),
              :wild_link
            )
          end
          draw_all
          refresh_detail_icon(@state.current) if @state
          @viewport.visible = true
        end

        def load_methods(preferred_method = nil, preferred_species = nil)
          old_method = preferred_method || current_method_id
          old_species = preferred_species || current_species_key
          @methods = EncounterPools.available_methods
          if old_method
            found = @methods.index { |method| method[:id] == old_method }
            @method_index = found if found
          end
          @method_index = @method_index.clamp(
            0, [@methods.length - 1, 0].max
          )
          load_entries(old_species)
        end

        def load_entries(preferred_species = nil)
          @entries = current_method ?
            EncounterPools.entries_for(current_method) : []
          @state = KantoReloaded::ListState::State.new(
            @entries, :visible_rows => VISIBLE_ROWS
          )
          if preferred_species
            index = @entries.index do |entry|
              !entry[:signal] &&
                WildLink.species_key(entry[:species]) == preferred_species
            end
            @state.select(index) if index
          end
          build_row_presentations
          build_method_completion
          @detail_icon_key = nil
        end

        def draw_all
          draw_header
          draw_list
          draw_detail
          draw_footer
        rescue StandardError => e
          WildLink.log_exception("Wild Link scene redraw failed", e)
          raise
        end

        def draw_list_panel
          bitmap = @list_panel_sprite.bitmap
          bitmap.clear
          panel(bitmap, LIST_W, LIST_H)
        end

        def draw_header
          bitmap = @header_sprite.bitmap
          bitmap.clear
          bitmap.fill_rect(0, 0, SCREEN_W, HEADER_H, BG)
          set_font(bitmap, 16)
          text(bitmap, 8, -1, SCREEN_W - 16, 24, _INTL("WILD LINK"), BLUE, 1, 16)
          draw_method_completion(bitmap)
          if @methods.empty?
            text(
              bitmap, 8, 30, SCREEN_W - 16, 22,
              _INTL("No compatible encounter signals are available here."),
              DIM, 1
            )
          else
            draw_method_tabs(bitmap)
          end
          bitmap.fill_rect(0, HEADER_H - 1, SCREEN_W, 1, BORDER)
        end

        def draw_method_completion(bitmap)
          progress = @method_completion
          return unless progress && progress[:total].to_i > 0
          total = progress[:total].to_i
          text(
            bitmap, 8, 1, 150, 18,
            _INTL("Seen {1}/{2}", progress[:seen], total),
            GOLD, 0, 12
          )
          text(
            bitmap, SCREEN_W - 158, 1, 150, 18,
            _INTL("Caught {1}/{2}", progress[:caught], total),
            GREEN, 2, 12
          )
        rescue StandardError => e
          WildLink.log_exception("Wild Link header progress draw failed", e)
        end

        def draw_method_tabs(bitmap)
          width = (SCREEN_W - 16) / @methods.length
          @methods.each_with_index do |method, index|
            x = 8 + index * width
            actual_width = index == @methods.length - 1 ?
              SCREEN_W - 8 - x : width - 2
            if index == @method_index
              fill, border = KantoReloaded::Options.cursor_colors
              KantoReloaded::UI::Draw.rounded_rect(
                bitmap, x, 29, actual_width, 27, 4, fill, border
              )
            end
            color = index == @method_index ? WHITE : GRAY
            text(
              bitmap, x + 2, 29, actual_width - 4, 25,
              method[:label], color, 1
            )
          end
          active = Runtime.target
          return unless active
          label = active[:unknown] ? _INTL("Rare Signal") :
            EncounterPools.species_name(active[:species])
          text(
            bitmap, 8, 51, SCREEN_W - 16, 18,
            _INTL("Active: {1} | Chain {2}", label, WildLink.runtime.chain),
            GREEN, 1, 13
          )
        rescue StandardError => e
          WildLink.log_exception("Wild Link method tabs draw failed", e)
        end

        def draw_list
          bitmap = @list_sprite.bitmap
          bitmap.clear
          set_font(bitmap, 15)
          if @state.empty?
            @list_cursor_sprite.visible = false
            text(
              bitmap, 10, 104, LIST_W - 20, 24,
              _INTL("No Pokemon are available for this method."), DIM, 1
            )
            return
          end
          @state.visible.each_with_index do |entry, local|
            index = @state.scroll + local
            y = 6 + local * ROW_H
            selected = index == @state.index
            presentation = presentation_for(entry)
            color = if entry[:signal] || entry[:rare]
                      GOLD
                    else
                      selected ? WHITE : presentation[:row_color]
                    end
            text(
              bitmap, 14, y - 2, LIST_W - 112, ROW_H,
              presentation[:name], color
            )
            text(
              bitmap, LIST_W - 110, y - 2, 94, ROW_H,
              presentation[:status], presentation[:status_color], 2
            )
          end
          draw_list_cursor
        end

        def draw_detail
          bitmap = @detail_sprite.bitmap
          bitmap.clear
          panel(bitmap, DETAIL_W, LIST_H)
          set_font(bitmap, 15)
          entry = @state.current
          unless entry
            hide_active_detail_icon
            text(
              bitmap, 8, 104, DETAIL_W - 16, 24,
              _INTL("Select a signal."), DIM, 1
            )
            return
          end
          hide_detail_icon_for_other_entry(entry)
          name = presentation_for(entry)[:name]
          text(bitmap, 8, 8, DETAIL_W - 16, 22, name, WHITE, 1)
          if entry[:signal]
            draw_signal_detail(bitmap, entry)
          else
            draw_species_detail(bitmap, entry)
          end
        end

        def draw_signal_detail(bitmap, entry)
          current = active_signal_target? ? Runtime.target : nil
          status = if current
                     _INTL("Active Signal")
                   elsif entry[:unlocked]
                     _INTL("Signal Available")
                   else
                     _INTL("Signal Locked")
                   end
          color = (current || entry[:unlocked]) ? GREEN : RED
          text(bitmap, 8, 34, DETAIL_W - 16, 20, status, color, 1)
          if current
            draw_search_and_chain(
              bitmap,
              current[:search_level].to_i,
              current[:chain].to_i
            )
            if @detail_page == :bonuses
              draw_bonus_preview(
                bitmap, entry, current[:search_level], current[:chain],
                161, current[:species]
              )
            else
              draw_active_details(bitmap, current, 161)
            end
            return
          end
          if @detail_page == :bonuses
            draw_bonus_preview(bitmap, entry, 0, 0, 161, nil)
            return
          end
          text(
            bitmap, 10, 123, DETAIL_W - 20, 38,
            entry[:unlocked] ?
              _INTL("Search for an undiscovered route-exclusive Pokemon.") :
              _INTL("See every standard Land Pokemon on this map first."),
            GRAY, 1
          )
          draw_level_range(bitmap, entry, 174)
        end

        def draw_species_detail(bitmap, entry)
          presentation = presentation_for(entry)
          seen = presentation[:seen]
          caught = presentation[:caught]
          status = caught ? _INTL("Caught") : (seen ? _INTL("Seen") : _INTL("Unseen"))
          color = caught ? GREEN : (seen ? GOLD : DIM)
          text(bitmap, 8, 34, DETAIL_W - 16, 20, status, color, 1)
          level = WildLink.search_level(entry[:species])
          method_id = current_method ? current_method[:id] : :land
          chain = WildLink.chain_for(entry[:species], method_id)
          draw_search_and_chain(bitmap, level, chain)
          active = active_target_for?(entry)
          if @detail_page == :bonuses
            draw_bonus_preview(bitmap, entry, level, chain, 161)
          elsif active
            draw_active_details(bitmap, Runtime.target, 161)
          else
            draw_search_level_info(bitmap, level, 161)
          end
        end

        def draw_search_and_chain(bitmap, level, chain)
          text(
            bitmap, 10, 122, DETAIL_W - 20, 20,
            _INTL("Search Level"), GRAY
          )
          text(
            bitmap, 10, 122, DETAIL_W - 20, 20,
            level.to_i.to_s, BLUE, 2
          )
          text(bitmap, 10, 143, DETAIL_W - 20, 20, _INTL("Chain"), GRAY)
          text(bitmap, 10, 143, DETAIL_W - 20, 20, chain.to_i.to_s, GOLD, 2)
        end

        def draw_bonus_preview(bitmap, entry, level, chain, start_y,
                               species = entry[:species])
          preview = Bonuses.bonus_preview(level, chain, species)
          native_min = entry[:min_level].to_i
          native_max = entry[:max_level].to_i
          native_levels = native_min == native_max ?
            native_min.to_s : "#{native_min}-#{native_max}"
          bonus_min, bonus_max = preview[:level_bonus]
          level_bonus = bonus_min == bonus_max ?
            "+#{bonus_min}" : "+#{bonus_min}-#{bonus_max}"
          second_egg = preview[:second_egg_move]
          hidden_label = percentage_or_na(preview[:hidden_ability])
          item_label = percentage_or_na(preview[:held_item])

          text(
            bitmap, 8, start_y, DETAIL_W - 16, 16,
            _INTL("CURRENT BONUSES"), BLUE, 1, 13
          )
          text(
            bitmap, 8, start_y + 16, DETAIL_W - 16, 16,
            _INTL("Levels {1} | Bonus {2}", native_levels, level_bonus),
            GRAY, 1, 12
          )
          text(
            bitmap, 8, start_y + 31, DETAIL_W - 16, 16,
            _INTL("Shiny +{1} Rolls", preview[:shiny_rolls]),
            GREEN, 1, 12
          )
          text(
            bitmap, 8, start_y + 46, DETAIL_W - 16, 16,
            _INTL("IV {1}", preview[:perfect_ivs]), WHITE, 1, 12
          )
          text(
            bitmap, 8, start_y + 61, DETAIL_W - 16, 16,
            _INTL("HA {1} | Item Roll {2}", hidden_label, item_label),
            GOLD, 1, 12
          )
          if preview[:first_egg_move].nil?
            text(
              bitmap, 8, start_y + 76, DETAIL_W - 16, 16,
              _INTL("Egg Moves N/A"), GRAY, 1, 12
            )
          else
            second_egg_label = case second_egg
                               when :locked then _INTL("Locked")
                               when nil then _INTL("N/A")
                               else _INTL("{1}%", second_egg)
                               end
            text(
              bitmap, 8, start_y + 76, DETAIL_W - 16, 16,
              _INTL("Egg 1 {1}% | Egg 2 {2}",
                    preview[:first_egg_move], second_egg_label),
              GRAY, 1, 12
            )
          end
        rescue StandardError => e
          WildLink.log_exception("Wild Link bonus preview draw failed", e)
        end

        def percentage_or_na(value)
          value.nil? ? _INTL("N/A") : _INTL("{1}%", value)
        end

        def draw_level_range(bitmap, entry, y)
          minimum = entry[:min_level].to_i
          maximum = entry[:max_level].to_i
          label = minimum == maximum ? minimum.to_s : "#{minimum}-#{maximum}"
          text(bitmap, 10, y, DETAIL_W - 20, 20, _INTL("Native Levels"), GRAY)
          text(bitmap, 10, y, DETAIL_W - 20, 20, label, WHITE, 2)
        end

        def draw_active_details(bitmap, current, start_y)
          lines = Runtime.target_summary_lines(current)
          locked_details = lines.empty?
          if locked_details
            lines = [_INTL("Target details unlock as Search Level rises.")]
          end
          set_font(bitmap, 12)
          text(
            bitmap, 8, start_y, DETAIL_W - 16, 16,
            _INTL("SEARCH LEVEL INFO"), BLUE, 1, 13
          )
          wrapped = lines.inject([]) do |rows, line|
            rows.concat(
              KantoReloaded::UI::Draw.wrap_lines(
                bitmap, line.to_s, DETAIL_W - 20
              )
            )
          end
          wrapped.first(8).each_with_index do |line, index|
            color = locked_details ? GREEN : (index.zero? ? GREEN : GRAY)
            text(
              bitmap, 8, start_y + 15 + index * 12, DETAIL_W - 16, 14,
              line, color, 1, 12
            )
          end
        end

        def draw_search_level_info(bitmap, level, start_y)
          text(
            bitmap, 8, start_y, DETAIL_W - 16, 16,
            _INTL("SEARCH LEVEL INFO"), BLUE, 1, 13
          )
          unlock_rows.each_with_index do |row, index|
            threshold, label = row
            unlocked = level.to_i >= threshold
            text(
              bitmap, 8, start_y + 16 + index * 13,
              DETAIL_W - 16, 16,
              _INTL("SL {1}  {2}", threshold, label),
              unlocked ? GREEN : DIM, 1, 12
            )
          end
        end

        def unlock_rows
          [
            [1, _INTL("Target Level")],
            [5, _INTL("Temperament")],
            [10, _INTL("Perfect IVs")],
            [15, _INTL("Held Item")],
            [20, _INTL("Ability")],
            [25, _INTL("Egg Moves")],
            [50, _INTL("Signal Location")]
          ]
        end

        def draw_footer
          bitmap = @footer_sprite.bitmap
          bitmap.clear
          bitmap.fill_rect(0, 0, SCREEN_W, FOOTER_H, BG)
          bitmap.fill_rect(0, 0, SCREEN_W, 1, BORDER)
          @footer_entries = footer_entries
          KantoReloaded::HintText.draw_footer(
            bitmap, @footer_entries,
            8, 4, SCREEN_W - 16,
            :size => 14, :color => WHITE, :height => FOOTER_H,
            :y_offset => -4, :show_hint => false
          )
        end

        def footer_entries
          entries = [
            KantoReloaded::HintText.confirm("Search"),
            KantoReloaded::HintText.back("Back")
          ]
          entries << KantoReloaded::HintText.action("Cancel Link") if
            cancellable_link?
          entries << KantoReloaded::HintText.special(
            @detail_page == :bonuses ? "SL Info" : "Bonuses"
          )
          entries << KantoReloaded::HintText.other("Method", "L/R")
          entries
        end

        def handle_input
          mouse_result = update_mouse
          if mouse_result == :cancel &&
             KantoReloaded::MouseInput.mouse_triggered?
            return cancel_current_link
          elsif mouse_result == :search &&
             KantoReloaded::MouseInput.mouse_triggered?
            return search_selected
          elsif mouse_result == :method &&
                KantoReloaded::MouseInput.mouse_triggered?
            return :continue
          end
          wheel = KantoReloaded::MouseInput.wheel_delta
          if wheel != 0
            move(wheel < 0 ? 1 : -1)
          elsif Input.repeat?(Input::UP)
            move(-1)
          elsif Input.repeat?(Input::DOWN)
            move(1)
          elsif Input.repeat?(Input::LEFT)
            move(-5)
          elsif Input.repeat?(Input::RIGHT)
            move(5)
          elsif trigger?(:AUX1)
            change_method(-1)
          elsif trigger?(:AUX2)
            change_method(1)
          elsif trigger?(:SPECIAL)
            toggle_detail_page
          elsif Input.trigger?(Input::ACTION) && cancellable_link?
            return cancel_current_link
          elsif Input.trigger?(Input::USE)
            return search_selected
          elsif Input.trigger?(Input::BACK)
            pbPlayCloseMenuSE rescue nil
            return :close
          end
          :continue
        end

        def toggle_detail_page
          @detail_page = @detail_page == :bonuses ? :search_level : :bonuses
          pbPlayCursorSE rescue nil
          draw_detail
          draw_footer
          :continue
        end

        def cancellable_link?
          Runtime.active? || Runtime.chain_active?
        end

        def cancel_current_link
          proceed = WildLink.confirm(
            _INTL("Cancel the current Wild Link target and end its chain?"),
            :default => false, :serious => true, :theme => :warning
          )
          unless proceed
            draw_all
            return :continue
          end
          if Runtime.active?
            Runtime.clear_target(:manual_cancel, true)
          else
            WildLink.break_chain
          end
          pbPlayCancelSE rescue nil
          WildLink.toast(:success, _INTL("The current Wild Link was cancelled."))
          load_methods(current_method_id, current_species_key)
          draw_all
          :continue
        end

        def search_selected
          entry = @state.current
          return :continue unless entry && current_method
          unless searchable?(entry)
            pbPlayBuzzerSE rescue nil
            message = entry[:signal] ?
              _INTL("This Rare Signal is still locked.") :
              _INTL("This Pokemon must be seen before it can be searched.")
            WildLink.message(message, :theme => :warning)
            draw_all
            return :continue
          end
          label = presentation_for(entry)[:name]
          proceed = WildLink.confirm(
            _INTL("Start a Wild Link search for {1}?", label),
            :default => true
          )
          unless proceed
            draw_all
            return :continue
          end
          if Runtime.start_search(entry, current_method)
            @result = :target_started
            return :close
          end
          load_methods(current_method_id, current_species_key)
          draw_all
          :continue
        end

        def searchable?(entry)
          presentation_for(entry)[:searchable]
        end

        def move(amount)
          return unless @state.move(amount)
          pbPlayCursorSE rescue nil
          draw_list
          draw_detail
          queue_detail_icon(@state.current)
        end

        def change_method(amount)
          return if @methods.empty?
          @method_index = (@method_index + amount.to_i) % @methods.length
          pbPlayCursorSE rescue nil
          load_entries
          draw_all
          queue_detail_icon(@state.current)
        end

        def update_mouse
          position = KantoReloaded::MouseInput.active_position
          return nil unless position
          x, y = position
          return :cancel if cancellable_link? &&
                            footer_entry_at?(x, y, :action)
          if y >= 29 && y < 57 && x >= 8 && x < SCREEN_W - 8 &&
             !@methods.empty?
            width = (SCREEN_W - 16) / @methods.length
            index = ((x - 8) / width).clamp(0, @methods.length - 1)
            if index != @method_index
              @method_index = index
              load_entries
              pbPlayCursorSE rescue nil
              draw_all
              queue_detail_icon(@state.current)
            end
            return :method
          end
          return nil unless x >= LIST_X && x < LIST_X + LIST_W
          return nil unless y >= LIST_Y + 6 && y < LIST_Y + LIST_H - 6
          local = (y - LIST_Y - 6) / ROW_H
          index = @state.scroll + local
          return nil if index < 0 || index >= @state.rows.length
          changed = index != @state.index
          if changed
            @state.select(index)
            draw_list
            draw_detail
          end
          queue_detail_icon(@state.current) if
            changed || !detail_icon_requested_for?(@state.current)
          :search
        end

        def footer_entry_at?(mouse_x, mouse_y, type)
          local_y = mouse_y - @footer_sprite.y
          return false if local_y < 0 || local_y >= FOOTER_H
          bitmap = @footer_sprite.bitmap
          entries = @footer_entries || footer_entries
          labels = entries.map do |entry|
            KantoReloaded::HintText.format([entry])
          end
          separator = "   "
          separator_width = bitmap.text_size(separator).width
          full_text = labels.join(separator)
          full_width = bitmap.text_size(full_text).width
          footer_width = SCREEN_W - 16
          hidden_hint = KantoReloaded::HintText.other("Hints", "Z")
          hint_text = KantoReloaded::HintText.format([hidden_hint])
          hint_width = [
            bitmap.text_size(hint_text).width + 8, footer_width / 3
          ].min
          center_width = [footer_width - hint_width - 8, 0].max
          cursor_x = 8 + [(center_width - full_width) / 2, 0].max
          entries.each_with_index do |entry, index|
            label_width = bitmap.text_size(labels[index]).width
            if entry[:type] == type.to_sym
              left = cursor_x - separator_width / 2
              right = cursor_x + label_width + separator_width / 2
              return mouse_x >= left && mouse_x < right
            end
            cursor_x += label_width + separator_width
          end
          false
        rescue StandardError
          false
        end

        def refresh_detail_icon(entry)
          request = detail_icon_request(entry)
          return hide_active_detail_icon unless request
          presentation = presentation_for(entry)
          display_key = [
            request[:key], presentation[:seen], presentation[:caught],
            entry[:signal], request[:active_signal]
          ]
          if @detail_icon_key == display_key && @active_detail_icon
            touch_detail_icon(request[:key])
            return
          end
          icon = cached_detail_icon(request[:key], request[:species])
          return hide_active_detail_icon unless icon
          hide_active_detail_icon unless @active_detail_icon.equal?(icon)
          @active_detail_icon = icon
          @active_detail_icon_cache_key = request[:key]
          @detail_icon_key = display_key
          icon.visible = true
          if entry[:signal] ||
             (!presentation[:seen] && !presentation[:caught])
            icon.color = Color.new(0, 0, 0, 255)
          else
            icon.color = Color.new(0, 0, 0, 0)
          end
        rescue StandardError => e
          WildLink.log_exception("Wild Link detail icon refresh failed", e)
          hide_active_detail_icon
        end

        def queue_detail_icon(entry)
          request = detail_icon_request(entry)
          return hide_active_detail_icon unless request
          presentation = presentation_for(entry)
          display_key = [
            request[:key], presentation[:seen], presentation[:caught],
            entry[:signal], request[:active_signal]
          ]
          if @detail_icon_key == display_key && @active_detail_icon
            @pending_detail_icon_entry = nil
            @pending_detail_icon_frame = nil
            @pending_detail_icon_key = nil
            touch_detail_icon(request[:key])
            return
          end
          hide_active_detail_icon
          @pending_detail_icon_entry = entry
          @pending_detail_icon_frame = Graphics.frame_count rescue 0
          @pending_detail_icon_key = display_key
        rescue StandardError => e
          WildLink.log_exception("Wild Link detail icon queue failed", e)
          hide_active_detail_icon
        end

        def process_pending_detail_icon
          entry = @pending_detail_icon_entry
          return unless entry
          queued_at = @pending_detail_icon_frame.to_i
          current_frame = Graphics.frame_count rescue queued_at
          return if current_frame - queued_at < 2
          @pending_detail_icon_entry = nil
          @pending_detail_icon_frame = nil
          @pending_detail_icon_key = nil
          refresh_detail_icon(entry)
        rescue StandardError => e
          @pending_detail_icon_entry = nil
          @pending_detail_icon_frame = nil
          @pending_detail_icon_key = nil
          WildLink.log_exception("Wild Link deferred preview failed", e)
        end

        def detail_icon_requested_for?(entry)
          request = detail_icon_request(entry)
          return false unless request
          presentation = presentation_for(entry)
          display_key = [
            request[:key], presentation[:seen], presentation[:caught],
            entry[:signal], request[:active_signal]
          ]
          @detail_icon_key == display_key ||
            @pending_detail_icon_key == display_key
        rescue StandardError
          false
        end

        def hide_detail_icon_for_other_entry(entry)
          return if detail_icon_requested_for?(entry)
          hide_active_detail_icon
        end

        def detail_icon_request(entry)
          return nil unless entry
          active_signal = entry[:signal] && active_signal_target?
          species = active_signal ? Runtime.target[:species] : entry[:species]
          return nil unless species
          {
            :key => WildLink.species_key(species),
            :species => species,
            :active_signal => active_signal
          }
        rescue StandardError
          nil
        end

        def cached_detail_icon(key, species)
          icon = @detail_icons[key]
          if icon && !icon.disposed?
            touch_detail_icon(key)
            return icon
          end
          @detail_icons.delete(key)
          @detail_icon_order.delete(key)
          entry = PreviewCache.fetch(species, @icon_context_signature)
          return nil unless entry
          icon = PreviewIconSprite.new(entry, @viewport)
          icon.x = DETAIL_X +
                   (DETAIL_W - entry.frame_width) / 2 +
                   entry.offset_x
          icon.y = LIST_Y + 55 +
                   (PreviewCache::FULL_SPRITE_SIZE - entry.frame_height) / 2 +
                   entry.offset_y
          icon.z = ICON_Z
          icon.visible = false
          @detail_icons[key] = icon
          touch_detail_icon(key)
          trim_detail_icon_cache
          icon
        rescue StandardError => e
          WildLink.log_exception("Wild Link preview cache failed", e)
          nil
        end

        def touch_detail_icon(key)
          @detail_icon_order.delete(key)
          @detail_icon_order << key
        end

        def trim_detail_icon_cache
          while @detail_icons.length > detail_icon_cache_limit
            victim = @detail_icon_order.find do |key|
              key != @active_detail_icon_cache_key
            end
            break unless victim
            @detail_icon_order.delete(victim)
            icon = @detail_icons.delete(victim)
            icon.dispose if icon && !icon.disposed?
          end
        rescue StandardError
          nil
        end

        def detail_icon_cache_limit
          if defined?(KantoReloaded::Platform) &&
             KantoReloaded::Platform.respond_to?(:joiplay?) &&
             KantoReloaded::Platform.joiplay?
            JOIPLAY_ICON_CACHE_LIMIT
          else
            ICON_CACHE_LIMIT
          end
        rescue StandardError
          JOIPLAY_ICON_CACHE_LIMIT
        end

        def hide_active_detail_icon
          if @active_detail_icon && !@active_detail_icon.disposed?
            @active_detail_icon.visible = false
          end
          @active_detail_icon = nil
          @active_detail_icon_cache_key = nil
          @detail_icon_key = nil
          @pending_detail_icon_entry = nil
          @pending_detail_icon_frame = nil
          @pending_detail_icon_key = nil
        rescue StandardError
          @active_detail_icon = nil
          @active_detail_icon_cache_key = nil
          @detail_icon_key = nil
          @pending_detail_icon_entry = nil
          @pending_detail_icon_frame = nil
          @pending_detail_icon_key = nil
        end

        def build_row_presentations
          @row_presentations = {}
          @entries.each do |entry|
            signal = !!entry[:signal]
            seen = signal ? false : WildLink.seen?(entry[:species])
            caught = signal ? false : WildLink.caught?(entry[:species])
            status = if signal
                       entry[:unlocked] ? _INTL("Ready") : _INTL("Locked")
                     elsif caught
                       _INTL("Caught")
                     elsif seen
                       _INTL("Seen")
                     else
                       _INTL("Unknown")
                     end
            status_color = if signal
                             entry[:unlocked] ? GREEN : RED
                           elsif caught
                             GREEN
                           elsif seen
                             GOLD
                           else
                             DIM
                           end
            row_color = (signal || entry[:rare]) ? GOLD : GRAY
            @row_presentations[entry.object_id] = {
              :name => EncounterPools.entry_name(entry),
              :status => status,
              :status_color => status_color,
              :row_color => row_color,
              :seen => seen,
              :caught => caught,
              :searchable => signal ? !!entry[:unlocked] : seen
            }
          end
        rescue StandardError => e
          WildLink.log_exception("Wild Link row presentation build failed", e)
          @row_presentations = {}
        end

        def build_method_completion
          seen = 0
          caught = 0
          total = 0
          counted = {}
          @entries.each do |entry|
            if entry[:signal]
              signals = EncounterPools.signal_species(entry)
              hidden = signals.reject do |species|
                counted[WildLink.species_key(species)]
              end
              if signals.empty?
                total += 1
              else
                hidden.each do |species|
                  counted[WildLink.species_key(species)] = true
                end
                total += hidden.length
              end
              next
            end
            key = WildLink.species_key(entry[:species])
            next if counted[key]
            counted[key] = true
            presentation = presentation_for(entry)
            total += 1
            seen += 1 if presentation[:seen] || presentation[:caught]
            caught += 1 if presentation[:caught]
          end
          @method_completion = {
            :seen => seen,
            :caught => caught,
            :total => total
          }
        rescue StandardError => e
          WildLink.log_exception("Wild Link completion counter build failed", e)
          @method_completion = nil
        end

        def presentation_for(entry)
          presentation = @row_presentations[entry.object_id]
          return presentation if presentation
          signal = !!entry[:signal]
          seen = signal ? false : WildLink.seen?(entry[:species])
          caught = signal ? false : WildLink.caught?(entry[:species])
          status = if signal
                     entry[:unlocked] ? _INTL("Ready") : _INTL("Locked")
                   elsif caught
                     _INTL("Caught")
                   elsif seen
                     _INTL("Seen")
                   else
                     _INTL("Unknown")
                   end
          status_color = if signal
                           entry[:unlocked] ? GREEN : RED
                         elsif caught
                           GREEN
                         elsif seen
                           GOLD
                         else
                           DIM
                         end
          {
            :name => EncounterPools.entry_name(entry),
            :status => status,
            :status_color => status_color,
            :row_color => (signal || entry[:rare]) ? GOLD : GRAY,
            :seen => seen,
            :caught => caught,
            :searchable => signal ? !!entry[:unlocked] : seen
          }
        end

        def active_target_for?(entry)
          current = Runtime.target
          return false unless current && !entry[:signal] && current_method
          current[:method_id] == current_method[:id] &&
            WildLink.species_key(current[:species]) ==
              WildLink.species_key(entry[:species])
        end

        def active_signal_target?
          current = Runtime.target
          return false unless current && current[:rare_signal] && current_method
          current[:method_id] == current_method[:id]
        rescue StandardError
          false
        end

        def current_method
          return nil unless @methods && !@methods.empty?
          @methods[@method_index]
        end

        def current_method_id
          method = current_method
          method ? method[:id] : nil
        end

        def current_species_key
          entry = @state && @state.current
          entry && !entry[:signal] ? WildLink.species_key(entry[:species]) : nil
        end

        def panel(bitmap, width, height)
          KantoReloaded::UI::Draw.rounded_rect(
            bitmap, 0, 0, width, height, 5, PANEL, BORDER
          )
        end

        def draw_list_cursor
          return unless @list_cursor_sprite
          if !@state || @state.empty?
            @list_cursor_sprite.visible = false
            return
          end
          local = @state.index - @state.scroll
          unless local >= 0 && local < VISIBLE_ROWS
            @list_cursor_sprite.visible = false
            return
          end
          frame = Graphics.frame_count rescue 0
          pulse = Math.sin(frame * Math::PI / 20.0) * 0.5 + 0.5
          fill_base, border_base = KantoReloaded::Options.cursor_colors
          fill = KantoReloaded::UI::Draw.with_alpha(
            fill_base, 90 + (pulse * 80).to_i
          )
          border = KantoReloaded::UI::Draw.with_alpha(
            border_base, 155 + (pulse * 80).to_i
          )
          bitmap = @list_cursor_sprite.bitmap
          bitmap.clear
          KantoReloaded::UI::Draw.rounded_rect(
            bitmap, 0, 0, bitmap.width, bitmap.height, 4, fill, border
          )
          @list_cursor_sprite.x = LIST_X + 7
          @list_cursor_sprite.y = LIST_Y + 8 + local * ROW_H
          @list_cursor_sprite.visible = true
        rescue StandardError
          @list_cursor_sprite.visible = false if @list_cursor_sprite
        end

        def set_font(bitmap, size = 15)
          pbSetSmallFont(bitmap) if defined?(pbSetSmallFont)
          bitmap.font.size = size
        end

        def text(bitmap, x, y, width, height, value, color,
                 align = 0, size = 15)
          KantoReloaded::UI::Draw.plain_text(
            bitmap, x, y, width, height, value.to_s, color, align, size
          )
        end

        def trigger?(name)
          KantoReloaded::UI::InputRouter.input_triggered?(name)
        rescue StandardError
          false
        end

        def dispose
          @detail_icons.each_value do |icon|
            icon.dispose if icon && !icon.disposed?
          rescue StandardError
            nil
          end
          @detail_icons.clear
          [@background, @header_sprite, @list_panel_sprite,
           @list_cursor_sprite, @list_sprite, @detail_sprite,
           @footer_sprite].each do |sprite|
            next unless sprite
            if sprite.bitmap && !sprite.bitmap.disposed?
              sprite.bitmap.dispose
            end
            sprite.dispose unless sprite.disposed?
          rescue StandardError
            nil
          end
          @viewport.dispose if @viewport && !@viewport.disposed?
          Graphics.update if defined?(Graphics)
        rescue StandardError
          nil
        end
      end
    end

    class SettingsScene < KantoReloaded::SettingsUI::BaseScene
      def scene_title
        "Wild Link"
      end

      def scene_description
        "Configure Wild Link search behavior and permanent progression."
      end

      def pbGetOptions(_inloadscreen = false)
        rows = []
        rows << setting_row(SPRITES_SETTING)
        rows << setting_row(MESSAGES_SETTING)
        rows << setting_row(CONTINUE_SETTING)
        rows << KantoReloaded::Options::TextDisplayOption.new(
          _INTL("Search Level Cap"),
          proc { SEARCH_LEVEL_CAP.to_s },
          _INTL("Search Levels are stored per exact Pokemon species or fusion.")
        )
        rows << KantoReloaded::Options::TextDisplayOption.new(
          _INTL("Shiny Bonus"),
          proc { _INTL("+8 Rolls Maximum") },
          _INTL("Search Level and chain bonuses provide up to eight additional rolls.")
        )
        rows << KantoReloaded::Options::TextDisplayOption.new(
          _INTL("Chain Scope"),
          proc { _INTL("Pokemon / Method / Map") },
          _INTL("Changing the Pokemon, method, or map ends the active chain.")
        )
        rows << KantoReloaded::Options::ActionButton.new(
          _INTL("Reset Search Levels"),
          proc { reset_search_levels },
          _INTL("Erase all permanent Wild Link Search Level progression.")
        )
        rows.compact
      end

      private

      def setting_row(key)
        definition = KantoReloaded::Settings.definition(key)
        return nil unless definition
        KantoReloaded::SettingsUI::RowFactory.build(
          definition, :scene => self, :wild_link => true
        )
      end

      def reset_search_levels
        return unless KantoReloaded::PopupWindow.confirm(
          _INTL("Erase every Wild Link Search Level? This cannot be undone."),
          :default => false, :serious => true, :theme => :warning
        )
        if Runtime.active?
          Runtime.clear_target(:reset, true)
        elsif Runtime.chain_active?
          WildLink.break_chain
        end
        WildLink.reset_search_levels
        sync_window_values
        WildLink.toast(:success, _INTL("Wild Link Search Levels reset."))
      end
    end
  end
end
