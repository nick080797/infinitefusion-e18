################################################################################
# Crafting System — KIF Mod
#
# Combines ItemCraftingScene (recipe crafting UI + PC menu) with
# CraftingMaterialItems (drop-based crafting resources).
#
# INSTALL:
#   Single file — drop into your Mods folder.
#   Must load BEFORE any mod file that references crafting item symbols.
#
# POCKET 9 — "Resources":
#   All crafting materials land in a dedicated 9th bag pocket.
#   The pocket icon reuses pocket 1's sprite until you add a custom one to
#   Graphics/Pictures/Bag/icon_pocket.png (28px wide per icon at index 8).
#
# SPECIAL INGREDIENT FORMAT:
#   [:NAME_CONTAINS, qty, "substring"] — matches any item whose name includes
#   the given substring. Multiple NAME_CONTAINS slots with the same substring
#   draw from a shared pool (e.g. two slots of "Apricorn" = consume any 2
#   apricorns total, highest quantity first).
################################################################################


alias __craftdrop_obtainBadgeMessage obtainBadgeMessage
def obtainBadgeMessage(badgeName)
  __craftdrop_obtainBadgeMessage(badgeName)
  CraftingDrops.pbGiveBadgeResources(badgeName)
end

module RelicRegistry
  if defined?(RELICS)
    RELICS << Relic.new(:SMITHERHAMMER, "Smither's Hammer", "Grants a 1/50 chance to receive a random resource on crafting something.")
    RELICS << Relic.new(:GATHERER_RELIC, "Gatherer's Charm I", "Grants a 1/30 chance to receive double resources.", upgrades_to: :GATHERER_RELIC_II)
    RELICS << Relic.new(:GATHERER_RELIC_II, "Gatherer's Charm II", "Grants a 1/12 chance to receive double resources.")
  end
end


CRAFTING_MATERIALS = [
  # ── Type-based ──────────────────────────────────────────────────────────────
  { id: :EMBERSHARD,    name: "Flame Powder",        name_plural: "Flame Powders",
    description: "Residual heat left behind by Fire-type Pokémon. Used in crafting." },
  { id: :AQUAGEL,       name: "Aqua Gel",            name_plural: "Aqua Gels",
    description: "A slippery secretion from Water-type Pokémon. Used in crafting." },
  { id: :STONECHIP,     name: "Stone Chip",          name_plural: "Stone Chips",
    description: "A mineral fragment shed by Rock or Ground-type Pokémon. Used in crafting." },
  { id: :LEAFFIBER,     name: "Leaf Fiber",          name_plural: "Leaf Fibers",
    description: "Shed organic matter from Grass-type Pokémon. Used in crafting." },
  { id: :SPARKCELL,     name: "Spark Cell",          name_plural: "Spark Cells",
    description: "A static discharge crystal from Electric-type Pokémon. Used in crafting." },
  { id: :FROSTVEIL,     name: "Frost Veil",          name_plural: "Frost Veils",
    description: "A crystalline membrane shed by Ice-type Pokémon. Used in crafting." },
  { id: :SHADOWDUST,    name: "Shadow Dust",         name_plural: "Shadow Dusts",
    description: "Ectoplasmic residue from Ghost or Dark-type Pokémon. Used in crafting." },
  { id: :WINDSCALE,     name: "Wind Scale",          name_plural: "Wind Scales",
    description: "A shed feather or scale from Flying-type Pokémon. Used in crafting." },
  { id: :VENOMGLAND,    name: "Venom Gland",         name_plural: "Venom Glands",
    description: "A toxic sac extracted from Poison-type Pokémon. Used in crafting." },
  { id: :IRONSHAVING,   name: "Iron Shaving",        name_plural: "Iron Shavings",
    description: "Metallic particles shed by Steel-type Pokémon. Used in crafting." },
  { id: :PSYCHCRYSTAL,  name: "Psychic Crystal",     name_plural: "Psychic Crystals",
    description: "Crystallised psychic energy from Psychic-type Pokémon. Used in crafting." },
  { id: :DRACONICSCALE, name: "Draconic Scale",      name_plural: "Draconic Scales",
    description: "A common scale shed by Dragon-type Pokémon. Used in crafting." },
  { id: :FAIRYDUST,     name: "Fairy Dust",          name_plural: "Fairy Dusts",
    description: "Magical particles shed by Fairy-type Pokémon. Used in crafting." },
  { id: :BUGCHITIN,     name: "Bug Chitin",          name_plural: "Bug Chitins",
    description: "A shed exoskeleton fragment from Bug-type Pokémon. Used in crafting." },
  { id: :FIGHTCORE,     name: "Combat Core",         name_plural: "Combat Cores",
    description: "Residual aura crystallised from Fighting-type Pokémon. Used in crafting." },
  { id: :NORMCHIP,      name: "Simple Shard",        name_plural: "Simple Shards",
    description: "Generic biological matter from Normal-type Pokémon. Used in crafting." },
  # ── Egg group only ──────────────────────────────────────────────────────────
  { id: :ROUGHHIDE,     name: "Rough Hide",          name_plural: "Rough Hides",
    description: "A coarse hide fragment from Monster egg group Pokémon. Used in crafting." },
  { id: :AMORPHGEL,     name: "Sticky Blob",         name_plural: "Sticky Blobs",
    description: "A gelatinous secretion from Amorphous egg group Pokémon. Used in crafting." },
  { id: :MINERALCORE,   name: "Ancient Geode",       name_plural: "Ancient Geodes",
    description: "A dense crystal fragment from Mineral egg group Pokémon. Used in crafting." },
  { id: :DRAGONBONE,    name: "Dragon Bone",         name_plural: "Dragon Bones",
    description: "A bone fragment from Dragon egg group Pokémon of any type. Used in crafting." },
  # ── Egg group AND type ──────────────────────────────────────────────────────
  { id: :AQUASCALE,     name: "Aquatic Scale",       name_plural: "Aquatic Scales",
    description: "A scale from Water 1 egg group Water-type Pokémon. Used in crafting." },
  { id: :DEEPSCALE,     name: "Ancient Scale",       name_plural: "Ancient Scales",
    description: "A scale from Water 2 egg group Water-type Pokémon. Used in crafting." },
  { id: :CORALCHIP,     name: "Coral Tip",           name_plural: "Coral Tips",
    description: "A shell fragment from Water 3 egg group Water-type Pokémon. Used in crafting." },
  { id: :TRUEDRAGONFANG, name: "Elder Fang",         name_plural: "Elder Fangs",
    description: "A rare fang from Dragon egg group Dragon-type Pokémon. Used in crafting." },
  { id: :ARMORPLATE,    name: "Armor Plate",         name_plural: "Armor Plates",
    description: "Dense plating from Monster egg group Rock or Ground-type Pokémon. Used in crafting." },
  { id: :ECTOGEL,       name: "Ectoplasm Orb",       name_plural: "Ectoplasm Orbs",
    description: "True ectoplasm from Amorphous egg group Ghost-type Pokémon. Used in crafting." },
  { id: :VITALESSENCE,  name: "Aura Residue",        name_plural: "Aura Residues",
    description: "A potent residue from Human-Like egg group Fighting-type Pokémon. Used in crafting." },
]

