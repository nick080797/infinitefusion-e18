#===============================================================================
# Mod: Trainer Rank System
# Player-side meta-progression. Points are earned from catching, fusing, and
# winning trainer battles. Rank requires BOTH a badge-count floor AND enough
# accumulated points (per player's own spec). Higher ranks unlock:
#   - Economy:      a higher personal money cap, bigger trainer-battle prize $
#   - Convenience:  automatic full-party heal right after winning a trainer battle
#   - Cosmetic:     a rank title shown on the Trainer Card
#
# Every hook below is alias-chained (never replaces existing logic outright,
# except Player#money= which is a one-line method fully reproduced with only
# the cap constant swapped for a dynamic one) and wrapped in rescue blocks so
# a problem here can never break catching, fusing, battling, or saving.
#===============================================================================
module TrainerRank
  # --- Tunables -----------------------------------------------------------
  POINTS_PER_CATCH   = 1
  POINTS_PER_FUSION  = 3
  POINTS_PER_WIN     = 5

  # badges/points are BOTH required to reach a rank. Ranks must stay sorted
  # ascending by requirement; RANKS[0] must be reachable at badges:0, points:0.
  RANKS = [
    { name: "Rookie",      badges: 0, points: 0,   money_cap: 999_999,   prize_mult: 1.0,  auto_heal: false },
    { name: "Trainer",     badges: 2, points: 25,  money_cap: 1_500_000, prize_mult: 1.1,  auto_heal: false },
    { name: "Ace Trainer", badges: 4, points: 60,  money_cap: 2_500_000, prize_mult: 1.2,  auto_heal: true  },
    { name: "Expert",      badges: 6, points: 120, money_cap: 4_000_000, prize_mult: 1.3,  auto_heal: true  },
    { name: "Champion",    badges: 8, points: 200, money_cap: 6_000_000, prize_mult: 1.4,  auto_heal: true  },
    { name: "Legend",      badges: 8, points: 350, money_cap: 9_999_999, prize_mult: 1.5,  auto_heal: true  }
  ].freeze

  # --- Persistent state (saved inside $PokemonGlobal, same object the game
  #     already serializes, so it survives save/load with no new save slot) ---
  def self.default_state
    { points: 0 }
  end

  def self.state
    return default_state unless $PokemonGlobal
    cur = $PokemonGlobal.trainer_rank_state
    $PokemonGlobal.trainer_rank_state = default_state unless cur.is_a?(Hash)
    default_state.each_pair do |k, v|
      $PokemonGlobal.trainer_rank_state[k] = v unless $PokemonGlobal.trainer_rank_state.key?(k)
    end
    $PokemonGlobal.trainer_rank_state
  end

  def self.current_badges
    return 0 unless $Trainer && $Trainer.respond_to?(:badge_count)
    $Trainer.badge_count
  rescue
    0
  end

  def self.rank_index_for(badges, points)
    best = 0
    RANKS.each_with_index do |r, i|
      best = i if badges >= r[:badges] && points >= r[:points]
    end
    best
  end

  def self.current_rank_index
    rank_index_for(current_badges, state[:points])
  end

  def self.current_rank
    RANKS[current_rank_index]
  end

  def self.current_money_cap
    current_rank[:money_cap]
  end

  def self.prize_multiplier
    current_rank[:prize_mult]
  end

  def self.auto_heal_unlocked?
    current_rank[:auto_heal] == true
  end

  # Adds points, and announces a rank-up if the new total (with the player's
  # CURRENT badge count) crosses into a higher rank. `announce` is a Symbol
  # naming the message method to call. If `context` is given (e.g. the active
  # battle, for :pbDisplayPaused), it's called on that object; otherwise the
  # global top-level `pbMessage` is called directly. Pass announce: nil to
  # skip announcing entirely.
  def self.add_points(amount, announce = :pbMessage, context = nil)
    return if amount.nil? || amount <= 0
    st = state
    before_idx = rank_index_for(current_badges, st[:points])
    st[:points] += amount
    after_idx = rank_index_for(current_badges, st[:points])
    if after_idx > before_idx && announce
      msg = _INTL("Your training has paid off! You are now ranked {1}!", RANKS[after_idx][:name])
      context ? context.send(announce, msg) : pbMessage(msg)
    end
  rescue => e
    echoln("[TrainerRankSystem] add_points error: #{e.message}") if $DEBUG
  end

  def self.maybe_auto_heal
    return unless auto_heal_unlocked?
    $Trainer.heal_party if $Trainer && $Trainer.respond_to?(:heal_party)
  rescue => e
    echoln("[TrainerRankSystem] auto_heal error: #{e.message}") if $DEBUG
  end
