#==============================================================================
# DBZInfiniteFusion port - near-1:1 port of real DBZ Infinite Fusion maps into
# the Multiverse Hub. Architecturally modeled on Mods/PIF2Port/main.rb (see
# that file's header for the general rationale of this whole approach), with
# one major departure: DBZ's own trainertypes.dat/trainers.dat are raw LEGACY
# POSITIONAL ARRAYS (pre-GameData-object format), not already-live GameData
# instances the way PIF2's are - so trainer porting here builds GameData::
# Trainer.register hashes from scratch (same public API AnimeFusionMerge/
# Bootstrap.rb already uses for its own PBS-text-driven loading) instead of
# copying+mutating existing objects.
#
# Confirmed offline (bare system Ruby, minimal RPG::* stub classes + Marshal.
# load, no engine/boot needed - see project_multiverse_hub memory) that DBZ's
# Map/MapInfo/Tileset/Event/CommonEvent Marshal schema is byte-identical to
# PIF2's and this host's own (same RPG::Map ivar set), and that all three
# games' compiled trainer text sources use item/move/species ids from each
# game's OWN PBS/*.txt files, keyed by plain "id,InternalName,..." rows (DBZ's
# PBS/pokemon.txt/moves.txt/items.txt) - so raw integer references inside
# trainers.dat resolve to symbols via a direct text-parse of those files,
# independent of AnimeFusionMerge's own separately-renumbered bundled copies.
#
# Offset scheme (150000-based, chosen to avoid the host's own max map id ~847,
# PIF2Port's already-occupied 50000+ range, and AnimeFusionMerge's trainer
# id_number range starting at 9,100,000):
#   - map id, switch id, variable id, tileset id: flat +150000
#   - trainer id_number: fresh id from TRAINER_ID_NUMBER_BASE (160000+),
#     always (mirrors PIF2Port's port_trainers - GameData.register double-keys
#     DATA[key] AND DATA[id_number], so a numeric collision is likely even
#     when the [type,name,version] key itself doesn't collide)
#   - trainer TYPES: not ported. Confirmed offline (dbz_trainertype_diff.rb)
#     that all 113 of DBZ's trainertypes.dat symbols already exist in the
#     host's own PBS/trainertypes.txt roster (0 missing) - DBZ, like PIF2,
#     descends from the same base-Essentials trainer-type roster. Only a
#     raw-integer -> symbol lookup (trainer_type_id_map, from DBZ's own
#     trainertypes.dat) is needed, to resolve trainers.dat's trainer_type_id
#     field.
#
# Known gaps (deferred, same spirit as PIF2Port's own documented gap list):
#   - Map metadata / wild encounters: PORTED (DBZPort.port_map_metadata /
#     .port_encounters) from DBZ's own PBS/metadata.txt + PBS/encounters.txt -
#     these turned out to be the same human-readable PBS text formats the
#     host's own Compiler already parses (not a divergent binary layout), so
#     no format-guessing was needed; the *.dat files were never touched.
#   - No Settings::GAME_ID-mismatch patches (PIF2Port has getDefaultHat/
#     getDefaultClothes/getDefaultHair/enter_common_building fixups for its
#     own :IF_HOENN-vs-host's-:IF_KANTO mismatch) - not yet investigated
#     whether DBZ's original data has any analogous GAME_ID-conditional logic.
#   - No intro-cutscene bootstrap (PIF2Port.bootstrap_pif2_intro!) - DBZ
#     enters directly at its START_MAP_ID like every other non-PIF2 gauntlet
#     game; not yet confirmed whether DBZ's own early game has a comparable
#     mandatory switch-gated cutscene chain that this would skip past.
#   - Player spawn point is the same nearest-passable-tile-to-center heuristic
#     PIF2Port uses, not DBZ's real default player start.
#==============================================================================
module DBZPortSettings
  DBZ_DATA_DIR      = "E:/pokemon infinite fusion and mods/Pokemon Anime fusions/dbz infinite fusions/Data"
  DBZ_GRAPHICS_DIR  = "E:/pokemon infinite fusion and mods/Pokemon Anime fusions/dbz infinite fusions/Graphics"
  DBZ_PBS_DIR       = "E:/pokemon infinite fusion and mods/Pokemon Anime fusions/dbz infinite fusions/PBS"
  MOD_GRAPHICS_DIR  = "Mods/DBZInfiniteFusion/Graphics"

  MAP_OFFSET      = 150000
  SWITCH_OFFSET   = 150000
  VARIABLE_OFFSET = 150000
  TILESET_OFFSET  = 150000
  TRAINER_VERSION_BASE        = 150000
  TRAINER_ID_NUMBER_BASE      = 160000
  TRAINER_TYPE_ID_NUMBER_BASE = 161000

  # DBZ Infinite Fusion reskins its entire base Kanto dex (ids 1-151) - every
  # slot keeps its vanilla InternalName (DRATINI, SQUIRTLE, ...) for engine/
  # fusion-system compatibility but overrides the displayed Name to a DBZ
  # character (Goku (Kid), Turtle, ...). Real new species registered for each
  # such reskin (see DBZPort.reskinned_species_map) get id_numbers from here.
  #
  # FIXED 2026-09-05: this used to be 165000, which is NOT inside the
  # is_reserved_standalone_dex? band (FusionUtils.rb: >=600000 && <700000) -
  # the old comment only checked the 700000 ceiling and missed the 600000
  # floor. 728-999998 is the live head*727+body two-way-fusion arithmetic
  # space (species_is_fusion), so every one of these 151 species was being
  # misidentified as a FUSION of two unrelated real Pokemon everywhere that
  # calls species_is_fusion/get_body_species_from_symbol/get_head_species_
  # from_symbol - wrong icons (isFusion? forces the generic DNA icon),
  # wrong Pokedex behavior, and pbFuse's own newid = body*727+head arithmetic
  # would have produced garbage ids if two of these were ever spliced
  # together. 610000 sits safely inside the reserved band, past
  # AnimeFusionMerge's own 600577-601326 range (see FusionMechanics.rb there)
  # - room for the ~151 possible reskins with no collision.
  SPECIES_ID_NUMBER_BASE = 610000

  # Real DBZ map id used as the single "DBZ Infinite Fusion" PC menu entry
  # point. "Pallet Town" (confirmed via MapInfos.rxdata name search); a
  # near-duplicate entry also named "Pallet Town" exists at id 205 (both
  # order~118/119, both with real map files, neither has children) - 76 was
  # picked as marginally more complete (10 events vs 205's 9) but this is a
  # coin-flip between two very similar maps, not a hard confirmation; may
  # need swapping to 205 after playtest if 76 turns out to be the stale one.
  START_MAP_ID = 76

  def self.remapped_id(real_id)
    MAP_OFFSET + real_id
  end

  def self.remap_switch_id(real_id)
    real_id + SWITCH_OFFSET
  end

  def self.real_map_infos
    @real_map_infos ||= Marshal.load(File.binread("#{DBZ_DATA_DIR}/MapInfos.rxdata"))
  end

  def self.all_real_map_ids
    @all_real_map_ids ||= real_map_infos.keys.select { |id|
      File.exist?("#{DBZ_DATA_DIR}/Map%03d.rxdata" % id)
    }.sort
  end

  def self.ported_maps
    @ported_maps ||= all_real_map_ids.each_with_object({}) { |id, h|
      h[id] = { name: real_map_infos[id].name }
    }
  end
