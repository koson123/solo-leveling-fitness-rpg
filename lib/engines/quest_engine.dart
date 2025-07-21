import 'dart:math';
import '../models/player.dart';
import '../models/quest.dart';
import '../services/storage_service.dart';

/// Engine for generating and managing daily and urgent quests
class QuestEngine {
  final StorageService _storageService;
  final Random _random = Random();
  
  QuestEngine(this._storageService);
  
  /// Generate daily quests for the player (3-5 quests)
  Future<List<Quest>> generateDailyQuests(Player player) async {
    List<Quest> quests = [];
    int questCount = 3 + _random.nextInt(3); // 3-5 quests
    
    // Available exercise types for daily quests
    List<QuestTemplate> templates = _getDailyQuestTemplates();
    
    for (int i = 0; i < questCount; i++) {
      QuestTemplate template = templates[_random.nextInt(templates.length)];
      
      // Scale difficulty based on player level
      int scaledReps = _scaleRepsForLevel(template.baseReps, player.level);
      int scaledTime = _scaleTimeForLevel(template.baseTime, player.level);
      int scaledXp = _scaleXpForLevel(template.baseXp, player.level);
      
      Quest quest = Quest(
        id: 'daily_${DateTime.now().millisecondsSinceEpoch}_$i',
        name: template.name,
        description: template.description,
        type: QuestType.daily,
        targetReps: scaledReps,
        targetTime: scaledTime,
        xpReward: scaledXp,
        statRewards: template.statRewards,
      );
      
      quests.add(quest);
    }
    
    await _storageService.saveDailyQuests(quests);
    return quests;
  }
  
  /// Generate an urgent quest with time limit
  Future<Quest?> generateUrgentQuest(Player player) async {
    // Check if player already has urgent quests
    List<Quest> existingUrgent = await _storageService.loadUrgentQuests();
    existingUrgent.removeWhere((q) => q.isExpired);
    
    // Limit to 2 urgent quests max
    if (existingUrgent.length >= 2) return null;
    
    // Random chance for urgent quest (20% per check)
    if (_random.nextDouble() > 0.2) return null;
    
    List<QuestTemplate> templates = _getUrgentQuestTemplates();
    QuestTemplate template = templates[_random.nextInt(templates.length)];
    
    // Urgent quests are harder but give better rewards
    int scaledReps = _scaleRepsForLevel(template.baseReps, player.level, 1.5);
    int scaledTime = _scaleTimeForLevel(template.baseTime, player.level, 1.2);
    int scaledXp = _scaleXpForLevel(template.baseXp, player.level, 2.0);
    
    // Urgent quests expire in 2-6 hours
    DateTime expiration = DateTime.now().add(
      Duration(hours: 2 + _random.nextInt(5))
    );
    
    Quest urgentQuest = Quest(
      id: 'urgent_${DateTime.now().millisecondsSinceEpoch}',
      name: '⚡ ${template.name}',
      description: '${template.description}\n⚠️ LIMITED TIME QUEST!',
      type: QuestType.urgent,
      targetReps: scaledReps,
      targetTime: scaledTime,
      xpReward: scaledXp,
      statRewards: _enhanceStatRewards(template.statRewards),
      expiresAt: expiration,
    );
    
    existingUrgent.add(urgentQuest);
    await _storageService.saveUrgentQuests(existingUrgent);
    
    return urgentQuest;
  }
  
  /// Update quest progress
  Future<bool> updateQuestProgress(String questId, int progress) async {
    // Check daily quests
    List<Quest> dailyQuests = await _storageService.loadDailyQuests();
    for (Quest quest in dailyQuests) {
      if (quest.id == questId) {
        quest.currentProgress += progress;
        if (quest.canComplete && !quest.isCompleted) {
          quest.isCompleted = true;
        }
        await _storageService.saveDailyQuests(dailyQuests);
        return true;
      }
    }
    
    // Check urgent quests
    List<Quest> urgentQuests = await _storageService.loadUrgentQuests();
    for (Quest quest in urgentQuests) {
      if (quest.id == questId) {
        quest.currentProgress += progress;
        if (quest.canComplete && !quest.isCompleted) {
          quest.isCompleted = true;
        }
        await _storageService.saveUrgentQuests(urgentQuests);
        return true;
      }
    }
    
    return false;
  }
  
