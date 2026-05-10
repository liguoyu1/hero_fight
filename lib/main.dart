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
  try {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  } catch (_) {} // Desktop doesn't support these
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
        scaffoldBackgroundColor: const Color(0xFF0D0D2B),
        colorScheme: ColorScheme.dark(
          primary: Colors.red,
          secondary: Colors.redAccent,
          surface: const Color(0xFF2A1A1A),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF8B0000),
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFCC0000),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white, fontSize: 16),
          bodyMedium: TextStyle(color: Color(0xFFDDDDDD), fontSize: 14),
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
