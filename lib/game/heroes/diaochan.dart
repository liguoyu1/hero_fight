import 'dart:math';
import 'package:flutter/material.dart';
import 'hero_data.dart';

/// 貂蝉 - 刺客：极速3连击，范围小但快，方向攻击带减速
class DiaochanHero extends HeroData {
  DiaochanHero()
      : super(
          id: 'diaochan',
          name: 'Diao Chan',
          nameEn: 'Diao Chan',
          title: 'The Peerless Beauty',
          titleEn: 'The Peerless Beauty',
          faction: Faction.threeKingdoms,
          colorValue: 0xFFFF66CC,
          skillName: 'Captivating Dance',
          skillNameEn: 'Captivating Dance',
          skillDesc: 'Launch 5 petals in all directions, each dealing 90 damage and slowing enemies',
          skillDescEn: 'Launch 5 petals in all directions, each dealing 90 damage and slowing enemies',
          hp: 880, // Balanced: was 750 (too low)
          speed: 195, // Balanced: was 200
          jumpForce: 360,
          attackPower: 38, // Balanced: was 32
          defense: 18, // Balanced: was 10
          skillCooldown: 5.0,
          skillDamage: 90,
          // 貂蝉：刺客，纤细体型，轻盈
          visuals: HeroVisuals(
            bodyType: BodyType.slim,
            headRadius: 8, torsoWidth: 18, torsoHeight: 18,
            armLength: 16, armWidth: 4, legLength: 22, legWidth: 5,
            secondaryColor: 0xFFDD44AA, skinColor: 0xFFFFE0D0,
          ),
          // 刺客：极速3连击，范围小
          normalAttack: NormalAttackProfile(
            damageMultiplier: 0.8,
            range: 48,
            hitboxHeightRatio: 0.8,
            duration: 0.18,
            knockbackX: 140,
            knockbackY: -90,
            lungeSpeed: 110,
            maxComboHits: 3,
            comboMultipliers: [0.7, 0.8, 1.4], // 第3击爆发
          ),
          directionalAttacks: [
            // 前方：突刺（快速穿刺）
            DirectionalAttack(
              direction: AttackDirection.forward,
              damage: 1.1,
              range: 75,
              hitboxHeight: 30,
              duration: 0.18,
              knockbackX: 160,
              knockbackY: -60,
              onHitEffect: OnHitEffect.freeze,
              effectDuration: 0.5,
              label: 'Thrust',
            ),
            // 上方：跳跃踢
            DirectionalAttack(
              direction: AttackDirection.up,
              damage: 1.0,
              range: 45,
              hitboxHeight: 80,
              duration: 0.2,
              knockbackX: 80,
              knockbackY: -350,
              label: 'Jump Kick',
            ),
          ],
        );

  @override
  SkillResult executeSkill({
    required double posX,
    required double posY,
    required bool facingRight,
  }) {
    final List<ProjectileConfig> projectiles = [];
    const int petalCount = 5;
    const double spreadAngle = 1.2;

    for (int i = 0; i < petalCount; i++) {
      final angle = -spreadAngle / 2 +
          (spreadAngle / (petalCount - 1)) * i +
          (facingRight ? 0 : pi);
      projectiles.add(ProjectileConfig(
        x: posX + cos(angle) * 20,
        y: posY + sin(angle) * 20 - 20,
        vx: cos(angle) * 350,
        vy: sin(angle) * 350,
        damage: 90,
        lifetime: 1.0,
        color: const Color(0xFFFF88DD),
        width: 12,
        height: 12,
        type: ProjectileType.normal,
        onHitEffect: OnHitEffect.freeze,
        effectDuration: 0.8,
      ));
    }
    return SkillResult(projectiles: projectiles);
  }
}
