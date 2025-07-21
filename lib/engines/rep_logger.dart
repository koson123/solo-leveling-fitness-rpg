import 'dart:math';
import '../models/player.dart';
import '../models/quest.dart';
import '../services/storage_service.dart';
import 'stat_engine.dart';

/// Engine for logging workout reps and calculating XP rewards
class RepLogger {
  final StorageService _storageService;
  final StatEngine _statEngine;
  
  RepLogger(this._storageService, this._statEngine);
  
  /// Log a complete workout session with multiple sets
  Future<WorkoutResult> logWorkoutSession({
    required Player player,
    required String exerciseName,
    required List<WorkoutSet> sets,
  }) async {
    // Create workout session
    WorkoutSession session = WorkoutSession(
      id: 'workout_${DateTime.now().millisecondsSinceEpoch}',
      exerciseName: exerciseName,
      sets: sets,
    );
    
    // Calculate total XP from all sets
    int totalXp = 0;
    int totalReps = 0;
    double averageRpe = 0;
    
    for (WorkoutSet set in sets) {
      totalXp += set.xpValue;
      totalReps += set.reps;
      averageRpe += set.rpe;
    }
    
    averageRpe = sets.isNotEmpty ? averageRpe / sets.length : 0;
    session.totalXpGained = totalXp;
    
    // Apply effort bonuses
    totalXp = _applyEffortBonuses(totalXp, averageRpe, totalReps, sets.length);
    
    // Apply player stat bonuses
    totalXp = _applyStatBonuses(player, totalXp, exerciseName);
    
    // Update player stats
    player.totalRepsCompleted += totalReps;
    
    // Save workout session
    List<WorkoutSession> sessions = await _storageService.loadWorkoutSessions();
    sessions.add(session);
    await _storageService.saveWorkoutSessions(sessions);
    
    // Update quest progress
    await _updateQuestProgress(exerciseName, totalReps);
    
    // Level up player
    LevelUpResult levelUpResult = await _statEngine.addExperience(player, totalXp);
    
    return WorkoutResult(
      session: session,
      xpGained: totalXp,
      levelUpResult: levelUpResult,
      totalReps: totalReps,
      averageRpe: averageRpe,
    );
  }
  
  /// Log a single set during workout
  Future<SetResult> logSingleSet({
    required Player player,
    required String exerciseName,
    required int reps,
    required double rpe,
    int restTime = 0,
  }) async {
    WorkoutSet set = WorkoutSet(
      reps: reps,
      rpe: rpe,
      restTime: restTime,
    );
    
    int xpGained = set.xpValue;
    
    // Apply bonuses for single set
    xpGained = _applyEffortBonuses(xpGained, rpe, reps, 1);
    xpGained = _applyStatBonuses(player, xpGained, exerciseName);
    
    // Update quest progress
    await _updateQuestProgress(exerciseName, reps);
    
    return SetResult(
      set: set,
      xpGained: xpGained,
      exerciseName: exerciseName,
    );
  }
  
  /// Get workout statistics for a time period
  Future<WorkoutStats> getWorkoutStats(Player player, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    List<WorkoutSession> sessions = await _storageService.loadWorkoutSessions();
    
    startDate ??= DateTime.now().subtract(Duration(days: 30));
    endDate ??= DateTime.now();
    
    // Filter sessions by date range
    sessions = sessions.where((session) {
      return session.completedAt.isAfter(startDate!) && 
             session.completedAt.isBefore(endDate!);
    }).toList();
    
    if (sessions.isEmpty) {
      return WorkoutStats.empty();
    }
    
    // Calculate statistics
    int totalSessions = sessions.length;
    int totalReps = sessions.fold(0, (sum, session) => sum + session.totalReps);
    int totalXp = sessions.fold(0, (sum, session) => sum + session.totalXpGained);
    double averageRpe = sessions.fold(0.0, (sum, session) => sum + session.averageRPE) / totalSessions;
    
    // Find most common exercise
    Map<String, int> exerciseCount = {};
    for (WorkoutSession session in sessions) {
      exerciseCount[session.exerciseName] = (exerciseCount[session.exerciseName] ?? 0) + 1;
    }
    
    String favoriteExercise = exerciseCount.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    
    // Calculate streak
    int currentStreak = _calculateWorkoutStreak(sessions);
    
    return WorkoutStats(
      totalSessions: totalSessions,
      totalReps: totalReps,
      totalXpGained: totalXp,
      averageRpe: averageRpe,
      favoriteExercise: favoriteExercise,
      currentStreak: currentStreak,
      sessionsThisWeek: _getSessionsThisWeek(sessions),
      personalBests: _calculatePersonalBests(sessions),
    );
  }
  
