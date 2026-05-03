import 'dart:math';
import 'package:flutter/material.dart';

import '../game/heroes/hero_data.dart';
import '../game/heroes/hero_registry.dart';
import '../network/network_manager.dart';
import 'game_screen.dart';

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
    final isP1 = !_isNetworkMode && _selectionPhase == 0;

    String title;
    String subtitle;
    if (_isNetworkMode) {
      title = _mySlot == 0 ? 'Player 1 - Select Hero' : 'Player 2 - Select Hero';
      subtitle = 'Choose your hero, then click "Ready"';
    } else if (widget.mode == 'ai') {
      title = 'Select Your Hero';
      subtitle = 'AI will auto-select opponent';
    } else {
      title = isP1 ? 'Select Your Hero' : 'Select Opponent Hero';
      subtitle = isP1
          ? 'Player 1, choose your hero'
          : 'Player 2, choose your hero';
    }

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
                  height: 3,
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
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            iconSize: 22,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: () {
              _network?.leaveRoom();
              Navigator.pop(context);
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                shadows: [
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Colors.black.withValues(alpha: 0.18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ),
          // Pick chips
          if (_isNetworkMode) ..._buildNetworkPicks(),
          if (!_isNetworkMode) ...[
            if (_p1HeroId != null)
              _buildPickChip('P1', _p1HeroId!, Colors.lightBlueAccent),
            if (_p2HeroId != null) ...[
              const SizedBox(width: 6),
              _buildPickChip(
                widget.mode == 'ai' ? 'AI' : 'P2',
                _p2HeroId!,
                Colors.orangeAccent,
              ),
            ],
          ],
        ],
      ),
    );
  }

  List<Widget> _buildNetworkPicks() {
    final myHeroId = _mySlot == 0 ? _p1HeroId : _p2HeroId;
    final myReady = _mySlot == 0 ? _p1Ready : _p2Ready;
    final myColor =
        _mySlot == 0 ? Colors.lightBlueAccent : Colors.orangeAccent;
    final oppColor =
        _mySlot == 0 ? Colors.orangeAccent : Colors.lightBlueAccent;
    return [
      _buildPickChipNetwork('You', myHeroId, myColor, myReady),
      const SizedBox(width: 6),
      _buildPickChipNetwork('Opponent', _opponentHeroId, oppColor, _opponentReady),
    ];
  }

  Widget _buildPickChip(String label, String heroId, Color color) {
    final hero = HeroRegistry.instance.get(heroId);
    if (hero == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: hero.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '$label · ${hero.name}',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickChipNetwork(
      String label, String? heroId, Color color, bool ready) {
    final hero = heroId != null ? HeroRegistry.instance.get(heroId) : null;
    final name = hero?.name ?? 'Not Selected';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: ready ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(14),
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
            size: 12,
            color: ready ? const Color(0xFF81C784) : color,
          ),
          const SizedBox(width: 4),
          Text(
            '$label · $name',
            style: TextStyle(
              color: ready ? const Color(0xFF81C784) : color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactionTabs() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFFFF6B35),
        indicatorWeight: 2.5,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        tabs: [
          for (final entry in _factionDisplay.entries)
            Tab(
              height: 36,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(entry.value.icon, size: 14, color: entry.value.color),
                  const SizedBox(width: 5),
                  Text(entry.value.label),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReadyButton() {
    final myReady = _mySlot == 0 ? _p1Ready : _p2Ready;
    final hasMyHero = (_mySlot == 0 ? _p1HeroId : _p2HeroId) != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 42,
        child: ElevatedButton.icon(
          onPressed: () {
            if (!hasMyHero) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please select a hero first')),
              );
              return;
            }
            _toggleReady();
          },
          icon: Icon(
            myReady ? Icons.check_circle : Icons.check_circle_outline,
            size: 18,
          ),
          label: Text(
            myReady ? 'Ready (Waiting...)' : 'Ready',
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.0),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: myReady
                ? const Color(0xFF4CAF50)
                : const Color(0xFFCC4444),
            foregroundColor: Colors.white,
            elevation: myReady ? 6 : 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroGrid(List<HeroData> heroes) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Wider screens get more columns. Landscape phones → 4-5 cols.
        final cols = (constraints.maxWidth / 150).floor().clamp(3, 6);
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            childAspectRatio: 0.78,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: heroes.length,
          itemBuilder: (context, index) => _buildHeroCard(heroes[index]),
        );
      },
    );
  }

  Widget _buildHeroCard(HeroData hero) {
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
                borderRadius: BorderRadius.circular(10),
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
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  if (isHovered && !isMine)
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.15),
                      blurRadius: 10,
                    ),
                ],
              ),
              child: child,
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
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
                        child: Center(child: _buildHeroAvatar(hero)),
                      ),
                    ),
                    // Hero info
                    Container(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hero.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            hero.title,
                            style: TextStyle(
                              color: hero.color.withValues(alpha: 0.95),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          _buildStatRow('HP', hero.hp.toInt(), 1500,
                              const Color(0xFFFF5252)),
                          const SizedBox(height: 2),
                          _buildStatRow('ATK', hero.attackPower.toInt(), 200,
                              const Color(0xFFFFB74D)),
                          const SizedBox(height: 2),
                          _buildStatRow('SPD', hero.speed.toInt(), 250,
                              const Color(0xFF4FC3F7)),
                        ],
                      ),
                    ),
                  ],
                ),
                // "MINE" badge
                if (isMine)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: hero.color,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                              color: hero.color.withValues(alpha: 0.7),
                              blurRadius: 6),
                        ],
                      ),
                      child: const Text(
                        'PICKED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
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

  Widget _buildStatRow(String label, int value, int maxValue, Color color) {
    final ratio = (value / maxValue).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 26,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: ratio,
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.7), color],
                    ),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 28,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroAvatar(HeroData hero) {
    final factionIcon =
        _factionDisplay[hero.faction]?.icon ?? Icons.person;
    return Stack(
      alignment: Alignment.center,
      children: [
        // Faction icon halo
        Icon(
          factionIcon,
          color: hero.color.withValues(alpha: 0.25),
          size: 64,
        ),
        // Avatar circle
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                hero.color.withValues(alpha: 0.9),
                hero.color.withValues(alpha: 0.5),
              ],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
            boxShadow: [
              BoxShadow(color: hero.color, blurRadius: 10, spreadRadius: 1),
            ],
          ),
          child: Center(
            child: Text(
              hero.name.isNotEmpty ? hero.name[0] : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                shadows: [
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
