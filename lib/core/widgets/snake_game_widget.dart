import 'dart:math';
import 'package:flutter/material.dart';

enum NPCSize { small, medium, large, xlarge }

enum NPCType { beginner, noob, pro, legend }

class Food {
  Offset pos;
  int size;
  Color color;
  bool isLoot; // Add this to identify snake remains

  Food(this.pos, this.size, this.color, {this.isLoot = false});
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
  int? targetFoodIndex;
  int decisionLock = 0;
  double wanderAngle = 0.0; // For circular rotation

  NPCSnake(this.pos, this.length, this.colors, this.rank, this.name, this.size)
      : angle = Random().nextDouble() * 2 * pi {
    body = List.generate(length, (i) => pos);
    wanderAngle = Random().nextDouble() * 0.02 - 0.01; // Unique drift for each bot
  }

  /// Base speed multiplier by size: smaller snakes faster, xlarge slower.
  double get baseSpeedForSize {
    switch (size) {
      case NPCSize.small: return 1.15;
      case NPCSize.medium: return 1.0;
      case NPCSize.large: return 0.9;
      case NPCSize.xlarge: return 0.8;
    }
  }

  /// Turn agility by size: smaller snakes turn quicker, xlarge more sluggish.
  double get turnAgilityForSize {
    switch (size) {
      case NPCSize.small: return 1.2;
      case NPCSize.medium: return 1.0;
      case NPCSize.large: return 0.85;
      case NPCSize.xlarge: return 0.7;
    }
  }

  double _lerpAngle(double current, double target, double lerpFactor) {
    double diff = target - current;
    while (diff < -pi) diff += 2 * pi;
    while (diff > pi) diff -= 2 * pi;
    return current + diff * lerpFactor;
  }

  void think(List<Offset> playerBody, List<NPCSnake> otherNPCs, List<Food> foods, double worldSize) {
    double targetA = angle;
    bool seesDanger = false;
    double detectionRange = (rank == NPCType.legend || rank == NPCType.pro) ? 250.0 : 150.0;

    // 1. COLLISION AVOIDANCE (Anti-Head-On)
    Offset lookAhead = pos + Offset(cos(angle) * detectionRange, sin(angle) * detectionRange);

    // 1. CHECK PLAYER FIRST (Always relevant if nearby)
    if ((pos - playerBody.first).distance < 600) { // Broad filter
      for (int i = 0; i < playerBody.length && i < 30; i += 5) {
        if ((lookAhead - playerBody[i]).distance < 100) {
          targetA = (pos - playerBody[i]).direction;
          seesDanger = true;
          break;
        }
      }
    }

    // 2. CHECK OTHER NPCs (With the distance filter)
    if (!seesDanger) {
      for (var other in otherNPCs) {
        if (other == this) continue;

        // PERFORMANCE FILTER: Skip if they are too far away to matter
        // This is the line that saves the Nubia's CPU
        if ((pos - other.pos).distance > 400) continue;

        // Only check the segments if the snake is actually close
        for (int i = 0; i < other.body.length && i < 30; i += 5) {
          if ((lookAhead - other.body[i]).distance < 100) {
            targetA = (pos - other.body[i]).direction;
            seesDanger = true;
            isBoosting = (rank != NPCType.noob);
            decisionLock = 15;
            break;
          }
        }
        if (seesDanger) break;
      }
    }

    // 2. WORLD BORDERS
    if (!seesDanger) {
      double margin = 400.0;
      if (pos.dx < margin || pos.dx > worldSize - margin || pos.dy < margin || pos.dy > worldSize - margin) {
        targetA = (Offset(worldSize / 2, worldSize / 2) - pos).direction;
        seesDanger = true;
      }
    }

    // 3. CATEGORY BEHAVIOR (Food & Wandering)
    if (!seesDanger && decisionLock <= 0) {
      isBoosting = false;

      if (foods.isNotEmpty && (rank == NPCType.pro || rank == NPCType.legend || Random().nextDouble() > 0.7)) {
        // Hunt Food
        if (targetFoodIndex == null || targetFoodIndex! >= foods.length) {
          _findNearestFood(foods);
        }
        if (targetFoodIndex != null) {
          targetA = (foods[targetFoodIndex!].pos - pos).direction;
          // Legend/Pro bots boost toward large food
          if (foods[targetFoodIndex!].size > 0 && rank == NPCType.legend) isBoosting = true;
        }
      } else {
        // CIRCULAR ROTATION (Wandering)
        targetA = angle + wanderAngle;
        if (Random().nextInt(100) == 0) wanderAngle = Random().nextDouble() * 0.04 - 0.02;
      }
    }

    if (decisionLock > 0) decisionLock--;

    // Rank-based turning speed, then modulated by size for smooth movement
    double baseTurn = (rank == NPCType.legend) ? 0.20 : (rank == NPCType.pro ? 0.15 : 0.08);
    double turnSpeed = (baseTurn * turnAgilityForSize).clamp(0.05, 0.25);
    angle = _lerpAngle(angle, targetA, turnSpeed);
  }

  void _findNearestFood(List<Food> foods) {
    double closestDist = 600 * 600; // Only care about food within 600px
    int? closestIndex;
    for (int i = 0; i < foods.length; i += 10) {
      double d = (pos - foods[i].pos).distanceSquared;
      if (d < closestDist) {
        closestDist = d;
        closestIndex = i;
      }
    }
    targetFoodIndex = closestIndex;
  }

  void move(double speed, double dt) {
    // 1. Calculate per-second speed
    double moveSpeed = speed * baseSpeedForSize * 60.0;

    // 2. Move the head
    Offset oldPos = pos;
    pos += Offset(
        cos(angle) * moveSpeed * dt,
        sin(angle) * moveSpeed * dt
    );

    // 3. Spacing logic
    double baseSpacing = 4.0;
    double spacingValue = baseSpacing * (
        size == NPCSize.small ? 0.9 :
        (size == NPCSize.xlarge ? 1.15 :
        (size == NPCSize.large ? 1.08 : 1.0))
    );
    if (isBoosting) spacingValue *= 1.1;

    // 4. THE FIX: Interpolate segments to fill gaps
    if (body.isEmpty) {
      body.insert(0, pos);
    } else {
      double distSinceLast = (pos - body.first).distance;

      // While the gap is bigger than our spacing, add "filler" segments
      while (distSinceLast > spacingValue) {
        double ratio = spacingValue / distSinceLast;
        Offset fillerPos = Offset.lerp(body.first, pos, ratio)!;
        body.insert(0, fillerPos);
        distSinceLast = (pos - body.first).distance;
      }
    }

    // 5. Trim the tail
    while (body.length > length) {
      body.removeLast();
    }
  }
}