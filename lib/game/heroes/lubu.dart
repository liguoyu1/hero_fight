import 'dart:math';
import 'package:flutter/material.dart';
import 'hero_data.dart';

/// 吕布 - 重型战士：慢速但高伤害，3连击，上挑攻击
class LubuHero extends HeroData {
  LubuHero()
      : super(
          id: 'lubu',
          name: 'Lu Bu',
          nameEn: 'Lu Bu',
          title: 'The Greatest Under Heaven',
          titleEn: 'The Greatest Under Heaven',
          faction: Faction.threeKingdoms,
          colorValue: 0xFFCC0000,
          skillName: 'Peerless',
          skillNameEn: 'Peerless',
          skillDesc: 'Spinning attack, deals 250 damage to all nearby enemies',
          skillDescEn: 'Spinning attack, deals 250 damage to all nearby enemies',
          hp: 1150, // Balanced: was 1200
          speed: 150, // Balanced: was 140 (increase slightly)
          jumpForce: 320,
          attackPower: 52, // Balanced: was 55
          defense: 28, // Balanced: was 30
          skillCooldown: 8.0,
          skillDamage: 240, // Balanced: was 250
          // 吕布：重型战士，大体型，戴头盔，持方天画戟
          visuals: HeroVisuals(
            bodyType: BodyType.heavy,
            headRadius: 12, torsoWidth: 30, torsoHeight: 24,
            armLength: 23, armWidth: 7, legLength: 21, legWidth: 8,
            secondaryColor: 0xFF880000, skinColor: 0xFFFFDBAC,
            hasHelmet: true, hasWeapon: true,
            weaponLength: 30, weaponColor: 0xFFCCCCCC,
          ),
          // 重型战士：范围大、伤害高、速度慢，3连击（横扫→刺→重击）
          normalAttack: NormalAttackProfile(
            damageMultiplier: 1.0,
            range: 80,
            hitboxHeightRatio: 1.0,
            duration: 0.4,
            knockbackX: 250,
            knockbackY: -80,
            lungeSpeed: 60,
            maxComboHits: 3,
            comboMultipliers: [0.8, 0.9, 1.5], // 第3击重击
          ),
          directionalAttacks: [
            // 前冲：突进重击
            DirectionalAttack(
              direction: AttackDirection.forward,
              damage: 1.4,
              range: 100,
              hitboxHeight: 70,
              duration: 0.35,
              knockbackX: 350,
              knockbackY: -120,
              label: 'Charge',
            ),
            // 上挑：将敌人击飞
            DirectionalAttack(
              direction: AttackDirection.up,
              damage: 1.2,
              range: 60,
              hitboxHeight: 90,
              duration: 0.4,
              knockbackX: 100,
              knockbackY: -400,
              label: 'Uppercut',
            ),
            // 下砸：对下方敌人
            DirectionalAttack(
              direction: AttackDirection.down,
              damage: 1.3,
              range: 70,
              hitboxHeight: 50,
              duration: 0.45,
              knockbackX: 150,
              knockbackY: 200,
              label: 'Slam',
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
    const int count = 8;
    for (int i = 0; i < count; i++) {
      final angle = (2 * pi / count) * i;
      projectiles.add(ProjectileConfig(
        x: posX,
        y: posY,
        vx: cos(angle) * 200,
        vy: sin(angle) * 200,
        damage: 250,
        lifetime: 0.5,
        color: const Color(0xFFFF4444),
        width: 30,
        height: 30,
        type: ProjectileType.piercing,
      ));
    }
    return SkillResult(
      projectiles: projectiles,
      spinAttack: true,
      spinRadius: 120,
      spinDamage: 250,
    );
  }
}
