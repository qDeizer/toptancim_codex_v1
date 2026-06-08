import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const MapPickerScreen({super.key, this.initialLocation});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late LatLng _pickedLocation;
  
  @override
  void initState() {
    super.initState();
    _pickedLocation = widget.initialLocation ?? const LatLng(38.6143, 27.4287); // Manisa'nın merkezi
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Konum Seç'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              Navigator.of(context).pop(_pickedLocation);
            },
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _pickedLocation,
          zoom: 13,
        ),
        onTap: (location) {
          setState(() {
            _pickedLocation = location;
          });
        },
        markers: {
          Marker(
            markerId: const MarkerId('m1'),
            position: _pickedLocation,
          ),
        },
      ),
    );
  }
}