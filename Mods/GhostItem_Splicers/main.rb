#===============================================================================
# GhostSplicers.rb
# A self-contained mod that adds advanced fusion splicers and the
# "Splice Boy Advance" key item system with battery charges.
#===============================================================================

#===============================================================================
# SECTION 1: Item Registration
# Register two new items in GameData using IDs 1050/1051 (modded range 1000+).
#
# IMPORTANT: GameData.load_all calls Item.load which replaces the DATA hash
# with the contents of items.dat via const_set. Items registered before that
# point are wiped. We solve this by:
#   1) Defining a registration method that can be called repeatedly
#   2) Hooking GameData.load_all to re-register after data loading
#   3) Also calling it immediately in case load_all already ran
#===============================================================================

GHOST_ITEM_MASTER_SPLICER_ID   = 1050
GHOST_ITEM_UNSTABLE_SPLICER_ID = 1051
GHOST_ITEM_ULTRA_SPLICER_ID    = 1052
GHOST_ITEM_CHAOS_SPLICER_ID    = 1053
GHOST_ITEM_SPLICEBOY_ADVANCE_ID = 1054
GHOST_ITEM_SPLICEBOY_BATTERY_ID = 1055

GHOST_ABILITY_CHAOS_SICKNESS_ID = 11000

def ghost_splicers_register_items
  GameData::Ability.register({
    :id          => :CHAOSSICKNESS,
    :id_number   => GHOST_ABILITY_CHAOS_SICKNESS_ID,
    :name        => "Chaos Sickness",
    :description => "Paralyzing Chaos energy confuses the pokemon."
  })
  MessageTypes.set(MessageTypes::Abilities, GHOST_ABILITY_CHAOS_SICKNESS_ID, "Chaos Sickness")
  MessageTypes.set(MessageTypes::AbilityDescs, GHOST_ABILITY_CHAOS_SICKNESS_ID, "Paralyzing Chaos energy confuses the pokemon.")

  GameData::Item.register({
    :id               => :MASTERSPLICER,
    :id_number        => GHOST_ITEM_MASTER_SPLICER_ID,
    :name             => "Master Splicer",
    :name_plural      => "Master Splicers",
    :pocket           => 1,
    :price            => 999999,
    :description      => "A splicer that fuses the DNA of two Pokémon, selecting their weakest traits in exchange for amazing abilities.",
    :field_use        => 1,
    :battle_use       => 0,
    :type             => 0,
    :move             => nil
  })

  GameData::Item.register({
    :id               => :UNSTABLESPLICER,
    :id_number        => GHOST_ITEM_UNSTABLE_SPLICER_ID,
    :name             => "Unstable Splicer",
    :name_plural      => "Unstable Splicers",
    :pocket           => 1,
    :price            => 125000,
    :description      => "A splicer that violently fuses the DNA of two Pokémon, destroying their potential in exchange for amazing abilities.",
    :field_use        => 1,
    :battle_use       => 0,
    :type             => 0,
    :move             => nil
  })

  GameData::Item.register({
    :id               => :ULTRASPLICER,
    :id_number        => GHOST_ITEM_ULTRA_SPLICER_ID,
    :name             => "Ultra Splicer",
    :name_plural      => "Ultra Splicers",
    :pocket           => 1,
    :price            => 500000,
    :description      => "A splicer that fuses the DNA of any two Pokémon, weakening their potential in exchange for amazing abilities.",
    :field_use        => 1,
    :battle_use       => 0,
    :type             => 0,
    :move             => nil
  })

  GameData::Item.register({
    :id               => :CHAOSSPLICER,
    :id_number        => GHOST_ITEM_CHAOS_SPLICER_ID,
    :name             => "Chaos Splicer",
    :name_plural      => "Chaos Splicers",
    :pocket           => 1,
    :price            => 333333,
    :description      => "A chaotic splicer that fuses the DNA of two Pokémon, scrambling their potential and mutating their abilities unpredictably.",
    :field_use        => 1,
    :battle_use       => 0,
    :type             => 0,
    :move             => nil
  })

  GameData::Item.register({
    :id               => :SPLICEBOYADVANCE,
    :id_number        => GHOST_ITEM_SPLICEBOY_ADVANCE_ID,
    :name             => "Splice Boy Advance",
    :name_plural      => "Splice Boy Advances",
    :pocket           => 8,
    :price            => 100000,
    :description      => "Insert Spliceboy Batteries to perform advanced fusions.",
    :field_use        => 2,
    :battle_use       => 0,
    :type             => 6,
    :move             => nil
  })

  GameData::Item.register({
    :id               => :SPLICEBOYBATTERY,
    :id_number        => GHOST_ITEM_SPLICEBOY_BATTERY_ID,
    :name             => "Spliceboy Battery",
    :name_plural      => "Spliceboy Batteries",
    :pocket           => 8,
    :price            => 75000,
    :description      => "Powers the Splice Boy Advance.",
    :field_use        => 0,
    :battle_use       => 0,
    :type             => 6,
    :move             => nil
  })

  # Set translated message strings for display
  MessageTypes.set(MessageTypes::Items,            GHOST_ITEM_MASTER_SPLICER_ID, "Master Splicer")
  MessageTypes.set(MessageTypes::ItemPlurals,      GHOST_ITEM_MASTER_SPLICER_ID, "Master Splicers")
  MessageTypes.set(MessageTypes::ItemDescriptions, GHOST_ITEM_MASTER_SPLICER_ID, "A splicer that fuses the DNA of two Pokémon, selecting their weakest traits in exchange for amazing abilities.")

  MessageTypes.set(MessageTypes::Items,            GHOST_ITEM_UNSTABLE_SPLICER_ID, "Unstable Splicer")
  MessageTypes.set(MessageTypes::ItemPlurals,      GHOST_ITEM_UNSTABLE_SPLICER_ID, "Unstable Splicers")
  MessageTypes.set(MessageTypes::ItemDescriptions, GHOST_ITEM_UNSTABLE_SPLICER_ID, "A splicer that violently fuses the DNA of two Pokémon, destroying their potential in exchange for amazing abilities.")

  MessageTypes.set(MessageTypes::Items,            GHOST_ITEM_ULTRA_SPLICER_ID, "Ultra Splicer")
  MessageTypes.set(MessageTypes::ItemPlurals,      GHOST_ITEM_ULTRA_SPLICER_ID, "Ultra Splicers")
  MessageTypes.set(MessageTypes::ItemDescriptions, GHOST_ITEM_ULTRA_SPLICER_ID, "A splicer that fuses the DNA of any two Pokémon, weakening their potential in exchange for amazing abilities.")

  MessageTypes.set(MessageTypes::Items,            GHOST_ITEM_CHAOS_SPLICER_ID, "Chaos Splicer")
  MessageTypes.set(MessageTypes::ItemPlurals,      GHOST_ITEM_CHAOS_SPLICER_ID, "Chaos Splicers")
  MessageTypes.set(MessageTypes::ItemDescriptions, GHOST_ITEM_CHAOS_SPLICER_ID, "A chaotic splicer that fuses the DNA of two Pokémon, scrambling their potential and mutating their abilities unpredictably.")

  MessageTypes.set(MessageTypes::Items,            GHOST_ITEM_SPLICEBOY_ADVANCE_ID, "Splice Boy Advance")
  MessageTypes.set(MessageTypes::ItemPlurals,      GHOST_ITEM_SPLICEBOY_ADVANCE_ID, "Splice Boy Advances")
  MessageTypes.set(MessageTypes::ItemDescriptions, GHOST_ITEM_SPLICEBOY_ADVANCE_ID, "Insert Spliceboy Batteries to perform advanced fusions.")

  MessageTypes.set(MessageTypes::Items,            GHOST_ITEM_SPLICEBOY_BATTERY_ID, "Spliceboy Battery")
  MessageTypes.set(MessageTypes::ItemPlurals,      GHOST_ITEM_SPLICEBOY_BATTERY_ID, "Spliceboy Batteries")
  MessageTypes.set(MessageTypes::ItemDescriptions, GHOST_ITEM_SPLICEBOY_BATTERY_ID, "Powers the Splice Boy Advance.")
