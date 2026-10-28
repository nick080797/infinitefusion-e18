# Double Abilities

SUMMARY
-------
- Each recorded fusion ability remains attached to its owning component during
  evolution.
- If the evolved component still supports that ability, the exact ability is
  preserved. Otherwise, KR maps it to the corresponding normal or hidden
  ability slot on the evolved component.
- Evolution never lets KIF's temporary post-evolution ability-index remap
  overwrite a still-legal component ability.

ABILITIES
---------
Gastro Acid

- Once KIF applies Gastro Acid, both active KR slots are suppressed through the
  shared battler ability state.
- KIF's existing failure and unstoppable-ability rules remain authoritative.

Mold Breaker

- Mold Breaker, Teravolt, or Turboblaze in either slot grants KIF's existing
  Mold Breaker behavior.
- Target-side ability handlers remain skipped through KIF's normal mold
  breaker checks.

Scrappy

- Scrappy in either active slot removes Ghost's immunity to the user's Normal-
  and Fighting-type moves.
- KIF's existing move and AI type-effectiveness calculations remain
  authoritative for every other type interaction.

Aerilate

- Secondary Aerilate uses the wrapped move-type and damage handlers.
- KIF's Aerilate feedback splash also identifies Ability 2 before a compatible
  Normal-type move is used.

Stance Change

- Secondary Stance Change runs after KIF accepts the move and, for ordinary
  move use, after PP is successfully consumed.
- KIF's existing attacking-move and King's Shield stance behavior remains
  authoritative.

Disguise

- Secondary Disguise participates in KIF's Mimikyu fusion damage-absorption
  check.
- Substitute and Mold Breaker continue to take priority.

Schooling, Power Construct, And Shields Down

- Secondary Schooling and Power Construct re-enter KIF/NPT's existing form
  checks once without replacing those routines.
- Secondary Shields Down participates in KIF's battle and stored-Pokemon HP
  form checks.
- Species, component, HP, level, and form restrictions remain native.

Battle Bond

- Pure Greninja retains KIF's native Ash-Greninja form behavior.
- A fusion or non-Greninja holder raises Attack, Special Attack, and Speed by
  one stage after it knocks out a target.
- The boost can activate only once per Pokemon per battle and does not activate
  after the opposing side has been defeated.
- KR defers to any Battle Bond end-of-move handler supplied by KIF, NPT, or
  another mod instead of replacing it.

Commander

- Commander can activate for any holder, but only when an active allied
  Dondozo or Dondozo fusion is available.
- KR enters NPT's existing Commander state after its native handler runs.
- Hiding, targeting immunity, switching restrictions, stat boosts, release,
  and cleanup continue through NPT's established Commander lifecycle.
- Native Tatsugiri behavior remains authoritative and is not activated twice.

Zen Mode

- Zen Mode in either slot changes only a fusion's Darmanitan component at half
  HP or less and restores its Standard component above half HP.
- Both Unovan and Galarian Darmanitan component forms are supported.
- Pure Darmanitan continues to use KIF's existing form behavior.

Neutralizing Gas

- Neutralizing Gas in either slot suppresses other battlers through NPT's
  shared ability-active state.
- Multiple gas holders are supported. Remaining abilities reactivate only
  after the final active holder switches out or faints.

Slow Start

- Changing the other ability no longer clears an active secondary Slow Start
  counter.

Multitype And RKS System

- Multitype can use a matching Plate or type Z-Crystal on any holder.
- RKS System can use a matching Memory on any holder.
- A single-type holder changes its complete type. A dual-type holder changes
  its primary type and retains its other type.
- On eligible fusions, the held item changes only the type position owned by
  that ability's source component.
- Type replacement can change the non-owning fusion component while retaining
  the type position owned by Multitype or RKS System.
- If both represented component positions are locked, KIF's type-change move
  still fails.
- Matching Plates, type Z-Crystals, and Memories are unlosable while their
  controlling ability is active in either slot.

Transform

- Transform copies a compatible target's two active battle abilities.
- The copied Ability 2 is battle-only and does not alter the saved Pokemon.
- Transforming into a one-ability target clears the temporary second slot.
- Family-owned secondary data is not copied by KR.

Imposter

- KIF's existing Imposter flow inherits KR's Transform handling.
- Transformation still occurs only once through KIF's normal checks.

Simple Beam And Worry Seed

- A legal editable slot is selected with the battle RNG.
- The replacement is battle-only.
- Duplicate and hard-blacklisted results are rejected.

