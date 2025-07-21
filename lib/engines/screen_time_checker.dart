import '../models/player.dart';
import '../services/storage_service.dart';
import 'debuff_engine.dart';

/// Engine for managing screen time tracking and penalties
class ScreenTimeChecker {
  final StorageService _storageService;
  final DebuffEngine _debuffEngine;
  
  // Screen time thresholds (in hours)
  static const int warningThreshold = 3;
  static const int penaltyThreshold = 4;
  static const int severePenaltyThreshold = 6;
  
  ScreenTimeChecker(this._storageService, this._debuffEngine);
  
  /// Check if daily screen time prompt is needed
  Future<bool> shouldPromptScreenTime(Player player) async {
    DateTime now = DateTime.now();
    DateTime lastCheck = player.lastScreenTimeCheck;
    
    // Check if it's a new day
    return now.day != lastCheck.day || 
           now.month != lastCheck.month || 
           now.year != lastCheck.year;
  }
  
  /// Process daily screen time input
  Future<ScreenTimeResult> processScreenTime(Player player, int screenTimeHours) async {
    DateTime now = DateTime.now();
    
    // Update last check time
    player.lastScreenTimeCheck = now;
    
    // Save screen time data
    Map<String, dynamic> screenTimeData = await _storageService.loadScreenTimeData();
    String dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    screenTimeData[dateKey] = screenTimeHours;
    await _storageService.saveScreenTimeData(screenTimeData);
    
    ScreenTimeResult result = ScreenTimeResult(
      screenTimeHours: screenTimeHours,
      threshold: _getThresholdLevel(screenTimeHours),
      message: _getScreenTimeMessage(screenTimeHours),
      hasReward: false,
      hasPenalty: false,
      xpBonus: 0,
      debuffApplied: null,
    );
    
    // Apply rewards or penalties based on screen time
    if (screenTimeHours <= 2) {
      // Excellent screen time - bonus XP
      result.hasReward = true;
      result.xpBonus = 50;
      result.message = 'Excellent self-control! Bonus XP awarded.';
    } else if (screenTimeHours <= warningThreshold) {
      // Good screen time - small bonus
      result.hasReward = true;
      result.xpBonus = 25;
      result.message = 'Good screen time management! Small XP bonus.';
    } else if (screenTimeHours >= severePenaltyThreshold) {
      // Severe penalty
      result.hasPenalty = true;
      result.debuffApplied = await _debuffEngine.applyScreenTimePenalty(player, screenTimeHours);
      result.message = 'Excessive screen time! Severe stat penalty applied.';
    } else if (screenTimeHours >= penaltyThreshold) {
      // Regular penalty
      result.hasPenalty = true;
      result.debuffApplied = await _debuffEngine.applyScreenTimePenalty(player, screenTimeHours);
      result.message = 'Too much screen time. Stat penalty applied.';
    } else {
      // Warning level - no penalty yet
      result.message = 'Screen time is getting high. Be careful!';
    }
    
    await _storageService.savePlayer(player);
    
    return result;
  }
  
  /// Get screen time statistics for a period
  Future<ScreenTimeStats> getScreenTimeStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Map<String, dynamic> screenTimeData = await _storageService.loadScreenTimeData();
    
    startDate ??= DateTime.now().subtract(Duration(days: 30));
    endDate ??= DateTime.now();
    
    List<DailyScreenTime> dailyData = [];
    int totalHours = 0;
    int daysTracked = 0;
    int goodDays = 0;
    int warningDays = 0;
    int penaltyDays = 0;
    
    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      String dateKey = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';
      
      if (screenTimeData.containsKey(dateKey)) {
        int hours = screenTimeData[dateKey];
        dailyData.add(DailyScreenTime(
          date: currentDate,
          hours: hours,
          threshold: _getThresholdLevel(hours),
        ));
        
        totalHours += hours;
        daysTracked++;
        
        if (hours <= warningThreshold) {
          goodDays++;
        } else if (hours <= penaltyThreshold) {
          warningDays++;
        } else {
          penaltyDays++;
        }
      }
      