  /// Complete a quest and return rewards
  Future<QuestReward?> completeQuest(String questId, Player player) async {
    Quest? quest = await _findQuestById(questId);
    if (quest == null || quest.isCompleted || !quest.canComplete) {
      return null;
    }
    
    quest.isCompleted = true;
    
    // Create reward
    QuestReward reward = QuestReward(
      xpGained: quest.xpReward,
      statRewards: Map.from(quest.statRewards),
      questName: quest.name,
      questType: quest.type,
    );
    
    // Update quest streaks
    if (quest.type == QuestType.daily) {
      player.dailyQuestStreak++;
      await _storageService.saveDailyQuests(await _storageService.loadDailyQuests());
    } else {
      await _storageService.saveUrgentQuests(await _storageService.loadUrgentQuests());
    }
    
    return reward;
  }
  
  /// Check for failed quests and apply penalties
  Future<List<QuestPenalty>> checkFailedQuests(Player player) async {
    List<QuestPenalty> penalties = [];
    DateTime now = DateTime.now();
    
    // Check daily quests (fail at midnight)
    List<Quest> dailyQuests = await _storageService.loadDailyQuests();
    DateTime lastReset = await _storageService.loadLastDailyQuestReset() ?? 
                        now.subtract(Duration(days: 1));
    
    if (_shouldResetDailyQuests(lastReset, now)) {
      for (Quest quest in dailyQuests) {
        if (!quest.isCompleted) {
          penalties.add(QuestPenalty(
            questName: quest.name,
            penaltyType: PenaltyType.statDebuff,
            duration: Duration(hours: 24),
          ));
          player.dailyQuestStreak = 0; // Reset streak
        }
      }
    }
    
    // Check urgent quests (fail when expired)
    List<Quest> urgentQuests = await _storageService.loadUrgentQuests();
    urgentQuests.removeWhere((quest) {
      if (quest.isExpired && !quest.isCompleted) {
        penalties.add(QuestPenalty(
          questName: quest.name,
          penaltyType: PenaltyType.statDebuff,
          duration: Duration(hours: 48), // Longer penalty for urgent quests
        ));
        return true; // Remove expired quest
      }
      return false;
    });
    
    await _storageService.saveUrgentQuests(urgentQuests);
    
    return penalties;
  }
  
  /// Reset daily quests if needed
  Future<bool> resetDailyQuestsIfNeeded(Player player) async {
    DateTime? lastReset = await _storageService.loadLastDailyQuestReset();
    DateTime now = DateTime.now();
    
    if (lastReset == null || _shouldResetDailyQuests(lastReset, now)) {
      await generateDailyQuests(player);
      await _storageService.saveLastDailyQuestReset(now);
      return true;
    }
    
    return false;
  }
  
  /// Find quest by ID across all quest types
  Future<Quest?> _findQuestById(String questId) async {
    List<Quest> dailyQuests = await _storageService.loadDailyQuests();
    for (Quest quest in dailyQuests) {
      if (quest.id == questId) return quest;
    }
    
    List<Quest> urgentQuests = await _storageService.loadUrgentQuests();
    for (Quest quest in urgentQuests) {
      if (quest.id == questId) return quest;
    }
    
    return null;
  }
  
  /// Check if daily quests should reset (new day)
  bool _shouldResetDailyQuests(DateTime lastReset, DateTime now) {
    return now.day != lastReset.day || 
           now.month != lastReset.month || 
           now.year != lastReset.year;
  }
  
  /// Scale reps based on player level
  int _scaleRepsForLevel(int baseReps, int level, [double multiplier = 1.0]) {
    if (baseReps == 0) return 0;
    double scaled = baseReps * (1 + (level - 1) * 0.1) * multiplier;
    return scaled.round().clamp(1, 200);
  }
  
