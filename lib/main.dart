import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(MaterialApp(home: GoogleMapTrackingApp()));

class GoogleMapTrackingApp extends StatefulWidget {
  @override
  _GoogleMapTrackingAppState createState() => _GoogleMapTrackingAppState();
}

class _GoogleMapTrackingAppState extends State<GoogleMapTrackingApp> {
  GoogleMapController? _mapController;
  bool _tracking = false;
  List<LatLng> _path = [];
  StreamSubscription<Position>? _positionStream;
  Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  String _elapsedTime = "00:00";
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {}; // New set for markers

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.locationWhenInUse.request(); // For foreground location
    await Permission.locationAlways.request(); // For background location
    await Geolocator.requestPermission();
  }

  void _startTracking() async {
    if (_tracking) return;
    setState(() {
      _tracking = true;
      _path.clear();
      _polylines.clear();
      _markers.clear(); // Clear markers on start
      _stopwatch.reset();
      _stopwatch.start();
    });

    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      setState(() {
        final minutes = _stopwatch.elapsed.inMinutes
            .remainder(60)
            .toString()
            .padLeft(2, '0');
        final seconds = _stopwatch.elapsed.inSeconds
            .remainder(60)
            .toString()
            .padLeft(2, '0');
        _elapsedTime = "$minutes:$seconds";
      });
    });

    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(accuracy: LocationAccuracy.best),
    ).listen((Position position) {
      final latLng = LatLng(position.latitude, position.longitude);
      print('Latitude: ${position.latitude}, Longitude: ${position.longitude}');
      setState(() {
        _path.add(latLng);
        _polylines = {
          Polyline(
            polylineId: PolylineId("tracking_path"),
            points: _path,
            color: Colors.blue,
            width: 8, // Increased width for thicker line
          ),
        };
        _markers = {
          Marker(
            markerId: MarkerId("current_position"),
            position: latLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
          ),
        };
        if (_mapController != null) {
          _mapController?.animateCamera(CameraUpdate.newLatLng(latLng));
        }
      });
    });
  }

  void _stopTracking() {
    _positionStream?.cancel();
    _stopwatch.stop();
    _timer?.cancel();
    setState(() => _tracking = false);
  }

  void _deleteTracking() {
    _stopTracking();
    setState(() {
      _path.clear();
      _polylines.clear();
      _markers.clear();
      _elapsedTime = "00:00";
    });
  }

  @override
  void dispose() {
    _stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Tracking Time: $_elapsedTime"),
        backgroundColor: Colors.green,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: CameraPosition(
              target: LatLng(
                37.7749,
                -122.4194,
              ), // Default San Francisco location
              zoom: 15,
            ),
            myLocationEnabled: true, // Show location on map
            myLocationButtonEnabled: true,
            polylines: _polylines,
            markers: _markers, // Add markers to the map
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _tracking ? null : _startTracking,
                  child: Text("Track"),
                ),
                ElevatedButton(
                  onPressed: _tracking ? _stopTracking : null,
                  child: Text("Done"),
                ),
                ElevatedButton(
                  onPressed: _path.isNotEmpty ? _deleteTracking : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: Text("Delete"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
