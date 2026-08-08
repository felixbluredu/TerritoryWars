import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/player.dart';

// Anonymous sign-in plus the player's document in Firestore. One document per
// uid, in the "players" collection.
class PlayerService {
  PlayerService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static const String collectionName = 'players';

  String? get uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _players =>
      _firestore.collection(collectionName);

  // Signs in anonymously unless this device already has an account. Firebase
  // keeps the account on the device, so the same uid comes back next launch.
  Future<String> signIn() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing.uid;

    final credential = await _auth.signInAnonymously();
    return credential.user!.uid;
  }

  // The stored player, or null if this uid hasn't saved one yet.
  Future<Player?> load(String uid) async {
    final doc = await _players.doc(uid).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return Player.fromMap(data);
  }

  // Writes the player only if there isn't one already. The document id is the
  // uid, so a second call returns the stored player instead of duplicating it.
  Future<Player> createIfAbsent({
    required String uid,
    required String nickname,
    required Color color,
  }) async {
    final existing = await load(uid);
    if (existing != null) return existing;

    final player = Player(uid: uid, nickname: nickname, color: color);
    await _players.doc(uid).set(player.toMap());
    return player;
  }
}
