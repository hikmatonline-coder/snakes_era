import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../core/widgets/snake_game_widget.dart';

class SnakeGameProvider with ChangeNotifier {
  // --- Constants ---
  final double worldSize = 6000.0;
  final double chunkSize = 500.0;
  final double baseSnakeSpeed = 3.5;
  final double spacing = 5.0; // Optimized spacing for smooth render

  // --- State Variables ---
  Offset playerPos = const Offset(3000, 3000);
  double playerAngle = 0.0;
  double targetAngle = 0.0;
  List<Offset> playerBody = [];
  Set<NPCSnake> deadNPCs = {};

  // Chunks mapping for extreme performance stability
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

  int adsWatchedThisSession = 0;
  final int maxAdsPerSession = 3;
  bool isScoreDoubled = false;

  Timer? gameTimer;
  DateTime _lastTick = DateTime.now();
  late List<Color> activeSkinColors;
  final List<String> botNames = ["Dragon", "Shadow", "Mamba", "Alpha", "Neon", "Viper", "Hunter", "Swift", "Venom", "Bolt"];

  // --- Core Lifecycle ---
  void startGame(List<Color> skinColors) {
    activeSkinColors = skinColors;
    resetGame();
  }

  void resetGame() {
    gameTimer?.cancel();
    playerPos = const Offset(3000, 3000);

    // Initialize standard fixed array length safely
    playerBody = List.generate(20, (i) => Offset(3000.0, 3000.0 + (i * spacing)));
    score = 0;
    adsWatchedThisSession = 0;
    isScoreDoubled = false;
    fractionalLength = 20.0;
    currentLengthLimit = 20;
    isGameOver = false;
    isBoosting = false;
    isInvincible = false;

    foods = [];
    chunkedFoods = {};
    npcs = [];

    _spawnFood(1500);
    _spawnNPCs(40);

    _lastTick = DateTime.now();
    gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) => _gameTick());
    notifyListeners();
  }

  void doubleScore() {
    if (!isScoreDoubled) {
      score *= 2;
      isScoreDoubled = true;
      notifyListeners();
    }
  }

  // --- Spatial Hashing (Chunks Management) ---
  String getChunkKey(Offset pos) {
    int x = (pos.dx / chunkSize).floor();
    int y = (pos.dy / chunkSize).floor();
    return "$x,$y";
  }

  void _addNewFood(Food f) {
    foods.add(f);
    String key = getChunkKey(f.pos);
    chunkedFoods.putIfAbsent(key, () => []).add(f);
  }

  void _removeFood(Food f) {
    foods.remove(f);
    String key = getChunkKey(f.pos);
    if (chunkedFoods.containsKey(key)) {
      chunkedFoods[key]!.remove(f);
    }
    for (var list in chunkedFoods.values) {
      list.remove(f);
    }
  }

  // --- Spawning Logic ---
  void _spawnFood(int count) {
    var rng = Random();
    for (int i = 0; i < count; i++) {
      bool isSmall = rng.nextDouble() < 0.8;
      Food newFood = Food(
          Offset(rng.nextDouble() * worldSize, rng.nextDouble() * worldSize),
          isSmall ? 0 : 1,
          Colors.primaries[rng.nextInt(Colors.primaries.length)],
          isLoot: false
      );
      _addNewFood(newFood);
    }
  }

  void _ejectBoostFood() {
    if (playerBody.length < 5) return;

    var rng = Random();
    Offset tail = playerBody.last;
    Offset prevTail = playerBody[playerBody.length - 2];

    Offset directionAway = (tail - prevTail);
    if (directionAway.distance == 0) directionAway = const Offset(1, 0);

    Offset spawnPos = tail + (directionAway / directionAway.distance) * 25.0;

    Food boostLoot = Food(
      spawnPos + Offset(rng.nextDouble() * 10 - 5, rng.nextDouble() * 10 - 5),
      0,
      activeSkinColors[0],
      isLoot: true,
    );
    _addNewFood(boostLoot);
  }

  void _handleSnakeDeath(List<Offset> bodySegments, List<Color> snakeColors) {
    var rng = Random();
    for (int i = 0; i < bodySegments.length; i += 6) {
      Food deathLoot = Food(
        bodySegments[i] + Offset(rng.nextDouble() * 12 - 6, rng.nextDouble() * 12 - 6),
        rng.nextInt(3),
        snakeColors[i % snakeColors.length],
        isLoot: true,
      );
      _addNewFood(deathLoot);
    }
  }

  // --- Game Loop ---
  void _gameTick() {
    if (isGameOver || isPaused) return;

    final now = DateTime.now();
    final double dt = now.difference(_lastTick).inMicroseconds / 1000000.0;
    double cappedDt = dt.clamp(0.0, 0.03);
    _lastTick = now;

    frameCounter++;
    _movePlayerLogic(cappedDt);

    if (isBoosting && playerBody.length > 15) {
      if (frameCounter % 8 == 0) {
        _ejectBoostFood();
        fractionalLength -= 0.15;
        currentLengthLimit = max(15, fractionalLength.toInt());
        if (score > 0) score -= 1;
      }
    }

    _applyFoodMagnet(cappedDt);

    if (frameCounter % 2 == 0) {
      _checkCollisions();
    }

    for (var npc in npcs) {
      npc.move(npc.isBoosting ? 5.0 : 3.2, cappedDt);
    }

    int npcsToUpdate = (npcs.length / 2).ceil();
    for (int i = 0; i < npcsToUpdate; i++) {
      int index = (frameCounter * npcsToUpdate + i) % npcs.length;
      if (index < npcs.length) {
        npcs[index].think(playerBody, npcs, foods, worldSize);
      }
    }

    notifyListeners();
  }

  void _checkCollisions() {
    if (isGameOver) return;

    // 1. BORDER CHECK
    if (playerPos.dx < 0 || playerPos.dx > worldSize || playerPos.dy < 0 || playerPos.dy > worldSize) {
      if (isInvincible) {
        playerPos = Offset(playerPos.dx.clamp(50.0, worldSize - 50.0), playerPos.dy.clamp(50.0, worldSize - 50.0));
        playerBody[0] = playerPos;
      } else {
        _handleSnakeDeath(playerBody, activeSkinColors);
        _endGame();
        return;
      }
    }

    // 2. BOT FOOD INTERACTION SYSTEM
    for (var npc in npcs) {
      int nX = (npc.pos.dx / chunkSize).floor();
      int nY = (npc.pos.dy / chunkSize).floor();
      List<Food> localFood = [];

      for (int x = nX - 1; x <= nX + 1; x++) {
        for (int y = nY - 1; y <= nY + 1; y++) {
          var chunk = chunkedFoods["$x,$y"];
          if (chunk != null) localFood.addAll(chunk);
        }
      }

      double npcHeadRadius = 10.0 + (npc.body.length / 100).clamp(0, 15);
      Food? foodToEat;

      for (var f in localFood) {
        if ((npc.pos - f.pos).distance < npcHeadRadius + 5) {
          foodToEat = f;
          break;
        }
      }

      if (foodToEat != null && foods.contains(foodToEat)) {
        _removeFood(foodToEat);
        npc.grow(max(1, ((foodToEat.isLoot ? 2 : 1) * 0.70).round()));
      }
    }

    // 3. HUMAN PLAYER COLLISION SWEEP (STRICT DIRECT CONTACT)
    int pX = (playerPos.dx / chunkSize).floor();
    int pY = (playerPos.dy / chunkSize).floor();
    List<Food> playerLocalFood = [];
    for (int x = pX - 1; x <= pX + 1; x++) {
      for (int y = pY - 1; y <= pY + 1; y++) {
        var chunk = chunkedFoods["$x,$y"];
        if (chunk != null) playerLocalFood.addAll(chunk);
      }
    }

    double playerHeadRadius = 12.0 + (playerBody.length / 120).clamp(0, 10);
    Food? playerFoodToEat;

    for (var f in playerLocalFood) {
      if ((playerPos - f.pos).distance < playerHeadRadius) {
        playerFoodToEat = f;
        break;
      }
    }

    if (playerFoodToEat != null && foods.contains(playerFoodToEat)) {
      _processFoodConsumption(playerFoodToEat);
    }

    // 4. COMBAT COMBINATORICS
    Set<NPCSnake> deadNPCsLocal = {};

    for (var npc in npcs) {
      bool npcDied = false;

      if (npc.pos.dx < 5 || npc.pos.dx > worldSize - 5 || npc.pos.dy < 5 || npc.pos.dy > worldSize - 5) {
        npcDied = true;
      }

      if (!npcDied) {
        for (var segment in playerBody.skip(3)) {
          if ((npc.pos - segment).distance < 16) {
            npcDied = true;
            break;
          }
        }
      }

      if (!npcDied) {
        for (var otherNpc in npcs) {
          if (identical(npc, otherNpc)) continue;
          if ((npc.pos - otherNpc.pos).distance > 300) continue;

          for (var segment in otherNpc.body.skip(2)) {
            if ((npc.pos - segment).distance < 16) {
              npcDied = true;
              break;
            }
          }
          if (npcDied) break;
        }
      }

      if (npcDied) deadNPCsLocal.add(npc);
    }

    for (var npc in deadNPCsLocal) {
      _handleSnakeDeath(npc.body, npc.colors);
      npcs.remove(npc);
      _spawnSingleNPC();
    }

    // 5. HUMAN CASUALTY CHECKER
    if (!isInvincible) {
      for (var npc in npcs) {
        if ((playerPos - npc.pos).distance > 400) continue;
        for (var segment in npc.body.skip(1)) {
          if ((playerPos - segment).distance < 16) {
            _handleSnakeDeath(playerBody, activeSkinColors);
            _endGame();
            return;
          }
        }
      }
    }

    if (foods.length < 1200) _spawnFood(200);
  }

  // --- FIXED SMOOTH INTERPOLATION MOVEMENT ENGINE ---
  void _movePlayerLogic(double dt) {
    double agility = (1.0 - (playerBody.length / 3000)).clamp(0.40, 1.0);
    double diff = targetAngle - playerAngle;
    while (diff < -pi) diff += 2 * pi;
    while (diff > pi) diff -= 2 * pi;

    playerAngle += diff * (11.0 * agility * dt);
    double speedMultiplier = 1.0 - (playerBody.length / 4000).clamp(0.0, 0.35);
    double moveSpeed = (isBoosting ? 390.0 : 220.0) * speedMultiplier;

    // 1. Move Head Point
    playerPos += Offset(cos(playerAngle) * moveSpeed * dt, sin(playerAngle) * moveSpeed * dt);

    if (playerBody.isEmpty) {
      playerBody.add(playerPos);
      return;
    }

    // 2. Head is always at index 0
    playerBody[0] = playerPos;

    // 3. Smoothly drag each subsequent segment toward the previous one with explicit spacing constraint
    for (int i = 1; i < playerBody.length; i++) {
      Offset prev = playerBody[i - 1];
      Offset current = playerBody[i];
      double segmentDist = (prev - current).distance;

      if (segmentDist > spacing) {
        // Calculate precise mathematical position vector to eliminate lag/glitch
        Offset direction = (prev - current) / segmentDist;
        playerBody[i] = prev - (direction * spacing);
      }
    }

    // 4. Dynamic Growth Guard: Automatically adds segments matching the current score limit safely
    while (playerBody.length < currentLengthLimit) {
      playerBody.add(playerBody.last);
    }

    // Dynamic Tail Cutter
    if (playerBody.length > currentLengthLimit) {
      playerBody = playerBody.sublist(0, currentLengthLimit);
    }
  }

  // --- CLEANED MAGNET SYSTEM ---
  void _applyFoodMagnet(double dt) {
    if (isGameOver || isPaused) return;

    int pX = (playerPos.dx / chunkSize).floor();
    int pY = (playerPos.dy / chunkSize).floor();

    for (int x = pX - 1; x <= pX + 1; x++) {
      for (int y = pY - 1; y <= pY + 1; y++) {
        var chunk = chunkedFoods["$x,$y"];
        if (chunk == null) continue;

        for (int i = chunk.length - 1; i >= 0; i--) {
          var food = chunk[i];
          if (food.isLoot) {
            double dist = (playerPos - food.pos).distance;

            if (dist < 75.0) {
              String oldKey = getChunkKey(food.pos);

              double pullSpeed = (75.0 - dist) * 6.0 * dt;
              Offset direction = (playerPos - food.pos) / dist;
              food.pos += direction * pullSpeed;

              String newKey = getChunkKey(food.pos);

              if (oldKey != newKey) {
                chunkedFoods[oldKey]?.remove(food);
                chunkedFoods.putIfAbsent(newKey, () => []).add(food);
              }
            }
          }
        }
      }
    }
  }

  // --- SCORE & PLAYER GROWTH CONTROL ---
  void _processFoodConsumption(Food f) {
    _removeFood(f);

    if (f.isLoot) {
      score += 5;
    } else if (f.type == 0) {
      score += 1;
    } else {
      score += 3;
    }

    double efficiency = 1.0 / (1.0 + (playerBody.length / 600));
    double baseGrowth = f.isLoot ? 1.0 : 0.4;
    double growth = baseGrowth * 0.70 * efficiency;

    fractionalLength += growth;
    currentLengthLimit = fractionalLength.toInt();
  }

  void _spawnSingleNPC() {
    var rng = Random();
    Offset spawnPos;
    do {
      spawnPos = Offset(rng.nextDouble() * (worldSize - 200) + 100, rng.nextDouble() * (worldSize - 200) + 100);
    } while ((spawnPos - playerPos).distance < 700);

    String name = botNames[rng.nextInt(botNames.length)];
    String uniqueName = "$name#${rng.nextInt(99)}";

    npcs.add(NPCSnake(
        spawnPos,
        rng.nextInt(25) + 20,
        [Colors.primaries[rng.nextInt(Colors.primaries.length)], Colors.white],
        NPCType.beginner,
        uniqueName,
        NPCSize.medium
    ));
  }

  void _spawnNPCs(int count) {
    for (int i = 0; i < count; i++) _spawnSingleNPC();
  }

  void togglePause() {
    if (isGameOver) return;
    isPaused = !isPaused;
    if (!isPaused) _lastTick = DateTime.now();
    notifyListeners();
  }

  void revivePlayer() {
    isGameOver = false;
    isPaused = false;
    isInvincible = true;

    playerPos = const Offset(3000, 3000);
    playerBody = List.generate(currentLengthLimit, (i) => const Offset(3000, 3000));

    foods = [];
    chunkedFoods = {};
    npcs = [];
    _spawnFood(1500);
    _spawnNPCs(40);

    targetAngle = playerAngle;
    gameTimer?.cancel();
    _lastTick = DateTime.now();
    gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) => _gameTick());

    notifyListeners();

    Timer(const Duration(seconds: 4), () {
      isInvincible = false;
      notifyListeners();
    });
  }

  void _endGame() {
    isGameOver = true;
    gameTimer?.cancel();
    notifyListeners();
  }

  void setTargetAngle(double angle) => targetAngle = angle;
  void setBoosting(bool val) { isBoosting = val; notifyListeners(); }

  @override
  void dispose() { gameTimer?.cancel(); super.dispose(); }
}