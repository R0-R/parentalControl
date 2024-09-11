import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parental_control/parent/forgetPw.dart';

class ParentProfileScreen extends StatefulWidget {
  @override
  _ParentProfileScreenState createState() => _ParentProfileScreenState();
}

class _ParentProfileScreenState extends State<ParentProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _currentUser;
  String? _username;
  String? _email;
  String? _uniqueCode;
  List<Map<String, dynamic>> _devices = [];

  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _currentPasswordError;
  String? _newPasswordError;
  String? _confirmPasswordError;

  StreamSubscription<QuerySnapshot>? _devicesListener;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _startDevicesListener();
  }

  @override
  void dispose() {
    _devicesListener?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    _currentUser = _auth.currentUser;

    if (_currentUser != null) {
      try {
        // Fetch user data from Firestore
        DocumentSnapshot userDoc = await _firestore.collection('parents').doc(_currentUser!.uid).get();
        
        if (userDoc.exists) {
          setState(() {
            _username = userDoc.get('username') ?? "Username";
            _email = userDoc.get('email') ?? "Email";
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User document does not exist.')));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading user data: $e')));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No user is currently logged in.')));
    }
  }


  void _startDevicesListener() {
    if (_currentUser != null) {
      _devicesListener = FirebaseFirestore.instance
        .collection('parents')
        .doc(_currentUser!.uid)
        .collection('children')
        .snapshots()
        .listen((snapshot) {
          setState(() {
            _devices = snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final childID = doc.id;
              return {
                'childID': childID,
                'childrenName': data['childrenName'] ?? 'Unnamed Device',
              };
            }).toList();
          });
        });
    }
  }

  String _generateUniqueCode() {
    final random = Random();
    final code = random.nextInt(9000) + 1000;
    return code.toString();
  }

  Future<void> _addDevice() async {
    _uniqueCode = _generateUniqueCode();
    Map<String, int> _dailyLimits = {
    'Monday': 0,
    'Tuesday': 0,
    'Wednesday': 0,
    'Thursday': 0,
    'Friday': 0,
    'Saturday': 0,
    'Sunday': 0,
  };
    Map<String, bool> categories = {
        "Social Networks": true,
        "Online Gaming": true,
        "Video Streaming": true,
        "Porn": true,
        "Gambling": true,
        "Dating": true,
        "TikTok": true,
        "Facebook": true,
        "WhatsApp": true,
        "YouTube": true,
      };
    if (_currentUser != null) {
      await _firestore.collection('parents')
          .doc(_currentUser!.uid)
          .collection('children')
          .doc(_uniqueCode!)
          .set({
        'childrenName': '',
        'childAge':0,
        //'dailyUsageLimits': _dailyLimits,
        'usageLimit': {
          'dailyUsageLimits': _dailyLimits,
          'appUsage': {},
          'remainingTime': 0,
          'lastUsageUpdate': Timestamp.now(),
          'lock': false
        },
        'contentFiltering': {
          'applyFiltering': true,
          'categories': categories
        },
        'locationData': GeoPoint(0, 0),

      });

      setState(() {});
      _listenForDeviceConnection();
      _showAddDeviceDialog();
    }
  }

  Future<void> _removeDevice(String childID) async {
    if (childID.isNotEmpty) {
      try {
        await _firestore.collection('parents')
            .doc(_currentUser!.uid)
            .collection('children')
            .doc(childID)
            .delete();
        setState(() {
          _devices.removeWhere((device) => device['childID'] == childID);
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Device removed successfully')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: Failed to remove device')));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: Device ID is null')));
    }
  }

  void _listenForDeviceConnection() {
    if (_currentUser != null && _uniqueCode != null) {
      FirebaseFirestore.instance.collection('parents')
          .doc(_currentUser!.uid)
          .collection('children')
          .doc(_uniqueCode!)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && snapshot.data()?['linked'] == true) {
          setState(() {
            _uniqueCode = null; 
            _loadUserData(); 
          });
        }
      });
    }
  }

  void _validatePassword(String value) {
    setState(() {
      if (value.isEmpty) {
        _newPasswordError = 'Please enter your password';
      } else if (value.length < 6) {
        _newPasswordError = 'Password must be at least 6 characters long';
      } else {
        _newPasswordError = null;
      }
    });
  }

  Future<void> _changePassword() async {
    setState(() {
      _isLoading = true;
      _currentPasswordError = null;
      _newPasswordError = null;
      _confirmPasswordError = null;
    });

    try {
      User? user = _auth.currentUser;
      String email = user?.email ?? '';

      AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: _currentPasswordController.text,
      );

      await user?.reauthenticateWithCredential(credential);
      if (_newPasswordController.text == _confirmPasswordController.text) {
        await user?.updatePassword(_newPasswordController.text);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ForgotPasswordScreen()),
        );
      } else {
        setState(() {
          _confirmPasswordError = 'Passwords do not match';
        });
      }
    } catch (e) {
      setState(() {
        _currentPasswordError = 'Failed to change password';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showAddDeviceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Add Device"),
          content: Text("Your unique code is: $_uniqueCode"),
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

  void _showEditPasswordDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _currentPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    errorText: _currentPasswordError,
                  ),
                  obscureText: true,
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _newPasswordController,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    errorText: _newPasswordError,
                  ),
                  obscureText: true,
                  onChanged: _validatePassword,
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    errorText: _confirmPasswordError,
                  ),
                  obscureText: true,
                ),
                SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ForgotPasswordScreen()),
                    );
                  },
                  child: Text('Forgot Password?'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _changePassword();
              },
              child: _isLoading
                  ? CircularProgressIndicator()
                  : Text('Change Password'),
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
        title: Text('Parent Profile'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(
              'Username: $_username',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 10),
            Text(
              'Email: $_email',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _showEditPasswordDialog,
              child: Text('Edit Password'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _addDevice,
              child: Text('Add Device'),
            ),
            SizedBox(height: 20),
            Text(
              'Connected Devices:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            _devices.isNotEmpty
                ? Column(
                    children: _devices.map((device) {
                      return ListTile(
                        title: Text('${device['childrenName']}'),
                        subtitle: Text('ID: ${device['childID']}'),
                        trailing: IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () => _removeDevice(device['childID']),
                        ),
                      );
                    }).toList(),
                  )
                : Text('No devices connected'),
          ],
        ),
      ),
    );
  }
}