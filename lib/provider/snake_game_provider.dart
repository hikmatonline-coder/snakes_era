import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../core/widgets/snake_game_widget.dart';

class LeaderboardEntry {
  final String name;
  final int score;
  final bool isPlayer;

  const LeaderboardEntry({
    required this.name,
    required this.score,
    required this.isPlayer,
  });
}

class CrownTarget {
  final Offset pos;
  final int length;
  final bool isPlayer;
  final NPCSize? npcSize;

  const CrownTarget({
    required this.pos,
    required this.length,
    required this.isPlayer,
    this.npcSize,
  });
}

class SnakeGameProvider with ChangeNotifier {
  final double worldSize = 6000.0;
  final double chunkSize = 500.0;
  final double baseSnakeSpeed = 3.5;
  final double spacing = 5.0;

  final ValueNotifier<int> frameNotifier = ValueNotifier(0);

  Offset playerPos = const Offset(3000, 3000);
  double playerAngle = 0.0;
  double targetAngle = 0.0;
  List<Offset> playerBody = [];
  Set<NPCSnake> deadNPCs = {};
  bool isLootBlinkingState = false;

  List<Food> foods = [];
  Map<String, List<Food>> chunkedFoods = {};

  List<NPCSnake> npcs = [];
  int score = 0;
  double fractionalLength = 20.0;
  int currentLengthLimit = 20;
  bool isGameOver = false;
  bool isBoosting = false;
  bool isInvincible = false;
  bool isPaused = false;
  int frameCounter = 0;

  List<LeaderboardEntry> leaderboardEntries = const [];
  List<CrownTarget> crownTargets = const [];

  int adsWatchedThisSession = 0;
  final int maxAdsPerSession = 3;
  bool isScoreDoubled = false;

  int milestonesClaimedDuringGame = 0;
  int ticketsAwardedSoFar = 0;
  Function(int tickets, String message)? onLiveTicketsRewarded;

  late List<Color> activeSkinColors;
  final List<String> botNames = [
    'Dragon',
    'Shadow',
    'Mamba',
    'Alpha',
    'Neon',
    'Viper',
    'Hunter',
    'Swift',
    'Venom',
    'Bolt',
  ];

  final List<Food> _foodQueryBuffer = [];
  final Random _rng = Random();

  void startGame(
    List<Color> skinColors, {
    Function(int, String)? onLiveTicketsRewarded,
  }) {
    this.onLiveTicketsRewarded = onLiveTicketsRewarded;
    activeSkinColors = skinColors;
    resetGame();
  }

  void resetGame() {
    playerPos = const Offset(3000, 3000);
    playerBody = List.generate(20, (i) => Offset(3000.0, 3000.0 + (i * spacing)));
    isPaused = false;
    score = 0;
    adsWatchedThisSession = 0;
    isScoreDoubled = false;
    fractionalLength = 20.0;
    currentLengthLimit = 20;
    isGameOver = false;
    isBoosting = false;
    isInvincible = false;
    frameCounter = 0;

    milestonesClaimedDuringGame = 0;
    ticketsAwardedSoFar = 0;

    foods = [];
    chunkedFoods = {};
    npcs = [];

    _spawnFood(1500);
    _spawnNPCs(40);
    _refreshHudCaches();
    frameNotifier.value = 0;
    notifyListeners();
  }

  void stopGameEngine() {
    isGameOver = true;
    isPaused = false;
    onLiveTicketsRewarded = null;
    notifyListeners();
  }

  void doubleScore() {
    if (!isScoreDoubled) {
      score *= 2;
      isScoreDoubled = true;
      notifyListeners();
    }
  }

  String getChunkKey(Offset pos) {
    final x = (pos.dx / chunkSize).floor();
    final y = (pos.dy / chunkSize).floor();
    return '$x,$y';
  }

  void _addNewFood(Food f) {
    foods.add(f);
    final key = getChunkKey(f.pos);
    chunkedFoods.putIfAbsent(key, () => []).add(f);
  }

  void _removeFood(Food f) {
    foods.remove(f);
    final key = getChunkKey(f.pos);
    chunkedFoods[key]?.remove(f);
  }

  void _collectNearbyFood(
    Offset pos,
    List<Food> buffer, {
    int chunkRadius = 1,
  }) {
    buffer.clear();
    final cx = (pos.dx / chunkSize).floor();
    final cy = (pos.dy / chunkSize).floor();

    for (int x = cx - chunkRadius; x <= cx + chunkRadius; x++) {
      for (int y = cy - chunkRadius; y <= cy + chunkRadius; y++) {
        final chunk = chunkedFoods['$x,$y'];
        if (chunk != null) {
          buffer.addAll(chunk);
        }
      }
    }
  }

