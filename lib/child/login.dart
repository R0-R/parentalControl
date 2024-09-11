import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parental_control/child/cnt.dart';
import 'mainScreen.dart'; // Import the ChildDashboardScreen

class ChildLoginScreen extends StatefulWidget {
  @override
  _ChildLoginScreenState createState() => _ChildLoginScreenState();
}

class _ChildLoginScreenState extends State<ChildLoginScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _childIDController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _errorMessage;
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    String childName = _nameController.text.trim();
    String childID = _childIDController.text.trim();

    if (childName.isEmpty || childID.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your name and child ID.';
        _isLoading = false;
      });
      return;
    }

    try {
      // Retrieve all parent documents
      QuerySnapshot parentSnapshot = await _firestore.collection('parents').get();

      bool childFound = false;
      String? parentID;

      for (var parentDoc in parentSnapshot.docs) {
        // Check the children subcollection for the matching child ID and name
        DocumentSnapshot childSnapshot = await parentDoc.reference
            .collection('children')
            .doc(childID)
            .get();

        if (childSnapshot.exists && childSnapshot['childrenName'] == childName) {
          childFound = true;
          parentID = parentDoc.id; // Store the parent ID for later use

          break;
        }
      }

      if (childFound) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Login successful!'),
        ));

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChildDashboardScreen(childName: childName, childID: childID, parentID: parentID!),
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Invalid name or child ID. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to log in. Please try again.';
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
        title: Text('Child Login'),
        backgroundColor: Colors.blue,
      ),
    backgroundColor: Colors.white,
      body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Image.asset(
                'assets/logo.png',
                height: 150,
              ),
              Text(
                'Welcome Back!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
            Text(
              'Enter your name and child ID to log in:',
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
            TextField(
              controller: _childIDController,
              decoration: InputDecoration(
                labelText: 'Enter Child ID',
                errorText: _errorMessage,
              ),
            ),
            SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ChildDeviceConnectionScreen()),
                  );
                },
                child: Text('Does not link to parent?'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue, textStyle: TextStyle(fontSize: 16),
                ),
              ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _login,
              child: _isLoading
                  ? CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    )
                  : Text('Login'),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
