import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationTrackingScreen extends StatefulWidget {
  final String parentId;

  const LocationTrackingScreen({required this.parentId});

  @override
  _LocationTrackingScreenState createState() => _LocationTrackingScreenState();
}

class _LocationTrackingScreenState extends State<LocationTrackingScreen> {
  late GoogleMapController mapController;
  final Set<Marker> _markers = {};

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Child Location Tracking'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('parents')
            .doc(widget.parentId)
            .collection('children')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return CircularProgressIndicator();

          _markers.clear();

          snapshot.data!.docs.forEach((doc) {
            var childData = doc.data() as Map<String, dynamic>;
            var locationData = childData['locationData'] as Map<String, dynamic>;
  
            // Convert Map to GeoPoint
            var location = GeoPoint(
              locationData['latitude'] as double,
              locationData['longitude'] as double,
            );
            var childrenName = childData['childrenName'];

            _markers.add(
              Marker(
                markerId: MarkerId(doc.id),
                position: LatLng(location.latitude, location.longitude),
                infoWindow: InfoWindow(
                  title: childrenName,
                  snippet: 'Click to view details',
                  onTap: () {
                    _showChildDetails(
                      childrenName,
                      location,
                      'School',
                      'Bandar Sungai Long, 43200 Kajang, Selangor',
                    );
                  },
                ),
              ),
            );
          });

          return GoogleMap(
            onMapCreated: _onMapCreated,
            markers: _markers,
            initialCameraPosition: CameraPosition(
              target: LatLng(2.993885, 101.789853), // Default location
              zoom: 15,
            ),
          );
        },
      ),
    );
  }

  void _showChildDetails(String name, GeoPoint location, String place, String address) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Place: $place'),
              SizedBox(height: 8),
              Text('Location: $address'),
              IconButton(
                icon: Icon(Icons.favorite_border),
                onPressed: () {
                  _saveFavoritePlace(name, location);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _saveFavoritePlace(String name, GeoPoint location) {
    FirebaseFirestore.instance.collection('parents').doc(widget.parentId).collection('favoritePlaces').add({
      'name': name,
      'location': location,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Location saved as favorite!')),
    );
  }
}
