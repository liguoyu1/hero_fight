import 'package:flutter/material.dart';
import 'hero_data.dart';

/// 后羿 - 射手：快速2连击，冰冻方向攻击
class HouyiHero extends HeroData {
 HouyiHero()
      : super(
          id: 'houyi',
          name: 'Hou Yi',
          nameEn: 'Hou Yi',
          title: 'Sun-Shooting Bow',
          titleEn: 'Sun-Shooting Bow',
          faction: Faction.mythology,
          colorValue: 0xFF66CCFF,
          skillName: 'Sun-Shot Arrow',
          skillNameEn: 'Sun-Shot Arrow',
          skillDesc: 'Fire a sun-powered arrow across screen, dealing 250 damage and freezing for 2s',
          skillDescEn: 'Fire a sun-powered arrow across screen, dealing 250 damage and freezing for 2s',
          hp: 880, // Balanced: was 800
          speed: 175, // Balanced: was 190 (reduce speed advantage)
          jumpForce: 300,
          attackPower: 42, // Balanced: was 38
          defense: 16, // Balanced: was 14
          skillCooldown: 12.0,
          skillDamage: 250,
          // 后羿：射手，纤细体型，持弓
          visuals: HeroVisuals(
            bodyType: BodyType.slim,
            headRadius: 9, torsoWidth: 20, torsoHeight: 19,
            armLength: 19, armWidth: 4, legLength: 23, legWidth: 5,
            secondaryColor: 0xFF4488CC, skinColor: 0xFFFFDDAA,
            hasWeapon: true, weaponLength: 24, weaponColor: 0xFF66BBEE,
          ),
          // 射手：快速2连击，范围中等
          normalAttack: NormalAttackProfile(
            damageMultiplier: 0.85,
            range: 65,
            hitboxHeightRatio: 0.75,
            duration: 0.2,
            knockbackX: 160,
            knockbackY: -70,
            lungeSpeed: 50,
            maxComboHits: 2,
            comboMultipliers: [1.0, 1.0],
          ),
          directionalAttacks: [
            // 前方：烈日箭（短程，冻结效果）
            DirectionalAttack(
              direction: AttackDirection.forward,
              damage: 1.1,
              range: 85,
              hitboxHeight: 25,
              duration: 0.25,
              knockbackX: 200,
              knockbackY: -40,
              onHitEffect: OnHitEffect.freeze,
              effectDuration: 0.8,
              label: 'Sun Arrow',
            ),
            // 上方：天射
            DirectionalAttack(
              direction: AttackDirection.up,
              damage: 0.9,
              range: 50,
              hitboxHeight: 90,
              duration: 0.22,
              knockbackX: 60,
              knockbackY: -300,
              label: 'Sky Shot',
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
        vx: dir * 600,
        vy: 0,
        damage: 250,
        lifetime: 3.0,
        color: const Color(0xFF88EEFF),
        width: 40,
        height: 16,
        type: ProjectileType.piercing,
        onHitEffect: OnHitEffect.freeze,
        effectDuration: 2.0,
      ),
    ];
    return SkillResult(projectiles: projectiles);
  }
}
