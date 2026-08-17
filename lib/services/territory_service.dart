import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/territory.dart';

// Captured loops in the "territories" collection. One document per loop, with
// an auto-generated id, so a player can own many.
class TerritoryService {
  TerritoryService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String collectionName = 'territories';

  CollectionReference<Map<String, dynamic>> get _territories =>
      _firestore.collection(collectionName);

  // Writes a new territory and returns it with the document id filled in.
  Future<Territory> save(Territory territory) async {
    final ref = await _territories.add(territory.toMap());
    return territory.copyWith(id: ref.id);
  }

  // Every territory in the game, from every player, re-emitted whenever the
  // collection changes. Firestore reports local writes straight away, so a loop
  // you just closed shows up without waiting for the server.
  Stream<List<Territory>> watchAll() {
    return _territories.snapshots().map((snapshot) {
      final territories = <Territory>[];
      for (final doc in snapshot.docs) {
        try {
          territories.add(Territory.fromMap(doc.data(), id: doc.id));
        } catch (e) {
          // One malformed document shouldn't blank out everyone's map, and
          // this collection has other players' writes in it.
          debugPrint('Skipping unreadable territory ${doc.id}: $e');
        }
      }
      return territories;
    });
  }

  // Every territory this uid has claimed, oldest first.
  Future<List<Territory>> loadForOwner(String uid) async {
    final snapshot =
        await _territories.where('ownerUid', isEqualTo: uid).get();

    final territories = [
      for (final doc in snapshot.docs) Territory.fromMap(doc.data(), id: doc.id),
    ];

    // Sorted here rather than with orderBy, because an equality filter plus an
    // orderBy on a different field would need a composite index.
    territories.sort((a, b) {
      final aTime = a.createdAt;
      final bTime = b.createdAt;
      if (aTime == null || bTime == null) return 0;
      return aTime.compareTo(bTime);
    });

    return territories;
  }
}
