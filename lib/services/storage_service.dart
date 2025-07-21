import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/player.dart';
import '../models/quest.dart';

/// Service for handling all local storage operations using SharedPreferences
class StorageService {
  static SharedPreferences? _prefs;
  
  // Storage keys
  static const String _playerKey = 'player_data';
  static const String _dailyQuestsKey = 'daily_quests';
  static const String _urgentQuestsKey = 'urgent_quests';
  static const String _workoutSessionsKey = 'workout_sessions';
  static const String _mobilitySessionsKey = 'mobility_sessions';
  static const String _lastDailyQuestResetKey = 'last_daily_quest_reset';
  static const String _screenTimeDataKey = 'screen_time_data';
  
  /// Initialize SharedPreferences
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }
  
  /// Save player data to local storage
  Future<void> savePlayer(Player player) async {
    await _prefs?.setString(_playerKey, jsonEncode(player.toJson()));
  }
  
  /// Load player data from local storage
  Future<Player> loadPlayer() async {
    final playerJson = _prefs?.getString(_playerKey);
    if (playerJson != null) {
      return Player.fromJson(jsonDecode(playerJson));
    }
    return Player(); // Return default player if no data exists
  }
  
  /// Save daily quests to local storage
  Future<void> saveDailyQuests(List<Quest> quests) async {
    final questsJson = quests.map((q) => q.toJson()).toList();
    await _prefs?.setString(_dailyQuestsKey, jsonEncode(questsJson));
  }
  
  /// Load daily quests from local storage
  Future<List<Quest>> loadDailyQuests() async {
    final questsJson = _prefs?.getString(_dailyQuestsKey);
    if (questsJson != null) {
      final List<dynamic> questsList = jsonDecode(questsJson);
      return questsList.map((q) => Quest.fromJson(q)).toList();
    }
    return [];
  }
  
  /// Save urgent quests to local storage
  Future<void> saveUrgentQuests(List<Quest> quests) async {
    final questsJson = quests.map((q) => q.toJson()).toList();
    await _prefs?.setString(_urgentQuestsKey, jsonEncode(questsJson));
  }
  
  /// Load urgent quests from local storage
  Future<List<Quest>> loadUrgentQuests() async {
    final questsJson = _prefs?.getString(_urgentQuestsKey);
    if (questsJson != null) {
      final List<dynamic> questsList = jsonDecode(questsJson);
      return questsList.map((q) => Quest.fromJson(q)).toList();
    }
    return [];
  }
  
  /// Save workout sessions to local storage
  Future<void> saveWorkoutSessions(List<WorkoutSession> sessions) async {
    final sessionsJson = sessions.map((s) => s.toJson()).toList();
    await _prefs?.setString(_workoutSessionsKey, jsonEncode(sessionsJson));
  }
  
  /// Load workout sessions from local storage
  Future<List<WorkoutSession>> loadWorkoutSessions() async {
    final sessionsJson = _prefs?.getString(_workoutSessionsKey);
    if (sessionsJson != null) {
      final List<dynamic> sessionsList = jsonDecode(sessionsJson);
      return sessionsList.map((s) => WorkoutSession.fromJson(s)).toList();
    }
    return [];
  }
  
  /// Save mobility sessions to local storage
  Future<void> saveMobilitySessions(List<MobilitySession> sessions) async {
    final sessionsJson = sessions.map((s) => s.toJson()).toList();
    await _prefs?.setString(_mobilitySessionsKey, jsonEncode(sessionsJson));
  }
  
  /// Load mobility sessions from local storage
  Future<List<MobilitySession>> loadMobilitySessions() async {
    final sessionsJson = _prefs?.getString(_mobilitySessionsKey);
    if (sessionsJson != null) {
      final List<dynamic> sessionsList = jsonDecode(sessionsJson);
      return sessionsList.map((s) => MobilitySession.fromJson(s)).toList();
    }
    return [];
  }
  
  /// Save last daily quest reset timestamp
  Future<void> saveLastDailyQuestReset(DateTime timestamp) async {
    await _prefs?.setInt(_lastDailyQuestResetKey, timestamp.millisecondsSinceEpoch);
  }
  
  /// Load last daily quest reset timestamp
  Future<DateTime?> loadLastDailyQuestReset() async {
    final timestamp = _prefs?.getInt(_lastDailyQuestResetKey);
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }
  
  /// Save screen time data
  Future<void> saveScreenTimeData(Map<String, dynamic> data) async {
    await _prefs?.setString(_screenTimeDataKey, jsonEncode(data));
  }
  
  /// Load screen time data
  Future<Map<String, dynamic>> loadScreenTimeData() async {
    final dataJson = _prefs?.getString(_screenTimeDataKey);
    if (dataJson != null) {
      return Map<String, dynamic>.from(jsonDecode(dataJson));
    }
    return {};
  }
  
  /// Clear all stored data (for reset functionality)
  Future<void> clearAllData() async {
    await _prefs?.clear();
  }
  
  /// Check if this is the first app launch
  Future<bool> isFirstLaunch() async {
    return _prefs?.getString(_playerKey) == null;
  }
}

/// Mobility/stretching session model
class MobilitySession {
  String id;
  String activityName;
  int durationMinutes;
  DateTime completedAt;
  String notes;
  
  MobilitySession({
    required this.id,
    required this.activityName,
    required this.durationMinutes,
    DateTime? completedAt,
    this.notes = '',
  }) : completedAt = completedAt ?? DateTime.now();
  
  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'activityName': activityName,
      'durationMinutes': durationMinutes,
      'completedAt': completedAt.millisecondsSinceEpoch,
      'notes': notes,
    };
  }
  
  /// Create from JSON
  factory MobilitySession.fromJson(Map<String, dynamic> json) {
    return MobilitySession(
      id: json['id'],
      activityName: json['activityName'],
      durationMinutes: json['durationMinutes'],
      completedAt: DateTime.fromMillisecondsSinceEpoch(json['completedAt']),
      notes: json['notes'] ?? '',
    );
  }
}