  void _spawnFood(int count) {
    for (int i = 0; i < count; i++) {
      final isSmall = _rng.nextDouble() < 0.8;
      _addNewFood(
        Food(
          Offset(_rng.nextDouble() * worldSize, _rng.nextDouble() * worldSize),
          isSmall ? 0 : 1,
          Colors.primaries[_rng.nextInt(Colors.primaries.length)],
        ),
      );
    }
  }

  void _ejectBoostFood() {
    if (playerBody.length < 5) return;

    final tail = playerBody.last;
    final prevTail = playerBody[playerBody.length - 2];

    var directionAway = tail - prevTail;
    if (directionAway.distance == 0) directionAway = const Offset(1, 0);

    final spawnPos = tail + (directionAway / directionAway.distance) * 25.0;

    _addNewFood(
      Food(
        spawnPos +
            Offset(_rng.nextDouble() * 10 - 5, _rng.nextDouble() * 10 - 5),
        0,
        activeSkinColors[0],
        isLoot: true,
      ),
    );
  }

  void _handleSnakeDeath(List<Offset> bodySegments, List<Color> snakeColors) {
    final npcLootItems = <Food>[];
    const premiumColors = [
      Color(0xFFFF5E7E),
      Color(0xFF00F5D4),
      Color(0xFF7B2CBF),
      Color(0xFFFFB703),
      Color(0xFF9EF01A),
      Color(0xFF4CC9F0),
    ];

    for (int i = 0; i < bodySegments.length; i += 3) {
      final segmentPos = bodySegments[i];
      final foodColor = premiumColors[_rng.nextInt(premiumColors.length)];

      final deathLoot1 = Food(segmentPos, 2, foodColor, isLoot: true);
      _addNewFood(deathLoot1);
      npcLootItems.add(deathLoot1);

      final tightOffset = Offset(
        (_rng.nextDouble() - 0.5) * 15,
        (_rng.nextDouble() - 0.5) * 15,
      );

      final deathLoot2 = Food(segmentPos + tightOffset, 2, foodColor, isLoot: true);
      _addNewFood(deathLoot2);
      npcLootItems.add(deathLoot2);
    }

    Timer(const Duration(seconds: 7), () {
      var pulseCount = 0;

      Timer.periodic(const Duration(milliseconds: 200), (blinkTimer) {
        pulseCount++;

        if (pulseCount >= 15) {
          blinkTimer.cancel();

          for (final lootItem in npcLootItems) {
            if (foods.contains(lootItem)) {
              _removeFood(lootItem);
            }
          }
          isLootBlinkingState = false;
          notifyListeners();
          return;
        }

        isLootBlinkingState = !isLootBlinkingState;
        notifyListeners();
      });
    });
  }

  void tick(double dt) {
    if (isGameOver || isPaused) return;

    final cappedDt = dt.clamp(0.0, 0.03);
    frameCounter++;

    _movePlayerLogic(cappedDt);

    if (isBoosting && playerBody.length > 15 && frameCounter % 8 == 0) {
      _ejectBoostFood();
      fractionalLength -= 0.15;
      final newLimit = max(15, fractionalLength.toInt());
      if (newLimit != currentLengthLimit) {
        currentLengthLimit = newLimit;
      }
      if (score > 0) score -= 1;
    }

    _applyFoodMagnet(cappedDt);

    if (frameCounter % 2 == 0) {
      _checkCollisions();
    }

    for (final npc in npcs) {
      npc.move(npc.isBoosting ? 5.0 : 3.2, cappedDt);
    }

    final npcsToUpdate = (npcs.length / 2).ceil();
    for (int i = 0; i < npcsToUpdate; i++) {
      final index = (frameCounter * npcsToUpdate + i) % npcs.length;
      if (index < npcs.length) {
        npcs[index].think(
          playerBody,
          npcs,
          chunkedFoods,
          chunkSize,
          worldSize,
          _foodQueryBuffer,
        );
      }
    }

    frameNotifier.value = frameCounter;

    if (frameCounter % 20 == 0) {
      _refreshHudCaches();
      notifyListeners();
    }
  }

