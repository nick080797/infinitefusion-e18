#==============================================================================
# Kanto Reloaded JoiPlay Dispose Compatibility
#==============================================================================
# KIF's GenOneStyle title-screen class is closed before its dispose helpers are
# declared. Those methods consequently land on Object and can recurse forever
# when JoiPlay disposes an unrelated UI helper.
#==============================================================================

module KantoReloaded
  module JoiPlayDisposeCompatibility
    TITLE_METHODS = [:dispose, :disposed?, :wait].freeze

    class << self
      def install
        return false unless joiplay?
        return true if @installed
        return false unless affected_kif_build?

        promote_title_methods
        installed = KantoReloaded::Hooks.wrap(
          Object,
          :dispose,
          :joiplay_misplaced_title_dispose_guard
        ) do |hook, *arguments|
          if defined?(::GenOneStyle) && is_a?(::GenOneStyle)
            hook.call(*arguments)
          else
            KantoReloaded::JoiPlayDisposeCompatibility.log_ignored_receiver(self)
            nil
          end
        end
        return false unless installed

        @installed = true
        if defined?(KantoReloaded::Log)
          KantoReloaded::Log.info(
            "Installed JoiPlay title-screen dispose compatibility",
            :framework
          )
        end
        true
      rescue StandardError => e
        if defined?(KantoReloaded::Log)
          KantoReloaded::Log.exception(
            "JoiPlay title-screen dispose compatibility failed",
            e,
            channel: :framework
          )
        end
        false
      end

      def log_ignored_receiver(receiver)
        return unless defined?(KantoReloaded::Log)
        label = receiver.class.to_s
        KantoReloaded::Log.debug_once(
          "Ignored misplaced KIF title-screen dispose for #{label}",
          :framework,
          key: "joiplay_dispose_guard:#{label}"
        )
      rescue
        nil
      end

      private

      def joiplay?
        defined?(KantoReloaded::Platform) &&
          KantoReloaded::Platform.respond_to?(:joiplay?) &&
          KantoReloaded::Platform.joiplay?
      end

      def affected_kif_build?
        return false unless defined?(::GenOneStyle)
        !direct_method?(::GenOneStyle, :dispose) &&
          direct_method?(Object, :dispose)
      end

      def promote_title_methods
        TITLE_METHODS.each do |method_name|
          next if direct_method?(::GenOneStyle, method_name)
          next unless direct_method?(Object, method_name)
          implementation = Object.instance_method(method_name)
          ::GenOneStyle.send(:define_method, method_name, implementation)
          ::GenOneStyle.send(:public, method_name)
        end
      end

      def direct_method?(owner, method_name)
        owner.public_instance_methods(false).include?(method_name) ||
          owner.protected_instance_methods(false).include?(method_name) ||
          owner.private_instance_methods(false).include?(method_name)
      end
    end
  end
end

KantoReloaded::JoiPlayDisposeCompatibility.install
