#==============================================================================
# Anime Fusion Merge - Ability Handlers
# Battle mechanics for the custom DBZ/Animon abilities registered by
# abilities.txt (see Bootstrap.rb#load_abilities). Effects are recovered from
# the original GBA ROM export data (Pokemon Anime fusions/gba export dbz/
# Abilities/*.ini) - each one below is either an exact copy of the vanilla
# ability whose handler matches that GBA description verbatim, or (where no
# handler-class hook exists for the effect) a direct addition to the relevant
# base-game array/case-statement, done the same non-invasive way as every
# other base-file touch in this project (see project_mod_conflict_audit.md).
#==============================================================================

# KI ABSORB - "Powers up if hit by fire." Exact match for Flash Fire (immune
# to Fire-type moves, next Fire-type move used gets boosted).
BattleHandlers::MoveImmunityTargetAbility.copy(:FLASHFIRE, :KIABSORB)
BattleHandlers::DamageCalcUserAbility.copy(:FLASHFIRE, :KIABSORB)

# PARRY - "Blocks critical hits." Exact match for Battle Armor.
BattleHandlers::CriticalCalcTargetAbility.copy(:BATTLEARMOR, :PARRY)

# POTENTIAL - "Ups DEFENSE if suffering [a status condition]." Exact match
# for Marvel Scale.
BattleHandlers::DamageCalcTargetAbility.copy(:MARVELSCALE, :POTENTIAL)

# MAJIN POWER - "Raises ATTACK." Exact match for Huge Power (doubles Attack
# in damage calc).
BattleHandlers::DamageCalcUserAbility.copy(:HUGEPOWER, :MAJINPOWER)

# TOUGHNESS - "Prevents ATTACK reduction." Exact match for Hyper Cutter
# (blocks Attack-stat drops specifically, unlike Clear Body which blocks all
# stats).
BattleHandlers::StatLossImmunityAbility.copy(:HYPERCUTTER, :TOUGHNESS)

# CHASE - "Prevents fleeing." / DEAD ZONE - "Prevents the foe's escape."
# Both describe trapping the opponent in battle; exact match for Shadow Tag
# (traps regardless of type, unlike Arena Trap which only traps grounded
# targets - neither GBA description mentions a grounded-only restriction).
BattleHandlers::TrappingTargetAbility.copy(:SHADOWTAG, :CHASE)
BattleHandlers::TrappingTargetAbility.copy(:SHADOWTAG, :DEADZONE)

# KI DRAIN - "Raises foe's PP usage." Exact match for Pressure's switch-in
# message; the actual PP-cost doubling is a hardcoded :PRESSURE check in
# 011_Battle/001_Battler/007_Battler_UseMove.rb (no handler-class hook exists
# for it), extended there directly to include :KIDRAIN.
BattleHandlers::AbilityOnSwitchIn.copy(:PRESSURE, :KIDRAIN)

# PERFECT BODY - "Prevents ability reduction." Matches PokeBattle_Battler
# #unstoppableAbility? (011_Battle/001_Battler/001_PokeBattle_Battler.rb),
# which already governs immunity to both losing one's ability (being
# replaced, e.g. Skill Swap/Role Play) and having it negated (e.g. Gastro
# Acid/Neutralizing Gas) for a hardcoded list of form-changing abilities.
# Prepended (not edited in place) so a base-game update to that method still
# takes effect; PERFECTBODY just always short-circuits to true first.
module AnimeFusionMerge
  module PerfectBodyUnstoppable
    def unstoppableAbility?(abil = nil)
      abil = @ability_id if !abil
      return true if abil == :PERFECTBODY
      super
    end
  end
end
PokeBattle_Battler.prepend(AnimeFusionMerge::PerfectBodyUnstoppable)
