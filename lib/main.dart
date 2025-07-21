import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';
import 'models/player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize storage service
  final storageService = StorageService();
  await storageService.init();
  
  // Load player data on startup
  final player = await storageService.loadPlayer();
  
  runApp(FitnessRPGApp(player: player));
}

class FitnessRPGApp extends StatelessWidget {
  final Player player;
  
  const FitnessRPGApp({Key? key, required this.player}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solo Leveling Fitness',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomeScreen(player: player),
    );
  }
}
