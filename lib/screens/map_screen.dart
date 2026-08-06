import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

// Map that follows the player's location. Nickname and color come from the
// start screen.
class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.nickname,
    required this.trailColor,
  });

  final String nickname;
  final Color trailColor;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  static const double _followZoom = 16;

  // Loop detection. GPS on the emulator jumps around a lot, so the close
  // radius is generous and the leave distance is much bigger than it, so a new
  // trail can't close on its own start point right away.
  static const double _loopCloseThresholdMeters = 10;
  static const double _minLeaveDistanceMeters = 60;

  final MapController _mapController = MapController();
  final Distance _distance = const Distance();

  StreamSubscription<Position>? _positionSub;

  // Used to slide the map and marker between GPS fixes instead of snapping.
  late final AnimationController _moveController;
  late final CurvedAnimation _moveCurve;
  Tween<double>? _latTween;
  Tween<double>? _lngTween;

  LatLng? _currentLocation;

  // The walked path, one point per GPS fix.
  final List<LatLng> _trail = [];

  // Every closed loop, drawn as a filled polygon. TODO: save these so they
  // survive a restart.
  final List<List<LatLng>> _territories = [];

  // Set once we're far enough from the start for a return to count as a loop.
  bool _hasLeftStart = false;

  String? _error;
  bool _loading = true;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _moveCurve = CurvedAnimation(
      parent: _moveController,
      curve: Curves.easeInOut,
    );
    _moveController.addListener(_onMoveTick);
    _startTracking();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _moveController.dispose();
    super.dispose();
  }

  // Check permission, get a first fix to center on, then start the stream.
  Future<void> _startTracking() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled. Enable them and try again.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw 'Location permission was denied.';
      }
      if (permission == LocationPermission.deniedForever) {
        throw 'Location permission is permanently denied. Enable it in Settings.';
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;
      final start = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentLocation = start;
        _trail
          ..clear()
          ..add(start);
        _hasLeftStart = false;
        _loading = false;
      });

      _subscribeToPositionStream();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _subscribeToPositionStream() {
    _positionSub?.cancel();
    // distanceFilter 0 means every fix is reported, which keeps it smooth.
    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
          ),
        ).listen(
          (position) => _onNewPosition(
            LatLng(position.latitude, position.longitude),
          ),
          onError: (Object e) {
            if (!mounted) return;
            setState(() => _error = e.toString());
          },
        );
  }

  void _onNewPosition(LatLng dest) {
    if (!mounted) return;

    // Skip fixes that didn't move, the stream repeats the same point when you
    // stand still.
    final last = _trail.isNotEmpty ? _trail.last : null;
    if (last == null || last.latitude != dest.latitude ||
        last.longitude != dest.longitude) {
      _trail.add(dest);
    }

    if (_checkLoopClosed(dest)) {
      _onLoopClosed(dest);
      return;
    }

    // Can't read the camera before the map is laid out, but initialCenter
    // already centers it on this point anyway.
    if (!_mapReady) {
      setState(() => _currentLocation = dest);
      return;
    }

    // Start from where the camera is right now, even if it's mid-animation,
    // otherwise overlapping updates jump.
    final from = _mapController.camera.center;
    _latTween = Tween<double>(begin: from.latitude, end: dest.latitude);
    _lngTween = Tween<double>(begin: from.longitude, end: dest.longitude);
    _moveController
      ..reset()
      ..forward();
  }

  // True when we're back near the start, but only if we left it first.
  // TODO: doesn't handle a path that crosses itself, only start-to-start.
  bool _checkLoopClosed(LatLng current) {
    if (_trail.length < 2) return false;

    final start = _trail.first;
    final metersFromStart = _distance.as(LengthUnit.Meter, current, start);

    if (!_hasLeftStart) {
      if (metersFromStart >= _minLeaveDistanceMeters) {
        _hasLeftStart = true;
      }
      return false;
    }

    return metersFromStart <= _loopCloseThresholdMeters;
  }

  // Shows the message and resets the trail so the next loop starts here.
  void _onLoopClosed(LatLng current) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Loop closed!'),
          duration: Duration(seconds: 2),
        ),
      );

    setState(() {
      // Copy the points out before clearing the trail.
      _territories.add(List<LatLng>.from(_trail));
      _trail
        ..clear()
        ..add(current);
      _hasLeftStart = false;
      _currentLocation = current;
    });
  }

  void _onMoveTick() {
    if (_latTween == null || _lngTween == null) return;
    final t = _moveCurve.value;
    final point = LatLng(_latTween!.transform(t), _lngTween!.transform(t));
    _mapController.move(point, _mapController.camera.zoom);
    setState(() => _currentLocation = point);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      floatingActionButton: _currentLocation == null
          ? null
          : FloatingActionButton(
              onPressed: () =>
                  _mapController.move(_currentLocation!, _followZoom),
              tooltip: 'Recenter on my location',
              child: const Icon(Icons.my_location),
            ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off, size: 48),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _startTracking,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final location = _currentLocation!;
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: location,
            initialZoom: _followZoom,
            onMapReady: () => _mapReady = true,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.territorywars.territory_wars',
            ),
            if (_territories.isNotEmpty)
              PolygonLayer(
                polygons: [
                  for (final area in _territories)
                    Polygon(
                      points: area,
                      color: widget.trailColor.withValues(alpha: 0.5),
                      borderColor: widget.trailColor,
                      borderStrokeWidth: 3,
                    ),
                ],
              ),
            if (_trail.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _trail,
                    strokeWidth: 10,
                    color: widget.trailColor,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: location,
                  width: 40,
                  height: 40,
                  child: Icon(
                    Icons.location_pin,
                    color: widget.trailColor,
                    size: 40,
                  ),
                ),
              ],
            ),
          ],
        ),
        _buildNameBadge(),
      ],
    );
  }

  // Name + color badge in the top corner.
  Widget _buildNameBadge() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 8, backgroundColor: widget.trailColor),
                const SizedBox(width: 8),
                Text(
                  widget.nickname,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
