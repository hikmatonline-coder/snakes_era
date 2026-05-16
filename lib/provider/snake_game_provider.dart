import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/widgets/snake_game_widget.dart';

class SnakeGameProvider with ChangeNotifier {
  // --- Constants ---
  final double worldSize = 6000.0;
  final double chunkSize = 500.0; // The grid size for rendering
  final double baseSnakeSpeed = 3.5;
  final double spacing = 4.5;

  // --- State Variables ---
  Offset playerPos = const Offset(3000, 3000);
  double playerAngle = 0.0;
  double targetAngle = 0.0;
  List<Offset> playerBody = [];

  // THE PERFORMANCE COMBO:
  List<Food> foods = [];
  Map<String, List<Food>> chunkedFoods = {}; // This is for the Painter

  List<NPCSnake> npcs = [];
  int score = 0;
  double fractionalLength = 35.0;
  int currentLengthLimit = 20;
  bool isGameOver = false;
  bool isBoosting = false;
  bool isInvincible = false;
  bool isPaused = false;
  int frameCounter = 0;

  int adsWatchedThisSession = 0; // Track 3-ad limit
  final int maxAdsPerSession = 3;
  bool isScoreDoubled = false; // Flag for the 2x reward

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
    playerBody = List.generate(20, (i) => const Offset(3000, 3000));
    score = 0;
    adsWatchedThisSession = 0;
    isScoreDoubled = false;
    fractionalLength = 35.0;
    currentLengthLimit = 20;
    isGameOver = false;
    isBoosting = false;
    isInvincible = false;

    // Clear everything
    foods = [];
    chunkedFoods = {};
    npcs = [];

    _spawnFood(1500);
    _spawnNPCs(50);

