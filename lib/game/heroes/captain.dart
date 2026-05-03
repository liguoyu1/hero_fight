import 'package:flutter/material.dart';
import 'hero_data.dart';

/// 盾卫将军 - 坦克：高防御，2连击，盾牌格挡方向攻击
class ShieldGeneralHero extends HeroData {
 ShieldGeneralHero()
      : super(
          id: 'shield_general',
          name: 'Shield General',
          nameEn: 'Shield General',
          title: 'Iron Wall',
          titleEn: 'Iron Wall',
          faction: Faction.warring,
          colorValue: 0xFF2244CC,
          skillName: 'Shield Toss',
          skillNameEn: 'Shield Toss',
          skillDesc: 'Throw shield that bounces 3 times, dealing 150 damage per hit',
          skillDescEn: 'Throw shield that bounces 3 times, dealing 150 damage per hit',
          hp: 1200, // Balanced: was 1500 (too high)
          speed: 140, // Balanced: was 110 (too low)
          jumpForce: 330,
          attackPower: 42,
          defense: 38, // Increased: was 35
          skillCooldown: 6.0,
          skillDamage: 150,
          // 盾卫将军：坦克，中等偏壮体型，持盾牌
          visuals: HeroVisuals(
            bodyType: BodyType.heavy,
            headRadius: 10, torsoWidth: 26, torsoHeight: 22,
            armLength: 21, armWidth: 6, legLength: 21, legWidth: 7,
            secondaryColor: 0xFF1144AA, skinColor: 0xFFFFDBAC,
            hasHelmet: true, hasShield: true,
          ),
          // 坦克：稳健2连击，范围中等
          normalAttack: NormalAttackProfile(
            damageMultiplier: 1.0,
            range: 68,
            hitboxHeightRatio: 1.0,
            duration: 0.32,
            knockbackX: 200,
            knockbackY: -90,
            lungeSpeed: 75,
            maxComboHits: 2,
            comboMultipliers: [1.0, 1.1],
          ),
          directionalAttacks: [
            // 前方：盾击冲锋
            DirectionalAttack(
              direction: AttackDirection.forward,
              damage: 1.2,
              range: 85,
              hitboxHeight: 75,
              duration: 0.3,
              knockbackX: 280,
              knockbackY: -60,
              label: 'Shield Charge',
            ),
            // 后方：回盾反击
            DirectionalAttack(
              direction: AttackDirection.backward,
              damage: 0.9,
              range: 55,
              hitboxHeight: 70,
              duration: 0.28,
              knockbackX: 180,
              knockbackY: -120,
              label: 'Counter Shield',
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
        x: posX + dir * 25,
        y: posY,
        vx: dir * 450,
        vy: -80,
        damage: 150,
        lifetime: 3.0,
        color: const Color(0xFF4488FF),
        width: 24,
        height: 24,
        type: ProjectileType.bouncing,
      ),
    ];
    return SkillResult(projectiles: projectiles);
  }
}
