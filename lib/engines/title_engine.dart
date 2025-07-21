import '../models/player.dart';
import '../services/storage_service.dart';

/// Engine for managing titles and achievements
class TitleEngine {
  final StorageService _storageService;
  
  TitleEngine(this._storageService);
  
  /// Check for new title unlocks based on player progress
  Future<List<UnlockedTitle>> checkForNewTitles(Player player) async {
    List<UnlockedTitle> newTitles = [];
    List<TitleRequirement> allTitles = _getAllTitleRequirements();
    
    for (TitleRequirement requirement in allTitles) {
      if (!player.unlockedTitles.contains(requirement.title) && 
          _meetsRequirement(player, requirement)) {
        
        player.unlockedTitles.add(requirement.title);
        
        newTitles.add(UnlockedTitle(
          title: requirement.title,
          description: requirement.description,
          rarity: requirement.rarity,
          unlockedAt: DateTime.now(),
          requirement: requirement.requirementText,
        ));
      }
    }
    
    if (newTitles.isNotEmpty) {
      await _storageService.savePlayer(player);
    }
    
    return newTitles;
  }
  
  /// Set player's active title
  Future<bool> setActiveTitle(Player player, String title) async {
    if (player.unlockedTitles.contains(title)) {
      player.currentTitle = title;
      await _storageService.savePlayer(player);
      return true;
    }
    return false;
  }
  
  /// Get all available titles with unlock status
  List<TitleInfo> getAllTitlesInfo(Player player) {
    List<TitleRequirement> allTitles = _getAllTitleRequirements();
    List<TitleInfo> titleInfos = [];
    
    for (TitleRequirement requirement in allTitles) {
      bool isUnlocked = player.unlockedTitles.contains(requirement.title);
      bool isActive = player.currentTitle == requirement.title;
      
      titleInfos.add(TitleInfo(
        title: requirement.title,
        description: requirement.description,
        rarity: requirement.rarity,
        requirementText: requirement.requirementText,
        isUnlocked: isUnlocked,
        isActive: isActive,
        progress: isUnlocked ? 1.0 : _calculateProgress(player, requirement),
      ));
    }
    
    // Sort by rarity and unlock status
    titleInfos.sort((a, b) {
      if (a.isUnlocked != b.isUnlocked) {
        return a.isUnlocked ? -1 : 1;
      }
      return a.rarity.index.compareTo(b.rarity.index);
    });
    
    return titleInfos;
  }
  
  /// Get titles by rarity
  List<TitleInfo> getTitlesByRarity(Player player, TitleRarity rarity) {
    return getAllTitlesInfo(player)
        .where((title) => title.rarity == rarity)
        .toList();
  }
  
  /// Get player's title statistics
  TitleStats getTitleStats(Player player) {
    List<TitleRequirement> allTitles = _getAllTitleRequirements();
    
    int totalTitles = allTitles.length;
    int unlockedTitles = player.unlockedTitles.length;
    
    Map<TitleRarity, int> unlockedByRarity = {};
    Map<TitleRarity, int> totalByRarity = {};
    
    for (TitleRarity rarity in TitleRarity.values) {
      unlockedByRarity[rarity] = 0;
      totalByRarity[rarity] = 0;
    }
    
    for (TitleRequirement requirement in allTitles) {
      totalByRarity[requirement.rarity] = totalByRarity[requirement.rarity]! + 1;
      
      if (player.unlockedTitles.contains(requirement.title)) {
        unlockedByRarity[requirement.rarity] = unlockedByRarity[requirement.rarity]! + 1;
      }
    }
    
    return TitleStats(
      totalTitles: totalTitles,
      unlockedTitles: unlockedTitles,
      completionPercentage: (unlockedTitles / totalTitles * 100),
      unlockedByRarity: unlockedByRarity,
      totalByRarity: totalByRarity,
      currentTitle: player.currentTitle,
    );
  }
  
  /// Check if player meets a specific title requirement
  bool _meetsRequirement(Player player, TitleRequirement requirement) {
    switch (requirement.type) {
      case TitleType.level:
        return player.level >= requirement.value;
      
      case TitleType.totalReps:
        return player.totalRepsCompleted >= requirement.value;
      
      case TitleType.questStreak:
        return player.dailyQuestStreak >= requirement.value;
      
      case TitleType.statTotal:
        return player.totalStats >= requirement.value;
      
      case TitleType.singleStat:
        return _getHighestStat(player) >= requirement.value;
      
      case TitleType.experience:
        return (player.level - 1) * 100 + player.experience >= requirement.value;
      
      case TitleType.special:
        return _checkSpecialRequirement(player, requirement.specialCondition!);
    }
  }
  
