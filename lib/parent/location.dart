// location

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  StreamSubscription<Position>? _positionStreamSubscription;
  
  GoogleMapController? _googleMapController;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {}; // To store the circles
  Map<CircleId, String> _circleNames = {};
  Position? _parentPosition;
  TextEditingController _placeNameController = TextEditingController();
  double _radius = 100.0; // Default radius
  Color _selectedColor = Colors.blue;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  

  Future<void> _loadLocations() async {
    try {
      _parentPosition = await _determinePosition();
      if (_parentPosition != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('parentLocation'),
            position: LatLng(_parentPosition!.latitude, _parentPosition!.longitude),
            infoWindow: const InfoWindow(title: 'Parent Location'),
          ),
        );
        _googleMapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(_parentPosition!.latitude, _parentPosition!.longitude),
              zoom: 14,
            ),
          ),
        );
      }
      await _getChildrenLocations();
      await _getMarkedPlaces(); // Load marked places
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading locations: $e')),
      );
    }
  }

  Future<void> _getChildrenLocations() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user is logged in')),
      );
      return;
    }

    QuerySnapshot childrenSnapshot = await _firestore
        .collection('parents')
        .doc(currentUser.uid)
        .collection('children')
        .get();

    setState(() {
      _markers.addAll(
        childrenSnapshot.docs.map((doc) {
          var data = doc.data() as Map<String, dynamic>;
          var locationData = data['locationData'];
          if (locationData is GeoPoint) {
            return Marker(
              markerId: MarkerId(doc.id),
              position: LatLng(locationData.latitude, locationData.longitude),
              infoWindow: InfoWindow(
                title: data['childrenName'],
                snippet: 'Tap for more info',
              ),
              onTap: () {
                _showLocationDetails(
                  doc.id,
                  data['childrenName'],
                  locationData.latitude,
                  locationData.longitude,
                );
              },
            );
          } else {
            print('Location data is not a GeoPoint');
            return null;
          }
        }).whereType<Marker>(),
      );
    });
  }

  Future<void> _getMarkedPlaces() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      return;
    }

    try {
      QuerySnapshot markedPlacesSnapshot = await _firestore
          .collection('parents')
          .doc(currentUser.uid)
          .collection('markedPlaces')
          .get();

      setState(() {
        _circles.addAll(
          markedPlacesSnapshot.docs.map((doc) {
            var data = doc.data() as Map<String, dynamic>;
            double lat = data['latitude'];
            double lng = data['longitude'];
            double radius = data['radius'];
            Color color = Color(int.parse(data['color']));
            String placeName = data['name'];

            CircleId circleId = CircleId(doc.id);
          _circleNames[circleId] = placeName;

            return Circle(
              circleId: CircleId(doc.id),
              //name: placeName,
              center: LatLng(lat, lng),
              radius: radius,
              fillColor: color.withOpacity(0.2),
              strokeColor: color,
              strokeWidth: 2,

            );
          }),
        );
      });
    } catch (e) {
      print('Error loading marked places: $e');
    }
  }

  Future<void> _saveMarkedPlace(double lat, double lng, [String? id]) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      return;
    }

    try {
      DocumentReference placeRef;
      if (id == null) {
        // Create new document if id is null
        placeRef = _firestore
            .collection('parents')
            .doc(currentUser.uid)
            .collection('markedPlaces')
            .doc(); // Creates a new document with a unique ID
      } else {
        // Update existing document
        placeRef = _firestore
            .collection('parents')
            .doc(currentUser.uid)
            .collection('markedPlaces')
            .doc(id);
      }

      Map<String, dynamic> placeData = {
        'name': _placeNameController.text,
        'latitude': lat,
        'longitude': lng,
        'radius': _radius,
        'color': _selectedColor.value.toString(),
        'timestamp': FieldValue.serverTimestamp(),
      };

      await placeRef.set(placeData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(id == null ? 'Place saved successfully!' : 'Place updated successfully!')),
      );

      setState(() {
        _circles.removeWhere((circle) => circle.circleId.value == placeRef.id);
        _circles.add(
          Circle(
            circleId: CircleId(placeRef.id),
            //name:_placeNameController.text,
            center: LatLng(lat, lng),
            radius: _radius,
            fillColor: _selectedColor.withOpacity(0.2),
            strokeColor: _selectedColor,
            strokeWidth: 2,
            
          ),
        );
      });
    } catch (e) {
      print('Error saving marked place: $e');
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error("Location permission denied");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied');
    }

    Position position = await Geolocator.getCurrentPosition();
    print('Current position: $position');
    return position;
  }