  void _refreshHudCaches() {
    final entries = <LeaderboardEntry>[
      LeaderboardEntry(
        name: 'YOU',
        score: currentLengthLimit,
        isPlayer: true,
      ),
      ...npcs.map(
        (n) => LeaderboardEntry(
          name: n.name,
          score: n.length,
          isPlayer: false,
        ),
      ),
    ]..sort((a, b) => b.score.compareTo(a.score));

    leaderboardEntries = entries;

    final crownCandidates = <CrownTarget>[
      CrownTarget(
        pos: playerPos,
        length: playerBody.length,
        isPlayer: true,
      ),
      ...npcs.map(
        (npc) => CrownTarget(
          pos: npc.pos,
          length: npc.body.length,
          isPlayer: false,
          npcSize: npc.size,
        ),
      ),
    ]..sort((a, b) => b.length.compareTo(a.length));

    crownTargets = crownCandidates.take(3).toList();
  }

  void _checkCollisions() {
    if (isGameOver) return;

    const borderPadding = 60.0;

    if (playerPos.dx < borderPadding ||
        playerPos.dx > (worldSize - borderPadding) ||
        playerPos.dy < borderPadding ||
        playerPos.dy > (worldSize - borderPadding)) {
      if (isInvincible) {
        playerPos = Offset(
          playerPos.dx.clamp(
            borderPadding + 10.0,
            worldSize - borderPadding - 10.0,
          ),
          playerPos.dy.clamp(
            borderPadding + 10.0,
            worldSize - borderPadding - 10.0,
          ),
        );
        playerBody[0] = playerPos;
      } else {
        _handleSnakeDeath(playerBody, activeSkinColors);
        _endGame();
        return;
      }
    }

    for (final npc in npcs) {
      _collectNearbyFood(npc.pos, _foodQueryBuffer);

      final npcHeadRadius = 10.0 + (npc.body.length / 100).clamp(0, 15);
      final eatRadiusSq = (npcHeadRadius + 5) * (npcHeadRadius + 5);
      Food? foodToEat;

      for (final f in _foodQueryBuffer) {
        if ((npc.pos - f.pos).distanceSquared < eatRadiusSq) {
          foodToEat = f;
          break;
        }
      }

      if (foodToEat != null && foods.contains(foodToEat)) {
        _removeFood(foodToEat);

        var baseGrowth = foodToEat.isLoot ? 3 : 1;
        if (npc.rank == NPCType.legend) {
          baseGrowth = foodToEat.isLoot ? 6 : 3;
        } else if (npc.rank == NPCType.pro) {
          baseGrowth = foodToEat.isLoot ? 4 : 2;
        }

        npc.grow(baseGrowth);
      }
    }

    _collectNearbyFood(playerPos, _foodQueryBuffer);

    final playerHeadRadius = 12.0 + (playerBody.length / 120).clamp(0, 10);
    final playerEatRadiusSq = playerHeadRadius * playerHeadRadius;
    Food? playerFoodToEat;

    for (final f in _foodQueryBuffer) {
      if ((playerPos - f.pos).distanceSquared < playerEatRadiusSq) {
        playerFoodToEat = f;
        break;
      }
    }

    if (playerFoodToEat != null && foods.contains(playerFoodToEat)) {
      _processFoodConsumption(playerFoodToEat);
    }

    final deadNPCsLocal = <NPCSnake>{};
    const hitRadiusSq = 16.0 * 16.0;

    for (final npc in npcs) {
      var npcDied = false;

      if (npc.pos.dx < borderPadding ||
          npc.pos.dx > worldSize - borderPadding ||
          npc.pos.dy < borderPadding ||
          npc.pos.dy > worldSize - borderPadding) {
        npcDied = true;
      }

      if (!npcDied) {
        for (final segment in playerBody.skip(3)) {
          if ((npc.pos - segment).distanceSquared < hitRadiusSq) {
            npcDied = true;
            break;
          }
        }
      }

      if (!npcDied) {
        for (final otherNpc in npcs) {
          if (identical(npc, otherNpc)) continue;
          if ((npc.pos - otherNpc.pos).distanceSquared > 90000) continue;

          for (final segment in otherNpc.body.skip(2)) {
            if ((npc.pos - segment).distanceSquared < hitRadiusSq) {
              npcDied = true;
              break;
            }
          }
          if (npcDied) break;
        }
      }

      if (npcDied) deadNPCsLocal.add(npc);
    }

    for (final npc in deadNPCsLocal) {
      _handleSnakeDeath(npc.body, npc.colors);
      npcs.remove(npc);
      _spawnSingleNPC();
    }

    if (!isInvincible) {
      for (final npc in npcs) {
        if ((playerPos - npc.pos).distanceSquared > 160000) continue;
        for (final segment in npc.body.skip(1)) {
          if ((playerPos - segment).distanceSquared < hitRadiusSq) {
            _handleSnakeDeath(playerBody, activeSkinColors);
            _endGame();
            return;
          }
        }
      }
    }

    if (foods.length < 1200) _spawnFood(200);
  }

