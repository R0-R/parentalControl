import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
//import 'package:parental_control/service/notification_servide.dart'; // Import notification service
import 'package:parental_control/parent/main_screen.dart';

class SetTimeLimitScreen extends StatefulWidget {
  final String? childId;

  SetTimeLimitScreen({required this.childId});

  @override
  _SetTimeLimitScreenState createState() => _SetTimeLimitScreenState();
}

class _SetTimeLimitScreenState extends State<SetTimeLimitScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<String, int> _dailyLimits = {
    'Sunday': 0,
    'Monday': 0,
    'Tuesday': 0,
    'Wednesday': 0,
    'Thursday': 0,
    'Friday': 0,
    'Saturday': 0,
  };
  bool _isLoading = true;

  final Map<String, int> _timeLimits = {
    '0 min': 0,
    '15 min': 15,
    '30 min': 30,
    '45 min': 45,
    '1 hr': 60,
    '1 hr 15 min': 75,
    '1 hr 30 min': 90,
    '1 hr 45 min': 105,
    '2 hr': 120,
    '2 hr 15 min': 135,
    '2 hr 30 min': 150,
    '2 hr 45 min': 165,
    '3 hr': 180,
  };

  @override
  void initState() {
    super.initState();
    _loadTimeLimits();
  }

  Future<void> _loadTimeLimits() async {
    if (widget.childId == null) {
      print("Child ID is null");
      return;
    }
    try {
      DocumentSnapshot childDoc = await _firestore
          .collection('parents')
          .doc(_auth.currentUser!.uid)
          .collection('children')
          .doc(widget.childId)
          .get();

      if (childDoc.exists) {
        setState(() {
          _dailyLimits = Map<String, int>.from(childDoc['usageLimit'] ?? {});
        });
      }
    } catch (e) {
      print("Error loading time limits: $e");
    } finally {
      setState(() {
        _isLoading = false; // Ensure loading indicator is turned off
      });
    }
  }

  Future<void> _saveTimeLimits() async {
  if (_auth.currentUser == null || widget.childId == null) return;

  await _firestore
      .collection('parents')
      .doc(_auth.currentUser!.uid)
      .collection('children')
      .doc(widget.childId)
      .set(
    {
      'usageLimit': {
        'dailyUsageLimits': _dailyLimits,
        'lastUsageUpdate': Timestamp.now(), // Current timestamp
      },
    },
    SetOptions(merge: true),
  );
}


  void _startMonitoring() {
    // Call this method to start monitoring usage limits and send notifications
    // Implement usage monitoring logic here
    //NotificationService().scheduleUsageLimitNotifications(_dailyLimits);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Set Time Limit'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: _dailyLimits.keys.map((day) {
                return ListTile(
                  title: Text(day),
                  trailing: DropdownButton<int>(
                    value: _dailyLimits[day],
                    items: _timeLimits.entries.map((entry) {
                      return DropdownMenuItem<int>(
                        value: entry.value,
                        child: Text(entry.key),
                      );
                    }).toList(),
                    onChanged: (int? value) {
                      setState(() {
                        _dailyLimits[day] = value ?? 0;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _saveTimeLimits();
          _startMonitoring(); // Start monitoring after saving
           Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ParentMainScreen(), // Replace with your dashboard screen
            ),
          );
        },
        child: Icon(Icons.save),
      ),
    );
  }
}