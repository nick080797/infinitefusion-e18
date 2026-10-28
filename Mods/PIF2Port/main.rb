#==============================================================================
# PIF2Port - near-1:1 port of real Pokemon Infinite Fusion 2 maps into the
# Multiverse Hub.
#
# Unlike a from-scratch synthetic gauntlet map (see Mods/MultiverseHub), this
# loads PIF2's REAL Marshal-serialized .rxdata map data directly -- PIF2 runs
# on the same RGSS1/RPG Maker XP engine fork as this host game, so its
# RPG::Map/RPG::Event/RPG::Tileset objects deserialize cleanly through this
# engine's own native classes. Confirmed live via a one-time diagnostic pass
# (Marshal.load of PIF2's System/MapInfos/Tilesets/CommonEvents/a sample map,
# all clean, zero errors) before this loader was written.
#
# Ids collide between the two games (switch 5, map 9, etc. mean completely
# different things in each), so every relevant id is shifted by a reserved
# offset (50000) before the map is handed to the engine:
#   - map id            (map.tileset_id references, transfer-player targets)
#   - switch id          (event page conditions, code 111/121)
#   - variable id         (event page conditions, code 111/122)
#   - tileset id          (map.tileset_id -> new $data_tilesets entry)
# Tileset PNG/panorama/fog/battleback/character-sprite assets are copied on
# first use into Mods/PIF2Port/Graphics/<Category>/ (namespaced) rather than
# referenced by bare filename, because PIF2 and the host both ship same-named
# PNGs (tilesets like "route-field.png"/"cave.png", and likely NPC character
# sheets too) with different actual content -- a bare-name reference would
# silently grab the HOST's asset instead (or render an invisible/misplaced
# NPC if the host has no file of that name at all -- a real crash/bug found
# via playtest for event character graphics specifically, fixed the same way
# tilesets already were). The copy
# is done with plain Dir.mkdir/File.binread/File.binwrite, NOT FileUtils --
# this mkxp-z build's embedded Ruby doesn't ship the fileutils stdlib, which
# caused a real in-game LoadError crash (opening the PC -> Change Game) before
# this was fixed.
#
# Autotiles are copied differently (see copy_autotile): namespaced directly
# under the real Graphics/Autotiles/PIF2Port/ tree instead of Mods/, because
# the renderer's autotile cache (001_TilemapRenderer.rb AutotileBitmaps#add)
# writes a derived "expanded" copy to Graphics/Autotiles/ExpandedAutotiles/
# using naive string concatenation with no ".." normalization -- a Mods/-
# relative "../../" name resolves that write to a nonexistent path and
# crashes with Errno::ENOENT the first time the map actually renders (not at
# boot, since that cache write is lazy too). Both real crashes above were
# found via actual user gameplay, fixed, and confirmed via a temporary
# self-test at mod-load time (build_map()/copy_asset()/copy_autotile() called
# directly, since their triggering code paths are otherwise only exercised
# by an actual PC warp or map render) -- see project_multiverse_hub memory
# for the full incident writeup.
#
# Rather than re-implementing the PC menu / warp / map-isolation plumbing,
# this mod reuses MultiverseHub's: it appends into the existing
# MultiverseHubSettings::GAMES table and MultiverseHub::GAUNTLET_MAP_BUILDERS
# hash, so MultiverseHub's own load_data/pbLoadMapInfos hooks and its
# PokemonMapFactory/TilemapRenderer isolation hooks pick up the ported map(s)
# automatically -- this file only needs to load AFTER MultiverseHub
# (mod.json dependency) and supply real map data.
#
# FULL PORT (every real map, not just the Littleroot pilot) / known gaps
# (see project_multiverse_hub memory):
#   - Every real PIF2 map (~116, everything MapInfos.rxdata lists that has an
#     actual Map###.rxdata file - folder-only tree nodes like "Hoenn"/"COMMON"
#     are filtered out) gets a GAUNTLET_MAP_BUILDERS entry, so any door/
#     transfer event (code 201) that targets one now resolves instead of
#     crashing with Errno::ENOENT when load_data can't find a builder for an
#     unregistered map id (the exact bug behind "crashed as soon as I walked
#     into a building" - only Littleroot itself was registered before this).
#     Only ONE of them (PIF2PortSettings::START_MAP_ID, Littleroot Town) gets
#     its own "Infinite Fusion 2" PC menu line - the rest are reached by
#     walking through PIF2's own real doors from there, not picked
#     individually out of "Change Game". All of them still count as
#     gauntlet/virtual territory (MultiverseHubSettings::EXTRA_GAUNTLET_MAP_NAMES) for
#     the isolation hooks and the pause-menu "Return to Main Game" gate.
#   - "Call Common Event" (event code 117) IS now remapped: PIF2Port.
#     ensure_common_events ports all ~250 of PIF2's common events into
#     $data_common_events the first time any map is built, recursively
#     remapping each common event's own switch/variable/map/common-event
#     references the same way map events are. Unlike every other id type
#     here, common events get CONTIGUOUS new ids (see common_event_id_map),
#     not a flat +50000 offset - the engine instantiates a real object for
#     every index in $data_common_events' range on every map setup, so a
#     50000-wide gap of nils crashed the very next map transfer (the actual
#     "crashed when changing to pif2" bug hit during a real playtest).
#   - Outdoor map-EDGE connections ARE now ported: PIF2Port.
#     real_map_connections reads PIF2's own Data/map_connections.dat,
#     remaps both map ids, and feeds them into MultiverseHubSettings::
#     EXTRA_MAP_CONNECTIONS, which MultiverseHub's load_data hook injects
#     into the real connections list. MultiverseHub's map-isolation hooks
#     (updateMapsInternal/check_if_screen_moved) now only isolate a gauntlet
#     map when it has NO real connection data, so a connected ported map
#     uses the engine's normal multi-map loading and walking off its border
#     reaches its real neighbor, same as any two vanilla-adjacent maps.
#   - Player spawn point for the single PC-menu entry map is chosen
#     heuristically (nearest passable tile to map center, layer-0-only
#     passability check) rather than PIF2's real default player start - may
#     need manual adjustment after playtest.
#==============================================================================
module PIF2PortSettings
  PIF2_DATA_DIR     = "E:/pokemon infinite fusion and mods/InfiniteFusion/InfiniteFusion2/Data"
  PIF2_GRAPHICS_DIR = "E:/pokemon infinite fusion and mods/InfiniteFusion/InfiniteFusion2/Graphics"
  MOD_GRAPHICS_DIR  = "Mods/PIF2Port/Graphics"

  MAP_OFFSET          = 50000
  SWITCH_OFFSET       = 50000
  VARIABLE_OFFSET     = 50000
  TILESET_OFFSET      = 50000
  # Not a flat offset applied to every trainer - see PIF2Port.port_trainers.
  # Real PIF2 trainers only get bumped onto this range's next free number
  # when their [type, name, version] key COLLIDES with a trainer the host
  # already has (both games start from the same base-game Hoenn roster, so
  # early trainers like YOUNGSTER "Allen" at version 0 are near-guaranteed
  # to collide) - every other trainer keeps its real PIF2 version untouched.
  TRAINER_VERSION_BASE = 50000
  # Every ported trainer gets a FRESH id_number from this base, always (not
  # just on collision) - see PIF2Port.port_trainers for why: GameData's
  # generic ClassMethods#register (010_Data/001_GameData.rb) double-keys
  # every entry as both self::DATA[real_id] AND self::DATA[id_number], and
  # both games assign id_numbers sequentially from 0, so a PIF2 trainer's
  # numeric alias colliding with one the host already has is close to
  # guaranteed - cheaper and safer to always renumber than to check each one.
  TRAINER_ID_NUMBER_BASE = 60000
  # Same double-keying issue for trainer TYPES (register does the identical
  # DATA[id] = DATA[id_number] = obj) - see port_trainer_types. Only actually
  # used on collision here, since trainer types are a small, mostly-shared
  # roster (see trainer_type_id_map's comment) and a fresh symbol usually
  # also means a numeric id_number gap - but PIF2 and the host both starting
  # their own numbering from 0 makes SOME collision likely even then.
  TRAINER_TYPE_ID_NUMBER_BASE = 61000
  # No flat COMMON_EVENT_OFFSET - see PIF2Port.common_event_id_map. Unlike
  # switches/variables/maps/tilesets (plain sparse-safe lookups), the engine
  # iterates $data_common_events by index range and instantiates a real
  # object for every slot, so a 50000-wide gap of nils crashes the very next
  # map setup. Common event ids are assigned contiguously instead.

  # Real PIF2 map id used as the single "Infinite Fusion 2" PC menu entry
  # point. Every other real map is still ported (see ported_maps below) and
  # reachable from here via PIF2's own real door/transfer events -- it just
  # doesn't get its own PC menu line.
  START_MAP_ID = 9 # Littleroot Town

  def self.remapped_id(real_id)
    MAP_OFFSET + real_id
  end

  # SWITCH_HOENN_STARTERS (885) and its region-starter-list siblings
  # (SWITCH_JOHTO/SINNOH/KANTO/KALOS/MIXED_STARTERS, 884/886/887/888/889 --
  # 052_InfiniteFusion/Constants/CONSTANTS_Switches.rb) are shared,
  # host-wide feature flags read directly by these raw ids in
  # 052_InfiniteFusion/Gameplay/Player/Starters.rb#obtainStarter -- not
  # per-instance PIF2 story state like the 2000+-range switches everywhere
  # else in this file. PIF2's own ported starter event (InfiniteFusion2
  # source Map005 ev2 "bag") sets switch 885 ON right before calling
  # hoennSelectStarter, so obtainStarter hands out Treecko/Torchic/Mudkip
  # instead of falling through to Settings::DEFAULT_STARTERS (KANTO_STARTERS
  # on this host, since its own GAME_ID is :IF_KANTO) -- confirmed by
  # dumping that event's raw command list. Remapping that SET command like
  # every other switch id turns it into "set switch 50885", which
  # obtainStarter's plain $game_switches[SWITCH_HOENN_STARTERS] check never
  # sees, so it silently falls through to the host's Kanto default
  # (Bulbasaur/Charmander/Squirtle) every time -- the "starter's not from
  # the right list" bug report. Leaving this specific handful of ids
  # unshifted lets the real event genuinely flip the real switch the shared
  # code reads, instead of force-setting anything by hand.
  SHARED_GLOBAL_SWITCHES = [884, 885, 886, 887, 888, 889].freeze

  def self.remap_switch_id(real_id)
    return real_id if SHARED_GLOBAL_SWITCHES.include?(real_id)
    real_id + SWITCH_OFFSET
  end

  # MapInfos.rxdata includes organizational folder nodes (e.g. real ids 1
  # "Hoenn", 175 "COMMON", 15 "New maps" -- editor map-tree groupings with no
  # Map###.rxdata file of their own), not just real playable maps. Filtering
  # to ids that actually have a map file on disk is what turns "every id
  # MapInfos knows about" into "every real map", cheaply and without needing
  # to hand-maintain a list.
  def self.real_map_infos
    @real_map_infos ||= Marshal.load(File.binread("#{PIF2_DATA_DIR}/MapInfos.rxdata"))
  end

  def self.all_real_map_ids
    @all_real_map_ids ||= real_map_infos.keys.select { |id|
      File.exist?("#{PIF2_DATA_DIR}/Map%03d.rxdata" % id)
    }.sort
  end

  # real PIF2 map id => display info, for every real map ("port everything")
  def self.ported_maps
    @ported_maps ||= all_real_map_ids.each_with_object({}) { |id, h|
      h[id] = { name: real_map_infos[id].name }
    }
  end
