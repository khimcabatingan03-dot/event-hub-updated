import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../app_colors.dart';
import '../helpers.dart';

class LocationScreen extends StatefulWidget {
  final String title;
  final String location;
  final String dateLabel;
  final String timeLabel;
  final String image;

  // optional coordinates — when these are set in the Firestore document
  // we use them straight away instead of guessing from the location text
  final double? lat;
  final double? lng;

  const LocationScreen({
    super.key,
    required this.title,
    required this.location,
    required this.dateLabel,
    required this.timeLabel,
    required this.image,
    this.lat,
    this.lng,
  });

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  // resolved map position (null = we couldn't work out where it is)
  LatLng? _coords;

  // true while we are still looking the place up
  bool _looking = true;

  @override
  void initState() {
    super.initState();
    _resolveCoords();
  }

  // work out the coordinates to show on the map:
  //   1. use lat/lng from the Firestore document if they exist
  //   2. otherwise look the location text up on OpenStreetMap (free)
  //   3. if that fails, _coords stays null and we show the old placeholder
  Future<void> _resolveCoords() async {
    // 1. coordinates already stored on the event
    if (widget.lat != null && widget.lng != null) {
      if (!mounted) return;
      setState(() {
        _coords = LatLng(widget.lat!, widget.lng!);
        _looking = false;
      });
      return;
    }

    final String place = widget.location.trim();
    if (place.isEmpty) {
      if (!mounted) return;
      setState(() => _looking = false);
      return;
    }

    // 2. try the place as written, then with the country added for context
    LatLng? found = await _geocode(place);
    found ??= await _geocode('$place, Philippines');

    if (!mounted) return;
    setState(() {
      _coords = found;
      _looking = false;
    });
  }

  // ask OpenStreetMap's free (Nominatim) service where this text is
  Future<LatLng?> _geocode(String query) async {
    final Uri uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeComponent(query)}&format=json&limit=1',
    );

    try {
      final http.Response res = await http
          .get(uri, headers: {'User-Agent': 'eventhub/1.0 (school project)'})
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return null;

      final dynamic body = jsonDecode(res.body);
      if (body is! List || body.isEmpty) return null;

      final double? lat = double.tryParse('${body.first['lat']}');
      final double? lon = double.tryParse('${body.first['lon']}');
      if (lat == null || lon == null) return null;

      return LatLng(lat, lon);
    } catch (_) {
      // offline, timed out, bad json — all treated as "not found"
      return null;
    }
  }

  // open the location in a maps app
  //
  // NOTE: we do NOT gate this with canLaunchUrl() — on Android 11+ the
  // package-visibility rules often make it return false even when a maps
  // app IS installed, which silently blocked the button. Instead we try
  // each way to open it and only report a failure if none of them work.
  Future<void> openInMaps() async {
    final String place = widget.location.trim();

    // nothing to search for
    if (place.isEmpty) {
      _showError('No location set for this event.');
      return;
    }

    final String encoded = Uri.encodeComponent(place);
    final List<Uri> candidates = [];

    // when we already know exactly where it is, lead with the coordinates
    if (_coords != null) {
      final String pos = '${_coords!.latitude},${_coords!.longitude}';
      candidates.add(Uri.parse('geo:$pos?q=$encoded'));
      candidates.add(Uri
          .parse('https://www.google.com/maps/search/?api=1&query=$pos'));
    }

    // otherwise fall back to searching by the location text
    candidates.add(Uri.parse('geo:0,0?q=$encoded')); // device maps app
    candidates.add(Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$encoded'));
    candidates.add(Uri.parse('https://maps.google.com/?q=$encoded'));

    for (final Uri url in candidates) {
      try {
        final bool ok =
            await launchUrl(url, mode: LaunchMode.externalApplication);
        if (ok) return; // opened successfully
      } catch (_) {
        // try the next option
      }
    }

    // none of them worked
    if (mounted) {
      _showError("Couldn't open a maps app on this device.");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  // the original grey "streets" drawing — kept as the fallback for when we
  // can't work out where the event is (empty location, no internet, etc)
  Widget _placeholderMap() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFE5E5E5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // fake streets
          Container(width: double.infinity, height: 12, color: Colors.white),
          Container(width: double.infinity, height: 12, color: Colors.white),
          Container(width: double.infinity, height: 12, color: Colors.white),
          Container(width: double.infinity, height: 12, color: Colors.white),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // map area
            Expanded(
              child: Stack(
                children: [
                  // the real map when we know where it is
                  if (_coords != null)
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: _coords!,
                        initialZoom: 16,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.eventhub',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _coords!,
                              width: 50,
                              height: 50,
                              child: const Icon(Icons.location_on,
                                  color: AppColors.primary, size: 50),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    // the old grey placeholder while we look, or if we give up
                    _placeholderMap(),

                  // still looking up the place
                  if (_looking)
                    const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary),
                    ),

                  // map data credit (required by OpenStreetMap)
                  if (_coords != null)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white70,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '© OpenStreetMap contributors',
                          style: TextStyle(
                              fontSize: 9, color: Colors.black54),
                        ),
                      ),
                    ),

                  // back button
                  Positioned(
                    top: 10,
                    left: 10,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      style: IconButton.styleFrom(
                          backgroundColor: Colors.white),
                    ),
                  ),

                  // top bar with location name
                  Positioned(
                    top: 10,
                    left: 60,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.location,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // bottom card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // event info row
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          widget.image,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            width: 50,
                            height: 50,
                            color: AppColors.primary,
                            child: const Icon(Icons.event,
                                color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on,
                                    color: AppColors.greyText, size: 12),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${widget.location}, campus',
                                    style: const TextStyle(
                                        color: AppColors.greyText,
                                        fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.access_time,
                                    color: AppColors.greyText, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.dateLabel} · ${timeStart(widget.timeLabel)}',
                                  style: const TextStyle(
                                      color: AppColors.greyText,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // open in maps button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: openInMaps,
                      icon: const Icon(Icons.navigation, color: Colors.white),
                      label: const Text(
                        'Open in Maps',
                        style:
                            TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // caption
                  const Center(
                    child: Text(
                      "Opens your device's maps app",
                      style: TextStyle(
                          color: AppColors.greyText, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
