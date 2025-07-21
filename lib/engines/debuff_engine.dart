import 'dart:math';
import '../models/player.dart';
import '../services/storage_service.dart';

/// Engine for managing stat debuffs and penalties
class DebuffEngine {
  final StorageService _storageService;
  final Random _random = Random();
  
  DebuffEngine(this._storageService);
  
  /// Apply a debuff to a random stat for failed quests
  Future<AppliedDebuff> applyQuestFailureDebuff(Player player, {
    Duration duration = const Duration(hours: 24),
    int severity = 1,
  }) async {
    // Choose random stat to debuff
    List<String> stats = ['strength', 'agility', 'vitality', 'intelligence', 'luck'];
    String targetStat = stats[_random.nextInt(stats.length)];
    
    String debuffId = 'quest_failure_${targetStat}_${DateTime.now().millisecondsSinceEpoch}';
    int expirationTime = DateTime.now().add(duration).millisecondsSinceEpoch;
    
    // Apply debuff
    player.debuffs[debuffId] = expirationTime;
    
    await _storageService.savePlayer(player);
    
    return AppliedDebuff(
      id: debuffId,
      type: DebuffType.questFailure,
      targetStat: targetStat,
      severity: severity,
      duration: duration,
      appliedAt: DateTime.now(),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expirationTime),
      description: 'Failed to complete quest - $targetStat reduced by $severity',
    );
  }
  
  /// Apply screen time penalty debuff
  Future<AppliedDebuff> applyScreenTimePenalty(Player player, int screenTimeHours) async {
    Duration duration = Duration(hours: 12 + (screenTimeHours * 2)); // Longer penalty for more screen time
    int severity = (screenTimeHours / 2).ceil(); // More severe for excessive screen time
    
    // Target intelligence and luck for screen time penalties
    List<String> targetStats = ['intelligence', 'luck'];
    String targetStat = targetStats[_random.nextInt(targetStats.length)];
    
    String debuffId = 'screen_time_${targetStat}_${DateTime.now().millisecondsSinceEpoch}';
    int expirationTime = DateTime.now().add(duration).millisecondsSinceEpoch;
    
    player.debuffs[debuffId] = expirationTime;
    
    await _storageService.savePlayer(player);
    
    return AppliedDebuff(
      id: debuffId,
      type: DebuffType.screenTime,
      targetStat: targetStat,
      severity: severity,
      duration: duration,
      appliedAt: DateTime.now(),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expirationTime),
      description: 'Excessive screen time ($screenTimeHours hours) - $targetStat reduced by $severity',
    );
  }
  
  /// Apply urgent quest failure penalty (more severe)
  Future<AppliedDebuff> applyUrgentQuestFailure(Player player) async {
    Duration duration = Duration(hours: 48); // Longer penalty
    int severity = 2; // More severe penalty
    
    // Choose random stat, but favor physical stats for urgent quest failures
    List<String> stats = ['strength', 'strength', 'agility', 'agility', 'vitality', 'vitality', 'intelligence', 'luck'];
    String targetStat = stats[_random.nextInt(stats.length)];
    
    String debuffId = 'urgent_failure_${targetStat}_${DateTime.now().millisecondsSinceEpoch}';
    int expirationTime = DateTime.now().add(duration).millisecondsSinceEpoch;
    
    player.debuffs[debuffId] = expirationTime;
    
    await _storageService.savePlayer(player);
    
    return AppliedDebuff(
      id: debuffId,
      type: DebuffType.urgentQuestFailure,
      targetStat: targetStat,
      severity: severity,
      duration: duration,
      appliedAt: DateTime.now(),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expirationTime),
      description: 'Failed urgent quest - $targetStat severely reduced by $severity',
    );
  }
  
  /// Apply inactivity debuff for long periods without exercise
  Future<AppliedDebuff> applyInactivityDebuff(Player player, int daysSinceLastWorkout) async {
    Duration duration = Duration(hours: 24 * daysSinceLastWorkout); // Scales with inactivity
    int severity = (daysSinceLastWorkout / 3).ceil().clamp(1, 5); // Max 5 point penalty
    
    // Inactivity affects all physical stats
    List<String> physicalStats = ['strength', 'agility', 'vitality'];
    String targetStat = physicalStats[_random.nextInt(physicalStats.length)];
    
    String debuffId = 'inactivity_${targetStat}_${DateTime.now().millisecondsSinceEpoch}';
    int expirationTime = DateTime.now().add(duration).millisecondsSinceEpoch;
    
    player.debuffs[debuffId] = expirationTime;
    
    await _storageService.savePlayer(player);
    
    return AppliedDebuff(
      id: debuffId,
      type: DebuffType.inactivity,
      targetStat: targetStat,
      severity: severity,
      duration: duration,
      appliedAt: DateTime.now(),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expirationTime),
      description: 'Inactivity for $daysSinceLastWorkout days - $targetStat reduced by $severity',
    );
  }
  
  /// Clear expired debuffs automatically
  Future<List<ClearedDebuff>> clearExpiredDebuffs(Player player) async {
    List<ClearedDebuff> clearedDebuffs = [];
    DateTime now = DateTime.now();
    
    List<String> expiredDebuffIds = [];
    
    player.debuffs.forEach((debuffId, expirationTime) {
      if (now.millisecondsSinceEpoch >= expirationTime) {
        expiredDebuffIds.add(debuffId);
        
        // Parse debuff info from ID
        List<String> parts = debuffId.split('_');
        String type = parts[0];
        String targetStat = parts.length > 1 ? parts[1] : 'unknown';
        
        clearedDebuffs.add(ClearedDebuff(
          id: debuffId,
          targetStat: targetStat,
          type: _parseDebuffType(type),
          clearedAt: now,
        ));
      }
    });
    
    // Remove expired debuffs
    for (String debuffId in expiredDebuffIds) {
      player.debuffs.remove(debuffId);
    }
    
    if (clearedDebuffs.isNotEmpty) {
      await _storageService.savePlayer(player);
    }
    
    return clearedDebuffs;
  }
  
  /// Get all active debuffs with details
  List<ActiveDebuff> getActiveDebuffs(Player player) {
    List<ActiveDebuff> activeDebuffs = [];
    DateTime now = DateTime.now();
    
    player.debuffs.forEach((debuffId, expirationTime) {
      if (now.millisecondsSinceEpoch < expirationTime) {
        List<String> parts = debuffId.split('_');
        String type = parts[0];
        String targetStat = parts.length > 1 ? parts[1] : 'unknown';
        
        Duration remainingTime = DateTime.fromMillisecondsSinceEpoch(expirationTime)
            .difference(now);
        
        activeDebuffs.add(ActiveDebuff(
          id: debuffId,
          type: _parseDebuffType(type),
          targetStat: targetStat,
          severity: _calculateDebuffSeverity(debuffId),
          remainingTime: remainingTime,
          expiresAt: DateTime.fromMillisecondsSinceEpoch(expirationTime),
        ));
      }
    });
    
    return activeDebuffs;
  }
  
  /// Calculate total debuff effect on a specific stat
  int calculateStatDebuff(Player player, String statName) {
    int totalDebuff = 0;
    DateTime now = DateTime.now();
    
    player.debuffs.forEach((debuffId, expirationTime) {
      if (now.millisecondsSinceEpoch < expirationTime && debuffId.contains(statName)) {
        totalDebuff += _calculateDebuffSeverity(debuffId);
      }
    });
    
    return totalDebuff;
  }
  
  /// Remove a specific debuff (for items/abilities that clear debuffs)
  Future<bool> removeDebuff(Player player, String debuffId) async {
    if (player.debuffs.containsKey(debuffId)) {
      player.debuffs.remove(debuffId);
      await _storageService.savePlayer(player);
      return true;
    }
    return false;
  }
  
  /// Reduce debuff duration (for mobility/stretching bonuses)
  Future<bool> reduceDebuffDuration(Player player, String debuffId, Duration reduction) async {
    if (player.debuffs.containsKey(debuffId)) {
      int currentExpiration = player.debuffs[debuffId]!;
      int newExpiration = currentExpiration - reduction.inMilliseconds;
      
      // Don't let it go negative
      if (newExpiration <= DateTime.now().millisecondsSinceEpoch) {
        player.debuffs.remove(debuffId);
      } else {
        player.debuffs[debuffId] = newExpiration;
      }
      
      await _storageService.savePlayer(player);
      return true;
    }
    return false;
  }
  
  /// Apply mobility bonus to reduce all debuff durations
  Future<int> applyMobilityBonus(Player player, int mobilityMinutes) async {
    int debuffsAffected = 0;
    Duration reduction = Duration(minutes: mobilityMinutes * 2); // 2 minutes reduction per mobility minute
    
    List<String> debuffIds = List.from(player.debuffs.keys);
    
    for (String debuffId in debuffIds) {
      if (await reduceDebuffDuration(player, debuffId, reduction)) {
        debuffsAffected++;
      }
    }
    
    return debuffsAffected;
  }
  
  /// Get debuff resistance based on player stats
  double getDebuffResistance(Player player) {
    // Higher vitality and intelligence provide debuff resistance
    double resistance = (player.vitality + player.intelligence - 20) * 0.01;
    return resistance.clamp(0.0, 0.5); // Max 50% resistance
  }
  
  /// Check if player should receive a debuff (considering resistance)
  bool shouldApplyDebuff(Player player) {
    double resistance = getDebuffResistance(player);
    return _random.nextDouble() > resistance;
  }
  
  /// Parse debuff type from string
  DebuffType _parseDebuffType(String typeString) {
    switch (typeString) {
      case 'quest':
        return DebuffType.questFailure;
      case 'screen':
        return DebuffType.screenTime;
      case 'urgent':
        return DebuffType.urgentQuestFailure;
      case 'inactivity':
        return DebuffType.inactivity;
      default:
        return DebuffType.questFailure;
    }
  }
  
  /// Calculate debuff severity from debuff ID
  int _calculateDebuffSeverity(String debuffId) {
    if (debuffId.contains('urgent')) return 2;
    if (debuffId.contains('inactivity')) return 3;
    if (debuffId.contains('screen')) return 1;
    return 1; // Default severity
  }
}