end

# Hook into GameData.load_all so items survive the DATA hash replacement
module GameData
  class << self
    alias ghost_splicers_original_load_all load_all
    def load_all
      ghost_splicers_original_load_all
      ghost_splicers_register_items
      echoln "[GhostSplicers] Items registered after GameData.load_all"
    end
  end
end

# Also register now in case load_all has already been called
ghost_splicers_register_items

# Register in PBItems for compatibility with older code paths
module PBItems
  MASTERSPLICER      = GHOST_ITEM_MASTER_SPLICER_ID
  UNSTABLESPLICER    = GHOST_ITEM_UNSTABLE_SPLICER_ID
  ULTRASPLICER       = GHOST_ITEM_ULTRA_SPLICER_ID
  CHAOSSPLICER       = GHOST_ITEM_CHAOS_SPLICER_ID
  SPLICEBOYADVANCE   = GHOST_ITEM_SPLICEBOY_ADVANCE_ID
  SPLICEBOYBATTERY   = GHOST_ITEM_SPLICEBOY_BATTERY_ID
end

#===============================================================================
# SECTION 2: Item Classification Helpers
# Extend the existing splicer classification methods so the game recognizes
# our new splicers in all the right places.
#===============================================================================

module GhostSplicers
  # All ghost splicers (custom)
  GHOST_SPLICERS = [:MASTERSPLICER, :UNSTABLESPLICER, :ULTRASPLICER, :CHAOSSPLICER]

  def self.is_ghost_splicer?(item)
    GHOST_SPLICERS.include?(item)
  end

  def self.dev_mode?
    return false unless defined?(ModSettingsMenu)
    return ModSettingsMenu.get(:gs_dev_mode) == 1
  end

  def self.is_dual_ability_splicer?(item)
    [:MASTERSPLICER, :UNSTABLESPLICER, :ULTRASPLICER, :CHAOSSPLICER].include?(item)
  end

  def self.is_chaos_splicer?(item)
    item == :CHAOSSPLICER
  end

  def self.is_master_splicer?(item)
    item == :MASTERSPLICER
  end

  def self.is_unstable_splicer?(item)
    item == :UNSTABLESPLICER
  end

  def self.is_ultra_splicer?(item)
    item == :ULTRASPLICER
  end
end

#===============================================================================
# Mod Settings: GhostSplicers Configuration
#===============================================================================
module GhostSplicers
  def self.register_settings
    return unless defined?(ModSettingsMenu)

    # Ensure "Ghost Settings" category exists
    unless ModSettingsMenu.categories.any? { |c| c[:name] == "Ghost Settings" }
      ModSettingsMenu.categories << {
        name: "Ghost Settings",
        priority: 85,
        description: "Settings for GhostXYZ mods",
        collapsed: true
      }
    end

    # Register Dev Mode toggle
    ModSettingsMenu.register(:gs_dev_mode, {
      name: "Splicers: Dev Mode",
      type: :enum,
      category: "Ghost Settings",
      save_key: "gs_dev_mode",
      values: ["No", "Yes"],
      default: 0,
      description: "When enabled, Splice Boy Advance and Batteries cost only 1 Pokedollar."
    })
  end
end

# Initialize if ModSettingsMenu is available. If not, queue for when it loads.
if defined?(ModSettingsMenu)
  GhostSplicers.register_settings
else
  $MOD_SETTINGS_PENDING_REGISTRATIONS ||= []
  $MOD_SETTINGS_PENDING_REGISTRATIONS << proc { GhostSplicers.register_settings }
end

#===============================================================================
# SECTION 3: Override isSuperSplicersMechanics
# Dual Ability Splicers should be treated like super splicers for fusion preview,
# ability choice inheritance, etc.
#===============================================================================

alias ghost_splicers_original_isSuperSplicersMechanics isSuperSplicersMechanics
def isSuperSplicersMechanics(item)
  return true if GhostSplicers.is_dual_ability_splicer?(item)
  return ghost_splicers_original_isSuperSplicersMechanics(item)
end

#===============================================================================
# SECTION 4: Item Usage Handlers
# Register UseOnPokemon and UseInField handlers so these items can be used
# from the bag and from the field just like other splicers.
#===============================================================================

# Master Splicer - use on Pokémon
ItemHandlers::UseOnPokemon.add(:MASTERSPLICER, proc { |item, pokemon, scene|
  next true if pbDNASplicing(pokemon, scene, item)
  next false
})

# Master Splicer - use from field
ItemHandlers::UseInField.add(:MASTERSPLICER, proc { |item|
  fusion_success = useSplicerFromField(item)
  next true if fusion_success
  next false
})

# Unstable Splicer - use on Pokémon
ItemHandlers::UseOnPokemon.add(:UNSTABLESPLICER, proc { |item, pokemon, scene|
  next true if pbDNASplicing(pokemon, scene, item)
  next false
})

# Unstable Splicer - use from field
ItemHandlers::UseInField.add(:UNSTABLESPLICER, proc { |item|
  fusion_success = useSplicerFromField(item)
  next true if fusion_success
  next false
})

# Ultra Splicer - use on Pokémon
ItemHandlers::UseOnPokemon.add(:ULTRASPLICER, proc { |item, pokemon, scene|
  next true if pbDNASplicing(pokemon, scene, item)
  next false
})

# Ultra Splicer - use from field
ItemHandlers::UseInField.add(:ULTRASPLICER, proc { |item|
  fusion_success = useSplicerFromField(item)
  next true if fusion_success
  next false
})

# Chaos Splicer - use on Pokémon
ItemHandlers::UseOnPokemon.add(:CHAOSSPLICER, proc { |item, pokemon, scene|
  next true if pbDNASplicing(pokemon, scene, item)
  next false
})

# Chaos Splicer - use from field
ItemHandlers::UseInField.add(:CHAOSSPLICER, proc { |item|
  fusion_success = useSplicerFromField(item)
  next true if fusion_success
  next false
})

#===============================================================================
# SECTION 4B: Splice Boy Advance UI & Handlers
# The Splice Boy Advance is a reusable key item that opens a selection menu
# letting the player choose a fusion type. Each type costs Spliceboy Batteries.
#===============================================================================

module SpliceBoyUI
  # Fusion options: [display_name, splicer_symbol, battery_cost]
  FUSION_OPTIONS = [
    ["Unstable Splice",  :UNSTABLESPLICER, 1],
    ["Ultra Splice",     :ULTRASPLICER,    3],
    ["Master Splice",    :MASTERSPLICER,   5],
    ["Chaos Splice",     :CHAOSSPLICER,    3]
  ]

  # Opens the Splice Boy Advance selection UI with proper graphical scene.
  # Returns the chosen splicer symbol, or nil if cancelled.
  def self.select_fusion_type
    scene = SpliceBoyScene.new
    return scene.main
  end

  # Returns the battery cost for a given splicer symbol
  def self.battery_cost(splicer_sym)
    opt = FUSION_OPTIONS.find { |_n, sym, _c| sym == splicer_sym }
    return opt ? opt[2] : 0
  end

  # Deducts batteries after a successful fusion
  def self.deduct_batteries(splicer_sym)
    cost = battery_cost(splicer_sym)
    if cost > 0
      $PokemonBag.pbDeleteItem(:SPLICEBOYBATTERY, cost)
      echoln "[GhostSplicers] Deducted #{cost} Spliceboy Batteries for #{splicer_sym}"
    end
  end

  # Opens the party screen and allows selecting a Pokémon for fusion,
  # but explicitly blocks selecting already fused Pokémon (protects against unfuse)
  def self.use_splicer_from_field(splicer_sym)
    scene = PokemonParty_Scene.new
    scene.pbStartScene($Trainer.party, _INTL("Select a Pokémon"))
    screen = PokemonPartyScreen.new(scene, $Trainer.party)
    fusion_success = false
    loop do
      chosen = screen.pbChoosePokemon(_INTL("Select a Pokémon"))
      break if chosen < 0
      pokemon = $Trainer.party[chosen]
      
      # Guard against unfusing
      if pokemon.fused != nil || (pokemon.species_data && pokemon.species_data.id_number > Settings::NB_POKEMON)
        scene.pbDisplay(_INTL("The Splice Boy Advance can only be used for fusing!"))
        next
      end
      
      fusion_success = pbDNASplicing(pokemon, scene, splicer_sym)
      break
    end
    screen.pbEndScene
    scene.dispose
    return fusion_success
  end
