import 'dart:ui';

/// Application localization helper - simple implementation
/// For full Flutter localization, use flutter_localizations package
class AppLocalizations {
  final String languageCode;
  
  AppLocalizations({this.languageCode = 'zh'});
  
  /// Get translations for current locale
  Map<String, String> get translations {
    if (languageCode == 'en') {
      return _enTranslations;
    }
    return _zhTranslations;
  }
  
  /// Get localized string by key
  String getString(String key) {
    return translations[key] ?? key;
  }
  
  /// Convenience getters for common strings
  String get singlePlayerMode => translations['single_player_mode'] ?? '单人模式';
  String get onlineBattle => translations['online_battle'] ?? '在线对战';
  String get localBattle => translations['local_battle'] ?? '本地双人';
  String get stats => translations['stats'] ?? '战绩统计';
  String get vsAI => translations['vs_ai'] ?? 'VS 电脑';
  String get draw => translations['draw'] ?? '平局';
  String get wins => translations['wins'] ?? '获胜';
  String get ready => translations['ready'] ?? '就绪';
  String get paused => translations['paused'] ?? '暂停';
  String get pressToResume => translations['press_to_resume'] ?? 'Press ESC to resume';
  String get pressToRestart => translations['press_to_restart'] ?? 'Press ENTER to restart';
  String get opponentDisconnected => translations['opponent_disconnected'] ?? '对手断开连接';
  String get reconnecting => translations['reconnecting'] ?? '重新连接中...';
  String get networkDisconnected => translations['network_disconnected'] ?? '网络断开';
  String get networkError => translations['network_error'] ?? '网络错误';
  String get exit => translations['exit'] ?? '退出';
  String get restart => translations['restart'] ?? '重开';
  String get waitingForOpponent => translations['waiting_for_opponent'] ?? '等待对手加入...';
  String get searchingForOpponent => translations['searching_for_opponent'] ?? '正在搜索对手...';
  String get cancel => translations['cancel'] ?? '取消';
  String get enterNickname => translations['enter_nickname'] ?? '输入昵称';
  String get confirm => translations['confirm'] ?? '确认';
  String get selectHero => translations['select_hero'] ?? '选择英雄';
  String get confirmSelection => translations['confirm_selection'] ?? '确认选择';
  String get totalBattles => translations['total_battles'] ?? '总对战次数';
  String get winRate => translations['win_rate'] ?? '胜率';
  String get winCount => translations['win_count'] ?? '胜利次数';
  String get lossCount => translations['loss_count'] ?? '失败次数';
  String get drawCount => translations['draw_count'] ?? '平局次数';
  String get clearStats => translations['clear_stats'] ?? '清除数据';
  String get tutorialMove => translations['tutorial_move'] ?? '使用 WASD 或摇杆移动';
  String get tutorialAttack => translations['tutorial_attack'] ?? '按 J 或攻击按钮攻击';
  String get tutorialSkill => translations['tutorial_skill'] ?? '按 K 或技能按钮释放技能';
  String get tutorialTap => translations['tutorial_tap'] ?? '点击屏幕继续';
  String get jump => translations['jump'] ?? '跳跃';
  String get attack => translations['attack'] ?? '攻击';
  String get skill => translations['skill'] ?? '技能';
  String get charge => translations['charge'] ?? '冲锋';
  String get uppercut => translations['uppercut'] ?? '上挑';
  String get slam => translations['slam'] ?? '下砸';
  String get spin => translations['spin'] ?? '旋转';
  String get shoot => translations['shoot'] ?? '射击';
  String get dash => translations['dash'] ?? '突进';
  String get lightning => translations['lightning'] ?? '闪电';
  String get arrowRain => translations['arrow_rain'] ?? '箭雨';
  String get mechanism => translations['mechanism'] ?? '机关';
  String get shieldBash => translations['shield_bash'] ?? '盾击';
  String get zenStrike => translations['zen_strike'] ?? '禅击';
  String get connectingToServer => translations['connecting_to_server'] ?? '正在连接服务器...';
  String get connectionLost => translations['connection_lost'] ?? '连接断开，请重试';
  String get connectionDisconnected => translations['connection_disconnected'] ?? '连接已断开';
  String get connectionFailed => translations['connection_failed'] ?? '连接失败';
  String get waitingForOpponentJoin => translations['waiting_for_opponent_join'] ?? '等待对手加入';
  String get matchingCancelled => translations['matching_cancelled'] ?? '已取消匹配';
  String get opponent => translations['opponent'] ?? '对手';
  String get matchFound => translations['match_found'] ?? '匹配成功！';
  String get errorOccurred => translations['error_occurred'] ?? '出错了';
  String get foundServer => translations['found_server'] ?? '发现服务器: ';
  String get searchingServers => translations['searching_servers'] ?? '正在搜索服务器...';
  String get connectingTo => translations['connecting_to'] ?? '正在连接 ';
  String get connectionFailedWithError => translations['connection_failed_with_error'] ?? '连接失败: ';
  String get noLanServer => translations['no_lan_server'] ?? '未找到局域网服务器';
  String get noServerFound => translations['no_server_found'] ?? '未找到服务器';
  String get enteringQueue => translations['entering_queue'] ?? '进入匹配队列...';
  String get retrySearch => translations['retry_search'] ?? '重新搜索服务器...';
  String get lanMatch => translations['lan_match'] ?? '局域网匹配';
  String get onlineMatch => translations['online_match'] ?? '在线匹配';
  String get inQueue => translations['in_queue'] ?? '队列中';
  String get lookingForOpponent => translations['looking_for_opponent'] ?? '正在寻找实力相当的对手...';
  String get opponentFound => translations['opponent_found'] ?? '对手已找到';
  String get enteringHeroSelection => translations['entering_hero_selection'] ?? '即将进入英雄选择...';
  String get unknownError => translations['unknown_error'] ?? '未知错误';
  String get ensureDeviceRunning => translations['ensure_device_running'] ?? '请确保另一台设备也在运行游戏并开启了服务器';
  String get retry => translations['retry'] ?? '重试';
  String get back => translations['back'] ?? '返回';
  String get cancelMatching => translations['cancel_matching'] ?? '取消匹配';
  String get nicknameEmpty => translations['nickname_empty'] ?? '昵称不能为空';
  String get nicknameTooLong => translations['nickname_too_long'] ?? '昵称过长';
  String get setNickname => translations['set_nickname'] ?? '设置昵称';
  String get changeNickname => translations['change_nickname'] ?? '修改昵称';
  String get enterNicknameHint => translations['enter_nickname_hint'] ?? '请输入你的游戏昵称，将在排行榜中展示';
  String get enterNicknamePlaceholder => translations['enter_nickname_placeholder'] ?? '输入昵称';
  String get myStats => translations['my_stats'] ?? '我的战绩';
  String get globalLeaderboard => translations['global_leaderboard'] ?? '世界排行榜';
  String get noStatsYet => translations['no_stats_yet'] ?? '暂无战绩数据';
  String get completeMatchToRecord => translations['complete_match_to_record'] ?? '完成一场对战后数据将自动记录';
  String get overall => translations['overall'] ?? '总战绩';
  String get totalGames => translations['total_games'] ?? '总场数';
  String get winsLabel => translations['wins_label'] ?? '胜场';
  String get losses => translations['losses'] ?? '负场';
  String get draws => translations['draws'] ?? '平局';
  String get topHeroes => translations['top_heroes'] ?? '擅长英雄 TOP 3';
  String get needMoreGames => translations['need_more_games'] ?? '需要更多场次解锁';
  String get gamesRemaining => translations['games_remaining'] ?? 'Play more games to unlock';
  String get heroStats => translations['hero_stats'] ?? '英雄战绩详情';
  String get noHeroStats => translations['no_hero_stats'] ?? '暂无英雄使用记录';
  String get resetData => translations['reset_data'] ?? '重置数据';
  String get confirmReset => translations['confirm_reset'] ?? '确定要清除所有战绩数据吗？此操作不可撤销。';
  String get controlsAi => translations['controls_ai'] ?? 'WASD移动 | J攻击 | K技能';
  String get controlsLocal => translations['controls_local'] ?? 'P1: WASD+J/K   P2: 方向键+小键盘1/2';
  String get controlsNetworkP1 => translations['controls_network_p1'] ?? '你的英雄: WASD+J/K  对手: 网络同步';
  String get controlsNetworkP2 => translations['controls_network_p2'] ?? '你的英雄: 方向键+小键盘1/2  对手: 网络同步';
  