  /// Calculate progress towards a title requirement (0.0 to 1.0)
  double _calculateProgress(Player player, TitleRequirement requirement) {
    switch (requirement.type) {
      case TitleType.level:
        return (player.level / requirement.value).clamp(0.0, 1.0);
      
      case TitleType.totalReps:
        return (player.totalRepsCompleted / requirement.value).clamp(0.0, 1.0);
      
      case TitleType.questStreak:
        return (player.dailyQuestStreak / requirement.value).clamp(0.0, 1.0);
      
      case TitleType.statTotal:
        return (player.totalStats / requirement.value).clamp(0.0, 1.0);
      
      case TitleType.singleStat:
        return (_getHighestStat(player) / requirement.value).clamp(0.0, 1.0);
      
      case TitleType.experience:
        int totalXp = (player.level - 1) * 100 + player.experience;
        return (totalXp / requirement.value).clamp(0.0, 1.0);
      
      case TitleType.special:
        return _checkSpecialRequirement(player, requirement.specialCondition!) ? 1.0 : 0.0;
    }
  }
  
  /// Get player's highest stat value
  int _getHighestStat(Player player) {
    return [
      player.strength,
      player.agility,
      player.vitality,
      player.intelligence,
      player.luck,
    ].reduce((a, b) => a > b ? a : b);
  }
  
  /// Check special title requirements
  bool _checkSpecialRequirement(Player player, String condition) {
    switch (condition) {
      case 'balanced_stats':
        // All stats within 5 points of each other
        int min = [player.strength, player.agility, player.vitality, player.intelligence, player.luck].reduce((a, b) => a < b ? a : b);
        int max = [player.strength, player.agility, player.vitality, player.intelligence, player.luck].reduce((a, b) => a > b ? a : b);
        return (max - min) <= 5;
      
      case 'no_debuffs':
        return player.debuffs.isEmpty;
      
      case 'strength_focus':
        return player.strength >= (player.agility + player.vitality + player.intelligence + player.luck) / 4 * 1.5;
      
      case 'agility_focus':
        return player.agility >= (player.strength + player.vitality + player.intelligence + player.luck) / 4 * 1.5;
      
      case 'vitality_focus':
        return player.vitality >= (player.strength + player.agility + player.intelligence + player.luck) / 4 * 1.5;
      
      case 'intelligence_focus':
        return player.intelligence >= (player.strength + player.agility + player.vitality + player.luck) / 4 * 1.5;
      
      case 'luck_focus':
        return player.luck >= (player.strength + player.agility + player.vitality + player.intelligence) / 4 * 1.5;
      
      default:
        return false;
    }
  }
  
