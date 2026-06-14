import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/model/challenge.dart';
import '../../domain/provider/challenge_provider.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _spFallback = LatLng(-23.5505, -46.6333);

  final _mapController = MapController();
  LatLng _userLocation = _spFallback;
  bool _locationLoaded = false;
  List<Marker> _markers = [];
  List<CircleMarker> _circles = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initLocation());
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) { _buildMarkers(_spFallback); return; }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) { _buildMarkers(_spFallback); return; }
      }
      if (perm == LocationPermission.deniedForever) { _buildMarkers(_spFallback); return; }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      if (!mounted) return;
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() { _userLocation = loc; _locationLoaded = true; });
      _buildMarkers(loc);
      _mapController.move(loc, 14);
    } catch (_) {
      _buildMarkers(_spFallback);
    }
  }

  void _buildMarkers(LatLng userPos) {
    final cp = context.read<ChallengeProvider>();
    final challenges = cp.allChallenges;
    final markers = <Marker>[];
    final circles = <CircleMarker>[];

    // Marcador do usuário
    markers.add(Marker(
      point: userPos,
      width: 44,
      height: 44,
      child: Tooltip(
        message: 'Você está aqui',
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue.shade700,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(color: Colors.blue.withAlpha(100), blurRadius: 8)],
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 22),
        ),
      ),
    ));

    circles.add(CircleMarker(
      point: userPos,
      radius: 200,
      useRadiusInMeter: true,
      color: Colors.blue.withAlpha(30),
      borderColor: Colors.blue.withAlpha(120),
      borderStrokeWidth: 2,
    ));

    // Marcadores de desafios
    for (var i = 0; i < challenges.length; i++) {
      final c = challenges[i];
      final risk = cp.getRisk(c.id);
      final offset = _offset(i);
      final pos = LatLng(
        userPos.latitude + offset.$1,
        userPos.longitude + offset.$2,
      );
      final color = c.isCompleted ? Colors.amber : AppColors.riskLow;

      markers.add(Marker(
        point: pos,
        width: 52,
        height: 62,
        child: GestureDetector(
          onTap: () => _showInfo(c, risk.riskScore),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [BoxShadow(color: color.withAlpha(120), blurRadius: 6)],
                ),
                child: Center(
                  child: Text(c.category.emoji, style: const TextStyle(fontSize: 18)),
                ),
              ),
              Container(width: 3, height: 12, color: color),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
        ),
      ));

      if (risk.riskScore > 0.7) {
        circles.add(CircleMarker(
          point: pos,
          radius: 350,
          useRadiusInMeter: true,
          color: Colors.red.withAlpha(30),
          borderColor: AppColors.riskCritical.withAlpha(120),
          borderStrokeWidth: 1,
        ));
      }
    }

    if (mounted) setState(() { _markers = markers; _circles = circles; });
  }

  void _showInfo(Challenge c, double riskScore) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: c.category.color.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text(c.category.emoji, style: const TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.title,
                          style: GoogleFonts.poppins(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      Text(c.category.displayName,
                          style: GoogleFonts.poppins(
                              color: AppColors.textSecond, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(children: [
              _Chip('Dia ${c.currentDay}/${c.totalDays}', Icons.calendar_today_outlined),
              const SizedBox(width: 8),
              _Chip('${c.streak} dias 🔥', Icons.local_fire_department_outlined),
              const SizedBox(width: 8),
              _Chip('Risco ${(riskScore * 100).toInt()}%', Icons.warning_amber_outlined),
            ]),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/challenge', arguments: c.id);
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Ver desafio'),
            ),
          ],
        ),
      ),
    );
  }

  (double, double) _offset(int i) {
    const r = 0.01;
    return (
      r * (i % 2 == 0 ? 1 : -1) * (0.5 + i * 0.1),
      r * (i % 3 == 0 ? 1 : -1) * (0.3 + i * 0.08),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Mapa de Desafios',
            style: GoogleFonts.poppins(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, color: AppColors.accent),
            tooltip: 'Centralizar',
            onPressed: () => _mapController.move(_userLocation, 14),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation,
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.level30.level30flutter',
              ),
              CircleLayer(circles: _circles),
              MarkerLayer(markers: _markers),
            ],
          ),
          Positioned(
            bottom: 16,
            left: 16,
            child: _Legend(),
          ),
          if (!_locationLoaded)
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: const Text('📍 São Paulo (localização padrão)',
                      style: TextStyle(color: AppColors.textSecond, fontSize: 12)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _Chip(this.label, this.icon);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: AppColors.textSecond, size: 11),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 11)),
        ]),
      );
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface.withAlpha(230),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            _LegendDot(color: Colors.blue, label: 'Você'),
            SizedBox(height: 4),
            _LegendDot(color: Color(0xFF00C853), label: 'Ativo'),
            SizedBox(height: 4),
            _LegendDot(color: Colors.amber, label: 'Concluído'),
            SizedBox(height: 4),
            _LegendDot(color: Colors.red, label: 'Zona de risco'),
          ],
        ),
      );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 10, height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 11)),
        ],
      );
}
