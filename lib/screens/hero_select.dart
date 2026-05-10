import 'dart:math';
import 'package:flutter/material.dart';

import '../game/heroes/hero_data.dart';
import '../game/heroes/hero_registry.dart';
import '../i18n/app_localizations.dart';
import '../network/network_manager.dart';
import 'game_screen.dart';

/// 自适应尺寸工具类
class _AdaptiveSize {
  final BuildContext context;
  final double screenWidth;
  final double screenHeight;
  final double textScaleFactor;
  
  _AdaptiveSize(this.context) 
      : screenWidth = MediaQuery.of(context).size.width,
        screenHeight = MediaQuery.of(context).size.height,
        textScaleFactor = MediaQuery.textScaleFactorOf(context);
  
  /// 自适应字体大小
  double fontSize(double base) => base * textScaleFactor * (screenWidth / 375).clamp(0.85, 1.2);
  
  /// 自适应间距
  double spacing(double base) => base * (screenWidth / 375).clamp(0.8, 1.3);
  
  /// 自适应图标大小
  double iconSize(double base) => base * (screenWidth / 375).clamp(0.8, 1.2);
  
  /// 是否是小屏幕手机
  bool get isSmallScreen => screenWidth < 375;
  
  /// 是否是中屏幕手机
  bool get isMediumScreen => screenWidth >= 375 && screenWidth < 414;
  
  /// 是否是大屏幕手机
  bool get isLargeScreen => screenWidth >= 414;
}

/// Faction display configuration
const Map<Faction, _FactionDisplay> _factionDisplay = {
  Faction.threeKingdoms:
      _FactionDisplay('Three Kingdoms', Color(0xFFCC4444), Icons.shield),
  Faction.mythology:
      _FactionDisplay('Mythology', Color(0xFF4488CC), Icons.flash_on),
  Faction.warring:
      _FactionDisplay('Warring States', Color(0xFF448844), Icons.star),
};

class _FactionDisplay {
  final String label;
  final Color color;
  final IconData icon;
  const _FactionDisplay(this.label, this.color, this.icon);
}

/// Hero selection screen.
/// In 'ai' mode, player 1 picks a hero; opponent is auto-assigned.
/// In 'local' mode, both players pick sequentially.
/// In 'online'/'lan' mode, both players pick simultaneously via server sync.
class HeroSelectScreen extends StatefulWidget {
  final String mode; // 'ai', 'local', 'online', 'lan'
  final NetworkManager? network; // Shared network connection (online/lan only)
  final int mySlot; // Player slot in network mode

  const HeroSelectScreen({
    super.key,
    this.mode = 'ai',
    this.network,
    this.mySlot = 0,
  });

  @override
  State<HeroSelectScreen> createState() => _HeroSelectScreenState();
}

