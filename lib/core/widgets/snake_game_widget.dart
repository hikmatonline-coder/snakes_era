import 'dart:math';
import 'package:flutter/material.dart';

enum NPCSize { small, medium, large, xlarge }

enum NPCType { beginner, noob, pro, legend }

class Food {
  Offset pos;
  final int type;
  final Color color;
  final bool isLoot;

  Food(this.pos, this.type, this.color, {this.isLoot = false});
}

class NPCSnake {
  final String name;
  Offset pos;
  double angle;
  List<Offset> body = [];
  int length;
  final List<Color> colors;
  NPCType rank;
  final NPCSize size;

  bool isBoosting = false;
  int decisionLock = 0;
  double wanderAngle = 0.0;

  // --- New Core AI Fields ---
  int defensiveCoilTicks = 0;
  double coilDirection = 1.0;

  NPCSnake(this.pos, this.length, this.colors, this.rank, this.name, this.size)
    : angle = Random().nextDouble() * 2 * pi {
    body = List.generate(length, (i) => pos);
    wanderAngle = Random().nextDouble() * 0.02 - 0.01;
  }

  double get baseSpeedForSize {
    switch (size) {
      case NPCSize.small:
        return 1.15;
      case NPCSize.medium:
        return 1.0;
      case NPCSize.large:
        return 0.9;
      case NPCSize.xlarge:
        return 0.8;
    }
  }

  double get turnAgilityForSize {
    switch (size) {
      case NPCSize.small:
        return 1.2;
      case NPCSize.medium:
        return 1.0;
      case NPCSize.large:
        return 0.85;
      case NPCSize.xlarge:
        return 0.7;
    }
  }

  double _lerpAngle(double current, double target, double lerpFactor) {
    double diff = target - current;
    while (diff < -pi) diff += 2 * pi;
    while (diff > pi) diff -= 2 * pi;
    return current + diff * lerpFactor;
  }

