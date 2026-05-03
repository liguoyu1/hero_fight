import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/heroes/all_heroes.dart';
import 'screens/main_menu.dart';
import 'screens/hero_select.dart';
import 'screens/matching_screen.dart';
import 'screens/game_screen.dart';
import 'screens/stats_screen.dart';
import 'network/network_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 全局强制横屏
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  registerAllHeroes();
  runApp(const HeroFighterApp());
}

class HeroFighterApp extends StatelessWidget {
  const HeroFighterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hero Fighter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.dark(
          primary: Colors.red.shade700,
          secondary: Colors.redAccent,
          surface: const Color(0xFF1A1A1A),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.red.shade900,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade800,
            foregroundColor: Colors.white,
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (_) => const MainMenuScreen(),
            );
          case '/matching':
            final mode = settings.arguments as String? ?? 'lan';
            // 使用 AppConfig 中配置的服务器地址，不再从浏览器地址推断
            return MaterialPageRoute(
              builder: (_) => MatchingScreen(
                  mode: mode,
                ),
            );
          case '/hero_select':
            final args = settings.arguments;
            String mode = 'local';
            NetworkManager? network;
            int mySlot = 0;
            if (args is Map<String, dynamic>) {
              mode = args['mode'] as String? ?? 'local';
              if (args['network'] != null) {
                network = args['network'] as NetworkManager?;
              }
              mySlot = args['mySlot'] as int? ?? 0;
            } else if (args is String) {
              mode = args;
            }
            return MaterialPageRoute(
              builder: (_) => HeroSelectScreen(
                mode: mode,
                network: network,
                mySlot: mySlot,
              ),
            );
          case '/game':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => GameScreen(
                hero1Id: args['hero1'] as String,
                hero2Id: args['hero2'] as String,
                mode: args['mode'] as String,
              ),
            );
          case '/stats':
            return MaterialPageRoute(
              builder: (_) => const StatsScreen(),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const MainMenuScreen(),
            );
        }
      },
    );
  }
}
