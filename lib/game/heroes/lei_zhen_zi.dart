import 'package:flutter/material.dart';
import 'hero_data.dart';

/// 雷震子 - 重型战士：慢速2连击，方向攻击带眩晕
class LeizhenziHero extends HeroData {
 LeizhenziHero()
      : super(
          id: 'leizhenzi',
          name: 'Leizhenzi',
          nameEn: 'Leizhenzi',
          title: 'Wings of Thunder',
          titleEn: 'Wings of Thunder',
          faction: Faction.mythology,
          colorValue: 0xFF4466FF,
          skillName: 'Thunder Strike',
          skillNameEn: 'Thunder Strike',
          skillDesc: 'Summon lightning at enemy position, dealing 220 damage and stunning for 1s',
          skillDescEn: 'Summon lightning at enemy position, dealing 220 damage and stunning for 1s',
          hp: 1000, // Balanced: was 1100
          speed: 165, // Balanced: was 165
          jumpForce: 340,
          attackPower: 48, // Balanced: was 50
          defense: 24, // Balanced: was 26
          skillCooldown: 7.0,
          skillDamage: 220,
          // 雷震子：重型战士，壮硕体型，持雷锤，披斗篷
          visuals: HeroVisuals(
            bodyType: BodyType.heavy,
            headRadius: 11, torsoWidth: 28, torsoHeight: 23,
            armLength: 22, armWidth: 7, legLength: 21, legWidth: 7,
            secondaryColor: 0xFF2255BB, skinColor: 0xFFFFDBAC,
            hasHelmet: true, hasCape: true, hasWeapon: true,
            weaponLength: 26, weaponColor: 0xFFCCCCDD,
          ),
          // 重型战士：慢速2连击，范围大
          normalAttack: NormalAttackProfile(
            damageMultiplier: 1.1,
            range: 78,
            hitboxHeightRatio: 1.0,
            duration: 0.38,
            knockbackX: 240,
            knockbackY: -100,
            lungeSpeed: 65,
            maxComboHits: 2,
            comboMultipliers: [0.9, 1.4],
          ),
          directionalAttacks: [
            // 前方：雷锤横扫
            DirectionalAttack(
              direction: AttackDirection.forward,
              damage: 1.4,
              range: 95,
              hitboxHeight: 70,
              duration: 0.35,
              knockbackX: 320,
              knockbackY: -80,
              onHitEffect: OnHitEffect.stun,
              effectDuration: 0.4,
              label: 'Hammer Sweep',
            ),
            // 下方：雷锤砸地
            DirectionalAttack(
              direction: AttackDirection.down,
              damage: 1.3,
              range: 75,
              hitboxHeight: 45,
              duration: 0.42,
              knockbackX: 120,
              knockbackY: 220,
              onHitEffect: OnHitEffect.stun,
              effectDuration: 0.3,
              label: 'Hammer Slam',
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
        x: posX + dir * 200,
        y: posY - 300,
        vx: 0,
        vy: 800,
        damage: 220,
        lifetime: 1.0,
        color: const Color(0xFFAABBFF),
        width: 30,
        height: 60,
        type: ProjectileType.normal,
        onHitEffect: OnHitEffect.stun,
        effectDuration: 1.0,
      ),
    ];
    return SkillResult(projectiles: projectiles);
  }
}
