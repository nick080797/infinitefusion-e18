#==============================================================================
# Kanto Reloaded - Regular Mart Reloaded Interface
#==============================================================================

module KantoReloaded
  module ReloadedShop
    module RegularMart
      class << self
        def install
          return true if @installed
          return false unless defined?(KantoReloaded::Hooks)
          @installed = KantoReloaded::Hooks.wrap(
            Object, :pbPokemonMart, :reloaded_regular_mart
          ) do |hook, stock, speech = nil, cantsell = false|
            marked_rld_shop = defined?($game_temp) && $game_temp &&
              $game_temp.respond_to?(:fromkurayshop) &&
              $game_temp.fromkurayshop
            if KantoReloaded::ReloadedShop.regular_mart_reloaded? &&
               !marked_rld_shop
              KantoReloaded::ReloadedShop::RegularMart.open(
                stock, speech, cantsell
              )
            else
              hook.call(stock, speech, cantsell)
            end
          end
          @installed
        rescue StandardError => e
          log_exception("Regular Mart hook failed", e)
          false
        end

        def open(stock, speech = nil, cantsell = false)
          randomized_stock = randomized_shop_stock?
          prepared = prepare_stock(stock, randomized_stock)
          adapter = PokemonMartAdapter.new
          context = KantoReloaded::EconomySystem.regular_shop_context(
            prepared, :randomized_stock => randomized_stock
          )
          prepare_economy_context(context, prepared, adapter)
          rows = [{ :label => _INTL("Buy"), :value => :buy }]
          rows << { :label => _INTL("Sell"), :value => :sell } unless cantsell
          if economy_control_available?
            rows << {
              :label => _INTL("Economy Control"),
              :value => :economy_control
            }
          end
          rows << { :label => _INTL("Quit"), :value => :quit }
          choice = KantoReloaded::PopupWindow.choice(
            speech || _INTL("Welcome! How may I serve you?"), rows
          )
          if choice == :buy
            BuyScene.new(prepared, adapter, {
              :regular_mart => true,
              :shop_label => _INTL("Mart"),
              :mart_event_context => context
            }).main
          elsif choice == :sell
            SellScene.new(prepared, adapter, {
              :regular_mart => true,
              :shop_label => _INTL("Mart")
            }).main
          elsif choice == :economy_control
            AdminControl::EconomyControl.open
          end
          KantoReloaded::PopupWindow.message(_INTL("Please come again!"))
          true
        rescue StandardError => e
          log_exception("Reloaded regular Mart failed", e)
          KantoReloaded::PopupWindow.message(
            _INTL("This Mart could not be opened."), :theme => :error
          )
          false
        ensure
          $game_temp.clear_mart_prices if defined?($game_temp) && $game_temp &&
            $game_temp.respond_to?(:clear_mart_prices)
        end

        def buy_entries(stock, adapter)
          Array(stock).each_with_index.each_with_object([]) do |(item, index), rows|
            data = GameData::Item.try_get(item) rescue nil
            next unless data
            next if data.is_important? && defined?($PokemonBag) &&
              $PokemonBag && $PokemonBag.pbHasItem?(data.id)
            price = adapter.getPrice(item, false).to_i
            category = "pocket_#{data.pocket.to_i}"
            rows << {
              :id => data.id, :runtime_id => item,
              :name => display_name(adapter, item, data),
              :description => data.description.to_s,
              :category => category,
              :category_name => pocket_name(data.pocket),
              :order => index, :buy_price => price,
              :base_buy_price => price, :sell_price => 0,
              :custom_price => false,
              :mart_event_eligible => !data.is_important? || data.is_TM?,
              :important => data.is_important?, :pocket => data.pocket.to_i
            }
          end
        end

        def sell_entries(adapter)
          bag = adapter.getInventory
          return [] unless bag && bag.respond_to?(:pockets)
          rows = []
          bag.pockets.each_with_index do |pocket, pocket_index|
            next if pocket_index <= 0
            Array(pocket).each_with_index do |slot, index|
              item = slot.is_a?(Array) ? slot[0] : slot
              quantity = slot.is_a?(Array) ? slot[1].to_i : adapter.getQuantity(item).to_i
              next if quantity <= 0 || !adapter.canSell?(item)
              data = GameData::Item.try_get(item) rescue nil
              next unless data
              rows << {
                :id => data.id, :runtime_id => item,
                :name => display_name(adapter, item, data),
                :description => data.description.to_s,
                :category => "pocket_#{pocket_index}",
                :category_name => pocket_name(pocket_index),
                :order => index,
                :buy_price => 0,
                :sell_price => adapter.getPrice(item, true).to_i / 2,
                :important => data.is_important?, :pocket => pocket_index
              }
            end
          end
          rows
        rescue StandardError => e
          log_exception("Mart sell inventory failed", e)
          []
        end

        def pocket_name(pocket)
          names = PokemonBag.pocketNames rescue []
          raw = names[pocket.to_i]
          raw = raw[0] if raw.is_a?(Array)
          value = raw.to_s
          value = _INTL("Items") if value.empty?
          value.gsub(/pok[eé]_?balls?/i, "Poke Balls").
            gsub(/tms?_?hms?/i, "TM/HMs").tr("_", " ")
        rescue StandardError
          _INTL("Items")
        end

        private

        def prepare_economy_context(context, stock, adapter)
          return false unless defined?(KantoReloaded::EconomySystem)
          KantoReloaded::EconomySystem.prepare_mart_event_context(
            context, buy_entries(stock, adapter)
          )
          true
        rescue StandardError => e
          log_exception("Mart economy context failed", e)
          false
        end

        def economy_control_available?
          defined?(AdminControl::EconomyControl) &&
            AdminControl::EconomyControl.respond_to?(:open)
        rescue StandardError
          false
        end

        def prepare_stock(stock, randomized = randomized_shop_stock?)
          rows = Array(stock).dup
          if randomized && defined?(replaceShopStockWithRandomized)
            rows = replaceShopStockWithRandomized(rows)
          end
          rows.map! do |item|
            data = GameData::Item.try_get(item) rescue nil
            next nil unless data
            next nil if data.is_important? && defined?($PokemonBag) &&
              $PokemonBag && $PokemonBag.pbHasItem?(data.id)
            data.id
          end
          rows.compact.uniq
        end

        def randomized_shop_stock?
          defined?($game_switches) && $game_switches &&
            defined?(SWITCH_RANDOM_ITEMS_GENERAL) &&
            defined?(SWITCH_RANDOM_SHOP_ITEMS) &&
            $game_switches[SWITCH_RANDOM_ITEMS_GENERAL] &&
            $game_switches[SWITCH_RANDOM_SHOP_ITEMS]
        rescue StandardError
          false
        end

        def display_name(adapter, item, data)
          adapter.getDisplayName(item).to_s
        rescue StandardError
          data.name.to_s
        end

        def log_exception(message, error)
          KantoReloaded::Log.exception(
            message, error, :channel => :reloaded_shop
          ) if defined?(KantoReloaded::Log)
        end
      end
    end

    class SellScene < BuyScene
      private

      def source_rows
        RegularMart.sell_entries(@adapter)
      end

      def empty_message
        _INTL("There is nothing in the Bag that can be sold.")
      end

      def rebuild_pockets(selected_id = nil)
        @mart_event_context = nil
        super
      end

      def sort_entries(rows)
        case SORT_MODES[@sort_index]
        when :price_low
          rows.sort_by { |row| [row[:sell_price].to_i, row[:name].to_s.downcase] }
        when :price_high
          rows.sort_by { |row| [-row[:sell_price].to_i, row[:name].to_s.downcase] }
        when :custom
          rows.sort_by { |row| [row[:order].to_i, row[:name].to_s.downcase] }
        else
          rows.sort_by { |row| row[:name].to_s.downcase }
        end
      end

      def handle_mode_input
        return unless trigger?(:AUX1)
        selected_id = selected_entry && selected_entry[:id]
        pbPlayCursorSE if defined?(pbPlayCursorSE)
        @sort_index = (@sort_index + 1) % SORT_MODES.length
        rebuild_pockets(selected_id)
        snap_quantity
        draw_content
      end

      def purchase_current
        entry = selected_entry
        return buzzer unless entry
        owned = quantity(entry)
        return display_error(_INTL("You don't have any to sell.")) if owned <= 0
        amount = if owned == 1
                   1
                 else
                   KantoReloaded::NumberPicker.quantity(
                     _INTL("Choose Quantity"),
                     :label => entry[:name], :min => 1, :max => owned,
                     :initial => 1, :step => 1, :large_step => 10,
                     :wrap => true, :show_max_label => true,
                     :allow_max_shortcut => true,
                     :unit_price => entry[:sell_price].to_i,
                     :show_unit_price => true,
                     :currency_formatter => proc { |value|
                       _INTL("${1}", formatted(value))
                     },
                     :preview_color => proc { |_total, _quantity| GREEN }
                   )
                 end
        return unless amount && amount > 0
        total = entry[:sell_price].to_i * amount
        return unless KantoReloaded::PopupWindow.confirm(
          _INTL("Sell {1} x{2} for ${3}?", entry[:name], amount,
                formatted(total)), :default => true
        )
        complete_sale(entry, amount, total)
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "Reloaded Mart sale failed", e, :channel => :reloaded_shop
        ) if defined?(KantoReloaded::Log)
        display_error(_INTL("The sale could not be completed."))
      end

      def complete_sale(entry, amount, total)
        return display_error(_INTL("You don't have enough to sell.")) if
          quantity(entry) < amount
        removed = 0
        amount.times do
          break unless @adapter.removeItem(entry[:runtime_id])
          removed += 1
        end
        if removed != amount
          removed.times { @adapter.addItem(entry[:runtime_id]) }
          return display_error(_INTL("The sale could not be completed."))
        end
        @adapter.setMoney(money + total)
        pbSEPlay("Mart buy item") if defined?(pbSEPlay)
        @money_display = money
        rebuild_pockets(entry[:id])
        if @pockets.empty?
          KantoReloaded::PopupWindow.message(_INTL("There is nothing else to sell."))
          @closing = true
        else
          snap_quantity
          draw_content
        end
      end

      def draw_entry_row(bitmap, entry, y, selected)
        name = entry[:name].to_s
        color = selected ? WHITE : GRAY
        price = entry[:sell_price].to_i
        price_text = _INTL("${1}", formatted(price))
        right = SW - PAD - 4
        price_width = bitmap.text_size(price_text).width
        name_width = [right - price_width - PAD - 18, 24].max
        shadow_text(bitmap, PAD + 6, y, name_width, ROW_H,
                    trim_text(bitmap, name, name_width), color)
        shadow_text(bitmap, 0, y, right, ROW_H, price_text,
                    selected ? GOLD : GRAY, 2)
      end

      def hint_entries
        [
          KantoReloaded::HintText.confirm("Sell"),
          KantoReloaded::HintText.back,
          KantoReloaded::HintText.other("Sort: #{sort_label}", :sort)
        ]
      end

      def hint_statuses
        [KantoReloaded::HintText.status("Sort: #{sort_label}", BLUE)]
      end

      def show_hint_popup
        pbPlayDecisionSE if defined?(pbPlayDecisionSE)
        KantoReloaded::HintText.open_popup(
          "Mart Sell Hints", hint_entries, :statuses => hint_statuses
        )
        draw_all
      rescue StandardError
        draw_all
      ensure
        KantoReloaded::UI::Modal.drain_input
      end

      def banner_text
        _INTL("SELL ITEMS")
      end
    end
  end
end