  /// Get all title requirements
  List<TitleRequirement> _getAllTitleRequirements() {
    return [
      // Starter titles
      TitleRequirement('Novice', 'Just starting your journey', TitleRarity.common, TitleType.level, 1, 'Reach level 1'),
      TitleRequirement('Apprentice', 'Learning the basics', TitleRarity.common, TitleType.level, 5, 'Reach level 5'),
      TitleRequirement('Trainee', 'Getting into the routine', TitleRarity.common, TitleType.totalReps, 100, 'Complete 100 total reps'),
      
      // Progress titles
      TitleRequirement('Dedicated', 'Showing commitment', TitleRarity.common, TitleType.questStreak, 7, 'Complete daily quests for 7 days straight'),
      TitleRequirement('Warrior', 'A true fighter emerges', TitleRarity.uncommon, TitleType.level, 10, 'Reach level 10'),
      TitleRequirement('Repslayer', 'Destroyer of repetitions', TitleRarity.uncommon, TitleType.totalReps, 1000, 'Complete 1,000 total reps'),
      TitleRequirement('Consistent', 'Reliability incarnate', TitleRarity.uncommon, TitleType.questStreak, 14, 'Complete daily quests for 14 days straight'),
      
      // Advanced titles
      TitleRequirement('Elite', 'Among the best', TitleRarity.rare, TitleType.level, 25, 'Reach level 25'),
      TitleRequirement('Unstoppable', 'Nothing can stop you', TitleRarity.rare, TitleType.questStreak, 30, 'Complete daily quests for 30 days straight'),
      TitleRequirement('Rep Master', 'Master of repetitions', TitleRarity.rare, TitleType.totalReps, 5000, 'Complete 5,000 total reps'),
      TitleRequirement('Powerhouse', 'Raw power unleashed', TitleRarity.rare, TitleType.statTotal, 100, 'Reach 100 total stat points'),
      
      // Legendary titles
      TitleRequirement('Shadow Monarch', 'Ruler of shadows', TitleRarity.legendary, TitleType.level, 50, 'Reach level 50'),
      TitleRequirement('Immortal', 'Transcended mortality', TitleRarity.legendary, TitleType.questStreak, 100, 'Complete daily quests for 100 days straight'),
      TitleRequirement('Rep God', 'Divine repetition mastery', TitleRarity.legendary, TitleType.totalReps, 25000, 'Complete 25,000 total reps'),
      TitleRequirement('Apex Hunter', 'Peak of evolution', TitleRarity.legendary, TitleType.statTotal, 250, 'Reach 250 total stat points'),
      
      // Special titles
      TitleRequirement('Balanced', 'Perfect harmony', TitleRarity.rare, TitleType.special, 0, 'Keep all stats within 5 points of each other', 'balanced_stats'),
      TitleRequirement('Pure', 'Untainted by weakness', TitleRarity.uncommon, TitleType.special, 0, 'Have no active debuffs', 'no_debuffs'),
      TitleRequirement('Berserker', 'Strength above all', TitleRarity.rare, TitleType.special, 0, 'Focus heavily on strength', 'strength_focus'),
      TitleRequirement('Speedster', 'Swift as the wind', TitleRarity.rare, TitleType.special, 0, 'Focus heavily on agility', 'agility_focus'),
      TitleRequirement('Tank', 'Unbreakable endurance', TitleRarity.rare, TitleType.special, 0, 'Focus heavily on vitality', 'vitality_focus'),
      TitleRequirement('Sage', 'Wisdom incarnate', TitleRarity.rare, TitleType.special, 0, 'Focus heavily on intelligence', 'intelligence_focus'),
      TitleRequirement('Lucky', 'Fortune favors you', TitleRarity.rare, TitleType.special, 0, 'Focus heavily on luck', 'luck_focus'),
      
      // Shame titles (for failures)
      TitleRequirement('Slacker', 'Needs more motivation', TitleRarity.common, TitleType.special, 0, 'Fail multiple quests', 'multiple_failures'),
      TitleRequirement('Couch Potato', 'Too much screen time', TitleRarity.common, TitleType.special, 0, 'Excessive screen time penalties', 'screen_time_addict'),
    ];
  }
}

/// Title requirement definition
class TitleRequirement {
  final String title;
  final String description;
  final TitleRarity rarity;
  final TitleType type;
  final int value;
  final String requirementText;
  final String? specialCondition;
  
  TitleRequirement(
    this.title,
    this.description,
    this.rarity,
    this.type,
    this.value,
    this.requirementText, [
    this.specialCondition,
  ]);
}

/// Title information for display
class TitleInfo {
  final String title;
  final String description;
  final TitleRarity rarity;
  final String requirementText;
  final bool isUnlocked;
  final bool isActive;
  final double progress;
  
  TitleInfo({
    required this.title,
    required this.description,
    required this.rarity,
    required this.requirementText,
    required this.isUnlocked,
    required this.isActive,
    required this.progress,
  });
}

/// Newly unlocked title
class UnlockedTitle {
  final String title;
  final String description;
  final TitleRarity rarity;
  final DateTime unlockedAt;
  final String requirement;
  
  UnlockedTitle({
    required this.title,
    required this.description,
    required this.rarity,
    required this.unlockedAt,
    required this.requirement,
  });
}

/// Title statistics
class TitleStats {
  final int totalTitles;
  final int unlockedTitles;
  final double completionPercentage;
  final Map<TitleRarity, int> unlockedByRarity;
  final Map<TitleRarity, int> totalByRarity;
  final String currentTitle;
  
  TitleStats({
    required this.totalTitles,
    required this.unlockedTitles,
    required this.completionPercentage,
    required this.unlockedByRarity,
    required this.totalByRarity,
    required this.currentTitle,
  });
}

/// Types of title requirements
enum TitleType {
  level,
  totalReps,
  questStreak,
  statTotal,
  singleStat,
  experience,
  special,
}

/// Title rarity levels
enum TitleRarity {
  common,
  uncommon,
  rare,
  legendary,
}
