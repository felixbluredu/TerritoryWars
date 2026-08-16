import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:territory_wars/models/territory.dart';

void main() {
  group('Territory', () {
    final points = [
      const LatLng(44.4268, 26.1025),
      const LatLng(44.4275, 26.1031),
      const LatLng(44.4269, 26.1040),
      const LatLng(44.4268, 26.1025),
    ];

    test('survives a round trip through a Firestore map', () {
      final createdAt = DateTime.utc(2026, 8, 16, 12, 30);
      final territory = Territory(
        ownerUid: 'abc123',
        nickname: 'TrailBlazer',
        color: const Color(0xFF1E88E5),
        points: points,
        createdAt: createdAt,
      );

      final restored = Territory.fromMap(territory.toMap(), id: 'doc1');

      expect(restored.id, 'doc1');
      expect(restored.ownerUid, territory.ownerUid);
      expect(restored.nickname, territory.nickname);
      expect(restored.color.toARGB32(), territory.color.toARGB32());
      // Firestore hands timestamps back in local time, so compare the instant
      // rather than the DateTime, which also carries an isUtc flag.
      expect(restored.createdAt, isNotNull);
      expect(restored.createdAt!.isAtSameMomentAs(createdAt), isTrue);
      expect(restored.points.length, points.length);
      for (var i = 0; i < points.length; i++) {
        expect(restored.points[i].latitude, closeTo(points[i].latitude, 1e-9));
        expect(restored.points[i].longitude, closeTo(points[i].longitude, 1e-9));
      }
    });

    test('stores the loop as GeoPoints, in walking order', () {
      final territory = Territory(
        ownerUid: 'abc123',
        nickname: 'Mia',
        color: const Color(0xFFE53935),
        points: points,
        createdAt: DateTime.utc(2026, 8, 16),
      );

      final stored = territory.toMap()['points'] as List<dynamic>;

      expect(stored, everyElement(isA<GeoPoint>()));
      expect((stored.first as GeoPoint).latitude, closeTo(44.4268, 1e-9));
      expect((stored.last as GeoPoint).longitude, closeTo(26.1025, 1e-9));
    });

    test('reads back a document whose server timestamp is still pending', () {
      final territory = Territory(
        ownerUid: 'abc123',
        nickname: 'Mia',
        color: const Color(0xFFE53935),
        points: points,
      );

      // What the local copy looks like before the server writes createdAt.
      final map = Map<String, dynamic>.from(territory.toMap())
        ..['createdAt'] = null;

      expect(Territory.fromMap(map).createdAt, isNull);
    });
  });
}