end

module PIF2Port
  @pif2_tilesets = nil
  @built_maps    = {}

  def self.pif2_tilesets
    @pif2_tilesets ||= Marshal.load(File.binread("#{PIF2PortSettings::PIF2_DATA_DIR}/Tilesets.rxdata"))
  end

  def self.load_real_map(real_id)
    Marshal.load(File.binread("#{PIF2PortSettings::PIF2_DATA_DIR}/Map%03d.rxdata" % real_id))
  end

  def self.ensure_dir(path)
    # Not using FileUtils.mkdir_p - this build's embedded Ruby doesn't ship
    # the fileutils stdlib (LoadError at runtime). Build the path up one
    # directory at a time with plain Dir.mkdir instead (same fix already
    # used in Mods/MultiverseHub/main.rb#ensure_tileset).
    parts = path.split('/')
    cur = ""
    parts.each do |part|
      cur = cur.empty? ? part : "#{cur}/#{part}"
      Dir.mkdir(cur) if !Dir.exist?(cur)
    end
  end

  def self.copy_asset(category, name)
    return "" if !name || name.empty?
    src = "#{PIF2PortSettings::PIF2_GRAPHICS_DIR}/#{category}/#{name}.png"
    return "" unless File.exist?(src)
    dest_dir = "#{PIF2PortSettings::MOD_GRAPHICS_DIR}/#{category}"
    ensure_dir(dest_dir)
    dest = "#{dest_dir}/#{name}.png"
    File.binwrite(dest, File.binread(src)) unless File.exist?(dest)
    "../../#{dest_dir}/#{name}"
  rescue => e
    puts "[PIF2Port] asset copy failed for #{category}/#{name}: #{e.message}"
    ""
  end

  # Autotiles need a different placement than the other categories. The
  # renderer (001_TilemapRenderer.rb AutotileBitmaps#add) caches an "expanded"
  # copy of every autotile the first time it's actually drawn, at
  # Graphics/Autotiles/ExpandedAutotiles/<filename>.png, built by plain string
  # concatenation (File.join, no ".." normalization) and then written without
  # creating intermediate directories. Our normal "../../Mods/PIF2Port/..."
  # relative-path trick (used for tileset/panorama/fog/battleback, which are
  # only ever READ, never cache-written this way) resolves to a nonexistent
  # location for that write and crashes with Errno::ENOENT the first time the
  # map actually renders -- not at boot, which is why the earlier self-test
  # (build_map only, no tilemap render) didn't catch this.
  #
  # Fix: copy autotiles into a namespaced subfolder INSIDE the real
  # Graphics/Autotiles/ tree ("PIF2Port/<name>", no ".." at all) instead of
  # under Mods/. A plain "PIF2Port/<name>" filename resolves correctly both
  # for the normal read (Graphics/Autotiles/PIF2Port/<name>.png) and for the
  # cache write (Graphics/Autotiles/ExpandedAutotiles/PIF2Port/<name>.png) as
  # long as we pre-create that second nested folder too, which we can since
  # we know the namespace up front. "PIF2Port" can't collide with any real
  # PIF2 or host autotile filename since it's not a filename, it's our folder.
  def self.copy_autotile(name)
    return "" if !name || name.empty?
    src = "#{PIF2PortSettings::PIF2_GRAPHICS_DIR}/Autotiles/#{name}.png"
    return "" unless File.exist?(src)
    dest_dir = "Graphics/Autotiles/PIF2Port"
    ensure_dir(dest_dir)
    dest = "#{dest_dir}/#{name}.png"
    File.binwrite(dest, File.binread(src)) unless File.exist?(dest)
    ensure_dir("Graphics/Autotiles/ExpandedAutotiles/PIF2Port")
    "PIF2Port/#{name}"
  rescue => e
    puts "[PIF2Port] autotile copy failed for #{name}: #{e.message}"
    ""
  end

  def self.ensure_tileset(real_ts_id)
    remapped = PIF2PortSettings::TILESET_OFFSET + real_ts_id
    return remapped if $data_tilesets[remapped]

    real = pif2_tilesets[real_ts_id]
    return remapped unless real

    ts = RPG::Tileset.new
    ts.id               = remapped
    ts.name             = real.name
    ts.tileset_name     = copy_asset("Tilesets", real.tileset_name)
    ts.panorama_name    = copy_asset("Panoramas", real.panorama_name)
    ts.panorama_hue     = real.panorama_hue
    ts.fog_name         = copy_asset("Fogs", real.fog_name)
    ts.fog_hue          = real.fog_hue
    ts.fog_opacity      = real.fog_opacity
    ts.fog_blend_type   = real.fog_blend_type
    ts.fog_zoom         = real.fog_zoom
    ts.fog_sx           = real.fog_sx
    ts.fog_sy           = real.fog_sy
    ts.battleback_name  = copy_asset("Battlebacks", real.battleback_name)
    ts.passages         = real.passages
    ts.priorities       = real.priorities
    ts.terrain_tags     = real.terrain_tags
    ts.autotile_names   = real.autotile_names.map { |n| copy_autotile(n) }
    $data_tilesets[remapped] = ts
    remapped
  end

  def self.remap_event_commands!(list)
    list.each do |cmd|
      case cmd.code
      when 111 # conditional branch
        case cmd.parameters[0]
        when 0 # switch
          cmd.parameters[1] = PIF2PortSettings.remap_switch_id(cmd.parameters[1])
        when 1 # variable
          cmd.parameters[1] += PIF2PortSettings::VARIABLE_OFFSET
          cmd.parameters[3] += PIF2PortSettings::VARIABLE_OFFSET if cmd.parameters[2] == 1
        when 12 # script condition - this, not a plain Script command (355/
          # 655), is where a real trainer event embeds its identity: the
          # compiler (InfiniteFusion2's own 021_Compiler/
          # 004_Compiler_MapsAndEvents.rb#convert_to_trainer_event) wraps
          # "pbTrainerBattle(:TYPE,\"Name\")" as the CONDITION of a
          # conditional branch, not a standalone command. (An earlier scan
          # that only checked codes 355/655 across all 113 real maps found
          # zero hits for this reason - dumping one real Trainer(N) event's
          # full unfiltered command list is what found it here instead.)
          # Only rewritten when PIF2Port.port_trainers actually had to
          # renumber this exact trainer's version to avoid clobbering one the
          # host already had - see that method's header comment.
          cmd.parameters[1] = PIF2Port.rewrite_trainer_battle_script(cmd.parameters[1])
        end
      when 121 # control switches (range)
        cmd.parameters[0] = PIF2PortSettings.remap_switch_id(cmd.parameters[0])
        cmd.parameters[1] = PIF2PortSettings.remap_switch_id(cmd.parameters[1])
      when 122 # control variables
        cmd.parameters[0] += PIF2PortSettings::VARIABLE_OFFSET
        cmd.parameters[1] += PIF2PortSettings::VARIABLE_OFFSET
        cmd.parameters[3] += PIF2PortSettings::VARIABLE_OFFSET if cmd.parameters[2] == 1
      when 201 # transfer player
        if cmd.parameters[0] == 0
          cmd.parameters[1] += PIF2PortSettings::MAP_OFFSET
        else
          cmd.parameters[1] += PIF2PortSettings::VARIABLE_OFFSET
          cmd.parameters[2] += PIF2PortSettings::VARIABLE_OFFSET
          cmd.parameters[3] += PIF2PortSettings::VARIABLE_OFFSET
        end
      when 117 # call common event
        mapped = common_event_id_map[cmd.parameters[0]]
        cmd.parameters[0] = mapped if mapped
      when 355, 655 # script line - see rewrite_starter_delete_script below
        cmd.parameters[0] = rewrite_starter_delete_script(cmd.parameters[0])
      end
    end
  end

  # PIF2's own Route 101 "bag" event (real Map005 ev2, both the normal and
  # custom-starter pages) hardcodes "$Trainer.party.delete_at(0)" right after
  # hoennSelectStarter/hoennSelectCustomStarter adds the chosen starter via
  # pbAddPokemonSilent. That's safe in real PIF2 because the player's party is
  # always empty at this point in its own story - the just-added starter is
  # guaranteed to land at index 0, and this line removes it again once the
  # scripted wild Zigzagoon battle ends (Birch gives you a fresh copy of the
  # same species later at the lab; this one was only ever "borrowed" for the
  # fight). In the Multiverse Hub the player already has their hub starter
  # sitting in party[0] before ever reaching PIF2, so pbAddPokemonSilent
  # appends the new starter at the END of the party instead - and this line
  # then deletes the WRONG Pokemon (the player's real hub starter) while
  # leaving the newly-chosen one in place. Confirmed by dumping this event's
  # actual raw command list (Marshal.load of the real Map005.rxdata) rather
  # than assuming it matched hoennSelectStarter's definition verbatim - the
  # user-reported "kicked my 1st pokemon out and turned it into the starter I
  # chose" bug is exactly this: party[0] removed, chosen starter still present
  # at whatever index it landed at.
  #
  # Fix: delete by object identity instead of by index. VAR_HOENN_STARTER
  # (052_InfiniteFusion/Constants) is a HOST constant, not a PIF2-internal
  # variable id needing remap - pbSet(VAR_HOENN_STARTER, pokemon) runs earlier
  # in this exact same script text and stores the SAME Pokemon object
  # pbAddPokemonSilent appended, so pbGet(VAR_HOENN_STARTER) here reliably
  # names the one Pokemon to remove regardless of where it ended up in the
  # party. Falls back to the original delete_at(0) if the variable somehow
  # isn't a real Pokemon (player backed out - the event's own next line
  # already returns early in that case, so this fallback should never
  # actually run, but keeps the rewrite from silently doing nothing on that
  # edge case).
  def self.rewrite_starter_delete_script(text)
    return text unless text == "$Trainer.party.delete_at(0)"
    "(pbGet(VAR_HOENN_STARTER).is_a?(Pokemon) ? $Trainer.party.delete(pbGet(VAR_HOENN_STARTER)) : $Trainer.party.delete_at(0))"
  end

  # Real PIF2 common-event id => new id, assigned CONTIGUOUSLY right after
  # the host's own highest existing common event id (not a flat +50000
  # offset like every other id type in this file). $data_common_events is a
  # plain id-indexed Array that the engine iterates by index RANGE on every
  # map setup, instantiating a real Game_CommonEvent for every slot in that
  # range - a 50000-wide gap of nils in between crashes the very first map
  # transfer after common events are ported (NoMethodError on nil in
  # Game_CommonEvent#trigger, from Game_Map#setup). Memoized: built once,
  # then reused by both ensure_common_events and remap_event_commands!'s
  # code-117 handling (for map events AND common events' own event lists).
  def self.common_event_id_map
    return @common_event_id_map if @common_event_id_map
    @common_event_id_map = {}
    real_list = Marshal.load(File.binread("#{PIF2PortSettings::PIF2_DATA_DIR}/CommonEvents.rxdata"))
    next_id = ($data_common_events.compact.map(&:id).max || 0) + 1
    real_list.each do |ce|
      next unless ce
      @common_event_id_map[ce.id] = next_id
      next_id += 1
    end
    @common_event_id_map
  end

  # Ports PIF2's ~250 common events into $data_common_events under the
  # contiguous ids from common_event_id_map, so code-117 "Call Common Event"
  # (remapped above) finds something real instead of whatever unrelated
  # common event happens to occupy that raw id in the HOST's own list, and
  # without leaving index gaps. Idempotent - safe to call from every
  # build_map, only does the actual work once.
  def self.ensure_common_events
    return if @common_events_ready
    @common_events_ready = true
    return unless defined?($data_common_events)
    id_map = common_event_id_map
    real_list = Marshal.load(File.binread("#{PIF2PortSettings::PIF2_DATA_DIR}/CommonEvents.rxdata"))
    real_list.each do |ce|
      next unless ce
      ce.id = id_map[ce.id]
      ce.switch_id += PIF2PortSettings::SWITCH_OFFSET if ce.respond_to?(:switch_id) && ce.switch_id
      remap_event_commands!(ce.list)
      $data_common_events[ce.id] = ce
    end
    puts "[PIF2Port] Ported #{real_list.compact.length} PIF2 common event(s)."
  rescue => e
    puts "[PIF2Port] common event port failed: #{e.class}: #{e.message}"
  end

  # Global safety net for ANY nil gap in $data_common_events -------------
  # Confirmed via a live playtest crash (NoMethodError at
  # 011_Game_CommonEvent.rb:28, undefined method `trigger' for nil, from
  # Game_Map#refresh) that happened on a plain save continue into a real
  # host map - BEFORE ensure_common_events above ever ran (it's lazy, only
  # triggered by entering a ported PIF2 map). So the gap responsible predates
  # anything this mod inserts; it's some other pre-existing hole in
  # $data_common_events. Game_Map#setup (004_Game_Map.rb) unconditionally
  # builds a Game_CommonEvent for every index in 1...$data_common_events.size
  # with no nil-check, and Game_CommonEvent's own accessors call straight
  # through to $data_common_events[id] with no nil-check either - so ANY gap
  # anywhere in that array crashes EVERY map load, not just a ported one.
  # Patched here (rather than chasing down the actual source of the gap)
  # because this is the one place already carrying this exact failure mode
  # in its head, and because it's a purely defensive change: a nil slot now
  # just behaves as an inert common event (never triggers, empty command
  # list) instead of crashing. Zero effect on any real common event.
  class ::Game_CommonEvent
    def name
      ce = $data_common_events[@common_event_id]
      ce ? ce.name : ""
    end

    def trigger
      ce = $data_common_events[@common_event_id]
      ce ? ce.trigger : nil
    end

    def switch_id
      ce = $data_common_events[@common_event_id]
      ce ? ce.switch_id : 0
    end

    def list
      ce = $data_common_events[@common_event_id]
      ce ? ce.list : []
    end
  end

  def self.build_map(real_id)
    remapped = PIF2PortSettings.remapped_id(real_id)
    return @built_maps[remapped] if @built_maps[remapped]
    ensure_common_events

    map = load_real_map(real_id)
    begin
      map.tileset_id = ensure_tileset(map.tileset_id)
    rescue => e
      puts "[PIF2Port] tileset remap failed for map #{real_id}: #{e.class}: #{e.message}"
    end

    (map.events || {}).each_value do |ev|
      ev.pages.each do |page|
        # Per-event rescue (not one big rescue around the whole map) is the
        # actual fix for "can't move to any PIF2 map but the first one": this
        # method used to have no rescue at all, so ONE malformed event on a
        # neighbor map (e.g. Route 101 out of Littleroot) raised out of
        # build_map entirely. That exception is invisible by the time it
        # surfaces - MapFactoryHelper#getMapDims (base engine, can't touch)
        # wraps its own load_data call in a bare `rescue => [0,0]`, so the
        # whole map silently got dims [0,0] and getMapConnections then
        # `next`s past EVERY connection touching it - not a partial failure,
        # the map becomes completely unreachable with zero error output.
        # Catching per-event here means one bad event just stays unremapped
        # (logged, harmless - it simply won't fire) while the rest of the
        # map, including its dimensions and its other events, still builds
        # normally and the real edge connection stays registered.
        begin
          cond = page.condition
          cond.switch1_id = PIF2PortSettings.remap_switch_id(cond.switch1_id) if cond.switch1_valid
          cond.switch2_id = PIF2PortSettings.remap_switch_id(cond.switch2_id) if cond.switch2_valid
          cond.variable_id += PIF2PortSettings::VARIABLE_OFFSET if cond.variable_valid
          remap_event_commands!(page.list)
          # Event graphics (NPC walking sprites) were never namespaced like
          # tileset/panorama/fog/battleback assets are - a real user playtest
          # showed NPCs invisible or mispositioned, because the ported event
          # still points at PIF2's raw filename, which either doesn't exist in
          # the host's Graphics/Characters (invisible) or DOES exist there as a
          # same-named-but-different sprite sheet (wrong frame slicing, so the
          # character renders shifted/off-screen). Same collision risk and
          # same fix as ensure_tileset's copy_asset calls.
          g = page.graphic
          g.character_name = copy_asset("Characters", g.character_name) if g.character_name && !g.character_name.empty?
        rescue => e
          puts "[PIF2Port] event remap failed on map #{real_id}, event #{ev.id rescue '?'}: #{e.class}: #{e.message}"
        end
      end
    end

    @built_maps[remapped] = map
  rescue => e
    puts "[PIF2Port] build_map(#{real_id}) FAILED: #{e.class}: #{e.message}"
    (e.backtrace || []).first(5).each { |l| puts "  #{l}" }
    # Last-resort fallback so this map still gets non-zero dimensions (see the
    # comment above) instead of silently vanishing from every connection that
    # touches it. The map itself will be blank if we ever actually hit this,
    # but at least it's reachable and the failure is now visible in the log.
    fallback = RPG::Map.new(20, 15)
    fallback.tileset_id = 1
    @built_maps[remapped] = fallback
  end

  # Real outdoor map-edge connections (walking off a route's border into its
  # real neighbor, no door needed) - PIF2's own Data/map_connections.dat, in
  # the same raw [mapA_id, edgeA, offsetA, mapB_id, edgeB, offsetB] format
  # the host's own connections file uses (edgeA/edgeB one of "N"/"S"/"E"/"W";
  # offsets are local to each map's own coordinate system, so only the two
  # map ids need remapping). Filtered to connections where BOTH sides are
  # real ported maps (drops any edge into an organizational-only MapInfos
  # node or an id past what all_real_map_ids kept).
  def self.real_map_connections
    return @real_map_connections if @real_map_connections
    raw = Marshal.load(File.binread("#{PIF2PortSettings::PIF2_DATA_DIR}/map_connections.dat"))
    ids = PIF2PortSettings.all_real_map_ids
    @real_map_connections = raw.select { |c| ids.include?(c[0]) && ids.include?(c[3]) }.map { |c|
      c2 = c.dup
      c2[0] = PIF2PortSettings.remapped_id(c[0])
      c2[3] = PIF2PortSettings.remapped_id(c[3])
      c2
    }
  rescue => e
    puts "[PIF2Port] map connections load failed: #{e.class}: #{e.message}"
    @real_map_connections = []
  end

  # Ports PIF2's own map_metadata.dat / encounters.dat entries for every
  # ported map id. GameData::MapMetadata keys its DATA hash by plain map id;
  # GameData::Encounter keys its by a "<map id>_<version>" symbol. Nothing
  # else in this mod ever populated either table for the remapped PIF2 ids,
  # which explains two separate live playtest reports at once:
  # "description posts [the location-name signpost popup, gated on
  # MapMetadata#announce_location] don't work in pif2", and "encounter
  # rates don't work for our added mod areas" (GameData::Encounter.get
  # looks up the EXACT map id the player is standing on - a remapped PIF2
  # id with no entry just returns nil, so wild encounters silently never
  # fire there).
  #
  # Hooked onto GameData.load_all (see the class << GameData block below),
  # not called at require time: GameData::MapMetadata.load/Encounter.load
  # both fully REPLACE their DATA hash via const_set the moment the host's
  # own compiled .dat loads, which happens after every mod script requires -
  # injecting any earlier would just get overwritten and silently vanish.
  #
  # CORRECTION (confirmed offline after a live playtest report of "no
  # encounters, no location signposts"): map_metadata.dat and encounters.dat
  # are BOTH actually XOR-encrypted, same as trainers.dat - the original
  # assumption below that they were plain was wrong, and this method used to
  # call Marshal.load directly instead of load_pif2_dat, so both silently hit
  # the rescue below and ported ZERO entries every time. Now routed through
  # load_pif2_dat like every other .dat read in this file. Only
  # map_connections.dat is actually plain.
  # Each file is wrapped in its own rescue: on any format mismatch that one
  # file simply fails to port (logged for the next round), and nothing is
  # written to either DATA hash until each individual entry is fully built,
  # so a failure here can't leave the host's own real metadata/encounters
  # partially overwritten or corrupted.
  # PIF2's own Encryption module (InfiniteFusion2/Data/Scripts/
  # 001_Technical/000_Encryption.rb) - a fixed 16-byte XOR applied to SOME of
  # its compiled Data/*.dat files, with its own loader falling back to plain
  # Marshal.load if decryption/parsing fails. Reused verbatim here,
  # generalized as load_pif2_dat below so ANY future PIF2 .dat file
  # (encrypted or not) can be pulled in the same way - try plain first, fall
  # back to XOR.
  PIF2_XOR_KEY = [0x4A, 0x8F, 0x2C, 0xE1, 0x73, 0xB5, 0x96, 0x0D,
                  0x5E, 0xA2, 0x3F, 0xC7, 0x81, 0x14, 0x6B, 0xD9].freeze

  def self.xor_pif2(bytes)
    bytes.bytes.each_with_index.map { |b, i| b ^ PIF2_XOR_KEY[i % PIF2_XOR_KEY.length] }.pack("C*")
  end

  def self.load_pif2_dat(filename)
    raw = File.binread("#{PIF2PortSettings::PIF2_DATA_DIR}/#{filename}")
    begin
      return Marshal.load(raw)
    rescue
      return Marshal.load(xor_pif2(raw))
    end
  end

  # Real PIF2 trainer-type symbol => renamed symbol. Left empty in practice:
  # PIF2 and this host both descend from the same base-Essentials trainer-
  # type roster (:YOUNGSTER, :LASS, :ACE_TRAINER...), so a symbol the host
  # already defines is assumed to BE that same trainer type, not a different
  # one squatting the name - safe to just skip re-adding it (see
  # port_trainer_types). Kept as a real remap table (not just a stub) so a
  # future source game whose roster doesn't line up 1:1 (e.g. "DBZ Inf") can
  # populate real renames here without changing anything downstream -
  # rewrite_trainer_battle_script already consults it.
  def self.trainer_type_id_map
    @trainer_type_id_map ||= {}
  end

  def self.remap_trainer_type_id(id)
    trainer_type_id_map[id] || id
  end

  # Copies one real graphics file straight into the HOST's real Graphics/
  # tree (NOT Mods/PIF2Port/Graphics/ like copy_asset/copy_autotile above).
  # Trainer-type sprites are the odd one out among every asset this mod
  # copies: every other asset (tileset/panorama/character/etc.) is
  # referenced through a filename WE control, stored on the RPG::Map/
  # RPG::Event data we already rewrite - so redirecting it into a
  # namespaced Mods/ subfolder is free. Trainer-type sprite lookups are
  # NOT data-driven: GameData::TrainerType.front_sprite_filename/
  # charset_filename/etc. (010_Data/002_PBS data/012_TrainerType.rb#
  # check_file) always recompute a path fresh from the trainer type's own
  # symbol (falling back to its %03d id_number), hardcoded to real
  # "Graphics/Trainers/"/"Graphics/Characters/" - there is no ivar we can
  # point elsewhere. So the file has to physically exist at that exact
  # real path or it will never resolve, for any trainer type, ported or not.
  # Never overwrites an existing destination file (checked directly against
  # real PIF2 data before this was written: 0 of the 84 new trainer types'
  # sprite filenames collide with anything the host already ships).
  def self.copy_direct(dest_path, src_path)
    return :missing unless File.exist?(src_path)
    return :exists if File.exist?(dest_path)
    ensure_dir(File.dirname(dest_path))
    File.binwrite(dest_path, File.binread(src_path))
    :copied
  rescue => e
    puts "[PIF2Port] direct asset copy failed (#{src_path} -> #{dest_path}): #{e.message}"
    :failed
  end

  # Only the front battle sprite is real for these 84 new trainer types -
  # checked directly against PIF2's Graphics/ tree before writing this:
  # PIF2 ships essentially no back sprites (only player-controllable
  # trainer types get one) and no Characters/trainer_<SYMBOL>.png overworld
  # charsets for them either (those NPCs' walking sprites come from
  # whatever character_name the map EVENT itself references, already
  # ported by build_map's own copy_asset("Characters", ...) call - nothing
  # extra needed here for that). mapPlayer icons likewise only exist for
  # player types (Red/Leaf), never for an opponent trainer type. So this
  # only copies Graphics/Trainers/<SYMBOL>.png; back/map-icon variants are
  # still attempted (harmless no-ops via :missing) in case a future source
  # game's roster actually has them.
  def self.port_trainer_type_graphics(symbol)
    base = symbol.to_s
    pif2_dir = PIF2PortSettings::PIF2_GRAPHICS_DIR
    [
      ["Graphics/Trainers/#{base}.png",      "#{pif2_dir}/Trainers/#{base}.png"],
      ["Graphics/Trainers/#{base}_back.png", "#{pif2_dir}/Trainers/#{base}_back.png"],
    ].count { |dest, src| copy_direct(dest, src) == :copied }
  end

  def self.port_trainer_types
    added = 0
    sprites_copied = 0
    missing_sprite = []
    next_id_number = PIF2PortSettings::TRAINER_TYPE_ID_NUMBER_BASE
    raw = load_pif2_dat("trainer_types.dat")
    raw.each_pair do |key, entry|
      # register (010_Data/001_GameData.rb) double-keys every entry as both
      # DATA[symbol_id] and DATA[id_number] pointing at the SAME object, so a
      # raw Marshal-loaded Hash yields each real trainer type TWICE under
      # each_pair - once per key. Only process the symbol-keyed occurrence;
      # the id_number alias is (re-)established manually below instead.
      next unless key.is_a?(Symbol)
      next if GameData::TrainerType::DATA[key] # same symbol assumed = same trainer type, see trainer_type_id_map comment
      id_num = entry.instance_variable_get(:@id_number)
      if GameData::TrainerType::DATA[id_num] # numeric alias collides with a host trainer type - give it a fresh one
        id_num = next_id_number
        next_id_number += 1
        entry.instance_variable_set(:@id_number, id_num)
      end
      GameData::TrainerType::DATA[key] = entry
      GameData::TrainerType::DATA[id_num] = entry
      added += 1
      copied = port_trainer_type_graphics(key)
      sprites_copied += copied
      missing_sprite << key if copied == 0
    end
    puts "[PIF2Port] Ported #{added} PIF2 trainer type(s), copied #{sprites_copied} sprite file(s)."
    if !missing_sprite.empty?
      # Known asset gap, not a bug: checked directly against real PIF2
      # Graphics/Trainers/ before this was written - these symbols simply
      # have no front-sprite PNG there either (12/84 in the current real
      # data, e.g. the Gen-9-style ADVENTURER_* variants and both
      # TEAM_MAGMAQUA_GRUNT_* types). Those trainer types will battle with
      # whatever GameData::TrainerType.front_sprite_filename's own %03d-
      # id_number fallback resolves to (almost certainly nothing real
      # either) until real art is sourced - same asset-gap class as the
      # true-Mega-sprite and Naruto-line sprite gaps noted elsewhere.
      puts "[PIF2Port]   no front sprite available for: #{missing_sprite.join(', ')}"
    end
  rescue => e
    puts "[PIF2Port] trainer_types port failed: #{e.class}: #{e.message}"
  end

  # Real PIF2 [trainer_type, name, version] key => the NEW version number it
  # was ported under. Only populated for keys that COLLIDED with a trainer
  # the host already had under that exact identity (both games starting from
  # the same Hoenn roster makes an early-game collision, e.g. YOUNGSTER
  # "Allen" at the default version 0, a near-certainty) - every other real
  # PIF2 trainer keeps its own version untouched. Consulted by
  # rewrite_trainer_battle_script so a ported map's own
  # pbTrainerBattle(:TYPE,"Name") event call still resolves to the right
  # (renumbered) trainer instead of silently battling whichever trainer the
  # host itself already had under that name.
  def self.trainer_version_overrides
    @trainer_version_overrides ||= {}
  end

  # Every trainer "tier" this fork has (013_Trainer.rb's base GameData::Trainer
  # for vanilla, plus 013_TrainerModern.rb / 013_TrainerExpert.rb's
  # GameData::TrainerModern / GameData::TrainerExpert for Remix/Expert mode)
  # is a real, separately-registered DATA hash - those two subclasses never
  # define their own `DATA = {}`, GameData::ClassMethods#load's `const_set`
  # is what actually gives each one its own registry, the FIRST time each
  # class's own .load runs (which happens before this mod's GameData.load_all
  # hook fires, same as every other GameData class). Same [trainertype,
  # name,version]+id_number double-keying as the base tier, so each gets
  # its own id_number range too so the three tiers can never collide with
  # each other even though they're otherwise fully independent.
  TRAINER_TIERS = [
    [GameData::Trainer,       "trainers.dat",        PIF2PortSettings::TRAINER_ID_NUMBER_BASE],
    [GameData::TrainerModern, "trainers_remix.dat",  PIF2PortSettings::TRAINER_ID_NUMBER_BASE + 2000],
    [GameData::TrainerExpert, "trainers_expert.dat", PIF2PortSettings::TRAINER_ID_NUMBER_BASE + 4000],
  ].freeze

  def self.port_trainers
    TRAINER_TIERS.each do |trainer_class, filename, id_number_base|
      port_trainer_tier(trainer_class, filename, id_number_base)
    end
  end

  # TEMPORARY diagnostic for the "Unknown trainer YOUNGSTER Charlie 0" crash
  # report (event 2, map 50010 / Route 102) plus the paired "route 101/102
  # have no encounters" report - appends one line per boot so the actual
  # runtime state of GameData::Trainer::DATA/GameData::Encounter::DATA can be
  # inspected without a live boot test on this end. Delete this method and
  # its call site in the GameData.load_all hook below once resolved.
  def self.write_boot_debug_trace
    path = "E:/pokemon infinite fusion and mods/Pokemon Anime fusions/InfiniteFusion/pif2port_debug_trace.log"
    charlie_keys = GameData::Trainer::DATA.keys.select { |k| k.is_a?(Array) && k[0] == :YOUNGSTER && k[1] == "Charlie" }
    route101 = defined?(GameData::Encounter) ? GameData::Encounter::DATA.key?(:"5_0") : nil
    route102 = defined?(GameData::Encounter) ? GameData::Encounter::DATA.key?(:"10_0") : nil
    File.open(path, "a") do |f|
      f.puts "[#{Time.now}] trainer_data_size=#{GameData::Trainer::DATA.size} charlie_keys=#{charlie_keys.inspect} route101_encounter_present=#{route101.inspect} route102_encounter_present=#{route102.inspect}"
    end
  rescue => e
    begin
      File.open("E:/pokemon infinite fusion and mods/Pokemon Anime fusions/InfiniteFusion/pif2port_debug_trace.log", "a") { |f| f.puts "[#{Time.now}] TRACE FAILED: #{e.class}: #{e.message}" }
    rescue
    end
  end

  def self.port_trainer_tier(trainer_class, filename, id_number_base)
    added = 0
    renamed = 0
    next_version = PIF2PortSettings::TRAINER_VERSION_BASE
    next_id_number = id_number_base
    raw = load_pif2_dat(filename)
    raw.each_pair do |key, entry|
      # Same double-keying as port_trainer_types (DATA[[type,name,version]]
      # AND DATA[id_number] both point at the same object) - only process the
      # tuple-keyed occurrence per real trainer.
      next unless key.is_a?(Array)
      orig_type, name, orig_version = key
      new_type = remap_trainer_type_id(orig_type)
      new_version = orig_version
      if trainer_class::DATA[[new_type, name, orig_version]] # never clobber a real host trainer
        new_version = next_version
        next_version += 1
        # Only the base vanilla tier's collisions matter to ported map events -
        # a Trainer(N) event's pbTrainerBattle(:TYPE,"Name") call always
        # resolves against GameData::Trainer, never TrainerModern/Expert
        # (those are consulted separately, by trainer_type+name+version, when
        # Remix/Expert mode is active - see 015_Trainers and player/
        # 002_Trainer_LoadAndNew.rb), so only that tier needs its renames fed
        # to rewrite_trainer_battle_script.
        trainer_version_overrides[[orig_type, name, orig_version]] = new_version if trainer_class == GameData::Trainer
        renamed += 1
      end
      # id_number always gets a fresh one - see TRAINER_ID_NUMBER_BASE comment
      # (both games number their trainers 0.. sequentially, so the numeric
      # alias colliding with a real host trainer is close to guaranteed).
      new_id_number = next_id_number
      next_id_number += 1
      new_key = [new_type, name, new_version]
      entry.instance_variable_set(:@trainer_type, new_type)
      entry.instance_variable_set(:@version, new_version)
      entry.instance_variable_set(:@id_number, new_id_number)
      entry.instance_variable_set(:@id, new_key)
      trainer_class::DATA[new_key] = entry
      trainer_class::DATA[new_id_number] = entry
      added += 1
    end
    puts "[PIF2Port] Ported #{added} PIF2 #{trainer_class} trainer(s) from #{filename} (#{renamed} renumbered to avoid colliding with an existing host trainer)."
  rescue => e
    puts "[PIF2Port] #{filename} port failed: #{e.class}: #{e.message}"
  end

  # Quote-aware top-level comma split, e.g. splitting the raw argument text
  # inside "pbTrainerBattle(...)" - good enough for the argument shapes real
  # trainer-battle calls actually use (symbols, quoted strings, literals);
  # does not handle nested parens/brackets in an argument, which none of the
  # real calls scanned so far ever contain.
  def self.split_top_level_args(str)
    args = []
    buf = "".dup
    in_str = false
    str.each_char do |c|
      if c == '"'
        in_str = !in_str
        buf << c
      elsif c == ',' && !in_str
        args << buf
        buf = "".dup
      else
        buf << c
      end
    end
    args << buf
    args
  end

  # Rewrites "pbTrainerBattle(:TYPE,\"Name\"[,...,trainerPartyID])" script
  # text so it asks for the renumbered version whenever port_trainers had to
  # renumber that exact trainer (see trainer_version_overrides). trainerID
  # and trainerName are pbTrainerBattle's 1st/2nd positional args; the
  # version - "trainerPartyID" in pbTrainerBattle's own signature, passed
  # straight through to GameData::Trainer.get(trainerID,trainerName,
  # trainerPartyID) (see Data/Scripts/012_Overworld/002_Battle triggering/
  # 001_Overworld_BattleStarting.rb) - is the 5th, defaulting to 0 when
  # omitted, which every real call scanned so far does. Missing positional
  # args between name and version are padded with pbTrainerBattle's own real
  # defaults (endSpeech=nil, doubleBattle=false) so inserting the version
  # doesn't shift any argument that WAS explicitly passed into the wrong slot.
  def self.rewrite_trainer_battle_script(text)
    return text unless text.is_a?(String) && text.include?("pbTrainerBattle")
    text.gsub(/pbTrainerBattle\(([^)]*)\)/) do |whole|
      args = split_top_level_args($1)
      next whole if args.size < 2
      type_match = args[0].strip.match(/\A:(\w+)\z/)
      name_match = args[1].strip.match(/\A"(.*)"\z/m)
      next whole unless type_match && name_match
      orig_type = type_match[1].to_sym
      name = name_match[1]
      orig_version = args[4] ? args[4].strip.to_i : 0
      new_version = trainer_version_overrides[[orig_type, name, orig_version]]
      next whole unless new_version
      args[2] = "nil" if args[2].nil?
      args[3] = "false" if args[3].nil?
      args[4] = new_version.to_s
      "pbTrainerBattle(#{args.join(',')})"
    end
  end

  def self.port_map_metadata_and_encounters
    ids = PIF2PortSettings.all_real_map_ids

    begin
      # NOT plain Marshal, despite this method's header comment above assuming
      # so - confirmed offline (plain Marshal.load raises "incompatible marshal
      # file format" on the real file) that PIF2 XOR-encrypts this one same as
      # trainers.dat. Real root cause of "encounter rates don't work"/"location
      # signposts don't work in the ported zone": every call here silently hit
      # the rescue below and ported ZERO entries. Fixed by routing through
      # load_pif2_dat (plain-then-XOR fallback) like every other .dat read in
      # this file already does.
      raw = load_pif2_dat("map_metadata.dat")
      added = 0
      raw.each_pair do |real_id, meta|
        next unless ids.include?(real_id)
        remapped = PIF2PortSettings.remapped_id(real_id)
        next if GameData::MapMetadata::DATA[remapped] # never clobber a real entry
        entry = meta.dup
        entry.instance_variable_set(:@id, remapped)
        GameData::MapMetadata::DATA[remapped] = entry
        added += 1
      end
      puts "[PIF2Port] Ported #{added} PIF2 map metadata entr#{added == 1 ? 'y' : 'ies'}."
    rescue => e
      puts "[PIF2Port] map_metadata port failed: #{e.class}: #{e.message}"
    end

    begin
      # Same fix as map_metadata.dat above - confirmed offline this file is
      # also XOR-encrypted, not plain, so this was silently porting 0 wild
      # encounter tables every single time (the actual cause of "no
      # encounters in Route 101").
      raw = load_pif2_dat("encounters.dat")
      added = 0
      raw.each_pair do |_key, enc|
        next unless ids.include?(enc.map)
        remapped = PIF2PortSettings.remapped_id(enc.map)
        new_key = sprintf("%s_%d", remapped, enc.version).to_sym
        next if GameData::Encounter::DATA[new_key]
        entry = enc.dup
        entry.map = remapped
        entry.id  = new_key
        GameData::Encounter::DATA[new_key] = entry
        added += 1
      end
      puts "[PIF2Port] Ported #{added} PIF2 encounter table(s)."
    rescue => e
      puts "[PIF2Port] encounters port failed: #{e.class}: #{e.message}"
    end

    # AnimeFusionQoL's "5%% minimum wild encounter chance" (enforce_min_
    # encounter_chance) only ever runs ONCE, synchronously, at mod-load time
    # (AnimeFusionQoL.install, called the moment its file is required) - which
    # is BEFORE the ported PIF2 entries above even exist (they're added here,
    # on a LATER GameData.load_all call fired after mods finish loading; see
    # AnimeFusionMerge/Bootstrap.rb's identical "load_all runs twice / replaces
    # DATA wholesale" writeup for the same class of bug). So the 5%% floor
    # normalized the base host's maps just fine but never touched any PIF2
    # map - the "wild pokemon odds mod not working for pif2" report. Re-run it
    # here, now that our entries exist, same idempotent-rerun pattern
    # AnimeFusionMerge already uses for its own added encounters.
    if defined?(AnimeFusionQoL) && AnimeFusionQoL.respond_to?(:enforce_min_encounter_chance)
      AnimeFusionQoL.enforce_min_encounter_chance
    end
  end

  # Battle Frontier / Battle Tower facility roster (Data/trainer_lists.dat) -
  # NOT a GameData table and NOT id-keyed like everything above: per
  # 021_Compiler/002_Compiler_CompilePBS.rb#compile_trainer_lists, it's a
  # plain Array of [bt_trainers, bt_pokemon, challenge_names, trainers_file,
  # pokemon_file, is_default] sections (one per PBS [TrainerList]/
  # [DefaultTrainerList] block), read fresh via plain `load_data` every time
  # a Battle Frontier facility is generated - never cached at boot the way
  # GameData tables are, so GameData.load_all is the wrong hook here.
  # Checked directly against the real files before writing this: PIF2 ships
  # the exact same 5 stock sections (DefaultTrainerList + the 4 cup
  # challenges) as this host, and 294 of the 300 stock Battle Tower trainer
  # records are byte-identical - the only differences are 6 female Breeder
  # entries PIF2 left tagged :POKEMONBREEDER_M (a well-known stock-Essentials
  # PBS quirk this host already fixed to a unified :POKEMONBREEDER), not
  # real added content. So today this hook has nothing new to merge - it's
  # here for completeness ("port everything") and so a FUTURE source game
  # with a genuinely different facility roster picks up correctly with zero
  # extra work.
  def self.merge_trainer_lists(host_lists)
    return host_lists unless host_lists.is_a?(Array)
    raw = load_pif2_dat("trainer_lists.dat")
    return host_lists unless raw.is_a?(Array)
    # Identify a facility section by its Challenge-name set (index 2), not
    # by trfile/pkfile (just PBS filenames, no stable identity) or by
    # position - the stock DefaultTrainerList's Challenges is [] in both
    # games too, so it still correctly matches and never gets duplicated.
    existing = host_lists.map { |s| s[2] || [] }
    added = 0
    raw.each do |section|
      next unless section.is_a?(Array) && section.length >= 6
      challenges = section[2] || []
      next if existing.include?(challenges) # never duplicate/clobber a facility the host already lists
      host_lists << section
      added += 1
    end
    puts "[PIF2Port] Merged #{added} PIF2 trainer-list facility section(s)." if added > 0
    host_lists
  rescue => e
    puts "[PIF2Port] trainer_lists merge failed: #{e.class}: #{e.message}"
    host_lists
  end

  # Heuristic spawn point: nearest-to-center tile that isn't fully blocked on
  # any of its 3 tile layers, per the real tileset's own passages table.
  # Approximate (ignores event-based passability and terrain tags) but good
  # enough for a pilot -- adjust after an interactive playtest if it's off.
  def self.find_spawn(real_id)
    map = load_real_map(real_id)
    ts = pif2_tilesets[map.tileset_id]
    passages = ts ? ts.passages : nil
    w, h = map.width, map.height
    cx, cy = w / 2.0, h / 2.0
    candidates = []
    (0...h).each { |y| (0...w).each { |x| candidates << [x, y] } }
    candidates.sort_by! { |x, y| (x - cx)**2 + (y - cy)**2 }
    candidates.each do |x, y|
      blocked = false
      (0..2).each do |layer|
        tile_id = map.data[x, y, layer]
        next if !tile_id || tile_id == 0
        p = passages ? (passages[tile_id] || 0) : 0
        blocked = true if (p & 0x0f) == 0x0f
      end
      return [x, y, 2] unless blocked
    end
    [w / 2, h / 2, 2]
  end

  # PIF2's early game is a chain of small cutscene events, each setting a
  # switch that unlocks a bit more of the map/NPCs (bag/starter-choice on
  # Route 101 needs switch 2010, set only by the HOENN_RIVAL NPC in the
  # player's house; that NPC needs 2002/2003, set only by the truck-arrival
  # intro; Oldale's Mart/Pokemon-Center door needs 2019, set only by its own
  # "controller_RivalPokemart" cutscene once the queue's been walked
  # through). Warping straight into ported Littleroot skips ALL of it.
  #
  # Rather than hand-setting each switch as it's discovered (confirmed
  # unsustainable -- every new area is another gate), the FIRST time the
  # player ever enters PIF2 via the Hub we instead drop them on the real
  # Truck map (raw id 14) so PIF2's own actual intro event plays for real:
  # `Map014.rxdata` ev1 is an unconditional parallel-process page that runs
  # the whole move-in sequence and sets switch 2001 itself via a real
  # in-event Control Switches command (confirmed by reading it directly --
  # trigger=4, no condition on page0; page1, which takes over once 2001 is
  # already on, is just the inert idle state). From there every other event
  # in the chain (meeting the rival, the starter bag, Oldale's queue/door)
  # fires from genuine player interaction exactly like a real PIF2 save,
  # confirmed by tracing each gate to a real Control Switches command inside
  # an actual map event, not a script snippet -- see bootstrap_pif2_intro!.
  #
  # One exception: switches 2002 (male)/2003 (female) are NEVER set by any
  # map event or common event anywhere in PIF2's data (confirmed by
  # scanning every Control Switches command AND every script command's text
  # for "2002"/"2003" across the whole install -- zero hits). Real PIF2 must
  # set these during its own out-of-map new-game/character-select flow,
  # which the Hub's own new-game system replaces entirely, so there is no
  # "real scene" to trigger for this one specifically. Seeded once, up
  # front, from the host's own $Trainer gender.
  def self.first_pif2_entry?
    !$PokemonGlobal.instance_variable_get(:@pif2_intro_seeded)
  end

  def self.warp_into(map_id, x, y, dir)
    MultiverseHub.ensure_map_infos
    unless MultiverseHubSettings.gauntlet_map_ids.include?($game_map.map_id)
      $PokemonGlobal.mvhub_return_point = [$game_map.map_id, $game_player.x, $game_player.y, $game_player.direction]
    end
    pbFadeOutIn do
      $game_temp.player_transferring   = true
      $game_temp.transition_processing = true
      $game_temp.player_new_map_id     = map_id
      $game_temp.player_new_x          = x
      $game_temp.player_new_y          = y
      $game_temp.player_new_direction  = dir
      $scene.transfer_player if $scene.respond_to?(:transfer_player)
    end
  end

  def self.bootstrap_pif2_intro!
    $PokemonGlobal.instance_variable_set(:@pif2_intro_seeded, true)
    base = PIF2PortSettings::SWITCH_OFFSET
    male = true
    begin
      male = $Trainer.male? if defined?($Trainer) && $Trainer && $Trainer.respond_to?(:male?)
    rescue StandardError
    end
    $game_switches[base + (male ? 2002 : 2003)] = true
    # Real PIF2's own new-game flow (Map067 "On the road!" ev6, the truck-
    # ride cutscene that leads into the Truck map) transfers the player
    # gender-conditionally to raw (20,5) [male] or (6,5) [female] on the
    # Truck map (raw id 14), facing down -- confirmed by decoding that
    # event's actual Transfer Player commands. Those exact tiles matter:
    # the Truck's cargo hold is packed with non-passable "moving box"
    # furniture events that `find_spawn`'s generic nearest-to-center
    # heuristic can't see (it only reads terrain passability, not event
    # collision), so it was landing the player in a pocket boxed in on
    # every side with no path to either exit door -- the literal "stuck in
    # the truck" bug. Each of these two real spawn tiles sits immediately
    # next to that gender's own real exit door (raw (17,5)/(17,6) for
    # male, (9,5)/(9,6) for female), matching real PIF2's own layout.
    x, y = male ? [20, 5] : [6, 5]
    dir = 2
    warp_into(PIF2PortSettings.remapped_id(14), x, y, dir)
    # Watchdog: the Truck's own real parallel-process event (ev1) is what's
    # actually supposed to flip switch 2001 (-> 52001) a few seconds after
    # entry, which is what unlocks all 4 of its exit doors (each door event's
    # only page is gated on that same switch, so if it's never true the door
    # is a no-op forever -- confirmed via offline simulation that the
    # remapping itself is clean, so if this doesn't fire in practice the
    # cause is something in real-time event execution this offline tooling
    # can't observe without a boot test). Rather than force-setting the
    # switch immediately (which would skip the real cutscene entirely --
    # exactly what an earlier fix in this project was about avoiding), arm a
    # generous countdown that only forces it on as a last resort if the real
    # event hasn't already done so, so the player is never permanently stuck
    # even if the real event silently fails to run/complete in this ported
    # context.
    @truck_unlock_countdown = 300 # ~5s at 60fps; real cutscene needs ~2.7s
  end

  def self.check_truck_unlock_watchdog
    return unless @truck_unlock_countdown
    return unless $game_map && $game_map.map_id == PIF2PortSettings.remapped_id(14)
    sw = PIF2PortSettings::SWITCH_OFFSET + 2001
    if $game_switches[sw]
      @truck_unlock_countdown = nil # real event already did its job
      return
    end
    @truck_unlock_countdown -= 1
    return unless @truck_unlock_countdown <= 0
    $game_switches[sw] = true
    $game_map.need_refresh = true
    @truck_unlock_countdown = nil
    puts "[PIF2Port] Truck intro watchdog: forced switch #{sw} ON after timeout " \
         "(the real intro event didn't set it in time)."
  end
