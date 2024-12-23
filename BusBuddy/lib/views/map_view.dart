import 'dart:async';
import 'dart:convert';
import 'package:busbuddy/views/custom_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Location _locationController = Location();
  final LatLng _initialPosition = const LatLng(-26.26447, 27.88018);
  LatLng? _currentPosition;
  MapController mapController = MapController();
  double _currentZoom = 13.0;
  List<Marker> busStopMarkers = [];
  List<Polyline> busRoutes = [];
  bool _firstLocationUpdate = true;

  @override
  void initState() {
    super.initState();
    getLocationUpdates();
    fetchBusStops();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const Drawer(
        child: Center(child: CustomDrawer()),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              center: _initialPosition,
              zoom: _currentZoom,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: const ['a', 'b', 'c'],
                additionalOptions: const {
                  'attribution': "© OpenStreetMap contributors",
                },
              ),
              PolylineLayer(
                polylines: busRoutes,
              ),
              MarkerLayer(
                markers: [
                  ...busStopMarkers,
                  if (_currentPosition != null)
                    Marker(
                      point: _currentPosition!,
                      builder: (ctx) => const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 40.0,
                      ),
                    ),
                  Marker(
                    point: _initialPosition,
                    builder: (ctx) => const Icon(
                      Icons.location_pin,
                      color: Colors.blue,
                      size: 40.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 15,
            top: 50,
            child: Ink(
              decoration: const ShapeDecoration(
                color: Colors.white,
                shape: CircleBorder(),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.menu,
                  color: Colors.black,
                ),
                iconSize: 35.0,
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            ),
          ),
          Positioned(
            right: 15,
            bottom: 100,
            child: FloatingActionButton(
              heroTag: "zoom_1",
              onPressed: () {
                setState(() {
                  _currentZoom += 1;
                  mapController.move(mapController.center, _currentZoom);
                });
              },
              child: const Icon(Icons.zoom_in),
            ),
          ),
          Positioned(
            right: 15,
            bottom: 30,
            child: FloatingActionButton(
              heroTag: "zoom_2",
              onPressed: () {
                setState(() {
                  _currentZoom -= 1;
                  mapController.move(mapController.center, _currentZoom);
                });
              },
              child: const Icon(Icons.zoom_out),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> getLocationUpdates() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await _locationController.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _locationController.requestService();
      if (!serviceEnabled) return;
    }

    permissionGranted = await _locationController.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _locationController.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    _locationController.onLocationChanged
        .listen((LocationData currentLocation) {
      if (currentLocation.latitude != null &&
          currentLocation.longitude != null) {
        setState(() {
          _currentPosition =
              LatLng(currentLocation.latitude!, currentLocation.longitude!);
        });
        if (_firstLocationUpdate) {
          mapController.move(_currentPosition!, 13.0);
          _firstLocationUpdate = false;
        }
      }
    });
  }

  Future<void> fetchBusStops() async {
    final DatabaseReference databaseRef = FirebaseDatabase.instance.ref();
    final snapshot = await databaseRef.child('bus_routes/T1/stops').get();

    if (snapshot.exists) {
      Map<String, dynamic> stops =
          Map<String, dynamic>.from(snapshot.value as Map);
      List<Marker> markers = [];
      List<LatLng> routeCoords = [];
      List<LatLng> fullRouteCoords = [];

      stops.forEach((key, stop) async {
        LatLng stopCoord = LatLng(stop['latitude'], stop['longitude']);
        markers.add(
          Marker(
            point: stopCoord,
            builder: (ctx) => const Icon(
              Icons.location_pin,
              color: Colors.green,
              size: 40.0,
            ),
          ),
        );
        routeCoords.add(stopCoord);
      });

      for (int i = 0; i < routeCoords.length - 1; i++) {
        LatLng start = routeCoords[i];
        LatLng end = routeCoords[i + 1];

        try {
          List<LatLng> segment = await fetchRoute(start, end);
          fullRouteCoords.addAll(segment);
        } catch (e) {
          print('Error fetching route from $start to $end: $e');
        }
      }

      if (fullRouteCoords.isNotEmpty) {
        busRoutes.clear();
        busRoutes.add(
          Polyline(
            points: fullRouteCoords,
            strokeWidth: 4.0,
            color: Colors.red,
          ),
        );
      }

      setState(() {
        busStopMarkers = markers;
      });
    } else {
      print('No data available for this route.');
    }
  }

  Future<List<LatLng>> fetchRoute(LatLng start, LatLng end) async {
    final url =
        'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> coordinates =
          data['routes'][0]['geometry']['coordinates'];
      return coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();
    } else {
      throw Exception('Failed to fetch route');
    }
  }
}
