import 'package:flutter/material.dart';
import 'hero_data.dart';

/// 少林武僧 - 格斗家：快速3连击，突进强
class ShaolinMonkHero extends HeroData {
 ShaolinMonkHero()
      : super(
          id: 'shaolin_monk',
          name: 'Shaolin Monk',
          nameEn: 'Shaolin Monk',
          title: 'Fearless Iron Fist',
          titleEn: 'Fearless Iron Fist',
          faction: Faction.mythology,
          colorValue: 0xFFFF8800,
          skillName: 'Diamond Demon Fist',
          skillNameEn: 'Diamond Demon Fist',
          skillDesc: 'Channel internal energy for a demon-subduing punch dealing 200 damage, then slam for 150 more',
          skillDescEn: 'Channel internal energy for a demon-subduing punch dealing 200 damage, then slam for 150 more',
          hp: 980, // Balanced: was 950
          speed: 185, // Balanced: was 190
          jumpForce: 350,
          attackPower: 48, // Balanced: was 45
          defense: 24, // Balanced: was 22
          skillCooldown: 9.0,
          skillDamage: 200,
          // 少林武僧：格斗家，标准体型，无武器
          visuals: HeroVisuals(
            bodyType: BodyType.normal,
            headRadius: 10, torsoWidth: 24, torsoHeight: 21,
            armLength: 20, armWidth: 6, legLength: 22, legWidth: 7,
            secondaryColor: 0xFF886622, skinColor: 0xFFDDBB88,
          ),
          // 格斗家：快速3连击，范围中等
          normalAttack: NormalAttackProfile(
            damageMultiplier: 0.85,
            range: 62,
            hitboxHeightRatio: 0.9,
            duration: 0.22,
            knockbackX: 180,
            knockbackY: -100,
            lungeSpeed: 100,
            maxComboHits: 3,
            comboMultipliers: [0.7, 0.8, 1.2],
          ),
          directionalAttacks: [
            // 前方：飞踢（突进）
            DirectionalAttack(
              direction: AttackDirection.forward,
              damage: 1.3,
              range: 95,
              hitboxHeight: 55,
              duration: 0.25,
              knockbackX: 300,
              knockbackY: -150,
              label: 'Whirlwind Kick',
            ),
            // 上方：上踢
            DirectionalAttack(
              direction: AttackDirection.up,
              damage: 1.1,
              range: 55,
              hitboxHeight: 85,
              duration: 0.28,
              knockbackX: 100,
              knockbackY: -380,
              label: 'Sky Kick',
            ),
            // 下方：下踩
            DirectionalAttack(
              direction: AttackDirection.down,
              damage: 1.2,
              range: 60,
              hitboxHeight: 45,
              duration: 0.3,
              knockbackX: 120,
              knockbackY: 200,
              label: 'Quake Hammer',
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
        x: posX + dir * 35,
        y: posY,
        vx: dir * 250,
        vy: -100,
        damage: 200,
        lifetime: 0.3,
        color: const Color(0xFFFFAA33),
        width: 45,
        height: 35,
        type: ProjectileType.piercing,
        onHitEffect: OnHitEffect.stun,
        effectDuration: 0.5,
      ),
      ProjectileConfig(
        x: posX + dir * 80,
        y: posY - 40,
        vx: dir * 150,
        vy: 300,
        damage: 150,
        lifetime: 0.6,
        color: const Color(0xFFFF6600),
        width: 35,
        height: 35,
        type: ProjectileType.normal,
      ),
    ];
    return SkillResult(
      projectiles: projectiles,
      dashForward: true,
      dashDistance: 100,
      knockback: 250,
    );
  }
}
