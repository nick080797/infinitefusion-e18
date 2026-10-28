#===============================================================================
# Unlock All Mystery Gifts
#
# Data/Scripts/016_UI/023_UI_MysteryGift.rb's pbMysteryGiftReadFromJson skips
# any gift whose entry in the downloaded JSON has "enabled":false - that's how
# the official gift server (download.infinitefusion.net) retires past events
# (e.g. HOENN_1 "Welcome to Hoenn!" and HOENN2 "Welcome to Hoenn! (2)" are
# both currently flagged enabled:false in MysteryGiftPublic.json).
#
# This redefines that top-level method (plain "def", not a class method, so a
# later "def" in load order simply replaces the earlier one - no alias chain
# needed) with the "enabled" gate removed. Region (kanto_only/hoenn_only),
# minimum_version, and trainer_id gating are all left intact, since those
# reflect real compatibility constraints, not "this gift has expired".
#===============================================================================
def pbMysteryGiftReadFromJson(json_string,trainer)
  json_data = JSON.parse(json_string) rescue {}
  mystery_gifts = []
  importer = SecretBaseImporter.new

  json_data.each do |key, value|
    id = key.to_s
    gift_data = json_data[key]

    minimum_version = gift_data[:minimum_version] || nil
    if minimum_version && !is_higher_version(Settings::GAME_VERSION_NUMBER, minimum_version)
      next
    end

    trainer_id = gift_data[:trainerId] || nil
    if trainer_id
      next unless trainer.id == trainer_id
    end
    pokemon= gift_data[:pokemon]
    item = gift_data[:item] || nil
    hat = gift_data[:hat] || nil
    clothes = gift_data[:clothes] || nil
    quantity = gift_data[:quantity] || 0
    name = gift_data[:name]
    kanto_only = gift_data[:kanto_only] || false
    hoenn_only = gift_data[:hoenn_only] || false

    next if kanto_only && !Settings::KANTO
    next if hoenn_only && !Settings::HOENN
    # NOTE: intentionally no "next unless enabled" here - that's the whole point.

    if pokemon
      gift_content = importer.import_pokemon_from_json(pokemon)
    elsif item
      gift_content = item.to_sym
      quantity = quantity.to_i
    elsif hat
      gift_content = Hat.new(hat,nil,nil,nil)
    elsif clothes
      gift_content = Clothes.new(clothes,nil,nil,nil)
    else
      next
    end
    gift_array = [id,quantity,gift_content,name]
    mystery_gifts.push(gift_array)
  end
  return mystery_gifts
end
