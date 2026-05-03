import 'dart:ui';

import 'package:flame/components.dart';

import '../fighter_game.dart';

/// Debug overlay showing FPS, particle count, and projectile count.
/// Only visible when [visible] is true. Toggle with backtick (`) key.
class DebugOverlay extends PositionComponent with HasGameReference<FighterGame> {
  bool visible = false;

  // FPS tracking
  double _fpsAccumulator = 0;
  int _fpsFrameCount = 0;
  double _currentFps = 0;
  static const double _fpsUpdateInterval = 0.5; // update every 0.5s

  // Frame time tracking
  double _maxDt = 0;
  double _dtResetTimer = 0;
  static const double _dtResetInterval = 2.0; // reset max every 2s

  DebugOverlay() {
    priority = 200; // Above everything
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!visible) return;

    // FPS calculation (rolling average)
    _fpsAccumulator += dt;
    _fpsFrameCount++;
    if (_fpsAccumulator >= _fpsUpdateInterval) {
      _currentFps = _fpsFrameCount / _fpsAccumulator;
      _fpsAccumulator = 0;
      _fpsFrameCount = 0;
    }

    // Track max frame time
    if (dt > _maxDt) _maxDt = dt;
    _dtResetTimer += dt;
    if (_dtResetTimer >= _dtResetInterval) {
      _dtResetTimer = 0;
      _maxDt = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!visible) return;

    final particleCount = game.particleSystem.activeCount;
    final poolSize = game.particleSystem.poolSize;
    final projectileCount = game.projectiles.length;
    final maxMs = (_maxDt * 1000).toStringAsFixed(1);

    final lines = [
      'FPS: ${_currentFps.toStringAsFixed(1)}',
      'Frame max: ${maxMs}ms',
      'Particles: $particleCount / $poolSize',
      'Projectiles: $projectileCount',
      'State: ${game.gameState.name}',
    ];

    // Background panel
    const panelX = 4.0;
    const panelY = 70.0;
    const lineHeight = 16.0;
    const panelPadding = 6.0;
    final panelHeight = lines.length * lineHeight + panelPadding * 2;
    const panelWidth = 160.0;

    final bgPaint = Paint()..color = const Color(0xAA000000);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(panelX, panelY, panelWidth, panelHeight),
        const Radius.circular(4),
      ),
      bgPaint,
    );

    // Border
    final borderPaint = Paint()
      ..color = const Color(0x44FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(panelX, panelY, panelWidth, panelHeight),
        const Radius.circular(4),
      ),
      borderPaint,
    );

    // Text lines
    for (int i = 0; i < lines.length; i++) {
      // Color-code FPS
      Color textColor;
      if (i == 0) {
        textColor = _currentFps >= 55
            ? const Color(0xFF44FF44)
            : _currentFps >= 30
                ? const Color(0xFFFFAA00)
                : const Color(0xFFFF4444);
      } else {
        textColor = const Color(0xFFCCCCCC);
      }

      final builder = ParagraphBuilder(ParagraphStyle(
        textAlign: TextAlign.left,
        fontSize: 11,
      ))
        ..pushStyle(TextStyle(
          color: textColor,
          fontSize: 11,
        ))
        ..addText(lines[i]);
      final paragraph = builder.build();
      paragraph.layout(const ParagraphConstraints(width: panelWidth - panelPadding * 2));
      canvas.drawParagraph(
        paragraph,
        Offset(panelX + panelPadding, panelY + panelPadding + i * lineHeight),
      );
    }
  }

  void toggle() {
    visible = !visible;
  }
}