  /// Get recommended RPE based on recent performance
  double getRecommendedRPE(String exerciseName) {
    // This would analyze recent sessions to suggest optimal RPE
    // For now, return a balanced recommendation
    return 7.0; // Sweet spot for consistent progress
  }
  
  /// Calculate rest time recommendation based on RPE
  int getRecommendedRestTime(double rpe) {
    if (rpe >= 9.0) return 180; // 3 minutes for very high intensity
    if (rpe >= 7.0) return 120; // 2 minutes for high intensity
    if (rpe >= 5.0) return 90;  // 1.5 minutes for moderate intensity
    return 60; // 1 minute for low intensity
  }
  
  /// Apply effort bonuses based on RPE and volume
  int _applyEffortBonuses(int baseXp, double averageRpe, int totalReps, int sets) {
    double multiplier = 1.0;
    
    // High effort bonus (RPE 8+)
    if (averageRpe >= 8.0) {
      multiplier += 0.25;
    } else if (averageRpe >= 7.0) {
      multiplier += 0.15;
    }
    
    // High volume bonus
    if (totalReps >= 100) {
      multiplier += 0.20;
    } else if (totalReps >= 50) {
      multiplier += 0.10;
    }
    
    // Multiple sets bonus
    if (sets >= 5) {
      multiplier += 0.15;
    } else if (sets >= 3) {
      multiplier += 0.10;
    }
    
    // Consistency bonus (moderate RPE with good volume)
    if (averageRpe >= 6.0 && averageRpe <= 8.0 && totalReps >= 30) {
      multiplier += 0.10;
    }
    
    return (baseXp * multiplier).round();
  }
  
  /// Apply stat-based bonuses to XP
  int _applyStatBonuses(Player player, int baseXp, String exerciseName) {
    double multiplier = 1.0;
    
    // Strength exercises benefit from STR stat
    if (_isStrengthExercise(exerciseName)) {
      multiplier += (player.strength - 10) * 0.01;
    }
    
    // Cardio exercises benefit from AGI and VIT stats
    if (_isCardioExercise(exerciseName)) {
      multiplier += (player.agility - 10) * 0.008;
      multiplier += (player.vitality - 10) * 0.008;
    }
    
    // Intelligence affects learning efficiency
    multiplier += (player.intelligence - 10) * 0.005;
    
    // Luck provides random bonuses
    if (Random().nextDouble() < (player.luck / 1000)) {
      multiplier += 0.5; // Lucky bonus!
    }
    
    return (baseXp * multiplier).round();
  }
  
  /// Update quest progress based on exercise
  Future<void> _updateQuestProgress(String exerciseName, int reps) async {
    // This would integrate with QuestEngine to update relevant quests
    // Implementation would depend on quest system integration
  }
  
  /// Check if exercise is strength-based
  bool _isStrengthExercise(String exerciseName) {
    List<String> strengthExercises = [
      'push-up', 'pull-up', 'squat', 'deadlift', 'bench press',
      'overhead press', 'dip', 'chin-up', 'row'
    ];
    
    return strengthExercises.any((exercise) => 
      exerciseName.toLowerCase().contains(exercise));
  }
  
  /// Check if exercise is cardio-based
  bool _isCardioExercise(String exerciseName) {
    List<String> cardioExercises = [
      'burpee', 'jumping jack', 'mountain climber', 'high knee',
      'running', 'sprint', 'cardio', 'hiit'
    ];
    
    return cardioExercises.any((exercise) => 
      exerciseName.toLowerCase().contains(exercise));
  }
  
