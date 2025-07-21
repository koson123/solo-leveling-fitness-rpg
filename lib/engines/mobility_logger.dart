import '../models/player.dart';
import '../services/storage_service.dart';
import 'debuff_engine.dart';
import 'stat_engine.dart';

/// Engine for logging mobility and stretching sessions
class MobilityLogger {
  final StorageService _storageService;
  final DebuffEngine _debuffEngine;
  final StatEngine _statEngine;
  
  MobilityLogger(this._storageService, this._debuffEngine, this._statEngine);
  
  /// Log a mobility/stretching session
  Future<MobilityResult> logMobilitySession({
    required Player player,
    required String activityName,
    required int durationMinutes,
    String notes = '',
  }) async {
    // Create mobility session
    MobilitySession session = MobilitySession(
      id: 'mobility_${DateTime.now().millisecondsSinceEpoch}',
      activityName: activityName,
      durationMinutes: durationMinutes,
      notes: notes,
    );
    
    // Calculate benefits
    MobilityBenefits benefits = _calculateMobilityBenefits(durationMinutes, activityName);
    
    // Apply debuff reduction
    int debuffsReduced = await _debuffEngine.applyMobilityBonus(player, durationMinutes);
    
    // Apply XP bonus
    LevelUpResult? levelUpResult;
    if (benefits.xpBonus > 0) {
      levelUpResult = await _statEngine.addExperience(player, benefits.xpBonus);
    }
    
    // Save mobility session
    List<MobilitySession> sessions = await _storageService.loadMobilitySessions();
    sessions.add(session);
    await _storageService.saveMobilitySessions(sessions);
    
    return MobilityResult(
      session: session,
      benefits: benefits,
      debuffsReduced: debuffsReduced,
      levelUpResult: levelUpResult,
    );
  }
  
  /// Get mobility statistics for a time period
  Future<MobilityStats> getMobilityStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    List<MobilitySession> sessions = await _storageService.loadMobilitySessions();
    
    startDate ??= DateTime.now().subtract(Duration(days: 30));
    endDate ??= DateTime.now();
    
    // Filter sessions by date range
    sessions = sessions.where((session) {
      return session.completedAt.isAfter(startDate!) && 
             session.completedAt.isBefore(endDate!);
    }).toList();
    
    if (sessions.isEmpty) {
      return MobilityStats.empty();
    }
    
    // Calculate statistics
    int totalSessions = sessions.length;
    int totalMinutes = sessions.fold(0, (sum, session) => sum + session.durationMinutes);
    double averageDuration = totalMinutes / totalSessions;
    
    // Find most common activity
    Map<String, int> activityCount = {};
    Map<String, int> activityMinutes = {};
    
    for (MobilitySession session in sessions) {
      activityCount[session.activityName] = (activityCount[session.activityName] ?? 0) + 1;
      activityMinutes[session.activityName] = (activityMinutes[session.activityName] ?? 0) + session.durationMinutes;
    }
    
    String favoriteActivity = activityCount.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    
    // Calculate streak
    int currentStreak = _calculateMobilityStreak(sessions);
    
