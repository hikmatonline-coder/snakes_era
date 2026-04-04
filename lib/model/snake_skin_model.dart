import 'package:flutter/material.dart';

enum SkinRarity { common, rare, epic, legendary, ultimate }

class SnakeSkin {
  final String id;
  final String name;
  final SkinRarity rarity;
  final List<Color> bodyColors; // Supports 2, 3, or 4+ colors
  final Color eyeColor;
  final Color tongueColor;
  final int price;

  SnakeSkin({
    required this.id,
    required this.name,
    this.rarity = SkinRarity.common,
    required this.bodyColors,
    this.eyeColor = Colors.white,
    this.tongueColor = Colors.redAccent,
    this.price = 0,
  });

  // Helper to get Rarity Color for UI
  Color get rarityColor {
    switch (rarity) {
      case SkinRarity.common: return Colors.grey;
      case SkinRarity.rare: return Colors.blue;
      case SkinRarity.epic: return Colors.purple;
      case SkinRarity.legendary: return Colors.orange;
      case SkinRarity.ultimate: return Colors.redAccent;
    }
  }
}

final List<SnakeSkin> snakeSkins = [
  // COMMON (2 Colors)
  SnakeSkin(id: "c1", name: "FOREST", rarity: SkinRarity.common, price: 0, bodyColors: [Color(0xFF4CAF50), Color(0xFF2E7D32)]),
  SnakeSkin(id: "c2", name: "DESERT", rarity: SkinRarity.common, price: 50, bodyColors: [Color(0xFFEDC9AF), Color(0xFFC2B280)]),
  SnakeSkin(id: "c3", name: "MIDNIGHT", rarity: SkinRarity.common, price: 70, bodyColors: [Color(0xFF2C3E50), Color(0xFF000000)]),
  SnakeSkin(id: "c4", name: "CHERRY", rarity: SkinRarity.common, price: 90, bodyColors: [Color(0xFFFF5F6D), Color(0xFFFFC371)]),
  SnakeSkin(id: "c5", name: "SKY", rarity: SkinRarity.common, price: 120, bodyColors: [Color(0xFF2193b0), Color(0xFF6dd5ed)]),

  // RARE (Blue Theme)
  SnakeSkin(id: "r1", name: "OCEAN", rarity: SkinRarity.rare, price: 250, bodyColors: [Colors.blue, Colors.cyan]),
  SnakeSkin(id: "r2", name: "COBALT", rarity: SkinRarity.rare, price: 280, bodyColors: [Color(0xFF00416A), Color(0xFFE4E5E6)]),
  SnakeSkin(id: "r3", name: "TOXIC", rarity: SkinRarity.rare, price: 300, bodyColors: [Color(0xFFADFF2F), Color(0xFF006400)], tongueColor: Colors.greenAccent),
  SnakeSkin(id: "r4", name: "FROST", rarity: SkinRarity.rare, price: 320, bodyColors: [Colors.white, Colors.lightBlueAccent], eyeColor: Colors.blue),
  SnakeSkin(id: "r5", name: "AMBER", rarity: SkinRarity.rare, price: 270, bodyColors: [Color(0xFFFFBF00), Color(0xFFFF7E00)]),

  // EPIC (Purple/Violent Themes)
  SnakeSkin(id: "e1", name: "INFERNO", rarity: SkinRarity.epic, price: 600, bodyColors: [Colors.orange, Colors.red, Colors.black]),
  SnakeSkin(id: "e2", name: "VOID", rarity: SkinRarity.epic, price: 650, bodyColors: [Colors.deepPurple, Colors.indigo, Colors.black]),
  SnakeSkin(id: "e3", name: "JUNGLE", rarity: SkinRarity.epic, price: 750, bodyColors: [Colors.green, Colors.yellow, Colors.brown]),
  SnakeSkin(id: "e4", name: "STORM", rarity: SkinRarity.epic, price: 640, bodyColors: [Colors.blueGrey, Colors.white, Colors.blue]),
  SnakeSkin(id: "e5", name: "VAMPIRE", rarity: SkinRarity.epic, price: 620, bodyColors: [Colors.red, Colors.black, Colors.grey], eyeColor: Colors.red),

  // LEGENDARY (Gold/Premium)
  SnakeSkin(id: "l1", name: "ROYAL", rarity: SkinRarity.legendary, price: 1200, bodyColors: [Color(0xFFFFD700), Color(0xFFB8860B), Colors.white]),
  SnakeSkin(id: "l2", name: "DIAMOND", rarity: SkinRarity.legendary, price: 1500, bodyColors: [Colors.white, Colors.cyanAccent, Colors.blueAccent], eyeColor: Colors.cyan),
  SnakeSkin(id: "l3", name: "PHOENIX", rarity: SkinRarity.legendary, price: 1000, bodyColors: [Colors.redAccent, Colors.orangeAccent, Colors.yellowAccent]),
  SnakeSkin(id: "l4", name: "DRAGON", rarity: SkinRarity.legendary, price: 1050, bodyColors: [Color(0xFF556B2F), Color(0xFF8B0000), Color(0xFFDAA520)]),

  // ULTIMATE (Animated/Neon)
  SnakeSkin(id: "u1", name: "HYPERDRIVE", rarity: SkinRarity.ultimate, price: 2000, bodyColors: [Color(0xFFF50057), Color(0xFF00E5FF), Color(0xFFD500F9), Colors.yellow]),
  SnakeSkin(id: "u2", name: "GALAXY", rarity: SkinRarity.ultimate, price: 2500, bodyColors: [Colors.black, Colors.deepPurple, Colors.blue, Colors.pinkAccent]),
  SnakeSkin(id: "u3", name: "MATRIX", rarity: SkinRarity.ultimate, price: 3000, bodyColors: [Colors.black, Color(0xFF00FF00), Color(0xFF003B00), Color(0xFF008F11)]),
  SnakeSkin(id: "u4", name: "AURORA", rarity: SkinRarity.ultimate, price: 4000, bodyColors: [Color(0xFF74ebd5), Color(0xFFACB6E5), Color(0xFFee9ca7), Color(0xFFffdde1)]),
  SnakeSkin(id: "u5", name: "ZENITH", rarity: SkinRarity.ultimate, price: 5000, bodyColors: [Colors.white, Colors.black, Colors.white, Colors.black]),
];