class _HeroSelectScreenState extends State<HeroSelectScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late final Random _rng = Random();
  NetworkManager? _network;
  late final AnimationController _glowController;

  // Selection state: 0 = P1 picking, 1 = P2 picking (local/ai mode only)
  int _selectionPhase = 0;
  String? _p1HeroId;
  String? _p2HeroId;
  String? _hoveredHeroId;
  bool _p1Ready = false;
  bool _p2Ready = false;

  // Network sync state (online/lan)
  late int _mySlot;
  String? _opponentHeroId;
  bool _opponentReady = false;

  bool get _isNetworkMode => widget.mode == 'online' || widget.mode == 'lan';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _mySlot = widget.mySlot;

    if (_isNetworkMode) {
      _setupNetworkSync();
    }
  }

  void _setupNetworkSync() {
    _network = widget.network;
    if (_network == null) {
      debugPrint('ERROR: Network mode requires network manager');
      return;
    }

    _network!.onHeroSelected = (data) {
      if (!mounted) return;
      final slot = data['slot'] as int? ?? 0;
      final heroId = data['heroId'] as String?;
      if (slot != _mySlot) {
        setState(() {
          _opponentHeroId = heroId;
          if (slot == 0) {
            _p1HeroId = heroId;
          } else {
            _p2HeroId = heroId;
          }
        });
      }
    };

    _network!.onPlayerReady = (data) {
      if (!mounted) return;
      final slot = data['slot'] as int? ?? 0;
      final ready = data['ready'] as bool? ?? false;
      if (slot != _mySlot) {
        setState(() {
          _opponentReady = ready;
        });
      }
    };

    _network!.onGameStart = (data) {
      if (!mounted) return;
      final players = data['players'] as List<dynamic>? ?? [];
      final seed = data['seed'] as int? ?? 0;
      String hero1, hero2;
      if (players.length >= 2) {
        hero1 = (players[0] as Map)['heroId'] as String;
        hero2 = (players[1] as Map)['heroId'] as String;
      } else {
        hero1 = _p1HeroId ?? 'lubu';
        hero2 = _p2HeroId ?? 'zhuge';
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GameScreen(
            hero1Id: hero1,
            hero2Id: hero2,
            mode: widget.mode,
            network: _network,
            mySlot: _mySlot,
            rollbackSeed: seed,
          ),
        ),
      );
    };

    _network!.onError = (msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Network Error: $msg'),
            backgroundColor: Colors.redAccent),
      );
    };

    _network!.onDisconnected = (reason) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Connection Lost: $reason'),
            backgroundColor: Colors.redAccent),
      );
    };
  }

  @override
  void dispose() {
    _tabController.dispose();
    _glowController.dispose();
    // Do NOT dispose _network here — ownership transfers to GameScreen
    super.dispose();
  }

  List<HeroData> get _heroes => HeroRegistry.instance.getAll();

  List<HeroData> _heroesByFaction(Faction faction) =>
      _heroes.where((h) => h.faction == faction).toList();

  void _selectHero(HeroData hero) {
    if (_isNetworkMode) {
      if (_mySlot == 0) {
        if (_p1HeroId == hero.id) return;
        setState(() {
          _p1HeroId = hero.id;
          _p1Ready = false;
        });
      } else {
        if (_p2HeroId == hero.id) return;
        setState(() {
          _p2HeroId = hero.id;
          _p2Ready = false;
        });
      }
      _network?.selectHero(hero.id);
      return;
    }

    if (_selectionPhase == 0) {
      setState(() {
        _p1HeroId = hero.id;
        if (widget.mode == 'ai') {
          final available = _heroes.where((h) => h.id != hero.id).toList();
          _p2HeroId = available[_rng.nextInt(available.length)].id;
          _navigateToGame();
        } else {
          _selectionPhase = 1;
        }
      });
    } else if (_selectionPhase == 1 && hero.id != _p1HeroId) {
      setState(() {
        _p2HeroId = hero.id;
        _navigateToGame();
      });
    }
  }

  void _toggleReady() {
    final myHeroId = _mySlot == 0 ? _p1HeroId : _p2HeroId;
    if (myHeroId == null) return;
    final newReady = _mySlot == 0 ? !_p1Ready : !_p2Ready;
    setState(() {
      if (_mySlot == 0) {
        _p1Ready = newReady;
      } else {
        _p2Ready = newReady;
      }
    });
    _network?.sendReady(ready: newReady);
  }

  void _navigateToGame() {
    if (_p1HeroId != null && _p2HeroId != null) {
      Navigator.pushNamed(context, '/game', arguments: {
        'hero1': _p1HeroId,
        'hero2': _p2HeroId,
        'mode': widget.mode,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.fromSystemLocale();
    final isP1 = !_isNetworkMode && _selectionPhase == 0;

    String title;
    String subtitle;
    if (_isNetworkMode) {
      title = _mySlot == 0 ? l10n.player1SelectHero : l10n.player2SelectHero;
      subtitle = l10n.chooseHeroThenReady;
    } else if (widget.mode == 'ai') {
      title = l10n.selectYourHero;
      subtitle = l10n.aiAutoSelect;
    } else {
      title = isP1 ? l10n.selectYourHero : l10n.selectOpponentHero;
      subtitle = isP1
          ? l10n.player1ChooseHero
          : l10n.player2ChooseHero;
    }

    final adaptive = _AdaptiveSize(context);
    final allReady = _isNetworkMode &&
        _p1Ready &&
        _p2Ready &&
        _p1HeroId != null &&
        _p2HeroId != null;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D0D2B),
              Color(0xFF1A0A3E),
              Color(0xFF2A1A1A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Compact header bar
              _buildHeaderBar(title),
              // Subtitle + picks row
              _buildPickSummary(subtitle),
              // Ready bar
              if (_isNetworkMode &&
                  _p1HeroId != null &&
                  _p2HeroId != null)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: adaptive.spacing(3),
                  color: allReady
                      ? const Color(0xFF4CAF50)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              // Faction tabs
              _buildFactionTabs(),
              // Hero grid
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    for (final faction in Faction.values)
                      _buildHeroGrid(_heroesByFaction(faction)),
                  ],
                ),
              ),
              // Ready button (network mode only)
              if (_isNetworkMode) _buildReadyButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBar(String title) {
    final adaptive = _AdaptiveSize(context);
    final headerHeight = adaptive.isSmallScreen ? 40.0 : 
                        adaptive.isMediumScreen ? 44.0 : 48.0;
    
    return Container(
      height: headerHeight,
      padding: EdgeInsets.symmetric(horizontal: adaptive.spacing(8)),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            iconSize: adaptive.iconSize(22),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: adaptive.spacing(36), 
              minHeight: adaptive.spacing(36),
            ),
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: () {
              _network?.leaveRoom();
              Navigator.pop(context);
            },
          ),
          SizedBox(width: adaptive.spacing(4)),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: adaptive.fontSize(16),
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                shadows: const [
                  Shadow(color: Color(0xAAFF6B35), blurRadius: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickSummary(String subtitle) {
    final adaptive = _AdaptiveSize(context);
    final l10n = AppLocalizations.fromSystemLocale();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: adaptive.spacing(12), 
        vertical: adaptive.spacing(6),
      ),
      color: Colors.black.withValues(alpha: 0.18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              subtitle,
              style: TextStyle(
                color: Colors.white60,
                fontSize: adaptive.fontSize(12),
              ),
            ),
          ),
          // Pick chips
          if (_isNetworkMode) ..._buildNetworkPicks(adaptive, l10n),
          if (!_isNetworkMode) ...[
            if (_p1HeroId != null)
              _buildPickChip(adaptive, l10n.player1, _p1HeroId!, Colors.lightBlueAccent),
            if (_p2HeroId != null) ...[
              SizedBox(width: adaptive.spacing(6)),
              _buildPickChip(
                adaptive,
                widget.mode == 'ai' ? l10n.aiLabel : l10n.player2,
                _p2HeroId!,
                Colors.orangeAccent,
              ),
            ],
          ],
        ],
      ),
    );
  }

  List<Widget> _buildNetworkPicks(_AdaptiveSize adaptive, AppLocalizations l10n) {
    final myHeroId = _mySlot == 0 ? _p1HeroId : _p2HeroId;
    final myReady = _mySlot == 0 ? _p1Ready : _p2Ready;
    final myColor =
        _mySlot == 0 ? Colors.lightBlueAccent : Colors.orangeAccent;
    final oppColor =
        _mySlot == 0 ? Colors.orangeAccent : Colors.lightBlueAccent;
    return [
      _buildPickChip(adaptive, l10n.you, myHeroId, myColor, myReady),
      SizedBox(width: adaptive.spacing(6)),
      _buildPickChipNetwork(adaptive, l10n.opponent, _opponentHeroId, oppColor, _opponentReady),
    ];
  }

  Widget _buildPickChip(_AdaptiveSize adaptive, String label, String? heroId, Color color, [bool ready = false]) {
    if (heroId == null) return const SizedBox.shrink();
    final hero = HeroRegistry.instance.get(heroId);
    if (hero == null) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: adaptive.spacing(8), 
        vertical: adaptive.spacing(4),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: ready ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(adaptive.spacing(14)),
        border: Border.all(
          color: ready ? const Color(0xFF4CAF50) : color.withValues(alpha: 0.5),
          width: ready ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: adaptive.spacing(8),
            height: adaptive.spacing(8),
            decoration: BoxDecoration(color: hero.color, shape: BoxShape.circle),
          ),
          SizedBox(width: adaptive.spacing(5)),
          Text(
            '$label · ${hero.name}',
            style: TextStyle(
              color: ready ? const Color(0xFF81C784) : color,
              fontSize: adaptive.fontSize(11),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickChipNetwork(
      _AdaptiveSize adaptive, String label, String? heroId, Color color, bool ready) {
    final l10n = AppLocalizations.fromSystemLocale();
    final hero = heroId != null ? HeroRegistry.instance.get(heroId) : null;
    final name = hero?.name ?? l10n.notSelected;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: adaptive.spacing(8), 
        vertical: adaptive.spacing(4),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: ready ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(adaptive.spacing(14)),
        border: Border.all(
          color: ready
              ? const Color(0xFF4CAF50)
              : color.withValues(alpha: 0.5),
          width: ready ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ready ? Icons.check_circle : Icons.radio_button_unchecked,
            size: adaptive.iconSize(12),
            color: ready ? const Color(0xFF81C784) : color,
          ),
          SizedBox(width: adaptive.spacing(4)),
          Text(
            '$label · $name',
            style: TextStyle(
              color: ready ? const Color(0xFF81C784) : color,
              fontSize: adaptive.fontSize(11),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactionTabs() {
    final adaptive = _AdaptiveSize(context);
    final l10n = AppLocalizations.fromSystemLocale();
    final tabHeight = adaptive.isSmallScreen ? 34.0 : 
                        adaptive.isMediumScreen ? 38.0 : 42.0;
    
    return Container(
      height: tabHeight,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFFFF6B35),
        indicatorWeight: adaptive.spacing(2.5),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: TextStyle(
          fontSize: adaptive.fontSize(13), 
          fontWeight: FontWeight.w600,
        ),
        tabs: [
          for (final faction in Faction.values)
            Tab(
              height: tabHeight - 2,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _factionDisplay[faction]!.icon, 
                    size: adaptive.iconSize(14), 
                    color: _factionDisplay[faction]!.color,
                  ),
                  SizedBox(width: adaptive.spacing(5)),
                  Text(_factionLabel(faction, l10n)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _factionLabel(Faction faction, AppLocalizations l10n) {
    switch (faction) {
      case Faction.threeKingdoms:
        return l10n.threeKingdoms;
      case Faction.mythology:
        return l10n.mythologyLabel;
      case Faction.warring:
        return l10n.warringStates;
    }
  }

  Widget _buildReadyButton() {
    final adaptive = _AdaptiveSize(context);
    final l10n = AppLocalizations.fromSystemLocale();
    final myReady = _mySlot == 0 ? _p1Ready : _p2Ready;
    final hasMyHero = (_mySlot == 0 ? _p1HeroId : _p2HeroId) != null;
    final buttonHeight = adaptive.isSmallScreen ? 38.0 : 
                          adaptive.isMediumScreen ? 42.0 : 46.0;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: adaptive.spacing(12),
        vertical: adaptive.spacing(8),
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: buttonHeight,
        child: ElevatedButton.icon(
          onPressed: () {
            if (!hasMyHero) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(
                  l10n.pleaseSelectHero,
                  style: TextStyle(fontSize: adaptive.fontSize(14)),
                )),
              );
              return;
            }
            _toggleReady();
          },
          icon: Icon(
            myReady ? Icons.check_circle : Icons.check_circle_outline,
            size: adaptive.iconSize(18),
          ),
          label: Text(
            myReady ? l10n.readyWaiting : l10n.ready,
            style: TextStyle(
              fontSize: adaptive.fontSize(14),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: myReady
                ? const Color(0xFF4CAF50)
                : const Color(0xFFCC4444),
            foregroundColor: Colors.white,
            elevation: myReady ? 6 : 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(adaptive.spacing(10)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroGrid(List<HeroData> heroes) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final adaptive = _AdaptiveSize(context);
        final screenWidth = constraints.maxWidth;
        
        // 完全自适应的列数计算
        int cols;
        double childAspectRatio;
        
        // 根据屏幕宽度动态计算列数
        if (screenWidth < 320) {
          cols = 2;
          childAspectRatio = 0.72;
        } else if (screenWidth < 375) {
          cols = 2;
          childAspectRatio = 0.75;
        } else if (screenWidth < 414) {
          cols = 3;
          childAspectRatio = 0.78;
        } else if (screenWidth < 500) {
          cols = 3;
          childAspectRatio = 0.80;
        } else if (screenWidth < 600) {
          cols = 4;
          childAspectRatio = 0.82;
        } else {
          cols = 5;
          childAspectRatio = 0.85;
        }
        
        return GridView.builder(
          padding: EdgeInsets.symmetric(
            horizontal: adaptive.spacing(10),
            vertical: adaptive.spacing(8),
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: adaptive.spacing(8),
            mainAxisSpacing: adaptive.spacing(8),
          ),
          itemCount: heroes.length,
          itemBuilder: (context, index) => _buildHeroCard(heroes[index]),
        );
      },
    );
  }

  Widget _buildHeroCard(HeroData hero) {
    final adaptive = _AdaptiveSize(context);
    final l10n = AppLocalizations.fromSystemLocale();
    final isSelected = hero.id == _p1HeroId || hero.id == _p2HeroId;
    final isMine = _isNetworkMode
        ? hero.id == (_mySlot == 0 ? _p1HeroId : _p2HeroId)
        : hero.id == _p1HeroId;
    final isDisabled = (_mySlot == 0 ? _p1HeroId : _p2HeroId) == hero.id ||
        (!_isNetworkMode && hero.id == _p1HeroId && _selectionPhase == 1);
    final isHovered = _hoveredHeroId == hero.id;

    return MouseRegion(
      cursor: isDisabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredHeroId = hero.id),
      onExit: (_) => setState(() => _hoveredHeroId = null),
      child: GestureDetector(
        onTap: isDisabled ? null : () => _selectHero(hero),
        onTapDown: (_) => setState(() => _hoveredHeroId = hero.id),
        onTapCancel: () => setState(() => _hoveredHeroId = null),
        child: AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            final glowStrength = isMine
                ? (0.6 + 0.4 * _glowController.value)
                : 0.0;
              final hoverScale = isHovered && !isDisabled ? 1.03 : 1.0;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                transform: Matrix4.diagonal3Values(hoverScale, hoverScale, 1.0),
              transformAlignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    hero.color.withValues(
                        alpha: isSelected ? 0.30 : (isHovered ? 0.16 : 0.08)),
                    Colors.black.withValues(alpha: 0.45),
                  ],
                ),
                borderRadius: BorderRadius.circular(adaptive.spacing(10)),
                border: Border.all(
                  color: isSelected
                      ? hero.color
                      : isHovered
                          ? Colors.white54
                          : Colors.white12,
                  width: isSelected ? 2.0 : 1.0,
                ),
                boxShadow: [
                  if (isMine)
                    BoxShadow(
                      color: hero.color.withValues(alpha: glowStrength * 0.6),
                      blurRadius: adaptive.spacing(18),
                      spreadRadius: 1,
                    ),
                  if (isHovered && !isMine)
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.15),
                      blurRadius: adaptive.spacing(10),
                    ),
                ],
              ),
              child: child,
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(adaptive.spacing(10)),
            child: Stack(
              children: [
                Column(
                  children: [
                    // Hero portrait area (gradient bg)
                    Expanded(
                      flex: 5,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 0.9,
                            colors: [
                              hero.color.withValues(alpha: 0.35),
                              hero.color.withValues(alpha: 0.05),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Center(child: _buildHeroAvatar(hero, adaptive)),
                      ),
                    ),
                    // Hero info
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        adaptive.spacing(8),
                        adaptive.spacing(6),
                        adaptive.spacing(8),
                        adaptive.spacing(8),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hero.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: adaptive.fontSize(15),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: adaptive.spacing(2)),
                          Text(
                            hero.title,
                            style: TextStyle(
                              color: hero.color.withValues(alpha: 0.95),
                              fontSize: adaptive.fontSize(10),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: adaptive.spacing(5)),
                          _buildStatRow(adaptive, 'HP', hero.hp.toInt(), 1500,
                              const Color(0xFFFF5252)),
                          SizedBox(height: adaptive.spacing(2)),
                          _buildStatRow(adaptive, 'ATK', hero.attackPower.toInt(), 200,
                              const Color(0xFFFFB74D)),
                          SizedBox(height: adaptive.spacing(2)),
                          _buildStatRow(adaptive, 'SPD', hero.speed.toInt(), 250,
                              const Color(0xFF4FC3F7)),
                        ],
                      ),
                    ),
                  ],
                ),
                // "MINE" badge
                if (isMine)
                  Positioned(
                    top: adaptive.spacing(6),
                    right: adaptive.spacing(6),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: adaptive.spacing(6), 
                          vertical: adaptive.spacing(2)),
                      decoration: BoxDecoration(
                        color: hero.color,
                        borderRadius: BorderRadius.circular(adaptive.spacing(6)),
                        boxShadow: [
                          BoxShadow(
                              color: hero.color.withValues(alpha: 0.7),
                              blurRadius: adaptive.spacing(6)),
                        ],
                      ),
                      child: Text(
                        l10n.picked,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: adaptive.fontSize(9),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(_AdaptiveSize adaptive, String label, int value, int maxValue, Color color) {
    final ratio = (value / maxValue).clamp(0.0, 1.0);
    final labelWidth = adaptive.isSmallScreen ? 24.0 : 28.0;
    final valueWidth = adaptive.isSmallScreen ? 26.0 : 32.0;
    
    return Row(
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white60,
              fontSize: adaptive.fontSize(9),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: adaptive.spacing(5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(adaptive.spacing(3)),
                ),
              ),
              FractionallySizedBox(
                widthFactor: ratio,
                child: Container(
                  height: adaptive.spacing(5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.7), color],
                    ),
                    borderRadius: BorderRadius.circular(adaptive.spacing(3)),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: adaptive.spacing(3),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: adaptive.spacing(4)),
        SizedBox(
          width: valueWidth,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.white70,
              fontSize: adaptive.fontSize(9),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroAvatar(HeroData hero, _AdaptiveSize adaptive) {
    final factionIcon =
        _factionDisplay[hero.faction]?.icon ?? Icons.person;
    final avatarSize = adaptive.isSmallScreen ? 40.0 : 
                        adaptive.isMediumScreen ? 44.0 : 50.0;
    final iconSize = adaptive.isSmallScreen ? 50.0 : 64.0;
    final fontSize = adaptive.fontSize(22);
    
    return Stack(
      alignment: Alignment.center,
      children: [
        // Faction icon halo
        Icon(
          factionIcon,
          color: hero.color.withValues(alpha: 0.25),
          size: iconSize,
        ),
        // Avatar circle
        Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                hero.color.withValues(alpha: 0.9),
                hero.color.withValues(alpha: 0.5),
              ],
            ),
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.8), 
                width: 2),
            boxShadow: [
              BoxShadow(
                  color: hero.color, 
                  blurRadius: adaptive.spacing(10), 
                  spreadRadius: 1),
            ],
          ),
          child: Center(
            child: Text(
              hero.name.isNotEmpty ? hero.name[0] : '?',
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                shadows: const [
                  Shadow(color: Colors.black, blurRadius: 6),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
