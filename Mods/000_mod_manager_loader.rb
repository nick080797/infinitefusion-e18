#==============================================================================
# Mod Manager Bootstrap
#
# This file is picked up by the existing Dir["./Mods/*.rb"] glob in
# 999_Main.rb. The "000_" prefix ensures it runs before any other
# legacy .rb mods in this folder.
#
# It calls ModManager.load_all_mods which loads subfolder-based mods
# (Mods/<mod_name>/mod.json + scripts) in dependency order.
#
# Legacy .rb files in Mods/ root still load normally after this via
# the same glob — no changes to core files needed.
#==============================================================================

#==============================================================================
# Compat shim: MessageTypes.set(type, id, value)
#
# Several mods (crafting_system, GhostItem_Splicers, GhostBase_PlayerHousing,
# alpha_encounters, mega_stones) call MessageTypes.set(type, id, value) to
# register a single custom item/ability name - but the base game's
# MessageTypes module never defines a `set` method (only bulk setMessages/
# addMessages that replace/merge a whole type's array at once). Every one of
# those .set calls has been silently raising NoMethodError, caught by each
# mod's own top-level rescue, so newly-registered items/abilities got a real
# GameData entry but their .name always returned "" - the "You found _!" /
# blank crafting ingredient names bug. Defined here, before any managed mod
# loads, so it's available no matter what order mods load in.
#==============================================================================
if defined?(MessageTypes) && !MessageTypes.respond_to?(:set)
  module MessageTypes
    def self.set(type, id, value)
      arr = []
      arr[id] = value
      addMessages(type, arr)
    end
  end
end

if defined?(ModManager) && ModManager.respond_to?(:load_all_mods)
  ModManager.load_all_mods
end