  void think(
    List<Offset> playerBody,
    List<NPCSnake> otherNPCs,
    List<Food> foods,
    double worldSize,
  ) {
    var rng = Random();
    double targetA = angle;
    bool seesDanger = false;
    double detectionRange = (rank == NPCType.legend || rank == NPCType.pro)
        ? 280.0
        : 180.0;

    // -------------------------------------------------------------
    // ACTION 1: ACTIVE COILING DEFENSE
    // -------------------------------------------------------------
    if (defensiveCoilTicks > 0) {
      angle += 0.24 * coilDirection;
      defensiveCoilTicks--;
      isBoosting = (rank != NPCType.noob);
      return;
    }

    // -------------------------------------------------------------
    // ACTION 2: THREE-PRONGED SIDE-STEP RADAR (Anti-Train Collision)
    // -------------------------------------------------------------
    // Project 3 danger zones: Left (-30°), Center (0°), and Right (+30°)
    Offset lookLeft =
        pos +
        Offset(
          cos(angle - pi / 6) * detectionRange,
          sin(angle - pi / 6) * detectionRange,
        );
    Offset lookCenter =
        pos + Offset(cos(angle) * detectionRange, sin(angle) * detectionRange);
    Offset lookRight =
        pos +
        Offset(
          cos(angle + pi / 6) * detectionRange,
          sin(angle + pi / 6) * detectionRange,
        );

    bool threatLeft = false;
    bool threatCenter = false;
    bool threatRight = false;

    // A. Scan Player Body
    if (playerBody.isNotEmpty && (pos - playerBody.first).distance < 600) {
      for (int i = 0; i < playerBody.length && i < 35; i += 5) {
        if ((lookCenter - playerBody[i]).distance < 95) threatCenter = true;
        if ((lookLeft - playerBody[i]).distance < 95) threatLeft = true;
        if ((lookRight - playerBody[i]).distance < 95) threatRight = true;
      }
    }

    // B. Scan Other NPCs
    for (var other in otherNPCs) {
      if (identical(other, this)) continue;
      if ((pos - other.pos).distance > 400) continue;

      for (int i = 0; i < other.body.length && i < 35; i += 5) {
        if ((lookCenter - other.body[i]).distance < 95) threatCenter = true;
        if ((lookLeft - other.body[i]).distance < 95) threatLeft = true;
        if ((lookRight - other.body[i]).distance < 95) threatRight = true;
      }
    }

    // C. Handle Smart Side-Stepping Evasion
    if (threatCenter || threatLeft || threatRight) {
      seesDanger = true;
      isBoosting = (rank != NPCType.noob);
      decisionLock = 10;

      if (threatCenter && !threatLeft && !threatRight) {
        // Direct head-on train scenario: Arbitrarily dodge hard to one side
        targetA = angle + (rng.nextBool() ? pi / 2 : -pi / 2);
      } else if (threatLeft && !threatRight) {
        // Threat is on the left side, escape hard to the right side
        targetA = angle + pi / 3;
      } else if (threatRight && !threatLeft) {
        // Threat is on the right side, escape hard to the left side
        targetA = angle - pi / 3;
      } else {
        // Surrounded or cut off: Try an emergency fallback break direction
        targetA = angle + pi;

        // High-rank snakes activate Coiling Circle Defense if fully cornered
        if (rng.nextDouble() < 0.50 && body.length > 25) {
          defensiveCoilTicks = rng.nextInt(12) + 20;
          coilDirection = rng.nextBool() ? 1.0 : -1.0;
          return;
        }
      }
    }

    // D. Border containment checks
    if (!seesDanger) {
      double margin = 350.0;
      if (pos.dx < margin ||
          pos.dx > worldSize - margin ||
          pos.dy < margin ||
          pos.dy > worldSize - margin) {
        targetA = (Offset(worldSize / 2, worldSize / 2) - pos).direction;
        seesDanger = true;
        isBoosting = false;
      }
    }

    // -------------------------------------------------------------
    // ACTION 3: HUNT ENEMIES & TRAIL LOOT PRIORITIZATION
    // -------------------------------------------------------------
    if (!seesDanger && decisionLock <= 0) {
      isBoosting = false;
      Offset? currentTargetDestination;

      // --- OFFENSIVE HUNTER MODE ---
      double optimalHuntDistance = 350.0;

      if (playerBody.isNotEmpty && rank != NPCType.noob) {
        double dToPlayer = (pos - playerBody.first).distance;
        if (dToPlayer < optimalHuntDistance &&
            body.length > playerBody.length * 0.7) {
          optimalHuntDistance = dToPlayer;
          currentTargetDestination = playerBody.first;
          if (dToPlayer < 140.0 && rank == NPCType.legend) isBoosting = true;
        }
      }

      for (var enemy in otherNPCs) {
        if (identical(enemy, this)) continue;
        double dToEnemy = (pos - enemy.pos).distance;
        if (dToEnemy < optimalHuntDistance && body.length > enemy.body.length) {
          optimalHuntDistance = dToEnemy;
          currentTargetDestination = enemy.pos;
          if (dToEnemy < 140.0 &&
              (rank == NPCType.pro || rank == NPCType.legend))
            isBoosting = true;
        }
      }

      // --- CRITICAL FOOD SEARCH REMAP ---
      if (currentTargetDestination == null && foods.isNotEmpty) {
        double highestCalculatedFoodPriority = 0.0;
        Food? optimalFoodTarget;

        // FIX: Pro and Legend bots now read EVERY food item (increment by 1)
        // to instantly catch trail loots when a snake drops dead next to them.
        int step = (rank == NPCType.legend || rank == NPCType.pro) ? 1 : 4;

        for (int i = 0; i < foods.length; i += step) {
          double dist = (pos - foods[i].pos).distance;
          if (dist > 600.0) continue; // Broadened vision awareness range

          // Trail loot drops receive a massive math weighting modifier over static dots
          double situationalWeight =
              (foods[i].isLoot ? 12.0 : 1.0) / (dist + 1.0);

          if (situationalWeight > highestCalculatedFoodPriority) {
            highestCalculatedFoodPriority = situationalWeight;
            optimalFoodTarget = foods[i];
          }
        }

        if (optimalFoodTarget != null) {
          currentTargetDestination = optimalFoodTarget.pos;
          // If it's loot, engage boost to steal it before anyone else does
          if (optimalFoodTarget.isLoot && rank != NPCType.noob) {
            isBoosting = true;
          }
        }
      }

      // --- FINAL STEERING ASSIGNMENT ---
      if (currentTargetDestination != null) {
        targetA = (currentTargetDestination - pos).direction;
      } else {
        // CIRCULAR WANDER ROUTINE
        targetA = angle + wanderAngle;
        if (rng.nextInt(80) == 0) wanderAngle = rng.nextDouble() * 0.04 - 0.02;
      }
    }

    if (decisionLock > 0) decisionLock--;

    double baseTurn = (rank == NPCType.legend)
        ? 0.24
        : (rank == NPCType.pro ? 0.18 : 0.10);
    double turnSpeed = (baseTurn * turnAgilityForSize).clamp(0.05, 0.28);
    angle = _lerpAngle(angle, targetA, turnSpeed);
  }

  void grow(int amount) {
    length += amount; // Increases length threshold target constraints
    if (body.isEmpty) {
      body = List.generate(amount, (i) => pos);
      return;
    }

    Offset tailSegment = body.last;
    for (int i = 0; i < amount; i++) {
      body.add(tailSegment);
    }
  }

  void move(double speed, double dt) {
    double moveSpeed = speed * baseSpeedForSize * 60.0;

    pos += Offset(cos(angle) * moveSpeed * dt, sin(angle) * moveSpeed * dt);

    double baseSpacing = 4.0;
    double spacingValue =
        baseSpacing *
        (size == NPCSize.small
            ? 0.9
            : (size == NPCSize.xlarge
                  ? 1.15
                  : (size == NPCSize.large ? 1.08 : 1.0)));
    if (isBoosting) spacingValue *= 1.1;

    if (body.isEmpty) {
      body.insert(0, pos);
    } else {
      double distSinceLast = (pos - body.first).distance;

      int safetyCap = 0;
      while (distSinceLast > spacingValue && safetyCap < 6) {
        double ratio = spacingValue / distSinceLast;
        Offset fillerPos = Offset.lerp(body.first, pos, ratio)!;
        body.insert(0, fillerPos);
        distSinceLast = (pos - body.first).distance;
        safetyCap++;
      }
    }

    while (body.length > length) {
      body.removeLast();
    }
  }
}
