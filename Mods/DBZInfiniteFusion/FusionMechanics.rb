#==============================================================================
# DBZ Infinite Fusion Port - Fusion Mechanics
#
# The 151 reskinned Kanto species (DBZPort.reskinned_species_map, id_numbers
# SPECIES_ID_NUMBER_BASE..+150, see main.rb) are real, standalone-registered
# GameData::Species entries - NOT the vanilla Bulbasaur/etc they're reskins
# of. The vanilla pbFuse (Gameplay/Items/New Items effects.rb) computes
# newid = body.id_number*NB_POKEMON + head.id_number, which only makes sense
# for real dex ids <=727; with two of these reskins (six-digit ids) it would
# produce a garbage/out-of-range id instead of a valid fusion. This file lets
# them fuse with each other through the normal PC-box "Fuse" flow by reusing
# the same symbol-based dynamic FusedSpecies mechanism the base game already
# uses for triple fusions and custom sprites (GameData::Species.get(:"B#{body}
# H#{head}") -> GameData::FusedSpecies.new(symbol), which pulls body/head
# straight out of the symbol's digits with regex - exact for any id size, no
# NB_POKEMON-multiple assumption). No curated named results here (unlike
# AnimeFusionMerge's Gogeta/Vegito etc.) - these are plain Kanto reskins, so
# the engine's own auto-blended name is correct as-is.
#
# Sprites: obtain_fusion_pif_sprite (Fusion/Sprites/BattleSpriteLoader.rb)
# resolves fusion battlers by the parents' raw id_numbers regardless of size
# (CustomSpriteExtracter's indexed/{head_id}/{head_id}.{body_id}.png cache),
# so placing the converted standalone-game art there (see
# build_dbz_inf_sprites.py) is all sprites need - no code change.
#
# Reskin x reskin fusion only: reskin x real-Pokemon or reskin x other-mod
# fusion is intentionally NOT handled here (falls through to the original
# pbFuse below, same as any two species neither this file nor
# AnimeFusionMerge recognizes) since there's no defined art/behavior for that
# combination in the source game this was ported from.
#==============================================================================
module DBZInfiniteFusionMechanics
  DBZ_INF_RESKIN_RANGE = (DBZPortSettings::SPECIES_ID_NUMBER_BASE..(DBZPortSettings::SPECIES_ID_NUMBER_BASE + 150)).freeze

  def self.dbz_inf_species?(species)
    data = GameData::Species.try_get(species)
    return false unless data
    return false unless DBZ_INF_RESKIN_RANGE.include?(data.id_number)
    return defined?(DBZPort) && DBZPort.reskinned_species_map.values.include?(data.species)
  end

  def self.fusion_result(body_species, head_species)
    return nil unless dbz_inf_species?(body_species) && dbz_inf_species?(head_species)
    body_data = GameData::Species.try_get(body_species)
    head_data = GameData::Species.try_get(head_species)
    return GameData::Species.get(get_fusion_symbol(head_data.id_number, body_data.id_number))
  end
end

alias dbzinf_orig_pbFuse pbFuse unless defined?(dbzinf_orig_pbFuse)
def pbFuse(pokemon_body, pokemon_head, splicer_item, fusion_pif_sprite = nil)
  dbzinf_result = DBZInfiniteFusionMechanics.fusion_result(pokemon_body.species, pokemon_head.species)
  unless dbzinf_result
    return dbzinf_orig_pbFuse(pokemon_body, pokemon_head, splicer_item, fusion_pif_sprite)
  end

  original_head = pokemon_head.clone
  original_body = pokemon_body.clone
  use_supersplicers_mechanics = isSuperSplicersMechanics(splicer_item)
  newid = dbzinf_result.species
  fus = PokemonFusionScene.new
  if fus.pbStartScreen(pokemon_body, pokemon_head, newid, splicer_item, fusion_pif_sprite)
    returnItemsToBag(pokemon_body, pokemon_head)
    fus.pbFusionScreen(false, use_supersplicers_mechanics)
    $game_variables[VAR_FUSE_COUNTER] += 1
    fus.pbEndScreen
    $PokemonTemp.fuse_count_today = 0 unless $PokemonTemp.fuse_count_today
    $PokemonTemp.fuse_count_today += 1
    checkFuseChallenges(original_head, original_body)
    return true
  end
end
