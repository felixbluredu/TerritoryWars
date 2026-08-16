import 'package:flutter/material.dart';

import '../models/player.dart';
import '../services/player_service.dart';
import '../services/territory_service.dart';
import 'map_screen.dart';
import 'start_screen.dart';

// Decides where the app opens. A uid that already has a saved player goes
// straight to the map; anyone else picks a nickname and color first.
class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key, this.playerService, this.territoryService});

  // Both null in widget tests, where there's no Firebase to talk to.
  final PlayerService? playerService;
  final TerritoryService? territoryService;

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen> {
  Player? _player;
  bool _checking = false;

  @override
  void initState() {
    super.initState();

    final service = widget.playerService;
    final uid = service?.uid;
    // Nothing to look up without a signed-in uid, so fall through to the start
    // screen on the first frame rather than flashing a spinner.
    if (service == null || uid == null) return;

    _checking = true;
    _restorePlayer(service, uid);
  }

  Future<void> _restorePlayer(PlayerService service, String uid) async {
    try {
      final player = await service.load(uid);
      if (!mounted) return;
      setState(() {
        _player = player;
        _checking = false;
      });
    } catch (e) {
      // Offline, most likely. The start screen still works, and createIfAbsent
      // returns the stored player once the connection is back, so a returning
      // player can't overwrite themselves by retyping a different name.
      debugPrint('Could not restore player: $e');
      if (!mounted) return;
      setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final player = _player;
    if (player != null) {
      return MapScreen(
        nickname: player.nickname,
        trailColor: player.color,
        territoryService: widget.territoryService,
        ownerUid: player.uid,
      );
    }

    return StartScreen(
      playerService: widget.playerService,
      territoryService: widget.territoryService,
    );
  }
}