    return MobilityStats(
      totalSessions: totalSessions,
      totalMinutes: totalMinutes,
      averageDuration: averageDuration,
      favoriteActivity: favoriteActivity,
      currentStreak: currentStreak,
      sessionsThisWeek: _getSessionsThisWeek(sessions),
      activityBreakdown: activityMinutes,
      longestSession: sessions.map((s) => s.durationMinutes).reduce((a, b) => a > b ? a : b),
    );
  }
  
  /// Get recommended mobility activities based on player needs
  List<MobilityRecommendation> getRecommendedActivities(Player player) {
    List<MobilityRecommendation> recommendations = [];
    
    // Check for active debuffs
    bool hasDebuffs = player.debuffs.isNotEmpty;
    
    // Base recommendations
    recommendations.addAll([
      MobilityRecommendation(
        name: 'Dynamic Warm-up',
        description: 'Prepare your body for exercise',
        recommendedDuration: 10,
        benefits: ['Injury prevention', 'Better performance'],
        priority: hasDebuffs ? MobilityPriority.high : MobilityPriority.medium,
      ),
      MobilityRecommendation(
        name: 'Full Body Stretch',
        description: 'Complete stretching routine',
        recommendedDuration: 20,
        benefits: ['Flexibility', 'Debuff reduction', 'Recovery'],
        priority: hasDebuffs ? MobilityPriority.high : MobilityPriority.medium,
      ),
      MobilityRecommendation(
        name: 'Yoga Flow',
        description: 'Flowing yoga sequence',
        recommendedDuration: 30,
        benefits: ['Flexibility', 'Mental clarity', 'Stress relief'],
        priority: MobilityPriority.medium,
      ),
    ]);
    
    // Add specific recommendations based on player stats
    if (player.agility < player.strength) {
      recommendations.add(MobilityRecommendation(
        name: 'Agility Mobility',
        description: 'Focus on movement quality and speed',
        recommendedDuration: 15,
        benefits: ['Agility improvement', 'Movement quality'],
        priority: MobilityPriority.high,
      ));
    }
    
    if (player.vitality < player.strength) {
      recommendations.add(MobilityRecommendation(
        name: 'Recovery Stretching',
        description: 'Gentle stretches for recovery',
        recommendedDuration: 25,
        benefits: ['Recovery', 'Vitality boost', 'Fatigue reduction'],
        priority: MobilityPriority.high,
      ));
    }
    
    // High priority if player has many debuffs
    if (player.debuffs.length >= 2) {
      recommendations.add(MobilityRecommendation(
        name: 'Debuff Cleansing Routine',
        description: 'Intensive mobility work to clear penalties',
        recommendedDuration: 45,
        benefits: ['Major debuff reduction', 'Stat recovery'],
        priority: MobilityPriority.urgent,
      ));
    }
    
    // Sort by priority
    recommendations.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    
    return recommendations;
  }
  
  /// Get mobility achievements
  List<MobilityAchievement> checkMobilityAchievements(Player player, MobilityStats stats) {
    List<MobilityAchievement> achievements = [];
    
    // Session count achievements
    if (stats.totalSessions >= 100) {
      achievements.add(MobilityAchievement(
        name: 'Flexibility Master',
        description: 'Complete 100 mobility sessions',
        type: MobilityAchievementType.sessions,
      ));
    } else if (stats.totalSessions >= 50) {
      achievements.add(MobilityAchievement(
        name: 'Mobility Enthusiast',
        description: 'Complete 50 mobility sessions',
        type: MobilityAchievementType.sessions,
      ));
    } else if (stats.totalSessions >= 10) {
      achievements.add(MobilityAchievement(
        name: 'Flexibility Seeker',
        description: 'Complete 10 mobility sessions',
        type: MobilityAchievementType.sessions,
      ));
    }
    
    // Duration achievements
    if (stats.totalMinutes >= 1000) {
      achievements.add(MobilityAchievement(
        name: 'Time Master',
        description: 'Spend 1000+ minutes on mobility',
        type: MobilityAchievementType.duration,
      ));
    }
    
    // Streak achievements
    if (stats.currentStreak >= 30) {
      achievements.add(MobilityAchievement(
        name: 'Consistency King',
        description: '30-day mobility streak',
        type: MobilityAchievementType.streak,
      ));
    } else if (stats.currentStreak >= 7) {
      achievements.add(MobilityAchievement(
        name: 'Weekly Warrior',
        description: '7-day mobility streak',
        type: MobilityAchievementType.streak,
      ));
    }
    
    return achievements;
  }
  
  /// Calculate benefits of mobility session
  MobilityBenefits _calculateMobilityBenefits(int durationMinutes, String activityName) {
    int baseXp = (durationMinutes * 1.5).round();
    int debuffReduction = (durationMinutes * 2); // 2 minutes reduction per minute of mobility
    
    // Activity-specific bonuses
    double multiplier = 1.0;
    List<String> specificBenefits = [];
    
    switch (activityName.toLowerCase()) {
      case 'yoga':
      case 'yoga flow':
        multiplier = 1.3;
        specificBenefits.addAll(['Mental clarity', 'Stress relief', 'Balance']);
        break;
      case 'dynamic warm-up':
      case 'warm-up':
        multiplier = 1.1;
        specificBenefits.addAll(['Injury prevention', 'Performance boost']);
        break;
      case 'stretching':
      case 'full body stretch':
        multiplier = 1.2;
        specificBenefits.addAll(['Flexibility', 'Recovery']);
        break;
      case 'foam rolling':
        multiplier = 1.4;
        specificBenefits.addAll(['Muscle recovery', 'Tension relief']);
        break;
      case 'pilates':
        multiplier = 1.25;
        specificBenefits.addAll(['Core strength', 'Posture']);
        break;
      default:
        specificBenefits.add('General mobility');
    }
    
    // Duration bonuses
    if (durationMinutes >= 45) {
      multiplier += 0.3;
      specificBenefits.add('Extended session bonus');
    } else if (durationMinutes >= 30) {
      multiplier += 0.2;
    } else if (durationMinutes >= 20) {
      multiplier += 0.1;
    }
    
    return MobilityBenefits(
      xpBonus: (baseXp * multiplier).round(),
      debuffReductionMinutes: debuffReduction,
      recoveryBonus: (durationMinutes * 0.5).round(),
      specificBenefits: specificBenefits,
    );
  }
  
  /// Calculate mobility streak
  int _calculateMobilityStreak(List<MobilitySession> sessions) {
    if (sessions.isEmpty) return 0;
    
    sessions.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    
    int streak = 0;
    DateTime currentDate = DateTime.now();
    Set<String> checkedDates = {};
    
    for (MobilitySession session in sessions) {
      String sessionDateKey = '${session.completedAt.year}-${session.completedAt.month}-${session.completedAt.day}';
      String currentDateKey = '${currentDate.year}-${currentDate.month}-${currentDate.day}';
      
      if (sessionDateKey == currentDateKey && !checkedDates.contains(sessionDateKey)) {
        streak++;
        checkedDates.add(sessionDateKey);
        currentDate = currentDate.subtract(Duration(days: 1));
      } else if (checkedDates.contains(sessionDateKey)) {
        continue; // Skip if we already counted this date
      } else {
        break; // Streak broken
      }
    }
    
    return streak;
  }
  
  /// Get sessions from this week
  int _getSessionsThisWeek(List<MobilitySession> sessions) {
    DateTime now = DateTime.now();
    DateTime weekStart = now.subtract(Duration(days: now.weekday - 1));
    
    return sessions.where((session) => 
      session.completedAt.isAfter(weekStart)).length;
  }
}

