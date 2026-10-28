#==============================================================================
# Anime Fusion Merge
# Additively registers species (pokemon.txt) and moves (moves.txt) bundled in
# this mod folder into GameData, without touching the base game's PBS files.
# Mirrors the base game's own compile_pokemon/compile_moves logic (021_Compiler
# /002_Compiler_CompilePBS.rb) but skips DATA.clear so existing entries survive,
# and skips MessageTypes registration (species/move name/category/description
# accessors fall back to the literal values in the hash when no message is set).
#==============================================================================
module GameData
  class TrainerType
    # Unlike GameData::Species#name, the base #name has no fallback to
    # @real_name when no MessageTypes::TrainerTypes entry exists for
    # @id_number - and we deliberately skip MessageTypes registration (see
    # AnimeFusionMerge.load_trainertypes). Without this override, every
    # trainer type added by this mod would display as a blank name prefix
    # in battle ("  Miguel wants to battle!" instead of "Leader Miguel...").
    def name
      ret = pbGetMessage(MessageTypes::TrainerTypes, @id_number)
      return (ret && !ret.empty?) ? ret : @real_name
    end
  end
end

module GameData
  class Species
    class << self
      # AnimeFusionMerge species sit at dex 600577-601326, purely as an ID range to
      # avoid colliding with vanilla (1-576). Infinite Fusion's own isFusion?/
      # is_fusion checks use ">727" as a proxy for "this dex number is a
      # computed head*727+body fusion, not a real species" - true for every
      # real fusion, but also true for every one of our added mons, so they
      # were all misidentified as fusions here and got the generic DNA icon
      # instead of their own. Skip straight to the normal icon lookup for our
      # explicitly-registered species; everything else (eggs, real fusions,
      # vanilla mons) goes through the original, completely unchanged.
      alias animefusionmerge_orig_icon_filename_from_pokemon icon_filename_from_pokemon
      def icon_filename_from_pokemon(pkmn)
        if pkmn.isFusion? && !pkmn.egg? && defined?(AnimeFusionMerge) &&
           AnimeFusionMerge.added_species.include?(pkmn.species)
          # These species were renumbered into the 600000-699999 reserved
          # standalone band (is_reserved_standalone_dex?, FusionUtils.rb) -
          # their real icon assets live at Graphics/Icons/icon{dex}.png (the
          # same convention box/party icons use elsewhere, e.g.
          # 003_Pokemon_Sprites.rb/PokemonBoxIcon.rb), NOT under
          # Graphics/Pokemon/Icons/{species name}.png like the line below
          # checks. Try the real location first so these mons show their own
          # icon instead of silently falling back to the generic "000" icon.
          species_data = self.try_get(pkmn.species)
          if species_data && is_reserved_standalone_dex?(species_data.id_number)
            dex_icon = pbResolveBitmap(sprintf("Graphics/Icons/icon%03d", species_data.id_number))
            return dex_icon if dex_icon
          end
          return self.icon_filename(pkmn.species, pkmn.spriteform_head, pkmn.gender,
                                     pkmn.shiny?, pkmn.shadowPokemon?, pkmn.egg?)
        end
        return animefusionmerge_orig_icon_filename_from_pokemon(pkmn)
      end
    end
  end
end

