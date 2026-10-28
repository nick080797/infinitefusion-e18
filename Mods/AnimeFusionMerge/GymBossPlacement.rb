#==============================================================================
# Anime Fusion Merge - Gym/Elite Four/Champion corner-boss placement
#
# Adds ONE extra, fully optional trainer NPC into each of Kanto's 8 gym rooms,
# 4 Elite Four rooms and the Champion's room - standing next to (not replacing)
# the existing vanilla leader. Battling them fights the DBZ counterpart already
# registered in this mod's trainers.txt (Yajirobe/Brock, Muri/Misty, etc.),
# using DBZ's own overworld sprite for that character (copied into
# Graphics/Characters/ by the mod loader's asset-install step).
#
# Nothing here touches any base .rxdata map file. The new event is built from
# scratch in memory and injected via Events.onMapCreate, which fires with the
# raw pre-conversion RPG::Map object - anything added to @map.events here gets
# turned into a live Game_Event by the vanilla code that runs immediately
# after this hook (Game_Map#setup, 004_Game classes/004_Game_Map.rb). Fully
# additive and reversible: delete this file and the extra NPCs are gone.
#
# Battles are repeatable "rematch ladder" style (per the confirmed design):
# each boss has one or more tiers (see :tiers); beating the current tier
# advances to the next one for next time, capping at the last tier. Progress
# is stored in $PokemonGlobal so it saves with the game.
#
# Animon's 13 counterparts ARE included below. Their roster was identified
# straight from real data, not guessed: trainers_dump.txt (Animon's own GBA
# export) tags trainer classes LEADER (x8: Nami, Denki, Jackie, Reigan,
# Winry, Shiemi, Anna, Yugi), ELITE FOUR (x4: Kaiba, Hiyuri, Erwin, Blank)
# and CHAMPION (Light) - exactly 8+4+1. Cross-checked against this mod's own
# trainers.txt, which already carries real [LEADER,Nami] / [ELITEFOUR,Kaiba]
# / [CHAMPION,Light] entries (plus rematch versions) - so unlike DBZ, no
# vanilla-name translation is needed here: the anime name IS the PBS name.
# ("Zero", floated earlier as a guess, is actually a separate BOSS-class
# Team-Rocket-style trainer in Animon, not the Champion - Light is.)
# Since Animon has no dedicated overworld art in this project, each gets a
# human sprite borrowed from the base game's own bundled "BW (N).png" pack
# (409 shared community sprites already installed in Graphics/Characters/,
# visually confirmed human via a contact-sheet review).
#
# NOT included here (deliberately out of scope for this pass):
# - The per-source-game "legendary gate" switch (flips after a full 8+4+1
#   gauntlet is cleared) - separate follow-up.
# - Any reward item that doesn't already exist in this game's items.txt
#   (Senzu, Z-Drink, and the TM23/Teleport reward from the West Kai/Babidi
#   guide data all fall in this bucket - Zeni is granted, the item part is
#   skipped until those items exist).
#==============================================================================
module AnimeFusionMerge
  # map_id => array of boss NPC defs to inject into that map.
  # anchor: [x,y] of the EXISTING vanilla leader event in that room (used only
  #         to derive a safe nearby spot - the vanilla event itself is never
  #         touched). offset: [dx,dy] applied to anchor for the new NPC.
  # tiers: ordered list of trainers.txt version numbers; battle starts at
  #        tier 0 and advances by 1 each win, capping at the last entry.
  GYM_BOSS_NPCS = {
    386 => [
      { id: :dbz_gym1, anchor: [9, 6], offset: [-2, 0],
        graphic: "BW_brock",     trainer_type: :LEADER_Brock,    trainer_name: "Brock",
        display_name: "Yajirobe", tiers: [900, 901], reward_money: 3000 },
      { id: :animon_gym1, anchor: [9, 6], offset: [2, 0],
        graphic: "BW (16)", trainer_type: :LEADER, trainer_name: "Nami",
        display_name: "Nami", tiers: [0, 1], reward_money: 3000 },
    ],
    4   => [
      { id: :dbz_gym2, anchor: [9, 8], offset: [-2, 0],
        graphic: "BWLeaderMisty", trainer_type: :LEADER_Misty,    trainer_name: "Misty",
        display_name: "Muri",     tiers: [900], reward_money: 3000 },
      { id: :animon_gym2, anchor: [9, 8], offset: [2, 0],
        graphic: "BW (19)", trainer_type: :LEADER, trainer_name: "Denki",
        display_name: "Denki", tiers: [0, 1], reward_money: 3000 },
    ],
    # Map61 shares the "Vermillion City Gym" name with Map24 and also matches
    # Surge's coordinates - can't tell which one is actually used in-game, so
    # Gym 3's corner NPCs go in BOTH rooms (same :id per boss, so rematch-tier
    # progress carries over regardless of which room the player visits).
    24  => [
      { id: :dbz_gym3, anchor: [9, 6], offset: [-2, 0],
        graphic: "BW_surge",      trainer_type: :LEADER_Surge,    trainer_name: "Lt. Surge",
        display_name: "General Red", tiers: [900], reward_money: 3500 },
      { id: :animon_gym3, anchor: [9, 6], offset: [2, 0],
        graphic: "BW (22)", trainer_type: :LEADER, trainer_name: "Jackie",
        display_name: "Jackie", tiers: [0], reward_money: 3500 },
    ],
    61  => [
      { id: :dbz_gym3, anchor: [9, 6], offset: [-2, 0],
        graphic: "BW_surge",      trainer_type: :LEADER_Surge,    trainer_name: "Lt. Surge",
        display_name: "General Red", tiers: [900], reward_money: 3500 },
      { id: :animon_gym3, anchor: [9, 6], offset: [2, 0],
        graphic: "BW (22)", trainer_type: :LEADER, trainer_name: "Jackie",
        display_name: "Jackie", tiers: [0], reward_money: 3500 },
    ],
    542 => [
      { id: :dbz_gym4, anchor: [12, 13], offset: [-2, 0],
        graphic: "BW_Erika",      trainer_type: :LEADER_Erika,    trainer_name: "Erika",
        display_name: "Bulma",    tiers: [900], reward_money: 3500 },
      { id: :animon_gym4, anchor: [12, 13], offset: [2, 0],
        graphic: "BW (25)", trainer_type: :LEADER, trainer_name: "Reigan",
        display_name: "Reigan", tiers: [0, 1], reward_money: 3500 },
    ],
    479 => [
      { id: :dbz_gym5, anchor: [13, 9], offset: [-2, 0],
        graphic: "BW_koga",       trainer_type: :LEADER_Koga,     trainer_name: "Koga",
        display_name: "Satan",    tiers: [900], reward_money: 4000 },
      { id: :animon_gym5, anchor: [13, 9], offset: [2, 0],
        graphic: "BW (31)", trainer_type: :LEADER, trainer_name: "Winry",
        display_name: "Winry", tiers: [0, 1], reward_money: 4000 },
    ],
    152 => [
      { id: :dbz_gym6, anchor: [13, 2], offset: [-2, 0],
        graphic: "BW_Sabrina",    trainer_type: :LEADER_Sabrina,  trainer_name: "Babidi",
        display_name: "Babidi",   tiers: [900], reward_money: 4500 },
      { id: :animon_gym6, anchor: [13, 2], offset: [2, 0],
        graphic: "BW (34)", trainer_type: :LEADER, trainer_name: "Shiemi",
        display_name: "Shiemi", tiers: [0, 1], reward_money: 4500 },
    ],
    221 => [
      { id: :dbz_gym7, anchor: [14, 4], offset: [-2, 0],
        graphic: "BW_Blaine",     trainer_type: :LEADER_Blaine,   trainer_name: "Blaine",
        display_name: "Roshi",    tiers: [900], reward_money: 4500 },
      { id: :animon_gym7, anchor: [14, 4], offset: [2, 0],
        graphic: "BW (37)", trainer_type: :LEADER, trainer_name: "Anna",
        display_name: "Anna", tiers: [0, 1], reward_money: 4500 },
    ],
    85  => [
      { id: :dbz_gym8, anchor: [9, 7], offset: [-2, 0],
        graphic: "BW_giovanni",   trainer_type: :LEADER_Giovanni, trainer_name: "Giovanni",
        display_name: "Pilaf",    tiers: [900], reward_money: 5000 },
      { id: :animon_gym8, anchor: [9, 7], offset: [2, 0],
        graphic: "BW (45)", trainer_type: :LEADER, trainer_name: "Yugi",
        display_name: "Yugi", tiers: [0, 1], reward_money: 5000 },
    ],
    315 => [
      { id: :dbz_e4_1, anchor: [10, 9], offset: [-2, 0],
        graphic: "BW_Lorelei",    trainer_type: :ELITEFOUR_Lorelei, trainer_name: "Lorelei",
        display_name: "East Kai", tiers: [900], reward_money: 6000 },
      { id: :animon_e4_1, anchor: [10, 9], offset: [2, 0],
        graphic: "BW (48)", trainer_type: :ELITEFOUR, trainer_name: "Kaiba",
        display_name: "Kaiba", tiers: [0, 1, 2], reward_money: 6000 },
    ],
    316 => [
      { id: :dbz_e4_2, anchor: [10, 9], offset: [-2, 0],
        graphic: "BW (57)",       trainer_type: :ELITEFOUR_Bruno,   trainer_name: "Bruno",
        display_name: "South Kai", tiers: [900], reward_money: 6000 },
      { id: :animon_e4_2, anchor: [10, 9], offset: [2, 0],
        graphic: "BW (51)", trainer_type: :ELITEFOUR, trainer_name: "Hiyuri",
        display_name: "Hiyuri", tiers: [0, 1], reward_money: 6000 },
    ],
    317 => [
      { id: :dbz_e4_3, anchor: [10, 9], offset: [-2, 0],
        graphic: "BW (40)",       trainer_type: :ELITEFOUR_Agatha,  trainer_name: "West Kai",
        display_name: "West Kai", tiers: [900, 901], reward_money: 5800 },
      { id: :animon_e4_3, anchor: [10, 9], offset: [2, 0],
        graphic: "BW (54)", trainer_type: :ELITEFOUR, trainer_name: "Erwin",
        display_name: "Erwin", tiers: [0, 1], reward_money: 6000 },
    ],
    318 => [
      { id: :dbz_e4_4, anchor: [10, 9], offset: [-2, 0],
        graphic: "BW_Lance",      trainer_type: :ELITEFOUR_Lance,   trainer_name: "Lance",
        display_name: "North Kai", tiers: [900], reward_money: 6000 },
      { id: :animon_e4_4, anchor: [10, 9], offset: [2, 0],
        graphic: "BW (60)", trainer_type: :ELITEFOUR, trainer_name: "Blank",
        display_name: "Blank", tiers: [0, 1], reward_money: 6000 },
    ],
    # Champion Blue's leader event matches at two different spots on Map328 -
    # (10,8) and (0,28) - can't tell which is the real one, so both get the
    # corner NPCs (same :id per boss, so tier progress carries over).
    328 => [
      # DBZ's champion room event battles vanilla [CHAMPION,Blue,900-908] (9
      # PBS versions, confirmed in trainers.txt) under the DBZ flavor name
      # "Zero" - trainer_name must stay "Blue" (the real PBS lookup key);
      # only display_name is the DBZ character name.
      { id: :dbz_champ, anchor: [10, 8], offset: [-2, 0],
        graphic: "gary_oak_overworld_bw_completed_by_malice936-d5ruwuc",
        trainer_type: :CHAMPION, trainer_name: "Blue", display_name: "Zero",
        tiers: [900, 901, 902, 903, 904, 905, 906, 907, 908], reward_money: 10000 },
      # Animon: Zero IS the real Champion (first win records the Hall-of-Fame
      # style victory); trainers.txt only has one PBS version for Zero.
      # Rematches instead face Light (4 PBS versions) - per the user's
      # correction, not the earlier guess that Light was the Champion.
      { id: :animon_champ, anchor: [10, 8], offset: [2, 0],
        graphic: "BW (63)", trainer_type: :CHAMPION, trainer_name: "Zero", display_name: "Zero",
        reward_money: 10000,
        tiers: [
          { version: 0, win_message: "Your Pokemon League victory has been recorded!",
            advance_message: "Rumor has it a challenger named Light awaits those who dare a rematch..." },
          { version: 0, trainer_name: "Light", display_name: "Light" },
          { version: 1, trainer_name: "Light", display_name: "Light" },
          { version: 2, trainer_name: "Light", display_name: "Light" },
          { version: 3, trainer_name: "Light", display_name: "Light" },
        ] },
      { id: :dbz_champ, anchor: [0, 28], offset: [-2, 0],
        graphic: "gary_oak_overworld_bw_completed_by_malice936-d5ruwuc",
        trainer_type: :CHAMPION, trainer_name: "Blue", display_name: "Zero",
        tiers: [900, 901, 902, 903, 904, 905, 906, 907, 908], reward_money: 10000 },
      { id: :animon_champ, anchor: [0, 28], offset: [3, 1],
        graphic: "BW (63)", trainer_type: :CHAMPION, trainer_name: "Zero", display_name: "Zero",
        reward_money: 10000,
        tiers: [
          { version: 0, win_message: "Your Pokemon League victory has been recorded!",
            advance_message: "Rumor has it a challenger named Light awaits those who dare a rematch..." },
          { version: 0, trainer_name: "Light", display_name: "Light" },
          { version: 1, trainer_name: "Light", display_name: "Light" },
          { version: 2, trainer_name: "Light", display_name: "Light" },
          { version: 3, trainer_name: "Light", display_name: "Light" },
        ] },
    ],
  }.freeze

  # Flat lookup by :id, built once from GYM_BOSS_NPCS.
  def self.boss_lookup
    return @boss_lookup if @boss_lookup
    @boss_lookup = {}
    GYM_BOSS_NPCS.each_value { |list| list.each { |d| @boss_lookup[d[:id]] = d } }
    @boss_lookup
  end

  # Overrides for the explicit West Kai / Babidi rewards the user supplied
  # (5800 base / 7000 rematch, and 4500 flat respectively). Keyed by tier
  # index so West Kai's rematch tier pays out the higher amount.
  BOSS_REWARD_BY_TIER = {
    dbz_e4_3: [5800, 7000],
    dbz_gym1: [3000, 3800], # Brock rematch - no guide figure given, scaled up
  }.freeze

  # A :tiers entry is normally a bare PBS version Integer (battles data's own
  # trainer_type/trainer_name/display_name). It can also be a Hash to swap in
  # a DIFFERENT trainer at that tier - needed for Animon's Champion room,
  # where the first win is against Zero (the real Champion) and every
  # rematch after that is against Light instead (per trainers.txt: Zero has
  # exactly one PBS version, Light has 4 - confirmed real data, not a guess).
  def self.tier_info(data, tier_idx)
    entry = data[:tiers][tier_idx]
    return { version: entry, trainer_type: data[:trainer_type], trainer_name: data[:trainer_name],
             display_name: data[:display_name], win_message: nil, advance_message: nil } unless entry.is_a?(Hash)
    { version: entry[:version],
      trainer_type: entry[:trainer_type] || data[:trainer_type],
      trainer_name: entry[:trainer_name] || data[:trainer_name],
      display_name: entry[:display_name] || data[:display_name],
      win_message: entry[:win_message], advance_message: entry[:advance_message] }
  end

  # Which of the 13 GYM_BOSS_NPCS :id values belong to each source game's
  # 8 gym + 4 E4 + 1 champion gauntlet - used to tell when that game's
  # "legendary gate" should open (see LegendaryEncounters.rb). Derived
  # straight from the :id naming convention already used above, not guessed.
  GAME_BOSS_IDS = {
    dbz: [:dbz_gym1, :dbz_gym2, :dbz_gym3, :dbz_gym4, :dbz_gym5, :dbz_gym6,
          :dbz_gym7, :dbz_gym8, :dbz_e4_1, :dbz_e4_2, :dbz_e4_3, :dbz_e4_4, :dbz_champ],
    animon: [:animon_gym1, :animon_gym2, :animon_gym3, :animon_gym4, :animon_gym5,
             :animon_gym6, :animon_gym7, :animon_gym8, :animon_e4_1, :animon_e4_2,
             :animon_e4_3, :animon_e4_4, :animon_champ],
  }.freeze

  # How many of that game's 13 gauntlet bosses have been beaten at least
  # once (0-13). Uses a dedicated one-time-win set (afm_boss_beaten) rather
  # than afm_boss_tier, because a single-tier boss's tier_idx never advances
  # past 0 even after being won (nothing to advance to), so tier_idx > 0
  # would never trigger for those. LegendaryEncounters.rb compares this
  # against each legendary's own dex-order unlock threshold to unlock them
  # one at a time instead of all at once.
  def self.bosses_beaten_count(game)
    ids = GAME_BOSS_IDS[game]
    return 0 unless ids
    $PokemonGlobal.afm_boss_beaten ||= {}
    ids.count { |id| $PokemonGlobal.afm_boss_beaten[id] }
  end

  # True once every boss in that game's gauntlet has been beaten at least
  # once. Kept for the "a powerful presence stirs" flavor message below.
  def self.legendary_gate_open?(game)
    ids = GAME_BOSS_IDS[game]
    return false unless ids
    bosses_beaten_count(game) >= ids.length
  end

  def self.trigger_boss_battle(id)
    data = boss_lookup[id]
    return unless data
    $PokemonGlobal.afm_boss_tier ||= {}
    tier_idx = $PokemonGlobal.afm_boss_tier[id] || 0
    tier_idx = [tier_idx, data[:tiers].length - 1].min
    info = tier_info(data, tier_idx)
    pbMessage(_INTL("{1} wants to battle!", info[:display_name]))
    won = pbTrainerBattle(info[:trainer_type], info[:trainer_name], nil, false,
                           info[:version], false, 1, info[:display_name])
    return unless won
    pbMessage(_INTL("You defeated {1}!", info[:display_name]))
    pbMessage(_INTL(info[:win_message])) if info[:win_message]
    rewards = BOSS_REWARD_BY_TIER[id]
    money = rewards ? (rewards[tier_idx] || rewards.last) : (data[:reward_money] || 3000)
    pbReceiveMoney(money)
    if tier_idx < data[:tiers].length - 1
      $PokemonGlobal.afm_boss_tier[id] = tier_idx + 1
      next_info = tier_info(data, tier_idx + 1)
      msg = info[:advance_message] ? _INTL(info[:advance_message]) :
            _INTL("{1}: Come back when you've gotten stronger - I'll be ready.", next_info[:display_name])
      pbMessage(msg)
    end
    $PokemonGlobal.afm_boss_beaten ||= {}
    before = GAME_BOSS_IDS.keys.map { |g| [g, bosses_beaten_count(g)] }.to_h
    $PokemonGlobal.afm_boss_beaten[id] = true
    GAME_BOSS_IDS.each_key do |game|
      after = bosses_beaten_count(game)
      next if after == before[game]
      AnimeFusionMerge.announce_new_legendary_unlocks(game, before[game], after) if AnimeFusionMerge.respond_to?(:announce_new_legendary_unlocks)
    end
  end

  def self.make_boss_event(event_id, x, y, npc)
    event = RPG::Event.new(x, y)
    event.id = event_id
    event.name = "AFM_#{npc[:id]}"
    page = event.pages[0]
    page.trigger = 0 # Action Button
    page.graphic.character_name = npc[:graphic]
    page.graphic.character_hue = 0
    page.graphic.direction = 2 # Facing down
    page.move_type = 0 # Fixed - never wanders off its tile
    page.through = false
    page.list = [
      RPG::EventCommand.new(355, 0, ["AnimeFusionMerge.trigger_boss_battle(:#{npc[:id]})"]),
      RPG::EventCommand.new(0, 0, []),
    ]
    event
  end

  def self.inject_boss_npcs(map_id, map)
    list = GYM_BOSS_NPCS[map_id]
    return unless list
    next_id = (map.events.keys.max || 0)
    list.each do |npc|
      ax, ay = npc[:anchor]
      dx, dy = npc[:offset]
      x = ax + dx
      y = ay + dy
      x = ax - dx if x < 0 || (map.width && x >= map.width)
      y = ay - dy if y < 0 || (map.height && y >= map.height)
      next_id += 1
      map.events[next_id] = make_boss_event(next_id, x, y, npc)
    end
  end
end

Events.onMapCreate += proc { |_sender, e|
  map_id, map = e[0], e[1]
  AnimeFusionMerge.inject_boss_npcs(map_id, map)
}
