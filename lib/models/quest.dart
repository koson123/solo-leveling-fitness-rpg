/// Quest model for daily and urgent quests
class Quest {
  String id;
  String name;
  String description;
  QuestType type;
  int targetReps;
  int targetTime; // in seconds, 0 if not time-based
  int xpReward;
  Map<String, int> statRewards; // stat name -> points
  bool isCompleted;
  DateTime createdAt;
  DateTime? expiresAt; // for urgent quests
  int currentProgress;
  
  Quest({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.targetReps = 0,
    this.targetTime = 0,
    required this.xpReward,
    Map<String, int>? statRewards,
    this.isCompleted = false,
    DateTime? createdAt,
    this.expiresAt,
    this.currentProgress = 0,
  }) : statRewards = statRewards ?? {},
       createdAt = createdAt ?? DateTime.now();

  /// Check if quest is expired (for urgent quests)
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
  
  /// Get progress percentage
  double get progressPercentage {
    if (targetReps > 0) {
      return (currentProgress / targetReps).clamp(0.0, 1.0);
    }
    if (targetTime > 0) {
      return (currentProgress / targetTime).clamp(0.0, 1.0);
    }
    return 0.0;
  }
  
  /// Check if quest can be completed
  bool get canComplete {
    if (targetReps > 0) {
      return currentProgress >= targetReps;
    }
    if (targetTime > 0) {
      return currentProgress >= targetTime;
    }
    return false;
  }
  
  /// Convert quest to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.toString(),
      'targetReps': targetReps,
      'targetTime': targetTime,
      'xpReward': xpReward,
      'statRewards': statRewards,
      'isCompleted': isCompleted,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'expiresAt': expiresAt?.millisecondsSinceEpoch,
      'currentProgress': currentProgress,
    };
  }
  
  /// Create quest from JSON
  factory Quest.fromJson(Map<String, dynamic> json) {
    return Quest(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      type: QuestType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => QuestType.daily,
      ),
      targetReps: json['targetReps'] ?? 0,
      targetTime: json['targetTime'] ?? 0,
      xpReward: json['xpReward'],
      statRewards: Map<String, int>.from(json['statRewards'] ?? {}),
      isCompleted: json['isCompleted'] ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
      expiresAt: json['expiresAt'] != null 
        ? DateTime.fromMillisecondsSinceEpoch(json['expiresAt'])
        : null,
      currentProgress: json['currentProgress'] ?? 0,
    );
  }
}

/// Types of quests available
enum QuestType {
  daily,
  urgent,
}

/// Workout session log for rep tracking
class WorkoutSession {
  String id;
  String exerciseName;
  List<WorkoutSet> sets;
  DateTime completedAt;
  int totalXpGained;
  
  WorkoutSession({
    required this.id,
    required this.exerciseName,
    required this.sets,
    DateTime? completedAt,
    this.totalXpGained = 0,
  }) : completedAt = completedAt ?? DateTime.now();
  
  /// Calculate total reps across all sets
  int get totalReps => sets.fold(0, (sum, set) => sum + set.reps);
  
  /// Calculate average RPE across all sets
  double get averageRPE => sets.isEmpty ? 0 : 
    sets.fold(0.0, (sum, set) => sum + set.rpe) / sets.length;
  
  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exerciseName': exerciseName,
      'sets': sets.map((set) => set.toJson()).toList(),
      'completedAt': completedAt.millisecondsSinceEpoch,
      'totalXpGained': totalXpGained,
    };
  }
  
  /// Create from JSON
  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    return WorkoutSession(
      id: json['id'],
      exerciseName: json['exerciseName'],
      sets: (json['sets'] as List).map((s) => WorkoutSet.fromJson(s)).toList(),
      completedAt: DateTime.fromMillisecondsSinceEpoch(json['completedAt']),
      totalXpGained: json['totalXpGained'] ?? 0,
    );
  }
}

/// Individual set within a workout session
class WorkoutSet {
  int reps;
  double rpe; // Rate of Perceived Exertion (1-10)
  int restTime; // in seconds
  
  WorkoutSet({
    required this.reps,
    required this.rpe,
    this.restTime = 0,
  });
  
  /// Calculate XP for this set based on reps and RPE
  int get xpValue => (reps * rpe * 2).round();
  
  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'reps': reps,
      'rpe': rpe,
      'restTime': restTime,
    };
  }
  
  /// Create from JSON
  factory WorkoutSet.fromJson(Map<String, dynamic> json) {
    return WorkoutSet(
      reps: json['reps'],
      rpe: json['rpe'].toDouble(),
      restTime: json['restTime'] ?? 0,
    );
  }
}