module AnimeFusionMerge
  # load_moves/load_species below call pbCompilerEachPreppedLine, pbEachFileSection,
  # pbGetCsvRecord, csvEnumField! etc. - all real base-game helpers, but they're
  # plain instance methods of module Compiler (021_Compiler/001_Compiler.rb), not
  # global Kernel methods. Without mixing Compiler in, the very first call
  # (pbCompilerEachPreppedLine in load_moves) raised NoMethodError, which aborted
  # self.install entirely before load_species/load_encounters ever ran - species
  # and moves were silently never registered on every boot. extend-ing Compiler
  # here gives AnimeFusionMerge's singleton methods (def self.x) access to them.
  extend Compiler

  def self.added_species
    @added_species ||= []
  end

  def self.load_moves(path)
    return unless safeExists?(path)
    added = 0
    pbCompilerEachPreppedLine(path) { |line, line_no|
      line = pbGetCsvRecord(line, line_no, [0, "vnssueeuuueiss",
                                            nil, nil, nil, nil, nil, :Type, ["Physical", "Special", "Status"],
                                            nil, nil, nil, :Target, nil, nil, nil
      ])
      move_number = line[0]
      move_symbol = line[1].to_sym
      next if GameData::Move::DATA[move_number] || GameData::Move::DATA[move_symbol]
      move_hash = {
        :id_number => move_number,
        :id => move_symbol,
        :name => line[2],
        :function_code => line[3],
        :base_damage => line[4],
        :type => line[5],
        :category => line[6],
        :accuracy => line[7],
        :total_pp => line[8],
        :effect_chance => line[9],
        :target => GameData::Target.get(line[10]).id,
        :priority => line[11],
        :flags => line[12],
        :description => line[13]
      }
      GameData::Move.register(move_hash)
      # GameData::Move#name/#description (unlike Species#name) have NO fallback
      # to the raw hash value - they route straight through MessageTypes with
      # no rescue, so without this every added move shows a blank name/
      # description in battle/summary ("Bear Thief used _!"). Uses the
      # MessageTypes.set compat shim from 000_mod_manager_loader.rb.
      MessageTypes.set(MessageTypes::Moves, move_number, line[2]) if line[2]
      MessageTypes.set(MessageTypes::MoveDescriptions, move_number, line[13]) if line[13]
      added += 1
    }
    echoln("[AnimeFusionMerge] Registered #{added} moves")
  end

  #----------------------------------------------------------------------------
  # Additively registers new generic TrainerType records (PBS/trainertypes.txt
  # format) so trainer classes that don't exist in the base game can be used by
  # merged trainers. Mirrors compile_trainer_types (021_Compiler/002_Compiler
  # _CompilePBS.rb) but skips DATA.clear/MessageTypes so vanilla types survive.
  #----------------------------------------------------------------------------
  def self.load_trainertypes(path)
    return unless safeExists?(path)
    added = 0
    pbCompilerEachCommentedLine(path) { |line, line_no|
      line = pbGetCsvRecord(line, line_no, [0, "unsUSSSeUS",
                                            nil, nil, nil, nil, nil, nil, nil, {
                                              "Male" => 0, "M" => 0, "0" => 0,
                                              "Female" => 1, "F" => 1, "1" => 1,
                                              "Mixed" => 2, "X" => 2, "2" => 2, "" => 2
                                            }, nil, nil]
      )
      type_number = line[0]
      type_symbol = line[1].to_sym
      next if GameData::TrainerType::DATA[type_number] || GameData::TrainerType::DATA[type_symbol]
      type_hash = {
        :id_number => type_number,
        :id => type_symbol,
        :name => line[2],
        :base_money => line[3],
        :battle_BGM => line[4],
        :victory_ME => line[5],
        :intro_ME => line[6],
        :gender => line[7],
        :skill_level => line[8],
        :skill_code => line[9]
      }
      GameData::TrainerType.register(type_hash)
      added += 1
    }
    echoln("[AnimeFusionMerge] Registered #{added} trainer types")
  end

  #----------------------------------------------------------------------------
  # Additively registers the custom DBZ/Animon abilities (abilities.txt) that
  # pokemon.txt's Abilities/HiddenAbility columns reference by symbol. Must
  # run before load_species - species registration doesn't validate ability
  # symbols itself, but battle/overworld code and AbilityHandlers.rb (loaded
  # separately by 998_ModManager, after Bootstrap.rb) both look them up by ID.
  #----------------------------------------------------------------------------
  def self.load_abilities(path)
    return unless safeExists?(path)
    added = 0
    pbCompilerEachPreppedLine(path) { |line, line_no|
      line = pbGetCsvRecord(line, line_no, [0, "vnss"])
      ability_number = line[0]
      ability_symbol = line[1].to_sym
      next if GameData::Ability::DATA[ability_number] || GameData::Ability::DATA[ability_symbol]
      GameData::Ability.register({
        :id => ability_symbol,
        :id_number => ability_number,
        :name => line[2],
        :description => line[3]
      })
      added += 1
    }
    echoln("[AnimeFusionMerge] Registered #{added} abilities")
  end

  def self.load_species(path)
    return unless safeExists?(path)
    added_symbols = []
    File.open(path, "rb") { |f|
      FileLineData.file = path
      schema = GameData::Species.schema
      pbEachFileSection(f) { |contents, species_number|
        next if GameData::Species::DATA[species_number]
        next if GameData::Species::DATA[contents["InternalName"].to_sym]
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
            value = (value * 10).round
            contents[key] = value
          when "Moves"
            move_array = []
            for i in 0...value.length / 2
              move_array.push([value[i * 2], value[i * 2 + 1], i])
            end
            # was "a[0] <=> b[1]" - typo vs. the base game's own identical block
            # (021_Compiler/002_Compiler_CompilePBS.rb) comparing b[0]; comparing
            # a level against a move symbol raised "comparison ... failed".
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
        species_symbol = contents["InternalName"].to_sym
        species_hash = {
          :id => species_symbol,
          :id_number => species_number,
          :name => contents["Name"],
          :form_name => contents["FormName"],
          :category => contents["Kind"],
          :pokedex_entry => contents["Pokedex"],
          :type1 => contents["Type1"],
          :type2 => contents["Type2"],
          :base_stats => contents["BaseStats"],
          :evs => contents["EffortPoints"],
          :base_exp => contents["BaseEXP"],
          :growth_rate => contents["GrowthRate"],
          :gender_ratio => contents["GenderRate"],
          :catch_rate => contents["Rareness"],
          :happiness => contents["Happiness"],
          :moves => contents["Moves"],
          :tutor_moves => contents["TutorMoves"],
          :egg_moves => contents["EggMoves"],
          :abilities => contents["Abilities"],
          :hidden_abilities => contents["HiddenAbility"],
          :wild_item_common => contents["WildItemCommon"],
          :wild_item_uncommon => contents["WildItemUncommon"],
          :wild_item_rare => contents["WildItemRare"],
          :egg_groups => contents["Compatibility"],
          :hatch_steps => contents["StepsToHatch"],
          :incense => contents["Incense"],
          :evolutions => contents["Evolutions"],
          :height => contents["Height"],
          :weight => contents["Weight"],
          :color => contents["Color"],
          :shape => GameData::BodyShape.get(contents["Shape"]).id,
          :habitat => contents["Habitat"],
          :generation => contents["Generation"],
          :back_sprite_x => contents["BattlerPlayerX"],
          :back_sprite_y => contents["BattlerPlayerY"],
          :front_sprite_x => contents["BattlerEnemyX"],
          :front_sprite_y => contents["BattlerEnemyY"],
          :front_sprite_altitude => contents["BattlerAltitude"],
          :shadow_x => contents["BattlerShadowX"],
          :shadow_size => contents["BattlerShadowSize"]
        }
        GameData::Species.register(species_hash)
        added_symbols.push(species_symbol)
      }
    }
    # Resolve evolution targets/params now that every species (vanilla + ours) is loaded
    added_symbols.each do |sym|
      species = GameData::Species.get(sym)
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
      end
    end
    # Add reciprocal prevolution entries, scoped to our own species only so
    # vanilla species (which already got theirs at boot) aren't touched twice
    all_evos = {}
    added_symbols.each do |sym|
      species = GameData::Species.get(sym)
      species.evolutions.each do |evo|
        all_evos[evo[0]] = [species.species, evo[1], evo[2], true] if !all_evos[evo[0]]
      end
    end
    added_symbols.each do |sym|
      species = GameData::Species.get(sym)
      next if species.evolutions.any? { |evo| evo[3] }
      species.evolutions.push(all_evos[species.species].clone) if all_evos[species.species]
    end
    @added_species = (@added_species || []) + added_symbols
    echoln("[AnimeFusionMerge] Registered #{added_symbols.length} species")
  end

  #----------------------------------------------------------------------------
  # Additively merges wild encounter slots into whatever GameData::Encounter
  # data already exists for a map, instead of replacing it (no DATA.clear -
  # matches the additive-wild-encounters rule). File is our own new-format
  # PBS text (percent chance, species, minLv, maxLv per line) already remapped
  # onto this game's own map IDs.
  #----------------------------------------------------------------------------
  def self.load_encounters(path)
    return unless safeExists?(path)
    lines = File.readlines(path, chomp: true)
    current_map = nil
    current_type = nil
    added_maps = 0
    added_slots = 0
    lines.each do |line|
      line = line.strip
      next if line.empty?
      if line =~ /^\[(\d+)\]$/
        current_map = $1.to_i
        current_type = nil
        if !GameData::Encounter.exists?(current_map)
          GameData::Encounter.register({
            :id => sprintf("%s_0", current_map).to_sym,
            :map => current_map,
            :version => 0,
            :step_chances => {},
            :types => {}
          })
          added_maps += 1
        end
      elsif line =~ /^([A-Za-z0-9_]+)$/ && GameData::EncounterType.exists?($1.to_sym)
        current_type = $1.to_sym
      elsif current_map && current_type && line =~ /^(\d+)\s*,\s*([A-Za-z0-9_]+)\s*,\s*(\d+)\s*,\s*(\d+)$/
        enc = GameData::Encounter.get(current_map)
        enc.types[current_type] ||= []
        enc.types[current_type] << [$1.to_i, $2.to_sym, $3.to_i, $4.to_i]
        added_slots += 1
      end
    end
    echoln("[AnimeFusionMerge] Merged wild encounters into #{added_maps} new + existing maps (#{added_slots} slots)")
  end

  #----------------------------------------------------------------------------
  # Registers wholly new/separate GameData::Trainer records from our own
  # new-format PBS text (trainers.txt), sourced from DBZ Infinite Fusion and
  # diffed/regenerated by an offline script. Every entry in this file is a
  # brand-new trainer identity - none of IF1's own trainers.txt entries are
  # ever touched, so (unlike load_encounters) there is no merge-into-existing
  # logic here, only straightforward registration with a defensive collision
  # check (should never trigger - alt entries use version = dbz_version + 900,
  # which was verified offline to never collide with IF1's own versions).
  #----------------------------------------------------------------------------
  GENDER_TOKEN_MAP = { "M" => 0, "m" => 0, "Male" => 0, "male" => 0, "0" => 0,
                       "F" => 1, "f" => 1, "Female" => 1, "female" => 1, "1" => 1 }

  def self.load_trainers(path, id_number_base: 9_000_000)
    return unless safeExists?(path)
    lines = File.readlines(path, chomp: true)
    trainers = []
    current = nil
    current_pkmn = nil
    lines.each do |raw|
      line = raw.sub(/\s*#.*$/, "").strip
      next if line.empty?
      if line =~ /^\[\s*(.+?)\s*\]$/
        trainers << current if current
        parts = $1.split(",").map { |p| p.strip }
        current = {
          :trainer_type => parts[0].to_sym,
          :name => parts[1],
          :version => (parts[2] && parts[2] != "") ? parts[2].to_i : 0,
          :pokemon => []
        }
        current_pkmn = nil
        next
      end
      next unless current
      next unless line =~ /^(\w+)\s*=\s*(.*)$/
      prop = $1
      val = $2.strip
      if prop == "Pokemon"
        fields = val.split(",").map { |p| p.strip }
        current_pkmn = { :species => fields[0].to_sym, :level => fields[1].to_i }
        current[:pokemon].push(current_pkmn)
        next
      end
      next unless current_pkmn
      case prop
      when "Item"
        current_pkmn[:item] = val.to_sym
      when "Moves"
        current_pkmn[:moves] = val.split(",").map { |m| m.strip.to_sym }
      when "AbilityIndex"
        current_pkmn[:ability_index] = val.to_i
      when "Ability"
        if val =~ /^\d+$/
          current_pkmn[:ability_index] = val.to_i
        else
          current_pkmn[:ability] = val.to_sym
        end
      when "Gender"
        current_pkmn[:gender] = GENDER_TOKEN_MAP[val] if GENDER_TOKEN_MAP.key?(val)
      when "Form"
        current_pkmn[:form] = val.to_i
      when "Shiny"
        current_pkmn[:shininess] = !!(val =~ /^(true|1)$/i)
      when "Nature"
        current_pkmn[:nature] = val.to_sym
      when "IV", "EV"
        v = val.to_i
        stat_hash = {}
        GameData::Stat.each_main { |s| stat_hash[s.id] = v }
        current_pkmn[(prop == "IV") ? :iv : :ev] = stat_hash
      when "Happiness"
        current_pkmn[:happiness] = val.to_i
      when "Name"
        current_pkmn[:name] = val.sub(/\A"/, "").sub(/"\z/, "")
      when "Shadow"
        current_pkmn[:shadowness] = !!(val =~ /^(true|1)$/i)
      when "Ball"
        current_pkmn[:poke_ball] = val.to_sym
      end
    end
    trainers << current if current

    added_trainers = 0
    skipped_collisions = 0
    trainers.each_with_index do |t, i|
      if GameData::Trainer.exists?(t[:trainer_type], t[:name], t[:version])
        skipped_collisions += 1
        echoln("[AnimeFusionMerge] Skipped trainer collision (already exists): #{t[:trainer_type]} / #{t[:name]} / #{t[:version]}")
        next
      end
      t[:id] = [t[:trainer_type], t[:name], t[:version]]
      t[:id_number] = id_number_base + i
      GameData::Trainer.register(t)
      added_trainers += 1
    end
    echoln("[AnimeFusionMerge] Registered #{added_trainers} new trainers (#{skipped_collisions} skipped due to key collision)")
  end

  def self.install
    load_moves(File.join(__dir__, "moves.txt"))
    load_abilities(File.join(__dir__, "abilities.txt"))
    load_species(File.join(__dir__, "pokemon.txt"))
    load_encounters(File.join(__dir__, "encounters.txt"))
    load_trainertypes(File.join(__dir__, "trainertypes.txt"))
    load_trainers(File.join(__dir__, "trainers.txt"))
    # Animon trainers/classes - see build_animon_trainers.py (tools/gba_pipeline).
    # Separate id_number_base keeps these from colliding with the DBZ import
    # above, since each load_trainers call numbers its own batch from 0.
    load_trainertypes(File.join(__dir__, "animon_trainertypes.txt"))
    load_trainers(File.join(__dir__, "animon_trainers.txt"), id_number_base: 9_100_000)
  end

  #----------------------------------------------------------------------------
  # GameData.load_all runs twice during a normal boot (999_Main.rb, then again
  # from StartGame.rb once a save is actually loaded) and replaces each
  # GameData::*::DATA hash wholesale each time - see GhostItem_Splicers/main.rb
  # for the same issue with Item data. Our first install() (below, at file-load
  # time) lands between those two calls, so the second load_all was silently
  # wiping every map we added to GameData::Encounter (they don't exist in the
  # base PBS/encounters.txt, so the rebuilt DATA hash simply doesn't have them)
  # before the player could ever reach one. Re-running load_encounters after
  # every load_all keeps our added wild encounters alive. Scoped to encounters
  # only (not the whole install) since that's the part load_all actually
  # clobbers for us and re-adding species/moves/trainers repeatedly is
  # unnecessary risk for no benefit.
  #----------------------------------------------------------------------------
  def self.reload_encounters_after_game_data_load
    load_encounters(File.join(__dir__, "encounters.txt"))
  end
end

AnimeFusionMerge.install

module GameData
  class << self
    alias animefusionmerge_original_load_all load_all
    def load_all
      animefusionmerge_original_load_all
      AnimeFusionMerge.reload_encounters_after_game_data_load
      echoln "[AnimeFusionMerge] Re-merged wild encounters after GameData.load_all"
    end
  end
end
