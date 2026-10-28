#==============================================================================
# Kanto Reloaded - Bulk Purchase Rewards
#==============================================================================
# Shared per-10 rewards for Reloaded Shop and standard KIF marts.
# Standard marts retain their native transaction flow; guarded hooks only track
# successful purchases and replace KIF's single Premier Ball bonus.
#==============================================================================

module KantoReloaded
  module BulkPurchaseRewards
    POTION_REWARD_PURCHASES = [
      :SUPERPOTION,
      :HYPERPOTION,
      :MAXPOTION
    ].freeze

    @native_contexts = []

    class << self
      def reward_for(item, quantity)
        purchased = item_data(item)
        earned = quantity.to_i / 10
        return nil unless purchased && earned > 0
        bonus_id = bonus_id_for(purchased)
        bonus = item_data(bonus_id)
        return nil unless bonus
        {
          :purchased_id => purchased.id,
          :bonus_id => bonus.id,
          :bonus => bonus,
          :earned => earned,
          :awarded => 0
        }
      rescue StandardError
        nil
      end

      def rewardable?(item)
        purchased = item_data(item)
        !!(purchased && bonus_id_for(purchased))
      rescue StandardError
        false
      end

      def preview(item, quantity)
        purchased = item_data(item)
        bonus = item_data(bonus_id_for(purchased))
        return nil unless purchased && bonus
        earned = quantity.to_i / 10
        return _INTL("Bonus: 1 {1} per 10", bonus.name) if earned <= 0
        name = earned == 1 ? bonus.name : bonus.name_plural
        _INTL("Bonus: {1} {2}", earned, name)
      rescue StandardError
        nil
      end

      def append_preview(message, item, quantity)
        text = preview(item, quantity)
        text ? _INTL("{1}\n{2}", message.to_s, text) : message
      rescue StandardError
        message
      end

      def award(adapter, item, quantity)
        reward = reward_for(item, quantity)
        return nil unless reward && adapter && adapter.respond_to?(:addItem)
        awarded = 0
        reward[:earned].times do
          break unless adapter.addItem(reward[:bonus_id])
          awarded += 1
        end
        reward[:awarded] = awarded
        reward
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "Bulk purchase reward failed", e, channel: :modules
        ) if defined?(KantoReloaded::Log)
        reward
      end

      def show_reward(reward)
        return false unless reward && reward[:earned].to_i > 0
        awarded = reward[:awarded].to_i
        earned = reward[:earned].to_i
        bonus = reward[:bonus]
        if awarded >= earned
          name = awarded == 1 ? bonus.name : bonus.name_plural
          text = _INTL("You received {1} {2}.", awarded, name)
          theme = :success
        elsif awarded > 0
          name = earned == 1 ? bonus.name : bonus.name_plural
          text = _INTL(
            "You received {1} of {2} {3}. The Bag is full.",
            awarded, earned, name
          )
          theme = :warning
        else
          name = earned == 1 ? bonus.name : bonus.name_plural
          text = _INTL(
            "The Bag is full, so {1} {2} could not be added.",
            earned, name
          )
          theme = :warning
        end
        if defined?(KantoReloaded::PopupWindow)
          KantoReloaded::PopupWindow.message(text, :theme => theme)
        elsif Kernel.respond_to?(:pbMessage)
          Kernel.pbMessage(text)
        end
        true
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "Bulk purchase reward prompt failed", e, channel: :modules
        ) if defined?(KantoReloaded::Log)
        false
      end

      def install
        return false unless defined?(KantoReloaded::Hooks)
        ready = true
        ready = install_buy_context_hook && ready
        ready = install_item_selection_hook && ready
        ready = install_quantity_hook && ready
        ready = install_confirm_hook && ready
        ready = install_money_hook && ready
        ready = install_add_item_hook && ready
        ready = install_message_hook && ready
        ready
      end

      def begin_native_context(screen)
        context = {
          :screen => screen,
          :scene => screen.instance_variable_get(:@scene),
          :adapter => screen.instance_variable_get(:@adapter),
          :item => nil,
          :quantity => 0,
          :reward => nil,
          :reward_recorded => false,
          :prompt_pending => false,
          :awarding => false,
          :native_bonus_pending => false,
          :skip_native_bonus_message => false
        }
        @native_contexts << context
        context
      end

      def end_native_context(context)
        return unless context
        if @native_contexts.last.equal?(context)
          @native_contexts.pop
        else
          @native_contexts.delete(context)
        end
      end

      def reset_purchase(scene, item)
        context = context_for_scene(scene)
        return unless context
        context[:item] = item
        context[:quantity] = item ? 1 : 0
        context[:reward] = nil
        context[:reward_recorded] = false
        context[:prompt_pending] = false
        context[:awarding] = false
        context[:native_bonus_pending] = false
        context[:skip_native_bonus_message] = false
      end

      def capture_quantity(scene, item, quantity)
        context = context_for_scene(scene)
        return unless context
        context[:item] = item
        context[:quantity] = quantity.to_i
      end

      def record_purchase(adapter)
        context = context_for_adapter(adapter)
        return unless context
        return if context[:awarding] || context[:reward_recorded]
        return unless context[:item] && context[:quantity].to_i > 0
        context[:reward_recorded] = true
        context[:awarding] = true
        begin
          context[:reward] = award(
            adapter, context[:item], context[:quantity]
          )
        ensure
          context[:awarding] = false
        end
        reward = context[:reward]
        return unless reward
        context[:prompt_pending] = true
        context[:native_bonus_pending] =
          reward[:bonus_id] == :PREMIERBALL
      end

      def consume_native_bonus(adapter, item)
        context = context_for_adapter(adapter)
        return [false, nil] unless context
        return [false, nil] if context[:awarding]
        return [false, nil] unless context[:native_bonus_pending]
        return [false, nil] unless item_id(item) == :PREMIERBALL
        context[:native_bonus_pending] = false
        awarded = context[:reward] ? context[:reward][:awarded].to_i : 0
        context[:skip_native_bonus_message] = awarded > 0
        [true, awarded > 0]
      end

      def consume_native_bonus_message(screen)
        context = context_for_screen(screen)
        return false unless context && context[:skip_native_bonus_message]
        context[:skip_native_bonus_message] = false
        true
      end

      def show_pending_reward(screen)
        context = context_for_screen(screen)
        return false unless context && context[:prompt_pending]
        context[:prompt_pending] = false
        show_reward(context[:reward])
      end

      def append_context_preview(screen, message)
        context = context_for_screen(screen)
        return message unless context
        append_preview(message, context[:item], context[:quantity])
      end

      def native_shop_marked?
        defined?($game_temp) && $game_temp &&
          $game_temp.respond_to?(:fromkurayshop) &&
          $game_temp.fromkurayshop
      rescue StandardError
        false
      end

      private

      def bonus_id_for(purchased)
        return nil unless purchased
        return :PREMIERBALL if purchased.is_poke_ball?
        return :DNAREVERSER if purchased.id == :DNASPLICERS
        return :POTION if POTION_REWARD_PURCHASES.include?(purchased.id)
        nil
      end

      def item_data(item)
        return nil unless item && defined?(GameData::Item)
        GameData::Item.try_get(item)
      rescue StandardError
        nil
      end

      def item_id(item)
        data = item_data(item)
        data ? data.id : nil
      end

      def current_context
        @native_contexts.last
      end

      def context_for_screen(screen)
        context = current_context
        context if context && context[:screen].equal?(screen)
      end

      def context_for_scene(scene)
        context = current_context
        context if context && context[:scene].equal?(scene)
      end

      def context_for_adapter(adapter)
        context = current_context
        context if context && context[:adapter].equal?(adapter)
      end

      def install_buy_context_hook
        return false unless defined?(PokemonMartScreen)
        KantoReloaded::Hooks.wrap(
          PokemonMartScreen, :pbBuyScreen, :bulk_rewards_native_buy_context
        ) do |hook, *_arguments|
          if KantoReloaded::BulkPurchaseRewards.native_shop_marked?
            hook.call
          else
            context = KantoReloaded::BulkPurchaseRewards.begin_native_context(self)
            begin
              hook.call
            ensure
              KantoReloaded::BulkPurchaseRewards.end_native_context(context)
            end
          end
        end
      end

      def install_item_selection_hook
        return false unless defined?(PokemonMart_Scene)
        KantoReloaded::Hooks.wrap(
          PokemonMart_Scene, :pbChooseBuyItem,
          :bulk_rewards_native_item_selection
        ) do |hook, *_arguments|
          item = hook.call
          KantoReloaded::BulkPurchaseRewards.reset_purchase(self, item)
          item
        end
      end

      def install_quantity_hook
        return false unless defined?(PokemonMart_Scene)
        KantoReloaded::Hooks.wrap(
          PokemonMart_Scene, :pbChooseNumber, :bulk_rewards_native_quantity
        ) do |hook, helptext, item, maximum|
          quantity = hook.call(helptext, item, maximum)
          KantoReloaded::BulkPurchaseRewards.capture_quantity(
            self, item, quantity
          )
          quantity
        end
      end

      def install_confirm_hook
        return false unless defined?(PokemonMartScreen)
        KantoReloaded::Hooks.wrap(
          PokemonMartScreen, :pbConfirm, :bulk_rewards_native_preview
        ) do |hook, message|
          message = KantoReloaded::BulkPurchaseRewards.append_context_preview(
            self, message
          )
          hook.call(message)
        end
      end

      def install_money_hook
        return false unless defined?(PokemonMartAdapter)
        KantoReloaded::Hooks.wrap(
          PokemonMartAdapter, :setMoney, :bulk_rewards_native_purchase
        ) do |hook, value|
          result = hook.call(value)
          KantoReloaded::BulkPurchaseRewards.record_purchase(self)
          result
        end
      end

      def install_add_item_hook
        return false unless defined?(PokemonMartAdapter)
        KantoReloaded::Hooks.wrap(
          PokemonMartAdapter, :addItem, :bulk_rewards_native_bonus
        ) do |hook, item|
          handled, result =
            KantoReloaded::BulkPurchaseRewards.consume_native_bonus(self, item)
          handled ? result : hook.call(item)
        end
      end

      def install_message_hook
        return false unless defined?(PokemonMartScreen)
        KantoReloaded::Hooks.wrap(
          PokemonMartScreen, :pbDisplayPaused,
          :bulk_rewards_native_message
        ) do |hook, message, &message_block|
          if KantoReloaded::BulkPurchaseRewards.consume_native_bonus_message(self)
            nil
          else
            result = hook.call(message, &message_block)
            KantoReloaded::BulkPurchaseRewards.show_pending_reward(self)
            result
          end
        end
      end
    end
  end
end

KantoReloaded::BulkPurchaseRewards.install
