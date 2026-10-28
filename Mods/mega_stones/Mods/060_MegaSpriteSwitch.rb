#===============================================================================
# True Mega Evolution sprite switch.
#
# The engine's own makeMega/makeUnmega (014_Pokemon/002_Pokemon_MegaEvolution.rb)
# already correctly flip Pokemon#form for the 3 true-mega solo species
# (PBS/pokemonforms.txt: MEDICHAM, CHIMECHO, EELEKTROSS) -- stats/type/ability
# all change correctly in battle. But this fork's custom sprite pipeline
# (052_InfiniteFusion/Fusion/Sprites/FusionSprites.rb) picks a battle sprite
# purely from pokemon.species and never looks at pokemon.form, so the sprite
# never visually changes on its own.
#
# Deliberately NOT fixed by mutating pokemon.species itself (that would
# desync Pokedex seen/owned tracking, evolution-family checks, breeding/trade
# validity, and anything else that compares species by symbol). Instead this
# patches the sprite LOOKUP to respect the form state the engine already
# tracks correctly, via the precise Pokemon#mega? check.
#
# Add art at: Graphics/CustomBattlers/local_sprites/BaseSprites/<id>_mega.png
# (id = the base species' own dex number, e.g. 528 for Medicham). Missing
# art simply falls through to the normal (non-mega) sprite -- never an error.
#===============================================================================
module GameData
  class Species
    class << self
      unless method_defined?(:megaspriteswitch_orig_front_sprite_bitmap_pokemon)
        alias_method :megaspriteswitch_orig_front_sprite_bitmap_pokemon, :front_sprite_bitmap_pokemon
      end
    end

    def self.front_sprite_bitmap_pokemon(pokemon)
      begin
        if pokemon && pokemon.respond_to?(:mega?) && pokemon.mega?
          base_id = GameData::Species.get(pokemon.species).id_number
          path = "#{Settings::CUSTOM_BASE_SPRITES_FOLDER}#{base_id}_mega"
          bitmap_file = pbResolveBitmap(path)
          if bitmap_file
            sprite = AnimatedBitmap.new(bitmap_file)
            sprite.shiftAllColors(base_id, pokemon.bodyShiny?, pokemon.headShiny?) if pokemon.shiny?
            return sprite
          end
        end
      rescue => e
        echoln("[MegaSpriteSwitch] mega sprite lookup error: #{e.message}") if $DEBUG
      end
      return megaspriteswitch_orig_front_sprite_bitmap_pokemon(pokemon)
    end
  end
end
