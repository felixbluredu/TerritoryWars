import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:territory_wars/models/player.dart';

void main() {
  group('Player', () {
    test('survives a round trip through a Firestore map', () {
      const player = Player(
        uid: 'abc123',
        nickname: 'TrailBlazer',
        color: Color(0xFF1E88E5),
      );

      final restored = Player.fromMap(player.toMap());

      expect(restored.uid, player.uid);
      expect(restored.nickname, player.nickname);
      expect(restored.color.toARGB32(), player.color.toARGB32());
    });

    test('stores the color as an int', () {
      const player = Player(
        uid: 'abc123',
        nickname: 'Mia',
        color: Color(0xFFE53935),
      );

      expect(player.toMap()['color'], 0xFFE53935);
    });
  });
}