  // Tutorial step keys
  String get tutorialStep1Title => translations['tutorial_step_1_title'] ?? '第1步：移动';
  String get tutorialStep1Keyboard => translations['tutorial_step_1_keyboard'] ?? 'WASD 键控制角色移动\n↑↓←→ 八方向自由移动';
  String get tutorialStep1Touch => translations['tutorial_step_1_touch'] ?? '左侧虚拟摇杆\n拖动控制移动方向';
  String get tutorialStep2Title => translations['tutorial_step_2_title'] ?? '第2步：攻击';
  String get tutorialStep2Keyboard => translations['tutorial_step_2_keyboard'] ?? 'J 键发动普通攻击\n连续按可触发连击';
  String get tutorialStep2Touch => translations['tutorial_step_2_touch'] ?? '右侧「攻击」按钮\n连续点击触发连击';
  String get tutorialStep3Title => translations['tutorial_step_3_title'] ?? '第3步：技能';
  String get tutorialStep3Keyboard => translations['tutorial_step_3_keyboard'] ?? 'K 键释放英雄技能\n技能有冷却时间，注意时机';
  String get tutorialStep3Touch => translations['tutorial_step_3_touch'] ?? '右侧「技能」按钮\n冷却结束后可再次释放';
  String get tutorialStep4Title => translations['tutorial_step_4_title'] ?? '准备战斗！';
  String get tutorialStep4Keyboard => translations['tutorial_step_4_keyboard'] ?? '击败对手获得胜利\nESC 暂停游戏';
  String get tutorialStep4Touch => translations['tutorial_step_4_touch'] ?? '击败对手获得胜利\n祝你好运！';
  String get tutorialHint => translations['tutorial_hint'] ?? '点击屏幕继续  |  按 ESC 跳过';
  
