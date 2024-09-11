import 'package:app_usage/app_usage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:parental_control/child/SOS.dart';
import 'package:parental_control/child/profile.dart';
import 'package:parental_control/child/reward.dart';

class ChildDashboardScreen extends StatefulWidget {
  final String childName;
  final String childID;
  final String parentID;

  ChildDashboardScreen({
    required this.childName,
    required this.childID,
    required this.parentID,
  });

  @override
  _ChildDashboardScreenState createState() => _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends State<ChildDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic> _appUsage = {};
  Map<String, dynamic> _usageLimit = {};
  int _timeLimitForToday = 0;
  int _remainingTimeForToday = 0;

  @override
  void initState() {
    super.initState();
    _loadChildData();
    _loadAppUsageData();
    _startLocationTracking(); // Start location updates
  }

  // Function to determine the current position
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

    return await Geolocator.getCurrentPosition();
  }

  // Function to update location data to Firestore
  Future<void> _updateLocation(Position position) async {
    try {
      await _firestore
          .collection('parents')
          .doc(widget.parentID)
          .collection('children')
          .doc(widget.childID)
          .update({
        'locationData': GeoPoint(position.latitude, position.longitude),
      });

      print(
          'Successfully updated location in Firestore: Latitude ${position.latitude}, Longitude ${position.longitude}');
    } catch (e) {
      print('Error updating location in Firestore: $e');

      // Optionally implement a retry mechanism
      print('Retrying Firestore update in 5 seconds...');
      await Future.delayed(Duration(seconds: 5));
      _updateLocation(position); // Retry once after delay
    }
  }

  // Function to start location updates
  void _startLocationTracking() async {
    try {
      await _determinePosition();
      Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 100,
        ),
      ).listen((Position position) {
        print(
            'Received location update: Latitude ${position.latitude}, Longitude ${position.longitude}');
        _updateLocation(position);
        _handleGeofence(position); // Check geofence status
      });
    } catch (e) {
      print('Error starting location tracking: $e');
      _promptForGPS(context);
    }
  }

  // Function to handle geofence entry/exit
  Future<void> _handleGeofence(Position position) async {
    final parentDocRef = _firestore
        .collection('parents')
        .doc(widget.parentID)
        .collection('children')
        .doc(widget.childID);

    // Fetch marked places
    final markedPlaces = await _fetchMarkedPlaces();

    bool isInsideGeofence = false;

    for (var place in markedPlaces) {
      final locationData = place['locationData'];
      final radius = place['radius']?.toDouble(); // Ensure radius is a double

      if (locationData is GeoPoint && radius != null) {
        final GeoPoint center = locationData;

        if (_isInsideGeofence(position, center, radius)) {
          isInsideGeofence = true;
          break;
        }
      }
    }

    // Fetch child's document and set default value for 'insideGeofence' if needed
    final childDoc = await parentDocRef.get();

    // Check if the document exists and if 'insideGeofence' is set, otherwise initialize it
    bool currentlyInsideGeofence = false;
    final childData = childDoc.data();
    if (childDoc.exists &&
        childData != null &&
        childData.containsKey('insideGeofence')) {
      currentlyInsideGeofence = childData['insideGeofence'];
    } else {
      // Initialize the field if it doesn't exist
      await parentDocRef.update({'insideGeofence': false});
    }

    // Check for geofence status changes
    if (isInsideGeofence && !currentlyInsideGeofence) {
      // Child entered a geofence
      await parentDocRef.update({'insideGeofence': true});
      _sendNotification('Child entered geofence');
    } else if (!isInsideGeofence && currentlyInsideGeofence) {
      // Child left a geofence
      await parentDocRef.update({'insideGeofence': false});
      _sendNotification('Child left geofence');
    }
  }

// Function to check if the position is inside a geofence
  bool _isInsideGeofence(Position position, GeoPoint center, double radius) {
    double distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      center.latitude,
      center.longitude,
    );
    return distance <= radius;
  }

