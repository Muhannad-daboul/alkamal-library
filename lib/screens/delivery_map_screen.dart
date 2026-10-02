import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../widgets/app_drawer.dart';

class DeliveryMapScreen extends StatefulWidget {
  final String orderId;
  final String address;
  final LatLng location;

  const DeliveryMapScreen({
    super.key,
    required this.orderId,
    required this.address,
    required this.location,
  });

  @override
  State<DeliveryMapScreen> createState() => _DeliveryMapScreenState();
}

class _DeliveryMapScreenState extends State<DeliveryMapScreen> {
  bool _isSatellite = false;

  static const _storeLocation = LatLng(33.5138, 36.2765);
  static const _primary = Color(0xFF00827E);

  @override
  Widget build(BuildContext context) {
    final location = widget.location;

    return Scaffold(
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          // ── خريطة full screen ──────────────────────────────
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(
                (_storeLocation.latitude + location.latitude) / 2,
                (_storeLocation.longitude + location.longitude) / 2,
              ),
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: _isSatellite
                    ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.alkamal_app',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [_storeLocation, location],
                    color: _primary,
                    strokeWidth: 4,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    width: 40,
                    height: 40,
                    point: _storeLocation,
                    child: const Icon(Icons.store, color: Colors.black87, size: 32),
                  ),
                  Marker(
                    width: 40,
                    height: 40,
                    point: location,
                    child: const Icon(Icons.location_pin, color: Colors.red, size: 32),
                  ),
                ],
              ),
            ],
          ),

          // ── Overlay: أزرار وعنوان ──────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // عنوان الطلب
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(30),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Text(
                          'طلب #${widget.orderId.length > 6 ? widget.orderId.substring(0, 6) : widget.orderId}',
                          style: GoogleFonts.tajawal(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.0,
                          ),
                        ),
                      ),

                      // أزرار الجانب
                      Column(
                        children: [
                          _MapButton(
                            icon: Icons.arrow_back_ios_new,
                            onTap: () => Navigator.pop(context),
                          ),
                          const SizedBox(height: 10),
                          _MapButton(
                            icon: _isSatellite ? Icons.satellite_alt : Icons.map,
                            color: _isSatellite ? _primary : Colors.black87,
                            onTap: () => setState(() => _isSatellite = !_isSatellite),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── بطاقة معلومات الطلب (أسفل) ────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(30),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withAlpha(80),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'طلب #${widget.orderId.length > 6 ? widget.orderId.substring(0, 6) : widget.orderId}',
                    style: GoogleFonts.tajawal(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: _primary,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.address,
                          style: GoogleFonts.tajawal(
                            fontSize: 14.0,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MapButton({
    required this.icon,
    required this.onTap,
    this.color = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(30),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}
