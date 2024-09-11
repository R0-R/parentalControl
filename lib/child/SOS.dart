import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SOSScreen extends StatefulWidget {
  final String childID;
  final String parentID;

  SOSScreen({required this.childID, required this.parentID});

  @override
  _SOSScreenState createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool SOS = false;

  void _sendSOS() async {
    try {
      // Get the current location from Firestore
      DocumentSnapshot childDoc = await _firestore
          .collection('parents')
          .doc(widget.parentID)
          .collection('children')
          .doc(widget.childID)
          .get();
      
      if (childDoc.exists) {
        GeoPoint? currentLocation = childDoc['locationData'] as GeoPoint?;

        if (currentLocation != null) {
          await _firestore
              .collection('parents')
              .doc(widget.parentID)
              .collection('children')
              .doc(widget.childID)
              .update({
            'sosData': {
              'isSOSActive': true,
              'sosTimestamp': Timestamp.now(),
              'sosLocation': currentLocation,
            },
          });

          setState(() {
            SOS = true;
          });
        } else {
          print('No location data available');
        }
      }
    } catch (e) {
      // Handle the error
      print(e);
    }
  }

  void _stopSOS() async {
    try {
      await _firestore
          .collection('parents')
          .doc(widget.parentID)
          .collection('children')
          .doc(widget.childID)
          .update({'sosData.isSOSActive': false});

      setState(() {
        SOS = false;
      });
    } catch (e) {
      // Handle the error
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SOS'),
        backgroundColor: Colors.red,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SOS
                ? Text(
                    'SOS Active!',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : Text(
                    'Send SOS',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
            SizedBox(height: 20),
            Container(
              width: 400,  // Button width
              height: 400, // Button height
              child: ElevatedButton(
                onPressed: SOS ? _stopSOS : _sendSOS,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: CircleBorder(),
                  padding: EdgeInsets.all(20), // Button padding to control the size
                ),
                child: Icon(
                  SOS ? Icons.stop : Icons.sos,
                  size: 200, // Icon size
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
