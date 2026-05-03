import 'dart:math';
import 'package:flutter/material.dart';

import '../data/nickname.dart';
import 'nickname_dialog.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenuScreen> with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _titleController;
  late Animation<double> _titleScale;
  String? _nickname;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _titleScale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _titleController, curve: Curves.easeInOut),
    );
    _checkNickname();
  }

  Future<void> _checkNickname() async {
    final saved = await getNickname();
    if (saved == null && mounted) {
      final name = await showNicknameDialog(context);
      if (name != null) {
        await saveNickname(name);
        setState(() => _nickname = name);
      }
    } else {
      setState(() => _nickname = saved);
    }
  }

  Future<void> _editNickname() async {
    final name = await showNicknameDialog(context, currentNickname: _nickname);
    if (name != null) {
      await saveNickname(name);
      setState(() => _nickname = name);
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _navigate(String mode) {
    if (mode == 'online' || mode == 'lan') {
      // Online/LAN: go to matchmaking screen
      Navigator.pushNamed(context, '/matching', arguments: mode);
    } else {
      // AI/Local: go directly to hero select
      Navigator.pushNamed(context, '/hero_select', arguments: {
        'mode': mode,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _AnimatedBuilderWidget(
        listenable: _bgController,
        builder: (context, child) {
          final t = _bgController.value;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(sin(t * 2 * pi), -1),
                end: Alignment(-sin(t * 2 * pi), 1),
                colors: const [
                  Color(0xFF0D0D2B),
                  Color(0xFF1A0A3E),
                  Color(0xFF2A1A1A),
                  Color(0xFF0D0D2B),
                ],
              ),
            ),
            child: child,
          );
        },
        child: Stack(
              children: [
              // Floating particles
              ...List.generate(12, (i) => _Particle(index: i, controller: _bgController)),
              // Main content — scrollable, centered for all orientations
              LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = constraints.maxHeight;
                  final isLandscape = w > h;
                  final titleSize = (w * 0.08).clamp(28.0, 64.0);

                  final btnWidth = (w * 0.35).clamp(200.0, 400.0);
                  final gap = isLandscape ? 24.0 : 48.0;
                  return SizedBox.expand(
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: h),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Title
                            ScaleTransition(
                              scale: _titleScale,
                              child: ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [Color(0xFFFFD700), Color(0xFFFF6B35), Color(0xFFFFD700)],
                                ).createShader(bounds),
                                child: Text(
                                  'HERO FIGHTER',
                                  style: TextStyle(
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 6,
                                    shadows: const [
                                      Shadow(color: Color(0xAAFF6B35), blurRadius: 20),
                                      Shadow(color: Color(0x66FFD700), blurRadius: 40),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: gap),
                            _MenuButton(label: 'VS AI', icon: Icons.smart_toy, onTap: () => _navigate('ai'), width: btnWidth),
                            _MenuButton(label: 'Online Battle', icon: Icons.public, onTap: () => _navigate('online'), width: btnWidth),
                            _MenuButton(label: 'Local 2P', icon: Icons.people, onTap: () => _navigate('local'), width: btnWidth),
                            SizedBox(height: isLandscape ? 6.0 : 12.0),
                            _MenuButton(label: 'Stats', icon: Icons.bar_chart, onTap: () => Navigator.pushNamed(context, '/stats'), width: btnWidth),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Settings icon + nickname
              Positioned(
                top: 8,
                right: 8,
                child: SafeArea(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_nickname != null)
                        GestureDetector(
                          onTap: _editNickname,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person, color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  _nickname!,
                                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.edit, color: Colors.white38, size: 12),
                              ],
                            ),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white54, size: 28),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final double width;
  const _MenuButton({required this.label, required this.icon, required this.onTap, this.width = 260});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        width: width,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 20),
          label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
            ),
          ),
        ),
      ),
    );
  }
}

class _Particle extends StatelessWidget {
  final int index;
  final AnimationController controller;
  const _Particle({required this.index, required this.controller});

  @override
  Widget build(BuildContext context) {
    final rng = Random(index);
    final startX = rng.nextDouble();
    final speed = 0.3 + rng.nextDouble() * 0.7;
    final size = 2.0 + rng.nextDouble() * 4;
    return _AnimatedBuilderWidget(
      listenable: controller,
      builder: (context, _) {
        final t = (controller.value * speed + index * 0.08) % 1.0;
        final screen = MediaQuery.of(context).size;
        return Positioned(
          left: startX * screen.width,
          top: (1.0 - t) * screen.height,
          child: Opacity(
            opacity: (0.3 + 0.4 * sin(t * pi)).clamp(0.0, 1.0),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedBuilderWidget extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;
  const _AnimatedBuilderWidget({
    required super.listenable,
    required this.builder,
    this.child,
  }) : super();

  Animation<double> get animation => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) => builder(context, child);
}