end

class ::Scene_Map
  alias_method :pif2port_orig_update, :update
  def update
    pif2port_orig_update
    PIF2Port.check_truck_unlock_watchdog
  end
end

#-- Fix: PIF2's own ported event data (e.g. the Littleroot dresser event, --
# Map013 ev9/ev29) hardcodes `isWearingHat(HAT_BRENDAN)` / `isWearingHat
# (HAT_MAY)` checks -- baked in from PIF2's original build, which always ran
# with Settings::GAME_ID == :IF_HOENN. This host's GAME_ID is NOT :IF_HOENN,
# so the base engine's getDefaultHat (052_InfiniteFusion/.../OutfitUtils.rb)
# falls through to DEFAULT_OUTFIT_MALE/FEMALE ("red"/"leaf") instead of
# HAT_BRENDAN/HAT_MAY. The dresser event puts on "red"/"leaf" via
# `obtainHat(getDefaultHat)`, then checks `isWearingHat(HAT_BRENDAN)` to
# decide whether to clear the switch that gates its own "give hat" page --
# that check is always false (player is wearing "red", not "brendanRSE"),
# so the switch is never cleared and the *entire* obtain-hat sequence
# (including a surprise "change outfit" menu from Common Event #80) replays
# every single time the player interacts with the dresser again, forever.
# Scope the fix to PIF2Port maps only (map_id >= MAP_OFFSET) so the host's
# own non-Hoenn areas keep their normal default hat.
class Object
  alias_method :pif2port_orig_getDefaultHat, :getDefaultHat

  def getDefaultHat(gender=getPlayerGenderId())
    if $game_map && $game_map.map_id >= PIF2PortSettings::MAP_OFFSET
      hat = gender == GENDER_MALE ? HAT_BRENDAN : HAT_MAY
      # The dresser event (ev9/ev29) only calls obtainHat(getDefaultHat) --
      # the matching clothes item is granted by a SEPARATE event (ev48/ev49)
      # elsewhere on the map, which the player can easily miss or which may
      # not fire reliably once remapped. Silently unlock the matching
      # clothes here too (no dialogue -- unlockClothes, not obtainClothes)
      # so the outfit is always available once the hat is, without forcing
      # it on or bypassing the real events for players who DO reach ev48/49.
      clothes = gender == GENDER_MALE ? CLOTHES_BRENDAN : CLOTHES_MAY
      unlockClothes(clothes) if $Trainer
      return hat
    end
    pif2port_orig_getDefaultHat(gender)
  end