  void _movePlayerLogic(double dt) {
    final agility = (1.0 - (playerBody.length / 3000)).clamp(0.40, 1.0);
    var diff = targetAngle - playerAngle;
    while (diff < -pi) diff += 2 * pi;
    while (diff > pi) diff -= 2 * pi;

    playerAngle += diff * (11.0 * agility * dt);

    final speedMultiplier =
        1.0 - (playerBody.length / 6000).clamp(0.0, 0.20);
    final moveSpeed = (isBoosting ? 400.0 : 240.0) * speedMultiplier;

    playerPos += Offset(
      cos(playerAngle) * moveSpeed * dt,
      sin(playerAngle) * moveSpeed * dt,
    );

    if (playerBody.isEmpty) {
      playerBody.add(playerPos);
      return;
    }

    playerBody[0] = playerPos;

    for (int i = 1; i < playerBody.length; i++) {
      final prev = playerBody[i - 1];
      final current = playerBody[i];
      final segmentDist = (prev - current).distance;

      if (segmentDist > spacing) {
        final direction = (prev - current) / segmentDist;
        playerBody[i] = prev - (direction * spacing);
      }
    }

    while (playerBody.length < currentLengthLimit) {
      playerBody.add(playerBody.last);
    }

    if (playerBody.length > currentLengthLimit) {
      playerBody.removeRange(currentLengthLimit, playerBody.length);
    }
  }

  void _applyFoodMagnet(double dt) {
    if (isGameOver || isPaused) return;

    final pX = (playerPos.dx / chunkSize).floor();
    final pY = (playerPos.dy / chunkSize).floor();

    for (int x = pX - 1; x <= pX + 1; x++) {
      for (int y = pY - 1; y <= pY + 1; y++) {
        final chunk = chunkedFoods['$x,$y'];
        if (chunk == null) continue;

        for (int i = chunk.length - 1; i >= 0; i--) {
          final food = chunk[i];
          if (!food.isLoot) continue;

          final dist = (playerPos - food.pos).distance;
          if (dist < 75.0) {
            final oldKey = getChunkKey(food.pos);
            final pullSpeed = (75.0 - dist) * 6.0 * dt;
            final direction = (playerPos - food.pos) / dist;
            food.pos += direction * pullSpeed;

            final newKey = getChunkKey(food.pos);
            if (oldKey != newKey) {
              chunkedFoods[oldKey]?.remove(food);
              chunkedFoods.putIfAbsent(newKey, () => []).add(food);
            }
          }
        }
      }
    }
  }

  void _processFoodConsumption(Food f) {
    _removeFood(f);

    if (f.isLoot) {
      score += 5;
    } else if (f.type == 0) {
      score += 1;
    } else {
      score += 3;
    }

    final expectedMilestones = score ~/ 1000;
    if (expectedMilestones > milestonesClaimedDuringGame) {
      final newMilestonesHit =
          expectedMilestones - milestonesClaimedDuringGame;
      milestonesClaimedDuringGame = expectedMilestones;

      final liveTickets = newMilestonesHit * 10;
      ticketsAwardedSoFar += liveTickets;
      onLiveTicketsRewarded?.call(
        liveTickets,
        '💥 AMAZING! +$liveTickets Live Tickets Added!',
      );
    }

    final efficiency = 1.0 / (1.0 + (playerBody.length / 600));
    final baseGrowth = f.isLoot ? 0.334 : 0.20;
    fractionalLength += baseGrowth * efficiency;

    final newLimit = fractionalLength.toInt();
    if (newLimit != currentLengthLimit) {
      currentLengthLimit = newLimit;
    }

    notifyListeners();
  }

  int getRemainingTickets() {
    final totalDeservedTickets = score ~/ 100;
    final rem = totalDeservedTickets - ticketsAwardedSoFar;
    return rem < 0 ? 0 : rem;
  }