################################################################################
# NAME_CONTAINS ingredient helpers
# Used by canCraft?, consumeIngredients, and ingredientText.
################################################################################

module NameContainsHelper
  # Returns all items in the bag whose name includes the substring.
  # Sorted highest quantity first for greedy consumption.
  def self.matching_items(substring)
    matches = []
    $PokemonBag.allItems.each do |item_id, qty|
      item = GameData::Item.get(item_id) rescue next
      matches << [item_id, qty] if item.name.include?(substring)
    end
    matches.sort_by { |_id, qty| -qty }
  end

  # Returns total quantity of all matching items.
  def self.total_qty(substring)
    matching_items(substring).sum { |_id, qty| qty }
  end

  # Consumes `needed` items from the matching pool, highest qty first.
  def self.consume(substring, needed)
    matching_items(substring).each do |item_id, _qty|
      have = $PokemonBag.quantityOf(item_id)
      take = [have, needed].min
      $PokemonBag.removeItem(item_id, take)
      needed -= take
      break if needed <= 0
    end
  end

  # Display label for a NAME_CONTAINS slot, e.g. "Any Apricorn: 1/1"
  def self.display_text(substring, needed)
    have = [total_qty(substring), needed].min
    "Any #{substring}: #{have}/#{needed}"
  end
end

################################################################################
# Pocket 9 — patch PokemonBag before items are registered
################################################################################

module Settings
  unless defined?(CRAFTING_POCKET_ADDED)
    CRAFTING_POCKET_ADDED = true
    BAG_POCKET_NAMES     = BAG_POCKET_NAMES     + ["Resources"] rescue nil
    BAG_POCKET_AUTO_SORT = BAG_POCKET_AUTO_SORT + [false]       rescue nil
  end
end

class PokemonBag
  class << self
    alias __craftdrop_numPockets  numPockets  rescue nil
    alias __craftdrop_pocketNames pocketNames rescue nil

    def numPockets
      n = __craftdrop_numPockets rescue 8
      [n, 9].max
    end

    def pocketNames
      names = (__craftdrop_pocketNames rescue nil) || []
      names[9] ||= "Resources"
      names
    end
  end

  alias __craftdrop_initialize initialize
  def initialize
    __craftdrop_initialize
    @pockets[9] ||= []
    @choices[9] ||= 0
  end

  alias __craftdrop_pockets pockets rescue nil
  def pockets
    p = __craftdrop_pockets
    p[9] ||= []
    return p
  end

  def maxPocketSize(pocket)
    return -1 if pocket == 9
    maxsize = Settings::BAG_MAX_POCKET_SIZE[pocket]
    return -1 if !maxsize
    return maxsize
  end

  def pbStoreItem(item, qty = 1)
    item = GameData::Item.get(item)
    pocket = item.pocket
    maxsize = maxPocketSize(pocket)
    if @pockets
      maxsize = @pockets[pocket].length + 1 if maxsize < 0
    end
    return ItemStorageHelper.pbStoreItem(
      @pockets[pocket], maxsize, Settings::BAG_MAX_PER_SLOT, item.id, qty, true)
  end

  def allItems
    items = []
    @pockets.each { |pocket| pocket.each { |item, qty| items.push([item, qty]) } }
    items
  end

  def quantityOf(item)
    item   = GameData::Item.get(item).id
    pocket = GameData::Item.get(item).pocket
    return 0 if @pockets[pocket] == nil
    ItemStorageHelper.pbQuantity(@pockets[pocket], item)
  end

  def removeItem(item, qty = 1)
    item   = GameData::Item.get(item).id
    pocket = GameData::Item.get(item).pocket
    ItemStorageHelper.pbDeleteItem(@pockets[pocket], item, qty)
  end

  def addItem(item, qty = 1)
    item    = GameData::Item.get(item).id
    pocket  = GameData::Item.get(item).pocket
    maxsize = maxPocketSize(pocket)
    maxsize = @pockets[pocket].length + 1 if maxsize < 0
    ItemStorageHelper.pbStoreItem(@pockets[pocket], maxsize, Settings::BAG_MAX_PER_SLOT, item, qty, true)
  end
end


class PokemonBag_Scene
  alias __craftdrop_pbStartScene pbStartScene
  def pbStartScene(*args)
    __craftdrop_pbStartScene(*args)
    CraftingMaterialItems.register_once!
    spr = @sprites["pocketicon"]
    old_bmp = spr.bitmap
    new_bmp = Bitmap.new(210, old_bmp.height)
    new_bmp.blt(0, 0, old_bmp, Rect.new(0, 0, old_bmp.width, old_bmp.height))
    spr.bitmap = new_bmp
  end

  alias __craftdrop_pbRefresh pbRefresh
  def pbRefresh
    __craftdrop_pbRefresh
    return unless @sprites["itemlist"].pocket == 9
    @sprites["background"].setBitmap("Graphics/Pictures/Bag/bg_1") rescue nil
    fbagexists = pbResolveBitmap("Graphics/Pictures/Bag/bag_1_f")
    if $Trainer.female? && fbagexists
      @sprites["bagsprite"].setBitmap("Graphics/Pictures/Bag/bag_1_f") rescue nil
    else
      @sprites["bagsprite"].setBitmap("Graphics/Pictures/Bag/bag_1") rescue nil
    end
    x_dest = 2 + (9 - 1) * 22
    @sprites["pocketicon"].bitmap.fill_rect(x_dest, 0, 32, 32, Color.new(0, 0, 0, 0))
    @sprites["pocketicon"].bitmap.blt(
      x_dest, 2,
      @pocketbitmap.bitmap,
      Rect.new(0, 0, 28, 28)
    )
  end
end

################################################################################
# Save data
################################################################################