end

#-- Same bug, same fix, for getDefaultClothes/getDefaultHair: -----------
# CharacterSelectMenuPresenter#main_rival (Data/Scripts/050_Outfits/UI/
# CharacterSelectMenuPresenter.rb) drives the "what does your rival look
# like?" creation flow triggered by PIF2's Map013 birthday-cutscene event
# (rival_appearance_controller). It calls getDefaultClothes/getDefaultHair
# with the OPPOSITE gender to seed the rival's starting look before the
# player customizes hair/skin - same Settings::GAME_ID == :IF_HOENN gate
# as getDefaultHat above, same false-on-this-host result: it falls through
# to DEFAULT_OUTFIT_MALE/FEMALE ("red"/"leaf") instead of CLOTHES_BRENDAN/
# MAY and HAIR_BRENDAN/MAY. "leaf"/"red" aren't valid hair style ids at
# all, so the hair layer fails to resolve and the rival renders bald; the
# mismatched clothes id compounds it - this is the "rival is naked and
# hairless" report. $Trainer.init_rival_appearance(...) then bakes these
# same bad ids into $Trainer.rival_appearance, which is what the rival's
# in-battle custom_appearance sprite is generated from too (Hoenn_Rival.rb
# initializeRivalBattledTrainer) - so this one fix should also address the
# battle sprite falling back to looking wrong. Scoped to PIF2Port maps
# only, identical to the getDefaultHat override.
class Object
  alias_method :pif2port_orig_getDefaultClothes, :getDefaultClothes

  def getDefaultClothes(gender)
    if $game_map && $game_map.map_id >= PIF2PortSettings::MAP_OFFSET
      return gender == GENDER_MALE ? CLOTHES_BRENDAN : CLOTHES_MAY
    end
    pif2port_orig_getDefaultClothes(gender)
  end

  alias_method :pif2port_orig_getDefaultHair, :getDefaultHair

  def getDefaultHair(gender)
    if $game_map && $game_map.map_id >= PIF2PortSettings::MAP_OFFSET
      return gender == GENDER_MALE ? HAIR_BRENDAN : HAIR_MAY
    end
    pif2port_orig_getDefaultHair(gender)
  end
