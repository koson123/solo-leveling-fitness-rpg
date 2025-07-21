/// Player model containing all character stats and progression
class Player {
  int level;
  int experience;
  int statPoints;
  
  // Base stats
  int strength;
  int agility;
  int vitality;
  int intelligence;
  int luck;
  
  // Current debuffs with expiration timestamps
  Map<String, int> debuffs;
  
  // Quest streaks and achievements
  int dailyQuestStreak;
  int totalRepsCompleted;
  List<String> unlockedTitles;
  String currentTitle;
  
  // Screen time tracking
  DateTime lastScreenTimeCheck;
  
  Player({
    this.level = 1,
    this.experience = 0,
    this.statPoints = 0,
    this.strength = 10,
    this.agility = 10,
    this.vitality = 10,
    this.intelligence = 10,
    this.luck = 10,
    Map<String, int>? debuffs,
    this.dailyQuestStreak = 0,
    this.totalRepsCompleted = 0,
    List<String>? unlockedTitles,
    this.currentTitle = "Novice",
    DateTime? lastScreenTimeCheck,
  }) : debuffs = debuffs ?? {},
       unlockedTitles = unlockedTitles ?? ["Novice"],
       lastScreenTimeCheck = lastScreenTimeCheck ?? DateTime.now();

  /// Calculate experience needed for next level
  int get experienceToNextLevel => level * 100;
  
  /// Get total stat points (base + allocated)
  int get totalStats => strength + agility + vitality + intelligence + luck;
  
  /// Convert player to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'experience': experience,
      'statPoints': statPoints,
      'strength': strength,
      'agility': agility,
      'vitality': vitality,
      'intelligence': intelligence,
      'luck': luck,
      'debuffs': debuffs,
      'dailyQuestStreak': dailyQuestStreak,
      'totalRepsCompleted': totalRepsCompleted,
      'unlockedTitles': unlockedTitles,
      'currentTitle': currentTitle,
      'lastScreenTimeCheck': lastScreenTimeCheck.millisecondsSinceEpoch,
    };
  }
  
  /// Create player from JSON
  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      level: json['level'] ?? 1,
      experience: json['experience'] ?? 0,
      statPoints: json['statPoints'] ?? 0,
      strength: json['strength'] ?? 10,
      agility: json['agility'] ?? 10,
      vitality: json['vitality'] ?? 10,
      intelligence: json['intelligence'] ?? 10,
      luck: json['luck'] ?? 10,
      debuffs: Map<String, int>.from(json['debuffs'] ?? {}),
      dailyQuestStreak: json['dailyQuestStreak'] ?? 0,
      totalRepsCompleted: json['totalRepsCompleted'] ?? 0,
      unlockedTitles: List<String>.from(json['unlockedTitles'] ?? ["Novice"]),
      currentTitle: json['currentTitle'] ?? "Novice",
      lastScreenTimeCheck: DateTime.fromMillisecondsSinceEpoch(
        json['lastScreenTimeCheck'] ?? DateTime.now().millisecondsSinceEpoch
      ),
    );
  }
}