class PokemonGlobalMetadata
  alias __crafting_sys_initialize initialize
  def initialize
    __crafting_sys_initialize
    @craft_count      = 0
    @craft_milestones = {}
  end

  def craft_count
    @craft_count ||= 0
  end

  def increase_craftcount
    @craft_count = craft_count + 1
    check_craft_milestones
  end

  def craft_milestones
    @craft_milestones ||= {}
  end

  def check_craft_milestones
    if craft_count >= 1 && !craft_milestones[1]
      craft_milestones[1] = true
      if defined?(RelicSystem)
        RelicSystem.give(:GATHERER_RELIC)
        pbMessage(_INTL("You crafted your first item and obtained the Gatherer's Charm relic!"))
      end
    end
    if craft_count >= 15 && !craft_milestones[15]
      craft_milestones[15] = true
      if defined?(RelicSystem)
        RelicSystem.give(:SMITHERHAMMER)
        pbMessage(_INTL("You have crafted 15 items and obtained the Smither's Hammer relic!"))
      end
    end
  end
end

################################################################################
# Crafting categories
################################################################################

CRAFTING_CATEGORIES = [
  { id: :ALL,        label: "All"        },
  { id: :CRAFTABLE,  label: "Craftable"  },
  { id: :POKEBALLS,  label: "Poké Balls" },
  { id: :EVOLUTION,  label: "Evolution"  },
  { id: :HELD_ITEMS, label: "Held Items" },
  { id: :CONSUMABLES,label: "Consumables"},
  { id: :MISC,       label: "Misc"       },
]

#===============================================================================
# Window_CraftingList
#===============================================================================
class Window_CraftingList < Window_DrawableCommand
  GREEN_COLOR   = Color.new(64,  200, 64)
  GREEN_SHADOW  = Color.new(16,  80,  16)
  YELLOW_COLOR  = Color.new(248, 216, 32)
  YELLOW_SHADOW = Color.new(100, 80,  8)
  RED_COLOR     = Color.new(224, 48,  48)
  RED_SHADOW    = Color.new(88,  8,   8)
  WHITE_COLOR   = Color.new(248, 248, 248)
  WHITE_SHADOW  = Color.new(0,   0,   0)

  attr_reader :category

  def self.craftStatus(recipe)
    total     = recipe[:ingredients].length
    have_full = 0
    have_any  = 0

    # Group NAME_CONTAINS slots by substring to check pool totals
    name_contains_totals = {}
    recipe[:ingredients].each do |slot|
      next unless slot[0] == :NAME_CONTAINS

      sub = slot[2]
      name_contains_totals[sub] ||= 0
      name_contains_totals[sub] += slot[1]
    end
    if name_contains_totals.length > 0
      total -= 1
    end
    recipe[:ingredients].each do |slot|
      if slot[0] == :NAME_CONTAINS

        sub    = slot[2]
        needed = name_contains_totals.delete(sub)  # only count once per group
        next unless needed
        pool = NameContainsHelper.total_qty(sub)
        have_full += 1 if pool >= needed
        have_any  += 1 if pool >= needed * 0.5
      else
        item, needed = slot
        next unless (GameData::Item.exists?(item) rescue false)
        qty = ($PokemonBag.quantityOf(item) rescue 0)
        have_full += 1 if qty >= needed
        have_any  += 1 if qty >= needed * 0.5
      end
    end

    return :full    if have_full == total
    return :partial if have_any  >= total * 0.5
    :none
  end

  def initialize(recipes, x, y, width, height)
    @recipes  = recipes
    @category = :ALL
    @selarrow = AnimatedBitmap.new("Graphics/Pictures/Bag/cursor")
    super(x, y, width, height)
    self.windowskin = nil
  end

  def dispose
    @selarrow.dispose if @selarrow && !@selarrow.disposed?
    super
  end

  def category=(cat)
    @category = cat
    self.index = 0
  end

  def itemCount
    @recipes.length + 1
  end

  def currentRecipe
    return nil if self.index >= @recipes.length
    @recipes[self.index]
  end

  def page_row_max;  return CraftingMenuScene::RECIPES_VISIBLE; end
  def page_item_max; return CraftingMenuScene::RECIPES_VISIBLE; end

  def drawCursor(index, rect)
    pbCopyBitmap(self.contents, @selarrow.bitmap, rect.x, rect.y + 25) if self.index == index
  end

  def drawItem(index, _count, rect)
    rect = Rect.new(rect.x + 16, rect.y + 16, rect.width - 16, rect.height)
    if index == @recipes.length
      pbDrawTextPositions(self.contents,
        [[_INTL("CLOSE"), rect.x, rect.y - 2, false, WHITE_COLOR, WHITE_SHADOW]])
      return
    end
    _key, recipe = @recipes[index]
    label  = ItemCraftingScene.resultText(recipe)
    color, shadow = case Window_CraftingList.craftStatus(recipe)
                    when :full    then [GREEN_COLOR,  GREEN_SHADOW]
                    when :partial then [YELLOW_COLOR, YELLOW_SHADOW]
                    else               [RED_COLOR,    RED_SHADOW]
                    end
    self.contents.font.size = 26
    pbDrawTextPositions(self.contents,
      [[label, rect.x, rect.y - 2, false, color, shadow]])
  end

  def refresh
    list = ItemCraftingScene::RECIPES.clone

    if defined?(RelicSystem) && !RelicSystem.has_any_tier?(:GOLDEN_EGG)
      list[:GOLDENEGG] = {
        ingredients: [[:LUCKYEGG, 1], [:BIGNUGGET, 2]],
        result:      [proc { RelicSystem.give(:GOLDEN_EGG) }],
        label:       "Golden Egg Relic",
        category:    :MISC,
      }
    end

    CRAFTING_MATERIALS.each do |mat|
      id = mat[:id]
      next if $PokemonBag.quantityOf(id) < 2
      list[id] = {
        ingredients: [[id, 2]],
        result:      [proc { CraftingDrops.give_rand_resource([id]) }],
        label:       "Random Resource",
        category:    :MISC,
      }
    end

    filtered = list.select do |_key, recipe|
      case @category
      when :ALL       then true
      when :CRAFTABLE then Window_CraftingList.craftStatus(recipe) == :full
      else                 recipe[:category] == @category
      end
    end

    @recipes  = filtered.map { |key, recipe| [key, recipe] }
    @item_max = itemCount
    self.update_cursor_rect
    dwidth  = self.width  - self.borderX
    dheight = self.height - self.borderY
    self.contents = pbDoEnsureBitmap(self.contents, dwidth, dheight)
    self.contents.clear
    for i in 0...@item_max
      next if i <= self.top_item - 1 || i > self.top_item + self.page_item_max
      drawItem(i, @item_max, itemRect(i))
    end
    drawCursor(self.index, itemRect(self.index))
  end

  def update
    super
    @uparrow.visible   = false
    @downarrow.visible = false
  end
end

