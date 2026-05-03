import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 新手引导覆盖层 — 4步教学：移动→攻击→技能→开战
///
/// 首次进入战斗时自动显示，完成后通过 SharedPreferences 记录，
/// 后续不再弹出。键盘任意键/ESC/触摸任意位置推进或跳过。
class TutorialOverlay extends PositionComponent with TapCallbacks {
  static const String _prefKey = 'tutorial_completed';

  bool _visible = false;
  bool get isVisible => _visible;

  int _step = 0; // 0-3: 四步引导
  static const int _totalSteps = 4;

  // 是否正在淡入/淡出
  double _fadeAlpha = 0;
  static const double _fadeSpeed = 4.0; // 每秒淡入速度

  // 步骤内容
  static const List<_TutorialStep> _steps = [
    _TutorialStep(
      title: 'Step 1: Move',
      descKeyboard: 'WASD to move\nArrow keys for 8 directions',
      descTouch: 'Left virtual joystick\nDrag to move',
      icon: '🕹️',
    ),
    _TutorialStep(
      title: 'Step 2: Attack',
      descKeyboard: 'J to attack\nTap repeatedly for combos',
      descTouch: 'Right Attack button\nTap for combos',
      icon: '⚔️',
    ),
    _TutorialStep(
      title: 'Step 3: Skill',
      descKeyboard: 'K for hero skill\nWatch the cooldown',
      descTouch: 'Right Skill button\nUse after cooldown',
      icon: '✨',
    ),
    _TutorialStep(
      title: 'Ready to Fight!',
      descKeyboard: 'Defeat your opponent\nESC to pause',
      descTouch: 'Defeat your opponent\nGood luck!',
      icon: '🏆',
    ),
  ];

