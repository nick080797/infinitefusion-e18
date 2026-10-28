#==============================================================================
# Digimon Trials
# Additively registers species (pokemon.txt), moves (moves.txt), and evolution
# items (items.txt) bundled in this mod folder into GameData, without touching
# the base game's PBS files or AnimeFusionMerge's. Mirrors AnimeFusionMerge's
# own Bootstrap.rb pattern (same additive-merge / no-DATA.clear approach).
#
# Scope for this v1 build (see build_digimon_trials_mod.py's own header for
# the full data-driven reasoning behind each cut):
#   - 1224 wholly new species (Digimon Trials names with no existing vanilla/
#     AnimeFusionMerge match), 299 overlap species reused as evolution
#     endpoints only (never re-registered).
#   - 484 wholly new moves; 605 overlap moves reused by symbol.
#   - 33 new items, needed only as evolution-trigger items for kept branches.
#   - 17 extra evolution branches added onto EXISTING (vanilla/AnimeFusionMerge)
#     species, letting real Pokemon (and AFM's own Digimon) branch into a new
#     Digimon Trials species (e.g. Gardevoir -> Medusamon).
#   - Evolution methods with no native Essentials equivalent (Jogress,
#     DigiXros, Special, NatureAmped/LowKey, CriticalHits, TookDamage, the
#     scroll items, FamilyOfThree/Four) are dropped per-branch -- the species
#     keeps every other stat/move/evolution, it just can't evolve down that
#     one specific path yet.
#   - Wild encounters, trainer placement, gym bosses, and battler/icon sprite
#     art are explicitly OUT OF SCOPE for this pass (see build script header:
#     Digimon Trials is Emerald/Hoenn-mapped, Infinite Fusion is FireRed/
#     Kanto-mapped, so raw map IDs don't correspond -- unlike AnimeFusionMerge's
#     FireRed-based sources).
#==============================================================================
module GameData
  class Species
    class << self
      # Same >727 fusion-detection issue AnimeFusionMerge already worked around
      # for its own added species (see AnimeFusionMerge/Bootstrap.rb) - our
      # species sit at 20000+, also above 727, so they're just as misidentified
      # as computed fusions by isFusion?. Chain onto whatever
      # icon_filename_from_pokemon currently is (AnimeFusionMerge's wrapper if
      # it loaded first, or the original base method if it didn't) so both
      # mods' added species get their own icon regardless of mod load order.
      alias digimontrials_orig_icon_filename_from_pokemon icon_filename_from_pokemon
      def icon_filename_from_pokemon(pkmn)
        if pkmn.isFusion? && !pkmn.egg? && defined?(DigimonTrials) &&
           DigimonTrials.added_species.include?(pkmn.species)
          return self.icon_filename(pkmn.species, pkmn.spriteform_head, pkmn.gender,
                                     pkmn.shiny?, pkmn.shadowPokemon?, pkmn.egg?)
        end
        return digimontrials_orig_icon_filename_from_pokemon(pkmn)
      end
    end
  end
end

