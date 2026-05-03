import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import 'fighter.dart';

/// Virtual touch controls for mobile play
class TouchControls extends PositionComponent with DragCallbacks, TapCallbacks {
  // Output state
  final FighterInput input = FighterInput();

  // Joystick state
  Vector2 _joystickCenter = Vector2.zero();
  Vector2 _joystickKnob = Vector2.zero();
  bool _joystickActive = false;
  int? _joystickPointerId;

  // Button states
  bool _attackPressed = false;
  bool _skillPressed = false;
  bool _jumpPressed = false;

  // Layout constants
  static const double joystickRadius = 50;
  static const double knobRadius = 22;
  static const double buttonRadius = 28;
  static const double deadZone = 10;

  // Screen-relative positions (set in onGameResize)
  late Vector2 _joyPos;
  late Vector2 _atkPos;
  late Vector2 _sklPos;
  late Vector2 _jmpPos;

  double _screenW = 1280;
  double _screenH = 600;

  Vector2 get joyPos => _joyPos;
  Vector2 get atkPos => _atkPos;
  Vector2 get sklPos => _sklPos;
  Vector2 get jmpPos => _jmpPos;

  TouchControls() {
    _joyPos = Vector2(100, 480);
    _atkPos = Vector2(1140, 480);
    _sklPos = Vector2(1200, 420);
    _jmpPos = Vector2(1080, 420);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _screenW = size.x;
    _screenH = size.y;
    final rightEdge = _screenW;
    final bottom = _screenH;
    final btnR = buttonRadius;
    final joyR = joystickRadius;
    // 摇杆：左下角，保证在左半屏内
    _joyPos = Vector2(
      (joyR + 20).clamp(joyR, _screenW / 2 - joyR),
      bottom - joyR - 20,
    );
    // 三个按钮：右下角，间距自适应
    final spacing = (btnR * 2 + 8).clamp(btnR * 2 + 4, 80.0);
    final baseX = rightEdge - btnR - 12;
    final baseY = bottom - btnR - 20;
    _atkPos = Vector2(baseX, baseY);
    _sklPos = Vector2(baseX - spacing, baseY - spacing * 0.8);
    _jmpPos = Vector2(baseX - spacing * 2, baseY);
    // 窄屏：缩小间距以适应
    final maxX = rightEdge - btnR - 4;
    final halfW = _screenW / 2 + btnR;
    if (_jmpPos.x < halfW || _atkPos.x > maxX) {
      final availW = maxX - halfW;
      final newSpacing = availW / 2;
      _atkPos.x = maxX;
      _sklPos.x = maxX - newSpacing;
      _jmpPos.x = halfW;
      _sklPos.y = baseY - (newSpacing * 0.8).clamp(btnR + 4, spacing * 0.8);
    }
    this.size = size;
    position = Vector2.zero();
  }

  @override
  bool containsLocalPoint(Vector2 point) => true;

  void _updateInputFromJoystick() {
    if (!_joystickActive) {
      input.left = false;
      input.right = false;
      input.up = false;
      input.down = false;
      return;
    }
    final delta = _joystickKnob - _joystickCenter;
    if (delta.length < deadZone) {
      input.left = false;
      input.right = false;
      input.up = false;
      input.down = false;
      return;
    }
    input.left = delta.x < -deadZone;
    input.right = delta.x > deadZone;
    input.up = delta.y < -deadZone;
    input.down = delta.y > deadZone;
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    final pos = event.localPosition;
    // Left half = joystick
    if (pos.x < _screenW / 2) {
      _joystickActive = true;
      _joystickPointerId = event.pointerId;
      _joystickCenter = pos.clone();
      _joystickKnob = pos.clone();
    }
    _checkButtonPress(pos, true);
    _syncInput();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (_joystickActive && event.pointerId == _joystickPointerId) {
      _joystickKnob = event.localStartPosition + event.localDelta;
      // Clamp knob to joystick radius
      final delta = _joystickKnob - _joystickCenter;
      if (delta.length > joystickRadius) {
        _joystickKnob = _joystickCenter + delta.normalized() * joystickRadius;
      }
    }
    _syncInput();
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (event.pointerId == _joystickPointerId) {
      _joystickActive = false;
      _joystickPointerId = null;
      _joystickKnob = _joystickCenter.clone();
    }
    _attackPressed = false;
    _skillPressed = false;
    _jumpPressed = false;
    _syncInput();
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    _checkButtonPress(event.localPosition, true);
    _syncInput();
  }

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);
    _attackPressed = false;
    _skillPressed = false;
    _jumpPressed = false;
    _syncInput();
  }

  void _checkButtonPress(Vector2 pos, bool pressed) {
    if ((pos - _atkPos).length < buttonRadius * 1.5) {
      _attackPressed = pressed;
    }
    if ((pos - _sklPos).length < buttonRadius * 1.5) {
      _skillPressed = pressed;
    }
    if ((pos - _jmpPos).length < buttonRadius * 1.5) {
      _jumpPressed = pressed;
    }
  }

  void _syncInput() {
    _updateInputFromJoystick();
    input.attack = _attackPressed;
    input.skill = _skillPressed;
    // Jump button still sets up for backward compat (mapped to up movement)
    if (_jumpPressed) input.up = true;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Joystick base
    final basePaint = Paint()..color = const Color(0x44FFFFFF);
    final knobPaint = Paint()..color = const Color(0x88FFFFFF);
    final center = _joystickActive ? _joystickCenter : _joyPos;
    canvas.drawCircle(center.toOffset(), joystickRadius, basePaint);
    final knob = _joystickActive ? _joystickKnob : _joyPos;
    canvas.drawCircle(knob.toOffset(), knobRadius, knobPaint);

    // Buttons
    _drawButton(canvas, _atkPos, 'A', _attackPressed, const Color(0xCCFF4444));
    _drawButton(canvas, _sklPos, 'S', _skillPressed, const Color(0xCC4488FF));
    _drawButton(canvas, _jmpPos, 'J', _jumpPressed, const Color(0xCC44CC44));
  }

  void _drawButton(Canvas canvas, Vector2 pos, String label, bool pressed, Color color) {
    final bgPaint = Paint()..color = pressed ? color : color.withValues(alpha: 0.4);
    final borderPaint = Paint()
      ..color = const Color(0x88FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(pos.toOffset(), buttonRadius, bgPaint);
    canvas.drawCircle(pos.toOffset(), buttonRadius, borderPaint);

    // Label
    final builder = ParagraphBuilder(ParagraphStyle(
      textAlign: TextAlign.center,
      fontSize: 18,
    ))
      ..pushStyle(TextStyle(
        color: const Color(0xFFFFFFFF),
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ))
      ..addText(label);
    final paragraph = builder.build();
    paragraph.layout(const ParagraphConstraints(width: 40));
    canvas.drawParagraph(
      paragraph,
      Offset(pos.x - 20, pos.y - 10),
    );
  }
}