end

#===============================================================================
# SpliceBoyScene: Custom graphical UI for the Splice Boy Advance
# Layout (512x384 screen):
#   ┌──────────────┬──────────────────────────┐
#   │  Item Icon   │   Selection Menu         │
#   │  (128x128)   │   (command window)       │
#   │              │                          │
#   ├──────────────┴──────────────────────────┤
#   │  Description Text Box                   │
#   │  (full width, ~96px tall)               │
#   └─────────────────────────────────────────┘
#===============================================================================
class SpliceBoyScene
  def main
    batteries = $PokemonBag.pbQuantity(:SPLICEBOYBATTERY)
    options = SpliceBoyUI::FUSION_OPTIONS

    # Build command strings
    commands = []
    options.each do |name, _sym, cost|
      if batteries >= cost
        commands.push(_INTL("{1} ({2} BTRY)", name, cost))
      else
        commands.push(_INTL("{1} ({2} BTRY) [LOCKED]", name, cost))
      end
    end
    commands.push(_INTL("Cancel"))

    # Create viewport
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}

    # Dark overlay behind everything
    @sprites["bg"] = Sprite.new(@viewport)
    @sprites["bg"].bitmap = Bitmap.new(Graphics.width, Graphics.height)
    @sprites["bg"].bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0, 160))

    # === Panel layout ===
    icon_panel_w = 128
    icon_panel_h = 160
    icon_panel_x = 16
    icon_panel_y = 16

    menu_x = icon_panel_x + icon_panel_w + 8
    menu_y = icon_panel_y
    menu_w = Graphics.width - menu_x - 16
    menu_h = icon_panel_h

    desc_x = 16
    desc_y = icon_panel_y + icon_panel_h + 8
    desc_w = Graphics.width - 32
    desc_h = Graphics.height - desc_y - 16

    # === Icon panel background ===
    @sprites["icon_bg"] = Sprite.new(@viewport)
    @sprites["icon_bg"].bitmap = Bitmap.new(icon_panel_w, icon_panel_h)
    @sprites["icon_bg"].bitmap.fill_rect(0, 0, icon_panel_w, icon_panel_h, Color.new(40, 40, 50, 200))
    @sprites["icon_bg"].x = icon_panel_x
    @sprites["icon_bg"].y = icon_panel_y

    # === Battery counter text ===
    @sprites["battery_text"] = Sprite.new(@viewport)
    @sprites["battery_text"].bitmap = Bitmap.new(icon_panel_w, 24)
    @sprites["battery_text"].x = icon_panel_x
    @sprites["battery_text"].y = icon_panel_y + icon_panel_h - 28
    pbSetSystemFont(@sprites["battery_text"].bitmap)
    pbDrawShadowText(@sprites["battery_text"].bitmap, 0, 0, icon_panel_w, 24,
      _INTL("BTRY x{1}", batteries), Color.new(255, 255, 255), Color.new(60, 60, 60), 1)

    # === Item icon sprite (centered in icon panel) ===
    first_sym = options[0][1]
    @sprites["item_icon"] = ItemIconSprite.new(
      icon_panel_x + icon_panel_w / 2,
      icon_panel_y + (icon_panel_h - 28) / 2,
      first_sym, @viewport
    )
    @sprites["item_icon"].setOffset(PictureOrigin::Center)
    @sprites["item_icon"].zoom_x = 2.0
    @sprites["item_icon"].zoom_y = 2.0

    # === Command window (selection menu) ===
    @sprites["cmdwindow"] = Window_CommandPokemon.newWithSize(
      commands, menu_x, menu_y, menu_w, menu_h, @viewport
    )
    @sprites["cmdwindow"].index = 0

    # === Description text box ===
    @sprites["desc_bg"] = Sprite.new(@viewport)
    @sprites["desc_bg"].bitmap = Bitmap.new(desc_w, desc_h)
    @sprites["desc_bg"].bitmap.fill_rect(0, 0, desc_w, desc_h, Color.new(40, 40, 50, 200))
    @sprites["desc_bg"].x = desc_x
    @sprites["desc_bg"].y = desc_y

    @sprites["desc_text"] = Sprite.new(@viewport)
    @sprites["desc_text"].bitmap = Bitmap.new(desc_w - 16, desc_h - 8)
    @sprites["desc_text"].x = desc_x + 8
    @sprites["desc_text"].y = desc_y + 4

    # Initial description
    @last_index = -1
    update_description(0, options, batteries)

    # === Main loop ===
    result = nil
    loop do
      Graphics.update
      Input.update
      @sprites["cmdwindow"].update

      # Update icon + description when selection changes
      idx = @sprites["cmdwindow"].index
      if idx != @last_index
        update_description(idx, options, batteries)
        @last_index = idx
      end

      # Update the item icon animation
      if @sprites["item_icon"]
        @sprites["item_icon"].update
        raw_item = @sprites["item_icon"].item
        if raw_item && defined?(GhostSplicerIconAnimator)
          GhostSplicerIconAnimator.update_sprite(@sprites["item_icon"], raw_item)
        end
      end

      if Input.trigger?(Input::C) # Confirm
        idx = @sprites["cmdwindow"].index
        if idx >= options.length
          # Cancel
          result = nil
          break
        end
        name, splicer_sym, cost = options[idx]
        if batteries < cost
          pbMessage(_INTL("Not enough batteries! {1} requires {2}, but you only have {3}.",
            name, cost, batteries))
          next
        end
        if pbConfirmMessage(_INTL("Use {1} batteries for {2}?", cost, name))
          result = splicer_sym
          break
        end
      elsif Input.trigger?(Input::B) # Back
        result = nil
        break
      end
    end

    # Cleanup
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
    return result
  end

  private

  def update_description(idx, options, batteries)
    if idx < options.length
      name, splicer_sym, cost = options[idx]
      splicer_data = GameData::Item.try_get(splicer_sym)
      desc = splicer_data ? splicer_data.description : ""

      # Update item icon
      @sprites["item_icon"].item = splicer_sym if @sprites["item_icon"]

      # Update description text
      bmp = @sprites["desc_text"].bitmap
      bmp.clear
      pbSetSmallFont(bmp)
      # Title line
      title_color = (batteries >= cost) ? Color.new(100, 255, 100) : Color.new(255, 100, 100)
      pbDrawShadowText(bmp, 0, 0, bmp.width, 24,
        _INTL("{1} — {2} Batteries", name, cost),
        title_color, Color.new(40, 40, 40))
      # Description (word-wrapped)
      drawTextEx(bmp, 0, 26, bmp.width, 4, desc,
        Color.new(230, 230, 230), Color.new(60, 60, 60))
    else
      # Cancel selected — clear preview
      @sprites["item_icon"].item = nil if @sprites["item_icon"]
      bmp = @sprites["desc_text"].bitmap
      bmp.clear
      pbSetSmallFont(bmp)
      pbDrawShadowText(bmp, 0, 0, bmp.width, 24,
        _INTL("Return without selecting."),
        Color.new(180, 180, 180), Color.new(40, 40, 40))
    end
  end

  def drawTextEx(bitmap, x, y, width, max_lines, text, base_color, shadow_color)
    return if !text || text == ""
    pbSetSmallFont(bitmap)
    # Simple word wrap
    words = text.split(' ')
    lines = []
    current_line = ""
    words.each do |word|
      test = current_line == "" ? word : current_line + " " + word
      tw = bitmap.text_size(test).width
      if tw > width && current_line != ""
        lines.push(current_line)
        current_line = word
      else
        current_line = test
      end
    end
    lines.push(current_line) if current_line != ""
    lines = lines[0, max_lines] if lines.length > max_lines
    lines.each_with_index do |line, i|
      pbDrawShadowText(bitmap, x, y + i * 22, width, 22, line, base_color, shadow_color)
    end
  end
