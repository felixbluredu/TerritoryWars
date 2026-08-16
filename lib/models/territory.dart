import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

// One captured loop: who claimed it, what it looks like, and when.
class Territory {
  const Territory({
    this.id,
    required this.ownerUid,
    required this.nickname,
    required this.color,
    required this.points,
    this.createdAt,
  });

  // Firestore's document id. Null until the document has been written.
  final String? id;

  final String ownerUid;
  final String nickname;
  final Color color;

  // The closed loop, in walking order. Order matters, it's the polygon shape.
  final List<LatLng> points;

  // Null on a territory that hasn't been saved yet, the server fills it in.
  final DateTime? createdAt;

  factory Territory.fromMap(Map<String, dynamic> map, {String? id}) {
    final rawPoints = (map['points'] as List<dynamic>? ?? const []);
    return Territory(
      id: id,
      ownerUid: map['ownerUid'] as String,
      nickname: map['nickname'] as String,
      color: Color(map['color'] as int),
      points: [
        for (final point in rawPoints.cast<GeoPoint>())
          LatLng(point.latitude, point.longitude),
      ],
      // Missing while the server timestamp is still pending on a local write.
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerUid': ownerUid,
      'nickname': nickname,
      // Same as Player: no color type in Firestore, so ARGB int.
      'color': color.toARGB32(),
      'points': [
        for (final point in points) GeoPoint(point.latitude, point.longitude),
      ],
      // Let the server stamp new territories so the time doesn't depend on the
      // phone's clock.
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
    };
  }

  Territory copyWith({String? id, DateTime? createdAt}) {
    return Territory(
      id: id ?? this.id,
      ownerUid: ownerUid,
      nickname: nickname,
      color: color,
      points: points,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
