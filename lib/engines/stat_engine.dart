import '../models/player.dart';
import '../services/storage_service.dart';

/// Engine for handling player stats, XP, and leveling system
class StatEngine {
  final StorageService _storageService;
  
  StatEngine(this._storageService);
  
  /// Add experience points to player and handle level ups
  Future<LevelUpResult> addExperience(Player player, int xp) async {
    player.experience += xp;
    
    LevelUpResult result = LevelUpResult(
      levelsGained: 0,
      statPointsGained: 0,
      newLevel: player.level,
    );
    
    // Check for level ups
    while (player.experience >= player.experienceToNextLevel) {
      player.experience -= player.experienceToNextLevel;
      player.level++;
      result.levelsGained++;
      
      // Grant stat points on level up (2 points per level)
      int statPointsThisLevel = 2;
      player.statPoints += statPointsThisLevel;
      result.statPointsGained += statPointsThisLevel;
    }
    
    result.newLevel = player.level;
    
    // Save updated player data
    await _storageService.savePlayer(player);
    
    return result;
  }
  
  /// Allocate stat points to a specific stat
  Future<bool> allocateStatPoint(Player player, StatType statType, int points) async {
    if (player.statPoints < points) return false;
    
    player.statPoints -= points;
    
    switch (statType) {
      case StatType.strength:
        player.strength += points;
        break;
      case StatType.agility:
        player.agility += points;
        break;
      case StatType.vitality:
        player.vitality += points;
        break;
      case StatType.intelligence:
        player.intelligence += points;
        break;
      case StatType.luck:
        player.luck += points;
        break;
    }
    
    await _storageService.savePlayer(player);
    return true;
  }
  
  /// Get current stat value including debuffs
  int getEffectiveStat(Player player, StatType statType) {
    int baseStat = _getBaseStat(player, statType);
    String statName = statType.toString().split('.').last;
    
    // Apply debuffs
    int debuffAmount = 0;
    player.debuffs.forEach((debuffType, expirationTime) {
      if (DateTime.now().millisecondsSinceEpoch < expirationTime) {
        if (debuffType.contains(statName)) {
          debuffAmount += 1; // Each debuff reduces stat by 1
        }
      }
    });
    
    return (baseStat - debuffAmount).clamp(1, 999); // Minimum stat is 1
  }
  
  /// Get base stat value without debuffs
  int _getBaseStat(Player player, StatType statType) {
    switch (statType) {
      case StatType.strength:
        return player.strength;
      case StatType.agility:
        return player.agility;
      case StatType.vitality:
        return player.vitality;
      case StatType.intelligence:
        return player.intelligence;
      case StatType.luck:
        return player.luck;
    }
  }
  
  /// Calculate XP reward based on RPE and reps
  int calculateXpReward(int reps, double rpe, int sets) {
    // Base XP formula: reps * RPE * sets * multiplier
    double baseXp = reps * rpe * sets * 1.5;
    
    // Bonus for high effort (RPE 8+)
    if (rpe >= 8.0) {
      baseXp *= 1.2;
    }
    
    // Bonus for high volume (50+ total reps)
    int totalReps = reps * sets;
    if (totalReps >= 50) {
      baseXp *= 1.1;
    }
    
    return baseXp.round();
  }
  
  /// Calculate stat bonuses for quest completion
  Map<String, int> calculateQuestStatRewards(String questType, int difficulty) {
    Map<String, int> rewards = {};
    
    switch (questType.toLowerCase()) {
      case 'strength':
      case 'push-ups':
      case 'pull-ups':
        rewards['strength'] = difficulty;
        break;
      case 'cardio':
      case 'running':
      case 'burpees':
        rewards['agility'] = difficulty;
        rewards['vitality'] = (difficulty * 0.5).round();
        break;
      case 'endurance':
      case 'plank':
        rewards['vitality'] = difficulty;
        break;
      case 'flexibility':
      case 'stretching':
        rewards['agility'] = (difficulty * 0.5).round();
        break;
      default:
        // Balanced reward for mixed exercises
        rewards['strength'] = (difficulty * 0.3).round();
        rewards['agility'] = (difficulty * 0.3).round();
        rewards['vitality'] = (difficulty * 0.4).round();
    }
    
    return rewards;
  }
  
  /// Apply stat rewards from quest completion
  Future<void> applyStatRewards(Player player, Map<String, int> rewards) async {
    rewards.forEach((statName, points) {
      switch (statName.toLowerCase()) {
        case 'strength':
          player.strength += points;
          break;
        case 'agility':
          player.agility += points;
          break;
        case 'vitality':
          player.vitality += points;
          break;
        case 'intelligence':
          player.intelligence += points;
          break;
        case 'luck':
          player.luck += points;
          break;
      }
    });
    
    await _storageService.savePlayer(player);
  }
  
  /// Get player's power level (total effective stats)
  int calculatePowerLevel(Player player) {
    int totalStats = 0;
    for (StatType statType in StatType.values) {
      totalStats += getEffectiveStat(player, statType);
    }
    return totalStats;
  }
  
  /// Reset all stats to base values (admin function)
  Future<void> resetStats(Player player) async {
    player.strength = 10;
    player.agility = 10;
    player.vitality = 10;
    player.intelligence = 10;
    player.luck = 10;
    player.level = 1;
    player.experience = 0;
    player.statPoints = 0;
    
    await _storageService.savePlayer(player);
  }
}

/// Result of level up calculation
class LevelUpResult {
  final int levelsGained;
  final int statPointsGained;
  final int newLevel;
  
  LevelUpResult({
    required this.levelsGained,
    required this.statPointsGained,
    required this.newLevel,
  });
  
  bool get hasLeveledUp => levelsGained > 0;
}

/// Enum for different stat types
enum StatType {
  strength,
  agility,
  vitality,
  intelligence,
  luck,
}
