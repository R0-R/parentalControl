import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parental_control/parent/main_screen.dart';

class ContentFilteringScreen extends StatefulWidget {
  final String? childId;

  ContentFilteringScreen({this.childId});

  @override
  _ContentFilteringScreenState createState() => _ContentFilteringScreenState();
}

class _ContentFilteringScreenState extends State<ContentFilteringScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool applyFiltering = true;
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

  @override
  void initState() {
    super.initState();
    print('Child ID: ${widget.childId}');
    _loadContentFilteringData();
  }

  Future<void> _loadContentFilteringData() async {
    if (widget.childId != null) {
      try {
        DocumentSnapshot childDoc = await _firestore
            .collection('parents')
            .doc(_auth.currentUser!.uid)
            .collection('children')
            .doc(widget.childId)
            .get();

        if (childDoc.exists) {
          Map<String, dynamic>? data =
              childDoc.data() as Map<String, dynamic>?;

          if (data != null && data.containsKey('contentFiltering')) {
            setState(() {
              applyFiltering = data['contentFiltering']['applyFiltering'] ?? true;
              categories = Map<String, bool>.from(data['contentFiltering']['categories'] ?? categories);
            });
          }
        }
      } catch (e) {
        print('Error loading content filtering data: $e');
      }
    }
  }

  Future<void> _saveContentFilteringData() async {
    if (widget.childId != null) {
      try {
        await _firestore
            .collection('parents')
            .doc(_auth.currentUser!.uid)
            .collection('children')
            .doc(widget.childId)
            .update({
          'contentFiltering': {
            'applyFiltering': applyFiltering,
            'categories': categories,
          },
        });
        print('Content filtering data updated successfully.');

        await _updateNextDNSSettings();
      } catch (e) {
        print('Error saving content filtering data: $e');
      }
    } else {
      print('No childId provided.');
    }
  }

  Future<void> _updateNextDNSSettings() async {
  final profileId = '362d98';
  final url = Uri.parse('https://api.nextdns.io/profiles/$profileId/parentalcontrol');
  final headers = {
    'x-api-key': '318f29dd5d4cd5c24f380abb7a7d86f4ccef6e48',
    'Content-Type': 'application/json',
  };

  final body = jsonEncode({
    'safeSearch': false,
    'youtubeRestrictedMode': false,
    'blockBypass': false, // Block bypass if filtering is applied
    'services': [
      {'id': 'tiktok', 'active': categories['TikTok'] ?? false},
      {'id': 'facebook', 'active': categories['Facebook'] ?? false},
      {'id': 'youtube', 'active': categories['YouTube'] ?? false},
      {'id': 'whatsapp', 'active': categories['WhatsApp'] ?? false},
    ],
    'categories': [
      {'id': 'porn', 'active': categories['Porn'] ?? false},
      {'id': 'social-networks', 'active': categories['Social Networks'] ?? false},
      {'id': 'gambling', 'active': categories['Gambling'] ?? false},
      {'id': 'gaming', 'active': categories['Online Gaming'] ?? false},
      {'id': 'video-streaming', 'active': categories['Video Streaming'] ?? false},
      {'id': 'dating', 'active': categories['Dating'] ?? false},
    ],
  });

  try {
    final response = await http.patch(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      print('NextDNS settings updated successfully.');
    } else {
      print('Failed to update NextDNS settings: ${response.statusCode}');
      print('Response body: ${response.body}');
    }
  } catch (e) {
    print('Error updating NextDNS settings: $e');
  }
}





  void _handleApplyFilteringChange(bool value) {
    setState(() {
      applyFiltering = value;
      if (!applyFiltering) {
        categories.updateAll((key, _) => false); // Set all categories to false
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Content Filtering'),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.0),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Apply Filtering',
                    style: TextStyle(fontSize: 18),
                  ),
                  Switch(
                    value: applyFiltering,
                    onChanged: (bool value) {
                      _handleApplyFilteringChange(value);
                    },
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Enable it to help filter the content on websites that your children access through.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              SizedBox(height: 16),
            ],
          ),
          Divider(),
          ...categories.keys.map((category) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  category,
                  style: TextStyle(fontSize: 16),
                ),
                Switch(
                  value: categories[category] ?? false,
                  onChanged: applyFiltering
                      ? (bool value) {
                          setState(() {
                            categories[category] = value;
                          });
                        }
                      : null, // Disable switch if filtering is off
                ),
              ],
            );
          }).toList(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _saveContentFilteringData();
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
