import 'package:flutter/material.dart';
import 'hero_data.dart';

/// 关羽 - 突进战士：中等速度，2连击，冲刺攻击强
class GuanyuHero extends HeroData {
  GuanyuHero()
      : super(
          id: 'guanyu',
          name: 'Guan Yu',
          nameEn: 'Guan Yu',
          title: 'The God of War',
          titleEn: 'The God of War',
          faction: Faction.threeKingdoms,
          colorValue: 0xFF22AA22,
          skillName: 'Green Dragon Crescent',
          skillNameEn: 'Green Dragon Crescent',
          skillDesc: 'Dash forward and slash, dealing 300 damage with huge knockback',
          skillDescEn: 'Dash forward and slash, dealing 300 damage with huge knockback',
          hp: 1080, // Balanced: was 1100
          speed: 155, // Balanced: was 160
          jumpForce: 320,
          attackPower: 50, // Balanced: was 48
          defense: 28, // Balanced: was 28
          skillCooldown: 10.0,
          skillDamage: 280, // Balanced: was 300
          // 关羽：突进战士，中等体型，持青龙偃月刀
          visuals: HeroVisuals(
            bodyType: BodyType.heavy,
            headRadius: 11, torsoWidth: 28, torsoHeight: 23,
            armLength: 22, armWidth: 6, legLength: 22, legWidth: 7,
            secondaryColor: 0xFF115511, skinColor: 0xFFFFDBAC,
            hasWeapon: true, weaponLength: 32, weaponColor: 0xFF88CC88,
          ),
          // 突进战士：横扫范围广，2连击
          normalAttack: NormalAttackProfile(
            damageMultiplier: 1.0,
            range: 75,
            hitboxHeightRatio: 0.9,
            duration: 0.35,
            knockbackX: 220,
            knockbackY: -90,
            lungeSpeed: 90,
            maxComboHits: 2,
            comboMultipliers: [0.9, 1.3],
          ),
          directionalAttacks: [
            DirectionalAttack(
              direction: AttackDirection.forward,
              damage: 1.5,
              range: 110,
              hitboxHeight: 65,
              duration: 0.3,
              knockbackX: 400,
              knockbackY: -100,
              label: 'Charge Strike',
            ),
            DirectionalAttack(
              direction: AttackDirection.down,
              damage: 1.1,
              range: 65,
              hitboxHeight: 45,
              duration: 0.4,
              knockbackX: 100,
              knockbackY: 180,
              label: 'Down Slash',
            ),
          ],
        );

  @override
  SkillResult executeSkill({
    required double posX,
    required double posY,
    required bool facingRight,
  }) {
    final dir = facingRight ? 1.0 : -1.0;
    final projectiles = [
      ProjectileConfig(
        x: posX + dir * 40,
        y: posY,
        vx: dir * 350,
        vy: 0,
        damage: 300,
        lifetime: 0.6,
        color: const Color(0xFF44FF44),
        width: 60,
        height: 40,
        type: ProjectileType.piercing,
      ),
    ];
    return SkillResult(
      projectiles: projectiles,
      dashForward: true,
      dashDistance: 180,
      dashDamage: 300,
      knockback: 400,
    );
  }
}