end

class PokemonGlobalMetadata
  attr_accessor :trainer_rank_state
end

#===============================================================================
# Hook 1: wild-catch points (fires once per successful catch, mid-battle)
#===============================================================================
module BallHandlers
  class << self
    alias trainerranksystem_orig_onCatch onCatch unless method_defined?(:trainerranksystem_orig_onCatch)

    def onCatch(ball, battle, pkmn)
      trainerranksystem_orig_onCatch(ball, battle, pkmn)
      begin
        TrainerRank.add_points(TrainerRank::POINTS_PER_CATCH, :pbDisplayPaused, battle)
      rescue => e
        echoln("[TrainerRankSystem] onCatch hook error: #{e.message}") if $DEBUG
      end
    end
  end
end

#===============================================================================
# Hook 2: fusion points (fires once per successful fusion, outside battle)
#===============================================================================
alias trainerranksystem_orig_pbFuse pbFuse unless defined?(trainerranksystem_orig_pbFuse)
def pbFuse(pokemon_body, pokemon_head, splicer_item, fusion_pif_sprite = nil)
  result = trainerranksystem_orig_pbFuse(pokemon_body, pokemon_head, splicer_item, fusion_pif_sprite)
  begin
    TrainerRank.add_points(TrainerRank::POINTS_PER_FUSION, :pbMessage) if result
  rescue => e
    echoln("[TrainerRankSystem] pbFuse hook error: #{e.message}") if $DEBUG
  end
  result
end

#===============================================================================
# Hook 3/4: trainer-battle win points + prize-money multiplier + auto-heal
#===============================================================================
class PokeBattle_Battle
  alias trainerranksystem_orig_calculateMoneyGain calculateMoneyGain unless method_defined?(:trainerranksystem_orig_calculateMoneyGain)
  def calculateMoneyGain
    base = trainerranksystem_orig_calculateMoneyGain
    return base if !base.is_a?(Numeric) || base <= 0
    begin
      (base * TrainerRank.prize_multiplier).round
    rescue
      base
    end
  end

  alias trainerranksystem_orig_pbGainMoney pbGainMoney unless method_defined?(:trainerranksystem_orig_pbGainMoney)
  def pbGainMoney(cosmetics_money = 0)
    trainerranksystem_orig_pbGainMoney(cosmetics_money)
    begin
      if trainerBattle? && @internalBattle && @moneyGain
        TrainerRank.add_points(TrainerRank::POINTS_PER_WIN, :pbDisplayPaused, self)
        TrainerRank.maybe_auto_heal
      end
    rescue => e
      echoln("[TrainerRankSystem] pbGainMoney hook error: #{e.message}") if $DEBUG
    end
  end
end

#===============================================================================
# Hook 5: dynamic money cap (full one-line method reproduced; only the cap
# constant is swapped for TrainerRank.current_money_cap)
#===============================================================================
class Player
  def money=(value)
    validate value => Integer
    cap = Settings::MAX_MONEY
    begin
      cap = TrainerRank.current_money_cap
    rescue
      cap = Settings::MAX_MONEY
    end
    @money = value.clamp(0, cap)
  end
end

#===============================================================================
# Hook 6: rank title on the Trainer Card (cosmetic)
#===============================================================================
class PokemonTrainerCard_Scene
  alias trainerranksystem_orig_pbDrawTrainerCardFront pbDrawTrainerCardFront unless method_defined?(:trainerranksystem_orig_pbDrawTrainerCardFront)
  def pbDrawTrainerCardFront
    trainerranksystem_orig_pbDrawTrainerCardFront
    begin
      overlay = @sprites["overlay"]
      return unless overlay
      rank_name = TrainerRank.current_rank[:name]
      base = Color.new(72, 72, 72)
      shadow = Color.new(160, 160, 160)
      pbDrawTextPositions(overlay.bitmap, [[_INTL("Rank: {1}", rank_name), 34, 28, 0, base, shadow]])
    rescue => e
      echoln("[TrainerRankSystem] Trainer Card hook error: #{e.message}") if $DEBUG
    end
  end
end
