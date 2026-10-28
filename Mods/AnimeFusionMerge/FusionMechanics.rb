#==============================================================================
# Anime Fusion Merge - Fusion Mechanics
#
# Lets our DBZ-block species (dex 577-1052) fuse with each other through the
# normal PC-box "Fuse" flow, using curated named results for canon combos
# (Goku+Vegeta -> Gogeta, Goten+Trunks -> Gotenks, Caulifla+Kale -> Kefla)
# and falling back to the engine's own dynamic FusedSpecies synthesis for any
# other DBZ+DBZ pair. Pokemon x Pokemon fusion (dex <=576) is untouched.
# Animon/other-anime species (dex 1053-1326) get no fusion path at all, per
# design - neither this file nor the vanilla gate grants them one.
#
# Why not the vanilla body*727+head integer scheme (getFusionSpecies /
# getSpeciesIdForFusion) for the dynamic fallback: that scheme treats head
# dex as a single base-727 "digit", so any head dex >727 aliases onto a
# different (body+1, head-727) pair - and about half our DBZ block (dex
# 728-1052) is >727. The symbol form instead - GameData::Species.get(:"B#{body}H#{head}")
# -> GameData::FusedSpecies.new(symbol) - pulls body/head straight out of
# the symbol's digits with regex (get_body_number_from_symbol /
# get_head_number_from_symbol in Fusion/Data/FusedSpecies.rb), so it's exact
# for any dex size. It's also the same mechanism the base game already uses
# for triple fusions and custom sprites - not a new code path, just reused.
#
# Sprites: obtain_fusion_pif_sprite (Fusion/Sprites/BattleSpriteLoader.rb)
# already auto-generates a composite battler from the two parents' own
# sprites (type :AUTOGEN) whenever no hand-drawn one exists for that pair -
# this is the "top half one sprite, bottom half the other" fallback the base
# game itself uses, and it works off the parents' real dex numbers, not the
# fusion id, so it needs no changes here to cover uncurated DBZ pairs.
#==============================================================================
module AnimeFusionMerge
  DBZ_DEX_RANGE = (600577..601052)

  # Fusion eligibility within the DBZ block is further restricted to species
  # that actually came from the DBZ Infinite Fusion character roster, not the
  # ones ported in from Dragon Ball Team Training - most Team Training adds
  # (early-DB cast like Bear Thief/Giran/Taopaipai, and prefix-named power-up
  # forms like "SSJ Goku"/"KG Vegeta"/"GT Trunks") were never drawn with the
  # multi-alt fusion-ready art DBZ Infinite Fusion's own roster has, so they
  # aren't "built to be fused" per the user.
  #
  # This dex list was derived (2026-08-29) by cross-referencing this file's
  # merged pokemon.txt (dex 577-1052) against the character list scraped from
  # the DBZ Infinite Fusion web tool's own character-select dropdown
  # (../../../dbz infinite fusions/dbz_list.xlsx, sheet "list(full)", 169
  # names) - matching by name after stripping parenthetical qualifiers. 139
  # of the 473 DBZ-block species matched; those are the ones below. Note this
  # means most single-form "SSJ"/"GT"/"KG"-prefixed transformation entries
  # are EXCLUDED even though they look DBZ-Inf-ish, because DBZ Infinite
  # Fusion's own roster names those forms differently (e.g. "Goku (SSJ4)",
  # not "SSJ Goku") or doesn't have them at all - only exact-ish name matches
  # count. If a specific species should be added/removed from this list,
  # just edit the array.
  DBZ_INF_DEX_NUMBERS = [
    600577, 600578, 600579, 600580, 600581, 600582, 600583, 600584, 600585, 600586, 600587, 600588, 600589, 600590, 600591,
    600592, 600593, 600594, 600595, 600596, 600597, 600598, 600599, 600600, 600601, 600602, 600603, 600604, 600605, 600606,
    600607, 600608, 600609, 600610, 600611, 600612, 600613, 600614, 600615, 600616, 600617, 600618, 600619, 600620, 600621,
    600622, 600623, 600624, 600625, 600626, 600627, 600628, 600629, 600630, 600631, 600632, 600633, 600634, 600635, 600636,
    600637, 600638, 600639, 600640, 600641, 600642, 600643, 600644, 600645, 600646, 600647, 600649, 600650, 600651, 600652,
    600653, 600654, 600655, 600656, 600657, 600658, 600659, 600660, 600661, 600662, 600663, 600664, 600665, 600666, 600667,
    600668, 600669, 600671, 600672, 600673, 600674, 600675, 600676, 600677, 600678, 600679, 600680, 600681, 600682, 600683,
    600684, 600685, 600686, 600687, 600688, 600689, 600690, 600691, 600692, 600693, 600694, 600695, 600696, 600697, 600698,
    600699, 600700, 600701, 600702, 600703, 600704, 600705, 600706, 600707, 600708, 600709, 600710, 600711, 600712, 600713,
    600714, 600715, 600716, 600717, 600718, 600719, 600720, 600721, 600722, 600723, 600724, 600725, 600726, 600727, 600728,
    600729, 600730, 600731, 600732, 600733, 600734, 600735, 600736, 600737, 600738, 600739, 600740, 600741, 600742, 600743,
    600744, 600745, 600746, 600747, 600748, 600749, 600750, 600751, 600752, 600753, 600754, 600755, 600756, 600757, 600758,
    600759, 600760, 600761, 600762, 600763, 600764, 600765, 600766, 600767, 600768, 600769, 600770, 600771, 600772, 600773,
    600774, 600775, 600776, 600778, 600779, 600780, 600781, 600782, 600783, 600784, 600785, 600786, 600787, 600788, 600789,
    600790, 600791, 600792, 600793, 600794, 600795, 600796, 600797, 600798, 600799, 600800, 600801, 600802, 600803, 600804,
    600805, 600806, 600807, 600808, 600809, 600810, 600811, 600812, 600813, 600814, 600815, 600816, 600817, 600818, 600819,
    600820, 600821, 600822, 600823, 600824, 600825, 600826, 600827, 600828, 600829, 600830, 600831, 600832, 600833, 600834,
    600835, 600836, 600837, 600838, 600839, 600840, 600841, 600842, 600843, 600844, 600845, 600846, 600847, 600848, 600852,
    600853, 600854, 600855, 600856, 600857, 600858, 600859, 600860, 600861, 600862, 600863, 600864, 600865, 600866, 600867,
    600868, 600869, 600870, 600871, 600872, 600873, 600874, 600875, 600876, 600877, 600878, 600879, 600880, 600881, 600882,
    600883, 600884, 600885, 600886, 600887, 600888, 600889, 600890, 600891, 600892, 600893, 600894, 600895, 600896, 600897,
    600898, 600899, 600900, 600901, 600902, 600903, 600904, 600905, 600906, 600907, 600908, 600909, 600910, 600911, 600912,
    600913, 600915, 600916, 600917, 600918, 600919, 600920, 600921, 600922, 600923, 600924, 600925, 600926, 600927, 600928,
    600929, 600930, 600931, 600932, 600933, 600934, 600935, 600936, 600937, 600938, 600939, 600940, 600941, 600942, 600943,
    600944, 600945, 600946, 600947, 600948, 600949, 600950, 600951, 600952, 600953, 600954, 600955, 600956, 600957, 600958,
    600959, 600961, 600962, 600963, 600964, 600965, 600966, 600967, 600968, 600969, 600970, 600971, 600972, 600973, 600974,
    600975, 600976, 600977, 600978, 600979, 600980, 600981, 600982, 600983, 600984, 600985, 600986, 600987, 600988, 600989,
    600990, 600991, 600992, 600993, 600994, 600995, 600996, 600997, 600998, 600999, 601000, 601001, 601002, 601003, 601004,
    601005, 601006, 601007, 601008, 601009, 601010, 601011, 601012, 601013, 601014, 601015, 601016, 601017, 601018, 601019,
    601020, 601021, 601022, 601023, 601024, 601025, 601026, 601027, 601028, 601029, 601030, 601031, 601032, 601033, 601034,
    601035, 601036, 601037, 601038, 601039, 601040, 601041, 601042, 601043, 601044, 601045, 601046, 601047, 601048, 601049,
    601050, 601051, 601052,
  ].freeze

  # A handful of curated pairs live outside DBZ_DEX_RANGE entirely (6-digit
  # Team Training-merge IDs, e.g. Caulifla/Kale at 600750/600753) - not a
  # blanket range widen (that'd pull in ~150 unvetted 600000+ species), just
  # the specific inputs the recipes below actually need:
  #   600750 CAULIFLA, 600752 CAULIFLA2 (SSJ2 Caulifla), 600753 KALE,
  #   600755 MBSKKALE (Mastered Berserk Kale), 600821 SSBVEGETA.
  # Discovered 2026-08-31: this also means the long-standing
  # [:CAULIFLA,:KALE]=>:KEFLA entry below was dead code until now - dex
  # 600750/600753 were never in DBZ_DEX_RANGE (577-1052), so dbz_species?
  # always rejected them and every Caulifla+Kale fuse silently fell through
  # to the dynamic BxHy fallback instead.
  #
  # 2026-08-31 (round 2): the "team training fusion pairs" the user flagged
  # (Gohanks/Gokhan/Goditz/Raunks/GT Gotenks 2-4/SS3Gohanks) turned out NOT to
  # be part of the DBZ Team Training Fusion Machine's 16-combo canon list at
  # all - tracked their real recipes down on the separate DBZ ULTIMATE Team
  # Training wiki instead (a different, expanded hack this mod also pulled
  # 600000+ IDs from). Each is the first link of its own evolution chain that
  # was ALREADY correctly present in pokemon.txt's Evolutions fields the whole
  # time (GODITZ->SPGODITZ->SSGGODTIZ->MSSBGODITZ->SSBEGODITZ,
  # GOHANKS->SS3GOHANKS, GOKHAN2->GOKHAN->ULTGOKHAN, RAUNKS->SSRAUNKS,
  # GTGOTENKS->GTGOTENKS2->GTGOTENKS3->GTGOTENKS4) - the only missing piece
  # was the fusion recipe that creates the first link, so wiring that one
  # CURATED_FUSIONS entry per chain below makes the whole rest of each chain
  # reachable via its existing level/item evolutions, no other changes
  # needed. New parent species whitelisted here: 600827 RADITZ2, 600828
  # RANCH, 600904 GTTRUNKS, 600906 GTGOTEN (GOKU/GOHAN/TRUNKS are already in
  # DBZ_INF_DEX_NUMBERS). Note: GODITZ2 (dex 600955) is GENUINELY Goditz's
  # own second form, not a duplicate as first assumed here - pokemon.txt's
  # GODITZ entry was missing that middle link (it jumped straight to
  # SPGODITZ), fixed by pointing GODITZ -> GODITZ2 (Lvl 10) -> SPGODITZ
  # (Lvl 20, unchanged) instead.
  DBZ_FUSION_EXTRA_IDS = [600750, 600752, 600753, 600755, 600821,
                          600827, 600828, 600904, 600906].freeze

  # Order-sensitive curated results (2026-08-31, user request): three pairs
  # in the canon list have BOTH a Metamoran (Fusion Dance) and a Potara
  # result - Goku+Vegeta, SSJ Goku+SSJ Vegeta, and SSJ4 Goku+SSJ4 Vegeta.
  # Rather than force-picking one per pair (the old approach - see removed
  # header note), whichever parent is picked FIRST (pbFuse's pokemon_body /
  # the party member you choose first in Potara Fusion) now decides which
  # canon result you get, exactly like the real games distinguish Fusion
  # Dance vs Potara by which fighter initiates: Goku-first -> Gogeta (dance),
  # Vegeta-first -> Vegito (Potara), and the same pattern one SSJ tier up.
  # SSJ4 has no listed Potara counterpart (SS4 Gogeta only), so that pair
  # stays a plain order-independent CURATED_FUSIONS entry below instead.
  # Checked before CURATED_FUSIONS in dbz_fusion_result, so it takes
  # priority for these four exact (body, head) orderings only.
  ORDERED_FUSIONS = {
    [:GOKU, :VEGETA]       => :GOGETA,
    [:VEGETA, :GOKU]       => :VEGITO,
    [:SSJGOKU, :SSJVEGETA] => :SSJGOGETA,
    [:SSJVEGETA, :SSJGOKU] => :SSJVEGITO,
  }.freeze

  # Curated canon fusion results, keyed by the two parents' InternalNames
  # (order-independent - see ORDERED_FUSIONS above for the pairs where order
  # actually matters). 2026-08-31 additions (user-supplied canon fusion
  # list): Gotenks 2, Kibitoshin, M-Zamasu, Baby Vegeta and Super C-17 are
  # added too even though already reachable elsewhere, purely so fusing
  # their listed parents gives the correct named result instead of a
  # generic auto-blend. Buutenks and Buuhan were the only two of the whole
  # list actually UNREACHABLE by any other means before this pass.
  # SS4 Gogeta, SSB Vegito, and Mastered Berserk Kefla added this same pass
  # once their inputs were confirmed to exist (see DBZ_FUSION_EXTRA_IDS for
  # the three of those five inputs that needed the extra-ID allowance).
  CURATED_FUSIONS = {
    [:GOTEN, :TRUNKS].sort        => :GOTENKS,
    [:CAULIFLA, :KALE].sort       => :KEFLA,
    [:SSJGOTEN, :SSJTRUNKS].sort  => :GOTENKS2,
    [:KIBITO, :KAIOSHIN].sort     => :KIBITOSHIN,
    [:ZAMASU, :GOKUBLACK].sort    => :MZAMASU,
    [:BABY, :MJNVEGETA].sort      => :BABYVEGETA,
    [:ANDROID17, :ANDROID17].sort => :SUPER17,
    [:SUPERBUU, :GOTENKS3].sort   => :BUUTENKS,
    [:SUPERBUU, :ULTMGOHAN].sort  => :BUUHAN,
    [:SS4GOKU, :SS4VEGETA].sort   => :SS4GOGETA,
    [:SSBGOKU, :SSBVEGETA].sort   => :SSBVEGITO,
    [:MBSKKALE, :CAULIFLA2].sort  => :MBSKKEFLA,
    # 2026-08-31 (round 2, DBZ Ultimate Team Training-sourced recipes - see
    # DBZ_FUSION_EXTRA_IDS comment above for how these were tracked down):
    [:GOHAN, :TRUNKS].sort        => :GOHANKS,
    [:GOKU, :GOHAN].sort          => :GOKHAN2,
    [:RADITZ2, :GOKU].sort        => :GODITZ,
    [:RANCH, :TRUNKS].sort        => :RAUNKS,
    [:GTGOTEN, :GTTRUNKS].sort    => :GTGOTENKS,
    # 2026-09-01: FP (Full Power) Pikkon is two Pikkon fused together,
    # same self-fusion pattern as Android17+Android17=Super17 above.
    [:PIKKON, :PIKKON].sort       => :FPPIKKON,
  }

  # True if this species is one of ours in the DBZ block AND specifically
  # from the DBZ Infinite Fusion roster (see DBZ_INF_DEX_NUMBERS above) -
  # i.e. allowed to fuse with another DBZ-Inf species. Real Pokemon
  # (dex <=727) and Animon/other-anime species (dex 1053-1326) return false,
  # and so do Team Training-only DBZ-block species even though they share
  # the same dex range.
  def self.dbz_species?(species)
    data = GameData::Species.try_get(species)
    return false unless data
    in_main_block = DBZ_DEX_RANGE.include?(data.id_number) && DBZ_INF_DEX_NUMBERS.include?(data.id_number)
    in_extras = DBZ_FUSION_EXTRA_IDS.include?(data.id_number)
    return added_species.include?(data.species) && (in_main_block || in_extras)
  end

  # True if this species should be blocked from taking part in a fusion at
  # all (either role) - preserves the vanilla "already fused" gate for real
  # fusions and excludes Animon species, while newly allowing DBZ-block ones.
  def self.blocks_fusion?(species)
    return false if dexNum(species) <= NB_POKEMON
    return !dbz_species?(species)
  end

  # Resolves the fusion result for two DBZ-block species, or nil if either
  # parent isn't actually one of ours in that block.
  def self.dbz_fusion_result(body_species, head_species)
    return nil unless dbz_species?(body_species) && dbz_species?(head_species)
    body_data = GameData::Species.try_get(body_species)
    head_data = GameData::Species.try_get(head_species)
    ordered = ORDERED_FUSIONS[[body_data.species, head_data.species]]
    return GameData::Species.get(ordered) if ordered
    curated = CURATED_FUSIONS[[body_data.species, head_data.species].sort]
    return GameData::Species.get(curated) if curated
    return GameData::Species.get(get_fusion_symbol(head_data.id_number, body_data.id_number))
  end
