class PokemonTemp
  attr_accessor :battleRewards

  alias_method :old_initialize, :initialize

  def initialize
    old_initialize
    @battleRewards = []
  end
end



class PokeBattle_AI


def pbChooseMoves(idxBattler)
  user        = @battle.battlers[idxBattler]
  wildBattler = (@battle.wildBattle? && @battle.opposes?(idxBattler))
  skill       = 0
  if user.alpha?
    skill = 48
  end
  if !wildBattler
    skill     = 100#@battle.pbGetOwnerFromBattlerIndex(user.index).skill_level || 0
  end

  # Get scores and targets for each move
  # NOTE: A move is only added to the choices array if it has a non-zero
  #       score.
  choices     = []
  if !@battle.wildBattle? or user.alpha?
    echo("\n\nDamage calculations for: "+user.name+"\n")
    echo("------------------------------------------")
  end
  user.eachMoveWithIndex do |_m, i|
    next if !@battle.pbCanChooseMove?(idxBattler, i, false)
    if wildBattler and !user.alpha?
      pbRegisterMoveWild(user, i, choices)
    else
      pbRegisterMoveTrainer(user, i, choices, skill)
    end
  end

  if !@battle.wildBattle? or user.alpha?
    echo("\nChoices and scores:\n") #for: "+user.name+"\n")
    echo("------------------------\n")#----------------\n")
  end
  # Figure out useful information about the choices
  totalScore = 0
  maxScore   = 0
  choices.each do |c|
    totalScore += c[1]
    if !@battle.wildBattle? or user.alpha?
      echo(user.moves[c[0]].name+": "+c[1].to_s+"\n")
    end
    maxScore = c[1] if maxScore < c[1]
  end
  echo("\n")

  item, idxTarget = pbEnemyItemToUse(idxBattler)
  if item
    if item[0]
      # Determine target of item (always the Pokémon choosing the action)
      useType = GameData::Item.get(item[0]).battle_use
      if [1, 2, 3, 6, 7, 8].include?(useType)   # Use on Pokémon
        idxTarget = @battle.battlers[idxTarget].pokemonIndex   # Party Pokémon
      end
      party = @battle.pbParty(idxBattler)
      if user.pokemonIndex == 0 && party.length>1
        item[1] *= 0.5
        echo(item[0].name+": "+item[1].to_s+" discourage item usage on lead.\n")
      end
      if item[1]>maxScore
        # Register use of item
        @battle.pbRegisterItem(idxBattler,item[0],idxTarget)
        PBDebug.log("[AI] #{user.pbThis} (#{user.index}) will use item #{GameData::Item.get(item[0]).name}")
        return
      end
    end
  end

  echo("\n\n")

  # if $consoleenabled
  # 	echo(choices)
  # end

  # Log the available choices
  if $INTERNAL
    logMsg = "[AI] Move choices for #{user.pbThis(true)} (#{user.index}): "
    choices.each_with_index do |c, i|
      logMsg += "#{user.moves[c[0]].name}=#{c[1]}"
      logMsg += " (target #{c[2]})" if c[2] >= 0
      logMsg += ", " if i < choices.length - 1
    end
    PBDebug.log(logMsg)
  end
  # Find any preferred moves and just choose from them
  if !wildBattler && skill >= PBTrainerAI.highSkill && maxScore > 100 or user.alpha? && skill >= PBTrainerAI.highSkill && maxScore > 100
    #stDev = pbStdDev(choices)
    #if stDev >= 40 && pbAIRandom(100) < 90
    # DemICE removing randomness of AI
    preferredMoves = []
    choices.each do |c|
      next if c[1] < 200 && c[1] < maxScore * 0.8
      #preferredMoves.push(c)
      # DemICE prefer ONLY the best move
      preferredMoves.push(c) if c[1] == maxScore   # Doubly prefer the best move
    end
    if preferredMoves.length > 0
      m = preferredMoves[pbAIRandom(preferredMoves.length)]
      PBDebug.log("[AI] #{user.pbThis} (#{user.index}) prefers #{user.moves[m[0]].name}")
      @battle.pbRegisterMove(idxBattler, m[0], false)
      @battle.pbRegisterTarget(idxBattler, m[2]) if m[2] >= 0
      return
    end
    #end
  end
  # Decide whether all choices are bad, and if so, try switching instead
  if !wildBattler && skill >= PBTrainerAI.highSkill
    badMoves = false
    if ((maxScore <= 20 && user.turnCount > 2) ||
        (maxScore <= 40 && user.turnCount > 5)) #&& pbAIRandom(100) < 80  # DemICE removing randomness
      badMoves = true
    end
    if !badMoves && totalScore < 100 && user.turnCount >= 1
      badMoves = true
      choices.each do |c|
        next if !user.moves[c[0]].damagingMove?
        badMoves = false
        break
      end
      #badMoves = false if badMoves && pbAIRandom(100) < 10 # DemICE removing randomness
    end
    if badMoves && pbEnemyShouldWithdrawEx?(idxBattler, false)
      if $INTERNAL
        echo("\nWill switch due to terrible moves.\n")
        #PBDebug.log("[AI] #{user.pbThis} (#{user.index}) will switch due to terrible moves")
      end
      return
    end
  end
  # If there are no calculated choices, pick one at random
  if choices.length == 0
    PBDebug.log("[AI] #{user.pbThis} (#{user.index}) doesn't want to use any moves; picking one at random")
    user.eachMoveWithIndex do |_m, i|
      next if !@battle.pbCanChooseMove?(idxBattler, i, false)
      choices.push([i, 100, -1])   # Move index, score, target
    end
    if choices.length == 0   # No moves are physically possible to use; use Struggle
      @battle.pbAutoChooseMove(user.index)
    end
  end
  # Randomly choose a move from the choices and register it
  randNum = pbAIRandom(totalScore)
  choices.each do |c|
    randNum -= c[1]
    next if randNum >= 0
    @battle.pbRegisterMove(idxBattler, c[0], false)
    @battle.pbRegisterTarget(idxBattler, c[2]) if c[2] >= 0
    break
  end
  # Log the result
  if @battle.choices[idxBattler][2]
    PBDebug.log("[AI] #{user.pbThis} (#{user.index}) will use #{@battle.choices[idxBattler][2].name}")
  end
end
end