    _lastTick = DateTime.now();
    gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) => _gameTick());
    notifyListeners();
  }

  // NEW: Call this instead of resetGame when user wants to double score
  void doubleScore() {
    if (!isScoreDoubled) {
      score *= 2;
      isScoreDoubled = true;
      notifyListeners();
    }
  }

  // --- Food Synchronization (The Most Important Part) ---

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
    chunkedFoods[key]?.remove(f);
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
    // Get the last two segments to calculate the "backward" direction
    Offset tail = playerBody.last;
    Offset prevTail = playerBody[playerBody.length - 2];

    // Calculate a vector pointing away from the snake
    Offset directionAway = (tail - prevTail);
    if (directionAway.distance == 0) directionAway = const Offset(1, 0);

    // Normalize and push the food 20-30 pixels away from the tail
    Offset spawnPos = tail + (directionAway / directionAway.distance) * 25.0;

    Food boostLoot = Food(
      spawnPos + Offset(rng.nextDouble() * 10 - 5, rng.nextDouble() * 10 - 5),
      0, // Small food type
      activeSkinColors[0],
      isLoot: true,
    );
    _addNewFood(boostLoot);
  }

  void _handleSnakeDeath(List<Offset> bodySegments, List<Color> snakeColors) {
    var rng = Random();
    for (int i = 0; i < bodySegments.length; i += 10) {
      Food deathLoot = Food(
        bodySegments[i] + Offset(rng.nextDouble() * 5, rng.nextDouble() * 5),
        rng.nextInt(3),
        snakeColors[i % snakeColors.length],
        isLoot: true,
      );
      _addNewFood(deathLoot);
    }
  }

  // --- Game Loop ---

  void _gameTick() {
    // If the game is over, paused, or the provider is disposed, stop everything immediately
    if (isGameOver || isPaused) return;

    final now = DateTime.now();
    final double dt = now.difference(_lastTick).inMicroseconds / 1000000.0;

    // Safety: If the frame drop is massive (e.g., phone lagged),
    // don't try to calculate a huge jump. Cap it at 0.03 seconds.
    double cappedDt = dt.clamp(0.0, 0.03);
    _lastTick = now;

    frameCounter++;
    _movePlayerLogic(dt);

    if (isBoosting && playerBody.length > 15) {
      if (frameCounter % 12 == 0) {
        _ejectBoostFood();
        fractionalLength -= 0.1;
        currentLengthLimit = fractionalLength.toInt();
        if (score > 0) score -= 1;
      }
    }

    _applyFoodMagnet(dt);

    if (frameCounter % 2 == 0) {
      _checkCollisions();
    }

    // NPC Logic
    for (var npc in npcs) {
      npc.move(npc.isBoosting ? 4.5 : 3.0, dt);
    }

    int npcsToUpdate = 5;
    for (int i = 0; i < npcsToUpdate; i++) {
      int index = (frameCounter + i) % npcs.length;
      if (index < npcs.length) {
        npcs[index].think(playerBody, npcs, foods, worldSize);
      }
    }

    notifyListeners();
  }

  // --- Optimized SnakeGameProvider ---

  void _checkCollisions() {
    if (isGameOver) return;

    // --- 1. ALWAYS CHECK BORDER FIRST ---
    if (playerPos.dx < 0 || playerPos.dx > worldSize ||
        playerPos.dy < 0 || playerPos.dy > worldSize) if (isInvincible) {
      // OPTION A: Teleport to opposite side (Slightly beyond the edge to prevent loops)
      double newX = playerPos.dx;
      double newY = playerPos.dy;

      if (playerPos.dx < 0) newX = worldSize - 50;
      else if (playerPos.dx > worldSize) newX = 50;

      if (playerPos.dy < 0) newY = worldSize - 50;
      else if (playerPos.dy > worldSize) newY = 50;

      playerPos = Offset(newX, newY);
      playerBody[0] = playerPos; // Force update head

      // OPTION B: Or just flip the angle to "bounce"
      // playerAngle += pi;

    } else {
      // Regular death if not invincible
      _handleSnakeDeath(playerBody, activeSkinColors);
      _endGame();
      return;
    }

    // 2. COLLISION WITH FOOD (Using Chunks)
    int pX = (playerPos.dx / chunkSize).floor();
    int pY = (playerPos.dy / chunkSize).floor();

    List<Food> checkableFood = [];
    for (int x = pX - 1; x <= pX + 1; x++) {
      for (int y = pY - 1; y <= pY + 1; y++) {
        var chunk = chunkedFoods["$x,$y"];
        if (chunk != null) checkableFood.addAll(chunk);
      }
    }

    double headRadius = 10.0 + (playerBody.length / 100).clamp(0, 15);

    for (var f in List.from(checkableFood)) {
      // If the food is within the head's reach
      if ((playerPos - f.pos).distance < headRadius + 10) {
        // Just call the helper! It handles scoring, growth, and removal.
        _processFoodConsumption(f);
      }
    }

    // 3. NPC DEATH LOGIC (Separated for Performance)
    Set<NPCSnake> deadNPCs = {};
    for (var npc in npcs) {
      bool npcDied = false;
      // Border check for NPCs
      if (npc.pos.dx < 0 || npc.pos.dx > worldSize || npc.pos.dy < 0 || npc.pos.dy > worldSize) {
        npcDied = true;
      }
      // Hit player body check
      if (!npcDied) {
        for (var segment in playerBody.skip(5)) {
          if ((npc.pos - segment).distance < 18) { npcDied = true; break; }
        }
      }
      if (npcDied) deadNPCs.add(npc);
    }

    for (var npc in deadNPCs) {
      _handleSnakeDeath(npc.body, npc.colors);
      npcs.remove(npc);
      _spawnSingleNPC();
    }

    // 4. PLAYER DEATH LOGIC (Snake vs Snake)
    if (!isInvincible) {
      for (var npc in npcs) {
        for (var segment in npc.body.skip(2)) {
          if ((playerPos - segment).distance < 18) {
            _handleSnakeDeath(playerBody, activeSkinColors);
            _endGame();
            return;
          }
        }
      }
    }

    // Maintenance: keep food density
    if (foods.length < 1000) _spawnFood(150);
  }

  void _movePlayerLogic(double dt) {
    double agility = (1.0 - (playerBody.length / 2500)).clamp(0.35, 1.0);
    double diff = targetAngle - playerAngle;
    while (diff < -pi) diff += 2 * pi;
    while (diff > pi) diff -= 2 * pi;

    playerAngle += diff * (10.0 * agility * dt);
    double speedMultiplier = 1.0 - (playerBody.length / 3000).clamp(0.0, 0.4);
    double moveSpeed = (isBoosting ? 378.0 : 210.0) * speedMultiplier;
    if (moveSpeed < 130.0) moveSpeed = 130.0;

    playerPos += Offset(cos(playerAngle) * moveSpeed * dt, sin(playerAngle) * moveSpeed * dt);

    if (playerBody.isEmpty) {
      playerBody.insert(0, playerPos);
    } else {
      double dist = (playerPos - playerBody.first).distance;
      while (dist > spacing) {
        playerBody.insert(0, Offset.lerp(playerBody.first, playerPos, spacing / dist)!);
        dist = (playerPos - playerBody.first).distance;
      }
    }

    while (playerBody.length > currentLengthLimit) playerBody.removeLast();
  }

  // --- Helpers ---

  // OPTIMIZED MAGNET (Only pulls nearby loot to save CPU)
  void _applyFoodMagnet(double dt) {
    int pX = (playerPos.dx / chunkSize).floor();
    int pY = (playerPos.dy / chunkSize).floor();

    for (int x = pX - 1; x <= pX + 1; x++) {
      for (int y = pY - 1; y <= pY + 1; y++) {
        var chunk = chunkedFoods["$x,$y"];
        if (chunk == null) continue;

        // Use a standard for loop to avoid concurrent modification issues
        for (int i = chunk.length - 1; i >= 0; i--) {
          var food = chunk[i];
          if (food.isLoot) {
            double dist = (playerPos - food.pos).distance;

            // --- SAFETY FIX ---
            // If food is super close (less than 15px), "eat" it immediately
            // to prevent it getting stuck at the border
            if (dist < 15) {
              _processFoodConsumption(food);
              continue;
            }

            if (dist < 180) {
              double pull = pow((180 - dist) / 180, 2) * 25 * (dt * 60);
              food.pos += (playerPos - food.pos) / dist * pull;
            }
          }
        }
      }
    }
  }

  void _processFoodConsumption(Food f) {
    // CRITICAL: Remove it immediately so no other logic can see it
    _removeFood(f);

    // 1. Calculate Score
    if (f.isLoot) {
      score += 5;
    } else if (f.type == 0) {
      score += 1;
    } else {
      score += 3;
    }

    // 2. Calculate Growth
    double efficiency = 1.0 / (1.0 + (playerBody.length / 500));
    double growth = (f.isLoot ? 0.4 : 0.15) * efficiency;

    fractionalLength += growth;
    currentLengthLimit = fractionalLength.toInt();

    // 3. Optional: Trigger a tiny haptic or sound here
    // notifyListeners(); // Only call if you aren't calling it at the end of the tick
  }

  void _spawnSingleNPC() {
    var rng = Random();
    Offset spawnPos;
    do {
      spawnPos = Offset(rng.nextDouble() * worldSize, rng.nextDouble() * worldSize);
    } while ((spawnPos - playerPos).distance < 800);

    // Pick a professional name from your list, or fallback to a numbered bot if list is empty
    String name = botNames[rng.nextInt(botNames.length)];

    // Optional: Add a random number to the name to avoid duplicates on the leaderboard
    String uniqueName = "$name#${rng.nextInt(99)}";

    npcs.add(NPCSnake(
        spawnPos,
        rng.nextInt(40) + 20, // Give them random starting lengths
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

    // 1. Teleport player to a safe distance from the edge (e.g., center)
    playerPos = const Offset(3000, 3000);

    // 2. Reset body to the new position so the snake doesn't "stretch" across the map
    playerBody = List.generate(currentLengthLimit, (i) => const Offset(3000, 3000));

    // 3. Clear and Respawn world entities
    foods = [];
    chunkedFoods = {};
    npcs = [];
    _spawnFood(1500);
    _spawnNPCs(50);

    // 4. Restart Timer
    targetAngle = playerAngle;
    gameTimer?.cancel();
    _lastTick = DateTime.now();
    gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) => _gameTick());

    notifyListeners();

    // 5. Longer invincibility for border safety
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