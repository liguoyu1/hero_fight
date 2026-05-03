import 'package:flutter/material.dart';
import 'hero_data.dart';

/// 墨家机关师 - 科技型：快速单击，方向攻击为机关术
class MohistHero extends HeroData {
 MohistHero()
      : super(
          id: 'mohist',
          name: 'Mohist Engineer',
          nameEn: 'Mohist Engineer',
          title: 'Master of Machines',
          titleEn: 'Master of Machines',
          faction: Faction.warring,
          colorValue: 0xFFDD2222,
          skillName: 'Tiangong Cannon',
          skillNameEn: 'Tiangong Cannon',
          skillDesc: 'Charge 0.5s then fire a beam dealing 280 damage',
          skillDescEn: 'Charge 0.5s then fire a beam dealing 280 damage',
          hp: 920, // Balanced: was 1000
          speed: 165, // Balanced: was 170
          jumpForce: 340,
          attackPower: 45, // Balanced: was 42
          defense: 24, // Balanced: was 25
          skillCooldown: 8.0,
          skillDamage: 260, // Balanced: was 280
          // 墨家机关师：科技型，标准体型，全身机关甲
          visuals: HeroVisuals(
            bodyType: BodyType.normal,
            headRadius: 10, torsoWidth: 24, torsoHeight: 22,
            armLength: 20, armWidth: 6, legLength: 22, legWidth: 6,
            secondaryColor: 0xFFCCAA00, skinColor: 0xFFCC2222,
            hasHelmet: true,
          ),
          // 科技型：快速单击，范围中等
          normalAttack: NormalAttackProfile(
            damageMultiplier: 0.9,
            range: 60,
            hitboxHeightRatio: 0.85,
            duration: 0.22,
            knockbackX: 175,
            knockbackY: -85,
            lungeSpeed: 85,
            maxComboHits: 1,
            comboMultipliers: [1.0],
          ),
          directionalAttacks: [
            // 前方：机关弩箭
            DirectionalAttack(
              direction: AttackDirection.forward,
              damage: 1.3,
              range: 100,
              hitboxHeight: 20,
              duration: 0.2,
              knockbackX: 220,
              knockbackY: -50,
              label: 'Crossbow Bolt',
            ),
            // 上方：冲天弩
            DirectionalAttack(
              direction: AttackDirection.up,
              damage: 1.1,
              range: 50,
              hitboxHeight: 110,
              duration: 0.22,
              knockbackX: 80,
              knockbackY: -320,
              label: 'Sky Arrow',
            ),
            // 下方：地火术
            DirectionalAttack(
              direction: AttackDirection.down,
              damage: 1.0,
              range: 65,
              hitboxHeight: 35,
              duration: 0.25,
              knockbackX: 150,
              knockbackY: 180,
              label: 'Ground Fire',
            ),
          ],
        );

  @override
  SkillResult executeSkill({
    required double posX,
    required double posY,
    required bool facingRight,
  }) {
    final double dir = facingRight ? 1.0 : -1.0;
    final projectiles = [
      ProjectileConfig(
        x: posX + dir * 30,
        y: posY,
        vx: dir * 550,
        vy: 0,
        damage: 280,
        lifetime: 1.5,
        color: const Color(0xFFFFFF44),
        width: 80,
        height: 24,
        type: ProjectileType.piercing,
      ),
    ];
    return SkillResult(projectiles: projectiles, chargeTime: 0.5);
  }
}