end

#-- Fix: PIF2's ported Oldale (and every other town's) Pokemon Center door --
# event calls enter_pokemon_center(city), which calls the base engine's
# enter_common_building(:POKEMON_CENTER, city) (052_InfiniteFusion/Graphics/
# Overworld/CommonMaps.rb). That function picks COMMON_MAPS_HOENN or
# COMMON_MAPS_KANTO based on Settings::HOENN (== Settings::GAME_ID ==
# :IF_HOENN) - the same GAME_ID gate already worked around above for
# getDefaultHat/Clothes/Hair. This host's GAME_ID is :IF_KANTO, so it picks
# COMMON_MAPS_KANTO, which only defines :POKEMART - no :POKEMON_CENTER,
# :POKEMON_CENTER_BIRTHDAY, :CLOTHING_STORE or :CONTEST_HALL key at all.
# new_map_data comes back nil and enter_common_building silently `return`s -
# no transfer, no error, nothing - which is exactly the reported "the
# Pokemon Center door won't open" symptom (walking onto the door tile does
# nothing at all).
#
# Simply forcing Settings::HOENN to true would be worse: COMMON_MAPS_HOENN's
# map ids (24/25/27/94/110) are PIF2's OWN source map numbering, and this
# host already has unrelated real Kanto maps at those exact ids (confirmed:
# 24 = Vermillion City Gym, 25 = Pokemon Fan Club, 27 = S.S. Anne, 94 =
# Soaring, 110 = Saffron Hotel) - using them raw would teleport the player
# into the wrong building entirely. The maps COMMON_MAPS_HOENN actually
# means (PIF2's own real map024/025/027/094/110.rxdata, named "PokeMart"/
# "Pokemon Center"/"Happy Birthday!"/"Clothing Boutique"/"Contest Hall" in
# PIF2's own MapInfos) are already ported like every other PIF2 map (see
# this file's header comment) and reachable at their PIF2Port-remapped ids
# (+MAP_OFFSET). Scoped to ported maps only, identical to the getDefaultHat
# override, so the host's own real Kanto Pokemon Centers/Marts (which DO
# resolve correctly via COMMON_MAPS_KANTO) are untouched.
class Object
  alias_method :pif2port_orig_enter_common_building, :enter_common_building

  def enter_common_building(building_id, city)
    if $game_map && $game_map.map_id >= PIF2PortSettings::MAP_OFFSET
      new_map_data = COMMON_MAPS_HOENN[building_id]
      if new_map_data
        $PokemonGlobal.common_map_entrance_id = $game_map.map_id
        $PokemonGlobal.common_map_entrance_position = [$game_player.x, $game_player.y]
        pbSet(VAR_CURRENT_CITY, city)
        new_map = PIF2PortSettings.remapped_id(new_map_data[:id])
        new_position = new_map_data[:position]
        pbFadeOutIn {
          $game_temp.player_new_map_id = new_map
          $game_temp.player_new_x = new_position[0]
          $game_temp.player_new_y = new_position[1]
          $game_temp.player_new_direction = $game_player.direction
          $scene.transfer_player(true)
          $game_map.autoplay
          $game_map.refresh
        }
        return
      end
    end
    pif2port_orig_enter_common_building(building_id, city)
  end