  /// Calculate current workout streak
  int _calculateWorkoutStreak(List<WorkoutSession> sessions) {
    if (sessions.isEmpty) return 0;
    
    sessions.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    
    int streak = 0;
    DateTime currentDate = DateTime.now();
    
    for (WorkoutSession session in sessions) {
      DateTime sessionDate = DateTime(
        session.completedAt.year,
        session.completedAt.month,
        session.completedAt.day,
      );
      
      DateTime checkDate = DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day,
      );
      
      if (sessionDate.isAtSameMomentAs(checkDate) || 
          sessionDate.isAtSameMomentAs(checkDate.subtract(Duration(days: 1)))) {
        streak++;
        currentDate = currentDate.subtract(Duration(days: 1));
      } else {
        break;
      }
    }
    
    return streak;
  }
  
  /// Get sessions from this week
  int _getSessionsThisWeek(List<WorkoutSession> sessions) {
    DateTime now = DateTime.now();
    DateTime weekStart = now.subtract(Duration(days: now.weekday - 1));
    
    return sessions.where((session) => 
      session.completedAt.isAfter(weekStart)).length;
  }
  
  /// Calculate personal bests
  Map<String, PersonalBest> _calculatePersonalBests(List<WorkoutSession> sessions) {
    Map<String, PersonalBest> personalBests = {};
    
    for (WorkoutSession session in sessions) {
      String exercise = session.exerciseName;
      
      if (!personalBests.containsKey(exercise)) {
        personalBests[exercise] = PersonalBest(
          exercise: exercise,
          maxReps: session.totalReps,
          maxXp: session.totalXpGained,
          bestRpe: session.averageRPE,
          achievedAt: session.completedAt,
        );
      } else {
        PersonalBest current = personalBests[exercise]!;
        
        if (session.totalReps > current.maxReps) {
          personalBests[exercise] = PersonalBest(
            exercise: exercise,
            maxReps: session.totalReps,
            maxXp: max(current.maxXp, session.totalXpGained),
            bestRpe: session.averageRPE,
            achievedAt: session.completedAt,
          );
        }
      }
    }
    
    return personalBests;
  }
}

/// Result of logging a complete workout session
class WorkoutResult {
  final WorkoutSession session;
  final int xpGained;
  final LevelUpResult levelUpResult;
  final int totalReps;
  final double averageRpe;
  
  WorkoutResult({
    required this.session,
    required this.xpGained,
    required this.levelUpResult,
    required this.totalReps,
    required this.averageRpe,
  });
}

/// Result of logging a single set
class SetResult {
  final WorkoutSet set;
  final int xpGained;
  final String exerciseName;
  
  SetResult({
    required this.set,
    required this.xpGained,
    required this.exerciseName,
  });
}

/// Workout statistics for analysis
class WorkoutStats {
  final int totalSessions;
  final int totalReps;
  final int totalXpGained;
  final double averageRpe;
  final String favoriteExercise;
  final int currentStreak;
  final int sessionsThisWeek;
  final Map<String, PersonalBest> personalBests;
  
  WorkoutStats({
    required this.totalSessions,
    required this.totalReps,
    required this.totalXpGained,
    required this.averageRpe,
    required this.favoriteExercise,
    required this.currentStreak,
    required this.sessionsThisWeek,
    required this.personalBests,
  });
  
  factory WorkoutStats.empty() {
    return WorkoutStats(
      totalSessions: 0,
      totalReps: 0,
      totalXpGained: 0,
      averageRpe: 0.0,
      favoriteExercise: 'None',
      currentStreak: 0,
      sessionsThisWeek: 0,
      personalBests: {},
    );
  }
}

/// Personal best record for an exercise
class PersonalBest {
  final String exercise;
  final int maxReps;
  final int maxXp;
  final double bestRpe;
  final DateTime achievedAt;
  
  PersonalBest({
    required this.exercise,
    required this.maxReps,
    required this.maxXp,
    required this.bestRpe,
    required this.achievedAt,
  });
}