module DigimonTrials
  # See AnimeFusionMerge/Bootstrap.rb for why this extend is required: the
  # pbCompilerEachPreppedLine/pbGetCsvRecord/etc. helpers used below are
  # instance methods of module Compiler, not global Kernel methods.
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
      # GameData::Move#name/#description have no fallback to the raw hash
      # value (unlike Species#name) - without this every added move shows a
      # blank name/description in battle/summary.
      MessageTypes.set(MessageTypes::Moves, move_number, line[2]) if line[2]
      MessageTypes.set(MessageTypes::MoveDescriptions, move_number, line[13]) if line[13]
      added += 1
    }
    echoln("[DigimonTrials] Registered #{added} moves")
  end

  #----------------------------------------------------------------------------
  # Additively registers the small set of new items needed by kept evolution
  # branches (data crystals etc. that pokemon.txt's Evolutions column
  # references by symbol). Must run before load_species for the same reason
  # AnimeFusionMerge's load_abilities runs before its load_species.
  #----------------------------------------------------------------------------
  def self.load_items(path)
    return unless safeExists?(path)
    added = 0
    pbCompilerEachCommentedLine(path) { |line, line_no|
      line = pbGetCsvRecord(line, line_no, [0, "vnssuusuuU"])
      item_number = line[0]
      item_symbol = line[1].to_sym
      next if GameData::Item::DATA[item_number] || GameData::Item::DATA[item_symbol]
      GameData::Item.register({
        :id_number => item_number,
        :id => item_symbol,
        :name => line[2],
        :name_plural => line[3],
        :pocket => line[4],
        :price => line[5],
        :description => line[6],
        :field_use => line[7],
        :battle_use => line[8],
        :type => line[9]
      })
      MessageTypes.set(MessageTypes::Items, item_number, line[2]) if line[2]
      MessageTypes.set(MessageTypes::ItemPlurals, item_number, line[3]) if line[3]
      MessageTypes.set(MessageTypes::ItemDescriptions, item_number, line[6]) if line[6]
      added += 1
    }
    echoln("[DigimonTrials] Registered #{added} items")
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
          # Body shape wasn't extracted from the ROM (documented gap) - unlike
          # AnimeFusionMerge's own pokemon.txt (which always sets Shape),
          # ours never does, and GameData::BodyShape.get(nil) raises
          # ArgumentError rather than returning a default. Confirmed via a
          # real boot test (ArgumentError at 004_Validation.rb:29, "Expected
          # nil to be one of [Symbol, GameData::BodyShape, String, Integer]")
          # which aborted load_species before a single species registered.
          :shape => GameData::BodyShape.get(contents["Shape"] || :Head).id,
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
    # Resolve evolution targets/params now that every species (vanilla + AFM +
    # ours) is loaded.
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
    # Reciprocal prevolution entries, scoped to our own species only (mirrors
    # AnimeFusionMerge's identical pass) so vanilla/AFM species aren't touched
    # here - those are handled separately below via extra_evolutions.txt.
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
    echoln("[DigimonTrials] Registered #{added_symbols.length} species")
  end

  #----------------------------------------------------------------------------
  # Pushes the ~17 evolution branches whose SOURCE is an already-existing
  # species (vanilla or AnimeFusionMerge) and whose TARGET is one of our new
  # species - e.g. Gardevoir -> Medusamon, Agumon -> Monochromon. These can't
  # go through load_species (that only touches species this mod itself
  # registers), and can't be added by editing vanilla's/AFM's own pokemon.txt
  # (never touched), so they're appended directly onto the already-loaded
  # GameData::Species record. Skips gracefully if a name doesn't resolve
  # (e.g. running with AnimeFusionMerge disabled removes some sources).
  #----------------------------------------------------------------------------
  def self.load_extra_evolutions(path)
    return unless safeExists?(path)
    added = 0
    File.readlines(path, chomp: true).each do |line|
      line = line.strip
      next if line.empty?
      parts = line.split(",").map { |p| p.strip }
      src_sym, method_sym, param_str, tgt_sym = parts[0].to_sym, parts[1].to_sym, parts[2], parts[3].to_sym
      next unless GameData::Species.exists?(src_sym)
      next unless GameData::Species.exists?(tgt_sym)
      next unless GameData::Evolution.exists?(method_sym)
      species = GameData::Species.get(src_sym)
      next if species.evolutions.any? { |evo| evo[0] == tgt_sym && evo[1] == method_sym }
      param_type = GameData::Evolution.get(method_sym).parameter
      param = if param_type.nil? || param_str.nil? || param_str.empty?
                nil
              elsif param_type == Integer
                param_str.to_i
              else
                param_str.to_sym
              end
      species.evolutions.push([tgt_sym, method_sym, param, false])
      added += 1
    end
    echoln("[DigimonTrials] Added #{added} extra evolution branches onto existing species")
  end

  def self.install
    load_moves(File.join(__dir__, "moves.txt"))
    load_items(File.join(__dir__, "items.txt"))
    load_species(File.join(__dir__, "pokemon.txt"))
    load_extra_evolutions(File.join(__dir__, "extra_evolutions.txt"))
  end
end

DigimonTrials.install
