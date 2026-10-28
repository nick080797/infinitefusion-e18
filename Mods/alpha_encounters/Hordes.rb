# Swarm
Events.onWildBattleOverride += proc { |_sender,e|
  species = e[0]
  level   = e[1]
  handled = e[2]
  next if handled[0]!=nil
  next if rand(100) > 1
  handled[0] = pb1v3WildBattle(species, (level * 0.8).clamp(1, 100).round, species, level, species, (level * 0.8).clamp(1, 100).round)
}

