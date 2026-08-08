import 'package:flutter/material.dart';

// One player, keyed by their anonymous Firebase uid.
class Player {
  const Player({
    required this.uid,
    required this.nickname,
    required this.color,
  });

  final String uid;
  final String nickname;
  final Color color;

  // Firestore has no color type, so it goes in and out as a plain ARGB int.
  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      uid: map['uid'] as String,
      nickname: map['nickname'] as String,
      color: Color(map['color'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nickname': nickname,
      'color': color.toARGB32(),
    };
  }
}
