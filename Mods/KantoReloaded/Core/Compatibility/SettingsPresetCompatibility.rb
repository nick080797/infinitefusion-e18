#==============================================================================
# Kanto Reloaded Settings Preset Compatibility
#==============================================================================
# Extends KIF's existing .kro presets with KR registry values and provides
# portable preset paths for JoiPlay without replacing the preset scene.
#==============================================================================

module KantoReloaded
  module SettingsPresetCompatibility
    PRESET_KEY = "kanto_reloaded"
    SCHEMA_VERSION = 1

    class << self
      def install
        return true if @installed
        return false unless defined?(SLOptionsScene)

        install_scene_hooks
        @installed = true
        KantoReloaded::Log.info("Installed KR settings preset compatibility", :ui) if defined?(KantoReloaded::Log)
        true
      rescue StandardError => e
        @installed = false
        log_exception("Settings preset compatibility failed", e)
        false
      end

      def add_kr_settings(payload)
        return payload unless payload.is_a?(Hash)
        extended = payload.dup
        extended[PRESET_KEY] = {
          "schema_version" => SCHEMA_VERSION,
          "framework_version" => KantoReloaded.version.to_s,
          "settings" => exported_settings
        }
        extended
      rescue StandardError => e
        log_exception("Could not add KR settings to preset", e)
        payload
      end

      def load_kr_settings(payload)
        return 0 unless payload.is_a?(Hash)
        section = payload[PRESET_KEY] || payload[PRESET_KEY.to_sym]
        return 0 unless section.is_a?(Hash)
        values = section["settings"] || section[:settings]
        return 0 unless values.is_a?(Hash)
        return 0 unless defined?(KantoReloaded::Settings)

        imported = KantoReloaded::Settings.import_values(
          values,
          :overwrite => true,
          :notify => false
        )
        KantoReloaded::Settings.apply_callbacks(:preset_loaded)
        KantoReloaded::Log.info("Loaded #{imported} KR setting(s) from preset", :settings) if defined?(KantoReloaded::Log)
        imported
      rescue StandardError => e
        log_exception("Could not load KR settings from preset", e)
        0
      end

      def save_preset(index)
        path = preset_path(index)
        payload = add_kr_settings(options_to_json())
        write_text(path, payload.to_s)
        pbMessage(_INTL("Saved current options into Preset {1}.", preset_name(index)))
        true
      rescue StandardError => e
        log_exception("Could not save settings preset", e)
        pbMessage(_INTL("The settings preset could not be saved."))
        false
      end

      def load_preset(index)
        path = existing_preset_path(index)
        unless path
          pbPlayBuzzerSE
          pbMessage(_INTL("No options found in {1}.", preset_name(index)))
          return false
        end
        payload = eval(KantoReloaded::Platform.read_text(path))
        options_load_json(payload)
        load_kr_settings(payload)
        pbMessage(_INTL("Loaded options from Preset {1}.", preset_name(index)))
        true
      rescue StandardError => e
        log_exception("Could not load settings preset", e)
        pbMessage(_INTL("The settings preset could not be loaded."))
        false
      end

      def save_names
        write_text(names_path, $PokemonSystem.optionsnames.to_s)
        true
      rescue StandardError => e
        log_exception("Could not save settings preset names", e)
        pbMessage(_INTL("The preset name could not be saved."))
        false
      end

      def prepare_names
        return true if $KURAY_OPTIONSNAME_LOADED
        $KURAY_OPTIONSNAME_LOADED = true
        path = existing_names_path
        return true unless path
        values = eval(KantoReloaded::Platform.read_text(path))
        if values.is_a?(Array) && values.length == 12
          $PokemonSystem.optionsnames = values
        end
        true
      rescue StandardError => e
        log_exception("Could not load settings preset names", e)
        true
      end

      def joiplay?
        defined?(KantoReloaded::Platform) &&
          KantoReloaded::Platform.respond_to?(:joiplay?) &&
          KantoReloaded::Platform.joiplay?
      end

      private

      def install_scene_hooks
        KantoReloaded::Hooks.wrap(
          SLOptionsScene,
          :pbSaveKO,
          :kr_settings_preset_save,
          :required => true
        ) do |_hook, index = 1|
          KantoReloaded::SettingsPresetCompatibility.save_preset(index)
        end
        KantoReloaded::Hooks.wrap(
          SLOptionsScene,
          :pbLoadKO,
          :kr_settings_preset_load,
          :required => true
        ) do |_hook, index = 1|
          KantoReloaded::SettingsPresetCompatibility.load_preset(index)
        end
        KantoReloaded::Hooks.wrap(
          SLOptionsScene,
          :buildKO,
          :kr_settings_preset_names_save,
          :required => true
        ) do |_hook, *_arguments|
          KantoReloaded::SettingsPresetCompatibility.save_names
        end
        KantoReloaded::Hooks.wrap(
          SLOptionsScene,
          :createButtonsOption,
          :kr_settings_preset_names_load,
          :required => true
        ) do |hook, *arguments|
          KantoReloaded::SettingsPresetCompatibility.prepare_names
          hook.call(*arguments)
        end
      end

      def exported_settings
        return {} unless defined?(KantoReloaded::Settings)
        values = KantoReloaded::Settings.export_values(:include_defaults => true)
        KantoReloaded::Settings.definitions.each do |definition|
          next unless definition[:type] == :button
          values.delete(definition[:key].to_s)
          values.delete(definition[:key])
        end
        values
      end

      def preset_name(index)
        names = $PokemonSystem.optionsnames rescue nil
        value = names[index.to_i] if names.respond_to?(:[])
        value.to_s.empty? ? _INTL("Preset {1}", index.to_i + 1) : value
      end

      def preset_path(index)
        File.join(storage_directory, "Options_#{index.to_i}.kro")
      end

      def names_path
        File.join(storage_directory, "Options_Names.kro")
      end

      def existing_preset_path(index)
        existing_path("Options_#{index.to_i}.kro")
      end

      def existing_names_path
        existing_path("Options_Names.kro")
      end

      def existing_path(filename)
        path_candidates(filename).find { |path| KantoReloaded::Platform.file?(path) }
      end

      def path_candidates(filename)
        candidates = [File.join(storage_directory, filename)]
        if defined?(RTP) && RTP.respond_to?(:getSaveFolder)
          folder = RTP.getSaveFolder rescue nil
          unless folder.to_s.empty?
            candidates << File.join(folder.to_s, filename)
            candidates << (folder.to_s + "\\" + filename)
          end
        end
        candidates.map { |path| File.expand_path(path) }.uniq
      end

      def storage_directory
        if defined?(KantoReloaded::GlobalSettings)
          return File.dirname(KantoReloaded::GlobalSettings.storage_path)
        end
        KantoReloaded::Platform.user_data_directory
      end

      def write_text(path, payload)
        ensure_directory(File.dirname(path))
        File.open(path, "wb") { |file| file.write(payload.to_s) }
        raise "Settings preset write produced an empty file" if File.size(path) <= 0
        true
      end

      def ensure_directory(path)
        return true if File.directory?(path)
        parent = File.dirname(path)
        ensure_directory(parent) unless parent == path || File.directory?(parent)
        Dir.mkdir(path) unless File.directory?(path)
        true
      end

      def log_exception(message, error)
        KantoReloaded::Log.exception(message, error, channel: :settings) if defined?(KantoReloaded::Log)
      rescue
        nil
      end
    end
  end
end

KantoReloaded::SettingsPresetCompatibility.install
