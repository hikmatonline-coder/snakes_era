import 'dart:math';
import 'package:flutter/material.dart';

enum NPCSize { small, medium, large, xlarge }

enum NPCType { beginner, noob, pro, legend }

class Food {
  Offset pos;
  final int type;
  final Color color;
  final bool isLoot;
  double opacity;

  Food(
    this.pos,
    this.type,
    this.color, {
    this.isLoot = false,
    this.opacity = 1.0,
  });
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

  int defensiveCoilTicks = 0;
  double coilDirection = 1.0;

  final Random _rng = Random();

  NPCSnake(this.pos, this.length, this.colors, this.rank, this.name, this.size)
      : angle = Random().nextDouble() * 2 * pi {
    body = List.generate(length, (_) => pos);
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
    var diff = target - current;
    while (diff < -pi) diff += 2 * pi;
    while (diff > pi) diff -= 2 * pi;
    return current + diff * lerpFactor;
  }

  void think(
    List<Offset> playerBody,
    List<NPCSnake> otherNPCs,
    Map<String, List<Food>> chunkedFoods,
    double chunkSize,
    double worldSize,
    List<Food> nearbyFoodBuffer,
  ) {
    var targetA = angle;
    var seesDanger = false;
    final detectionRange = (rank == NPCType.legend || rank == NPCType.pro)
        ? 280.0
        : 180.0;

    if (defensiveCoilTicks > 0) {
      angle += 0.24 * coilDirection;
      defensiveCoilTicks--;
      isBoosting = rank != NPCType.noob;
      return;
    }

    final lookLeft = pos +
        Offset(
          cos(angle - pi / 6) * detectionRange,
          sin(angle - pi / 6) * detectionRange,
        );
    final lookCenter =
        pos + Offset(cos(angle) * detectionRange, sin(angle) * detectionRange);
    final lookRight = pos +
        Offset(
          cos(angle + pi / 6) * detectionRange,
          sin(angle + pi / 6) * detectionRange,
        );

    var threatLeft = false;
    var threatCenter = false;
    var threatRight = false;

    if (playerBody.isNotEmpty && (pos - playerBody.first).distance < 600) {
      for (int i = 0; i < playerBody.length && i < 35; i += 5) {
        if ((lookCenter - playerBody[i]).distance < 95) threatCenter = true;
        if ((lookLeft - playerBody[i]).distance < 95) threatLeft = true;
        if ((lookRight - playerBody[i]).distance < 95) threatRight = true;
      }
    }

    for (final other in otherNPCs) {
      if (identical(other, this)) continue;
      if ((pos - other.pos).distance > 400) continue;

      for (int i = 0; i < other.body.length && i < 35; i += 5) {
        if ((lookCenter - other.body[i]).distance < 95) threatCenter = true;
        if ((lookLeft - other.body[i]).distance < 95) threatLeft = true;
        if ((lookRight - other.body[i]).distance < 95) threatRight = true;
      }
    }

    if (threatCenter || threatLeft || threatRight) {
      seesDanger = true;
      isBoosting = rank != NPCType.noob;
      decisionLock = 10;

      if (threatCenter && !threatLeft && !threatRight) {
        targetA = angle + (_rng.nextBool() ? pi / 2 : -pi / 2);
      } else if (threatLeft && !threatRight) {
        targetA = angle + pi / 3;
      } else if (threatRight && !threatLeft) {
        targetA = angle - pi / 3;
      } else {
        targetA = angle + pi;

        if (_rng.nextDouble() < 0.50 && body.length > 25) {
          defensiveCoilTicks = _rng.nextInt(12) + 20;
          coilDirection = _rng.nextBool() ? 1.0 : -1.0;
          return;
        }
      }
    }

    if (!seesDanger) {
      const margin = 350.0;
      if (pos.dx < margin ||
          pos.dx > worldSize - margin ||
          pos.dy < margin ||
          pos.dy > worldSize - margin) {
        targetA = (Offset(worldSize / 2, worldSize / 2) - pos).direction;
        seesDanger = true;
        isBoosting = false;
      }
    }

    if (!seesDanger && decisionLock <= 0) {
      isBoosting = false;
      Offset? currentTargetDestination;

      var optimalHuntDistance = 350.0;

      if (playerBody.isNotEmpty && rank != NPCType.noob) {
        final dToPlayer = (pos - playerBody.first).distance;
        if (dToPlayer < optimalHuntDistance &&
            body.length > playerBody.length * 0.7) {
          optimalHuntDistance = dToPlayer;
          currentTargetDestination = playerBody.first;
          if (dToPlayer < 140.0 && rank == NPCType.legend) isBoosting = true;
        }
      }

      for (final enemy in otherNPCs) {
        if (identical(enemy, this)) continue;
        final dToEnemy = (pos - enemy.pos).distance;
        if (dToEnemy < optimalHuntDistance && body.length > enemy.body.length) {
          optimalHuntDistance = dToEnemy;
          currentTargetDestination = enemy.pos;
          if (dToEnemy < 140.0 &&
              (rank == NPCType.pro || rank == NPCType.legend)) {
            isBoosting = true;
          }
        }
      }

      if (currentTargetDestination == null) {
        nearbyFoodBuffer.clear();
        final cx = (pos.dx / chunkSize).floor();
        final cy = (pos.dy / chunkSize).floor();
        const chunkRadius = 2;

        for (int x = cx - chunkRadius; x <= cx + chunkRadius; x++) {
          for (int y = cy - chunkRadius; y <= cy + chunkRadius; y++) {
            final chunk = chunkedFoods['$x,$y'];
            if (chunk != null) {
              nearbyFoodBuffer.addAll(chunk);
            }
          }
        }

        var highestCalculatedFoodPriority = 0.0;
        Food? optimalFoodTarget;
        final step = (rank == NPCType.legend || rank == NPCType.pro) ? 1 : 3;

        for (int i = 0; i < nearbyFoodBuffer.length; i += step) {
          final food = nearbyFoodBuffer[i];
          final dist = (pos - food.pos).distance;
          if (dist > 600.0) continue;

          final situationalWeight = (food.isLoot ? 12.0 : 1.0) / (dist + 1.0);

          if (situationalWeight > highestCalculatedFoodPriority) {
            highestCalculatedFoodPriority = situationalWeight;
            optimalFoodTarget = food;
          }
        }

        if (optimalFoodTarget != null) {
          currentTargetDestination = optimalFoodTarget.pos;
          if (optimalFoodTarget.isLoot && rank != NPCType.noob) {
            isBoosting = true;
          }
        }
      }

      if (currentTargetDestination != null) {
        targetA = (currentTargetDestination - pos).direction;
      } else {
        targetA = angle + wanderAngle;
        if (_rng.nextInt(80) == 0) {
          wanderAngle = _rng.nextDouble() * 0.04 - 0.02;
        }
      }
    }

    if (decisionLock > 0) decisionLock--;

    final baseTurn = rank == NPCType.legend
        ? 0.24
        : (rank == NPCType.pro ? 0.18 : 0.10);
    final turnSpeed = (baseTurn * turnAgilityForSize).clamp(0.05, 0.28);
    angle = _lerpAngle(angle, targetA, turnSpeed);
  }

  void grow(int amount) {
    length += amount;
    if (body.isEmpty) {
      body = List.generate(amount, (_) => pos);
      return;
    }

    final tailSegment = body.last;
    for (int i = 0; i < amount; i++) {
      body.add(tailSegment);
    }
  }

  void move(double speed, double dt) {
    final moveSpeed = speed * baseSpeedForSize * 60.0;

    pos += Offset(cos(angle) * moveSpeed * dt, sin(angle) * moveSpeed * dt);

    final baseSpacing = 4.0;
    var spacingValue = baseSpacing *
        (size == NPCSize.small
            ? 0.9
            : (size == NPCSize.xlarge
                ? 1.15
                : (size == NPCSize.large ? 1.08 : 1.0)));
    if (isBoosting) spacingValue *= 1.1;

    if (body.isEmpty) {
      body.insert(0, pos);
    } else {
      var distSinceLast = (pos - body.first).distance;

      var safetyCap = 0;
      while (distSinceLast > spacingValue && safetyCap < 6) {
        final ratio = spacingValue / distSinceLast;
        final fillerPos = Offset.lerp(body.first, pos, ratio)!;
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