#===============================================================================
# CraftingMenuScene
#===============================================================================
class CraftingMenuScene
  LISTBASECOLOR   = Color.new(88,  88,  80)
  LISTSHADOWCOLOR = Color.new(168, 184, 184)
  RECIPES_VISIBLE = 7

  ICON_SIZE       = 24
  ICON_PAD        = 4
  LINE_HEIGHT     = 38
  FULL_SIZE_ICONS = []

  TAB_Y       = 4
  TAB_HEIGHT  = 20
  TAB_PADDING = 6

  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end

  def pbStartScene(recipes)
    @recipes   = recipes
    @cat_index = 0
    @viewport  = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites   = {}

    @sprites["background"] = IconSprite.new(0, 0, @viewport)
    bg = pbResolveBitmap("Graphics/Pictures/Bag/bg_1")
    @sprites["background"].setBitmap(bg) if bg

    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    pbSetSystemFont(@sprites["overlay"].bitmap)

    @sprites["tabs"] = BitmapSprite.new(Graphics.width, TAB_HEIGHT + TAB_Y + 4, @viewport)
    pbSetSystemFont(@sprites["tabs"].bitmap)

    @sprites["list"] = Window_CraftingList.new(
      @recipes, 168, -8 + TAB_HEIGHT + TAB_Y, 314, 40 + 32 + RECIPES_VISIBLE * 32
    )
    @sprites["list"].viewport    = @viewport
    @sprites["list"].index       = 0
    @sprites["list"].baseColor   = LISTBASECOLOR
    @sprites["list"].shadowColor = LISTSHADOWCOLOR

    @sprites["itemicon"] = ItemIconSprite.new(48, Graphics.height - 48, nil, @viewport)

    @sprites["msgwindow"] = Window_AdvancedTextPokemon.new("")
    @sprites["msgwindow"].visible  = false
    @sprites["msgwindow"].viewport = @viewport

    pbDeactivateWindows(@sprites)
    pbRefreshTabs
    @sprites["list"].category = CRAFTING_CATEGORIES[@cat_index][:id]
    @sprites["list"].refresh
    pbRefreshDescription
    pbFadeInAndShow(@sprites)
  end

  def pbEndScene
    pbFadeOutAndHide(@sprites)
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end

  def pbDisplay(msg)
    UIHelper.pbDisplay(@sprites["msgwindow"], msg, true) { pbUpdate }
  end

  def pbConfirm(msg)
    UIHelper.pbConfirm(@sprites["msgwindow"], msg) { pbUpdate }
  end

  def pbRefreshTabs
    bmp = @sprites["tabs"].bitmap
    bmp.clear
    bmp.font.size = 16
    x = 4
    CRAFTING_CATEGORIES.each_with_index do |cat, i|
      label  = cat[:label]
      w      = bmp.text_size(label).width + TAB_PADDING * 2
      active = (i == @cat_index)
      bg_color = active ? Color.new(248, 248, 248) : Color.new(100, 100, 100)
      bmp.fill_rect(x, TAB_Y, w, TAB_HEIGHT, bg_color)
      bmp.fill_rect(x, TAB_Y, w, 1, Color.new(0, 0, 0))
      bmp.fill_rect(x, TAB_Y + TAB_HEIGHT - 1, w, 1, Color.new(0, 0, 0))
      bmp.fill_rect(x, TAB_Y, 1, TAB_HEIGHT, Color.new(0, 0, 0))
      bmp.fill_rect(x + w - 1, TAB_Y, 1, TAB_HEIGHT, Color.new(0, 0, 0))
      txt_color = active ? Color.new(32, 32, 32) : Color.new(220, 220, 220)
      pbDrawTextPositions(bmp, [[label, x + TAB_PADDING, TAB_Y + 1, false, txt_color, Color.new(0, 0, 0)]])
      x += w + 2
    end
  end

  def pbRefreshDescription
    overlay = @sprites["overlay"].bitmap
    desc_y  = 260
    overlay.fill_rect(0, desc_y, Graphics.width, Graphics.height - desc_y, Color.new(0, 0, 0, 0))

    pair = @sprites["list"].currentRecipe
    if pair.nil?
      @sprites["itemicon"].item = nil
      overlay.font.size = 24
      pbDrawTextPositions(overlay,
        [[_INTL("Close the crafting menu."), 72, desc_y + 25, false,
          Color.new(248, 248, 248), Color.new(0, 0, 0)]])
      return
    end

    _key, recipe = pair

    first_result = recipe[:result].first
    if first_result.is_a?(Proc)
      @sprites["itemicon"].item = nil
    else
      @sprites["itemicon"].item = (GameData::Item.exists?(first_result) rescue false) ? first_result : nil
    end

    icon_x = 84
    # Track NAME_CONTAINS slots already displayed so we show one line per group
    shown_name_contains = {}
    recipe[:ingredients].each_with_index do |slot, i|
      row_y = desc_y + LINE_HEIGHT * (i + 1)

      if slot[0] == :NAME_CONTAINS
        sub    = slot[2]
        needed = slot[1]
        # Accumulate total needed across repeated slots with same substring
        shown_name_contains[sub] ||= 0
        shown_name_contains[sub] += needed
        # Only draw the line once — when we see the last occurrence
        total_needed = recipe[:ingredients].select { |s| s[0] == :NAME_CONTAINS && s[2] == sub }.sum { |s| s[1] }
        next if shown_name_contains[sub] < total_needed

        have = [NameContainsHelper.total_qty(sub), total_needed].min
        ingr_color, ingr_shadow = if have >= total_needed
          [Color.new(64,  200, 64),  Color.new(16, 80, 16)]
        elsif have > 0
          [Color.new(248, 216, 32),  Color.new(100, 80, 8)]
        else
          [Color.new(224, 48,  48),  Color.new(88, 8,  8)]
        end
        overlay.font.size = 24
        pbDrawTextPositions(overlay,
          [["Any #{sub}: #{have}/#{total_needed}",
            icon_x + ICON_SIZE + ICON_PAD, row_y, false,
            ingr_color, ingr_shadow]])
      else
        item, needed = slot
        have  = ($PokemonBag.quantityOf(item) rescue 0)
        name  = (GameData::Item.exists?(item) rescue false) ? GameData::Item.get(item).name : item.to_s

        ingr_color, ingr_shadow = if have >= needed
          [Color.new(64,  200, 64),  Color.new(16, 80, 16)]
        elsif have >= needed * 0.5
          [Color.new(248, 216, 32),  Color.new(100, 80, 8)]
        else
          [Color.new(224, 48,  48),  Color.new(88, 8,  8)]
        end

        if (GameData::Item.exists?(item) rescue false)
          icon_bmp = Bitmap.new("Graphics/Items/" + GameData::Item.get(item).id.to_s) rescue nil
          if icon_bmp && !icon_bmp.disposed?
            draw_size = FULL_SIZE_ICONS.include?(item) ? icon_bmp.width : ICON_SIZE
            tmp = Bitmap.new(draw_size, draw_size)
            tmp.stretch_blt(
              Rect.new(0, 0, draw_size, draw_size),
              icon_bmp,
              Rect.new(0, 0, icon_bmp.width, icon_bmp.height)
            )
            overlay.blt(icon_x, row_y + (LINE_HEIGHT - draw_size) / 2 - LINE_HEIGHT / 2, tmp, Rect.new(0, 0, draw_size, draw_size))
            tmp.dispose
            icon_bmp.dispose
          end
        end

        overlay.font.size = 24
        pbDrawTextPositions(overlay,
          [["#{name}: #{have}/#{needed}",
            icon_x + ICON_SIZE + ICON_PAD, row_y, false,
            ingr_color, ingr_shadow]])
      end
    end
  end

  def pbChooseRecipe
    list = @sprites["list"]
    pbActivateWindow(@sprites, "list") {
      loop do
        oldindex = list.index
        Graphics.update
        Input.update
        pbUpdate

        if Input.trigger?(Input::LEFT)
          @cat_index = (@cat_index - 1) % CRAFTING_CATEGORIES.length
          pbPlayCursorSE
          pbRefreshTabs
          list.category = CRAFTING_CATEGORIES[@cat_index][:id]
          list.refresh
          pbRefreshDescription
        elsif Input.trigger?(Input::RIGHT)
          @cat_index = (@cat_index + 1) % CRAFTING_CATEGORIES.length
          pbPlayCursorSE
          pbRefreshTabs
          list.category = CRAFTING_CATEGORIES[@cat_index][:id]
          list.refresh
          pbRefreshDescription
        end

        if list.index != oldindex
          pbPlayCursorSE
          list.refresh
          pbRefreshDescription
        end

        if Input.trigger?(Input::BACK)
          pbPlayCloseMenuSE
          return nil
        elsif Input.trigger?(Input::USE)
          if list.index == list.itemCount - 1
            pbPlayCloseMenuSE
            return nil
          end
          pbPlayDecisionSE
          return list.currentRecipe
        end
      end
    }
  end