  /// 检查是否需要显示引导，如果需要则显示
  Future<void> checkAndShow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completed = prefs.getBool(_prefKey) ?? false;
      if (!completed) {
        show();
      }
    } catch (_) {
      // SharedPreferences 不可用（测试环境等），直接显示
      show();
    }
  }

  /// 强制显示引导（忽略已完成标记）
  void show() {
    _visible = true;
    _step = 0;
    _fadeAlpha = 0;
  }

  /// 隐藏引导
  void hide() {
    _visible = false;
    _step = 0;
    _fadeAlpha = 0;
  }

  /// 推进到下一步，如果已是最后一步则完成引导
  void advance() {
    if (!_visible) return;
    _step++;
    if (_step >= _totalSteps) {
      _complete();
    }
  }

  /// 直接跳过全部引导
  void skip() {
    if (!_visible) return;
    _complete();
  }

  void _complete() {
    _visible = false;
    _step = 0;
    _fadeAlpha = 0;
    _markCompleted();
  }

  Future<void> _markCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, true);
    } catch (_) {
      // 忽略存储失败
    }
  }

  /// 重置引导状态（清除已完成标记）
  static Future<void> resetTutorial() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
    } catch (_) {
      // 忽略
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_visible && _fadeAlpha < 1.0) {
      _fadeAlpha = (_fadeAlpha + _fadeSpeed * dt).clamp(0.0, 1.0);
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // In viewport, size is the actual widget pixel size (e.g. 390×844)
    this.size = size;
    position = Vector2.zero();
  }

  @override
  bool containsLocalPoint(Vector2 point) => _visible;

  @override
  void onTapUp(TapUpEvent event) {
    advance();
  }

  @override
  void render(Canvas canvas) {
    if (!_visible || _fadeAlpha <= 0) return;

    final screenW = size.x;
    final screenH = size.y;
    if (screenW <= 0 || screenH <= 0) return;

    // 半透明黑色背景
    final bgPaint = Paint()
      ..color = Color.fromARGB((180 * _fadeAlpha).toInt(), 0, 0, 0);
    canvas.drawRect(Rect.fromLTWH(0, 0, screenW, screenH), bgPaint);

    if (_step >= _totalSteps) return;
    final step = _steps[_step];

    // 中央内容面板 — 自适应屏幕尺寸
    final panelW = (screenW * 0.65).clamp(280.0, 600.0);
    final panelH = (panelW * 0.55).clamp(180.0, 340.0);
    final panelX = (screenW - panelW) / 2;
    final panelY = (screenH - panelH) / 2;

    // 面板背景
    final panelPaint = Paint()
      ..color = Color.fromARGB((220 * _fadeAlpha).toInt(), 20, 20, 40);
    final panelRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(panelX, panelY, panelW, panelH),
      const Radius.circular(16),
    );
    canvas.drawRRect(panelRRect, panelPaint);

    // 面板边框
    final borderPaint = Paint()
      ..color = Color.fromARGB((180 * _fadeAlpha).toInt(), 100, 180, 255)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(panelRRect, borderPaint);

    // 步骤指示器 (圆点)
    _drawStepIndicator(canvas, screenW, panelY + panelH - 30);

    // 标题
    _drawText(
      canvas,
      step.title,
      panelX + panelW / 2,
      panelY + 30,
      fontSize: 24,
      color: Color.fromARGB((255 * _fadeAlpha).toInt(), 100, 200, 255),
      center: true,
    );

    // 操作说明 — 根据平台显示不同内容
    // 简化处理：同时显示键盘和触屏说明
    _drawText(
      canvas,
      '⌨️ 键盘',
      panelX + 40,
      panelY + 75,
      fontSize: 14,
      color: Color.fromARGB((200 * _fadeAlpha).toInt(), 180, 180, 180),
    );
    _drawMultilineText(
      canvas,
      step.descKeyboard,
      panelX + 40,
      panelY + 100,
      fontSize: 16,
      color: Color.fromARGB((255 * _fadeAlpha).toInt(), 255, 255, 255),
      lineHeight: 24,
    );

    _drawText(
      canvas,
      '📱 触屏',
      panelX + panelW / 2 + 20,
      panelY + 75,
      fontSize: 14,
      color: Color.fromARGB((200 * _fadeAlpha).toInt(), 180, 180, 180),
    );
    _drawMultilineText(
      canvas,
      step.descTouch,
      panelX + panelW / 2 + 20,
      panelY + 100,
      fontSize: 16,
      color: Color.fromARGB((255 * _fadeAlpha).toInt(), 255, 255, 255),
      lineHeight: 24,
    );

    // 底部提示
    _drawText(
      canvas,
      'Tap to continue  |  ESC to skip',
      screenW / 2,
      panelY + panelH + 20,
      fontSize: 13,
      color: Color.fromARGB(
        ((120 + 60 * (_fadeAlpha)).toInt()).clamp(0, 255),
        200,
        200,
        200,
      ),
      center: true,
    );
  }

  void _drawStepIndicator(Canvas canvas, double screenW, double y) {
    final dotRadius = 5.0;
    final dotSpacing = 20.0;
    final totalW = (_totalSteps - 1) * dotSpacing;
    final startX = (screenW - totalW) / 2;

    for (int i = 0; i < _totalSteps; i++) {
      final isActive = i == _step;
      final isDone = i < _step;
      final paint = Paint()
        ..color = isActive
            ? Color.fromARGB((255 * _fadeAlpha).toInt(), 100, 200, 255)
            : isDone
                ? Color.fromARGB((200 * _fadeAlpha).toInt(), 80, 160, 80)
                : Color.fromARGB((100 * _fadeAlpha).toInt(), 100, 100, 100);
      canvas.drawCircle(
        Offset(startX + i * dotSpacing, y),
        isActive ? dotRadius + 1 : dotRadius,
        paint,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    double x,
    double y, {
    double fontSize = 16,
    Color color = const Color(0xFFFFFFFF),
    bool center = false,
  }) {
    final builder = ParagraphBuilder(ParagraphStyle(
      textAlign: center ? TextAlign.center : TextAlign.left,
      fontSize: fontSize,
    ))
      ..pushStyle(TextStyle(color: color, fontSize: fontSize))
      ..addText(text);
    final paragraph = builder.build()
      ..layout(const ParagraphConstraints(width: 400));
    final dx = center ? x - paragraph.maxIntrinsicWidth / 2 : x;
    canvas.drawParagraph(paragraph, Offset(dx, y));
  }

  void _drawMultilineText(
    Canvas canvas,
    String text,
    double x,
    double y, {
    double fontSize = 16,
    Color color = const Color(0xFFFFFFFF),
    double lineHeight = 22,
  }) {
    final lines = text.split('\n');
    for (int i = 0; i < lines.length; i++) {
      _drawText(canvas, lines[i], x, y + i * lineHeight,
          fontSize: fontSize, color: color);
    }
  }
}

class _TutorialStep {
  final String title;
  final String descKeyboard;
  final String descTouch;
  final String icon;

  const _TutorialStep({
    required this.title,
    required this.descKeyboard,
    required this.descTouch,
    required this.icon,
  });
}
