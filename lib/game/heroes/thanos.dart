import 'package:flutter/material.dart';
import 'hero_data.dart';

/// 蚩尤 - 最强坦克：极慢但极高伤害，2连击，方向攻击震慑
class ChiyouHero extends HeroData {
 ChiyouHero()
      : super(
          id: 'chiyou',
          name: 'Chi You',
          nameEn: 'Chi You',
          title: 'The War God Descended',
          titleEn: 'The War God Descended',
          faction: Faction.mythology,
          colorValue: 0xFF6622AA,
          skillName: 'Juli War Cry',
          skillNameEn: 'Juli War Cry',
          skillDesc: 'Devastating punch dealing 350 damage and stunning for 1.5s',
          skillDescEn: 'Devastating punch dealing 350 damage and stunning for 1.5s',
          hp: 1150, // Balanced: was 1300
          speed: 145, // Balanced: was 130
          jumpForce: 300,
          attackPower: 52, // Balanced: was 55
          defense: 32, // Balanced: was 35
          skillCooldown: 12.0,
          skillDamage: 320, // Balanced: was 350
          // 蚩尤：最强坦克，巨型体型，铜头铁额
          visuals: HeroVisuals(
            bodyType: BodyType.giant,
            headRadius: 13, torsoWidth: 34, torsoHeight: 26,
            armLength: 25, armWidth: 9, legLength: 22, legWidth: 9,
            secondaryColor: 0xFF664488, skinColor: 0xFFBB88CC,
            hasHelmet: true, hasWeapon: true,
            weaponLength: 18, weaponColor: 0xFFFFDD44,
          ),
          // 最强坦克：极慢2连击，超大范围超高伤害
          normalAttack: NormalAttackProfile(
            damageMultiplier: 1.2,
            range: 90,
            hitboxHeightRatio: 1.1,
            duration: 0.45,
            knockbackX: 300,
            knockbackY: -110,
            lungeSpeed: 50,
            maxComboHits: 2,
            comboMultipliers: [1.0, 1.8],
          ),
          directionalAttacks: [
            // 前方：蛮荒巨拳（超强击退）
            DirectionalAttack(
              direction: AttackDirection.forward,
              damage: 1.6,
              range: 110,
              hitboxHeight: 80,
              duration: 0.4,
              knockbackX: 500,
              knockbackY: -150,
              onHitEffect: OnHitEffect.stun,
              effectDuration: 0.8,
              label: 'Savage Fist',
            ),
            // 下方：地裂震击
            DirectionalAttack(
              direction: AttackDirection.down,
              damage: 1.3,
              range: 85,
              hitboxHeight: 50,
              duration: 0.5,
              knockbackX: 200,
              knockbackY: 250,
              onHitEffect: OnHitEffect.stun,
              effectDuration: 0.5,
              label: 'Earth Shatter',
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
        y: posY - 10,
        vx: dir * 300,
        vy: 0,
        damage: 350,
        lifetime: 0.8,
        color: const Color(0xFF9944FF),
        width: 50,
        height: 40,
        type: ProjectileType.piercing,
        onHitEffect: OnHitEffect.stun,
        effectDuration: 1.5,
      ),
    ];
    return SkillResult(
      projectiles: projectiles,
      dashForward: true,
      dashDistance: 120,
      knockback: 500,
    );
  }
}
