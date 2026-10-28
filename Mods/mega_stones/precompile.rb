#==============================================================================
# Mega Stones - precompile item registration
#==============================================================================
# PBS/pokemonforms.txt declares "MegaStone = MEDICHAMITE/CHIMECHOITE/
# EELEKTROSSITE" for Medicham/Chimecho/Eelektross's mega forms. The PBS
# compiler (Compiler.compile_all, called from Data/Scripts/999_Main before
# Mods/*.rb ever loads -- confirmed by reading 999_Main.rb directly) checks
# that key against GameData::Item while compiling pokemonforms.txt, so those
# three items must exist in GameData::Item at that moment or it raises
# "Undefined value ... in GameData::Item", aborting the rest of that compile
# pass (confirmed via PBS/_recompile_log.txt: this can leave other,
# unrelated PBS-derived cache files -- e.g. Data/english.dat -- stale/
# missing for the rest of that boot).
#
# A naive "register these 3 items before compile_all runs" fix does NOT
# work: compile_all compiles PBS/items.txt (Compiler.compile_items) BEFORE
# pokemonforms.txt, and compile_items starts with
# "GameData::Item::DATA.clear" (Data/Scripts/021_Compiler/
# 002_Compiler_CompilePBS.rb:354) -- wiping out anything registered earlier,
# including these 3 items, before pokemonforms.txt is even reached.
# (Confirmed by testing: pre-registering before compile_all still produced
# the same "Undefined value MEDICHAMITE" failure.)
#
# So instead this aliases Compiler.compile_items to re-register the 3 items
# immediately *after* the original runs (i.e. after DATA.clear + the
# PBS/items.txt parse, but still before compile_pokemon_forms validates
# them). This file is loaded early -- see the small addition in
# Data/Scripts/999_Main/999_Main.rb, right before its Compiler.compile_all
# call -- so the alias is installed before compile_all (and therefore
# compile_items) ever runs.
#
# The mod's own full script (Mods/mega_stones/Mods/050_MegaStoneSimulator.rb)
# still loads normally later (via the existing Dir["./Mods/*.rb"] pass) and
# calls MegaStoneItems.register_once!, which is idempotent and simply skips
# these three items then, since they already exist.
#
# Never touches base PBS/items.txt -- these three items live only in this
# mod, exactly like the rest of the mega_stones item roster.
module MegaStonesPrecompile
  STONES = [
    { sym: :MEDICHAMITE, name: "Medichamite",
      desc: "A mysterious stone. Have Medicham or a fusion containing it hold this to unlock its true potential!" },
    { sym: :CHIMECHOITE, name: "Chimechoite",
      desc: "A mysterious stone. Have Chimecho or a fusion containing it hold this to unlock its true potential!" },
    { sym: :EELEKTROSSITE, name: "Eelektrossite",
      desc: "A mysterious stone. Have Eelektross or a fusion containing it hold this to unlock its true potential!" }
  ]

  def self.register_stones!
    return unless defined?(GameData::Item) && GameData::Item.respond_to?(:register) &&
                  GameData::Item.respond_to?(:exists?) && GameData::Item.respond_to?(:each)

    used = {}
    begin
      GameData::Item.each do |it|
        n = (it.id_number rescue nil)
        used[n] = true if n.is_a?(Integer)
      end
    rescue
    end

    id_here = 6000
    STONES.each do |s|
      next if (GameData::Item.exists?(s[:sym]) rescue false)
      id_here += 1 while used[id_here]
      used[id_here] = true
      plural = s[:name] + "s"
      GameData::Item.register({
        :id          => s[:sym],
        :id_number   => id_here,
        :name        => s[:name],
        :name_plural => plural,
        :pocket      => 1,
        :price       => 0,
        :description => s[:desc],
        :field_use   => 0,
        :battle_use  => 0,
        :type        => 0,
        :move        => nil
      })
      if defined?(MessageTypes) && MessageTypes.respond_to?(:set)
        MessageTypes.set(MessageTypes::Items,            id_here, s[:name])
        MessageTypes.set(MessageTypes::ItemPlurals,      id_here, plural)
        MessageTypes.set(MessageTypes::ItemDescriptions, id_here, s[:desc])
      end
      id_here += 1
    end
  end
end

begin
  if defined?(Compiler) && Compiler.respond_to?(:compile_items) &&
     !Compiler.respond_to?(:__mega_stones_orig_compile_items)
    class << Compiler
      alias_method :__mega_stones_orig_compile_items, :compile_items
      def compile_items(*args)
        __mega_stones_orig_compile_items(*args)
        MegaStonesPrecompile.register_stones!
      end
    end
  end
rescue => e
  # Never let this early hook break the boot -- worst case, PBS compile
  # falls back to its original (pre-fix) behavior for these 3 items.
  begin
    File.open("PBS/_recompile_log.txt", "ab") { |f| f.write("[mega_stones precompile] #{e.class}: #{e.message}\r\n") }
  rescue
  end
end
