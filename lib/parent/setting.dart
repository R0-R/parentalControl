import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parental_control/main.dart';

class SettingScreen extends StatefulWidget {
  @override
  _SettingScreenState createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _feedbackController = TextEditingController();

  StreamSubscription<DocumentSnapshot>? _deviceListener;

  @override
  void initState() {
    super.initState();
    _initializeListeners();
  }

  @override
  void dispose() {
    _stopDeviceListener();
    super.dispose();
  }

  void _initializeListeners() {
    if (_auth.currentUser != null) {
      _startDeviceListener();
    }
  }

  void _startDeviceListener() {
    String deviceId = 'your_device_id'; // Use a valid device ID

    _deviceListener = FirebaseFirestore.instance
      .collection('users')
      .doc(_auth.currentUser!.uid)
      .collection('devices')
      .doc(deviceId)
      .snapshots()
      .listen((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data();
          if (data != null && data['linked'] == true) {
            print('Device linked successfully');
          }
        }
      }, onError: (error) {
        print('Error listening to device: $error');
      });
  }

  void _stopDeviceListener() {
    if (_deviceListener != null) {
      _deviceListener!.cancel();
      print('Device listener stopped');
    }
    _deviceListener = null;
  }

  void _logout() async {
    _stopDeviceListener();
    try {
      await _auth.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => OnboardingScreen()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      print('Error during logout: $e');
      // Optionally, show an error message to the user
    }
  }

  void _showAboutUs() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("About Us"),
          content: Text("This is a remote parental control application for monitoring and managing children's online activities.",textAlign: TextAlign.justify),
          actions: [
            TextButton(
              child: Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _sendFeedback() async {
    String feedback = _feedbackController.text;

    if (feedback.isNotEmpty) {
      try {
        await _firestore.collection('feedback').add({
          'feedback': feedback,
          'userId': _auth.currentUser?.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });

        _feedbackController.clear();
        Navigator.of(context).pop();
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("Feedback"),
              content: Text("Thank you for your feedback!"),
              actions: [
                TextButton(
                  child: Text("OK"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      } catch (e) {
        print('Error sending feedback: $e');
        // Handle the error appropriately
      }
    }
  }

  void _openFeedbackDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Submit Feedback"),
          content: TextField(
            controller: _feedbackController,
            decoration: InputDecoration(
              hintText: "Enter your feedback",
            ),
            maxLines: 5,
          ),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Submit"),
              onPressed: _sendFeedback,
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.info),
            title: Text("About Us"),
            onTap: _showAboutUs,
          ),
          ListTile(
            leading: Icon(Icons.feedback),
            title: Text("Feedback"),
            onTap: _openFeedbackDialog,
          ),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text("Logout"),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}