      currentDate = currentDate.add(Duration(days: 1));
    }
    
    return ScreenTimeStats(
      dailyData: dailyData,
      averageHours: daysTracked > 0 ? totalHours / daysTracked : 0.0,
      totalHours: totalHours,
      daysTracked: daysTracked,
      goodDays: goodDays,
      warningDays: warningDays,
      penaltyDays: penaltyDays,
      currentStreak: _calculateGoodScreenTimeStreak(dailyData),
    );
  }
  
  /// Get weekly screen time summary
  Future<WeeklyScreenTimeSummary> getWeeklyScreenTimeSummary() async {
    DateTime now = DateTime.now();
    DateTime weekStart = now.subtract(Duration(days: now.weekday - 1));
    DateTime weekEnd = weekStart.add(Duration(days: 6));
    
    ScreenTimeStats stats = await getScreenTimeStats(
      startDate: weekStart,
      endDate: weekEnd,
    );
    
    return WeeklyScreenTimeSummary(
      weekStart: weekStart,
      weekEnd: weekEnd,
      totalHours: stats.totalHours,
      averageHours: stats.averageHours,
      daysTracked: stats.daysTracked,
      grade: _calculateWeeklyGrade(stats),
      recommendation: _getWeeklyRecommendation(stats),
    );
  }
  
  /// Set screen time goal for the player
  Future<void> setScreenTimeGoal(Player player, int dailyGoalHours) async {
    Map<String, dynamic> screenTimeData = await _storageService.loadScreenTimeData();
    screenTimeData['daily_goal'] = dailyGoalHours;
    await _storageService.saveScreenTimeData(screenTimeData);
  }
  
  /// Get player's screen time goal
  Future<int> getScreenTimeGoal() async {
    Map<String, dynamic> screenTimeData = await _storageService.loadScreenTimeData();
    return screenTimeData['daily_goal'] ?? penaltyThreshold;
  }
  
  /// Check if player met their screen time goal today
  Future<bool> metScreenTimeGoalToday() async {
    DateTime now = DateTime.now();
    String dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
    Map<String, dynamic> screenTimeData = await _storageService.loadScreenTimeData();
    int todayScreenTime = screenTimeData[dateKey] ?? 0;
    int goal = await getScreenTimeGoal();
    
    return todayScreenTime <= goal;
  }
  
  /// Get screen time threshold level
  ScreenTimeThreshold _getThresholdLevel(int hours) {
    if (hours <= 2) return ScreenTimeThreshold.excellent;
    if (hours <= warningThreshold) return ScreenTimeThreshold.good;
    if (hours <= penaltyThreshold) return ScreenTimeThreshold.warning;
    if (hours <= severePenaltyThreshold) return ScreenTimeThreshold.penalty;
    return ScreenTimeThreshold.severe;
  }
  
  /// Get appropriate message for screen time
  String _getScreenTimeMessage(int hours) {
    switch (_getThresholdLevel(hours)) {
      case ScreenTimeThreshold.excellent:
        return 'Outstanding digital wellness! You\'re a role model.';
      case ScreenTimeThreshold.good:
        return 'Great job managing your screen time!';
      case ScreenTimeThreshold.warning:
        return 'Screen time is getting a bit high. Consider taking breaks.';
      case ScreenTimeThreshold.penalty:
        return 'Excessive screen time detected. This will affect your stats.';
      case ScreenTimeThreshold.severe:
        return 'Dangerously high screen time! Severe penalties applied.';
    }
  }
  
  /// Calculate good screen time streak
  int _calculateGoodScreenTimeStreak(List<DailyScreenTime> dailyData) {
    if (dailyData.isEmpty) return 0;
    
    // Sort by date (most recent first)
    dailyData.sort((a, b) => b.date.compareTo(a.date));
    
    int streak = 0;
    for (DailyScreenTime day in dailyData) {
      if (day.threshold == ScreenTimeThreshold.excellent || 
          day.threshold == ScreenTimeThreshold.good) {
        streak++;
      } else {
        break;
      }
    }
    
    return streak;
  }
  
  /// Calculate weekly grade
  String _calculateWeeklyGrade(ScreenTimeStats stats) {
    if (stats.daysTracked == 0) return 'N/A';
    
    double goodPercentage = stats.goodDays / stats.daysTracked;
    
    if (goodPercentage >= 0.9) return 'A+';
    if (goodPercentage >= 0.8) return 'A';
    if (goodPercentage >= 0.7) return 'B+';
    if (goodPercentage >= 0.6) return 'B';
    if (goodPercentage >= 0.5) return 'C+';
    if (goodPercentage >= 0.4) return 'C';
    if (goodPercentage >= 0.3) return 'D';
    return 'F';
  }
  
  /// Get weekly recommendation
  String _getWeeklyRecommendation(ScreenTimeStats stats) {
    if (stats.penaltyDays > stats.goodDays) {
      return 'Focus on reducing screen time. Try setting specific times for device use.';
    } else if (stats.warningDays > 2) {
      return 'You\'re doing well, but watch out for those warning days. Set reminders to take breaks.';
    } else {
      return 'Excellent screen time management! Keep up the great work.';
    }
  }
}

/// Result of processing daily screen time
class ScreenTimeResult {
  final int screenTimeHours;
  final ScreenTimeThreshold threshold;
  final String message;
  final bool hasReward;
  final bool hasPenalty;
  final int xpBonus;
  final AppliedDebuff? debuffApplied;
  
  ScreenTimeResult({
    required this.screenTimeHours,
    required this.threshold,
    required this.message,
    required this.hasReward,
    required this.hasPenalty,
    required this.xpBonus,
    this.debuffApplied,
  });
}

/// Screen time statistics
class ScreenTimeStats {
  final List<DailyScreenTime> dailyData;
  final double averageHours;
  final int totalHours;
  final int daysTracked;
  final int goodDays;
  final int warningDays;
  final int penaltyDays;
  final int currentStreak;
  
  ScreenTimeStats({
    required this.dailyData,
    required this.averageHours,
    required this.totalHours,
    required this.daysTracked,
    required this.goodDays,
    required this.warningDays,
    required this.penaltyDays,
    required this.currentStreak,
  });
}

/// Daily screen time data
class DailyScreenTime {
  final DateTime date;
  final int hours;
  final ScreenTimeThreshold threshold;
  
  DailyScreenTime({
    required this.date,
    required this.hours,
    required this.threshold,
  });
}

/// Weekly screen time summary
class WeeklyScreenTimeSummary {
  final DateTime weekStart;
  final DateTime weekEnd;
  final int totalHours;
  final double averageHours;
  final int daysTracked;
  final String grade;
  final String recommendation;
  
  WeeklyScreenTimeSummary({
    required this.weekStart,
    required this.weekEnd,
    required this.totalHours,
    required this.averageHours,
    required this.daysTracked,
    required this.grade,
    required this.recommendation,
  });
}

/// Screen time threshold levels
enum ScreenTimeThreshold {
  excellent,  // 0-2 hours
  good,       // 2-3 hours
  warning,    // 3-4 hours
  penalty,    // 4-6 hours
  severe,     // 6+ hours
}

// Import the AppliedDebuff class from debuff_engine.dart
import 'debuff_engine.dart';
