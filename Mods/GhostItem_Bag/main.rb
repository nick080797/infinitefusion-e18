#===============================================================================
# GhostBag.rb
# A mod that modernizes the Kuray Infinite Fusion inventory by replacing the
# static vanilla pockets with an automated, function-first sorting engine.
#===============================================================================

module Settings
  # Override the pocket names to match the new 8 categories
  def self.bag_pocket_names
    return [
      _INTL("TM & HM"),
      _INTL("Medicine"),
      _INTL("Status & Battle"),
      _INTL("Capture & Mutate"),
      _INTL("Held Items"),
      _INTL("Enhancers"),
      _INTL("Field Utility"),
      _INTL("Treasures"),
      _INTL("Key Items")
    ]
  end
end

# In-place patch of the Bag pocket size array
# We need exactly 9 elements (0 for dummy/hidden, 1-8 for visible pockets).
Settings::BAG_MAX_POCKET_SIZE.clear
Settings::BAG_MAX_POCKET_SIZE.concat([-1, -1, -1, -1, -1, -1, -1, -1, -1])

# In-place patch of the Auto Sort flags
Settings::BAG_POCKET_AUTO_SORT.clear
Settings::BAG_POCKET_AUTO_SORT.concat([0, false, false, false, false, false, false, false, false])

# Override Item's pocket method to use the heuristic logic
module GameData
  class Item
    def ghost_bag_pocket
      # Priority 0: Dummy Pocket for TMs, HMs, and Mail (hidden from standard loop)
      return 0 if is_machine? || is_mail?
      
      # Priority 8: Key Items (Unique, un-tossable progression tools)
      return 8 if is_key_item? || is_important?
      
      desc = self.description.downcase
      name_str = (self.real_name || "").downcase

      # Priority 7 explicit strings for Treasures
      is_treasure = name_str.match?(/\b(fossil|amber|scale|nugget|pearl|star piece|stardust|mushroom|relic|shard|comet|bottle cap|bone)\b/)
      return 7 if is_treasure

      # Priority 3: Capture & Mutation (Tools for acquiring and modifying species)
      if is_poke_ball? || is_snag_ball? || is_evolution_stone? || 
         desc.match?(/\bevolves?\b/) || desc.match?(/\bdevolves?\b/) || desc.match?(/\bmutation\b/) || 
         desc.match?(/\bfuse[ds]?\b/) || desc.match?(/\bsplicer\b/) || desc.match?(/\breverser\b/) ||
         name_str.include?("dna") || name_str.include?("splicer") || name_str.include?("reverser") ||
         name_str.include?("fusion") || name_str.include?("devolution") || 
         name_str.include?("gender") || name_str.include?("resonator")
        return 3
      end
                  
      # Exception for Held Items that might be caught by Medicine, Enhancers, or Battle Consumables
      is_held_gear = (!is_berry? && self.can_hold? && (desc.match?(/\bhold\b/) || desc.match?(/\bheld\b/) || 
                               is_mega_stone? || is_gem? || name_str.include?("plate") || 
                               name_str.include?("drive") || name_str.include?("memory") || 
                               name_str.include?("band") || name_str.include?("scarf") || 
                               name_str.include?("specs") || name_str.include?("leftovers") ||
                               name_str.include?("vest") || name_str.include?("belt") || name_str.include?("lens") ||
                               (name_str.include?("incense") && !(desc.include?("step") || desc.include?("attract"))) ||
                               name_str.include?("exp. share")))

      # Priority 5: Enhancers (Permanent stat, ability, and nature modifiers)
      if (name_str.include?("mint") || name_str.include?("candy") || 
         desc.match?(/\bbase\b/) || desc.match?(/\bbase stat\b/) || desc.match?(/\bbase points\b/) || 
         desc.match?(/\blevel\b/) || desc.match?(/\bability\b/) || 
         desc.match?(/\bnature\b/) || desc.match?(/\beffort values\b/) || desc.match?(/\bexp\./) ||
         name_str.include?("hp up") || name_str.include?("protein") || name_str.include?("iron") || 
         name_str.include?("calcium") || name_str.include?("zinc") || name_str.include?("carbos") || 
         name_str.include?("pp up") || name_str.include?("pp max")) && !is_held_gear
        return 5
      end
      

      # Priority 1: Medicine (Immediate resource recovery: HP, PP, Revive)
      if (desc.match?(/\bhp\b/) || desc.match?(/\bpp\b/) || 
         desc.match?(/\bfaint(ed)?\b/) || desc.match?(/\brevive\b/)) && !is_held_gear
        return 1
      end
      if (name_str.include?("potion") || name_str.include?("elixir") || name_str.include?("ether") ||
         name_str.include?("revive") || name_str.include?("fresh water") || 
         name_str.include?("lemonade") || name_str.include?("moomoo") || name_str.include?("berry juice") || 
         name_str.include?("sacred ash") || name_str.include?("lava cookie") || name_str.include?("old gateau") || 
         name_str.include?("casteliacone") || name_str.include?("lumiose") || name_str.include?("shalour") || 
         name_str.include?("pewter crunchies")) && !is_held_gear
        return 1
      end
      
      # Priority 6: Field Utility (Consumables used exclusively for overworld navigation)
      if (self.field_use > 0 && !self.has_battle_use? && !can_hold?) ||
         desc.match?(/\brepel\b/) || desc.include?("escape from a cave") || 
         desc.match?(/\bhoney\b/) || desc.include?("step") || desc.include?("attract") ||
         name_str.include?("repel") || name_str.include?("rope") || name_str.include?("lure")
        return 6
      end
                  
      # Priority 2: Battle Consumables (Alter combat state, cure afflictions, escape)
      if (self.has_battle_use? || desc.include?("cure") || desc.include?("status") || 
         desc.include?("poison") || desc.match?(/\bparalyz/) || desc.include?("sleep") || 
         desc.match?(/\bburn\b/) || desc.include?("frozen") || desc.match?(/\bescape\b/) || 
         desc.match?(/\bconfusion\b/) || desc.include?("in battle") ||
         (desc.include?("stat") && !desc.match?(/\bbase\b/)) || name_str.include?("heal")) && !is_held_gear
        return 2
      end
                  
      # Priority 4: Held Items (Permanent equippable gear and combat-triggered consumables)
      if is_held_gear || (self.can_hold? && (is_berry? || desc.match?(/\bhold\b/) || desc.match?(/\bheld\b/)))
        return 4
      end
                  
      # Priority 7: Treasures & Materials (Items with no active executable function, to be sold)
      return 7 if self.price > 0
      
      # Ultimate failsafe
      return 7
    end
    
    # Alias the original pocket method
    alias __original_pocket pocket unless method_defined?(:__original_pocket)
    
    
    # Clear the cache for all items to ensure logic updates apply
    def self.clear_ghost_pockets
      return if !method_defined?(:each) # Safety
      self.each { |item| item.instance_variable_set(:@ghost_pocket, nil) }
    end
    
    # Serve the newly calculated pocket (memoized)
    def pocket
      @ghost_pocket ||= ghost_bag_pocket
      return @ghost_pocket
    end
  end