  // Hero directional attack labels
  String get chargeStrike => translations['charge_strike'] ?? '冲刺斩';
  String get downwardSlash => translations['downward_slash'] ?? '下劈';
  String get mechanismCrossbow => translations['mechanism_crossbow'] ?? '机关弩箭';
  String get skyArrow => translations['sky_arrow'] ?? '冲天弩';
  String get groundFire => translations['ground_fire'] ?? '地火术';
  String get whirlwindKick => translations['whirlwind_kick'] ?? '旋风腿';
  String get skyKick => translations['sky_kick'] ?? '冲天脚';
  String get earthquakeHammer => translations['earthquake_hammer'] ?? '震地锤';
  String get shieldBashCharge => translations['shield_bash_charge'] ?? '盾击冲锋';
  String get counterShield => translations['counter_shield'] ?? '回盾反击';
  String get savageFist => translations['savage_fist'] ?? '蛮荒巨拳';
  String get earthShatter => translations['earth_shatter'] ?? '地裂震击';
  String get thrust => translations['thrust'] ?? '突刺';
  String get jumpingKick => translations['jumping_kick'] ?? '跳跃踢';
  String get magicBullet => translations['magic_bullet'] ?? '魔法弹';
  String get magicUp => translations['magic_up'] ?? '上方魔法';
  String get stunCard => translations['stun_card'] ?? '定身符';
  String get earthTrap => translations['earth_trap'] ?? '地煞符';
  String get sunArrow => translations['sun_arrow'] ?? '烈日箭';
  String get skyShot => translations['sky_shot'] ?? '天射';
  String get hammerSweep => translations['hammer_sweep'] ?? '雷锤横扫';
  String get hammerGround => translations['hammer_ground'] ?? '雷锤砸地';
  String get gamesPlayed => translations['games_played'] ?? 'games';
  String get connected => translations['connected'] ?? '已连接';
  String get disconnected => translations['disconnected'] ?? '断开';
  String get gamesSuffix => translations['games_suffix'] ?? 'games';
  String get winsSuffix => translations['wins_suffix'] ?? 'wins';
  String get lossesSuffix => translations['losses_suffix'] ?? 'losses';
  
  /// Create instance from system locale
  static AppLocalizations fromSystemLocale() {
    final systemLocale = PlatformDispatcher.instance.locale;
    final langCode = systemLocale.languageCode == 'en' ? 'en' : 'zh';
    return AppLocalizations(languageCode: langCode);
  }
  