/// Types of debuffs
enum DebuffType {
  questFailure,
  screenTime,
  urgentQuestFailure,
  inactivity,
}

/// Applied debuff information
class AppliedDebuff {
  final String id;
  final DebuffType type;
  final String targetStat;
  final int severity;
  final Duration duration;
  final DateTime appliedAt;
  final DateTime expiresAt;
  final String description;
  
  AppliedDebuff({
    required this.id,
    required this.type,
    required this.targetStat,
    required this.severity,
    required this.duration,
    required this.appliedAt,
    required this.expiresAt,
    required this.description,
  });
}

/// Active debuff information
class ActiveDebuff {
  final String id;
  final DebuffType type;
  final String targetStat;
  final int severity;
  final Duration remainingTime;
  final DateTime expiresAt;
  
  ActiveDebuff({
    required this.id,
    required this.type,
    required this.targetStat,
    required this.severity,
    required this.remainingTime,
    required this.expiresAt,
  });
  
  /// Get user-friendly description
  String get description {
    String typeDesc = '';
    switch (type) {
      case DebuffType.questFailure:
        typeDesc = 'Quest Failure';
        break;
      case DebuffType.screenTime:
        typeDesc = 'Screen Time Penalty';
        break;
      case DebuffType.urgentQuestFailure:
        typeDesc = 'Urgent Quest Failure';
        break;
      case DebuffType.inactivity:
        typeDesc = 'Inactivity Penalty';
        break;
    }
    
    return '$typeDesc: $targetStat -$severity';
  }
  
  /// Get remaining time as formatted string
  String get remainingTimeString {
    if (remainingTime.inDays > 0) {
      return '${remainingTime.inDays}d ${remainingTime.inHours % 24}h';
    } else if (remainingTime.inHours > 0) {
      return '${remainingTime.inHours}h ${remainingTime.inMinutes % 60}m';
    } else {
      return '${remainingTime.inMinutes}m';
    }
  }
}

/// Cleared debuff information
class ClearedDebuff {
  final String id;
  final String targetStat;
  final DebuffType type;
  final DateTime clearedAt;
  
  ClearedDebuff({
    required this.id,
    required this.targetStat,
    required this.type,
    required this.clearedAt,
  });
}