end

#===============================================================================
# ItemCraftingScene — recipe data + helpers
#===============================================================================
class ItemCraftingScene
  RECIPES = {
    # ── Poké Balls ───────────────────────────────────────────────────────────────
    APRICORN_BALL: {
      ingredients: [[:NAME_CONTAINS, 1, "Apricorn"], [:NAME_CONTAINS, 1, "Apricorn"]],
      result:      [:POKEBALL],
      category:    :POKEBALLS,
      label:       "Poké Ball",
    },
    ULTRABALL: {
      ingredients: [[:GREATBALL, 2], [:IRONSHAVING, 1]],
      result:      [:ULTRABALL],
      category:    :POKEBALLS,
    },
    DIVEBALL: {
      ingredients: [[:POKEBALL, 1], [:AQUAGEL, 2]],
      result:      [:DIVEBALL],
      category:    :POKEBALLS,
    },
    DUSKBALL: {
      ingredients: [[:POKEBALL, 1], [:SHADOWDUST, 2]],
      result:      [:DUSKBALL],
      category:    :POKEBALLS,
    },
    NETBALL: {
      ingredients: [[:POKEBALL, 1], [:BUGCHITIN, 2], [:AQUAGEL, 1]],
      result:      [:NETBALL],
      category:    :POKEBALLS,
    },
    REPEATBALL: {
      ingredients: [[:POKEBALL, 1], [:NORMCHIP, 3]],
      result:      [:REPEATBALL],
      category:    :POKEBALLS,
    },
    TIMERBALL: {
      ingredients: [[:POKEBALL, 1], [:NORMCHIP, 2], [:STONECHIP, 1]],
      result:      [:TIMERBALL],
      category:    :POKEBALLS,
    },

    # ── Evolution Items ──────────────────────────────────────────────────────────
    SUN_STONE: {
      ingredients: [[:STONECHIP, 4], [:EMBERSHARD, 2]],
      result:      [:SUNSTONE],
      category:    :EVOLUTION,
    },
    MOON_STONE: {
      ingredients: [[:STONECHIP, 4], [:SHADOWDUST, 2]],
      result:      [:MOONSTONE],
      category:    :EVOLUTION,
    },
    SHINYSTONE: {
      ingredients: [[:PSYCHCRYSTAL, 2], [:FAIRYDUST, 2], [:STONECHIP, 2]],
      result:      [:SHINYSTONE],
      category:    :EVOLUTION,
    },
    DAWNSTONE: {
      ingredients: [[:PSYCHCRYSTAL, 3], [:SPARKCELL, 2]],
      result:      [:DAWNSTONE],
      category:    :EVOLUTION,
    },
    DUSKSTONE: {
      ingredients: [[:SHADOWDUST, 3], [:STONECHIP, 2]],
      result:      [:DUSKSTONE],
      category:    :EVOLUTION,
    },
    DRAGONSCALE_ITEM: {
      ingredients: [[:DRAGONBONE, 2], [:DRACONICSCALE, 4]],
      result:      [:DRAGONSCALE],
      category:    :EVOLUTION,
    },
    METALCOAT: {
      ingredients: [[:IRONSHAVING, 5]],
      result:      [:METALCOAT],
      category:    :EVOLUTION,
    },
    KINGSROCK: {
      ingredients: [[:FIGHTCORE, 3], [:STONECHIP, 3]],
      result:      [:KINGSROCK],
      category:    :EVOLUTION,
    },
    PRISMSCALE: {
      ingredients: [[:FAIRYDUST, 3], [:AQUASCALE, 2]],
      result:      [:PRISMSCALE],
      category:    :EVOLUTION,
    },
    UPGRADE: {
      ingredients: [[:IRONSHAVING, 3], [:SPARKCELL, 3], [:PSYCHCRYSTAL, 1]],
      result:      [:UPGRADE],
      category:    :EVOLUTION,
    },

    # ── Type-Boosting Held Items ─────────────────────────────────────────────────
    CHARCOAL: {
      ingredients: [[:EMBERSHARD, 5]],
      result:      [:CHARCOAL],
      category:    :HELD_ITEMS,
    },
    MYSTICWATER: {
      ingredients: [[:AQUAGEL, 5]],
      result:      [:MYSTICWATER],
      category:    :HELD_ITEMS,
    },
    MIRACLESEED: {
      ingredients: [[:LEAFFIBER, 5]],
      result:      [:MIRACLESEED],
      category:    :HELD_ITEMS,
    },
    MAGNET: {
      ingredients: [[:SPARKCELL, 5]],
      result:      [:MAGNET],
      category:    :HELD_ITEMS,
    },
    NEVERMELTICE: {
      ingredients: [[:FROSTVEIL, 5]],
      result:      [:NEVERMELTICE],
      category:    :HELD_ITEMS,
    },
    SPELLTAG: {
      ingredients: [[:SHADOWDUST, 5]],
      result:      [:SPELLTAG],
      category:    :HELD_ITEMS,
    },
    SHARPBEAK: {
      ingredients: [[:WINDSCALE, 5]],
      result:      [:SHARPBEAK],
      category:    :HELD_ITEMS,
    },
    POISONBARB: {
      ingredients: [[:VENOMGLAND, 5]],
      result:      [:POISONBARB],
      category:    :HELD_ITEMS,
    },
    HARDSTONE: {
      ingredients: [[:STONECHIP, 5]],
      result:      [:HARDSTONE],
      category:    :HELD_ITEMS,
    },
    TWISTEDSPOON: {
      ingredients: [[:PSYCHCRYSTAL, 5]],
      result:      [:TWISTEDSPOON],
      category:    :HELD_ITEMS,
    },
    DRAGONFANG: {
      ingredients: [[:DRACONICSCALE, 5]],
      result:      [:DRAGONFANG],
      category:    :HELD_ITEMS,
    },
    SILVERPOWDER: {
      ingredients: [[:BUGCHITIN, 5]],
      result:      [:SILVERPOWDER],
      category:    :HELD_ITEMS,
    },
    BLACKBELT: {
      ingredients: [[:FIGHTCORE, 5]],
      result:      [:BLACKBELT],
      category:    :HELD_ITEMS,
    },
    LEFTOVERS: {
      ingredients: [[:NORMCHIP, 3], [:LEAFFIBER, 2], [:AQUAGEL, 2]],
      result:      [:LEFTOVERS],
      category:    :HELD_ITEMS,
    },
    ROCKYHELMET: {
      ingredients: [[:STONECHIP, 4], [:IRONSHAVING, 3]],
      result:      [:ROCKYHELMET],
      category:    :HELD_ITEMS,
    },
    CHOICESCARF: {
      ingredients: [[:WINDSCALE, 4], [:FIGHTCORE, 2]],
      result:      [:CHOICESCARF],
      category:    :HELD_ITEMS,
    },
    CHOICEBAND: {
      ingredients: [[:FIGHTCORE, 4], [:ROUGHHIDE, 3]],
      result:      [:CHOICEBAND],
      category:    :HELD_ITEMS,
    },
    CHOICESPECS: {
      ingredients: [[:PSYCHCRYSTAL, 4], [:FAIRYDUST, 2]],
      result:      [:CHOICESPECS],
      category:    :HELD_ITEMS,
    },
    LIFEORB: {
      ingredients: [[:TRUEDRAGONFANG, 2], [:VITALESSENCE, 3]],
      result:      [:LIFEORB],
      category:    :HELD_ITEMS,
    },
    ASSAULTVEST: {
      ingredients: [[:IRONSHAVING, 4], [:ROUGHHIDE, 3], [:FIGHTCORE, 1]],
      result:      [:ASSAULTVEST],
      category:    :HELD_ITEMS,
    },

    # ── Consumables ──────────────────────────────────────────────────────────────
    HYPERPOTION: {
      ingredients: [[:POTION, 2], [:SUPERPOTION, 1]],
      result:      [:HYPERPOTION],
      category:    :CONSUMABLES,
    },
    FULLHEAL: {
      ingredients: [[:ANTIDOTE, 1], [:PARLYZHEAL, 1]],
      result:      [:FULLHEAL],
      category:    :CONSUMABLES,
    },
    REVIVE: {
      ingredients: [[:DRAGONBONE, 1], [:VITALESSENCE, 2]],
      result:      [:REVIVE],
      category:    :CONSUMABLES,
    },
    ESCAPEROPE: {
      ingredients: [[:LEAFFIBER, 3], [:WINDSCALE, 1]],
      result:      [:ESCAPEROPE],
      category:    :CONSUMABLES,
    },
    REPEL: {
      ingredients: [[:VENOMGLAND, 2]],
      result:      [:REPEL],
      category:    :CONSUMABLES,
    },
    SUPERREPEL: {
      ingredients: [[:VENOMGLAND, 4]],
      result:      [:SUPERREPEL],
      category:    :CONSUMABLES,
    },
  }

  def self.canCraft?(recipe)
    # Group NAME_CONTAINS slots by substring to check pool totals once
    name_contains_needed = {}
    recipe[:ingredients].each do |slot|
      next unless slot[0] == :NAME_CONTAINS
      name_contains_needed[slot[2]] ||= 0
      name_contains_needed[slot[2]] += slot[1]
    end

    recipe[:ingredients].all? do |slot|
      if slot[0] == :NAME_CONTAINS
        sub    = slot[2]
        needed = name_contains_needed.delete(sub)
        next true unless needed  # already checked this group
        NameContainsHelper.total_qty(sub) >= needed
      else
        item, qty = slot
        next false unless (GameData::Item.exists?(item) rescue false)
        $PokemonBag.quantityOf(item) >= qty
      end
    end
  end

  def self.ingredientText(recipe)
    # Collapse NAME_CONTAINS slots into one label per substring
    name_contains_totals = {}
    recipe[:ingredients].each do |slot|
      next unless slot[0] == :NAME_CONTAINS
      name_contains_totals[slot[2]] ||= 0
      name_contains_totals[slot[2]] += slot[1]
    end
    shown = {}
    parts = recipe[:ingredients].map do |slot|
      if slot[0] == :NAME_CONTAINS
        sub = slot[2]
        next nil if shown[sub]
        shown[sub] = true
        "#{name_contains_totals[sub]}x Any #{sub}"
      else
        item, qty = slot
        name = (GameData::Item.exists?(item) rescue false) ? GameData::Item.get(item).name : item.to_s
        "#{qty}x #{name}"
      end
    end.compact
    parts.join(", ")
  end

  def self.resultText(recipe)
    recipe[:result].map do |r|
      if r.is_a?(Proc)
        recipe[:label] || "Special Effect"
      else
        (GameData::Item.exists?(r) rescue false) ? GameData::Item.get(r).name : r.to_s
      end
    end.join(" + ")
  end

  def self.consumeIngredients(recipe)
    # Group NAME_CONTAINS slots first
    name_contains_needed = {}
    recipe[:ingredients].each do |slot|
      next unless slot[0] == :NAME_CONTAINS
      name_contains_needed[slot[2]] ||= 0
      name_contains_needed[slot[2]] += slot[1]
    end
    consumed_groups = {}
    recipe[:ingredients].each do |slot|
      if slot[0] == :NAME_CONTAINS
        sub = slot[2]
        next if consumed_groups[sub]
        consumed_groups[sub] = true
        NameContainsHelper.consume(sub, name_contains_needed[sub])
      else
        item, qty = slot
        $PokemonBag.removeItem(item, qty)
      end
    end
  end

  def startCrafting
    CraftingMaterialItems.register_once!
    scene = CraftingMenuScene.new
    scene.pbStartScene([])

    loop do
      pair = scene.pbChooseRecipe
      break unless pair

      key, recipe = pair

      unless ItemCraftingScene.canCraft?(recipe)
        scene.pbDisplay(_INTL("You don't have the required ingredients."))
        next
      end

      result_str = ItemCraftingScene.resultText(recipe)
      ingr_str   = ItemCraftingScene.ingredientText(recipe)
      next unless scene.pbConfirm(_INTL("Craft {1}?\nRequires: {2}", result_str, ingr_str))

      ItemCraftingScene.consumeIngredients(recipe)

      recipe[:result].each do |r|
        if r.is_a?(Proc)
          r.call
        else
          $PokemonBag.addItem(r, 1)
        end
      end

      scene.pbDisplay(_INTL("You crafted {1}!", result_str))

      if defined?(RelicSystem) && RelicSystem.active?(:SMITHERHAMMER) && rand(50) == 0
        CraftingDrops.give_rand_resource
      end

      $PokemonGlobal.increase_craftcount
      scene.instance_variable_get(:@sprites)["list"].refresh
      scene.pbRefreshDescription
    end

    scene.pbEndScene
  end