  /// Chinese translations (default)
  static const Map<String, String> _zhTranslations = {
    'single_player_mode': '单人模式',
    'online_battle': '在线对战',
    'local_battle': '本地双人',
    'stats': '战绩统计',
    'vs_ai': 'VS 电脑',
    'draw': '平局',
    'wins': '获胜',
    'ready': '就绪',
    'paused': '暂停',
    'press_to_resume': '按 ESC 继续',
    'press_to_restart': '按 回车键 重新开始',
    'opponent_disconnected': '对手断开连接',
    'reconnecting': '重新连接中...',
    'network_disconnected': '网络断开',
    'network_error': '网络错误',
    'exit': '退出',
    'restart': '重开',
    'waiting_for_opponent': '等待对手加入...',
    'searching_for_opponent': '正在搜索对手...',
    'cancel': '取消',
    'enter_nickname': '输入昵称',
    'confirm': '确认',
    'select_hero': '选择英雄',
    'confirm_selection': '确认选择',
    'total_battles': '总对战次数',
    'win_rate': '胜率',
    'win_count': '胜利次数',
    'loss_count': '失败次数',
    'draw_count': '平局次数',
    'clear_stats': '清除数据',
    'tutorial_move': '使用 WASD 或摇杆移动',
    'tutorial_attack': '按 J 或攻击按钮攻击',
    'tutorial_skill': '按 K 或技能按钮释放技能',
    'tutorial_tap': '点击屏幕继续',
    'jump': '跳跃',
    'attack': '攻击',
    'skill': '技能',
    'charge': '冲锋',
    'uppercut': '上挑',
    'slam': '下砸',
    'spin': '旋转',
    'shoot': '射击',
    'dash': '突进',
    'lightning': '闪电',
    'arrow_rain': '箭雨',
    'mechanism': '机关',
    'shield_bash': '盾击',
    'zen_strike': '禅击',
    'connecting_to_server': '正在连接服务器...',
    'connection_lost': '连接断开，请重试',
    'connection_disconnected': '连接已断开',
    'connection_failed': '连接失败',
    'waiting_for_opponent_join': '等待对手加入',
    'matching_cancelled': '已取消匹配',
    'opponent': '对手',
    'match_found': '匹配成功！',
    'error_occurred': '出错了',
    'found_server': '发现服务器: ',
    'searching_servers': '正在搜索服务器...',
    'connecting_to': '正在连接 ',
    'connection_failed_with_error': '连接失败: ',
    'no_lan_server': '未找到局域网服务器',
    'no_server_found': '未找到服务器',
    'entering_queue': '进入匹配队列...',
    'retry_search': '重新搜索服务器...',
    'lan_match': '局域网匹配',
    'online_match': '在线匹配',
    'in_queue': '队列中',
    'looking_for_opponent': '正在寻找实力相当的对手...',
    'opponent_found': '对手已找到',
    'entering_hero_selection': '即将进入英雄选择...',
    'unknown_error': '未知错误',
    'ensure_device_running': '请确保另一台设备也在运行游戏并开启了服务器',
    'retry': '重试',
    'back': '返回',
    'cancel_matching': '取消匹配',
    'nickname_empty': '昵称不能为空',
    'nickname_too_long': '昵称过长',
    'enter_nickname_placeholder': '输入昵称',
    'set_nickname': '设置昵称',
    'change_nickname': '修改昵称',
    'enter_nickname_hint': '请输入你的游戏昵称，将在排行榜中展示',
    'my_stats': '我的战绩',
    'global_leaderboard': '世界排行榜',
    'no_stats_yet': '暂无战绩数据',
    'complete_match_to_record': '完成一场对战后数据将自动记录',
    'overall': '总战绩',
    'total_games': '总场数',
    'wins_label': '胜场',
    'losses': '负场',
    'draws': '平局',
    'top_heroes': '擅长英雄 TOP 3',
    'need_more_games': '需要更多场次解锁',
    'games_remaining': 'Play more games to unlock',
    'hero_stats': '英雄战绩详情',
    'no_hero_stats': '暂无英雄使用记录',
    'reset_data': '重置数据',
    'confirm_reset': '确定要清除所有战绩数据吗？此操作不可撤销。',
    'controls_ai': 'WASD移动 | J攻击 | K技能',
    'controls_local': 'P1: WASD+J/K   P2: 方向键+小键盘1/2',
    'controls_network_p1': '你的英雄: WASD+J/K  对手: 网络同步',
    'controls_network_p2': '你的英雄: 方向键+小键盘1/2  对手: 网络同步',
    // Tutorial
    'tutorial_step_1_title': '第1步：移动',
    'tutorial_step_1_keyboard': 'WASD 键控制角色移动\n↑↓←→ 八方向自由移动',
    'tutorial_step_1_touch': '左侧虚拟摇杆\n拖动控制移动方向',
    'tutorial_step_2_title': '第2步：攻击',
    'tutorial_step_2_keyboard': 'J 键发动普通攻击\n连续按可触发连击',
    'tutorial_step_2_touch': '右侧「攻击」按钮\n连续点击触发连击',
    'tutorial_step_3_title': '第3步：技能',
    'tutorial_step_3_keyboard': 'K 键释放英雄技能\n技能有冷却时间，注意时机',
    'tutorial_step_3_touch': '右侧「技能」按钮\n冷却结束后可再次释放',
    'tutorial_step_4_title': '准备战斗！',
    'tutorial_step_4_keyboard': '击败对手获得胜利\nESC 暂停游戏',
    'tutorial_step_4_touch': '击败对手获得胜利\n祝你好运！',
    'tutorial_hint': '点击屏幕继续  |  按 ESC 跳过',
    // Hero directional attack labels
    'charge_strike': '冲刺斩',
    'downward_slash': '下劈',
    'mechanism_crossbow': '机关弩箭',
    'sky_arrow': '冲天弩',
    'ground_fire': '地火术',
    'whirlwind_kick': '旋风腿',
    'sky_kick': '冲天脚',
    'earthquake_hammer': '震地锤',
    'shield_bash_charge': '盾击冲锋',
    'counter_shield': '回盾反击',
    'savage_fist': '蛮荒巨拳',
    'earth_shatter': '地裂震击',
    'thrust': '突刺',
    'jumping_kick': '跳跃踢',
    'magic_bullet': '魔法弹',
    'magic_up': '上方魔法',
    'stun_card': '定身符',
    'earth_trap': '地煞符',
    'sun_arrow': '烈日箭',
    'sky_shot': '天射',
    'hammer_sweep': '雷锤横扫',
    'hammer_ground': '雷锤砸地',
    'games_played': '场',
    'connected': '已连接',
    'disconnected': '断开',
    'games_suffix': '场',
    'wins_suffix': '胜',
    'losses_suffix': '负',
  };
  
