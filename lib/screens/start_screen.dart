import 'package:flutter/material.dart';

import '../services/player_service.dart';
import '../services/territory_service.dart';
import '../utils/nickname_validator.dart';
import 'map_screen.dart';

// Colors to pick from. Chosen to stay visible on top of the OSM tiles.
const List<Color> kPresetColors = [
  Color(0xFFE53935), // red
  Color(0xFFF4511E), // deep orange
  Color(0xFFFFB300), // amber
  Color(0xFF43A047), // green
  Color(0xFF00897B), // teal
  Color(0xFF00ACC1), // cyan
  Color(0xFF1E88E5), // blue
  Color(0xFF3949AB), // indigo
  Color(0xFF8E24AA), // purple
  Color(0xFFD81B60), // pink
];

class StartScreen extends StatefulWidget {
  const StartScreen({super.key, this.playerService, this.territoryService});

  // Both null in widget tests, where there's no Firebase to talk to.
  final PlayerService? playerService;

  // Passed straight through to the map, which is what uses it.
  final TerritoryService? territoryService;

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  final TextEditingController _nicknameController = TextEditingController();

  int? _selectedColorIndex;
  String? _errorText;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadExistingPlayer();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  bool get _canStart =>
      !_saving &&
      _nicknameController.text.trim().isNotEmpty &&
      _selectedColorIndex != null;

  // If this device already has a player saved, show their name and color
  // instead of an empty form.
  Future<void> _loadExistingPlayer() async {
    final service = widget.playerService;
    final uid = service?.uid;
    if (service == null || uid == null) return;

    try {
      final player = await service.load(uid);
      if (player == null || !mounted) return;

      final index = kPresetColors.indexWhere(
        (c) => c.toARGB32() == player.color.toARGB32(),
      );
      setState(() {
        _nicknameController.text = player.nickname;
        if (index != -1) _selectedColorIndex = index;
      });
    } catch (e) {
      debugPrint('Could not load existing player: $e');
    }
  }

  Future<void> _onStartPressed() async {
    final error = NicknameValidator.validate(_nicknameController.text);
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }
    if (_selectedColorIndex == null) {
      setState(() => _errorText = 'Please pick a color.');
      return;
    }

    var nickname = _nicknameController.text.trim();
    var color = kPresetColors[_selectedColorIndex!];

    final service = widget.playerService;
    final uid = service?.uid;
    if (service != null && uid != null) {
      setState(() {
        _saving = true;
        _errorText = null;
      });
      try {
        // Returns the stored player if there already is one for this uid.
        final player = await service.createIfAbsent(
          uid: uid,
          nickname: nickname,
          color: color,
        );
        nickname = player.nickname;
        color = player.color;
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _errorText = "Couldn't save your player. Check your connection.";
        });
        return;
      }
      if (!mounted) return;
      setState(() => _saving = false);
    } else if (service != null && uid == null) {
      setState(() => _errorText = "You're not signed in yet. Try again.");
      return;
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MapScreen(
          nickname: nickname,
          trailColor: color,
          territoryService: widget.territoryService,
          ownerUid: uid,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Territory Wars',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pick a name and a color to claim your turf.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _nicknameController,
                    maxLength: NicknameValidator.maxLength,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Nickname',
                      hintText: 'e.g. TrailBlazer',
                      border: const OutlineInputBorder(),
                      errorText: _errorText,
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    onChanged: (_) {
                      // Clear the old error and re-check if Start can enable.
                      setState(() => _errorText = null);
                    },
                    onSubmitted: (_) {
                      if (_canStart) _onStartPressed();
                    },
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Trail color', style: theme.textTheme.titleMedium),
                  ),
                  const SizedBox(height: 12),
                  _buildColorSwatches(theme),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _canStart ? _onStartPressed : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Start'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorSwatches(ThemeData theme) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: List.generate(kPresetColors.length, (index) {
        final color = kPresetColors[index];
        final selected = _selectedColorIndex == index;
        return GestureDetector(
          onTap: () => setState(() => _selectedColorIndex = index),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? theme.colorScheme.onSurface
                    : Colors.transparent,
                width: 3,
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 3),
              ],
            ),
            child: selected
                ? const Icon(Icons.check, color: Colors.white, size: 24)
                : null,
          ),
        );
      }),
    );
  }
}
