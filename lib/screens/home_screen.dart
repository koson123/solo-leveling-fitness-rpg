import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/quest.dart';
import '../services/storage_service.dart';
import '../engines/stat_engine.dart';
import '../engines/quest_engine.dart';
import '../engines/rep_logger.dart';
import '../engines/debuff_engine.dart';
import '../engines/title_engine.dart';
import '../engines/screen_time_checker.dart';
import '../engines/mobility_logger.dart';

/// Main home screen displaying player stats and daily quests
class HomeScreen extends StatefulWidget {
  final Player player;
  
  const HomeScreen({Key? key, required this.player}) : super(key: key);
  
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Player _player;
  late StorageService _storageService;
  late StatEngine _statEngine;
  late QuestEngine _questEngine;
  late RepLogger _repLogger;
  late DebuffEngine _debuffEngine;
  late TitleEngine _titleEngine;
  late ScreenTimeChecker _screenTimeChecker;
  late MobilityLogger _mobilityLogger;
  
  List<Quest> _dailyQuests = [];
  List<Quest> _urgentQuests = [];
  List<ActiveDebuff> _activeDebuffs = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _player = widget.player;
    _initializeEngines();
    _loadData();
  }
  
  /// Initialize all game engines
  void _initializeEngines() {
    _storageService = StorageService();
    _statEngine = StatEngine(_storageService);
    _questEngine = QuestEngine(_storageService);
    _debuffEngine = DebuffEngine(_storageService);
    _titleEngine = TitleEngine(_storageService);
    _repLogger = RepLogger(_storageService, _statEngine);
    _screenTimeChecker = ScreenTimeChecker(_storageService, _debuffEngine);
    _mobilityLogger = MobilityLogger(_storageService, _debuffEngine, _statEngine);
  }
  
  /// Load all necessary data
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Clear expired debuffs
      await _debuffEngine.clearExpiredDebuffs(_player);
      
      // Check for failed quests and apply penalties
      await _questEngine.checkFailedQuests(_player);
      
      // Reset daily quests if needed
      await _questEngine.resetDailyQuestsIfNeeded(_player);
      
      // Load quests
      _dailyQuests = await _storageService.loadDailyQuests();
      _urgentQuests = await _storageService.loadUrgentQuests();
      
      // Remove expired urgent quests
      _urgentQuests.removeWhere((quest) => quest.isExpired);
      await _storageService.saveUrgentQuests(_urgentQuests);
      
      // Get active debuffs
      _activeDebuffs = _debuffEngine.getActiveDebuffs(_player);
      
      // Check for new titles
      List<UnlockedTitle> newTitles = await _titleEngine.checkForNewTitles(_player);
      if (newTitles.isNotEmpty) {
        _showNewTitlesDialog(newTitles);
      }
      
      // Check if screen time prompt is needed
      if (await _screenTimeChecker.shouldPromptScreenTime(_player)) {
        _showScreenTimeDialog();
      }
      
      // Generate urgent quest randomly
      Quest? newUrgentQuest = await _questEngine.generateUrgentQuest(_player);
      if (newUrgentQuest != null) {
        _urgentQuests.add(newUrgentQuest);
        _showUrgentQuestDialog(newUrgentQuest);
      }
      
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Color(0xFF0A0E27),
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.blue,
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Color(0xFF0A0E27),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              SizedBox(height: 20),
              _buildPlayerStats(),
              SizedBox(height: 20),
              if (_activeDebuffs.isNotEmpty) ...[
                _buildDebuffsSection(),
                SizedBox(height: 20),
              ],
              _buildDailyTraining(),
              SizedBox(height: 20),
              _buildDailyQuests(),
              if (_urgentQuests.isNotEmpty) ...[
                SizedBox(height: 20),
                _buildUrgentQuests(),
              ],
              SizedBox(height: 20),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Build header with title and notifications
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Solo Leveling',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.notifications,
            color: Colors.blue,
            size: 24,
          ),
        ),
      ],
    );
  }
  
  /// Build player stats display
  Widget _buildPlayerStats() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _player.currentTitle,
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Level ${_player.level}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          LinearProgressIndicator(
            value: _player.experience / _player.experienceToNextLevel,
            backgroundColor: Colors.grey[800],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
          SizedBox(height: 4),
          Text(
            'XP: ${_player.experience}/${_player.experienceToNextLevel}',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('STR', _statEngine.getEffectiveStat(_player, StatType.strength)),
              _buildStatItem('AGI', _statEngine.getEffectiveStat(_player, StatType.agility)),
              _buildStatItem('VIT', _statEngine.getEffectiveStat(_player, StatType.vitality)),
              _buildStatItem('INT', _statEngine.getEffectiveStat(_player, StatType.intelligence)),
              _buildStatItem('LCK', _statEngine.getEffectiveStat(_player, StatType.luck)),
            ],
          ),
          if (_player.statPoints > 0) ...[
            SizedBox(height: 12),
            Text(
              'Stat Points Available: ${_player.statPoints}',
              style: TextStyle(color: Colors.yellow, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
  
  /// Build individual stat item
  Widget _buildStatItem(String label, int value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
        Text(
          value.toString(),
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  /// Build debuffs section
  Widget _buildDebuffsSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active Penalties',
            style: TextStyle(
              color: Colors.red,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          ..._activeDebuffs.map((debuff) => Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  debuff.description,
                  style: TextStyle(color: Colors.red[300], fontSize: 14),
                ),
                Text(
                  debuff.remainingTimeString,
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
  
  /// Build daily training progress
  Widget _buildDailyTraining() {
    int completedQuests = _dailyQuests.where((q) => q.isCompleted).length;
    double progress = _dailyQuests.isEmpty ? 0 : completedQuests / _dailyQuests.length;
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Training',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_dailyQuests.length - completedQuests} exercises remaining',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              strokeWidth: 6,
            ),
          ),
          SizedBox(width: 8),
          Text(
            '${(progress * 100).round()}%',
            style: TextStyle(
              color: Colors.blue,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Build daily quests section
  Widget _buildDailyQuests() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.info, color: Colors.blue, size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'DAILY QUEST',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            '[Training to become a great warrior.]',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
          SizedBox(height: 16),
          Text(
            'GOALS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          ..._dailyQuests.map((quest) => _buildQuestItem(quest)),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  'WARNING!',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Failure to complete the quest within the allotted time will incur an appropriate penalty.',
                  style: TextStyle(color: Colors.red[300], fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// Build individual quest item
  Widget _buildQuestItem(Quest quest) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              quest.name,
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          Row(
            children: [
              Text(
                quest.targetReps > 0 
                  ? '[${quest.currentProgress}/${quest.targetReps}]'
                  : '[${quest.currentProgress}/${quest.targetTime}s]',
                style: TextStyle(color: Colors.blue, fontSize: 14),
              ),
              SizedBox(width: 8),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: quest.isCompleted
                  ? Icon(Icons.check, color: Colors.blue, size: 16)
                  : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  /// Build urgent quests section
  Widget _buildUrgentQuests() {
    return Column(
      children: _urgentQuests.map((quest) => Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flash_on, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Text(
                  'URGENT QUEST',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              quest.name,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            SizedBox(height: 4),
            Text(
              quest.description,
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Expires: ${_formatTimeRemaining(quest.expiresAt!)}',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
                Text(
                  'XP: ${quest.xpReward}',
                  style: TextStyle(color: Colors.blue, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      )).toList(),
    );
  }
  
  /// Build action buttons
  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _showWorkoutDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('Log Workout'),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _showMobilityDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('Log Mobility'),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        ElevatedButton(
          onPressed: () => _showStatsDialog(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            padding: EdgeInsets.symmetric(vertical: 12),
            minimumSize: Size(double.infinity, 0),
          ),
          child: Text('View Stats & Titles'),
        ),
      ],
    );
  }
  
  /// Format time remaining for urgent quests
  String _formatTimeRemaining(DateTime expiresAt) {
    Duration remaining = expiresAt.difference(DateTime.now());
    if (remaining.inHours > 0) {
      return '${remaining.inHours}h ${remaining.inMinutes % 60}m';
    } else {
      return '${remaining.inMinutes}m';
    }
  }
  
  /// Show new titles dialog
  void _showNewTitlesDialog(List<UnlockedTitle> newTitles) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('New Title Unlocked!', style: TextStyle(color: Colors.yellow)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: newTitles.map((title) => Text(
            '🏆 ${title.title}\n${title.description}',
            style: TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Awesome!', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }
  
  /// Show screen time dialog
  void _showScreenTimeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Daily Check-in', style: TextStyle(color: Colors.white)),
        content: Text(
          'How much screen time did you have yesterday?',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _processScreenTime(2);
            },
            child: Text('< 3 hours'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _processScreenTime(5);
            },
            child: Text('3-6 hours'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _processScreenTime(8);
            },
            child: Text('> 6 hours'),
          ),
        ],
      ),
    );
  }
  
  /// Show urgent quest dialog
  void _showUrgentQuestDialog(Quest quest) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Icon(Icons.flash_on, color: Colors.orange),
            SizedBox(width: 8),
            Text('Urgent Quest!', style: TextStyle(color: Colors.orange)),
          ],
        ),
        content: Text(
          '${quest.name}\n\n${quest.description}\n\nReward: ${quest.xpReward} XP',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Accept Challenge!', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }
  
  /// Show workout logging dialog
  void _showWorkoutDialog() {
    // This would open a detailed workout logging screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Workout logging screen would open here')),
    );
  }
  
  /// Show mobility logging dialog
  void _showMobilityDialog() {
    // This would open a mobility logging screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Mobility logging screen would open here')),
    );
  }
  
  /// Show stats and titles dialog
  void _showStatsDialog() {
    // This would open a detailed stats screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Stats & titles screen would open here')),
    );
  }
  
  /// Process screen time input
  Future<void> _processScreenTime(int hours) async {
    ScreenTimeResult result = await _screenTimeChecker.processScreenTime(_player, hours);
    
    String message = result.message;
    if (result.hasReward) {
      await _statEngine.addExperience(_player, result.xpBonus);
      message += '\n+${result.xpBonus} XP bonus!';
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: result.hasPenalty ? Colors.red : Colors.green,
      ),
    );
    
    setState(() {
      _activeDebuffs = _debuffEngine.getActiveDebuffs(_player);
    });
  }
}
