#===============================================================================
# GhostBroker.rb
# A stock market simulation mod for Kuray Infinite Fusion.
# Version: 1.1.0 - Stability & UI Overhaul (2026-03-23)
#===============================================================================

#===============================================================================
# DATA LAYER & ENGINE
#===============================================================================

class PokemonGlobalMetadata
  attr_accessor :ghost_broker_data
end

module GhostBroker
  COMPANIES = {
    "SLPH" => { name: "Silph Co.",       ticker: "SLPH", tier: 1, base: 10   },
    "DVNC" => { name: "Devon Corp.",     ticker: "DVNC", tier: 1, base: 10   },
    "LYSC" => { name: "Lysandre Labs",   ticker: "LYSC", tier: 2, base: 50   },
    "MCRM" => { name: "Macro Cosmos",    ticker: "MCRM", tier: 2, base: 50   },
    "ATHR" => { name: "Aether Found.",   ticker: "ATHR", tier: 3, base: 250  },
    "RKTC" => { name: "Rocket Holdings", ticker: "RKTC", tier: 3, base: 250  },
    "FLRE" => { name: "Team Flare Inc.", ticker: "FLRE", tier: 4, base: 1000 },
    "GLXY" => { name: "Galactic Energy", ticker: "GLXY", tier: 4, base: 1000 },
    "PKMN" => { name: "Poké Corp Intl.", ticker: "PKMN", tier: 5, base: 2500 },
    "ARCS" => { name: "Arceus Futures",  ticker: "ARCS", tier: 5, base: 2500 }
  }

  TIER_VOLATILITY = { 1 => 0.10, 2 => 0.12, 3 => 0.14, 4 => 0.16, 5 => 0.20 }
  TIER_MAX_PRICE  = { 1 => 100,  2 => 500,  3 => 2500, 4 => 10000, 5 => 25000 }
  TIER_BADGE_THRESHOLDS = { 1 => 2, 2 => 4, 3 => 6, 4 => 8, 5 => 9 }

  def self.data
    return {} unless defined?($PokemonGlobal) && $PokemonGlobal
    if !$PokemonGlobal.ghost_broker_data
      $PokemonGlobal.ghost_broker_data = default_data
    end
    return $PokemonGlobal.ghost_broker_data
  end

  def self.default_data
    {
      "last_tick_day"    => -1,
      "last_tick_time"   => 0,
      "step_accumulator" => 0,
      "portfolio"        => {},
      "companies"        => {},
      "unlocked_tiers"   => [],
      "total_ticks"      => 0
    }
  end

  def self.init
    d = self.data
    return if d.empty? || !d["companies"]
    COMPANIES.each do |id, defn|
      next if d["companies"][id]
      d["companies"][id] = {
        "price"        => defn[:base],
        "history"      => [defn[:base]],
        "phase_type"   => :stagnation,
        "phase_dir"    => 1,
        "phase_ticks"  => 0,
        "phase_length" => rand(3..7),
        "momentum_m"   => 0.0,
        "tier"         => defn[:tier],
        "base_price"   => defn[:base],
        "last_unstable_dir" => 1,
        "tick_history" => []
      }
    end
  end

  # Force init check before accessing companies
  def self.company(id)
    self.init 
    data["companies"][id]
  end

  def self.try_tick!
    d = self.data
    return if d.empty? || !d["companies"]

    now_time = pbGetTimeNow
    current_day = now_time.yday
    now_i = now_time.to_i
    
    is_debug = defined?(ModSettingsMenu) && ModSettingsMenu.get(:ghost_broker_debug) == 1
    dev_mode = defined?(ModSettingsMenu) && ModSettingsMenu.get(:ghost_broker_dev_mode) == 1

    if !is_debug
      if dev_mode
        # Tick every 10 minutes (600 seconds) in-game time (compatible with UnrealTime)
        last_t = d["last_tick_time"] || 0
        return if now_i - last_t < 600
      else
        return if d["last_tick_day"] == current_day
        return if (d["step_accumulator"] || 0) < 1280
      end
    end

    d["last_tick_day"] = current_day
    d["last_tick_time"] = now_i
    d["step_accumulator"] = 0
    tick_all_companies!
  end

  def self.force_tick!
    tick_all_companies!
  end

  def self.simulate_to_30_days!
    return unless data["companies"]
    c = company(COMPANIES.keys.first)
    return unless c
    needed = 30 - c["history"].length
    return if needed <= 0
    needed.times { tick_all_companies! }
  end

  def self.tick_all_companies!
    d = self.data
    d["total_ticks"] ||= 0
    d["total_ticks"] += 1
    unlocked = unlocked_companies
    d["companies"].each do |id, c|
      next unless unlocked.include?(id)

      p_old = c["price"].to_f
      tier = c["tier"]
      base_vol = TIER_VOLATILITY[tier]

      if c["phase_type"] == :reversion
        # Pre-calculated randomized drift
        diff = (c["reversion_steps"] || [])[c["phase_ticks"]] || 0
        if p_old > c["base_price"]
          p_new = [p_old - diff, c["base_price"]].max
        else
          p_new = [p_old + diff, c["base_price"]].min
        end
      else
        v = (rand * 2 * base_vol) - base_vol
        m = 0.0

        if c["phase_type"] == :unstable
          v = base_vol * (1.5 + rand * 2.0) # Spike magnitude 1.5x..3.5x
          if rand < 0.70
            c["last_unstable_dir"] *= -1
          end
          v = c["last_unstable_dir"] * v
          m = 0.0
        elsif c["phase_type"] == :momentum
          v = (rand * 2 * base_vol) - base_vol
          m = c["phase_dir"] * c["momentum_m"] * base_vol
          c["momentum_m"] = [c["momentum_m"] + 0.20, 1.0].min
        else
          v = (rand * 2 * base_vol) - base_vol
          m = 0.0
        end # stagnation is just v, no m

        p_new = p_old * (1.0 + v + m)
      end

      # Apply price, max/min clamps
      p_final = [ [p_new.round, 1].max, TIER_MAX_PRICE[tier] ].min

      c["price"] = p_final
      c["history"] << p_final
      c["history"].shift if c["history"].length > 30

      # Track price change for the ticker (last 7 ticks)
      change = p_final - p_old
      c["tick_history"] ||= []
      c["tick_history"] << { "price" => p_final, "change" => change }
      c["tick_history"].shift if c["tick_history"].length > 7

      c["phase_ticks"] += 1
      if c["phase_ticks"] >= c["phase_length"]
        roll_new_phase(c)
      end
    end
  end

  def self.roll_new_phase(c)
    c["phase_ticks"] = 0
    c["phase_length"] = rand(3..7)
    c["momentum_m"] = 0.0

    r = rand(100)
    if r < 35
      c["phase_type"] = :momentum
      c["phase_dir"] = [-1, 1].sample
    elsif r < 70
      c["phase_type"] = :reversion
      # Distribute total move (5% per tick) randomly across the phase
      total_move = (c["base_price"] * 0.05).round * c["phase_length"]
      diff_to_base = (c["price"] - c["base_price"]).abs
      total_move = [total_move, diff_to_base].min
      
      weights = Array.new(c["phase_length"]) { 0.5 + rand }
      w_sum = weights.sum
      c["reversion_steps"] = weights.map { |w| (w / w_sum * total_move).round }
      # Adjust last step for rounding errors to ensure exact sum
      c["reversion_steps"][-1] += total_move - c["reversion_steps"].sum
    elsif r < 90 || c["tier"] < 3
      c["phase_type"] = :stagnation
    else
      c["phase_type"] = :unstable
      c["last_unstable_dir"] = [-1, 1].sample
    end
  end

  def self.badge_tier
    if defined?(ModSettingsMenu) && ModSettingsMenu.get(:ghost_broker_debug) == 1
      return 5
    end
    return 0 unless defined?($Trainer) && $Trainer
    badges = $Trainer.badge_count
    tier = 0
    TIER_BADGE_THRESHOLDS.each { |t, b| tier = t if badges >= b }
    
    if defined?($PokemonGlobal) && $PokemonGlobal.respond_to?(:hallOfFameLastNumber) && $PokemonGlobal.hallOfFameLastNumber > 0
      tier = 5
    end
    
    return tier
  end

  def self.max_slots
    return 10 unless defined?($Trainer) && $Trainer
    badges = $Trainer.badge_count
    slots = 10
    slots += [badges - 2, 6].min * 2 if badges > 2
    
    if badges >= 9 || (defined?($PokemonGlobal) && $PokemonGlobal.respond_to?(:hallOfFameLastNumber) && $PokemonGlobal.hallOfFameLastNumber > 0)
      slots += 2 
    end
    
    return [[slots, 10].max, 24].min
  end

  def self.used_slots
    return 0 if self.data.empty?
    self.data["portfolio"].values.map { |h| h["qty"] }.sum
  end

  def self.unlocked_companies
    tier = badge_tier
    COMPANIES.select { |id, defn| defn[:tier] <= tier }.keys
  end

  def self.can_buy?(company_id)
    c = company(company_id)
    return false unless c
    return c["price"] >= c["base_price"]
  end

  def self.buy_shares(id, qty)
    return false if qty <= 0
    c = company(id)
    cost = c["price"] * qty
    return false unless defined?($Trainer) && $Trainer
    return false if $Trainer.money < cost
    return false if used_slots + qty > max_slots

    $Trainer.money -= cost
    pf = data["portfolio"]
    pf[id] ||= { "qty" => 0, "avg_cost" => 0.0 }
    
    old_q = pf[id]["qty"]
    old_c = pf[id]["avg_cost"]
    
    new_q = old_q + qty
    new_c = ((old_q * old_c) + cost) / new_q.to_f
    
    pf[id]["qty"] = new_q
    pf[id]["avg_cost"] = new_c
    return true
  end

  def self.sell_shares(id, qty)
    return false if qty <= 0
    pf = data["portfolio"]
    return false unless pf[id] && pf[id]["qty"] >= qty

    c = company(id)
    revenue = c["price"] * qty
    
    return false unless defined?($Trainer) && $Trainer
    $Trainer.money += revenue
    pf[id]["qty"] -= qty
    pf.delete(id) if pf[id]["qty"] == 0
    return revenue
  end