end

#-- Hook the engine's own load_data so Data/trainer_lists.dat gets PIF2's ---
# facility sections spliced in on every real read (see merge_trainer_lists
# above for why GameData.load_all is the wrong hook for this one file).
# load_data/save_data are RGSS/mkxp-z native globals, which Ruby turns into
# PRIVATE instance methods of Object - aliasing works the same as any other
# method, but the guard below checks both public and private forms since
# every other alias guard in this file only ever checked the public form.
# Every call site in this codebase passes exactly one argument
# (load_data("Data/whatever.rxdata")), so *rest is just defensive, not
# because a real second argument has ever been seen.
class Object
  if !method_defined?(:__pif2port_orig_load_data) && !private_method_defined?(:__pif2port_orig_load_data)
    alias_method :__pif2port_orig_load_data, :load_data
  end

  def load_data(filename, *rest)
    result = __pif2port_orig_load_data(filename, *rest)
    result = PIF2Port.merge_trainer_lists(result) if filename == "Data/trainer_lists.dat" && defined?(PIF2Port)
    result
  end
  private :load_data
end

#-- Port map_metadata/encounters right after the host loads its own -------
# GameData.load_all runs every GameData class's .load in sequence, each of
# which const_sets its own DATA hash fresh from the host's compiled .dat -
# hooking the very end of that bulk loader is the first point where both
# DATA hashes exist AND are guaranteed not to be replaced out from under us
# again afterward.
module GameData
  class << self
    alias __pif2port_orig_load_all load_all unless method_defined?(:__pif2port_orig_load_all)
    def load_all
      __pif2port_orig_load_all
      if defined?(PIF2Port)
        # Trainers/trainer types MUST port before map_metadata/encounters (in
        # practice order doesn't matter between those two, but it matters a
        # lot relative to any map ever being built - see build_map/
        # remap_event_commands!): every real map is built LAZILY, only when
        # the player actually steps onto it, which can only happen after
        # GameData.load_all has fully returned - so trainer_version_overrides
        # is always populated before rewrite_trainer_battle_script needs it.
        begin
          PIF2Port.port_trainer_types
          PIF2Port.port_trainers
          PIF2Port.port_map_metadata_and_encounters
        ensure
          PIF2Port.write_boot_debug_trace
        end
      end
    end
  end