Role Play

- Role Play replaces Ability 1 and leaves Ability 2 unchanged.
- A player selects between legal target abilities; AI selection uses the battle
  RNG.
- Ungainable, Trace, Receiver, Power of Alchemy, and Wonder Guard choices remain
  unavailable.

Entrainment

- Entrainment replaces the target's Ability 1 and leaves Ability 2 unchanged.
- A player selects between legal user abilities; AI selection uses the battle
  RNG.
- Ungainable, Trace, Receiver, and Power of Alchemy choices remain unavailable.

Skill Swap

- Skill Swap exchanges Ability 1 and leaves Ability 2 unchanged.
- Both resulting pairs are validated before KIF performs either assignment.

Trace

- Trace in Ability 2 replaces Ability 2 instead of Ability 1.
- Trace can select either legal opposing ability when the target uses a KR
  pair.
- KIF's battle RNG selects the opposing Pokemon/slot when more than one legal
  source exists.

Receiver And Power Of Alchemy

- A KR pair holder can inherit either legal ability from a fainted KR ally.
- The inherited ability replaces the exact Receiver or Power of Alchemy slot.
- Ungainable, Trace, Receiver, Power of Alchemy, and Wonder Guard sources
  remain unavailable.

Illusion

- KIF's standard active-ability predicate starts secondary Illusion normally.
- Shift-style opponent previews and send-out messages use the disguised
  Pokemon when Illusion is in Ability 2.
- Removing the exact Illusion slot clears its appearance only when the other
  slot does not still contain Illusion.

Mummy And Lingering Aroma

- When both battlers use KR pairs, contact replacement chooses a legal attacker
  slot with the battle RNG.
- Mummy and Lingering Aroma can each replace one slot from the same contact
  event when both are active.
- Other KIF contact checks and single-ability behavior remain unchanged.

Wandering Spirit

- When both battlers use KR pairs, Wandering Spirit swaps its exact holder slot
  with one random legal attacker slot.
- Both resulting pairs are validated before either slot changes.
- The exchange is battle-only.

Wonder Guard

- Wonder Guard remains unlimited when it is the Pokemon's only active ability.
- A single-ability Wonder Guard assigned by Dynamic Abilities is the exception
  and receives the same three-charge limit as a two-ability holder.
- With two active abilities, Wonder Guard has three charges per battle.
- One charge is consumed for each damaging move use that Wonder Guard blocks.
- Multi-hit moves consume no more than one charge for the move use.
- Type immunity, super-effective damage, and Mold Breaker do not consume a
  charge.
- At zero charges, Wonder Guard becomes inactive for the rest of the battle.
- A secondary Wonder Guard applies the same one-maximum-HP rule.

Emergency Exit And Wimp Out

- If both are active, only the first successful slot can switch or escape from
  the same HP change.

ITEMS
-----
Ability Capsule

- Presents Ability 1 and Ability 2 when both have legal normal alternatives.
- Changes only the selected slot.
- Never edits Family Pokemon.
- The item is consumed only after a successful legal change.
- With Double Abilities Off, KIF's native handler remains unchanged.

Secret Capsule

- Presents every slot with a legal component hidden ability.
- Changes only the selected slot.
- Never edits Family Pokemon.
- The item is consumed only after a successful legal change.
- With Double Abilities Off, KIF's native handler remains unchanged.

Ability Ball

- Single-species Pokemon retain KIF's native behavior.
- A caught KR fusion restores its pre-handler primary, then applies a legal
  component hidden ability to the selected slot.
- The only legal slot or ability is selected automatically.
- Family Pokemon ability data is not changed.

BLACKLIST
---------
Only combinations that are technically unsafe, overpowered or produce extreme multiplicative
behavior are hard-blacklisted.

Illusion + Imposter

- Both abilities compete for displayed identity and transformation state.

Wonder Guard + Sturdy

- One maximum HP can repeatedly reactivate Sturdy after direct attacks.

Huge Power + Pure Power

- KIF applies both as separate two-times Attack multipliers.

Multiscale + Shadow Shield

- Both independently halve full-HP damage and stack to one-quarter damage.

Huge Power/Pure Power + Water Bubble

- The Attack multiplier and Water damage multiplier produce four-times damage
  before STAB and other modifiers.

Shadow Tag + Perish Body

- Contact can start a Perish countdown while Shadow Tag prevents switching,
  creating unacceptable forced losses for Nuzlocke saves.

As One Variants

- More than one As One variant is treated as a semantic duplicate.