void _onMapLongPress(LatLng location) {
  _placeNameController.clear();
  _radius = 100.0;
  _selectedColor = Colors.blue;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) { // Use StatefulBuilder to manage state
          return AlertDialog(
            title: const Text('Mark this place'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _placeNameController,
                    decoration: const InputDecoration(
                      labelText: 'Place Name',
                    ),
                  ),
                  const SizedBox(height: 16),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Radius (meters):'),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(
                          '${_radius.round()} m',
                          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                        ),
                      ),
                      Slider(
                        value: _radius,
                        min: 10,
                        max: 1000,
                        divisions: 99,
                        label: _radius.round().toString(),
                        onChanged: (value) {
                          setState(() {
                            _radius = value; // Update radius using setState from StatefulBuilder
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Color:'),
                      IconButton(
                        icon: Icon(Icons.color_lens, color: _selectedColor),
                        onPressed: () {
                          _selectColor();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  _saveMarkedPlace(location.latitude, location.longitude);
                  Navigator.of(context).pop();
                },
                child: const Text('Save'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );
    },
  );
}





  void _selectColor() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Color'),
          content: BlockPicker(
            pickerColor: _selectedColor,
            onColorChanged: (color) {
              setState(() {
                _selectedColor = color;
              });
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _checkChildLocationsForGeofencing() async {
  User? currentUser = _auth.currentUser;
  if (currentUser == null) return;

  QuerySnapshot childrenSnapshot = await _firestore
      .collection('parents')
      .doc(currentUser.uid)
      .collection('children')
      .get();

  for (var childDoc in childrenSnapshot.docs) {
    var data = childDoc.data() as Map<String, dynamic>;
    var locationData = data['locationData'];

    if (locationData is GeoPoint) {
      LatLng childLocation = LatLng(locationData.latitude, locationData.longitude);

      for (var circle in _circles) {
        double distance = Geolocator.distanceBetween(
          circle.center.latitude,
          circle.center.longitude,
          childLocation.latitude,
          childLocation.longitude,
        );

        if (distance <= circle.radius) {
          // Notify the parent
          await _notifyParent(
            currentUser.uid,
            childDoc.id,
            _circleNames[circle.circleId]!,
          );
        }
      }
    }
  }
}

Future<void> _notifyParent(String parentId, String childId, String placeName) async {
  // Implement the logic to notify the parent
  // You can use Firebase Cloud Messaging or any other notification service
  // For simplicity, we will log the notification
  print('Child $childId is in $placeName');

  await _firestore.collection('parents').doc(parentId).collection('notifications').add({
    'childId': childId,
    'message': 'Your child is in $placeName',
    'timestamp': FieldValue.serverTimestamp(),
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Tracking'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            myLocationButtonEnabled: false,
            markers: _markers,
            circles: _circles, // Display circles on the map
            onTap: _handleTap,
            onMapCreated: (GoogleMapController controller) {
              _googleMapController = controller;
              if (_parentPosition != null) {
                _googleMapController!.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: LatLng(_parentPosition!.latitude, _parentPosition!.longitude),
                      zoom: 14,
                    ),
                  ),
                );
              }
            },
            initialCameraPosition: CameraPosition(
              target: LatLng(
                _parentPosition?.latitude ?? 0.0,
                _parentPosition?.longitude ?? 0.0,
              ),
              zoom: 14,
            ),
            onLongPress: _onMapLongPress, // Handle long press to mark places
          ),
          Positioned(
            right: 16.0,
            top: 16.0,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              child: const Icon(
                Icons.my_location,
                size: 30,
              ),
              onPressed: () async {
                if (_googleMapController != null) {
                  Position position = await _determinePosition();
                  print('New position from FloatingActionButton: $position');
                  setState(() {
                    _parentPosition = position;
                    _markers.add(
                      Marker(
                        markerId: const MarkerId('parentLocation'),
                        position: LatLng(position.latitude, position.longitude),
                        infoWindow: const InfoWindow(title: 'Parent Location'),
                      ),
                    );
                    _googleMapController!.animateCamera(
                      CameraUpdate.newCameraPosition(
                        CameraPosition(
                          target: LatLng(position.latitude, position.longitude),
                          zoom: 14,
                        ),
                      ),
                    );
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showLocationDetails(String id, String name, double lat, double lng) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Latitude: $lat'),
              Text('Longitude: $lng'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

    void _handleTap(LatLng tappedPoint) {
    for (var circle in _circles) {
      double distance = Geolocator.distanceBetween(
        circle.center.latitude,
        circle.center.longitude,
        tappedPoint.latitude,
        tappedPoint.longitude,
      );

      if (distance <= circle.radius) {
        _showMarkedPlaceDetails(circle);
        break;
      }
    }
  }

  void _showMarkedPlaceDetails(Circle circle) {
  String? placeName = _circleNames[circle.circleId];
  //double radius = circle.radius;
  _radius = circle.radius;
  Color color = circle.fillColor;

  // Use a new TextEditingController for name editing
  //TextEditingController placeNameController = TextEditingController(text: placeName);

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Marked Place Details'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _placeNameController,
                    decoration: InputDecoration(labelText: 'Place Name'),
                  ),
                  SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Radius (meters):'),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(
                          '${_radius.round()} m',
                          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                        ),
                      ),
                      Slider(
                        value: _radius,
                        min: 10,
                        max: 1000,
                        divisions: 99,
                        label: _radius.round().toString(),
                        onChanged: (value) {
                          setState(() {
                            _radius = value; // Update radius using setState from StatefulBuilder
                          });
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Color:'),
                      IconButton(
                        icon: Icon(Icons.color_lens, color: _selectedColor),
                        onPressed: () {
                          _selectColor();
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  await _saveMarkedPlace(
                    circle.center.latitude,
                    circle.center.longitude,
                    circle.circleId.value, // Pass the circle ID for updating
                  );
                  Navigator.of(context).pop();
                },
                child: Text('Save Changes'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _deleteMarkedPlace(circle.circleId.value);
                  Navigator.of(context).pop();
                },
                child: Text('Delete Place'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Close'),
              ),
            ],
          );
        },
      );
    },
  );
}


Future<void> _deleteMarkedPlace(String placeId) async {
  User? currentUser = _auth.currentUser;
  if (currentUser == null) {
    return;
  }

  try {
    await _firestore
        .collection('parents')
        .doc(currentUser.uid)
        .collection('markedPlaces')
        .doc(placeId)
        .delete();

    setState(() {
      _circles.removeWhere((circle) => circle.circleId.value == placeId);
      _circleNames.removeWhere((key, value) => key.value == placeId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Marked place deleted successfully!')),
    );
  } catch (e) {
    print('Error deleting marked place: $e');
  }
}

void _selectColors(BuildContext context, ValueChanged<Color> onColorChanged) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Select Color'),
        content: BlockPicker(
          pickerColor: _selectedColor,
          onColorChanged: (color) {
            onColorChanged(color);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('OK'),
          ),
        ],
      );
    },
  );
}


}