end

# Splice Boy Advance - use from field
ItemHandlers::UseInField.add(:SPLICEBOYADVANCE, proc { |item|
  chosen = SpliceBoyUI.select_fusion_type
  if chosen
    fusion_success = SpliceBoyUI.use_splicer_from_field(chosen)
    if fusion_success
      SpliceBoyUI.deduct_batteries(chosen)
      next 2  # 2 tells the bag engine to close the screen after use
    end
  end
  next 0
})



#===============================================================================
# SECTION 5: Override Fusion IV Logic
# Intercept setFusionIVs in PokemonFusionScene to apply our special IV rules:
#   - Master Splicer:   Lowest of both Pokémon's IVs
#   - Ultra Splicer:    All IVs set to 0
#   - Unstable Splicer: All IVs set to -31
#   - Chaos Splicer:    Random IVs between -42 and 42
#===============================================================================

class PokemonFusionScene
  alias ghost_splicers_original_pbStartScreen pbStartScreen
  def pbStartScreen(pokemon1, pokemon2, newspecies, splicerItem = :DNASPLICERS)
    @ghost_splicer_item = splicerItem
    ghost_splicers_original_pbStartScreen(pokemon1, pokemon2, newspecies, splicerItem)
  end

  alias ghost_splicers_original_setFusionIVs setFusionIVs
  def setFusionIVs(supersplicers)
    if GhostSplicers.is_master_splicer?(@ghost_splicer_item)
      setLowestFusionIvs()
    elsif GhostSplicers.is_ultra_splicer?(@ghost_splicer_item)
      setZeroFusionIvs()
    elsif GhostSplicers.is_unstable_splicer?(@ghost_splicer_item)
      setNegativeFusionIvs()
    elsif GhostSplicers.is_chaos_splicer?(@ghost_splicer_item)
      setChaosFusionIvs()
    else
      ghost_splicers_original_setFusionIVs(supersplicers)
    end
  end

  def setChaosFusionIvs
    [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].each do |stat|
      # rand(85) gives 0..84. Then - 42 gives -42..42
      @pokemon1.iv[stat] = rand(85) - 42
    end
  end

  def setZeroFusionIvs
    [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].each do |stat|
      @pokemon1.iv[stat] = 0
    end
  end

  def setNegativeFusionIvs
    [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].each do |stat|
      @pokemon1.iv[stat] = -31
    end
  end

  def setLowestFusionIvs
    [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].each do |stat|
      @pokemon1.iv[stat] = [@pokemon1.iv[stat], @pokemon2.iv[stat]].min
    end
  end
end

#===============================================================================
# SECTION 6: Pokemon class — Master Splicer flag + dedicated ability2 storage
# We store a @master_splicer_fused flag and @master_splicer_ability2 on the
# Pokemon so we can distinguish Master-Splicer fusions from normal ones.
# The game's lazy-init in ability_id / ability2_id often overwrites @ability2,
# so we use a separate ivar that survives those recalculations.
#===============================================================================

class Pokemon
  attr_accessor :master_splicer_fused
  attr_accessor :master_splicer_ability2

  # Override ability2 to return the Master Splicer's second ability.
  # This build's base Pokemon class has no ability2/ability2_id (no
  # second-ability concept outside this mod) -- confirmed via project-wide
  # search of Data/Scripts -- so `alias ... ability2` used to raise
  # NameError and abort the rest of this file's load. Fall back to a nil
  # (no ability) accessor, matching this engine's "no ability" convention
  # (see ability_id in Data/Scripts/014_Pokemon/001_Pokemon.rb), when the
  # method isn't already defined.
  if method_defined?(:ability2)
    alias ghost_splicers_original_ability2 ability2
  else
    def ghost_splicers_original_ability2
      return nil
    end
  end
  def ability2
    if @master_splicer_fused && @master_splicer_ability2
      return GameData::Ability.try_get(@master_splicer_ability2)
    end
    return ghost_splicers_original_ability2
  end

  # Override ability2_id to return the Master Splicer's second ability ID
  if method_defined?(:ability2_id)
    alias ghost_splicers_original_ability2_id ability2_id
  else
    def ghost_splicers_original_ability2_id
      return nil
    end
  end
  def ability2_id
    if @master_splicer_fused && @master_splicer_ability2
      return @master_splicer_ability2
    end
    return ghost_splicers_original_ability2_id
  end
end

#===============================================================================
# SECTION 7: Override Ability Selection for Dual Ability Splicers
# When using these splicers, the fused Pokémon gets BOTH abilities instead
# of choosing one. Sets the master_splicer_fused flag and stores ability2 in
# a dedicated ivar.
#===============================================================================

class PokemonFusionScene
  alias ghost_splicers_original_setAbilityAndNatureAndNickname setAbilityAndNatureAndNickname
  def setAbilityAndNatureAndNickname(abilitiesList, naturesList)
    if GhostSplicers.is_dual_ability_splicer?(@ghost_splicer_item)
      clearUIForMoves

      # Nature selection only (no ability choice)
      scene = FusionSelectOptionsScene.new(nil, naturesList, @pokemon1, @pokemon2)
      screen = PokemonOptionScreen.new(scene)
      screen.pbStartScreen

      if GhostSplicers.is_chaos_splicer?(@ghost_splicer_item)
        # 33% Both, 33% Pick One, 33% Chaos Sickness
        roll = rand(3)
        if roll == 0
          # Both!
          @pokemon1.ability = abilitiesList[0]
          ability2_data = GameData::Ability.try_get(abilitiesList[1])
          if ability2_data
            @pokemon1.master_splicer_fused = true
            @pokemon1.master_splicer_ability2 = ability2_data.id
            @pokemon1.instance_variable_set(:@ability2, ability2_data.id)
          end
        elsif roll == 1
          # Randomly pick one of the two parents' abilities
          selected_ab = (rand(2) == 0) ? abilitiesList[0] : abilitiesList[1]
          @pokemon1.ability = selected_ab
          # Clear dual ability state — single ability only
          @pokemon1.master_splicer_fused = false
          @pokemon1.master_splicer_ability2 = nil
          @pokemon1.instance_variable_set(:@ability2, nil)
        else
          # Chaos Sickness!
          @pokemon1.ability = :CHAOSSICKNESS
          # Clear dual ability state — Chaos Sickness is a single ability
          @pokemon1.master_splicer_fused = false
          @pokemon1.master_splicer_ability2 = nil
          @pokemon1.instance_variable_set(:@ability2, nil)
        end
      else
        # Standard Dual Ability assign
        @pokemon1.ability = abilitiesList[0]

        ability2_data = GameData::Ability.try_get(abilitiesList[1])
        if ability2_data
          @pokemon1.master_splicer_fused = true
          @pokemon1.master_splicer_ability2 = ability2_data.id
          @pokemon1.instance_variable_set(:@ability2, ability2_data.id)
        end
      end

      # Store original ability indices for unfusing
      @pokemon1.body_original_ability_index = @pokemon1.ability_index
      @pokemon1.head_original_ability_index = @pokemon2.ability_index

      @pokemon1.nature = scene.selectedNature
      if scene.hasNickname
        @pokemon1.name = scene.nickname
      end
    else
      # All other splicers: use original logic
      ghost_splicers_original_setAbilityAndNatureAndNickname(abilitiesList, naturesList)
    end
  end