  /// English translations
  static const Map<String, String> _enTranslations = {
    'single_player_mode': 'Single Player',
    'online_battle': 'Online Battle',
    'local_battle': 'Local Battle',
    'stats': 'Statistics',
    'vs_ai': 'vs AI',
    'draw': 'Draw',
    'wins': 'Wins',
    'ready': 'Ready',
    'paused': 'Paused',
    'press_to_resume': 'Press ESC to resume',
    'press_to_restart': 'Press ENTER to restart',
    'opponent_disconnected': 'Opponent disconnected',
    'reconnecting': 'Reconnecting...',
    'network_disconnected': 'Network disconnected',
    'network_error': 'Network error',
    'exit': 'Exit',
    'restart': 'Restart',
    'waiting_for_opponent': 'Waiting for opponent...',
    'searching_for_opponent': 'Searching for opponent...',
    'cancel': 'Cancel',
    'enter_nickname': 'Enter Nickname',
    'confirm': 'Confirm',
    'select_hero': 'Select Hero',
    'confirm_selection': 'Confirm',
    'total_battles': 'Total Battles',
    'win_rate': 'Win Rate',
    'win_count': 'Wins',
    'loss_count': 'Losses',
    'draw_count': 'Draws',
    'clear_stats': 'Clear Data',
    'tutorial_move': 'Use WASD or joystick to move',
    'tutorial_attack': 'Press J or attack button to attack',
    'tutorial_skill': 'Press K or skill button to use skill',
    'tutorial_tap': 'Tap to continue',
    'jump': 'Jump',
    'attack': 'Attack',
    'skill': 'Skill',
    'charge': 'Charge',
    'uppercut': 'Uppercut',
    'slam': 'Slam',
    'spin': 'Spin',
    'shoot': 'Shoot',
    'dash': 'Dash',
    'lightning': 'Lightning',
    'arrow_rain': 'Arrow Rain',
    'mechanism': 'Mechanism',
    'shield_bash': 'Shield Bash',
    'zen_strike': 'Zen Strike',
    'connecting_to_server': 'Connecting to server...',
    'connection_lost': 'Connection lost, please retry',
    'connection_disconnected': 'Connection disconnected',
    'connection_failed': 'Connection failed',
    'waiting_for_opponent_join': 'Waiting for opponent',
    'matching_cancelled': 'Matching cancelled',
    'opponent': 'Opponent',
    'match_found': 'Match found!',
    'error_occurred': 'Error',
    'found_server': 'Found server: ',
    'searching_servers': 'Searching for servers...',
    'connecting_to': 'Connecting to ',
    'connection_failed_with_error': 'Connection failed: ',
    'no_lan_server': 'No LAN server found',
    'no_server_found': 'No server found',
    'entering_queue': 'Entering matchmaking queue...',
    'retry_search': 'Searching for servers again...',
    'lan_match': 'LAN Match',
    'online_match': 'Online Match',
    'in_queue': 'In Queue',
    'looking_for_opponent': 'Looking for a suitable opponent...',
    'opponent_found': 'Opponent found',
    'entering_hero_selection': 'Entering hero selection...',
    'unknown_error': 'Unknown error',
    'ensure_device_running': 'Make sure another device is running the game with server enabled',
    'retry': 'Retry',
    'back': 'Back',
    'cancel_matching': 'Cancel Match',
    'nickname_empty': 'Nickname cannot be empty',
    'nickname_too_long': 'Nickname too long',
    'enter_nickname_placeholder': 'Enter nickname',
    'set_nickname': 'Set Nickname',
    'change_nickname': 'Change Nickname',
    'enter_nickname_hint': 'Enter your game nickname, which will be shown on the leaderboard',
    'my_stats': 'My Stats',
    'global_leaderboard': 'Global Leaderboard',
    'no_stats_yet': 'No stats yet',
    'complete_match_to_record': 'Complete a match to record stats',
    'overall': 'Overall',
    'total_games': 'Total',
    'wins_label': 'Wins',
    'losses': 'Losses',
    'draws': 'Draws',
    'top_heroes': 'Top 3 Heroes',
    'need_more_games': 'Need more games to unlock',
    'games_remaining': 'Play more games to unlock',
    'hero_stats': 'Hero Stats',
    'no_hero_stats': 'No hero stats',
    'reset_data': 'Reset Data',
    'confirm_reset': 'Clear all stats? This cannot be undone.',
    'controls_ai': 'WASD Move | J Attack | K Skill',
    'controls_local': 'P1: WASD+J/K   P2: Arrows+Num1/2',
    'controls_network_p1': 'Your Hero: WASD+J/K  Opponent: Network Sync',
    'controls_network_p2': 'Your Hero: Arrows+Num1/2  Opponent: Network Sync',
    // Tutorial
    'tutorial_step_1_title': 'Step 1: Move',
    'tutorial_step_1_keyboard': 'WASD to move\nArrow keys for 8 directions',
    'tutorial_step_1_touch': 'Left virtual joystick\nDrag to move',
    'tutorial_step_2_title': 'Step 2: Attack',
    'tutorial_step_2_keyboard': 'J to attack\nTap repeatedly for combos',
    'tutorial_step_2_touch': 'Right Attack button\nTap for combos',
    'tutorial_step_3_title': 'Step 3: Skill',
    'tutorial_step_3_keyboard': 'K for hero skill\nWatch the cooldown',
    'tutorial_step_3_touch': 'Right Skill button\nUse after cooldown',
    'tutorial_step_4_title': 'Ready to Fight!',
    'tutorial_step_4_keyboard': 'Defeat your opponent\nESC to pause',
    'tutorial_step_4_touch': 'Defeat your opponent\nGood luck!',
    'tutorial_hint': 'Tap to continue  |  ESC to skip',
    // Hero directional attack labels
    'charge_strike': 'Charge Strike',
    'downward_slash': 'Down Slash',
    'mechanism_crossbow': 'Crossbow Bolt',
    'sky_arrow': 'Sky Arrow',
    'ground_fire': 'Ground Fire',
    'whirlwind_kick': 'Whirlwind Kick',
    'sky_kick': 'Sky Kick',
    'earthquake_hammer': 'Quake Hammer',
    'shield_bash_charge': 'Shield Charge',
    'counter_shield': 'Counter Shield',
    'savage_fist': 'Savage Fist',
    'earth_shatter': 'Earth Shatter',
    'thrust': 'Thrust',
    'jumping_kick': 'Jump Kick',
    'magic_bullet': 'Magic Bullet',
    'magic_up': 'Magic Up',
    'stun_card': 'Stun Card',
    'earth_trap': 'Earth Trap',
    'sun_arrow': 'Sun Arrow',
    'sky_shot': 'Sky Shot',
    'hammer_sweep': 'Hammer Sweep',
    'hammer_ground': 'Hammer Slam',
    'games_played': 'games',
    'connected': 'Connected',
    'disconnected': 'Disconnected',
    'games_suffix': 'games',
    'wins_suffix': 'wins',
    'losses_suffix': 'losses',
  };
}