end

#----------------------------------------------------------------------------
# pbFuse (Data/Scripts/052_InfiniteFusion/Gameplay/Items/New Items effects.rb)
# hardcodes newid = body.id_number*NB_POKEMON + head.id_number, the same
# integer scheme that breaks for our DBZ pairs (see header above). Delegate
# to it unchanged for every non-DBZ fusion (including chaining correctly
# through any other mod's own pbFuse alias, e.g. counterfeit_shinies); only
# the DBZ+DBZ path is reproduced here, swapped to use the resolved result's
# species symbol as newid instead.
#
# "No items needed" (2026-08-31, user request - our take on the DBZ Team
# Training Fusion Machine, which needs no item for Metamoran/Special fusion
# but does for Potara): our dbz_fusion_result never checks held items in the
# first place, so a curated pair fuses with nothing held - that alone already
# covers the Potara/Up-Grade requirement. The one remaining cost is the
# Splicer item itself, auto-deducted by the vanilla item-use screen after
# whatever calls pbFuse returns true (outside this file, so not something we
# can skip); refunding it back to the bag right before returning nets it to
# free without touching that shared deduction code path, so non-DBZ fusions
# via the same Splicer item are still charged normally.
#
# Guaranteed-shiny-on-fusion and IV averaging need no new code here - both
# are already unconditional base-engine behavior in
# PokemonFusionScene#pbFusionScreen (Fusion/Data/PokemonFusion.rb).
#----------------------------------------------------------------------------
alias animefusionmerge_orig_pbFuse pbFuse unless defined?(animefusionmerge_orig_pbFuse)
def pbFuse(pokemon_body, pokemon_head, splicer_item, fusion_pif_sprite = nil)
  dbz_result = AnimeFusionMerge.dbz_fusion_result(pokemon_body.species, pokemon_head.species)
  unless dbz_result
    return animefusionmerge_orig_pbFuse(pokemon_body, pokemon_head, splicer_item, fusion_pif_sprite)
  end

  original_head = pokemon_head.clone
  original_body = pokemon_body.clone
  use_supersplicers_mechanics = isSuperSplicersMechanics(splicer_item)
  newid = dbz_result.species
  fus = PokemonFusionScene.new
  if fus.pbStartScreen(pokemon_body, pokemon_head, newid, splicer_item, fusion_pif_sprite)
    returnItemsToBag(pokemon_body, pokemon_head)
    fus.pbFusionScreen(false, use_supersplicers_mechanics)
    $game_variables[VAR_FUSE_COUNTER] += 1
    fus.pbEndScreen
    $PokemonTemp.fuse_count_today = 0 unless $PokemonTemp.fuse_count_today
    $PokemonTemp.fuse_count_today += 1
    checkFuseChallenges(original_head, original_body)
    $PokemonBag.pbStoreItem(splicer_item, 1) if splicer_item
    return true
  end
end