end

#===============================================================================
# SECTION 8: Chaos Sickness Battle Effect
#===============================================================================
BattleHandlers::AbilityOnSwitchIn.add(:CHAOSSICKNESS,
  proc { |ability, battler, battle|
    battle.pbShowAbilitySplash(battler)
    battle.pbDisplay(_INTL("{1} is suffering from Chaos Sickness!", battler.pbThis))
    if rand(2) == 0
      if battler.pbCanConfuse?(battler, false)
        battler.pbConfuse
      else
        battle.pbDisplay(_INTL("But nothing happened!"))
      end
    else
      if battler.pbCanParalyze?(battler, false)
        battler.pbParalyze(battler)
      else
        battle.pbDisplay(_INTL("But nothing happened!"))
      end
    end
    battle.pbHideAbilitySplash(battler)
  }
)

#===============================================================================
# SECTION 8: Extend Battler class for Master Splicer dual abilities
# Override ability2 / hasActiveAbility? on PokeBattle_Battler so that in battle,
# a Master-Splicer-fused Pokemon benefits from BOTH abilities at once.
# We check the Pokemon's master_splicer_fused flag to avoid interfering with
# the Family system or the SWITCH_DOUBLE_ABILITIES system.
#===============================================================================

class PokeBattle_Battler
  # Same missing-method issue as Pokemon#ability2 above -- PokeBattle_Battler
  # has no ability2 in this build either.
  if method_defined?(:ability2)
    alias ghost_splicers_original_ability2 ability2
  else
    def ghost_splicers_original_ability2
      return nil
    end
  end
  def ability2
    pkmn = self.pokemon rescue nil
    if pkmn && pkmn.master_splicer_fused && pkmn.master_splicer_ability2
      return GameData::Ability.try_get(pkmn.master_splicer_ability2)
    end
    return ghost_splicers_original_ability2
  end

  alias ghost_splicers_original_hasActiveAbility hasActiveAbility?
  def hasActiveAbility?(check_ability, ignore_fainted = false, mold_broken = false)
    pkmn = self.pokemon rescue nil
    if pkmn && pkmn.master_splicer_fused && pkmn.master_splicer_ability2
      return false if !abilityActive?(ignore_fainted)
      ms_ability2_id = pkmn.master_splicer_ability2
      if check_ability.is_a?(Array)
        return check_ability.include?(@ability_id) || check_ability.include?(ms_ability2_id)
      end
      return self.ability == check_ability ||
             GameData::Ability.try_get(ms_ability2_id) == check_ability
    end
    # Forward only as many args as the aliased original actually accepts.
    # This method's own signature always fills in `mold_broken` (default
    # false) even when the real caller only passed 1-2 args, so blindly
    # forwarding all 3 crashes whenever `ghost_splicers_original_hasActiveAbility`
    # resolves to the vanilla 2-arg `hasActiveAbility?` (Data/Scripts base) --
    # e.g. when this mod loads before KantoReloaded's DoubleAbilities hook
    # wraps the method. Found via a live playtest crash: ArgumentError
    # "wrong number of arguments (given 3, expected 1..2)" at
    # 001_PokeBattle_Battler.rb:394, on every single ability check.
    orig_params = method(:ghost_splicers_original_hasActiveAbility).parameters
    accepts_third_arg = orig_params.any? { |type, _| type == :rest } ||
                         orig_params.count { |type, _| type == :req || type == :opt } >= 3
    if accepts_third_arg
      return ghost_splicers_original_hasActiveAbility(check_ability, ignore_fainted, mold_broken)
    end
    return ghost_splicers_original_hasActiveAbility(check_ability, ignore_fainted)
  end

  # Trigger ability2 on switch-in for Master Splicer fusions
  alias ghost_splicers_original_pbEffectsOnSwitchIn pbEffectsOnSwitchIn
  def pbEffectsOnSwitchIn(switchIn = false)
    ghost_splicers_original_pbEffectsOnSwitchIn(switchIn)

    pkmn = self.pokemon rescue nil
    if pkmn && pkmn.master_splicer_fused && pkmn.master_splicer_ability2
      ab2 = GameData::Ability.try_get(pkmn.master_splicer_ability2)
      if ab2 && ((!fainted? && unstoppableAbility?) || abilityActive?)
        @triggering_ability2 = true
        BattleHandlers.triggerAbilityOnSwitchIn(ab2, self, @battle)
        @triggering_ability2 = false
      end
    end
  end
end

#===============================================================================
# SECTION 9: Summary Screen & Global UI - Dynamic Dual Abilities
# For Master Splicer fusions, the "Ability" title glows rainbow, and the actual
# ability swaps every 3 seconds to show both abilities cleanly.
# We hook into the active update loops of PokemonSummary_Scene and PokemonStorageScene.
#===============================================================================

module GhostSplicerAnimator
  def self.rainbow_color
    time_ms = (Time.now.to_f * 1000).to_i
    hue = ((time_ms % 3000) * 360 / 3000).to_i
    
    h = hue / 60.0
    c = 200
    x = (c * (1 - ((h % 2) - 1).abs)).to_i
    
    r = g = b = 0
    case h.to_i
    when 0 then r = c; g = x; b = 0
    when 1 then r = x; g = c; b = 0
    when 2 then r = 0; g = c; b = x
    when 3 then r = 0; g = x; b = c
    when 4 then r = x; g = 0; b = c
    else        r = c; g = 0; b = x
    end
    
    return Color.new(r + 55, g + 55, b + 55)
  end

  def self.active_master_splicer_ability(pokemon)
    return pokemon.ability unless pokemon && pokemon.master_splicer_fused && pokemon.master_splicer_ability2
    time_ms = (Time.now.to_f * 1000).to_i
    phase = (time_ms / 3000).to_i % 2
    return (phase == 0) ? pokemon.ability : GameData::Ability.try_get(pokemon.master_splicer_ability2)
  end

  def self.should_update_drawing?(last_phase, last_color)
    time_ms = (Time.now.to_f * 1000).to_i
    phase = (time_ms / 3000).to_i % 2
    # redraw every 50ms for smooth rainbow
    if phase != last_phase || (time_ms - last_color) > 50
      return [true, phase, time_ms]
    end
    return [false, last_phase, last_color]
  end
end

class PokemonSummary_Scene
  alias ghost_splicers_anim_drawPageThree drawPageThree
  def drawPageThree
    ghost_splicers_anim_drawPageThree
    return unless @pokemon && @pokemon.master_splicer_fused && @pokemon.master_splicer_ability2
    
    @ms_last_phase = -1
    @ms_last_color = 0
    ghost_splicers_redraw_master_splicer_summary
  end

  alias ghost_splicers_anim_pbUpdate pbUpdate
  def pbUpdate
    ghost_splicers_anim_pbUpdate
    
    return unless @pokemon && @pokemon.master_splicer_fused && @pokemon.master_splicer_ability2
    return if @page != 3
    
    @ms_last_phase ||= -1
    @ms_last_color ||= 0
    
    do_update, @ms_last_phase, @ms_last_color = GhostSplicerAnimator.should_update_drawing?(@ms_last_phase, @ms_last_color)
    if do_update
      ghost_splicers_redraw_master_splicer_summary
    end
  end
  
  def ghost_splicers_redraw_master_splicer_summary
    overlay = @sprites["overlay"].bitmap
    rainbow = GhostSplicerAnimator.rainbow_color
    base    = Color.new(248, 248, 248)
    shadow  = Color.new(104, 104, 104)
    fg      = Color.new(64, 64, 64)
    fg_s    = Color.new(176, 176, 176)
    
    active_ab = GhostSplicerAnimator.active_master_splicer_ability(@pokemon)
    return unless active_ab

    # Clear area for "Ability", Ability Name, and Description
    overlay.fill_rect(224, 278, 280, 40, Color.new(0, 0, 0, 0)) # Title & name
    overlay.fill_rect(224, 320, 282, 64, Color.new(0, 0, 0, 0)) # Description
    
    textpos = [
      [_INTL("Ability"), 224, 278, 0, base, shadow],
      [active_ab.name, 362, 278, 0, rainbow, shadow]
    ]
    pbDrawTextPositions(overlay, textpos)
    drawTextEx(overlay, 224, 320, 282, 2, active_ab.description, fg, fg_s)
  end