end

module DBZPort
  @dbz_tilesets  = nil
  @built_maps    = {}

  def self.dbz_tilesets
    @dbz_tilesets ||= Marshal.load(File.binread("#{DBZPortSettings::DBZ_DATA_DIR}/Tilesets.rxdata"))
  end

  def self.load_real_map(real_id)
    Marshal.load(File.binread("#{DBZPortSettings::DBZ_DATA_DIR}/Map%03d.rxdata" % real_id))
  end

  # Not FileUtils.mkdir_p - this build's embedded Ruby doesn't ship the
  # fileutils stdlib (confirmed via PIF2Port's own real crash/fix).
  def self.ensure_dir(path)
    parts = path.split('/')
    cur = ""
    parts.each do |part|
      cur = cur.empty? ? part : "#{cur}/#{part}"
      Dir.mkdir(cur) if !Dir.exist?(cur)
    end
  end

  def self.copy_asset(category, name)
    return "" if !name || name.empty?
    src = "#{DBZPortSettings::DBZ_GRAPHICS_DIR}/#{category}/#{name}.png"
    return "" unless File.exist?(src)
    dest_dir = "#{DBZPortSettings::MOD_GRAPHICS_DIR}/#{category}"
    ensure_dir(dest_dir)
    dest = "#{dest_dir}/#{name}.png"
    File.binwrite(dest, File.binread(src)) unless File.exist?(dest)
    "../../#{dest_dir}/#{name}"
  rescue => e
    puts "[DBZPort] asset copy failed for #{category}/#{name}: #{e.message}"
    ""
  end

  # Same namespaced-directly-under-Graphics/Autotiles/ placement PIF2Port
  # uses - see that file's copy_autotile for why (the renderer's own autotile
  # expansion cache write doesn't normalize "../.." Mods/-relative names).
  def self.copy_autotile(name)
    return "" if !name || name.empty?
    src = "#{DBZPortSettings::DBZ_GRAPHICS_DIR}/Autotiles/#{name}.png"
    return "" unless File.exist?(src)
    dest_dir = "Graphics/Autotiles/DBZPort"
    ensure_dir(dest_dir)
    dest = "#{dest_dir}/#{name}.png"
    File.binwrite(dest, File.binread(src)) unless File.exist?(dest)
    ensure_dir("Graphics/Autotiles/ExpandedAutotiles/DBZPort")
    "DBZPort/#{name}"
  rescue => e
    puts "[DBZPort] autotile copy failed for #{name}: #{e.message}"
    ""
  end

  def self.ensure_tileset(real_ts_id)
    remapped = DBZPortSettings::TILESET_OFFSET + real_ts_id
    return remapped if $data_tilesets[remapped]

    real = dbz_tilesets[real_ts_id]
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
          cmd.parameters[1] = DBZPortSettings.remap_switch_id(cmd.parameters[1])
        when 1 # variable
          cmd.parameters[1] += DBZPortSettings::VARIABLE_OFFSET
          cmd.parameters[3] += DBZPortSettings::VARIABLE_OFFSET if cmd.parameters[2] == 1
        end
      when 121 # control switches (range)
        cmd.parameters[0] = DBZPortSettings.remap_switch_id(cmd.parameters[0])
        cmd.parameters[1] = DBZPortSettings.remap_switch_id(cmd.parameters[1])
      when 122 # control variables
        cmd.parameters[0] += DBZPortSettings::VARIABLE_OFFSET
        cmd.parameters[1] += DBZPortSettings::VARIABLE_OFFSET
        cmd.parameters[3] += DBZPortSettings::VARIABLE_OFFSET if cmd.parameters[2] == 1
      when 201 # transfer player
        if cmd.parameters[0] == 0
          cmd.parameters[1] += DBZPortSettings::MAP_OFFSET
        else
          cmd.parameters[1] += DBZPortSettings::VARIABLE_OFFSET
          cmd.parameters[2] += DBZPortSettings::VARIABLE_OFFSET
          cmd.parameters[3] += DBZPortSettings::VARIABLE_OFFSET
        end
      when 117 # call common event
        mapped = common_event_id_map[cmd.parameters[0]]
        cmd.parameters[0] = mapped if mapped
      when 355, 655 # script / script continuation
        cmd.parameters[0] = remap_species_in_script!(cmd.parameters[0]) if cmd.parameters[0]
      end
    end
  end

  # Contiguous new ids right after the host's own current highest common
  # event id - NOT a flat +150000 offset. See PIF2Port.common_event_id_map's
  # comment for why a wide gap of nils crashes the engine's own per-map
  # Game_CommonEvent setup. Reads $data_common_events fresh at runtime (not a
  # hardcoded base), so this correctly starts after whatever PIF2Port (or any
  # other mod) already appended, regardless of load order.
  def self.common_event_id_map
    return @common_event_id_map if @common_event_id_map
    @common_event_id_map = {}
    real_list = Marshal.load(File.binread("#{DBZPortSettings::DBZ_DATA_DIR}/CommonEvents.rxdata"))
    next_id = ($data_common_events.compact.map(&:id).max || 0) + 1
    real_list.each do |ce|
      next unless ce
      @common_event_id_map[ce.id] = next_id
      next_id += 1
    end
    @common_event_id_map
  end

  def self.ensure_common_events
    return if @common_events_ready
    @common_events_ready = true
    return unless defined?($data_common_events)
    id_map = common_event_id_map
    real_list = Marshal.load(File.binread("#{DBZPortSettings::DBZ_DATA_DIR}/CommonEvents.rxdata"))
    real_list.each do |ce|
      next unless ce
      ce.id = id_map[ce.id]
      ce.switch_id += DBZPortSettings::SWITCH_OFFSET if ce.respond_to?(:switch_id) && ce.switch_id
      remap_event_commands!(ce.list)
      $data_common_events[ce.id] = ce
    end
    puts "[DBZPort] Ported #{real_list.compact.length} DBZ common event(s)."
  rescue => e
    puts "[DBZPort] common event port failed: #{e.class}: #{e.message}"
  end

  def self.build_map(real_id)
    remapped = DBZPortSettings.remapped_id(real_id)
    return @built_maps[remapped] if @built_maps[remapped]
    ensure_common_events

    map = load_real_map(real_id)
    begin
      map.tileset_id = ensure_tileset(map.tileset_id)
    rescue => e
      puts "[DBZPort] tileset remap failed for map #{real_id}: #{e.class}: #{e.message}"
    end

    (map.events || {}).each_value do |ev|
      ev.pages.each do |page|
        # Per-event rescue, not one rescue around the whole map - see
        # PIF2Port.build_map's comment for the exact failure mode this
        # avoids (MapFactoryHelper#getMapDims swallowing a raised error and
        # silently making the whole map unreachable with zero output).
        begin
          cond = page.condition
          cond.switch1_id = DBZPortSettings.remap_switch_id(cond.switch1_id) if cond.switch1_valid
          cond.switch2_id = DBZPortSettings.remap_switch_id(cond.switch2_id) if cond.switch2_valid
          cond.variable_id += DBZPortSettings::VARIABLE_OFFSET if cond.variable_valid
          remap_event_commands!(page.list)
          g = page.graphic
          g.character_name = copy_asset("Characters", g.character_name) if g.character_name && !g.character_name.empty?
        rescue => e
          puts "[DBZPort] event remap failed on map #{real_id}, event #{ev.id rescue '?'}: #{e.class}: #{e.message}"
        end
      end
    end

    @built_maps[remapped] = map
  rescue => e
    puts "[DBZPort] build_map(#{real_id}) FAILED: #{e.class}: #{e.message}"
    (e.backtrace || []).first(5).each { |l| puts "  #{l}" }
    fallback = RPG::Map.new(20, 15)
    fallback.tileset_id = 1
    @built_maps[remapped] = fallback
  end

  # DBZ's connections.dat - same [mapA, edgeA, offsetA, mapB, edgeB, offsetB]
  # format as PIF2's map_connections.dat / the host's own, confirmed plain
  # Marshal (no XOR, unlike some of PIF2's .dat files).
  def self.real_map_connections
    return @real_map_connections if @real_map_connections
    raw = Marshal.load(File.binread("#{DBZPortSettings::DBZ_DATA_DIR}/connections.dat"))
    ids = DBZPortSettings.all_real_map_ids
    @real_map_connections = raw.select { |c| ids.include?(c[0]) && ids.include?(c[3]) }.map { |c|
      c2 = c.dup
      c2[0] = DBZPortSettings.remapped_id(c[0])
      c2[3] = DBZPortSettings.remapped_id(c[3])
      c2
    }
  rescue => e
    puts "[DBZPort] map connections load failed: #{e.class}: #{e.message}"
    @real_map_connections = []
  end

  def self.find_spawn(real_id)
    map = load_real_map(real_id)
    ts = dbz_tilesets[map.tileset_id]
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

  #============================================================================
  # Trainer port - DBZ's trainertypes.dat/trainers.dat are raw legacy
  # positional arrays (ground-truthed by reading DBZ's own bundled Scripts.
  # rxdata "Compiler"/"PTrainer_NPCTrainers" sections offline), not live
  # GameData objects, so this builds GameData::Trainer.register hashes from
  # scratch instead of PIF2Port's ivar-copy approach.
  #============================================================================

  TP_SPECIES   = 0
  TP_LEVEL     = 1
  TP_ITEM      = 2
  TP_MOVE1     = 3
  TP_MOVE2     = 4
  TP_MOVE3     = 5
  TP_MOVE4     = 6
  TP_ABILITY   = 7
  TP_GENDER    = 8
  TP_FORM      = 9
  TP_SHINY     = 10
  TP_NATURE    = 11
  TP_IV        = 12
  TP_HAPPINESS = 13
  TP_NAME      = 14
  TP_SHADOW    = 15
  TP_BALL      = 16

  # Standard Essentials PBNatures constant order (0-24) - DBZ's own compiler
  # (parseNature, via pbGetConst(PBNatures, name)) stores this same raw index
  # in trainers.dat, not a name string.
  NATURE_NAMES = %i[
    HARDY LONELY BRAVE ADAMANT NAUGHTY BOLD DOCILE RELAXED IMPISH LAX
    TIMID HASTY SERIOUS JOLLY NAIVE MODEST MILD QUIET BASHFUL RASH
    CALM GENTLE SASSY CAREFUL QUIRKY
  ].freeze

  # Generic "id,InternalName,..." CSV-row parser shared by DBZ's own moves.txt
  # / items.txt (confirmed same column layout as the host's own PBS files -
  # first column a raw integer id, second column the InternalName symbol).
  def self.parse_id_to_internal_name_csv(path)
    map = {}
    File.readlines(path, encoding: "bom|utf-8").each do |line|
      line = line.strip
      next if line.empty? || line.start_with?("#")
      parts = line.split(",")
      next unless parts[0] =~ /^\d+$/
      map[parts[0].to_i] = parts[1].strip
    end
    map
  end

  # Registers a brand-new GameData::Species for every DBZ dex-1-151 slot whose
  # displayed Name differs from the host's real name for that InternalName
  # (e.g. InternalName=DRATINI, Name="Goku (Kid)") - confirmed via
  # find_dbz_reskins.rb that this covers exactly the base Kanto dex (151
  # reskins), the foundational conceit of the whole DBZ port's fusion system.
  # Mirrors AnimeFusionMerge/Bootstrap.rb#load_species's own field mapping/
  # schema-conversion loop exactly (same GameData::Species.schema, same
  # pbGetCsvRecord/csvEnumField! machinery - this runs at real game boot, not
  # offline, so those engine helpers are available), but assigns each reskin
  # a brand-new :"DBZ_<InternalName>" symbol and a sequential
  # SPECIES_ID_NUMBER_BASE id_number instead of reusing/overwriting the
  # vanilla entry, so vanilla Dratini etc. remain completely untouched.
  # Returns {vanilla_symbol => new_dbz_symbol} for the untranslated-name slots
  # only - used by build_pokemon_hash (trainer rosters) and
  # remap_species_in_script! (map-event pbAddPokemon calls) to redirect any
  # DBZ-side reference onto the correct new species.
  def self.reskinned_species_map
    return @reskinned_species_map if @reskinned_species_map
    map = {}
    return (@reskinned_species_map = map) unless defined?(GameData::Species)
    path = "#{DBZPortSettings::DBZ_PBS_DIR}/pokemon.txt"
    return (@reskinned_species_map = map) unless File.exist?(path)

    pending = []
    File.open(path, "rb") { |f|
      FileLineData.file = path
      schema = GameData::Species.schema
      pbEachFileSection(f) { |contents, species_number|
        next unless species_number >= 1 && species_number <= 151
        internal_name = contents["InternalName"].to_s.strip
        next if internal_name.empty?
        real_symbol = internal_name.to_sym
        next unless GameData::Species.exists?(real_symbol)
        real_species = GameData::Species.get(real_symbol)
        next if real_species.real_name == contents["Name"].to_s.strip
        pending << [real_symbol, real_species, contents]
      }

      next_id = DBZPortSettings::SPECIES_ID_NUMBER_BASE
      pending.each do |real_symbol, real_species, contents|
        new_symbol = :"DBZ_#{real_symbol}"
        next if GameData::Species.exists?(new_symbol)
        for key in schema.keys
          if nil_or_empty?(contents[key])
            contents[key] = nil
            next
          end
          value = pbGetCsvRecord(contents[key], key, schema[key])
          value = nil if value.is_a?(Array) && value.length == 0
          contents[key] = value
          case key
          when "BaseStats", "EffortPoints"
            value_hash = {}
            GameData::Stat.each_main do |s|
              value_hash[s.id] = value[s.pbs_order] if s.pbs_order >= 0
            end
            contents[key] = value_hash
          when "Height", "Weight"
            contents[key] = (value * 10).round
          when "Moves"
            move_array = []
            for i in 0...value.length / 2
              move_array.push([value[i * 2], value[i * 2 + 1], i])
            end
            move_array.sort! { |a, b| (a[0] == b[0]) ? a[2] <=> b[2] : a[0] <=> b[0] }
            move_array.each { |arr| arr.pop }
            contents[key] = move_array
          when "TutorMoves", "EggMoves", "Abilities", "HiddenAbility", "Compatibility"
            contents[key] = [contents[key]] if !contents[key].is_a?(Array)
            contents[key].compact!
          when "Evolutions"
            evo_array = []
            for i in 0...value.length / 3
              evo_array.push([value[i * 3], value[i * 3 + 1], value[i * 3 + 2], false])
            end
            contents[key] = evo_array
          end
        end
        species_hash = {
          id: new_symbol,
          id_number: next_id,
          name: contents["Name"],
          form_name: contents["FormName"],
          category: contents["Kind"],
          pokedex_entry: contents["Pokedex"],
          type1: contents["Type1"],
          type2: contents["Type2"],
          base_stats: contents["BaseStats"],
          evs: contents["EffortPoints"],
          base_exp: contents["BaseEXP"],
          growth_rate: contents["GrowthRate"],
          gender_ratio: contents["GenderRate"],
          catch_rate: contents["Rareness"],
          happiness: contents["Happiness"],
          moves: contents["Moves"],
          tutor_moves: contents["TutorMoves"],
          egg_moves: contents["EggMoves"],
          abilities: contents["Abilities"],
          hidden_abilities: contents["HiddenAbility"],
          wild_item_common: contents["WildItemCommon"],
          wild_item_uncommon: contents["WildItemUncommon"],
          wild_item_rare: contents["WildItemRare"],
          egg_groups: contents["Compatibility"],
          hatch_steps: contents["StepsToHatch"],
          incense: contents["Incense"],
          evolutions: contents["Evolutions"],
          height: contents["Height"],
          weight: contents["Weight"],
          color: contents["Color"],
          shape: contents["Shape"] ? GameData::BodyShape.get(contents["Shape"]).id : real_species.shape,
          habitat: contents["Habitat"],
          generation: contents["Generation"],
          back_sprite_x: contents["BattlerPlayerX"],
          back_sprite_y: contents["BattlerPlayerY"],
          front_sprite_x: contents["BattlerEnemyX"],
          front_sprite_y: contents["BattlerEnemyY"],
          front_sprite_altitude: contents["BattlerAltitude"],
          shadow_x: contents["BattlerShadowX"],
          shadow_size: contents["BattlerShadowSize"],
        }
        GameData::Species.register(species_hash)
        map[real_symbol] = new_symbol
        next_id += 1
      end
    }

    # Resolve evolution targets (same csvEnumField!/csvPosInt! calls
    # Bootstrap.rb#load_species makes in its own second pass), then remap any
    # target that is itself a reskinned sibling (e.g. Goku's Dratini ->
    # Dragonair -> Dragonite chain) onto its new DBZ_ symbol - otherwise every
    # reskin's evolution would silently point at the untouched vanilla mon.
    map.each_value do |new_symbol|
      species = GameData::Species.get(new_symbol)
      species.evolutions.each do |evo|
        evo[0] = csvEnumField!(evo[0], :Species, "Evolutions", species.id_number)
        param_type = GameData::Evolution.get(evo[1]).parameter
        if param_type.nil?
          evo[2] = nil
        elsif param_type == Integer
          evo[2] = csvPosInt!(evo[2])
        else
          evo[2] = csvEnumField!(evo[2], param_type, "Evolutions", species.id_number)
        end
        evo[0] = map[evo[0]] if map[evo[0]]
      end
    end

    puts "[DBZPort] Registered #{map.length} reskinned DBZ species (base Kanto dex characters)."
    @reskinned_species_map = map
  rescue => e
    puts "[DBZPort] reskinned species registration FAILED: #{e.class}: #{e.message}"
    (e.backtrace || []).first(5).each { |l| puts "  #{l}" }
    @reskinned_species_map = {}
  end

  # Rewrites the species symbol argument of pbAddPokemon/pbGenerateWildPokemon/
  # pbGeneratePokemon/PokeBattle_Pokemon.new/Pokemon.new(...) calls embedded in
  # a ported map event's Script (355) / Script-continuation (655) command text
  # onto the correct reskinned DBZ species, if any - remap_event_commands!
  # otherwise has no handling of these codes at all, so a starter/rival/gift
  # scene's pbAddPokemon(:DRATINI,5) would hand the player a literal vanilla
  # Dratini instead of DBZ's "Goku (Kid)".
  SPECIES_GIVING_CALL_RE = /\b(pbAddPokemon|pbGenerateWildPokemon|pbGeneratePokemon|PokeBattle_Pokemon\.new|Pokemon\.new)\s*\(\s*:([A-Za-z0-9_]+)/

  def self.remap_species_in_script!(text)
    return text unless text.is_a?(String)
    map = reskinned_species_map
    return text if map.empty?
    text.gsub(SPECIES_GIVING_CALL_RE) do |match|
      call, sym_name = $1, $2
      mapped = map[sym_name.to_sym]
      mapped ? "#{call}(:#{mapped}" : match
    end
  end

  # DBZ's own PBS/pokemon.txt: "[id]" section headers with an "InternalName="
  # line - NOT a flat CSV like moves/items. Confirmed against a real trainer
  # sample (species id 16 -> InternalName PIDGEY) and against AnimeFusionMerge/
  # Bootstrap.rb's own species loader, which also keys/dedups by InternalName -
  # so this resolves correctly whether the id lands on a vanilla species DBZ
  # re-skinned (kept the vanilla InternalName) or a genuinely custom one
  # AnimeFusionMerge separately registered under that same InternalName.
  def self.dbz_species_map
    return @dbz_species_map if @dbz_species_map
    map = {}
    current_id = nil
    File.readlines("#{DBZPortSettings::DBZ_PBS_DIR}/pokemon.txt", encoding: "bom|utf-8").each do |line|
      line = line.strip
      if line =~ /^\[(\d+)\]$/
        current_id = $1.to_i
      elsif current_id && line =~ /^InternalName\s*=\s*(.+)$/
        map[current_id] = $1.strip
        current_id = nil
      end
    end
    @dbz_species_map = map
  end

  def self.dbz_moves_map
    @dbz_moves_map ||= parse_id_to_internal_name_csv("#{DBZPortSettings::DBZ_PBS_DIR}/moves.txt")
  end

  def self.dbz_items_map
    @dbz_items_map ||= parse_id_to_internal_name_csv("#{DBZPortSettings::DBZ_PBS_DIR}/items.txt")
  end

  # DBZ's own trainertypes.dat: [type_id, symbol_name, display_name,
  # base_money, ?, ?, ?, gender, base_money_again] - confirmed all 113 symbols
  # already exist in the host's PBS/trainertypes.txt roster
  # (dbz_trainertype_diff.rb: 0 missing), so only the raw-id -> symbol lookup
  # is needed here, no GameData::TrainerType.register pass.
  def self.trainer_type_id_map
    return @trainer_type_id_map if @trainer_type_id_map
    map = {}
    types = Marshal.load(File.binread("#{DBZPortSettings::DBZ_DATA_DIR}/trainertypes.dat"))
    types.each { |t| map[t[0]] = t[1].to_sym if t[0] && t[1] }
    @trainer_type_id_map = map
  end

  def self.build_pokemon_hash(poke)
    species_name = dbz_species_map[poke[TP_SPECIES]]
    return nil unless species_name
    species_sym = species_name.to_sym
    species_sym = reskinned_species_map[species_sym] || species_sym
    h = {
      species: species_sym,
      level:   poke[TP_LEVEL],
      shininess:  !!poke[TP_SHINY],
      shadowness: !!poke[TP_SHADOW],
    }
    h[:form] = poke[TP_FORM] if poke[TP_FORM] && poke[TP_FORM] != 0
    h[:happiness] = poke[TP_HAPPINESS] if poke[TP_HAPPINESS]
    h[:gender] = poke[TP_GENDER] if poke[TP_GENDER]
    h[:ability_index] = poke[TP_ABILITY] if poke[TP_ABILITY]
    h[:name] = poke[TP_NAME] if poke[TP_NAME] && !poke[TP_NAME].to_s.empty?
    if poke[TP_NATURE]
      nat = NATURE_NAMES[poke[TP_NATURE]]
      h[:nature] = nat if nat
    end
    if poke[TP_IV]
      iv_hash = {}
      GameData::Stat.each_main { |s| iv_hash[s.id] = poke[TP_IV] }
      h[:iv] = iv_hash
    end
    if poke[TP_ITEM] && poke[TP_ITEM] != 0
      item_name = dbz_items_map[poke[TP_ITEM]]
      h[:item] = item_name.to_sym if item_name
    end
    if poke[TP_BALL] && poke[TP_BALL] != 0
      ball_name = dbz_items_map[poke[TP_BALL]]
      h[:poke_ball] = ball_name.to_sym if ball_name
    end
    moves = [TP_MOVE1, TP_MOVE2, TP_MOVE3, TP_MOVE4].map { |i| poke[i] }.select { |m| m && m != 0 }
    unless moves.empty?
      move_syms = moves.map { |m| dbz_moves_map[m] }.compact.map(&:to_sym)
      h[:moves] = move_syms unless move_syms.empty?
    end
    h
  rescue => e
    puts "[DBZPort] pokemon hash build failed for #{poke.inspect}: #{e.class}: #{e.message}"
    nil
  end

  # Ports DBZ's ~626 legacy trainers.dat entries into GameData::Trainer via
  # the public .register(hash) API (same mechanism AnimeFusionMerge/
  # Bootstrap.rb#load_trainers already uses for its own PBS-text trainers),
  # rather than PIF2Port's ivar-copy approach - not viable here since there
  # is no live GameData::Trainer object to copy from, only a raw array.
  # Collision-checked via GameData::Trainer.exists? (mirrors AnimeFusionMerge)
  # rather than PIF2Port's version-bump-on-collision, since a fresh
  # TRAINER_ID_NUMBER_BASE id_number is assigned unconditionally anyway - a
  # colliding [type, name, version] key here is just skipped, same as
  # AnimeFusionMerge does for its own trainers.
  def self.port_trainers
    return if @trainers_ported
    @trainers_ported = true
    return unless defined?(GameData::Trainer)

    type_map = trainer_type_id_map
    raw = Marshal.load(File.binread("#{DBZPortSettings::DBZ_DATA_DIR}/trainers.dat"))
    added = 0
    skipped = 0
    failed = 0
    raw.each_with_index do |t, i|
      type_id, name, items, pokemon_list, version = t
      type_sym = type_map[type_id]
      unless type_sym
        failed += 1
        next
      end
      if GameData::Trainer.exists?(type_sym, name, version || 0)
        skipped += 1
        next
      end
      pokemon = (pokemon_list || []).map { |p| build_pokemon_hash(p) }.compact
      if pokemon.empty?
        failed += 1
        next
      end
      item_syms = (items || []).map { |id| dbz_items_map[id] }.compact.map(&:to_sym)
      hash = {
        id: [type_sym, name, version || 0],
        id_number: DBZPortSettings::TRAINER_ID_NUMBER_BASE + i,
        trainer_type: type_sym,
        name: name,
        version: version || 0,
        items: item_syms,
        pokemon: pokemon,
      }
      GameData::Trainer.register(hash)
      added += 1
    rescue => e
      failed += 1
      puts "[DBZPort] trainer ##{i} (#{name rescue '?'}) failed: #{e.class}: #{e.message}"
    end
    puts "[DBZPort] Registered #{added} DBZ trainer(s) (#{skipped} skipped as collisions, #{failed} failed)."
  rescue => e
    puts "[DBZPort] port_trainers FAILED: #{e.class}: #{e.message}"
  end

  #============================================================================
  # Wild encounter + map metadata port - fixes "no wild Pokemon show up in
  # DBZ Infinite Fusion". DBZ ships its OWN PBS/encounters.txt and
  # PBS/metadata.txt (confirmed via direct inspection - these are the exact
  # same human-readable PBS text formats the host's own Compiler.
  # compile_encounters/compile_metadata parse, NOT some divergent legacy
  # binary layout), so this reuses the host's real parsing helpers
  # (Compiler.pbCompilerEachPreppedLine/pbEachFileSection/pbGetCsvRecord) on
  # DBZ's own PBS files directly instead of guessing at *.dat internals, then
  # builds fresh GameData::Encounter/MapMetadata.register hashes (same
  # from-scratch approach as port_trainers - nothing live to copy/mutate).
  #============================================================================

  # DBZ's encounters.txt uses the OLD PBS format (confirmed: map sections are
  # plain "008" lines, not "[008]") - same branch of compile_encounters this
  # mirrors (per-type probability looked up from GameData::EncounterType's
  # own #old_slots table, then identical (species,min,max) slots merged and
  # sorted descending, exactly like the real compiler does before registering).
  def self.port_encounters
    return if @encounters_ported
    @encounters_ported = true
    return unless defined?(GameData::Encounter) && defined?(GameData::EncounterType)
    path = "#{DBZPortSettings::DBZ_PBS_DIR}/encounters.txt"
    return unless File.exist?(path)

    real_ids = DBZPortSettings.all_real_map_ids
    blocks = []
    current = nil
    Compiler.pbCompilerEachPreppedLine(path) do |line, line_no|
      if line =~ /^(\d+)$/
        blocks << current if current
        current = { map: $1.to_i, lines: [] }
      elsif current
        current[:lines] << [line, line_no]
      end
    end
    blocks << current if current

    added = 0
    skipped = 0
    failed = 0
    blocks.each do |block|
      real_id = block[:map]
      next unless real_ids.include?(real_id)
      remapped = DBZPortSettings.remapped_id(real_id)
      if GameData::Encounter.exists?(remapped, 0)
        skipped += 1
        next
      end
      step_chances = {}
      types = {}
      current_type = nil
      probabilities = nil
      expected_lines = 0
      block[:lines].each do |line, line_no|
        if expected_lines > 0
          values = line.split(',').collect! { |v| v.strip }
          next if !values || values.length < 2
          values = Compiler.pbGetCsvRecord(line, line_no, [0, "evV", :Species])
          values[2] = values[1] if !values[2]
          probability = probabilities[probabilities.length - expected_lines]
          types[current_type].push([probability] + values)
          expected_lines -= 1
        elsif line =~ /^\d+\s*,/
          # Legacy global density line - dead in practice (no EncounterType
          # is ever registered with a lowercase :land/:cave/:water id, which
          # is the only thing this line would feed into); each type's own
          # per-header trigger chance (below) is what's actually used.
          next
        else
          values = line.split(',').collect! { |v| v.strip }
          current_type = (values[0] && !values[0].empty?) ? values[0].to_sym : nil
          next unless current_type && GameData::EncounterType.exists?(current_type)
          step_chances[current_type] = values[1].to_i if values[1] && !values[1].empty?
          step_chances[current_type] ||= GameData::EncounterType.get(current_type).trigger_chance
          probabilities = GameData::EncounterType.get(current_type).old_slots
          expected_lines = probabilities.length
          types[current_type] = []
        end
      end
      types.each_value do |slots|
        next if !slots || slots.empty?
        slots.each_with_index do |slot, i|
          next if !slot
          slots.each_with_index do |other_slot, j|
            next if i == j || !other_slot
            next if slot[1] != other_slot[1] || slot[2] != other_slot[2] || slot[3] != other_slot[3]
            slot[0] += other_slot[0]
            slots[j] = nil
          end
        end
        slots.compact!
        slots.sort! { |a, b| (a[0] == b[0]) ? a[1].to_s <=> b[1].to_s : b[0] <=> a[0] }
      end
      GameData::Encounter.register({
        id: sprintf("%s_0", remapped).to_sym,
        map: remapped,
        version: 0,
        step_chances: step_chances,
        types: types
      })
      added += 1
    rescue => e
      failed += 1
      puts "[DBZPort] encounters for map #{real_id} failed: #{e.class}: #{e.message}"
    end
    puts "[DBZPort] Registered #{added} DBZ map encounter set(s) (#{skipped} skipped as collisions, #{failed} failed)."
  rescue => e
    puts "[DBZPort] port_encounters FAILED: #{e.class}: #{e.message}"
  end

  # DBZ's metadata.txt uses the modern "[id]" + "Key=Value" PBS format - same
  # field names as the host's own GameData::MapMetadata::SCHEMA (confirmed via
  # direct inspection: Outdoor/ShowArea/Bicycle/BattleBack/MapPosition/etc.
  # all present verbatim). Section [000] is DBZ's own *global* metadata
  # (player character graphics, etc.) - deliberately skipped, since the host
  # already has its own and this must never overwrite it. HealingSpot/DiveMap
  # embed a real DBZ map id inside their value, so those are remapped too -
  # otherwise a Pokemon Center heal-and-fly on a ported map would point at an
  # unmapped/wrong map id.
  def self.port_map_metadata
    return if @metadata_ported
    @metadata_ported = true
    return unless defined?(GameData::MapMetadata)
    path = "#{DBZPortSettings::DBZ_PBS_DIR}/metadata.txt"
    return unless File.exist?(path)

    real_ids = DBZPortSettings.all_real_map_ids
    added = 0
    skipped = 0
    failed = 0
    File.open(path, "rb") do |f|
      FileLineData.file = path
      Compiler.pbEachFileSection(f) do |contents, map_id|
        next if map_id == 0
        next unless real_ids.include?(map_id)
        remapped = DBZPortSettings.remapped_id(map_id)
        if GameData::MapMetadata.exists?(remapped)
          skipped += 1
          next
        end
        begin
          schema = GameData::MapMetadata::SCHEMA
          for key in schema.keys
            next if contents[key].nil?
            value = Compiler.pbGetCsvRecord(contents[key], key, schema[key])
            value = nil if value.is_a?(Array) && value.length == 0
            contents[key] = value
          end
          if contents["HealingSpot"].is_a?(Array) && real_ids.include?(contents["HealingSpot"][0])
            contents["HealingSpot"][0] = DBZPortSettings.remapped_id(contents["HealingSpot"][0])
          end
          if contents["DiveMap"] && real_ids.include?(contents["DiveMap"])
            contents["DiveMap"] = DBZPortSettings.remapped_id(contents["DiveMap"])
          end
          GameData::MapMetadata.register({
            id: remapped,
            outdoor_map: contents["Outdoor"],
            announce_location: contents["ShowArea"],
            can_bicycle: contents["Bicycle"],
            always_bicycle: contents["BicycleAlways"],
            teleport_destination: contents["HealingSpot"],
            weather: contents["Weather"],
            town_map_position: contents["MapPosition"],
            dive_map_id: contents["DiveMap"],
            dark_map: contents["DarkMap"],
            safari_map: contents["SafariMap"],
            snap_edges: contents["SnapEdges"],
            random_dungeon: contents["Dungeon"],
            battle_background: contents["BattleBack"],
            battle_background_water: contents["BattleBackWater"],
            wild_battle_BGM: contents["WildBattleBGM"],
            trainer_battle_BGM: contents["TrainerBattleBGM"],
            wild_victory_ME: contents["WildVictoryME"],
            trainer_victory_ME: contents["TrainerVictoryME"],
            wild_capture_ME: contents["WildCaptureME"],
            town_map_size: contents["MapSize"],
            battle_environment: contents["Environment"]
          })
          added += 1
        rescue => e
          failed += 1
          puts "[DBZPort] metadata for map #{map_id} failed: #{e.class}: #{e.message}"
        end
      end
    end
    puts "[DBZPort] Registered #{added} DBZ map metadata entry/ies (#{skipped} skipped as collisions, #{failed} failed)."
  rescue => e
    puts "[DBZPort] port_map_metadata FAILED: #{e.class}: #{e.message}"
  end
end

# Global safety net for ANY nil gap in $data_common_events, same fix as
# PIF2Port's own (see that file's comment for the exact live-playtest crash
# this guards against - Game_Map#setup instantiates a Game_CommonEvent for
# EVERY index in range with no nil-check). Reopening the class with identical
# method bodies is harmless if PIF2Port has already patched it.
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

# Port trainers only after the host's own real GameData::Trainer.load has
# fully populated DATA - mirrors PIF2Port's identical GameData.load_all hook
# (registering earlier would just get overwritten, since GameData::Trainer.
# load replaces its DATA hash wholesale via const_set).
class << GameData
  alias_method :dbzport_orig_load_all, :load_all
  def load_all
    dbzport_orig_load_all
    DBZPort.reskinned_species_map
    DBZPort.port_trainers
    DBZPort.port_map_metadata
    DBZPort.port_encounters
  end
end

# Register each ported map into MultiverseHub's existing infrastructure -
# same pattern as PIF2Port's final registration block.
if defined?(MultiverseHub) && defined?(MultiverseHubSettings)
  start_id = DBZPortSettings::START_MAP_ID
  DBZPortSettings.ported_maps.each do |real_id, info|
    remapped = DBZPortSettings.remapped_id(real_id)
    method_name = :"build_dbz_map_#{real_id}"
    MultiverseHub.define_singleton_method(method_name) { DBZPort.build_map(real_id) }
    MultiverseHub::GAUNTLET_MAP_BUILDERS[remapped] = method_name

    if real_id == start_id
      MultiverseHubSettings::GAMES[:dbz] = {
        name:     "DBZ Infinite Fusion",
        map_id:   remapped,
        map_name: info[:name],
        spawn:    DBZPort.find_spawn(real_id),
      }
    else
      MultiverseHubSettings::EXTRA_GAUNTLET_MAP_NAMES[remapped] = info[:name]
    end
  end
  puts "[DBZPort] Ported #{DBZPortSettings.ported_maps.length} DBZ map(s) into the Multiverse Hub."

  conns = DBZPort.real_map_connections
  MultiverseHubSettings::EXTRA_MAP_CONNECTIONS.concat(conns)
  puts "[DBZPort] Registered #{conns.length} real DBZ map connection(s)."
  # See PIF2Port's identical call for why this reset is needed - MapFactoryHelper.
  # getMapConnections memoizes on first use and never recomputes.
  MapFactoryHelper.clear if defined?(MapFactoryHelper)
else
  puts "[DBZPort] ERROR: MultiverseHub not loaded -- check mod dependency order."
end
