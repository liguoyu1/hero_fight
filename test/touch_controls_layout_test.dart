import 'package:flutter_test/flutter_test.dart';
import 'package:flame/components.dart';
import 'package:hero_fighter/game/components/touch_controls.dart';

void main() {
  final screens = {
    'iPhone SE (375x667)': Vector2(375, 667),
    'iPhone 14 (390x844)': Vector2(390, 844),
    'iPhone 14 Pro Max (430x932)': Vector2(430, 932),
    'iPad (768x1024)': Vector2(768, 1024),
    'iPad Pro 12.9 (1024x1366)': Vector2(1024, 1366),
    'Android 360x800': Vector2(360, 800),
    'Android 412x915': Vector2(412, 915),
    'Web 1280x720': Vector2(1280, 720),
    'Web 1920x1080': Vector2(1920, 1080),
    'Web 2560x1440': Vector2(2560, 1440),
    'Landscape phone 844x390': Vector2(844, 390),
    'Landscape tablet 1024x768': Vector2(1024, 768),
  };

  group('TouchControls 布局验证', () {
    for (final entry in screens.entries) {
      final name = entry.key;
      final size = entry.value;

      test('[$name] 按钮在屏幕内且不重叠', () {
        final controls = TouchControls();
        controls.onGameResize(size);

        final w = size.x;
        final h = size.y;
        const r = TouchControls.buttonRadius;
        const jr = TouchControls.joystickRadius;

        final joyPos = controls.joyPos;
        final atkPos = controls.atkPos;
        final sklPos = controls.sklPos;
        final jmpPos = controls.jmpPos;

        // 摇杆在屏幕内
        expect(joyPos.x - jr, greaterThanOrEqualTo(0),
            reason: '[$name] 摇杆左边超出屏幕');
        expect(joyPos.y - jr, greaterThanOrEqualTo(0),
            reason: '[$name] 摇杆上边超出屏幕');
        expect(joyPos.x + jr, lessThanOrEqualTo(w),
            reason: '[$name] 摇杆右边超出屏幕');
        expect(joyPos.y + jr, lessThanOrEqualTo(h),
            reason: '[$name] 摇杆下边超出屏幕');

        // 三个按钮都在屏幕内
        for (final pos in [atkPos, sklPos, jmpPos]) {
          expect(pos.x - r, greaterThanOrEqualTo(0),
              reason: '[$name] 按钮左边超出屏幕 pos=$pos');
          expect(pos.y - r, greaterThanOrEqualTo(0),
              reason: '[$name] 按钮上边超出屏幕 pos=$pos');
          expect(pos.x + r, lessThanOrEqualTo(w),
              reason: '[$name] 按钮右边超出屏幕 pos=$pos');
          expect(pos.y + r, lessThanOrEqualTo(h),
              reason: '[$name] 按钮下边超出屏幕 pos=$pos');
        }

        // 按钮之间不重叠（圆心距 > 两半径之和）
        final minDist = r * 2 + 4;
        expect((atkPos - sklPos).length, greaterThan(minDist),
            reason: '[$name] 攻击键与技能键重叠');
        expect((atkPos - jmpPos).length, greaterThan(minDist),
            reason: '[$name] 攻击键与跳跃键重叠');
        expect((sklPos - jmpPos).length, greaterThan(minDist),
            reason: '[$name] 技能键与跳跃键重叠');

        // 摇杆在左半屏，按钮在右半屏
        expect(joyPos.x, lessThan(w / 2),
            reason: '[$name] 摇杆不在左半屏');
        expect(atkPos.x, greaterThan(w / 2),
            reason: '[$name] 攻击键不在右半屏');
        expect(sklPos.x, greaterThan(w / 2),
            reason: '[$name] 技能键不在右半屏');
        expect(jmpPos.x, greaterThan(w / 2),
            reason: '[$name] 跳跃键不在右半屏');

        // 按钮在屏幕下方 1/3 区域（拇指可达区）
        expect(joyPos.y, greaterThan(h * 0.5),
            reason: '[$name] 摇杆位置太高');
        expect(atkPos.y, greaterThan(h * 0.5),
            reason: '[$name] 攻击键位置太高');
      });
    }

    test('极小屏幕 (320x480) 按钮不超出边界', () {
      final controls = TouchControls();
      controls.onGameResize(Vector2(320, 480));
      final w = 320.0;
      final h = 480.0;
      const r = TouchControls.buttonRadius;

      for (final pos in [controls.atkPos, controls.sklPos, controls.jmpPos]) {
        expect(pos.x - r, greaterThanOrEqualTo(0));
        expect(pos.x + r, lessThanOrEqualTo(w));
        expect(pos.y - r, greaterThanOrEqualTo(0));
        expect(pos.y + r, lessThanOrEqualTo(h));
      }
    });

    test('超宽屏 (2560x800) 按钮不超出边界', () {
      final controls = TouchControls();
      controls.onGameResize(Vector2(2560, 800));
      const r = TouchControls.buttonRadius;
      for (final pos in [controls.atkPos, controls.sklPos, controls.jmpPos]) {
        expect(pos.x + r, lessThanOrEqualTo(2560.0));
        expect(pos.y + r, lessThanOrEqualTo(800.0));
      }
    });
  });
}
