import 'package:flutter/material.dart';
import 'hero_data.dart';

/// 荆轲 - 刺客型：高攻速低血量，3连击，图穷匕见冲刺+毒刃
class JingkeHero extends HeroData {
  JingkeHero()
      : super(
          id: 'jingke',
          name: 'Jing Ke',
          nameEn: 'Jing Ke',
          title: 'Dagger Reveal',
          titleEn: 'Dagger Reveal',
          faction: Faction.warring,
          colorValue: 0xFF4A148C,
          skillName: 'Dagger Reveal',
          skillNameEn: 'Dagger Reveal',
          skillDesc: 'Dash forward and throw 3 poison daggers',
          skillDescEn: 'Dash forward and throw 3 poison daggers',
          hp: 880,
          speed: 195,
          jumpForce: 360,
          attackPower: 46, // Balanced: was 52 (too high for assassin archetype)
          defense: 16,
          skillCooldown: 7.0,
          skillDamage: 90,
          // 荆轲：刺客型，瘦体型，深色装扮，持匕首
          visuals: HeroVisuals(
            bodyType: BodyType.slim,
            headRadius: 9,
            torsoWidth: 20,
            torsoHeight: 20,
            armLength: 19,
            armWidth: 4,
            legLength: 24,
            legWidth: 5,
            secondaryColor: 0xFF311B92,
            skinColor: 0xFFFFDBAC,
            hasCape: true,
            hasWeapon: true,
            weaponLength: 18,
            weaponColor: 0xFFB0BEC5,
          ),
          // 刺客型：极快单击，低击退，3连击
          normalAttack: NormalAttackProfile(
            damageMultiplier: 0.8,
            range: 50,
            hitboxHeightRatio: 0.75,
            duration: 0.16,
            knockbackX: 140,
            knockbackY: -70,
            lungeSpeed: 110,
            maxComboHits: 3,
            comboMultipliers: [1.0, 1.0, 1.4],
          ),
          directionalAttacks: [
            // 前方：突刺
            DirectionalAttack(
              direction: AttackDirection.forward,
              damage: 1.4,
              range: 80,
              hitboxHeight: 25,
              duration: 0.18,
              knockbackX: 240,
              knockbackY: -40,
              label: 'Assassin Stab',
            ),
            // 后方：回身斩（撤退反击）
            DirectionalAttack(
              direction: AttackDirection.backward,
              damage: 1.0,
              range: 55,
              hitboxHeight: 65,
              duration: 0.22,
              knockbackX: 160,
              knockbackY: -100,
              label: 'Retreat Slash',
            ),
            // 上方：飞刃
            DirectionalAttack(
              direction: AttackDirection.up,
              damage: 1.1,
              range: 45,
              hitboxHeight: 105,
              duration: 0.2,
              knockbackX: 60,
              knockbackY: -350,
              label: 'Dagger Toss',
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
    final List<ProjectileConfig> projectiles = [];

    // 3 poison daggers in a spread cone
    const int daggerCount = 3;
    for (int i = 0; i < daggerCount; i++) {
      final fraction = (i / (daggerCount - 1)) - 0.5;
      final vyOffset = fraction * 0.4 * 400;
      projectiles.add(ProjectileConfig(
        x: posX + dir * 20,
        y: posY - 5,
        vx: dir * 350,
        vy: vyOffset,
        damage: skillDamage,
        lifetime: 1.8,
        color: const Color(0xFF7C4DFF),
        width: 8,
        height: 16,
        type: ProjectileType.piercing,
        onHitEffect: OnHitEffect.stun,
        effectDuration: 0.3,
      ));
    }

    // Dash forward + projectiles
    return SkillResult(
      projectiles: projectiles,
      dashForward: true,
      dashDistance: 200,
      dashDamage: 90,
    );
  }
}