// Function to fetch marked places from Firestore
  Future<List<Map<String, dynamic>>> _fetchMarkedPlaces() async {
    try {
      final snapshot = await _firestore
          .collection('parents')
          .doc(widget.parentID)
          .collection('markedPlaces')
          .get();

      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('Error fetching marked places: $e');
      return [];
    }
  }

  // Function to load child data
  Future<void> _loadChildData() async {
    try {
      DocumentSnapshot childDoc = await _firestore
          .collection('parents')
          .doc(widget.parentID)
          .collection('children')
          .doc(widget.childID)
          .get();

      if (childDoc.exists) {
        final data = childDoc.data() as Map<String, dynamic>?;

        // Handling usageLimit and other fields
        final usageLimit = data?['usageLimit'] as Map<String, dynamic>?;
        final dailyUsageLimits =
            usageLimit?['dailyUsageLimits'] as Map<String, dynamic>?;
        String dayOfWeek = DateFormat('EEEE').format(DateTime.now());
        _timeLimitForToday = dailyUsageLimits?[dayOfWeek] as int? ?? 0;
        _remainingTimeForToday =
            data?['remainingTimeForToday'] as int? ?? _timeLimitForToday;

        // Handling locationData
        final location = data?['locationData'] as GeoPoint?;
        if (location != null) {
          print(
              'Location: Latitude ${location.latitude}, Longitude ${location.longitude}');
          // Update UI or state with location data if needed
        } else {
          print('No location data available');
        }

        setState(() {});
      } else {
        print('Child document does not exist');
      }
    } catch (e) {
      print('Error loading child data: $e');
    }
  }

  Future<void> _loadAppUsageData() async {
    try {
      DocumentSnapshot childDoc = await _firestore
          .collection('parents')
          .doc(widget.parentID)
          .collection('children')
          .doc(widget.childID)
          .get();

      if (childDoc.exists) {
        final data = childDoc.data() as Map<String, dynamic>?;

        // Fetch app usage data
        final appUsage = data?['appUsage'] as Map<String, dynamic>?;

        setState(() {
          _appUsage = appUsage ?? {};
        });
      } else {
        print('Child document does not exist');
      }
    } catch (e) {
      print('Error loading app usage data: $e');
    }
  }

  // Function to refresh child data
  Future<void> _refreshData() async {
    await _loadChildData();
  }

  // Function to prompt the user to enable GPS if it is disabled
  void _promptForGPS(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enable GPS'),
          content:
              Text('GPS is disabled. Please enable GPS to continue tracking.'),
          actions: <Widget>[
            TextButton(
              child: Text('Open Settings'),
              onPressed: () {
                Geolocator.openLocationSettings();
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Function to send a notification
  void _sendNotification(String message) async {
    try {
      // Write a new document to the 'geofenceNotifications' collection
      await _firestore
          .collection('parents')
          .doc(widget.parentID)
          .collection('geofenceNotifications')
          .add({
        'message': message,
        'timestamp': Timestamp.now(),
      });

      print('Notification sent: $message');
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // Navigation functions
  void _navigateToSOSScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              SOSScreen(childID: widget.childID, parentID: widget.parentID)),
    );
  }

  void _navigateToRewardScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RewardScreen(
          childID: widget.childID,
          parentID: widget.parentID,
        ),
      ),
    );
  }

  void _navigateToProfileScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => ChildProfileScreen(
              childID: widget.childID, parentID: widget.parentID)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Child Dashboard'),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.blue,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _refreshData();
          await _loadAppUsageData();
        },
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Text(
              "Welcome ${widget.childName}!",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            SizedBox(height: 20),
            Card(
              elevation: 4,
              margin: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _timeLimitForToday > 0
                          ? 'Time Limit for Today: ${_timeLimitForToday ~/ 60} hrs ${_timeLimitForToday % 60} mins'
                          : 'No Time Limit Set',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            // Add app usage section
            Card(
              elevation: 4,
              margin: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Usage',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    SizedBox(height: 10),
                    ..._appUsage.entries.map((entry) {
                      final appName = entry.key;
                      final timeSpent = entry.value as int;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Text(
                          '$appName: ${timeSpent ~/ 60} hrs ${timeSpent % 60} mins',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[800],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sos),
            label: 'SOS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star),
            label: 'Reward',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        onTap: (int index) {
          if (index == 0) {
            // Home screen logic (if needed)
          } else if (index == 1) {
            _navigateToSOSScreen();
          } else if (index == 2) {
            _navigateToRewardScreen();
          } else if (index == 3) {
            _navigateToProfileScreen();
          }
        },
      ),
    );
  }
}