end

class PokemonStorageScene
  alias ghost_anim_pbUpdateOverlay pbUpdateOverlay
  def pbUpdateOverlay(selection, party = nil)
    ghost_anim_pbUpdateOverlay(selection, party)
    
    if @screen && @screen.pbHolding? && !@screen.fusionMode
      @ms_current_pokemon = @screen.pbHeldPokemon
    elsif selection >= 0
      @ms_current_pokemon = (party) ? party[selection] : @storage[@storage.currentBox, selection]
    else
      @ms_current_pokemon = nil
    end
    
    @ms_last_phase = -1
    @ms_last_color = 0
  end

  alias ghost_anim_update update
  def update
    ghost_anim_update
    
    return unless @ms_current_pokemon && @ms_current_pokemon.master_splicer_fused && @ms_current_pokemon.master_splicer_ability2
    
    @ms_last_phase ||= -1
    @ms_last_color ||= 0
    
    do_update, @ms_last_phase, @ms_last_color = GhostSplicerAnimator.should_update_drawing?(@ms_last_phase, @ms_last_color)
    if do_update
      overlay = @sprites["overlay"].bitmap
      rainbow = GhostSplicerAnimator.rainbow_color
      shadow = Color.new(168, 184, 184)
      
      active_ab = GhostSplicerAnimator.active_master_splicer_ability(@ms_current_pokemon)
      return unless active_ab

      # Storage screen uses y=300, center aligned at x=86.
      overlay.fill_rect(10, 300, 150, 32, Color.new(0, 0, 0, 0))
      
      pbDrawTextPositions(overlay, [
        [active_ab.name, 86, 300, 2, rainbow, shadow]
      ])
    end
  end
end

#===============================================================================
# SECTION 10: PC Storage Integration
# Patch the PC to recognize our new splicers in the fusion menu.
# The PC's selectSplicer / isSuperSplicer? / canDeleteItem methods need to
# include the new items.
#===============================================================================

class PokemonStorageScreen
  # Track unfuse context so selectSplicer hides Splice Boy Advance during unfuse
  alias ghost_splicers_original_pbUnfuseFromPC pbUnfuseFromPC
  def pbUnfuseFromPC(*args)
    @ghost_unfuse_context = true
    ghost_splicers_original_pbUnfuseFromPC(*args)
  ensure
    @ghost_unfuse_context = false
  end

  # Override selectSplicer to include Splice Boy Advance + legacy splicers
  alias ghost_splicers_original_selectSplicer selectSplicer
  def selectSplicer
    splice_boy_const       = "Splice Boy Advance"
    master_splicer_const   = "Master Splicer"
    unstable_splicer_const = "Unstable Splicer"
    ultra_splicer_const    = "Ultra Splicer"
    chaos_splicer_const    = "Chaos Splicer"
    dna_splicers_const     = "DNA Splicers"
    super_splicers_const   = "Super Splicers"
    infinite_splicers_const = "Infinite Splicers"

    spliceBoyQt       = $PokemonBag.pbQuantity(:SPLICEBOYADVANCE)
    batteryQt         = $PokemonBag.pbQuantity(:SPLICEBOYBATTERY)
    masterSplicerQt   = $PokemonBag.pbQuantity(:MASTERSPLICER)
    unstableSplicerQt = $PokemonBag.pbQuantity(:UNSTABLESPLICER)
    ultraSplicerQt    = $PokemonBag.pbQuantity(:ULTRASPLICER)
    chaosSplicerQt    = $PokemonBag.pbQuantity(:CHAOSSPLICER)
    dnaSplicersQt     = $PokemonBag.pbQuantity(:DNASPLICERS)
    superSplicersQt   = $PokemonBag.pbQuantity(:SUPERSPLICERS)
    infiniteSplicersQt  = $PokemonBag.pbQuantity(:INFINITESPLICERS)
    infiniteSplicers2Qt = $PokemonBag.pbQuantity(:INFINITESPLICERS2)

    options = []
    # Splice Boy Advance first (if owned AND not unfusing) with battery count
    if spliceBoyQt > 0 && !@ghost_unfuse_context
      options.push(_INTL("{1} ({2} batteries)", splice_boy_const, batteryQt))
    end
    # Legacy individual splicers (for any the player already has)
    options.push(_INTL("{1} ({2})", master_splicer_const, masterSplicerQt)) if masterSplicerQt > 0
    options.push(_INTL("{1} ({2})", ultra_splicer_const, ultraSplicerQt)) if ultraSplicerQt > 0
    options.push(_INTL("{1} ({2})", unstable_splicer_const, unstableSplicerQt)) if unstableSplicerQt > 0
    options.push(_INTL("{1} ({2})", chaos_splicer_const, chaosSplicerQt)) if chaosSplicerQt > 0
    options.push(_INTL "{1}", infinite_splicers_const) if infiniteSplicers2Qt > 0 || infiniteSplicersQt > 0
    options.push(_INTL("{1} ({2})", super_splicers_const, superSplicersQt)) if superSplicersQt > 0
    options.push(_INTL("{1} ({2})", dna_splicers_const, dnaSplicersQt)) if dnaSplicersQt > 0

    if options.length <= 0
      pbDisplay(_INTL("You have no fusion items available."))
      return nil
    end

    cmd = pbShowCommands("Use which splicers?", options)
    if cmd == -1
      return nil
    end
    ret = options[cmd]
    if ret.start_with?(splice_boy_const)
      # Open Splice Boy Advance sub-menu
      chosen = SpliceBoyUI.select_fusion_type
      if chosen
        # Store the chosen splicer so we can deduct batteries after fusion
        @ghost_spliceboy_chosen = chosen
        return chosen
      end
      return nil
    elsif ret.start_with?(master_splicer_const)
      return :MASTERSPLICER
    elsif ret.start_with?(ultra_splicer_const)
      return :ULTRASPLICER
    elsif ret.start_with?(chaos_splicer_const)
      return :CHAOSSPLICER
    elsif ret.start_with?(unstable_splicer_const)
      return :UNSTABLESPLICER
    elsif ret.start_with?(dna_splicers_const)
      return :DNASPLICERS
    elsif ret.start_with?(super_splicers_const)
      return :SUPERSPLICERS
    elsif ret.start_with?(infinite_splicers_const)
      return infiniteSplicers2Qt >= 1 ? :INFINITESPLICERS2 : :INFINITESPLICERS
    end
    return nil
  end

  # Override isSuperSplicer? so dual ability splicers are recognized as a super splicer
  # in the PC fusion flow (for the preview screen)
  alias ghost_splicers_original_isSuperSplicer? isSuperSplicer?
  def isSuperSplicer?(item)
    return true if GhostSplicers.is_dual_ability_splicer?(item)
    return ghost_splicers_original_isSuperSplicer?(item)
  end

  # Override canDeleteItem so custom splicers are consumable (not infinite)
  # When the fusion was initiated via Splice Boy Advance, deduct batteries instead
  alias ghost_splicers_original_canDeleteItem canDeleteItem
  def canDeleteItem(item)
    return false if item == :SPLICEBOYADVANCE || item == :SPLICEBOYBATTERY
    # If this fusion came from Splice Boy Advance, deduct batteries instead
    if @ghost_spliceboy_chosen && GhostSplicers.is_ghost_splicer?(item)
      SpliceBoyUI.deduct_batteries(@ghost_spliceboy_chosen)
      @ghost_spliceboy_chosen = nil
      return false  # Don't try to delete the individual splicer item
    end
    return true if GhostSplicers.is_ghost_splicer?(item)
    return ghost_splicers_original_canDeleteItem(item)
  end