end

# Clear cache on script load
GameData::Item.clear_ghost_pockets if defined?(GameData::Item) && GameData::Item.respond_to?(:clear_ghost_pockets)

# We must force the bag to reorganize itself upon loading, because KIF
# only triggers rearrange if the total number of pockets changes.
class PokemonBag
  alias __ghost_rearrange rearrange unless method_defined?(:__ghost_rearrange)
  
  def rearrange
    # Reorganize once per version to ensure items from old saves are routed to the 
    # newest refined heuristic definitions.
    @ghost_bag_version ||= 0
    if @ghost_bag_version < 1
      # Clean up Tutor.net crashes from nil moves
      # GHOST: tutorlist doesn't exist on Trainer/Player in this engine build
      # (ported from a fork with a "Tutor.net" feature this build lacks) -
      # KantoReloaded's own TMVault.rb guards this same call with respond_to?,
      # so match that here instead of calling it unconditionally.
      if defined?($Trainer) && $Trainer && $Trainer.respond_to?(:tutorlist) && $Trainer.tutorlist
        $Trainer.tutorlist.delete_if { |tutor_entry| tutor_entry[0].nil? }
      end
      
      newpockets = []
      for i in 0..PokemonBag.numPockets
        newpockets[i] = []
        @choices[i] = 0 if !@choices[i]
      end
      for i in 0...@pockets.length
        next if !@pockets[i]
        for item in @pockets[i]
          itm_obj = GameData::Item.try_get(item[0])
          next if !itm_obj
          p = itm_obj.pocket
          newpockets[p].push(item) if newpockets[p]
        end
      end
      @pockets = newpockets
      @ghost_bag_version = 1
    end
    __ghost_rearrange
  end
end

# Bug Fix for Tutor.net compatibility
# Tutor.net normally checks Pocket 4 for TMs up on opening. We need it to 
# explicitly check the dummy Pocket 0 where GhostBag hides machines.
if defined?(tmtutor_convert)
  def tmtutor_convert
    enabled = $PokemonSystem.tutornet == 1
    $PokemonSystem.tutornet = 0 if enabled
    # Pocket 4 in vanilla is TMs, Pocket 0 in GhostBag is TMs.
    if $PokemonBag.pockets[0]
      for i in $PokemonBag.pockets[0]
        item = GameData::Item.try_get(i[0])
        pbTutorNetAdd(item.move) if item && item.is_machine? && item.move
      end    
    end
    $PokemonSystem.tutornet = 1 if enabled
  end
end

# Intercept messages to redirect the missing dummy pocket icon
alias __ghost_pbMessage pbMessage unless defined?(__ghost_pbMessage)
def pbMessage(message, *args, &block)
  if message.is_a?(String)
    message = message.gsub("<icon=bagPocket0>", "<icon=bagPocket4>")
  end
  __ghost_pbMessage(message, *args, &block)
end

# Eliminate massive UI lag spikes on bloated pockets (e.g. Treasures)
# by preventing thousands of redundant ruby method calls per frame.
class Window_PokemonBag
  alias __ghost_refresh refresh unless method_defined?(:__ghost_refresh)
  
  def refresh
    @item_max = itemCount()
    self.update_cursor_rect
    dwidth  = self.width-self.borderX
    dheight = self.height-self.borderY
    self.contents = pbDoEnsureBitmap(self.contents,dwidth,dheight)
    self.contents.clear
    
    # Bypassing the heavy O(N) evaluation loop for O(1) mathematical clamps
    start_item = [self.top_item - 1, 0].max
    end_item = [self.top_item + self.page_item_max, @item_max - 1].min
    
    for i in start_item..end_item
      drawItem(i, @item_max, itemRect(i))
    end
    
    drawCursor(self.index,itemRect(self.index))
  end
end