  void finalizeAndClaimRemainingTickets(Function(int) addTicketsCallback) {
    final remaining = getRemainingTickets();
    if (remaining > 0) {
      ticketsAwardedSoFar += remaining;
      addTicketsCallback(remaining);
      notifyListeners();
    }
  }

  void _spawnSingleNPC() {
    Offset spawnPos;
    do {
      spawnPos = Offset(
        _rng.nextDouble() * (worldSize - 200) + 100,
        _rng.nextDouble() * (worldSize - 200) + 100,
      );
    } while ((spawnPos - playerPos).distance < 700);

    var name = botNames[_rng.nextInt(botNames.length)];
    var uniqueName = '$name#${_rng.nextInt(99)}';

    late int initialLength;
    late NPCType rank;
    late NPCSize sizeCategory;

    final chance = _rng.nextDouble();

    if (chance < 0.08) {
      initialLength = _rng.nextInt(50) + 120;
      rank = NPCType.legend;
      sizeCategory = NPCSize.xlarge;
      uniqueName = '👑 $name [LEGEND]';
    } else if (chance < 0.28) {
      initialLength = _rng.nextInt(40) + 70;
      rank = NPCType.pro;
      sizeCategory = NPCSize.large;
      uniqueName = '🔥 $name [PRO]';
    } else if (chance < 0.65) {
      initialLength = _rng.nextInt(20) + 35;
      rank = NPCType.beginner;
      sizeCategory = NPCSize.medium;
    } else {
      initialLength = _rng.nextInt(15) + 15;
      rank = NPCType.noob;
      sizeCategory = NPCSize.small;
    }

    npcs.add(
      NPCSnake(
        spawnPos,
        initialLength,
        [
          Colors.primaries[_rng.nextInt(Colors.primaries.length)],
          Colors.white,
        ],
        rank,
        uniqueName,
        sizeCategory,
      ),
    );
  }

  void _spawnNPCs(int count) {
    for (int i = 0; i < count; i++) {
      final spawnPos = Offset(
        _rng.nextDouble() * (worldSize - 400) + 200,
        _rng.nextDouble() * (worldSize - 400) + 200,
      );

      final name = botNames[_rng.nextInt(botNames.length)];
      var uniqueName = '$name#${_rng.nextInt(99)}';

      late int initialLength;
      late NPCType rank;
      late NPCSize sizeCategory;

      if (i < 2) {
        initialLength = _rng.nextInt(80) + 180;
        rank = NPCType.legend;
        sizeCategory = NPCSize.xlarge;
        uniqueName = '👑 $name [LEGEND]';
      } else if (i < 7) {
        initialLength = _rng.nextInt(50) + 80;
        rank = NPCType.pro;
        sizeCategory = NPCSize.large;
        uniqueName = '🔥 $name [PRO]';
      } else if (i < 20) {
        initialLength = _rng.nextInt(25) + 35;
        rank = NPCType.beginner;
        sizeCategory = NPCSize.medium;
      } else {
        initialLength = _rng.nextInt(15) + 15;
        rank = NPCType.noob;
        sizeCategory = NPCSize.small;
      }

      npcs.add(
        NPCSnake(
          spawnPos,
          initialLength,
          [
            Colors.primaries[_rng.nextInt(Colors.primaries.length)],
            Colors.white,
          ],
          rank,
          uniqueName,
          sizeCategory,
        ),
      );
    }
  }

  void togglePause() {
    if (isGameOver) return;
    isPaused = !isPaused;
    notifyListeners();
  }

  void revivePlayer() {
    isGameOver = false;
    isPaused = false;
    isInvincible = true;

    playerPos = const Offset(3000, 3000);
    playerBody = List.generate(
      currentLengthLimit,
      (_) => const Offset(3000, 3000),
    );

    foods = [];
    chunkedFoods = {};
    npcs = [];
    _spawnFood(1500);
    _spawnNPCs(40);
    frameCounter = 0;

    targetAngle = playerAngle;
    _refreshHudCaches();
    frameNotifier.value = frameCounter;
    notifyListeners();

    Timer(const Duration(seconds: 4), () {
      isInvincible = false;
      notifyListeners();
    });
  }

  void _endGame() {
    isGameOver = true;
    notifyListeners();
  }

  void setTargetAngle(double angle) => targetAngle = angle;

  void setBoosting(bool val) {
    if (isBoosting == val) return;
    isBoosting = val;
    notifyListeners();
  }

  @override
  void dispose() {
    frameNotifier.dispose();
    super.dispose();
  }
}
