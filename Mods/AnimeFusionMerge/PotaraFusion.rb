#==============================================================================
# Anime Fusion Merge - Potara Fusion Machine
#
# A standalone feature, deliberately separate from the generic Splicer-item
# "Fuse" flow (FusionMechanics.rb's pbFuse override): a curated-fusion-only
# machine, gated behind earning your first Gym Badge, placed among the lab
# equipment in Professor Oak's Lab (Map077) per the user's own "the
# electronics in professor oaks lab" framing.
#
# NOT placed on the two existing "It's a complex looking machine." props
# (event ids 40/41 at (12,12)/(13,12)) - inspecting their full page list
# (2026-08-31) showed those are each 4-page conditional events wired to the
# real Pokedex-Randomizer-Mode "Re-randomize Pokemon?" feature (switches
# 954/61, variable 21), not inert flavor text - overwriting them would break
# that existing feature for anyone using Randomizer Mode. Placed a brand new
# event instead, at the one open gap in the same counter row (11,12), between
# the existing "document" (10,12) and "machine" (12,12) props, using the
# game's own BWComputer overworld graphic so it still reads as lab equipment.
#
# Nothing here touches Map077.rxdata on disk. Events.onMapCreate fires with
# the raw pre-conversion RPG::Map object (same hook GymBossPlacement.rb
# already uses) - we add the new event to @map.events in memory, exactly like
# GymBossPlacement's own gym/E4/champion NPCs, before the vanilla code turns
# it into a live Game_Event. Delete this file and the machine is gone with no
# other trace.
#
# Rules (all per explicit user override of the DBZ Team Training source
# material - see FusionMechanics.rb's own header for the shiny/IV/no-items
# behavior, all of which is shared with this entry point since it ends up
# calling the exact same PokemonFusionScene):
# - Only the pairs in AnimeFusionMerge::CURATED_FUSIONS work here (canon
#   combos only - "only a few combinations work", per the source wiki text).
#   Uncurated DBZ pairs are refused with a flavor message; the normal
#   Splicer-item Fuse flow is still there for those (dynamic BxHy result).
# - No item is held, needed, or consumed - held Potara/Up-Grade requirements
#   are simply never checked, and there's no Splicer item in this flow to
#   begin with, so nothing is spent either way.
# - Shiny guarantee and IV averaging: unconditional base-engine behavior in
#   PokemonFusionScene#pbFusionScreen, nothing extra needed here.
#==============================================================================
module AnimeFusionMerge
  POTARA_MACHINE_MAP_ID = 77
  POTARA_MACHINE_X = 11
  POTARA_MACHINE_Y = 12

  # Called (via Script Call) when the player presses Action Button on the
  # repurposed lab machine. Pure flavor until a badge is earned, matching
  # the user's "after obtaining a gym badge" gate.
  def self.interact_potara_machine
    if $Trainer.badge_count <= 0
      pbMessage(_INTL("It's some kind of complicated machine. It doesn't seem to be running yet."))
      return
    end
    pbMessage(_INTL("This is Professor Oak's Potara Fusion machine!"))
    pbMessage(_INTL("It only works on a few known combinations, needs no items, and always guarantees a shiny result if either Pokémon fed into it already is one."))
    trigger_potara_fusion
  end

  # Prompts for two party Pokémon and, if their pair is a known curated
  # combo, performs the fusion exactly like the Splicer-item flow does
  # (same PokemonFusionScene), just with no item involved at either end.
  def self.trigger_potara_fusion
    if $Trainer.party.length < 2
      pbMessage(_INTL("You need at least two Pokémon for that."))
      return
    end
    first_idx = pbPotaraChoosePokemon(_INTL("Choose the first Pokémon."))
    return if !first_idx || first_idx < 0
    second_idx = pbPotaraChoosePokemon(_INTL("Choose the second Pokémon."))
    return if !second_idx || second_idx < 0
    if first_idx == second_idx
      pbMessage(_INTL("A Pokémon can't fuse with itself!"))
      return
    end

    p1 = $Trainer.party[first_idx]
    p2 = $Trainer.party[second_idx]
    if p1.egg? || p2.egg?
      pbMessage(_INTL("It's impossible to fuse an egg!"))
      return
    end
    if p1.hp == 0 || p2.hp == 0
      pbMessage(_INTL("A fainted Pokémon cannot be fused!"))
      return
    end

    result = dbz_fusion_result(p1.species, p2.species)
    unless result
      pbMessage(_INTL("Nothing happens... this machine doesn't recognize that combination."))
      return
    end
    unless Kernel.pbConfirmMessage(_INTL("Perform Potara Fusion on {1} and {2}?", p1.name, p2.name))
      return
    end

    original_head = p2.clone
    original_body = p1.clone
    fus = PokemonFusionScene.new
    if fus.pbStartScreen(p1, p2, result.species, :INFINITESPLICERS, nil)
      returnItemsToBag(p1, p2)
      fus.pbFusionScreen(false, false)
      $game_variables[VAR_FUSE_COUNTER] += 1
      fus.pbEndScreen
      $PokemonTemp.fuse_count_today = 0 unless $PokemonTemp.fuse_count_today
      $PokemonTemp.fuse_count_today += 1
      checkFuseChallenges(original_head, original_body)
      pbRemovePokemonAt(second_idx)
      pbMessage(_INTL("Potara Fusion complete!"))
    end
  end

  # Small wrapper around the standard party-picker screen (same one the
  # vanilla item-use Fuse flow and countless other menus use).
  def self.pbPotaraChoosePokemon(helptext)
    chosen = -1
    pbFadeOutIn {
      scene = PokemonParty_Scene.new
      screen = PokemonPartyScreen.new(scene, $Trainer.party)
      screen.pbStartScene(helptext, false)
      chosen = screen.pbChoosePokemon
      screen.pbEndScene
    }
    chosen
  end

  def self.install_potara_machine(map_id, map)
    return unless map_id == POTARA_MACHINE_MAP_ID
    return if map.events.values.any? { |e| e.name == "Potara Fusion Machine" }
    next_id = (map.events.keys.max || 0) + 1
    event = RPG::Event.new(POTARA_MACHINE_X, POTARA_MACHINE_Y)
    event.id = next_id
    event.name = "Potara Fusion Machine"
    page = event.pages[0]
    page.trigger = 0 # Action Button
    page.graphic.character_name = "BWComputer"
    page.graphic.character_hue = 0
    page.graphic.direction = 2 # Facing down
    page.move_type = 0 # Fixed - never wanders off its tile
    page.through = false
    page.list = [
      RPG::EventCommand.new(355, 0, ["AnimeFusionMerge.interact_potara_machine"]),
      RPG::EventCommand.new(0, 0, []),
    ]
    map.events[next_id] = event
  end
end

Events.onMapCreate += proc { |_sender, e|
  map_id, map = e[0], e[1]
  AnimeFusionMerge.install_potara_machine(map_id, map)
}