end

EventHandlers.add(:on_load_save_file, :ghost_broker_init) do |save_data|
  GhostBroker.init
end if defined?(EventHandlers)

# Run once during script load for hot-reload/late install
GhostBroker.init

#===============================================================================
# MOD SETTINGS
#===============================================================================

module GhostBroker
  def self.register_settings
    return unless defined?(ModSettingsMenu)

    unless ModSettingsMenu.categories.any? { |c| c[:name] == "Ghost Settings" }
      ModSettingsMenu.categories << {
        name: "Ghost Settings",
        priority: 85,
        description: "Settings for GhostXYZ mods",
        collapsed: true
      }
    end

    ModSettingsMenu.register(:ghost_broker_enabled, {
      name: "Poké-Broker: Enabled",
      type: :enum,
      category: "Ghost Settings",
      save_key: "ghost_broker_enabled",
      values: ["Yes", "No"],
      default: 0,
      description: "Enable/disable the Poké-Broker stock market mod."
    })

    ModSettingsMenu.register(:ghost_broker_debug, {
      name: "Poké-Broker: Debug",
      type: :enum,
      category: "Ghost Settings",
      save_key: "ghost_broker_debug",
      values: ["Off", "On"],
      default: 0,
      description: "Debug mode: force-tick on demand, unlock all tiers."
    })

    ModSettingsMenu.register(:ghost_broker_dev_mode, {
      name: "Broker: Dev Mode",
      type: :enum,
      category: "Ghost Settings",
      save_key: "ghost_broker_dev_mode",
      values: ["Off", "On"],
      default: 0,
      description: "When enabled, stocks tick every 30 in-game minutes regardless of steps."
    })
  end
end

# Initialize if ModSettingsMenu is available. If not, queue for when it loads.
if defined?(ModSettingsMenu)
  GhostBroker.register_settings
