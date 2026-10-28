#==============================================================================
# Kanto Reloaded - Weather Alerts
#==============================================================================

module KantoReloaded
  module WeatherSystem
    module Alerts
      WIDTH = 210
      HEIGHT = 52
      TARGET_X = 8
      TARGET_Y = 8
      HOLD_SECONDS = 3

      PANEL = Color.new(16, 20, 38, 238)
      BORDER = Color.new(55, 75, 160, 255)
      TITLE = Color.new(80, 230, 150, 255)
      TEXT = Color.new(255, 255, 255, 255)

      class << self
        def show(state)
          return false unless WeatherSystem.enabled? && WeatherSystem.alerts?
          return false unless map_scene?
          data = state.is_a?(Hash) ? state : {}
          dispose
          @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
          @viewport.z = 99_997
          @sprite = Sprite.new(@viewport)
          @sprite.bitmap = Bitmap.new(WIDTH, HEIGHT)
          @sprite.x = -WIDTH
          @sprite.y = TARGET_Y
          @sprite.opacity = 255
          draw(@sprite.bitmap, data)
          @age = 0
          @active = true
          true
        rescue StandardError => e
          dispose
          WeatherSystem.log_exception("Weather alert failed to open", e)
          false
        end

        def show_change(previous_state, current_state)
          previous = state_weather(previous_state)
          current = state_weather(current_state)
          return false if previous == current
          show(current_state)
        end

        def update
          unless @active && @sprite && !@sprite.disposed? &&
                 WeatherSystem.enabled? && WeatherSystem.alerts? && map_scene?
            dispose if @active
            return false
          end
          @age = @age.to_i + 1
          slide_frames = [[frame_rate / 5, 6].max, 12].min
          hold_frames = frame_rate * HOLD_SECONDS
          fade_frames = [[frame_rate / 3, 8].max, 18].min
          if @age <= slide_frames
            distance = WIDTH + TARGET_X
            @sprite.x = -WIDTH + (distance * @age / slide_frames)
          elsif @age <= slide_frames + hold_frames
            @sprite.x = TARGET_X
          else
            fade_age = @age - slide_frames - hold_frames
            if fade_age >= fade_frames
              dispose
              return false
            end
            @sprite.opacity = 255 - (255 * fade_age / fade_frames)
          end
          true
        rescue StandardError => e
          dispose
          WeatherSystem.log_exception("Weather alert update failed", e)
          false
        end

        def dispose
          if @sprite && !@sprite.disposed?
            bitmap = @sprite.bitmap
            @sprite.dispose
            bitmap.dispose if bitmap && !bitmap.disposed?
          end
          @viewport.dispose if @viewport && !@viewport.disposed?
          @sprite = nil
          @viewport = nil
          @age = 0
          @active = false
          true
        rescue
          @sprite = nil
          @viewport = nil
          @active = false
          false
        end

        private

        def draw(bitmap, state)
          bitmap.clear
          KantoReloaded::UI::Draw.rounded_rect(
            bitmap, 0, 0, WIDTH, HEIGHT, 6, PANEL, BORDER
          )
          weather = WeatherSystem.normalize_weather(state[:weather])
          intensity = state[:intensity].to_i
          Forecast.draw_icon(bitmap, weather, intensity, 10, 12, 28)
          pbSetSmallFont(bitmap)
          bitmap.font.size = 12
          KantoReloaded::UI::Draw.plain_text(
            bitmap, 48, 7, WIDTH - 56, 15, "WEATHER CHANGED", TITLE
          )
          bitmap.font.size = 15
          description = WeatherSystem.weather_name(weather)
          description = _INTL("{1} / Intensity {2}", description, intensity) if
            weather != :None
          KantoReloaded::UI::Draw.plain_text(
            bitmap, 48, 23, WIDTH - 56, 20, description, TEXT
          )
        end

        def state_weather(state)
          data = state.is_a?(Hash) ? state : {}
          WeatherSystem.normalize_weather(data[:weather] || data["weather"])
        rescue
          :None
        end

        def map_scene?
          defined?($scene) && defined?(Scene_Map) && $scene.is_a?(Scene_Map)
        rescue
          false
        end

        def frame_rate
          rate = defined?(Graphics) ? Graphics.frame_rate.to_i : 40
          [rate, 1].max
        rescue
          40
        end
      end
    end
  end
end