end

class ItemCraftingScreen
  def initialize(scene)
    @scene = scene
  end

  def openCraftingMenu
    @scene.startCrafting
  end
end

def openItemCrafting
  ItemCraftingScreen.new(ItemCraftingScene.new).openCraftingMenu
end

#===============================================================================
# CraftingPC
#===============================================================================

class CraftingPC
  def shouldShow?; true; end
  def name;        _INTL("Open Crafting Menu"); end
  def access
    pbMessage(_INTL("\\se[PC access]Accessing the Crafting Menu..."))
    openItemCrafting
  end
end

PokemonPCList.registerPC(CraftingPC.new)

################################################################################
# CraftingMaterialItems
################################################################################
class DropSystem
  attr_accessor :item_queue
  attr_accessor :resource_battle
  ALWAYS_DROP = true

  def self.initialize
    @item_queue      = []
    @resource_battle = nil
  end

  def self.set_battle(b);   @resource_battle = b; end
  def self.set_queue(q);    @item_queue = q; end
  def self.item_queue;      @item_queue; end
  def self.resource_battle; @resource_battle; end
end

module CraftingMaterialItems
  START_ID = 9000

  @registered = false
  @ticked     = false

  def self.tick!
    return if @ticked
    @ticked = true
  end

  def self.register_once!
    return if @registered
    return unless defined?(GameData::Item) &&
                  GameData::Item.respond_to?(:register) &&
                  defined?(MessageTypes)

    used = {}
    begin
      GameData::Item.each { |it| n = it.id_number rescue nil; used[n] = true if n.is_a?(Integer) }
    rescue; end

    next_id = START_ID

    CRAFTING_MATERIALS.each do |mat|
      next if (GameData::Item.exists?(mat[:id]) rescue false)
      next_id += 1 while used[next_id]
      id = next_id
      next_id += 1

      GameData::Item.register({
        id:          mat[:id],
        id_number:   id,
        name:        mat[:name],
        name_plural: mat[:name_plural],
        pocket:      9,
        price:       0,
        description: mat[:description],
        field_use:   0,
        battle_use:  0,
        type:        0,
        move:        nil
      })
      MessageTypes.set(MessageTypes::Items,            id, mat[:name])
      MessageTypes.set(MessageTypes::ItemPlurals,      id, mat[:name_plural])
      MessageTypes.set(MessageTypes::ItemDescriptions, id, mat[:description])

      used[id] = true
      echoln "[CraftingMaterials] Registered #{mat[:id]} as id_number #{id}" if $DEBUG
    end

    @registered = true
  rescue => e
    echoln "[CraftingMaterials] register_once! error: #{e}"
  end
