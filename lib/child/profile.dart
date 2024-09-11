import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChildProfileScreen extends StatefulWidget {
  final String childID;
  final String parentID;

  ChildProfileScreen({required this.childID, required this.parentID});

  @override
  _ChildProfileScreenState createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  TextEditingController _ageController = TextEditingController();
  bool _isLoading = false;

  Future<Map<String, dynamic>> _getChildData() async {
    DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('parents')
        .doc(widget.parentID)
        .collection('children')
        .doc(widget.childID)
        .get();

    if (snapshot.exists) {
      return snapshot.data()!;
    } else {
      throw Exception('Child data not found');
    }
  }

  Future<void> _updateAge() async {
    setState(() {
      _isLoading = true;
    });

    try {
      int age = int.parse(_ageController.text);

      await _firestore
          .collection('parents')
          .doc(widget.parentID)
          .collection('children')
          .doc(widget.childID)
          .update({
        'childAge': age, // Store age as an int
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Age updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update age. Please try again.')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Child Profile'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getChildData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No data available'));
          }

          Map<String, dynamic> childData = snapshot.data!;
          String childName = childData['childrenName'];
          int childAge = childData['childAge'] is int
              ? childData['childAge'] as int
              : int.parse(childData['childAge'] as String); // Handle type conversion

          _ageController.text = childAge.toString();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Name: $childName',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  'ID: ${widget.childID}',
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 10),
                Text(
                  'Age:',
                  style: TextStyle(fontSize: 18),
                ),
                TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter your age',
                  ),
                ),
                SizedBox(height: 20),
                _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _updateAge,
                        child: Text('Save Changes'),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}
