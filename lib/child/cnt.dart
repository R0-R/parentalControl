import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'mainScreen.dart'; // Import the ChildDashboardScreen

class ChildDeviceConnectionScreen extends StatefulWidget {
  @override
  _ChildDeviceConnectionScreenState createState() => _ChildDeviceConnectionScreenState();
}

class _ChildDeviceConnectionScreenState extends State<ChildDeviceConnectionScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedAge;
  String? _errorMessage;
  bool _isLoading = false;

  Future<void> _connectDevice() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    String code = _codeController.text.trim();
    String childName = _nameController.text.trim();
    User? currentUser = _auth.currentUser;

    if (currentUser == null || code.isEmpty || childName.isEmpty || _selectedAge == null) {
      setState(() {
        _errorMessage = 'Please enter a valid code, name, and select age.';
        _isLoading = false;
      });
      return;
    }

    try {
      DocumentSnapshot deviceSnapshot = await _firestore
          .collection('parents')
          .doc(currentUser.uid)
          .collection('children')
          .doc(code)
          .get();

      if (deviceSnapshot.exists) {
        await _firestore
            .collection('parents')
            .doc(currentUser.uid)
            .collection('children')
            .doc(code)
            .update({
          'childrenName': childName,
          'childAge': _selectedAge
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Device connected successfully!'),
        ));

        setState(() {
          _codeController.clear();
          _nameController.clear();
          _selectedAge = null;
        });

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChildDashboardScreen(childName: childName, childID: code, parentID: currentUser.uid),
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Invalid code or device already connected';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to connect the device. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Connect to Parent Device'),
        backgroundColor: Colors.blue,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the code provided by your parent to connect this device:',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Enter Your Name',
                errorText: _errorMessage,
              ),
            ),
            SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedAge,
              decoration: InputDecoration(
                labelText: 'Select Age',
                errorText: _errorMessage,
              ),
              items: List.generate(12, (index) {
                String age = (index + 1).toString();
                return DropdownMenuItem<String>(
                  value: age,
                  child: Text(age),
                );
              }),
              onChanged: (value) {
                setState(() {
                  _selectedAge = value;
                });
              },
            ),
            SizedBox(height: 10),
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: 'Enter Code',
                errorText: _errorMessage,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _connectDevice,
              child: _isLoading
                  ? CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    )
                  : Text('Connect Device'),
            ),
          ],
        ),
      ),
    );
  }
}
