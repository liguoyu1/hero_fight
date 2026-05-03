import 'package:flutter/material.dart';
import 'hero_data.dart';

/// 鬼谷子 - 控制型：快速单击，方向攻击带眩晕
class GuiguziHero extends HeroData {
 GuiguziHero()
      : super(
          id: 'guiguzi',
          name: 'Guiguzi',
          nameEn: 'Guiguzi',
          title: 'Master Strategist',
          titleEn: 'Master Strategist',
          faction: Faction.warring,
          colorValue: 0xFFFFCC00,
          skillName: 'Art of Strategy',
          skillNameEn: 'Art of Strategy',
          skillDesc: 'Launch 5 talismans forward, each dealing 70 damage',
          skillDescEn: 'Launch 5 talismans forward, each dealing 70 damage',
          hp: 950, // Balanced: was 950
          speed: 165, // Balanced: was 165
          jumpForce: 310,
          attackPower: 44, // Balanced: was 40
          defense: 20, // Balanced: was 20
          skillCooldown: 5.0,
          skillDamage: 70,
          // 鬼谷子：控制型，标准体型，持符咒
          visuals: HeroVisuals(
            bodyType: BodyType.normal,
            headRadius: 10, torsoWidth: 22, torsoHeight: 20,
            armLength: 19, armWidth: 5, legLength: 23, legWidth: 6,
            secondaryColor: 0xFFAA8833, skinColor: 0xFFFFDBAC,
            hasWeapon: true, weaponLength: 16, weaponColor: 0xFFFFDD44,
          ),
          // 控制型：快速单击，伤害中等
          normalAttack: NormalAttackProfile(
            damageMultiplier: 0.9,
            range: 58,
            hitboxHeightRatio: 0.85,
            duration: 0.22,
            knockbackX: 170,
            knockbackY: -80,
            lungeSpeed: 70,
            maxComboHits: 1,
            comboMultipliers: [1.0],
          ),
          directionalAttacks: [
            // 前方：定身符（眩晕）
            DirectionalAttack(
              direction: AttackDirection.forward,
              damage: 1.0,
              range: 80,
              hitboxHeight: 35,
              duration: 0.28,
              knockbackX: 120,
              knockbackY: -50,
              onHitEffect: OnHitEffect.stun,
              effectDuration: 0.6,
              label: 'Stun Card',
            ),
            // 下方：地煞符（范围扫地）
            DirectionalAttack(
              direction: AttackDirection.down,
              damage: 1.2,
              range: 70,
              hitboxHeight: 40,
              duration: 0.3,
              knockbackX: 200,
              knockbackY: 150,
              label: 'Earth Trap',
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
    const int cardCount = 5;
    const double spreadAngle = 0.35;
    final double dir = facingRight ? 1.0 : -1.0;

    for (int i = 0; i < cardCount; i++) {
      final fraction = (i / (cardCount - 1)) - 0.5;
      final vyOffset = fraction * spreadAngle * 400;
      projectiles.add(ProjectileConfig(
        x: posX + dir * 25,
        y: posY,
        vx: dir * 420,
        vy: vyOffset,
        damage: 70,
        lifetime: 1.2,
        color: const Color(0xFFFFDD44),
        width: 14,
        height: 18,
        type: ProjectileType.normal,
      ));
    }
    return SkillResult(projectiles: projectiles);
  }
}
