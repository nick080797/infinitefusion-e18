#==============================================================================
# Kanto Reloaded - Weather Audio
#==============================================================================

module KantoReloaded
  module WeatherSystem
    module WeatherAudio
      TRACKS = {
        :Rain => "KR_Weather_Rain",
        :Storm => "KR_Weather_Storm",
        :HeavyRain => "KR_Weather_HeavyRain"
      }.freeze
      THUNDER = ["KR_Weather_Thunder1", "KR_Weather_Thunder2"].freeze
      THUNDER_SECONDS = {
        "KR_Weather_Thunder1" => 8.871,
        "KR_Weather_Thunder2" => 22.739
      }.freeze
      THUNDER_WAIT_SECONDS = {
        :Storm => 6..14,
        :HeavyRain => 10..20
      }.freeze
      AUDIO_EXTENSIONS = [".mp3", ".ogg", ".wav", ".wma", ".mid", ".midi"].freeze
      FADE_SECONDS = 0.4

      class << self
        def sync
          complete_transition
          desired = desired_track
          if desired
            if @owned_track && current_track_name != @owned_track
              relinquish!(:external_change)
              return false
            end
            signature = [current_map_id, desired]
            return false if @relinquished_signature == signature
            start_transition(desired) if @owned_track != desired
          else
            stop_and_restore(true)
          end
          update_thunder
          !desired.nil? || thunder_active?
        rescue StandardError => e
          WeatherSystem.log_exception("Weather audio sync failed", e)
          false
        end

        def map_changed!
          @relinquished_signature = nil
          sync
        end

        def weather_changed!
          @relinquished_signature = nil if
            @relinquished_signature &&
            @relinquished_signature[0].to_i != current_map_id
          sync
        end

        def stop!
          @relinquished_signature = nil
          stop_and_restore(true)
          true
        rescue
          false
        end

        def continue_in_battle?
          defined?($game_temp) && $game_temp &&
            ($game_temp.in_battle rescue false) &&
            WeatherSystem.enabled? &&
            WeatherSystem.battle_weather? &&
            WeatherSystem.kr_weather_owned? &&
            WeatherSystem.custom_audio? &&
            !@owned_track.nil?
        rescue
          false
        end

        def observe_external_change(action, value = nil)
          return if internal?
          return unless @owned_track || @pending
          expected = value.respond_to?(:name) ? value.name.to_s : value.to_s
          return if action == :play && expected == @owned_track
          relinquish!(:external_audio)
        rescue
          nil
        end

        def rain_audio_changed!
          @relinquished_signature = nil
          sync
        end

        def thunder_audio_changed!
          @next_thunder_at = nil
          @thunder_weather = nil
          sync
        end

        def with_internal
          @internal_depth = @internal_depth.to_i + 1
          yield
        ensure
          @internal_depth = [@internal_depth.to_i - 1, 0].max
        end

        def internal?
          @internal_depth.to_i > 0
        end

        private

        def desired_track
          return nil unless WeatherSystem.enabled?
          return nil unless WeatherSystem.custom_audio?
          return nil unless WeatherSystem.rain_audio?
          return nil unless WeatherSystem.kr_weather_owned?
          state = WeatherSystem.current_state
          TRACKS[state[:weather]]
        end

        def start_transition(track)
          capture_previous_bgs unless @owned_track || @pending
          @pending = { :track => track, :restore => false }
          @pending_frame = frame_count + fade_frames
          with_internal { pbBGSFade(FADE_SECONDS) } if current_track_name
          complete_transition(true) if fade_frames <= 1
        end

        def stop_and_restore(immediate = false)
          return false unless @owned_track || @pending || @direct_playback
          if immediate
            @pending = nil
            @pending_frame = nil
            restore_previous_bgs
            @owned_track = nil
            @next_thunder_at = nil
            @thunder_weather = nil
            return true
          end
          @pending = { :track => nil, :restore => true }
          @pending_frame = frame_count + fade_frames
          with_internal { pbBGSFade(FADE_SECONDS) } if current_track_name == @owned_track
          complete_transition(true) if fade_frames <= 1
          true
        end

        def complete_transition(force = false)
          return false unless @pending
          return false unless force || frame_count >= @pending_frame.to_i
          pending = @pending
          @pending = nil
          if pending[:restore]
            restore_previous_bgs
            @owned_track = nil
            @next_thunder_at = nil
            @thunder_weather = nil
          elsif pending[:track]
            track = pending[:track].to_s
            if play_bgs(track, 100, 100)
              @owned_track = track
            else
              WeatherSystem.log_warning(
                "Weather audio file missing: Audio/BGS/#{track}"
              )
              @owned_track = nil
              @direct_playback = false
              @next_thunder_at = nil
              @thunder_weather = nil
            end
          end
          true
        end

        def capture_previous_bgs
          @previous_bgs = if defined?($game_system) && $game_system &&
                             $game_system.respond_to?(:getPlayingBGS)
                            $game_system.getPlayingBGS
                          end
        rescue
          @previous_bgs = nil
        end

        def restore_previous_bgs
          previous = @previous_bgs
          @previous_bgs = nil
          @direct_playback = false
          with_internal do
            if previous && previous.respond_to?(:name) && !previous.name.to_s.empty?
              pbBGSPlay(previous)
            else
              pbBGSStop
            end
          end
        end

        def relinquish!(reason)
          @relinquished_signature = [current_map_id, desired_track]
          @owned_track = nil
          @pending = nil
          @previous_bgs = nil
          @direct_playback = false
          @next_thunder_at = nil
          @thunder_weather = nil
          WeatherSystem.log_debug("Weather audio relinquished: #{reason}")
          true
        end

        def update_thunder
          weather = WeatherSystem.current_state[:weather]
          unless thunder_active?(weather)
            @next_thunder_at = nil
            @thunder_weather = nil
            return false
          end
          if @thunder_weather != weather || @next_thunder_at.nil?
            schedule_thunder(weather)
            return false
          end
          return if monotonic_now < @next_thunder_at.to_f
          sound = THUNDER[audio_random.rand(THUNDER.length)]
          play_se(sound, 100, 100)
          schedule_thunder(weather, sound)
        end

        def schedule_thunder(weather = WeatherSystem.current_state[:weather], sound = nil)
          range = THUNDER_WAIT_SECONDS[weather]
          unless range && thunder_active?(weather)
            @next_thunder_at = nil
            @thunder_weather = nil
            return nil
          end
          @thunder_weather = weather
          sound_seconds = THUNDER_SECONDS[sound.to_s].to_f
          @next_thunder_at = monotonic_now + sound_seconds + audio_random.rand(range)
        end

        def thunder_active?(weather = WeatherSystem.current_state[:weather])
          WeatherSystem.enabled? && WeatherSystem.custom_audio? &&
            WeatherSystem.thunder_audio? && WeatherSystem.kr_weather_owned? &&
            THUNDER_WAIT_SECONDS.key?(weather)
        rescue
          false
        end

        def audio_random
          @audio_random ||= Random.new
        end

        def monotonic_now
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        rescue
          Time.now.to_f
        end

        def current_track_name
          return @owned_track if @direct_playback && @owned_track
          return nil unless defined?($game_system) && $game_system &&
                            $game_system.respond_to?(:playing_bgs)
          current = $game_system.playing_bgs
          current && current.respond_to?(:name) ? current.name.to_s : nil
        rescue
          nil
        end

        def play_bgs(track, volume, pitch)
          native_path = "Audio/BGS/#{track}"
          if native_audio_exists?(native_path)
            @direct_playback = false
            with_internal { pbBGSPlay(track, volume, pitch) }
            return true
          end
          path = mod_audio_path(native_path)
          return false unless path && defined?(Audio)
          with_internal do
            Audio.bgs_play(path, scaled_volume(volume), pitch)
          end
          @direct_playback = true
          true
        rescue StandardError => e
          WeatherSystem.log_exception("Weather BGS playback failed", e)
          false
        end

        def play_se(sound, volume, pitch)
          native_path = "Audio/SE/#{sound}"
          if native_audio_exists?(native_path)
            with_internal { pbSEPlay(sound, volume, pitch) }
            return true
          end
          path = mod_audio_path(native_path)
          return false unless path && defined?(Audio)
          with_internal do
            Audio.se_play(path, scaled_volume(volume), pitch)
          end
          true
        rescue StandardError => e
          WeatherSystem.log_exception("Weather SE playback failed", e)
          false
        end

        def native_audio_exists?(path)
          return false unless defined?(FileTest) &&
                              FileTest.respond_to?(:audio_exist?)
          !!FileTest.audio_exist?(path)
        rescue
          false
        end

        def mod_audio_path(path)
          relative = path.to_s.sub(/\AAudio[\\\/]?/i, "")
          mod_root_candidates.each do |root|
            base = File.join(root, "Audio", relative).tr("\\", "/")
            if defined?(FileTest) && FileTest.respond_to?(:audio_exist?) &&
               FileTest.audio_exist?(base)
              return RTP.getAudioPath(base) if defined?(RTP) &&
                                                RTP.respond_to?(:getAudioPath)
              return base
            end
            return base if File.file?(base)
            AUDIO_EXTENSIONS.each do |extension|
              candidate = "#{base}#{extension}"
              return candidate if File.file?(candidate)
            end
          end
          nil
        rescue
          nil
        end

        def mod_root_candidates
          roots = []
          moddev = defined?(::ModManager) &&
                   ::ModManager.respond_to?(:moddev_override?) &&
                   ::ModManager.moddev_override?
          roots << File.join("ModDev", "KantoReloaded") if moddev
          if defined?(::ModManager) && ::ModManager.respond_to?(:get_mod)
            info = ::ModManager.get_mod("KantoReloaded")
            if info && info.respond_to?(:folder_path)
              folder = info.folder_path.to_s
              folder_name = File.basename(folder.tr("\\", "/"))
              roots << File.join(moddev ? "ModDev" : "Mods", folder_name) unless
                folder_name.empty?
              roots << folder
            end
          end
          roots << File.join("Mods", "KantoReloaded")
          roots << KantoReloaded::ROOT if defined?(KantoReloaded::ROOT)
          roots.compact.map { |root| root.to_s.tr("\\", "/") }.uniq
        rescue
          [File.join("ModDev", "KantoReloaded"),
           File.join("Mods", "KantoReloaded")]
        end

        def scaled_volume(volume)
          scale = if defined?($PokemonSystem) && $PokemonSystem &&
                     $PokemonSystem.respond_to?(:sevolume)
                    $PokemonSystem.sevolume.to_i
                  else
                    100
                  end
          (volume.to_i * scale / 100.0).to_i
        rescue
          volume.to_i
        end

        def current_map_id
          defined?($game_map) && $game_map ? $game_map.map_id.to_i : 0
        rescue
          0
        end

        def fade_frames
          [(frame_rate * FADE_SECONDS).round, 1].max
        end

        def frame_rate
          defined?(Graphics) ? Graphics.frame_rate.to_i : 40
        rescue
          40
        end

        def frame_count
          defined?(Graphics) ? Graphics.frame_count.to_i : 0
        rescue
          0
        end
      end
    end
  end
end