  /// Scale time based on player level
  int _scaleTimeForLevel(int baseTime, int level, [double multiplier = 1.0]) {
    if (baseTime == 0) return 0;
    double scaled = baseTime * (1 + (level - 1) * 0.05) * multiplier;
    return scaled.round().clamp(30, 3600);
  }
  
  /// Scale XP based on player level
  int _scaleXpForLevel(int baseXp, int level, [double multiplier = 1.0]) {
    double scaled = baseXp * (1 + (level - 1) * 0.15) * multiplier;
    return scaled.round();
  }
  
  /// Enhance stat rewards for urgent quests
  Map<String, int> _enhanceStatRewards(Map<String, int> baseRewards) {
    Map<String, int> enhanced = {};
    baseRewards.forEach((stat, value) {
      enhanced[stat] = (value * 1.5).round();
    });
    return enhanced;
  }
  
  /// Get daily quest templates
  List<QuestTemplate> _getDailyQuestTemplates() {
    return [
      QuestTemplate('Push-up Challenge', 'Complete push-ups to build upper body strength', 20, 0, 50, {'strength': 1}),
      QuestTemplate('Squat Power', 'Perform squats for leg strength', 25, 0, 45, {'strength': 1, 'vitality': 1}),
      QuestTemplate('Plank Hold', 'Hold plank position for core strength', 0, 60, 40, {'vitality': 2}),
      QuestTemplate('Burpee Blast', 'High-intensity burpees for cardio', 15, 0, 60, {'agility': 1, 'vitality': 1}),
      QuestTemplate('Mountain Climbers', 'Fast mountain climbers for cardio', 30, 0, 55, {'agility': 2}),
      QuestTemplate('Jumping Jacks', 'Classic cardio exercise', 50, 0, 35, {'agility': 1}),
      QuestTemplate('Wall Sit', 'Isometric leg exercise', 0, 45, 40, {'vitality': 1, 'strength': 1}),
      QuestTemplate('High Knees', 'Running in place with high knees', 0, 30, 30, {'agility': 1}),
    ];
  }
  
  /// Get urgent quest templates
  List<QuestTemplate> _getUrgentQuestTemplates() {
    return [
      QuestTemplate('Shadow Clone Training', 'Intense push-up session', 50, 0, 100, {'strength': 3}),
      QuestTemplate('Speed of Light', 'Lightning-fast burpees', 30, 0, 120, {'agility': 2, 'vitality': 2}),
      QuestTemplate('Iron Will', 'Extended plank challenge', 0, 180, 90, {'vitality': 3, 'intelligence': 1}),
      QuestTemplate('Hunter\'s Endurance', 'Non-stop cardio session', 0, 300, 150, {'agility': 2, 'vitality': 3}),
      QuestTemplate('Monarch\'s Trial', 'Mixed exercise gauntlet', 100, 0, 200, {'strength': 2, 'agility': 2, 'vitality': 2}),
    ];
  }
}

/// Template for generating quests
class QuestTemplate {
  final String name;
  final String description;
  final int baseReps;
  final int baseTime;
  final int baseXp;
  final Map<String, int> statRewards;
  
  QuestTemplate(this.name, this.description, this.baseReps, this.baseTime, 
                this.baseXp, this.statRewards);
}

/// Reward given for completing a quest
class QuestReward {
  final int xpGained;
  final Map<String, int> statRewards;
  final String questName;
  final QuestType questType;
  
  QuestReward({
    required this.xpGained,
    required this.statRewards,
    required this.questName,
    required this.questType,
  });
}

/// Penalty for failing a quest
class QuestPenalty {
  final String questName;
  final PenaltyType penaltyType;
  final Duration duration;
  
  QuestPenalty({
    required this.questName,
    required this.penaltyType,
    required this.duration,
  });
}

/// Types of penalties
enum PenaltyType {
  statDebuff,
  xpLoss,
  questCooldown,
}