end

# Register each ported map into MultiverseHub's existing infrastructure --
# no new engine hooks needed here, MultiverseHub's own load_data/
# pbLoadMapInfos/isolation hooks already generalize over these tables.
if defined?(MultiverseHub) && defined?(MultiverseHubSettings)
  start_id = PIF2PortSettings::START_MAP_ID
  PIF2PortSettings.ported_maps.each do |real_id, info|
    remapped = PIF2PortSettings.remapped_id(real_id)
    method_name = :"build_pif2_map_#{real_id}"
    MultiverseHub.define_singleton_method(method_name) { PIF2Port.build_map(real_id) }
    MultiverseHub::GAUNTLET_MAP_BUILDERS[remapped] = method_name

    # Only the designated start map gets its own PC menu line - the other
    # ~115 maps are reachable from it via PIF2's own real door/transfer
    # events (now that every real map id has a builder registered above),
    # not by picking them individually out of "Change Game". They still need
    # to count as gauntlet/virtual territory for the isolation hooks and the
    # pause-menu "Return to Main Game" gate, so push them into the shared
    # extra-ids list instead of GAMES.
    if real_id == start_id
      MultiverseHubSettings::GAMES[:pif2] = {
        name:     "Infinite Fusion 2",
        map_id:   remapped,
        map_name: info[:name],
        spawn:    PIF2Port.find_spawn(real_id),
      }
    else
      MultiverseHubSettings::EXTRA_GAUNTLET_MAP_NAMES[remapped] = info[:name]
    end
  end
  puts "[PIF2Port] Ported #{PIF2PortSettings.ported_maps.length} PIF2 map(s) into the Multiverse Hub."

  conns = PIF2Port.real_map_connections
  MultiverseHubSettings::EXTRA_MAP_CONNECTIONS.concat(conns)
  puts "[PIF2Port] Registered #{conns.length} real PIF2 map connection(s)."
  # MapFactoryHelper.getMapConnections (004_Game_MapFactory.rb) memoizes its
  # result in a class variable the FIRST time anything calls it (hasConnections?/
  # setMapsInRange/getNewMap/areConnected? all funnel through it) and never
  # recomputes afterward. If any other mod's own load-time self-test happens to
  # touch one of those before this file runs, EXTRA_MAP_CONNECTIONS above would
  # be baked in too late and every PIF2 edge -- including this Littleroot/Route
  # 101 one -- would look like a real, correctly-registered connection in our
  # own data (confirmed offline) while the live game still treats it as an
  # unconnected border (real symptom reported: invisible wall walking out of
  # the ported Littleroot). Forcing a clear here is a free, harmless reset --
  # worst case it recomputes once for nothing.
  MapFactoryHelper.clear if defined?(MapFactoryHelper)

  # Hook the generic Hub warp-in so the player's FIRST-EVER entry into PIF2
  # (not any other registered game, and not later re-entries) redirects to
  # the real Truck map instead of straight to Littleroot -- see
  # PIF2Port.bootstrap_pif2_intro! for why this makes the real intro
  # cutscene (and everything chained after it) fire for real instead of
  # switches being hand-forced.
  class << MultiverseHub
    alias_method :pif2port_orig_enter_gauntlet, :enter_gauntlet
    def enter_gauntlet(key)
      if key == :pif2 && PIF2Port.first_pif2_entry?
        PIF2Port.bootstrap_pif2_intro!
        return
      end
      pif2port_orig_enter_gauntlet(key)
    end
  end
else
  puts "[PIF2Port] ERROR: MultiverseHub not loaded -- check mod dependency order."
end