end

#===============================================================================
# SECTION 11: Kuray Shop Integration
# Patch PokemonMart_Scene to inject Splice Boy Advance and Spliceboy Battery
# into the Kuray Shop. Individual splicers are no longer sold.
#===============================================================================

class PokemonMart_Scene
  alias ghost_splicers_original_pbStartBuyOrSellScene pbStartBuyOrSellScene
  def pbStartBuyOrSellScene(buying, stock, adapter)
    # If this is the Kuray Shop, inject Splice Boy Advance + Battery
    # NOTE (2026-09-04): fromkurayshop is only ever defined on $game_temp by
    # the Kuray Shop's own code -- it's not a base Game_Temp attribute. Every
    # other mod that reads it (KantoReloaded, GhostBase_PlayerHousing) guards
    # with respond_to? first; this call site didn't, so any OTHER buy scene
    # (e.g. the Outfit hat/clothes shop, which reuses base PokemonMart_Scene)
    # crashed with NoMethodError the moment it opened, since $game_temp here
    # simply has no such method at all.
    if $game_temp && $game_temp.respond_to?(:fromkurayshop) && $game_temp.fromkurayshop
      has_spliceboy  = stock.any? { |s| s == GHOST_ITEM_SPLICEBOY_ADVANCE_ID || s == :SPLICEBOYADVANCE }
      has_battery    = stock.any? { |s| s == GHOST_ITEM_SPLICEBOY_BATTERY_ID || s == :SPLICEBOYBATTERY }
      unless has_spliceboy
        stock.push(GHOST_ITEM_SPLICEBOY_ADVANCE_ID)
        price = GhostSplicers.dev_mode? ? 1 : 100000
        $game_temp.mart_prices[GHOST_ITEM_SPLICEBOY_ADVANCE_ID] = [price, 0]
      end
      unless has_battery
        stock.push(GHOST_ITEM_SPLICEBOY_BATTERY_ID)
        price = GhostSplicers.dev_mode? ? 1 : 75000
        $game_temp.mart_prices[GHOST_ITEM_SPLICEBOY_BATTERY_ID] = [price, 0]
      end
    end
    ghost_splicers_original_pbStartBuyOrSellScene(buying, stock, adapter)
  end
end

#===============================================================================
# SECTION 11B: Boss Loot Integration
# Inject Spliceboy Battery into the epic tier boss loot pool.
#===============================================================================
if defined?(BossConfig) && BossConfig::LOOT[:epic] && BossConfig::LOOT[:epic][:pool].is_a?(Array)
  BossConfig::LOOT[:epic][:pool].push(:SPLICEBOYBATTERY) unless BossConfig::LOOT[:epic][:pool].include?(:SPLICEBOYBATTERY)
  echoln "[GhostSplicers] Spliceboy Battery added to boss epic loot pool."
end

#===============================================================================
# SECTION 12: Logging
#===============================================================================
echoln "[GhostSplicers] Splice Boy Advance system loaded successfully."

#===============================================================================
# SECTION 12: Visual Sprite Overrides
# Extends item sprite rendering so our custom splicers automatically inherit
# the DNA Splicer sprites, while applying live visual effects per splicer.
#===============================================================================

module GameData
  class Item
    class << self
      alias ghost_splicers_original_icon_filename icon_filename
      def icon_filename(item)
        item_id = GameData::Item.try_get(item)&.id
        if GhostSplicers.is_ghost_splicer?(item_id)
          return ghost_splicers_original_icon_filename(:DNASPLICERS)
        elsif item_id == :SPLICEBOYADVANCE
          return "Graphics/Items/POKEDEX"
        elsif item_id == :SPLICEBOYBATTERY
          return "Graphics/Items/BOXLINK"
        end
        return ghost_splicers_original_icon_filename(item)
      end
      
      alias ghost_splicers_original_held_icon_filename held_icon_filename
      def held_icon_filename(item)
        item_id = GameData::Item.try_get(item)&.id
        if GhostSplicers.is_ghost_splicer?(item_id)
          return ghost_splicers_original_held_icon_filename(:DNASPLICERS)
        elsif item_id == :SPLICEBOYADVANCE
          return "Graphics/Items/POKEDEX"
        elsif item_id == :SPLICEBOYBATTERY
          return "Graphics/Items/BOXLINK"
        end
        return ghost_splicers_original_held_icon_filename(item)
      end
    end
  end
end