else
  $MOD_SETTINGS_PENDING_REGISTRATIONS ||= []
  $MOD_SETTINGS_PENDING_REGISTRATIONS << proc { GhostBroker.register_settings }
end


#===============================================================================
# PC HOOK
#===============================================================================

class BrokerPC
  def shouldShow?
    if defined?(ModSettingsMenu)
      val = ModSettingsMenu.get(:ghost_broker_enabled)
      return false if val == 1
    end
    return false unless defined?($Trainer) && $Trainer
    return GhostBroker.badge_tier >= 1 
  end

  def name
    return _INTL("Poké-Broker")
  end

  def access
    pbMessage(_INTL("\\se[PC access]Connecting to the Poké-Broker network..."))
    pbFadeOutIn {
      scene = BrokerDashboard_Scene.new
      scene.main
    }
  end
end

PokemonPCList.registerPC(BrokerPC.new)



#===============================================================================
# UI
#===============================================================================

class BrokerDashboard_Scene
  BG_DARK       = Color.new(12, 14, 22, 240)
  PANEL_BASE    = Color.new(28, 32, 48)
  PANEL_LITE    = Color.new(34, 38, 56)
  PANEL_BORDER  = Color.new(31, 177, 196)
  ACCENT_DIM    = Color.new(31, 177, 196, 80)
  TEXT_PRIMARY  = Color.new(230, 235, 245)
  TEXT_SHADOW   = Color.new(15, 15, 25)
  TEXT_SEC      = Color.new(140, 148, 168)
  TEXT_GAIN     = Color.new(80, 220, 120)
  TEXT_LOSS     = Color.new(240, 80, 90)
  TEXT_LOCKED   = Color.new(200, 60, 60)
  TEXT_WARN     = Color.new(255, 200, 40)
  ROW_HOVER     = Color.new(35, 40, 58)
  GRAPH_BG      = Color.new(18, 20, 28)
  GRAPH_GRID    = Color.new(40, 44, 60, 100)
  GRAPH_DOT     = Color.new(255, 255, 255, 200)

  TICK_SE = "GUI sel decision"
  W = 512; H = 384  # target resolution

  def main
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    @company_ids = GhostBroker.unlocked_companies
    @cursor_idx = 0
    @list_top = 0
    @tick_flash = 0
    @page = :market  # :market or :portfolio
    @pf_cursor = 0
    @pf_top = 0
    @exit_scene = false

    # Background
    @sprites["bg"] = Sprite.new(@viewport)
    @sprites["bg"].bitmap = Bitmap.new(W, H)
    @sprites["bg"].bitmap.fill_rect(0, 0, W, H, BG_DARK)

    # Header bar
    @sprites["header"] = Sprite.new(@viewport)
    @sprites["header"].bitmap = Bitmap.new(W, 30)

    # Footer bar
    @sprites["footer"] = Sprite.new(@viewport)
    @sprites["footer"].bitmap = Bitmap.new(W, 32)
    @sprites["footer"].y = H - 32

    # Main content area (full width, used by both pages)
    @content_y = 30; @content_h = H - 62
    @sprites["content"] = Sprite.new(@viewport)
    @sprites["content"].bitmap = Bitmap.new(W, @content_h)
    @sprites["content"].y = @content_y

    # Trading overlay
    @trading = false
    @sprites["overlay"] = Sprite.new(@viewport)
    @sprites["overlay"].bitmap = Bitmap.new(W, H)
    @sprites["overlay"].bitmap.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 180))
    @sprites["overlay"].visible = false
    @sprites["overlay"].z = 10

    @sprites["dialog"] = Sprite.new(@viewport)
    @sprites["dialog"].bitmap = Bitmap.new(300, 200)
    @sprites["dialog"].ox = 150; @sprites["dialog"].oy = 100
    @sprites["dialog"].x = W / 2; @sprites["dialog"].y = H / 2
    @sprites["dialog"].visible = false
    @sprites["dialog"].z = 11

    GhostBroker.init
    GhostBroker.simulate_to_30_days!
    GhostBroker.try_tick!
    @last_tick_count = GhostBroker.data["total_ticks"] || 0

    refresh_all

    until @exit_scene
      Graphics.update
      $PokemonGlobal.addNewFrameCount if defined?($PokemonGlobal) && $PokemonGlobal.respond_to?(:addNewFrameCount)
      Input.update

      @tick_flash -= 1 if @tick_flash > 0

      # Poll for market ticks
      if Graphics.frame_count % 20 == 0
        GhostBroker.try_tick!
        sig = GhostBroker.data["total_ticks"] || 0
        if sig != @last_tick_count
          @last_tick_count = sig
          @tick_flash = 30
          pbSEPlay(TICK_SE, 60, 110) if !@trading
          refresh_all
        end
        refresh_header if Graphics.frame_count % 60 == 0
      end

      if @trading
        update_trade_input
      elsif @page == :market
        update_market_input
      else
        update_portfolio_input
      end
    end

    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end

  def refresh_all
    refresh_header
    refresh_footer
    refresh_content
  end

  def refresh_content
    @page == :market ? refresh_market : refresh_portfolio
  end

  # =========================================================================
  # HELPERS
  # =========================================================================
  def draw_panel(bmp, x, y, w, h)
    bmp.fill_rect(x, y, w, h, PANEL_BASE)
    bmp.fill_rect(x, y, w, 1, PANEL_BORDER)
    bmp.fill_rect(x, y + h - 1, w, 1, PANEL_BORDER)
    bmp.fill_rect(x, y, 1, h, PANEL_BORDER)
    bmp.fill_rect(x + w - 1, y, 1, h, PANEL_BORDER)
  end

  def fmtn(n)
    n.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse
  end

  def calc_holdings_value
    pf = GhostBroker.data["portfolio"]
    total = 0
    pf.each { |id, h| c = GhostBroker.company(id); total += c["price"] * h["qty"] if c }
    total
  end

  def calc_total_cost
    pf = GhostBroker.data["portfolio"]
    total = 0.0
    pf.each { |id, h| total += h["avg_cost"] * h["qty"] }
    total
  end

  # =========================================================================
  # HEADER  - single clean row
  # =========================================================================
  def refresh_header
    b = @sprites["header"].bitmap; b.clear
    return if !b || b.disposed?
    b.fill_rect(0, 0, W, 29, PANEL_BASE)
    b.fill_rect(0, 29, W, 1, ACCENT_DIM)
    pbSetSmallFont(b)

    # Tab indicators
    mkt_c = @page == :market   ? PANEL_BORDER : TEXT_SEC
    pfl_c = @page == :portfolio ? PANEL_BORDER : TEXT_SEC
    pbDrawShadowText(b, 10, 7, 60, 16, "Market", mkt_c, TEXT_SHADOW)
    pbDrawShadowText(b, 75, 7, 70, 16, "Portfolio", pfl_c, TEXT_SHADOW)
    if @page == :market
      b.fill_rect(10, 24, 50, 2, PANEL_BORDER)
    else
      b.fill_rect(75, 24, 62, 2, PANEL_BORDER)
    end

    # Money
    mny = defined?($Trainer) && $Trainer ? $Trainer.money : 0
    pbDrawShadowText(b, 200, 7, 120, 16, "$#{fmtn(mny)}", TEXT_GAIN, TEXT_SHADOW, 2)

    # Slots
    pbDrawShadowText(b, 330, 7, 80, 16, "#{GhostBroker.used_slots}/#{GhostBroker.max_slots} Slots", TEXT_PRIMARY, TEXT_SHADOW, 2)

    # Time
    now = pbGetTimeNow
    time_str = now.strftime("%I:%M%p").downcase
    time_str = time_str[1..-1] if time_str[0, 1] == "0"
    pbDrawShadowText(b, W - 80, 7, 72, 16, time_str, TEXT_SEC, TEXT_SHADOW, 2)
  end

  # =========================================================================
  # FOOTER
  # =========================================================================
  def refresh_footer
    b = @sprites["footer"].bitmap; b.clear
    return if !b || b.disposed?
    b.fill_rect(0, 0, W, 1, ACCENT_DIM)
    pbSetSmallFont(b)
    if @page == :market
      txt = "D-Pad: Navigate   C: Trade   L/R: Portfolio   B: Exit"
      txt += "   A: Tick" if defined?(ModSettingsMenu) && ModSettingsMenu.get(:ghost_broker_debug) == 1
    else
      txt = "D-Pad: Navigate   L/R: Market   B: Exit"
    end
    pbDrawShadowText(b, 0, 0, W, 32, txt, TEXT_SEC, TEXT_SHADOW, 1)
  end

  # =========================================================================
  # MARKET PAGE
  # =========================================================================
  def refresh_market
    b = @sprites["content"].bitmap; b.clear
    return if !b || b.disposed?
    ch = @content_h
    list_w = 190; det_x = list_w + 6; det_w = W - det_x - 4

    # -- Left: company list --
    draw_panel(b, 0, 0, list_w, ch)
    pbSetSmallFont(b)
    row_h = 28; start_y = 6
    max_vis = (ch - 12) / row_h

    max_vis.times do |i|
      idx = @list_top + i
      break if idx >= @company_ids.length
      id = @company_ids[idx]
      c = GhostBroker.company(id); next unless c
      # No longer need defn here as tier label was removed
      yp = start_y + i * row_h

      if idx == @cursor_idx
        b.fill_rect(1, yp, list_w - 2, row_h, ROW_HOVER)
        b.fill_rect(1, yp, 3, row_h, PANEL_BORDER)
      end

      tc = idx == @cursor_idx ? PANEL_BORDER : TEXT_PRIMARY

      # Ticker
      pbDrawShadowText(b, 10, yp + 6, 50, 16, id, tc, TEXT_SHADOW)

      # Price (right-aligned)
      pbDrawShadowText(b, 62, yp + 6, 80, 16, "$#{fmtn(c["price"])}", TEXT_PRIMARY, TEXT_SHADOW, 2)

      # Trend arrow
      if c["history"].length > 1
        prev = c["history"][-2]; curr = c["history"].last
        if curr > prev
          pbDrawShadowText(b, list_w - 26, yp + 6, 16, 16, "+", TEXT_GAIN, TEXT_SHADOW, 1)
        elsif curr < prev
          pbDrawShadowText(b, list_w - 26, yp + 6, 16, 16, "-", TEXT_LOSS, TEXT_SHADOW, 1)
        end
      end
    end

    # -- Right: detail panel --
    draw_panel(b, det_x, 0, det_w, ch)
    return if @company_ids.empty?
    id = @company_ids[@cursor_idx]
    c = GhostBroker.company(id); return unless c
    defn = GhostBroker::COMPANIES[id]
    dx = det_x + 8; dw = det_w - 16

    # -- Company Title --
    pbSetSystemFont(b)
    pbDrawShadowText(b, dx, 2, dw, 30, defn[:name], TEXT_PRIMARY, TEXT_SHADOW)
    pbSetSmallFont(b)
    pbDrawShadowText(b, dx + dw - 60, 2, 60, 30, "Tier #{defn[:tier]}", PANEL_BORDER, TEXT_SHADOW, 2)

    # -- Price Row --
    price_color = TEXT_PRIMARY
    if @tick_flash > 0 && c["history"].length > 1
      price_color = c["history"].last >= c["history"][-2] ? TEXT_GAIN : TEXT_LOSS
    end
    pbDrawShadowText(b, dx, 24, 100, 24, "$#{fmtn(c["price"])}", price_color, TEXT_SHADOW)

    # Change %
    if c["history"].length > 1
      prev = c["history"][-2]; curr = c["history"].last
      diff = curr - prev
      pct = prev == 0 ? 0 : (diff.to_f / prev * 100).round(1)
      sign = diff >= 0 ? "+" : ""
      cp = diff > 0 ? TEXT_GAIN : (diff < 0 ? TEXT_LOSS : TEXT_SEC)
      pbDrawShadowText(b, dx + 100, 24, 80, 24, "#{sign}#{pct}%", cp, TEXT_SHADOW)
    end

    # Base price label (right side of price row)
    pbDrawShadowText(b, dx + dw - 80, 24, 80, 24, "Base: $#{fmtn(defn[:base])}", TEXT_SEC, TEXT_SHADOW, 2)

    # -- Graph --
    gy = 48; gh = 40; gx = dx; gw = dw
    b.fill_rect(gx, gy, gw, gh, GRAPH_BG)
    b.fill_rect(gx, gy, gw, 1, GRAPH_GRID)
    b.fill_rect(gx, gy + gh - 1, gw, 1, GRAPH_GRID)
    draw_graph(b, gx + 2, gy + 2, gw - 4, gh - 4, c["history"])

    # High/Low labels inside graph
    if c["history"].length >= 2
      hi = c["history"].max; lo = c["history"].min
      lbl_c = Color.new(255, 255, 255, 100); lbl_s = Color.new(0, 0, 0, 60)
      # Temporarily shrink font
      old_fs = b.font.size
      b.font.size -= 2
      pbDrawShadowText(b, gx + 4, gy - 4, 60, 24, "#{hi}", lbl_c, lbl_s)
      pbDrawShadowText(b, gx + 4, gy + gh - 24, 60, 24, "#{lo}", lbl_c, lbl_s)
      b.font.size = old_fs
    end

    # -- Info section below graph --
    iy = gy + gh + 4

    # -- Price Ticker --
    if c["tick_history"] && !c["tick_history"].empty?
      pbDrawShadowText(b, dx, iy - 4, dw, 24, "Price History (Last 7 Ticks)", TEXT_SEC, TEXT_SHADOW)
      iy += 18
      history_ticks = c["tick_history"].reverse.first(7)
      
      # Pass 1: Row Backgrounds
      history_ticks.each_with_index do |data, idx|
        row_y = iy + idx * 19
        b.fill_rect(dx, row_y, dw, 18, PANEL_LITE) if idx % 2 == 0
      end
      
      # Pass 2: Row Content
      history_ticks.each_with_index do |data, idx|
        row_y = iy + idx * 19
        price = data["price"]; chg = data["change"]
        color = chg > 0 ? TEXT_GAIN : (chg < 0 ? TEXT_LOSS : TEXT_SEC)
        sign = chg > 0 ? "+" : ""
        
        # Price
        pbDrawShadowText(b, dx + 4, row_y - 4, 80, 24, "$#{fmtn(price)}", TEXT_PRIMARY, TEXT_SHADOW)
        
        # Change + Pct
        old_p = price - chg
        pct = old_p == 0 ? 0 : (chg.to_f / old_p * 100).round(1)
        pct_sign = pct > 0 ? "+" : ""
        pbDrawShadowText(b, dx + 70, row_y - 4, dw - 74, 24, "#{sign}#{fmtn(chg)} (#{pct_sign}#{pct}%)", color, TEXT_SHADOW, 2)
      end
      iy += 7 * 19 + 4
    end

    # Status warnings
    if c["phase_type"] == :unstable
      b.fill_rect(dx, iy, dw, 16, Color.new(60, 30, 10, 160))
      pbDrawShadowText(b, dx, iy - 4, dw, 24, "!! UNSTABLE - HIGH VOLATILITY !!", TEXT_WARN, TEXT_SHADOW, 1)
      iy += 18
    end
    if !GhostBroker.can_buy?(id)
      b.fill_rect(dx, iy, dw, 16, Color.new(60, 10, 10, 160))
      pbDrawShadowText(b, dx, iy - 4, dw, 24, "Buy Locked - Below Base Price", TEXT_LOCKED, TEXT_SHADOW, 1)
      iy += 18
    end

    # -- Holdings Info --
    pf = GhostBroker.data["portfolio"][id]
    if pf && pf["qty"] > 0
      # Separator
      b.fill_rect(dx, ch - 46, dw, 1, ACCENT_DIM)
      pbDrawShadowText(b, dx, ch - 46, 80, 24, "Your Position", PANEL_BORDER, TEXT_SHADOW)

      # Row 1: Shares + Avg Cost
      pbDrawShadowText(b, dx, ch - 38, dw / 2, 24,
        "#{pf["qty"]} shares", TEXT_PRIMARY, TEXT_SHADOW)
      pbDrawShadowText(b, dx + dw / 2, ch - 38, dw / 2, 24,
        "Avg: $#{fmtn(pf["avg_cost"].to_i)}", TEXT_SEC, TEXT_SHADOW, 2)

      # Row 2: Total Value + P/L
      value = (c["price"] * pf["qty"]).to_i
      pl = (c["price"] - pf["avg_cost"]) * pf["qty"]
      pl_color = pl >= 0 ? TEXT_GAIN : TEXT_LOSS
      sign = pl >= 0 ? "+" : ""
      pbDrawShadowText(b, dx, ch - 22, dw / 2, 24,
        "Val: $#{fmtn(value)}", TEXT_PRIMARY, TEXT_SHADOW)
      pbDrawShadowText(b, dx + dw / 2, ch - 22, dw / 2, 24,
        "P/L: #{sign}$#{fmtn(pl.to_i.abs)}", pl_color, TEXT_SHADOW, 2)
    else
      # No holdings - show a hint
      b.fill_rect(dx, ch - 26, dw, 1, ACCENT_DIM)
      pbDrawShadowText(b, dx, ch - 26, dw, 24, "No position - Press C to trade", TEXT_SEC, TEXT_SHADOW, 1)
    end
  end

  # =========================================================================
  # PORTFOLIO PAGE
  # =========================================================================
  def refresh_portfolio
    b = @sprites["content"].bitmap; b.clear
    return if !b || b.disposed?
    ch = @content_h
    draw_panel(b, 0, 0, W, ch)
    pbSetSmallFont(b)

    pf = GhostBroker.data["portfolio"]
    held_ids = pf.keys.select { |id| pf[id]["qty"] > 0 }

    if held_ids.empty?
      pbSetSystemFont(b)
      pbDrawShadowText(b, 0, ch / 2 - 12, W, 24, "No holdings yet!", TEXT_SEC, TEXT_SHADOW, 1)
      pbSetSmallFont(b)
      pbDrawShadowText(b, 0, ch / 2 + 14, W, 16, "Go to Market and buy some shares.", TEXT_SEC, TEXT_SHADOW, 1)
      return
    end

    # Column headers
    hdr_y = 6
    b.fill_rect(4, hdr_y, W - 8, 18, PANEL_LITE)
    pbDrawShadowText(b, 12, hdr_y + 1, 50, 16, "Stock", TEXT_SEC, TEXT_SHADOW)
    pbDrawShadowText(b, 68, hdr_y + 1, 32, 16, "Qty", TEXT_SEC, TEXT_SHADOW, 2)
    pbDrawShadowText(b, 108, hdr_y + 1, 70, 16, "Avg Cost", TEXT_SEC, TEXT_SHADOW, 2)
    pbDrawShadowText(b, 186, hdr_y + 1, 70, 16, "Price", TEXT_SEC, TEXT_SHADOW, 2)
    pbDrawShadowText(b, 264, hdr_y + 1, 80, 16, "Value", TEXT_SEC, TEXT_SHADOW, 2)
    pbDrawShadowText(b, 352, hdr_y + 1, 70, 16, "P/L", TEXT_SEC, TEXT_SHADOW, 2)
    pbDrawShadowText(b, 430, hdr_y + 1, 60, 16, "P/L %", TEXT_SEC, TEXT_SHADOW, 2)

    row_h = 26; start_y = 28
    total_value = 0; total_cost = 0.0

    held_ids.each_with_index do |id, i|
      h = pf[id]; c = GhostBroker.company(id); next unless c
      yp = start_y + i * row_h
      break if yp + row_h > ch - 34  # leave room for totals

      value = c["price"] * h["qty"]
      cost = h["avg_cost"] * h["qty"]
      pl = value - cost
      pl_pct = cost > 0 ? (pl / cost * 100).round(1) : 0
      total_value += value; total_cost += cost

      if i == @pf_cursor
        b.fill_rect(1, yp, W - 2, row_h, ROW_HOVER)
        b.fill_rect(1, yp, 3, row_h, PANEL_BORDER)
      end

      tc = i == @pf_cursor ? PANEL_BORDER : TEXT_PRIMARY
      pl_color = pl >= 0 ? TEXT_GAIN : TEXT_LOSS
      sign = pl >= 0 ? "+" : ""

      pbDrawShadowText(b, 12, yp + 5, 50, 16, id, tc, TEXT_SHADOW)
      pbDrawShadowText(b, 68, yp + 5, 32, 16, "#{h["qty"]}", TEXT_PRIMARY, TEXT_SHADOW, 2)
      pbDrawShadowText(b, 108, yp + 5, 70, 16, "$#{fmtn(h["avg_cost"].to_i)}", TEXT_SEC, TEXT_SHADOW, 2)
      pbDrawShadowText(b, 186, yp + 5, 70, 16, "$#{fmtn(c["price"])}", TEXT_PRIMARY, TEXT_SHADOW, 2)
      pbDrawShadowText(b, 264, yp + 5, 80, 16, "$#{fmtn(value)}", TEXT_PRIMARY, TEXT_SHADOW, 2)
      pbDrawShadowText(b, 352, yp + 5, 70, 16, "#{sign}$#{fmtn(pl.to_i.abs)}", pl_color, TEXT_SHADOW, 2)
      pbDrawShadowText(b, 430, yp + 5, 60, 16, "#{sign}#{pl_pct}%", pl_color, TEXT_SHADOW, 2)
    end

    # Totals bar
    total_pl = total_value - total_cost
    total_pct = total_cost > 0 ? (total_pl / total_cost * 100).round(1) : 0
    pl_color = total_pl >= 0 ? TEXT_GAIN : TEXT_LOSS
    sign = total_pl >= 0 ? "+" : ""

    b.fill_rect(4, ch - 28, W - 8, 1, ACCENT_DIM)
    pbDrawShadowText(b, 12, ch - 24, 100, 16, "Total", TEXT_PRIMARY, TEXT_SHADOW)
    pbDrawShadowText(b, 264, ch - 24, 80, 16, "$#{fmtn(total_value)}", TEXT_PRIMARY, TEXT_SHADOW, 2)
    pbDrawShadowText(b, 352, ch - 24, 70, 16, "#{sign}$#{fmtn(total_pl.to_i.abs)}", pl_color, TEXT_SHADOW, 2)
    pbDrawShadowText(b, 430, ch - 24, 60, 16, "#{sign}#{total_pct}%", pl_color, TEXT_SHADOW, 2)
  end

  # =========================================================================
  # INPUT HANDLERS
  # =========================================================================
  def update_market_input
    if Input.trigger?(Input::UP)
      @cursor_idx = (@cursor_idx - 1) % @company_ids.length
      adjust_list_scroll
      pbSEPlay("GUI sel cursor", 80, 100)
      refresh_content
    elsif Input.trigger?(Input::DOWN)
      @cursor_idx = (@cursor_idx + 1) % @company_ids.length
      adjust_list_scroll
      pbSEPlay("GUI sel cursor", 80, 100)
      refresh_content
    elsif Input.trigger?(Input::C)
      start_trade(@company_ids[@cursor_idx])
    elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
      @page = :portfolio; @pf_cursor = 0
      pbSEPlay("GUI sel cursor", 80, 100)
      refresh_all
    elsif Input.trigger?(Input::A) && defined?(ModSettingsMenu) && ModSettingsMenu.get(:ghost_broker_debug) == 1
      GhostBroker.force_tick!
      @tick_flash = 30
      pbSEPlay(TICK_SE, 60, 110)
      refresh_all
    elsif Input.trigger?(Input::B)
      pbSEPlay("PC close"); @exit_scene = true
    end
  end

  def update_portfolio_input
    pf = GhostBroker.data["portfolio"]
    held_ids = pf.keys.select { |id| pf[id]["qty"] > 0 }
    if Input.trigger?(Input::UP) && held_ids.length > 0
      @pf_cursor = (@pf_cursor - 1) % held_ids.length
      pbSEPlay("GUI sel cursor", 80, 100)
      refresh_content
    elsif Input.trigger?(Input::DOWN) && held_ids.length > 0
      @pf_cursor = (@pf_cursor + 1) % held_ids.length
      pbSEPlay("GUI sel cursor", 80, 100)
      refresh_content
    elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
      @page = :market
      pbSEPlay("GUI sel cursor", 80, 100)
      refresh_all
    elsif Input.trigger?(Input::B)
      pbSEPlay("PC close"); @exit_scene = true
    end
  end

  def adjust_list_scroll
    max_visible = (@content_h - 12) / 28
    if @cursor_idx < @list_top
      @list_top = @cursor_idx
    elsif @cursor_idx >= @list_top + max_visible
      @list_top = @cursor_idx - max_visible + 1
      @list_top = 0 if @list_top < 0
    end
  end

  # =========================================================================
  # GRAPH
  # =========================================================================
  def draw_graph(bmp, x, y, w, h, history)
    return if !history || history.empty?
    min_p = history.min.to_f; max_p = history.max.to_f
    pad = [(max_p - min_p) * 0.15, 1].max
    min_p -= pad; max_p += pad
    range = [max_p - min_p, 1].max

    # Grid
    3.times do |g|
      pct = (g + 1) * 0.25
      gy = y + (h * (1.0 - pct)).to_i
      bmp.fill_rect(x, gy, w, 1, GRAPH_GRID)
    end

    color = history.last >= history.first ? TEXT_GAIN : TEXT_LOSS

    if history.length == 1
      py = y + h - ((history[0] - min_p) / range * h).to_i
      py = [[py, y + 2].max, y + h - 3].min
      bmp.fill_rect(x, py, w, 2, color)
      bmp.fill_rect(x + w / 2 - 2, py - 2, 5, 5, GRAPH_DOT)
      return
    end

    step_x = w.to_f / (history.length - 1)

    # Fill area
    fill_c = Color.new(color.red, color.green, color.blue, 25)
    history.each_with_index do |price, i|
      next if i >= history.length - 1
      px = x + (i * step_x).to_i
      npx = x + ((i + 1) * step_x).to_i
      py = y + h - ((price - min_p) / range * h).to_i
      py = [[py, y].max, y + h - 1].min
      npy = y + h - ((history[i + 1] - min_p) / range * h).to_i
      npy = [[npy, y].max, y + h - 1].min
      avg = (py + npy) / 2
      bw = [npx - px, x + w - px].min
      bmp.fill_rect(px, avg, bw, y + h - avg, fill_c) if bw > 0
    end

    # Lines
    history.each_with_index do |price, i|
      next if i == 0
      px = x + (i * step_x).to_i
      py = y + h - ((price - min_p) / range * h).to_i
      py = [[py, y].max, y + h - 1].min
      ppx = x + ((i - 1) * step_x).to_i
      ppy = y + h - ((history[i - 1] - min_p) / range * h).to_i
      ppy = [[ppy, y].max, y + h - 1].min
      draw_line_seg(bmp, ppx, ppy, px, py, color)
    end

    # Dots
    history.each_with_index do |price, i|
      px = x + (i * step_x).to_i
      py = y + h - ((price - min_p) / range * h).to_i
      py = [[py, y].max, y + h - 1].min
      sz = i == history.length - 1 ? 3 : 2
      bmp.fill_rect(px - sz / 2, py - sz / 2, sz, sz, GRAPH_DOT)
    end
  end

  def draw_line_seg(bmp, x0, y0, x1, y1, color)
    dx = (x1 - x0).abs; dy = (y1 - y0).abs
    sx = x0 < x1 ? 1 : -1; sy = y0 < y1 ? 1 : -1
    err = dx - dy; steps = 0; limit = dx + dy + 2
    loop do
      bmp.fill_rect(x0, y0, 2, 2, color)
      break if x0 == x1 && y0 == y1
      steps += 1; break if steps > limit
      e2 = 2 * err
      if e2 > -dy; err -= dy; x0 += sx; end
      if e2 < dx; err += dx; y0 += sy; end
    end
  end

  # =========================================================================
  # TRADE OVERLAY
  # =========================================================================
  def start_trade(id)
    @trade_id = id
    @trade_c = GhostBroker.company(id)
    @trade_mode = :select
    @trade_qty = 0
    @trade_options = ["Buy", "Sell", "Cancel"]
    @trade_opt_idx = 0
    @sprites["overlay"].visible = true
    @sprites["dialog"].visible = true
    @trading = true
    refresh_dialog
  end

  def update_trade_input
    if @trade_mode == :select
      if Input.trigger?(Input::LEFT)
        @trade_opt_idx = (@trade_opt_idx - 1) % 3
        pbSEPlay("GUI sel cursor", 80, 100); refresh_dialog
      elsif Input.trigger?(Input::RIGHT)
        @trade_opt_idx = (@trade_opt_idx + 1) % 3
        pbSEPlay("GUI sel cursor", 80, 100); refresh_dialog
      elsif Input.trigger?(Input::B)
        close_trade
      elsif Input.trigger?(Input::C)
        case @trade_opt_idx
        when 0
          if !GhostBroker.can_buy?(@trade_id); pbPlayBuzzerSE; return; end
          @trade_mode = :buy; @trade_qty = 1
        when 1
          pf = GhostBroker.data["portfolio"][@trade_id]
          if !pf || pf["qty"] <= 0; pbPlayBuzzerSE; return; end
          @trade_mode = :sell; @trade_qty = 1
        when 2; close_trade; return
        end
        pbSEPlay("GUI sel cursor", 80, 100); refresh_dialog
      end
    else
      max = if @trade_mode == :buy
        slots = GhostBroker.max_slots - GhostBroker.used_slots
        price = @trade_c["price"]
        mm = price > 0 ? $Trainer.money / price : 0
        [slots, mm].min
      else
        pf = GhostBroker.data["portfolio"][@trade_id]
        pf ? pf["qty"] : 0
      end
      max = [max, 0].max

      if Input.trigger?(Input::B)
        @trade_mode = :select; pbSEPlay("GUI sel cursor", 80, 100); refresh_dialog
      elsif Input.trigger?(Input::LEFT) || Input.repeat?(Input::LEFT)
        @trade_qty = [@trade_qty - 1, 1].max; refresh_dialog
      elsif Input.trigger?(Input::RIGHT) || Input.repeat?(Input::RIGHT)
        @trade_qty = [@trade_qty + 1, max].min; refresh_dialog
      elsif Input.trigger?(Input::UP) || Input.repeat?(Input::UP)
        @trade_qty = [@trade_qty + 10, max].min; refresh_dialog
      elsif Input.trigger?(Input::DOWN) || Input.repeat?(Input::DOWN)
        @trade_qty = [@trade_qty - 10, 1].max; refresh_dialog
      elsif Input.trigger?(Input::A)
        @trade_qty = [max, 1].max; pbSEPlay("GUI sel cursor", 80, 100); refresh_dialog
      elsif Input.trigger?(Input::C)
        if max <= 0; pbPlayBuzzerSE; return; end
        if @trade_mode == :buy
          GhostBroker.buy_shares(@trade_id, @trade_qty) ? (pbSEPlay("GUI party switch", 80, 100); close_trade) : pbPlayBuzzerSE
        else
          GhostBroker.sell_shares(@trade_id, @trade_qty) ? (pbSEPlay("GUI party switch", 80, 100); close_trade) : pbPlayBuzzerSE
        end
      end
    end
  end

  def refresh_dialog
    b = @sprites["dialog"].bitmap; b.clear
    return if !b || b.disposed?
    draw_panel(b, 0, 0, 300, 200)
    c = GhostBroker.company(@trade_id)
    defn = GhostBroker::COMPANIES[@trade_id]

    b.fill_rect(1, 1, 298, 26, PANEL_LITE)
    pbSetSystemFont(b)
    pbDrawShadowText(b, 12, 4, 276, 20, defn[:name], PANEL_BORDER, TEXT_SHADOW)
    pbSetSmallFont(b)
    pbDrawShadowText(b, 12, 32, 140, 16, "Price: $#{fmtn(c["price"])}", TEXT_PRIMARY, TEXT_SHADOW)

    if @trade_mode == :select
      if !GhostBroker.can_buy?(@trade_id)
        b.fill_rect(12, 70, 276, 18, Color.new(60, 10, 10, 160))
        pbDrawShadowText(b, 12, 71, 276, 16, "Buy Locked", TEXT_LOCKED, TEXT_SHADOW, 1)
      end
      pf = GhostBroker.data["portfolio"][@trade_id]
      qty_str = pf && pf["qty"] > 0 ? "You own: #{pf["qty"]} shares" : "You own: 0 shares"
      pbDrawShadowText(b, 12, 100, 276, 16, qty_str, TEXT_SEC, TEXT_SHADOW)

      bx = 20
      @trade_options.each_with_index do |opt, i|
        bw = 80
        col = @trade_opt_idx == i ? PANEL_BORDER : TEXT_PRIMARY
        if @trade_opt_idx == i
          b.fill_rect(bx, 160, bw, 24, ROW_HOVER)
          b.fill_rect(bx, 160, bw, 1, PANEL_BORDER)
          b.fill_rect(bx, 183, bw, 1, PANEL_BORDER)
          b.fill_rect(bx, 160, 1, 24, PANEL_BORDER)
          b.fill_rect(bx + bw - 1, 160, 1, 24, PANEL_BORDER)
        end
        pbDrawShadowText(b, bx, 164, bw, 16, opt, col, TEXT_SHADOW, 1)
        bx += 90
      end
    else
      mode_str = @trade_mode == :buy ? "BUY" : "SELL"
      mode_c = @trade_mode == :buy ? TEXT_GAIN : TEXT_LOSS
      pbDrawShadowText(b, 12, 54, 276, 16, "#{mode_str} #{defn[:ticker]}", mode_c, TEXT_SHADOW)
      pbDrawShadowText(b, 12, 78, 276, 16, "Qty:  << #{@trade_qty} >>", TEXT_WARN, TEXT_SHADOW)
      total = @trade_qty * c["price"]
      pbDrawShadowText(b, 12, 100, 276, 16, "Total: $#{fmtn(total)}", TEXT_PRIMARY, TEXT_SHADOW)
      if @trade_mode == :buy
        sl = GhostBroker.used_slots + @trade_qty
        sc = sl > GhostBroker.max_slots ? TEXT_LOSS : TEXT_SEC
        pbDrawShadowText(b, 12, 120, 276, 16, "Slots: #{sl}/#{GhostBroker.max_slots}", sc, TEXT_SHADOW)
        rem = $Trainer.money - total
        rc = rem < 0 ? TEXT_LOSS : TEXT_SEC
        pbDrawShadowText(b, 12, 138, 276, 16, "Remaining: $#{fmtn(rem)}", rc, TEXT_SHADOW)
      end
      b.fill_rect(12, 166, 276, 1, ACCENT_DIM)
      pbDrawShadowText(b, 12, 174, 276, 16, "L/R +/-1  U/D +/-10  A Max  C OK  B Back", TEXT_SEC, TEXT_SHADOW, 1)
    end
  end

  def close_trade
    @trading = false
    @sprites["overlay"].visible = false
    @sprites["dialog"].visible = false
    refresh_all
  end
end

# Hook into step increments using the proper Events system
Events.onStepTaken += proc {
  next unless defined?($PokemonGlobal) && $PokemonGlobal
  GhostBroker.data["step_accumulator"] ||= 0
  GhostBroker.data["step_accumulator"] += 1
  GhostBroker.try_tick!
} if defined?(Events) && Events.respond_to?(:onStepTaken)