/// Result of logging a mobility session
class MobilityResult {
  final MobilitySession session;
  final MobilityBenefits benefits;
  final int debuffsReduced;
  final LevelUpResult? levelUpResult;
  
  MobilityResult({
    required this.session,
    required this.benefits,
    required this.debuffsReduced,
    this.levelUpResult,
  });
}

/// Benefits gained from mobility session
class MobilityBenefits {
  final int xpBonus;
  final int debuffReductionMinutes;
  final int recoveryBonus;
  final List<String> specificBenefits;
  
  MobilityBenefits({
    required this.xpBonus,
    required this.debuffReductionMinutes,
    required this.recoveryBonus,
    required this.specificBenefits,
  });
}

/// Mobility statistics
class MobilityStats {
  final int totalSessions;
  final int totalMinutes;
  final double averageDuration;
  final String favoriteActivity;
  final int currentStreak;
  final int sessionsThisWeek;
  final Map<String, int> activityBreakdown;
  final int longestSession;
  
  MobilityStats({
    required this.totalSessions,
    required this.totalMinutes,
    required this.averageDuration,
    required this.favoriteActivity,
    required this.currentStreak,
    required this.sessionsThisWeek,
    required this.activityBreakdown,
    required this.longestSession,
  });
  
  factory MobilityStats.empty() {
    return MobilityStats(
      totalSessions: 0,
      totalMinutes: 0,
      averageDuration: 0.0,
      favoriteActivity: 'None',
      currentStreak: 0,
      sessionsThisWeek: 0,
      activityBreakdown: {},
      longestSession: 0,
    );
  }
}

/// Mobility activity recommendation
class MobilityRecommendation {
  final String name;
  final String description;
  final int recommendedDuration;
  final List<String> benefits;
  final MobilityPriority priority;
  
  MobilityRecommendation({
    required this.name,
    required this.description,
    required this.recommendedDuration,
    required this.benefits,
    required this.priority,
  });
}

/// Mobility achievement
class MobilityAchievement {
  final String name;
  final String description;
  final MobilityAchievementType type;
  
  MobilityAchievement({
    required this.name,
    required this.description,
    required this.type,
  });
}

/// Priority levels for mobility recommendations
enum MobilityPriority {
  urgent,
  high,
  medium,
  low,
}

/// Types of mobility achievements
enum MobilityAchievementType {
  sessions,
  duration,
  streak,
  variety,
}

// Import required classes
import '../services/storage_service.dart' show MobilitySession;
import 'stat_engine.dart' show LevelUpResult;
