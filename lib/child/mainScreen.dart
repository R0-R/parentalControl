import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:usage_stats/usage_stats.dart'; // Ensure this package is added to pubspec.yaml

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
  Map<String, dynamic> _usageLimit = {};
  int _timeLimitForToday = 0;
  int _remainingTimeForToday = 0;
  List<AppUsageInfo> _appUsageList = [];

  @override
  void initState() {
    super.initState();
    _loadChildData();
    _startLocationTracking(); // Start location updates
    _startAppUsageTracking(); // Start tracking app usage periodically
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

        print('Successfully updated location in Firestore: Latitude ${position.latitude}, Longitude ${position.longitude}');
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
          print('Received location update: Latitude ${position.latitude}, Longitude ${position.longitude}');
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
  if (childDoc.exists && childData != null && childData.containsKey('insideGeofence')) {
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
    
    return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  } catch (e) {
    print('Error fetching marked places: $e');
    return [];
  }
}

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
            content: Text('GPS is disabled. Please enable GPS to continue tracking.'),
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
    await _firestore.collection('parents')
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


  // Function to fetch app usage data
  Future<List<AppUsageInfo>> _fetchAppUsage() async {
    List<AppUsageInfo> usageInfoList = [];
    try {
      DateTime endDate = DateTime.now();
      DateTime startDate = endDate.subtract(Duration(hours: 24));

      // Request usage stats (requires permission)
      List<UsageInfo> usageStats = await UsageStats.queryUsageStats(startDate, endDate);

      for (UsageInfo info in usageStats) {
        if (info.packageName != null && info.totalTimeInForeground != null) {
          usageInfoList.add(
            AppUsageInfo(
              appName: info.packageName!,
              usage: (int.parse(info.totalTimeInForeground!) / 1000 / 60).round(), // convert to minutes
              timestamp: DateTime.now(),
            ),
          );
        }
      }
    } catch (e) {
      print('Error fetching app usage: $e');
    }
    return usageInfoList;
  }

  // Function to store app usage data in Firestore
  Future<void> _storeAppUsage(List<AppUsageInfo> usageInfoList) async {
    try {
      for (var usageInfo in usageInfoList) {
        await _firestore
            .collection('parents')
            .doc(widget.parentID)
            .collection('children')
            .doc(widget.childID)
            .collection('appUsage')
            .add({
          'appName': usageInfo.appName,
          'usageMinutes': usageInfo.usage,
          'timestamp': Timestamp.fromDate(usageInfo.timestamp),
        });
      }

      print('App usage data stored in Firestore');
    } catch (e) {
      print('Error storing app usage in Firestore: $e');
    }
  }

  // Function to start periodic app usage tracking
  void _startAppUsageTracking() {
    Timer.periodic(Duration(hours: 1), (Timer timer) async {
      try {
        List<AppUsageInfo> usageInfoList = await _fetchAppUsage();
        await _storeAppUsage(usageInfoList); // Store the fetched data
      } catch (e) {
        print('Error in periodic app usage tracking: $e');
      }
    });
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
        final dailyUsageLimits = usageLimit?['dailyUsageLimits'] as Map<String, dynamic>?;
        String dayOfWeek = DateFormat('EEEE').format(DateTime.now());
        _timeLimitForToday = dailyUsageLimits?[dayOfWeek] as int? ?? 0;
        _remainingTimeForToday = data?['remainingTimeForToday'] as int? ?? _timeLimitForToday;

        // Trigger a UI update
        setState(() {});
      }
    } catch (e) {
      print('Error loading child data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Child Dashboard'),
      ),
      body: ListView(
        children: [
          _buildUsageCard(),
          _buildAppUsageCard(),
        ],
      ),
    );
  }

  Widget _buildUsageCard() {
    return Card(
      margin: EdgeInsets.all(16),
      child: ListTile(
        title: Text('Usage Limit for Today'),
        subtitle: Text('Time Limit: ${_timeLimitForToday} minutes'),
        trailing: Text('Remaining: ${_remainingTimeForToday} minutes'),
      ),
    );
  }

  Widget _buildAppUsageCard() {
    return Card(
      margin: EdgeInsets.all(16),
      child: Column(
        children: _appUsageList.map((appUsage) {
          return ListTile(
            title: Text(appUsage.appName),
            subtitle: Text('Usage: ${appUsage.usage} minutes'),
            trailing: Text(DateFormat('yyyy-MM-dd HH:mm').format(appUsage.timestamp)),
          );
        }).toList(),
      ),
    );
  }
}

class AppUsageInfo {
  final String appName;
  final int usage;
  final DateTime timestamp;

  AppUsageInfo({
    required this.appName,
    required this.usage,
    required this.timestamp,
  });
}
