#===============================================================================
# Mod: Gameplay Tweaks
# Three independent, additive features. Every hook is alias-chained and
# rescue-wrapped so a problem in one can never break buying items, fusing,
# or the PC menu.
#===============================================================================
module GameplayTweaks
  FIRST_MART_CANDY_PRICE = 1
  GTS_SHINY_PERCENT = 25
end

#===============================================================================
# Feature 1: unlimited $1 Rare Candy, but only at the first Poke Mart (i.e.
# before the player has earned any badges).
#
# NOTE: mod.json declares a dependency on KantoReloaded so this mod loads
# AFTER it, if present. KantoReloaded's Reloaded Shop feature (on by default)
# replaces pbPokemonMart with its own dispatcher that, in "Reloaded" mode,
# calls RegularMart.open(stock, ...) directly and never reaches whichever
# pbPokemonMart definition came before it. Loading after KantoReloaded means
# THIS alias wraps that dispatcher instead of being wrapped by it, so the
# candy gets pushed into `stock` before KantoReloaded ever branches on it -
# reaching the player under both "Standard" and "Reloaded" mart modes. If
# this mod ever loads before KantoReloaded again (e.g. the dependency is
# removed), this feature silently stops working under the default "Reloaded"
# mart setting - it isn't broken, it's just been wrapped from the wrong side.
#===============================================================================
alias gameplaytweaks_orig_pbPokemonMart pbPokemonMart unless defined?(gameplaytweaks_orig_pbPokemonMart)
def pbPokemonMart(stock, speech_welcome = nil, cantsell = false, speech_bye = nil, speech_what_else = nil)
  begin
    if $Trainer && $Trainer.respond_to?(:badge_count) && $Trainer.badge_count == 0
      stock = stock ? stock.dup : []
      stock.push(:RARECANDY) unless stock.include?(:RARECANDY)
      $game_temp.mart_prices ||= {}
      $game_temp.mart_prices[:RARECANDY] = [GameplayTweaks::FIRST_MART_CANDY_PRICE, -1]
    end
  rescue => e
    echoln("[GameplayTweaks] first-mart rare candy error: #{e.message}") if $DEBUG
  end
  gameplaytweaks_orig_pbPokemonMart(stock, speech_welcome, cantsell, speech_bye, speech_what_else)
end

#===============================================================================
# Feature 2: block fusing two Pokemon when no custom sprite exists for that
# exact body+head combination. Gated at pbFuse itself (rather than the
# earlier head-selection screen) so it catches every path that leads to an
# actual fusion, and fails OPEN (allows the fuse) if the check itself errors,
# so a lookup bug can never brick the whole fusion feature.
#===============================================================================
alias gameplaytweaks_orig_pbFuse pbFuse unless defined?(gameplaytweaks_orig_pbFuse)
def pbFuse(pokemon_body, pokemon_head, splicer_item, fusion_pif_sprite = nil)
  begin
    body_id = pokemon_body.species_data.id_number
    head_id = pokemon_head.species_data.id_number
    if !customSpriteExists(body_id, head_id)
      pbMessage(_INTL("No custom fusion art exists yet for that combination. Try a different pairing."))
      return false
    end
  rescue => e
    echoln("[GameplayTweaks] fusion art gate error: #{e.message}") if $DEBUG
  end
  return gameplaytweaks_orig_pbFuse(pokemon_body, pokemon_head, splicer_item, fusion_pif_sprite)
end

#===============================================================================
# Feature 3: Simulated Global Trade Station. New PC menu option; costs the
# player one deposited party Pokemon (mirrors the storage system's "can't
# lose your last Pokemon" rule), returns a random level 1 species from the
# real dex (excludes the 1000000+ boss/special entries) with a 25% chance
# to be shiny.
#===============================================================================
class GlobalTradeStationPC
  def shouldShow?
    true
  end

  def name
    return _INTL("Global Trade Station")
  end

  def access
    pbMessage(_INTL("\\se[PC access]Connected to the Global Trade Station."))
    begin
      if !$Trainer || $Trainer.party.length <= 1
        pbMessage(_INTL("You need more than one Pokemon in your party to trade here."))
        return
      end
      return unless pbConfirmMessage(_INTL("Deposit a Pokemon in exchange for a random Pokemon from another trainer?"))

      pbChoosePokemon(1, 2, proc { |poke| !poke.egg? })
      index = pbGet(1)
      if !index || index < 0
        pbMessage(_INTL("Trade cancelled."))
        return
      end

      # Every installed single (non-fusion) species: the real dex, any species
      # added by mods, and this game's own 600000-699999 "reserved standalone"
      # custom species -- excludes only the 1000000+ triple-fusion boss
      # entries (isTripleFusion?) and any form>0 entries (e.g. our own Mega
      # forms, which aren't independently tradeable species).
      pool = []
      GameData::Species.each do |s|
        next if s.form != 0
        next if isTripleFusion?(s.id_number)
        pool.push(s.species)
      end
      pool.uniq!

      # Plus every two-Pokemon fusion that actually has real custom art on
      # disk (same "must have real art" rule as the fusion gate above), using
      # the same local sprite scan the base game already uses for this
      # (getCustomSpeciesList, FusionUtils.rb). That scan checks 700+ folders
      # so it's cached per game session rather than re-run on every PC visit.
      begin
        $game_temp.gts_fusion_pool ||= getCustomSpeciesList(false)
        pool.concat($game_temp.gts_fusion_pool) if $game_temp.gts_fusion_pool.is_a?(Array)
      rescue => e
        echoln("[GameplayTweaks] GTS fusion pool error: #{e.message}") if $DEBUG
      end

      species = pool.sample
      if !species
        pbMessage(_INTL("The GTS couldn't find a trade partner right now."))
        return
      end

      deposited = $Trainer.party[index]
      deposited_name = deposited.name
      $Trainer.remove_pokemon_at_index(index)

      received = Pokemon.new(species, 1)
      received.shiny = (rand(100) < GameplayTweaks::GTS_SHINY_PERCENT)
      $Trainer.party.push(received)

      pbSEPlay("Pkmn exp full")
      if received.shiny?
        pbMessage(_INTL("Traded away {1} and received a Level 1 \\c[1]Shiny\\c[0] {2} in return!", deposited_name, received.name))
      else
        pbMessage(_INTL("Traded away {1} and received a Level 1 {2} in return!", deposited_name, received.name))
      end
    rescue => e
      echoln("[GameplayTweaks] GTS error: #{e.message}") if $DEBUG
      pbMessage(_INTL("Something went wrong with the trade connection. Please try again."))
    end
  end
end
PokemonPCList.registerPC(GlobalTradeStationPC.new)
