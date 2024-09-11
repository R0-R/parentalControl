import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For getting the day of the week
import 'package:parental_control/parent/filter.dart';
import 'package:parental_control/parent/location.dart';
import 'package:parental_control/parent/notification.dart';
import 'package:parental_control/parent/setting.dart';
import 'package:parental_control/parent/timeManagement.dart';
import './userProfile.dart';
//import './location.dart';

class ParentMainScreen extends StatefulWidget {
  @override
  _ParentMainScreenState createState() => _ParentMainScreenState();
}

class _ParentMainScreenState extends State<ParentMainScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  List<Map<String, dynamic>> _children = [];
  int currentIndex = 0;
  Map<String, int> _appUsage = {};

  int _timeLimitForToday = 0;
  int _remainingTimeForToday = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    _currentUser = _auth.currentUser;

    if (_currentUser != null) {
      DocumentSnapshot userDoc =
          await _firestore.collection('parents').doc(_currentUser!.uid).get();

      if (userDoc.exists) {
        QuerySnapshot childrenSnapshot = await _firestore
            .collection('parents')
            .doc(_currentUser!.uid)
            .collection('children')
            .get();

        setState(() {
          _children = childrenSnapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;

            return {
              'id': doc.id,
              'childrenName': data['childrenName'] ?? 'No Name',
              'usageLimit': Map<String, dynamic>.from(data['usageLimit'] ?? {}),
              'appUsage': Map<String, dynamic>.from(data['appUsage'] ?? {}),
            };
          }).toList();
        });

        if (_children.isNotEmpty) {
          _loadCurrentChildData(
            Map<String, dynamic>.from(_children[currentIndex]['usageLimit']),
            Map<String, dynamic>.from(_children[currentIndex]['appUsage']),
          );
        }
      }
    }
  }

  void _loadCurrentChildData(
    Map<String, dynamic> usageLimit,
    Map<String, dynamic> appUsage,
  ) {
    String dayOfWeek = DateFormat('EEEE')
        .format(DateTime.now()); // Get current day of the week

    setState(() {
      _timeLimitForToday = usageLimit['dailyUsageLimits'][dayOfWeek] ?? 0;
      _appUsage = Map<String, int>.from(appUsage.map((key, value) {
        return MapEntry(key, value as int); // Cast value to int
      }));
    });
  }

  Future<void> _refreshData() async {
    await _loadUserData();
  }

  void _navigateToProfileScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ParentProfileScreen()),
    );
  }

  void _navigateToSetTimeScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SetTimeLimitScreen(
            childId: _children.isNotEmpty
                ? _children[currentIndex]['id'] as String?
                : null),
      ),
    );
  }

  void _navigateToFilterScreen() {
    final childId =
        _children.isNotEmpty ? _children[currentIndex]['id'] as String? : null;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContentFilteringScreen(childId: childId),
      ),
    );
  }

  void _navigateToMapScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LocationScreen()),
    );
  }

  void _navigateToSettingScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SettingScreen()),
    );
  }

  void _navigateToNotificationScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              NotificationScreen(parentID: _currentUser!.uid)),
    );
  }

  void _onChildChanged(int index) {
    setState(() {
      currentIndex = index;
      _loadCurrentChildData(
          _children[index]['usageLimit'], _children[index]['appUsage']);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _navigateToSettingScreen,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: () {
                    if (currentIndex > 0) {
                      _onChildChanged(currentIndex - 1);
                    }
                  },
                ),
                UserIcon(
                    name: _children.isNotEmpty
                        ? _children[currentIndex]['childrenName'] ?? 'No Name'
                        : 'No Children'),
                IconButton(
                  icon: Icon(Icons.arrow_forward),
                  onPressed: () {
                    if (currentIndex < _children.length - 1) {
                      _onChildChanged(currentIndex + 1);
                    }
                  },
                ),
              ],
            ),
            SizedBox(height: 30),
            Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Card for Time Limit and Remaining Time
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
                            _children.isNotEmpty
                                ? 'Time Limit for Today: ${_timeLimitForToday ~/ 60} hrs ${_timeLimitForToday % 60} mins'
                                : 'No Child Data Available',
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
                            'App Usage:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                          SizedBox(height: 10),
                          ..._appUsage.entries.map((entry) {
                            final appName = entry.key;
                            final timeSpent = entry.value;
                            return Text(
                              '$appName: ${timeSpent ~/ 60} hrs ${timeSpent % 60} mins',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[800],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),

                  // Divider
                  Divider(
                    thickness: 1,
                    indent: 20,
                    endIndent: 20,
                    color: Colors.grey[300],
                  ),
                ],
              ),
            ),
            SizedBox(height: 60),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: _navigateToSetTimeScreen,
                  icon: Icon(Icons.access_time),
                  label: Text('Set Time'),
                ),
                ElevatedButton.icon(
                  onPressed: _navigateToFilterScreen,
                  icon: Icon(Icons.filter_list),
                  label: Text('Filter'),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 0,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on),
            label: 'Location',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: <Widget>[
                Icon(Icons.notifications),
                Positioned(
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: BoxConstraints(
                      minWidth: 12,
                      minHeight: 12,
                    ),
                  ),
                ),
              ],
            ),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        onTap: (int index) {
          if (index == 1) {
            _navigateToMapScreen();
          } else if (index == 2) {
            _navigateToNotificationScreen();
          } else if (index == 3) {
            _navigateToProfileScreen();
          }
        },
      ),
    );
  }
}

class UserIcon extends StatelessWidget {
  final String name;

  UserIcon({required this.name});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          child: Icon(Icons.person),
        ),
        SizedBox(height: 8),
        Text(name),
      ],
    );
  }
}
