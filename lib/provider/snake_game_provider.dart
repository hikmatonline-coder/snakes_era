import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/widgets/snake_game_widget.dart';

class SnakeGameProvider with ChangeNotifier {
  final double worldSize = 6000.0;
  final double baseSnakeSpeed = 3.5;
  final double spacing = 4.5;

  Offset playerPos = const Offset(3000, 3000);
  double playerAngle = 0.0;
  double targetAngle = 0.0;
  List<Offset> playerBody = [];
  int score = 0;
  double fractionalLength = 35.0;
  int currentLengthLimit = 20;
  bool isGameOver = false;
  bool isBoosting = false;
  bool isInvincible = false;
  List<Food> foods = [];
  List<NPCSnake> npcs = [];
  Timer? gameTimer;
  int frameCounter = 0;
  bool isPaused = false;

  DateTime _lastTick = DateTime.now();

  final List<String> botNames = ["Dragon", "Shadow", "Mamba", "Alpha", "Neon", "Viper", "Hunter", "Swift", "Venom", "Bolt"];

  // To handle collision death colors
  late List<Color> activeSkinColors;

  void startGame(List<Color> skinColors) {
    activeSkinColors = skinColors;
    resetGame();
  }

  void togglePause() {
    if (isGameOver) return;

    isPaused = !isPaused;

    if (isPaused) {
      gameTimer?.cancel();
    } else {
      // Reset _lastTick so the snake doesn't "jump" after unpausing
      _lastTick = DateTime.now();
      gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) => _gameTick());
    }
    notifyListeners();
  }

  void setTargetAngle(double angle) => targetAngle = angle;

  void setBoosting(bool val) { isBoosting = val; notifyListeners(); }

  void resetGame() {
    gameTimer?.cancel();
    playerPos = const Offset(3000, 3000);
    playerBody = List.generate(20, (i) => const Offset(3000, 3000));
    score = 0;
    fractionalLength = 35.0;
    currentLengthLimit = 20;
    isGameOver = false;
    isBoosting = false;
    isInvincible = false;
    foods = [];
    npcs = [];
    _spawnFood(1500);
    _spawnNPCs(50);
    gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) => _gameTick());
    notifyListeners();
  }

  void _ejectBoostFood() {
    if (playerBody.isEmpty) return;

    var rng = Random();
    // Get the last segment of the snake
    Offset tailPos = playerBody.last;

    // Add a small piece of loot (size 0) using the snake's current skin color
    foods.add(Food(
      tailPos + Offset(rng.nextDouble() * 10 - 5, rng.nextDouble() * 10 - 5),
      0, // Smallest size
      activeSkinColors[0], // Use primary skin color
      isLoot: true, // It's "loot" so it glows and is magnetic
    ));
  }

  void _gameTick() {
    if (isGameOver) return;

    // --- CALCULATE DELTA TIME (Add this) ---
    final now = DateTime.now();
    final double dt = now.difference(_lastTick).inMicroseconds / 1000000.0;
    _lastTick = now;

    frameCounter++;
    _movePlayerLogic(dt);

    // --- BOOST COST LOGIC ---
    // Only lose length if boosting and length is greater than the starting minimum (e.g., 15)
    if (isBoosting && playerBody.length > 15) {
      // Drop food every 5 frames to avoid cluttering the map too fast
      if (frameCounter % 5 == 0) {
        _ejectBoostFood();

        // Decrease fractional length (this reduces the snake's actual size)
        fractionalLength -= 0.15;
        currentLengthLimit = fractionalLength.toInt();

        // Also update score if you want boosting to "cost" points
        if (score > 0) score -= 5;
      }
    }

    // 1. Move the food toward the player
    _applyFoodMagnet(dt);

    // 2. Check if the player hit the food
    // Only check heavy collisions every 2nd frame to save CPU
    if (frameCounter % 2 == 0) {
      _checkCollisions();
    }

    // 1. Move ALL NPCs every frame (Movement must be smooth)
    for (var npc in npcs) {
      double npcSpeed = npc.isBoosting ? 4.5 : 3.0;
      npc.move(npcSpeed, dt);
    }

    // 2. ONLY UPDATE 5 NPC BRAINS (The "Think" optimization)
    // This spreads the heavy CPU work over multiple frames
    int npcsToUpdate = 5;
    for (int i = 0; i < npcsToUpdate; i++) {
      // This formula ensures we rotate through the whole list of NPCs
      int index = (frameCounter + i) % npcs.length;
      if (index < npcs.length) {
        npcs[index].think(playerBody, npcs, foods, worldSize);
      }
    }

    notifyListeners();
  }

  void _checkCollisions() {
    if (isGameOver) return;

    final double viewportRadius = 1200.0;

  // Filter foods to only those near the player before checking distance
    var nearbyFoods = foods.where((f) => (f.pos - playerPos).distance < viewportRadius).toList();

    nearbyFoods.removeWhere((f) {
      double headRadius = 10.0 + (playerBody.length / 100).clamp(0, 15);

      if ((playerPos - f.pos).distance < headRadius + 10) {
        // 1. Calculate Growth Factor
        // As length increases, growth from a single piece of food decreases
        double growthEfficiency = 1.0 / (1.0 + (playerBody.length / 500));

        double baseGrowth = f.isLoot ? 0.4 : 0.15;
        double actualGrowth = baseGrowth * growthEfficiency;

        score += (f.isLoot ? 50 : 10);
        fractionalLength += actualGrowth;
        currentLengthLimit = fractionalLength.toInt();

        foods.remove(f);
        return true;
      }
      return false;
    });

    // 1. NPC DEATH LOGIC
    Set<NPCSnake> deadNPCs = {};

    for (var npc in npcs) {
      bool npcDied = false;

      // Hit World Boundary
      if (npc.pos.dx < 0 || npc.pos.dx > worldSize || npc.pos.dy < 0 || npc.pos.dy > worldSize) {
        npcDied = true;
      }

      // Hit Player Body
      if (!npcDied) {
        for (var segment in playerBody.skip(5)) { // skip(5) prevents head-on glitches
          if ((npc.pos - segment).distance < 18) {
            npcDied = true;
            break;
          }
        }
      }

      // Hit Other NPC Body
      if (!npcDied) {
        for (var other in npcs) {
          if (npc == other) continue;
          // Check if npc head hits other npc body
          for (var seg in other.body.skip(5)) {
            if ((npc.pos - seg).distance < 18) {
              npcDied = true;
              break;
            }
          }
          if (npcDied) break;
        }
      }

      if (npcDied) deadNPCs.add(npc);
    }

    // Process NPC Deaths (Turn them into food)
    for (var npc in deadNPCs) {
      _handleSnakeDeath(npc.body, npc.colors);
      npcs.remove(npc);
      _spawnSingleNPC(); // Respawn a new one to keep the map full
    }

    // 2. PLAYER DEATH LOGIC
    if (!isInvincible) {
      bool playerDied = false;

      // Hit World Boundary
      if (playerPos.dx < 0 || playerPos.dx > worldSize || playerPos.dy < 0 || playerPos.dy > worldSize) {
        playerDied = true;
      }

      // Hit NPC Body
      if (!playerDied) {
        for (var npc in npcs) {
          for (var segment in npc.body.skip(2)) {
            if ((playerPos - segment).distance < 18) {
              playerDied = true;
              break;
            }
          }
          if (playerDied) break;
        }
      }

      if (playerDied) {
        _handleSnakeDeath(playerBody, activeSkinColors);
        _endGame();
        return;
      }
    }

    // 3. FOOD CONSUMPTION
    foods.removeWhere((f) {
      double radius = 10.0 + (playerBody.length / 80).clamp(0, 15);
      if ((playerPos - f.pos).distance < radius + 15) {
        double growth = f.isLoot ? 0.1 : 0.33;
        score += (growth * 100).toInt();
        fractionalLength += growth;
        currentLengthLimit = fractionalLength.toInt();
        return true;
      }
      return false;
    });

    // NPCs eating food
    for (var npc in npcs) {
      double npcRadius = 10.0 + (npc.body.length / 80).clamp(0, 15);
      foods.removeWhere((f) {
        if ((npc.pos - f.pos).distance < npcRadius + 15) {
          npc.length += f.isLoot ? 2 : 1;
          return true;
        }
        return false;
      });
    }

    if (foods.length < 1000) _spawnFood(150);
  }

  void _movePlayerLogic(double dt) {
    double agility = (1.0 - (playerBody.length / 2500)).clamp(0.35, 1.0);
    double diff = targetAngle - playerAngle;
    while (diff < -pi) diff += 2 * pi;
    while (diff > pi) diff -= 2 * pi;

    // Normalize turning speed with dt
    playerAngle += diff * (10.0 * agility * dt);

    double lengthPenalty = (playerBody.length / 3000).clamp(0.0, 0.4);
    double speedMultiplier = 1.0 - lengthPenalty;

    // Use the scaled speed (210.0 is roughly 3.5 * 60)
    double frameIndependentSpeed = 210.0;

    double moveSpeed = isBoosting
        ? (frameIndependentSpeed * 1.8) * speedMultiplier
        : frameIndependentSpeed * speedMultiplier;

    if (moveSpeed < 130.0) moveSpeed = 130.0;

    // Move the player position
    playerPos += Offset(cos(playerAngle) * moveSpeed * dt, sin(playerAngle) * moveSpeed * dt);

    // --- FIXING THE GAPS ---
    // If the phone lags and the snake moves a long distance, we need to fill the gap
    if (playerBody.isEmpty) {
      playerBody.insert(0, playerPos);
    } else {
      double distSinceLastSegment = (playerPos - playerBody.first).distance;

      // If we moved more than 1 'spacing' unit, add segments until caught up
      while (distSinceLastSegment > spacing) {
        // Find the position for the intermediate segment
        double ratio = spacing / distSinceLastSegment;
        Offset newSegmentPos = Offset.lerp(playerBody.first, playerPos, ratio)!;

        playerBody.insert(0, newSegmentPos);
        distSinceLastSegment = (playerPos - playerBody.first).distance;
      }
    }

    // Keep the body at the correct length
    while (playerBody.length > currentLengthLimit) {
      playerBody.removeLast();
    }
  }

  void _handleSnakeDeath(List<Offset> bodySegments, List<Color> snakeColors) {
    var rng = Random();
    // Spawn food every 10 segments instead of every 2 or 6
    // This creates a clean, spaced-out trail
    for (int i = 0; i < bodySegments.length; i += 10) {
      foods.add(Food(
        bodySegments[i] + Offset(rng.nextDouble() * 5, rng.nextDouble() * 5),
        rng.nextInt(3), // 0, 1, or 2 for size variety
        snakeColors[i % snakeColors.length],
        isLoot: true,
      ));
    }
  }

  void _spawnSingleNPC() {
    var rng = Random();
    Offset spawnPos = Offset(rng.nextDouble() * worldSize, rng.nextDouble() * worldSize);
    // Ensure it doesn't spawn right on top of the player
    while ((spawnPos - playerPos).distance < 800) {
      spawnPos = Offset(rng.nextDouble() * worldSize, rng.nextDouble() * worldSize);
    }
    npcs.add(NPCSnake(spawnPos, 35, [Colors.primaries[rng.nextInt(15)], Colors.white], NPCType.beginner, "Bot_${rng.nextInt(100)}", NPCSize.medium));
  }

  void revivePlayer() {
    isGameOver = false;
    isInvincible = true; // Shield ON

    // Reset clock to prevent the "time jump" teleportation
    _lastTick = DateTime.now();

    // Reset body segments so you don't instantly die on your own tail
    playerBody = List.generate(currentLengthLimit, (i) => playerPos);

    // Restart the game loop if it was cancelled
    gameTimer?.cancel();
    gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) => _gameTick());

    // Use a standard Timer for the 10-second duration
    Timer(const Duration(seconds: 10), () {
      isInvincible = false; // Shield OFF
      notifyListeners();    // Tell the Painter to stop drawing the glow
      debugPrint("Shield Expired");
    });

    notifyListeners();
  }

  void _endGame() {
    isGameOver = true;
    gameTimer?.cancel();

    notifyListeners();
  }

  // This method will be called by your UI, passing the necessary IDs
  Future<void> syncFinalScore({required String userId, required int finalScore}) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        // We use SetOptions(merge: true) and standard logic
        // because FieldValue.maximum does not exist in the Flutter SDK
        'lastScore': finalScore,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Note: High score logic is usually handled better in UserProvider
      // where you compare (newScore > oldScore) before writing.
    } catch (e) {
      debugPrint("Firebase Sync Error: $e");
    }
  }

  // Helper Methods for Spawning
  NPCType _rankForSize(NPCSize sz, Random rng) {
    double roll = rng.nextDouble() * 100;
    switch (sz) {
      case NPCSize.small:
        if (roll < 50) return NPCType.beginner;
        if (roll < 80) return NPCType.noob;
        if (roll < 95) return NPCType.pro;
        return NPCType.legend;
      case NPCSize.medium:
        if (roll < 20) return NPCType.beginner;
        if (roll < 60) return NPCType.noob;
        if (roll < 90) return NPCType.pro;
        return NPCType.legend;
      case NPCSize.large:
        if (roll < 5) return NPCType.beginner;
        if (roll < 30) return NPCType.noob;
        if (roll < 75) return NPCType.pro;
        return NPCType.legend;
      case NPCSize.xlarge:
        if (roll < 10) return NPCType.noob;
        if (roll < 50) return NPCType.pro;
        return NPCType.legend;
    }
  }

  void _spawnFood(int count) {
    var rng = Random();
    for (int i = 0; i < count; i++) {
      bool isSmall = rng.nextDouble() < 0.8;
      foods.add(Food(
          Offset(rng.nextDouble() * worldSize, rng.nextDouble() * worldSize),
          isSmall ? 0 : 1,
          Colors.primaries[rng.nextInt(Colors.primaries.length)],
          isLoot: false // Map food is not loot
      ));
    }
  }

  void _applyFoodMagnet(double dt) {
    for (var food in foods) {
      if (food.isLoot) {
        double dist = (playerPos - food.pos).distance;
        if (dist < 180) { // Slightly larger range
          // Strength gets exponentially stronger as it gets closer
          double pullStrength = pow((180 - dist) / 180, 2) * 15 * (dt * 60);

          Offset direction = (playerPos - food.pos) / dist;

          // Add a tiny bit of random noise so they don't move in a perfect straight line
          double noise = (Random().nextDouble() - 0.5) * 2;

          food.pos += direction * pullStrength + Offset(noise, noise);
        }
      }
    }
  }

  void _spawnNPCs(int count) {
    var rng = Random();
    for (int i = 0; i < count; i++) {
      // Size: 20% small, 35% medium, 35% large, 10% xlarge
      double roll = rng.nextDouble() * 100;
      NPCSize sz;
      int startLen;
      if (roll < 20) {
        sz = NPCSize.small;
        startLen = 25 + rng.nextInt(16); // 25-40
      } else if (roll < 55) {
        sz = NPCSize.medium;
        startLen = 50 + rng.nextInt(31); // 50-80
      } else if (roll < 90) {
        sz = NPCSize.large;
        startLen = 120 + rng.nextInt(81); // 120-200
      } else {
        sz = NPCSize.xlarge;
        startLen = 300 + rng.nextInt(201); // 300-500
      }
      NPCType type = _rankForSize(sz, rng);

      String name = "${botNames[rng.nextInt(botNames.length)]}_${rng.nextInt(99)}";
      List<Color> colors = [
        Colors.primaries[rng.nextInt(Colors.primaries.length)],
        Colors.primaries[rng.nextInt(Colors.primaries.length)],
      ];

      Offset spawnPos;
      do {
        spawnPos = Offset(rng.nextDouble() * worldSize, rng.nextDouble() * worldSize);
      } while ((spawnPos - playerPos).distance < 600);

      npcs.add(NPCSnake(spawnPos, startLen, colors, type, name, sz));
    }
  }

  @override
  void dispose() { gameTimer?.cancel(); super.dispose(); }
}