module GhostSplicerIconAnimator
  @@cache_master = []
  @@cache_ultra = []
  @@initialized = false
  
  def self.init_caches
    return if @@initialized
    @@initialized = true
    
    # Fetch base DNA Splicers icon and clone to avoid modifying original caching
    icon_path = GameData::Item.ghost_splicers_original_icon_filename(:DNASPLICERS) rescue "Graphics/Icons/item_DNASPLICERS"
    anim = AnimatedBitmap.new(icon_path)
    base_bitmap = anim.bitmap.clone
    width = base_bitmap.width
    height = base_bitmap.height
    
    # 1. Cache Ultra Splicer (Tapered Cyan Outer Glow pulsing across 20 frames)
    # We identify outer layers for a 2-step gradient taper.
    layer1 = [] # 1px out
    layer2 = [] # 2px out
    (0...width).each do |x|
      (0...height).each do |y|
        next if base_bitmap.get_pixel(x,y).alpha > 128
        is_l1 = false
        is_l2 = false
        [[-1,0],[1,0],[0,-1],[0,1]].each do |dx, dy|
          nx, ny = x+dx, y+dy
          if nx>=0 && nx<width && ny>=0 && ny<height && base_bitmap.get_pixel(nx,ny).alpha > 128
            is_l1 = true; break
          end
        end
        if !is_l1
          [[-2,0],[2,0],[0,-2],[0,2],[-1,-1],[1,1],[-1,1],[1,-1]].each do |dx, dy|
            nx, ny = x+dx, y+dy
            if nx>=0 && nx<width && ny>=0 && ny<height && base_bitmap.get_pixel(nx,ny).alpha > 128
              is_l2 = true; break
            end
          end
        end
        layer1 << [x,y] if is_l1
        layer2 << [x,y] if is_l2
      end
    end
    
    20.times do |f|
      bmp = base_bitmap.clone
      pulse = ((Math.sin(f * Math::PI * 2.0 / 20.0) + 1.0) / 2.0)
      c_l1 = Color.new(0, 255, 255, (160 * pulse).to_i)
      c_l2 = Color.new(0, 255, 255, (80 * pulse).to_i)
      layer2.each { |x, y| bmp.set_pixel(x, y, c_l2) }
      layer1.each { |x, y| bmp.set_pixel(x, y, c_l1) }
      @@cache_ultra << bmp
    end
    
    # 2. Cache Master Splicer (Dual-Phase Rainbow: Gradient vs Outer Glow, 60 frames)
    60.times do |f|
      bmp = base_bitmap.clone
      phi = f * Math::PI * 2.0 / 60.0 # Phase
      
      # 1.0 = Max Internal Gradient (sin), 1.0 = Max Outer Glow (-sin)
      internal_intensity = (Math.sin(phi) + 1.0) / 2.0
      glow_intensity     = (1.0 - internal_intensity) # Anti-phase
      
      # Step A: Apply Outer Glow (Tapered Rainbow)
      # Inner Glow (L1) max alpha 150, Outer Glow (L2) max alpha 70
      [layer1, layer2].each_with_index do |layer, i|
        alpha_base = (i == 0) ? 150 : 70
        layer.each do |x, y|
          # Rainbow color based on Y + Time
          hue = ((y * 360 / height) + (f * 360 / 60)) % 360
          h = hue / 60.0; c = 200; xx = (c * (1 - ((h % 2) - 1).abs)).to_i
          r, g, b = 0, 0, 0
          case h.to_i
          when 0 then r = c; g = xx; b = 0
          when 1 then r = xx; g = c; b = 0
          when 2 then r = 0; g = c; b = xx
          when 3 then r = 0; g = xx; b = c
          when 4 then r = xx; g = 0; b = c
          else        r = c; g = 0; b = xx
          end
          bmp.set_pixel(x, y, Color.new(r, g, b, (alpha_base * glow_intensity).to_i))
        end
      end
      
      # Step B: Apply Internal Rainbow Gradient (subtle)
      (0...width).each do |x|
        (0...height).each do |y|
          pixel = bmp.get_pixel(x,y)
          next if pixel.alpha == 0 || layer1.include?([x,y]) || layer2.include?([x,y])
          
          hue = ((y * 360 / height) + (f * 360 / 60)) % 360
          h = hue / 60.0; c = 110; xx = (c * (1 - ((h % 2) - 1).abs)).to_i
          r, g, b = 0, 0, 0
          case h.to_i
          when 0 then r = c; g = xx; b = 0
          when 1 then r = xx; g = c; b = 0
          when 2 then r = 0; g = c; b = xx
          when 3 then r = 0; g = xx; b = c
          when 4 then r = xx; g = 0; b = c
          else        r = c; g = 0; b = xx
          end
          
          # Intensity multiplied by internal_intensity phase
          r = (r * 0.7 * internal_intensity).to_i
          g = (g * 0.7 * internal_intensity).to_i
          b = (b * 0.7 * internal_intensity).to_i
          
          bmp.set_pixel(x, y, Color.new([pixel.red+r,255].min, [pixel.green+g,255].min, [pixel.blue+b,255].min, pixel.alpha))
        end
      end
      @@cache_master << bmp
    end
  end

  def self.update_sprite(sprite, raw_item)
    return unless raw_item
    item_id = GameData::Item.try_get(raw_item)&.id
    if GhostSplicers.is_ghost_splicer?(item_id)
      self.init_caches # Ensure bitmaps are pre-baked
      time_ms = (Time.now.to_f * 1000).to_i
      
      sprite.changeOrigin if sprite.respond_to?(:changeOrigin)
      sprite.color = Color.new(0, 0, 0, 0) if sprite.color.alpha != 0
      sprite.tone  = Tone.new(0, 0, 0, 0) if sprite.tone.gray != 0 || sprite.tone.red != 0
      
      if GhostSplicers.is_master_splicer?(item_id)
        # Slowed down from 33 to 50 for a 3-second cycle (60 frames @ 20fps)
        frame = (time_ms / 50) % 60 
        sprite.bitmap = @@cache_master[frame] if @@cache_master[frame]
        sprite.opacity = 255

      elsif GhostSplicers.is_ultra_splicer?(item_id)
        frame = (time_ms / 50) % 20 # slightly slower pulse
        sprite.bitmap = @@cache_ultra[frame] if @@cache_ultra[frame]
        sprite.opacity = 255

      elsif GhostSplicers.is_unstable_splicer?(item_id)
        shake_x = (Math.sin(time_ms / 30.0) * 1.5).to_i
        shake_y = (Math.cos(time_ms / 35.0) * 1.5).to_i
        sprite.ox += shake_x
        sprite.oy += shake_y
        sprite.color = Color.new(255, 69, 0, 60) # Barely there orange glow
        sprite.opacity = 255

      elsif GhostSplicers.is_chaos_splicer?(item_id)
        fade = ((Math.sin(time_ms / 300.0) + 1.0) / 2.0) # 0.0 to 1.0
        # Min cap at 30% (76 out of 255)
        sprite.opacity = 76 + (179 * fade).to_i
        pulse = ((1.0 - fade) * 150).to_i
        sprite.color = Color.new(75, 0, 130, pulse + 50) # Dark purple pulse
      end
      
      sprite.instance_variable_set(:@ghost_splicer_fx_applied, true)
    elsif sprite.instance_variable_get(:@ghost_splicer_fx_applied)
      sprite.color = Color.new(0, 0, 0, 0)
      sprite.tone  = Tone.new(0, 0, 0, 0)
      sprite.opacity = 255
      sprite.changeOrigin if sprite.respond_to?(:changeOrigin)
      
      # Revert to standard item bitmap safely if it was hot-swapped
      if sprite.respond_to?(:item=)
        # Re-assign item forces native bitmap fetch
        cur_item = sprite.instance_variable_get(:@item)
        sprite.instance_variable_set(:@item, nil) 
        sprite.item = cur_item
      end
      sprite.instance_variable_set(:@ghost_splicer_fx_applied, false)
    end
  end
end

class ItemIconSprite
  alias ghost_splicers_anim_itemupdate update
  def update
    ghost_splicers_anim_itemupdate
    GhostSplicerIconAnimator.update_sprite(self, @item)
  end
end

class HeldItemIconSprite
  alias ghost_splicers_anim_helditemupdate update
  def update
    ghost_splicers_anim_helditemupdate
    GhostSplicerIconAnimator.update_sprite(self, @item)
  end
end

#===============================================================================
# SECTION 13: Gym Badge Spliceboy Battery Reward
# The player receives 1 Spliceboy Battery per gym badge earned.
# Hooks into the step taken event to passively track badge count and retroactively
# award batteries if the mod is installed mid-playthrough.
#===============================================================================
Events.onStepTaken += proc {
  if $Trainer && $PokemonBag
    # Initialize the tracker if it doesn't exist on the Trainer object yet
    # We use instance_variable_get/set to avoid undefined method errors if not explicitly declared in attr_accessor
    given = $Trainer.instance_variable_get(:@ghost_splicer_batteries_given) || 0
    current_badges = $Trainer.badge_count
    
    if current_badges > given
      diff = current_badges - given
      diff.times do
        $PokemonBag.pbStoreItem(:SPLICEBOYBATTERY)
      end
      
      if diff > 1
        pbMessage(_INTL("You found {1} Spliceboy Batteries tucked away in your Gym Badge Case!", diff))
      else
        pbMessage(_INTL("You found a Spliceboy Battery tucked away in your Gym Badge Case!"))
      end
      
      $Trainer.instance_variable_set(:@ghost_splicer_batteries_given, current_badges)
    end
  end
}

#===============================================================================
# SECTION 14: Shop Bypass for Spliceboy Battery
# Key items usually vanish from the shop once bought, and can only be bought
# 1 at a time. By forcing is_important? to false for the battery, we keep it
# as a key item (type 6 goes to pocket 8) but bypass the shop limits!
#===============================================================================
module GameData
  class Item
    alias ghost_splicers_shop_is_important? is_important?
    def is_important?
      # Allow the battery to be stacked and bought multiple times
      return false if @id == :SPLICEBOYBATTERY || @id_number == GHOST_ITEM_SPLICEBOY_BATTERY_ID
      return ghost_splicers_shop_is_important?
    end

    # Override price to return 1 if Dev Mode is active
    def price
      if defined?(GhostSplicers) && GhostSplicers.dev_mode?
        if GhostSplicers.is_ghost_splicer?(@id) || @id == :SPLICEBOYADVANCE || @id == :SPLICEBOYBATTERY
          return 1
        end
      end
      return @price
    end
  end
end