end

unless $__craftmat_gfx_hooked
  $__craftmat_gfx_hooked = true
  if defined?(Graphics) && Graphics.respond_to?(:update)
    class << Graphics
      alias __craftmat_gfx_update update
      def update(*a)
        __craftmat_gfx_update(*a)
        CraftingMaterialItems.tick!
      end
    end
  end
end

################################################################################
# Drop tables
################################################################################

module CraftingDrops
  TYPE_DROPS = {
    FIRE:     { item: :EMBERSHARD,    rate: 40 },
    WATER:    { item: :AQUAGEL,       rate: 40 },
    ROCK:     { item: :STONECHIP,     rate: 40 },
    GROUND:   { item: :STONECHIP,     rate: 35 },
    GRASS:    { item: :LEAFFIBER,     rate: 40 },
    ELECTRIC: { item: :SPARKCELL,     rate: 40 },
    ICE:      { item: :FROSTVEIL,     rate: 35 },
    GHOST:    { item: :SHADOWDUST,    rate: 35 },
    DARK:     { item: :SHADOWDUST,    rate: 30 },
    FLYING:   { item: :WINDSCALE,     rate: 40 },
    POISON:   { item: :VENOMGLAND,    rate: 40 },
    STEEL:    { item: :IRONSHAVING,   rate: 35 },
    PSYCHIC:  { item: :PSYCHCRYSTAL,  rate: 30 },
    DRAGON:   { item: :DRACONICSCALE, rate: 20 },
    FAIRY:    { item: :FAIRYDUST,     rate: 30 },
    BUG:      { item: :BUGCHITIN,     rate: 45 },
    FIGHTING: { item: :FIGHTCORE,     rate: 40 },
    NORMAL:   { item: :NORMCHIP,      rate: 50 },
  }

  EGG_GROUP_DROPS = {
    Dragon:    [
      { item: :TRUEDRAGONFANG, rate: 12, also_type: :DRAGON },
      { item: :DRAGONBONE,     rate: 20 },
    ],
    Monster:   [
      { item: :ARMORPLATE, rate: 15, also_type: [:ROCK, :GROUND] },
      { item: :ROUGHHIDE,  rate: 25 },
    ],
    Amorphous: [
      { item: :ECTOGEL,   rate: 15, also_type: :GHOST },
      { item: :AMORPHGEL, rate: 25 },
    ],
    HumanLike: [
      { item: :VITALESSENCE, rate: 18, also_type: :FIGHTING },
    ],
    Water1:  [{ item: :AQUASCALE,   rate: 25, also_type: :WATER }],
    Water2:  [{ item: :DEEPSCALE,   rate: 20, also_type: :WATER }],
    Water3:  [{ item: :CORALCHIP,   rate: 20, also_type: :WATER }],
    Mineral: [{ item: :MINERALCORE, rate: 20 }],
  }

  BADGE_REWARDS = {
    "Boulder Badge" => [[:STONECHIP, 5], [:ROUGHHIDE, 3]],
    "Cascade Badge" => [[:AQUAGEL, 5],   [:AQUASCALE, 3]],
    "Thunder Badge" => [[:SPARKCELL, 5], [:WINDSCALE, 2]],
    "Rainbow Badge" => [[:LEAFFIBER, 5], [:FAIRYDUST, 2]],
    "Soul Badge"    => [[:VENOMGLAND, 5],   [:AMORPHGEL, 2]],
    "Marsh Badge"   => [[:PSYCHCRYSTAL, 5]],
    "Volcano Badge" => [[:EMBERSHARD, 5],   [:DRAGONBONE, 2]],
    "Earth Badge"   => [[:SHADOWDUST, 5],   [:NORMCHIP, 3]],
    "Zephyr Badge"  => [[:WINDSCALE, 5],    [:NORMCHIP, 2]],
    "Hive Badge"    => [[:BUGCHITIN, 5],    [:LEAFFIBER, 2]],
    "Plain Badge"   => [[:NORMCHIP, 5],     [:LEAFFIBER, 2]],
    "Fog Badge"     => [[:SHADOWDUST, 5],   [:AMORPHGEL, 2]],
    "Storm Badge"   => [[:WINDSCALE, 5],    [:SPARKCELL, 3]],
    "Mineral Badge" => [[:STONECHIP, 5],    [:IRONSHAVING, 3]],
    "Glacier Badge" => [[:FROSTVEIL, 5],    [:AQUAGEL, 2]],
    "Rising Badge"  => [[:DRACONICSCALE, 5],[:TRUEDRAGONFANG, 1]],
  }

  GATHER_ODDS = {
    :GATHERER_RELIC    => 30,
    :GATHERER_RELIC_II => 12,
  }

  def self.pbGiveBadgeResources(badge)
    rewards = BADGE_REWARDS[badge]
    return unless rewards
    CraftingMaterialItems.register_once!
    reward_names = []
    rewards.each do |item, qty|
      if defined?(RelicSystem)
        active = RelicSystem.active
        gather_odds = GATHER_ODDS[active] || 0
        qty *= 2 if gather_odds > 0 && rand(gather_odds) == 0
      end
      qty.times { $PokemonBag.pbStoreItem(item) }
      name = (GameData::Item.exists?(item) rescue false) ? GameData::Item.get(item).name : item.to_s
      reward_names << "#{qty}x #{name}"
    end
    pbMessage(_INTL("You received a resource bundle!\n#{reward_names.join(", ")}"))
  end

  def self.give_rand_resource(blacklist = [])
    item_sym = nil
    attempts = 0
    available = TYPE_DROPS.reject { |_type, entry| blacklist.include?(entry[:item]) }
    return if available.empty?
    while item_sym.nil?
      available.each do |_type, entry|
        if rand(100) < entry[:rate]
          item_sym = entry[:item]
          break
        end
      end
      attempts += 1
      break if attempts > 100
    end
    return unless item_sym
    qty = 1
    if defined?(RelicSystem)
      active = RelicSystem.active
      gather_odds = GATHER_ODDS[active] || 0
      qty *= 2 if gather_odds > 0 && rand(gather_odds) == 0
    end
    if $PokemonBag.pbStoreItem(item_sym, qty)
      pbMessage(_INTL("You obtained {1} {2}!", qty, GameData::Item.get(item_sym).name))
    end
  end

  def self.pbTryDrop(battle, defeatedBattler)
    return unless battle.wildBattle?
    pkmn = defeatedBattler.pokemon
    return unless pkmn

    type_drop     = nil
    egggroup_drop = nil

    [pkmn.type1, pkmn.type2].each do |type|
      next unless type
      entry = TYPE_DROPS[type]
      next unless entry
      next unless (GameData::Item.exists?(entry[:item]) rescue false)
      if rand(100) < entry[:rate] || (DropSystem::ALWAYS_DROP && $DEBUG)
        type_drop = entry[:item]
        break
      end
    end

    echoln type_drop if $DEBUG

    egg_groups = (pkmn.species_data.egg_groups rescue []) || []
    if egg_groups.is_a?(Array)
    egg_groups.each do |group|
      next if !EGG_GROUP_DROPS.include?(group)
      entries = EGG_GROUP_DROPS[group]
      next unless entries
      entries.each do |entry|
        if entry[:also_type]
          required = Array(entry[:also_type])
          next unless required.any? { |t| pkmn.hasType?(t) rescue false }
        end
        next unless (GameData::Item.exists?(entry[:item]) rescue false)
        if rand(100) < entry[:rate]
          egggroup_drop = entry[:item]
          break
        end
      end
      break if egggroup_drop
    end
    end

    [type_drop, egggroup_drop].compact.uniq.each do |item_sym|
      next unless GameData::Item.exists?(item_sym)
      qty = 1
      if defined?(RelicSystem)
        active = RelicSystem.active
        gather_odds = GATHER_ODDS[active] || 0
        qty *= 2 if gather_odds > 0 && rand(gather_odds) == 0
      end
      if $PokemonBag.pbStoreItem(item_sym, qty)
        pbMessage(_INTL("You found {1} {2}!", qty, GameData::Item.get(item_sym).name))
        echoln "[CraftingDrop] #{pkmn.name} (#{pkmn.type1}/#{pkmn.type2}) dropped #{item_sym}" if $DEBUG
      end
    end
  end
end

################################################################################
# Hook into pbGainExp
################################################################################

class PokeBattle_Battle
  alias __craftdrop_pbGainExp pbGainExp
  def pbGainExp
    DropSystem.set_battle(nil)
    if wildBattle?
      CraftingMaterialItems.register_once!
      queue = []
      @battlers.each do |b|
        next unless b && b.opposes? && b.fainted?
        next if b.participants.empty?
        queue << b
      end
      DropSystem.set_queue(queue)
      DropSystem.set_battle(self)
    end
    __craftdrop_pbGainExp
  end
end

Events.onEndBattle += proc { |_sender, e|
  if DropSystem.resource_battle != nil
    DropSystem.item_queue.each do |b|
      CraftingDrops.pbTryDrop(DropSystem.resource_battle, b)
    end
    DropSystem.set_queue([])
  end
}
