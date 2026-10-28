#==============================================================================
# Kanto Reloaded - Economy System UI
#==============================================================================

module KantoReloaded
  module EconomySystem
    module EconomyUI
      SW = 512
      SH = 384
      ROW_H = 28
      BG = Color.new(18, 22, 34)
      PANEL = Color.new(28, 34, 52)
      BORDER = Color.new(60, 80, 130)
      WHITE = Color.new(255, 255, 255)
      GRAY = Color.new(170, 178, 200)
      DIM = Color.new(100, 108, 135)
      GOLD = Color.new(240, 200, 80)
      GREEN = Color.new(100, 215, 80)
      RED = Color.new(225, 95, 90)
      ENDING_SOON_SECONDS = 24 * 60 * 60
      FILTERS = [
        [:all, "All"],
        [:sale, "Sales"],
        [:shortage, "Shortages"],
        [:ending_soon, "Ending Soon"]
      ].freeze
      class << self
        def open_status
          if defined?(KantoReloaded::UI::Modal)
            KantoReloaded::UI::Modal.with_modal { Scene.new.main }
          else
            Scene.new.main
          end
        rescue StandardError => e
          KantoReloaded::Log.exception(
            "Mart Events failed to open", e, :channel => :economy_system
          ) if defined?(KantoReloaded::Log)
          KantoReloaded::PopupWindow.message(
            _INTL("Mart Events could not be opened."), :theme => :error
          ) if defined?(KantoReloaded::PopupWindow)
          false
        ensure
          KantoReloaded::UI::Modal.drain_input if
            defined?(KantoReloaded::UI::Modal)
        end
      end

      class Scene
        def main
          start_scene
          loop do
            Graphics.update
            Input.update
            handle_input
            break if @closing
          end
          true
        ensure
          end_scene
        end

        private

        def start_scene
          Graphics.freeze
          @all_events = MartEvents.known_active_events
          @filter_index = 0
          current = @all_events.find { |entry| entry[:current] }
          rebuild_events(current && current[:key])
          @closing = false
          screen_width = Graphics.width rescue SW
          screen_height = Graphics.height rescue SH
          @viewport = Viewport.new(0, 0, screen_width, screen_height)
          @viewport.z = 1_000_000_000
          @background = Sprite.new(@viewport)
          @background.bitmap = Bitmap.new(screen_width, screen_height)
          @background.bitmap.fill_rect(
            0, 0, screen_width, screen_height, Color.new(18, 22, 34, 255)
          )
          @background.z = 0
          @sprite = Sprite.new(@viewport)
          @sprite.bitmap = Bitmap.new(SW, SH)
          @sprite.z = 1
          draw
          Graphics.transition(8)
        end

        def end_scene
          Graphics.freeze
          if @sprite
            @sprite.bitmap.dispose if @sprite.bitmap && !@sprite.bitmap.disposed?
            @sprite.dispose unless @sprite.disposed?
          end
          if @background
            @background.bitmap.dispose if @background.bitmap && !@background.bitmap.disposed?
            @background.dispose unless @background.disposed?
          end
          @viewport.dispose if @viewport && !@viewport.disposed?
          Graphics.transition(8)
        rescue StandardError
          nil
        end

        def handle_input
          if Input.repeat?(Input::UP)
            move(-1)
          elsif Input.repeat?(Input::DOWN)
            move(1)
          elsif Input.trigger?(Input::LEFT)
            change_filter(-1)
          elsif Input.trigger?(Input::RIGHT)
            change_filter(1)
          elsif Input.trigger?(Input::BACK) || Input.trigger?(Input::USE)
            pbPlayCancelSE if defined?(pbPlayCancelSE)
            @closing = true
          else
            handle_mouse
          end
        end

        def handle_mouse
          mx, my = KantoReloaded::MouseInput.active_position
          wheel = KantoReloaded::MouseInput.wheel_delta
          return move(wheel < 0 ? 1 : -1) if wheel != 0
          return unless mx && my && KantoReloaded::MouseInput.mouse_triggered?
          if mx >= 12 && mx < 220 && my >= 55 && my < 77
            change_filter(mx < 116 ? -1 : 1)
            return
          end
          return unless mx >= 8 && mx < 224 && my >= 80 && my < 80 + 10 * ROW_H
          chosen = @scroll + ((my - 80) / ROW_H).floor
          return unless chosen >= 0 && chosen < @events.length
          @index = chosen
          pbPlayCursorSE if defined?(pbPlayCursorSE)
          draw
        rescue StandardError
          nil
        end

        def move(amount)
          return if @events.empty?
          next_index = [[@index + amount.to_i, 0].max, @events.length - 1].min
          return if next_index == @index
          @index = next_index
          visible = 10
          @scroll = @index if @index < @scroll
          @scroll = @index - visible + 1 if @index >= @scroll + visible
          pbPlayCursorSE if defined?(pbPlayCursorSE)
          draw
        end

        def change_filter(amount)
          selected = @events[@index] if @events && !@events.empty?
          @filter_index = (@filter_index + amount.to_i) % FILTERS.length
          rebuild_events(selected && selected[:key])
          pbPlayCursorSE if defined?(pbPlayCursorSE)
          draw
        end

        def rebuild_events(preferred_key = nil)
          @events = apply_filter(@all_events)
          @index = if preferred_key
                     @events.index { |entry| entry[:key].to_s == preferred_key.to_s } || 0
                   else
                     0
                   end
          @scroll = 0
          @scroll = @index - 9 if @index >= 10
        end

        def apply_filter(events)
          rows = Array(events)
          filter = FILTERS[@filter_index][0]
          case filter
          when :sale
            rows.select { |entry| entry[:event]["type"].to_s == "sale" }
          when :shortage
            rows.select { |entry| entry[:event]["type"].to_s == "shortage" }
          when :ending_soon
            now_value = current_time
            cutoff = now_value + ENDING_SOON_SECONDS
            rows.select do |entry|
              expires_at = entry[:event]["expires_at"].to_i
              expires_at > now_value && expires_at <= cutoff
            end.sort_by { |entry| entry[:event]["expires_at"].to_i }
          else
            rows
          end
        rescue StandardError
          []
        end

        def current_time
          defined?(pbGetTimeNow) ? pbGetTimeNow.to_i : Time.now.to_i
        rescue StandardError
          Time.now.to_i
        end

        def filter_label
          FILTERS[@filter_index][1]
        end

        def empty_filter_text
          case FILTERS[@filter_index][0]
          when :sale then _INTL("No active sales.")
          when :shortage then _INTL("No active shortages.")
          when :ending_soon then _INTL("No events ending soon.")
          else _INTL("No active Mart Events.")
          end
        end

        def draw
          bitmap = @sprite.bitmap
          bitmap.clear
          panel(bitmap, 8, 42, 216, 304)
          panel(bitmap, 232, 42, 272, 304)
          pbSetSmallFont(bitmap)
          bitmap.font.size = 20
          text(bitmap, 0, 8, SW, 28, _INTL("MART EVENTS"), WHITE, 1)
          bitmap.font.size = 16
          text(bitmap, 12, 55, 208, 22, _INTL("< {1} >", filter_label.upcase), GOLD, 1)
          if @events.empty?
            text(bitmap, 20, 96, 192, 22, empty_filter_text, DIM, 1)
          else
            bitmap.font.size = 18
            @events[@scroll, 10].to_a.each_with_index do |entry, row|
              y = 80 + row * ROW_H
              selected = @scroll + row == @index
              cursor(bitmap, 13, y, 206, ROW_H - 3) if selected
              label = entry[:label].to_s
              color = selected ? WHITE : GRAY
              text(
                bitmap, 13, y + 7, 206, ROW_H - 3,
                trim(bitmap, label, 196), color, 1
              )
            end
            draw_details(bitmap, @events[@index])
          end
          KantoReloaded::HintText.draw(
            bitmap,
            [
              KantoReloaded::HintText.confirm("Close"),
              KantoReloaded::HintText.back("Close"),
              KantoReloaded::HintText.other("Filter", "L/R")
            ],
            8, 354, SW - 16,
            :size => 14, :height => 20, :color => GRAY, :align => 1
          )
        end

        def draw_details(bitmap, entry)
          event = entry[:event]
          type = event["type"].to_s
          color = type == "sale" ? GREEN : RED
          bitmap.font.size = 20
          text(bitmap, 244, 58, 248, 24, entry[:label], WHITE, 1)
          bitmap.font.size = 18
          heading = type == "sale" ? _INTL("MART SALE") : _INTL("MART SHORTAGE")
          text(bitmap, 244, 91, 248, 24, heading, color, 1)
          bitmap.font.size = 16
          rows = [
            [_INTL("Adjustment"), _INTL("{1}% {2}", event["percent"].to_i,
              type == "sale" ? _INTL("off") : _INTL("markup"))],
            [_INTL("Scope"), scope_text(event)],
            [_INTL("Remaining"), MartEvents.remaining_text(event)]
          ]
          y = 132
          rows.each do |label, value|
            text(bitmap, 248, y, 100, 20, label, DIM)
            text(bitmap, 340, y, 150, 20, value, WHITE, 2)
            y += 28
          end
          affected = affected_text(event)
          text(bitmap, 248, 255, 236, 20, _INTL("AFFECTED"), GOLD, 1)
          wrapped = wrap(bitmap, affected, 236)
          wrapped.first(3).each_with_index do |line, index|
            text(bitmap, 248, 279 + index * 18, 236, 18, line, GRAY, 1)
          end
        end

        def scope_text(event)
          case event["scope"].to_s
          when "items" then _INTL("Selected Items")
          when "category" then event["category_name"].to_s
          when "shopwide" then _INTL("Whole Shop")
          else _INTL("None")
          end
        end

        def affected_text(event)
          if event["pending_targets"]
            return _INTL("Chosen when this Mart opens")
          end
          return scope_text(event) unless event["scope"].to_s == "items"
          names = Array(event["targets"]).map do |id|
            data = GameData::Item.try_get(id.to_sym) rescue nil
            data ? data.name.to_s : id.to_s
          end
          names.empty? ? _INTL("Selected items") : names.join(", ")
        end

        def panel(bitmap, x, y, width, height)
          KantoReloaded::UI::Draw.rounded_rect(
            bitmap, x, y, width, height, 5, PANEL, BORDER
          )
        end

        def cursor(bitmap, x, y, width, height)
          fill, _border = KantoReloaded::Options.cursor_colors rescue [
            Color.new(100, 160, 220, 190), Color.new(80, 130, 210)
          ]
          KantoReloaded::UI::Draw.rounded_rect(
            bitmap, x, y, width, height, 4, fill
          )
        end

        def text(bitmap, x, y, width, height, value, color, align = 0)
          bitmap.font.color = color
          bitmap.draw_text(x, y, width, height, value.to_s, align)
        end

        def trim(bitmap, value, width)
          result = value.to_s
          return result if bitmap.text_size(result).width <= width
          result = result[0...-1] while !result.empty? &&
            bitmap.text_size("#{result}...").width > width
          "#{result}..."
        end

        def wrap(bitmap, value, width)
          lines = []
          line = ""
          value.to_s.split(/\s+/).each do |word|
            candidate = line.empty? ? word : "#{line} #{word}"
            if bitmap.text_size(candidate).width <= width
              line = candidate
            else
              lines << line unless line.empty?
              line = word
            end
          end
          lines << line unless line.empty?
          lines
        end
      end
    end
  end
end
