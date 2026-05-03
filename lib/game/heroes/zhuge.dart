import 'dart:math';
import 'package:flutter/material.dart';
import 'hero_data.dart';

/// 诸葛亮 - 法师：快速远程，单击无连击，方向攻击为魔法弹
class ZhugeHero extends HeroData {
  ZhugeHero()
      : super(
          id: 'zhuge',
          name: 'Zhuge Liang',
          nameEn: 'Zhuge Liang',
          title: 'The Sleeping Dragon',
          titleEn: 'The Sleeping Dragon',
          faction: Faction.threeKingdoms,
          colorValue: 0xFF4488FF,
          skillName: 'Rain of Arrows',
          skillNameEn: 'Rain of Arrows',
          skillDesc: 'Fire 7 arrows in a fan, each dealing 80 damage',
          skillDescEn: 'Fire 7 arrows in a fan, each dealing 80 damage',
          hp: 880, // Balanced: was 800
          speed: 165, // Balanced: was 160
          jumpForce: 300,
          attackPower: 40, // Balanced: was 35
          defense: 18, // Balanced: was 15
          skillCooldown: 6.0,
          skillDamage: 80,
          // 诸葛亮：法师，纤细体型，持羽扇
          visuals: HeroVisuals(
            bodyType: BodyType.slim,
            headRadius: 9, torsoWidth: 20, torsoHeight: 20,
            armLength: 18, armWidth: 4, legLength: 23, legWidth: 5,
            secondaryColor: 0xFF2244AA, skinColor: 0xFFFFDBAC,
            hasCape: true,
          ),
          // 法师：近战范围小但快，无连击
          normalAttack: NormalAttackProfile(
            damageMultiplier: 0.9,
            range: 50,
            hitboxHeightRatio: 0.8,
            duration: 0.22,
            knockbackX: 150,
            knockbackY: -60,
            lungeSpeed: 40,
            maxComboHits: 1,
            comboMultipliers: [1.0],
          ),
          directionalAttacks: [
            // 前方：快速魔法弹（短程）
            DirectionalAttack(
              direction: AttackDirection.forward,
              damage: 1.2,
              range: 90,
              hitboxHeight: 30,
              duration: 0.25,
              knockbackX: 180,
              knockbackY: -50,
              label: 'Magic Bullet',
            ),
            // 上方：向上的魔法弹
            DirectionalAttack(
              direction: AttackDirection.up,
              damage: 1.0,
              range: 55,
              hitboxHeight: 100,
              duration: 0.28,
              knockbackX: 80,
              knockbackY: -350,
              label: 'Magic Up',
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
    const int arrowCount = 7;
    const double spreadAngle = 0.6;
    final double baseAngle = facingRight ? 0 : pi;

    for (int i = 0; i < arrowCount; i++) {
      final offset = -spreadAngle / 2 + (spreadAngle / (arrowCount - 1)) * i;
      final angle = baseAngle + offset;
      projectiles.add(ProjectileConfig(
        x: posX + (facingRight ? 30 : -30),
        y: posY,
        vx: cos(angle) * 400,
        vy: sin(angle) * 400,
        damage: 80,
        lifetime: 1.5,
        color: const Color(0xFF88CCFF),
        width: 20,
        height: 6,
        type: ProjectileType.normal,
      ));
    }
    return SkillResult(projectiles: projectiles);
  }
}
