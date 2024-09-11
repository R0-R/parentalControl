import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationScreen extends StatefulWidget {
  final String parentID;

  NotificationScreen({required this.parentID});

  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Stream<List<Map<String, dynamic>>>? _notificationsStream;

  @override
  void initState() {
    super.initState();
    _notificationsStream = _firestore
        .collection('parents')
        .doc(widget.parentID)
        .collection('geofenceNotifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList());
  }

  Future<void> _approveReward(String childID, String requestID, int timeReward) async {
    try {
      await _firestore
          .collection('parents')
          .doc(widget.parentID)
          .collection('children')
          .doc(childID)
          .collection('rewardRequests')
          .doc(requestID)
          .update({'isApproved': true});

      DocumentSnapshot childDoc = await _firestore
          .collection('parents')
          .doc(widget.parentID)
          .collection('children')
          .doc(childID)
          .get();

      if (childDoc.exists) {
        Map<String, dynamic> usageLimits = childDoc['usageLimit'] as Map<String, dynamic>;
        int remainingTime = usageLimits['remainingTime'] as int? ?? 0;
        remainingTime += timeReward;

        await _firestore
            .collection('parents')
            .doc(widget.parentID)
            .collection('children')
            .doc(childID)
            .update({'usageLimit.remainingTime': remainingTime});
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reward approved successfully.')),
      );
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve reward.')),
      );
    }
  }

  Future<void> _rejectReward(String childID, String requestID) async {
    try {
      await _firestore
          .collection('parents')
          .doc(widget.parentID)
          .collection('children')
          .doc(childID)
          .collection('rewardRequests')
          .doc(requestID)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reward request rejected.')),
      );
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reject reward.')),
      );
    }
  }

  Future<void> _deleteSOSNotification(String childID) async {
    try {
      await _firestore
          .collection('parents')
          .doc(widget.parentID)
          .collection('children')
          .doc(childID)
          .update({'sosData': FieldValue.delete()});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('SOS notification deleted.')),
      );
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete SOS notification.')),
      );
    }
  }

  Future<void> _deleteGeofenceNotification(String notificationID) async {
    try {
      await _firestore
          .collection('parents')
          .doc(widget.parentID)
          .collection('geofenceNotifications')
          .doc(notificationID)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Geofence notification deleted.')),
      );
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete geofence notification.')),
      );
    }
  }

  Widget _buildSOSNotification(String childID, String childName) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore
          .collection('parents')
          .doc(widget.parentID)
          .collection('children')
          .doc(childID)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox.shrink(); // No data yet, return an empty widget
        }

        var childData = snapshot.data!.data() as Map<String, dynamic>?;

        if (childData == null) {
          return SizedBox.shrink(); // No data in the document
        }

        var sosData = childData['sosData'] as Map<String, dynamic>?;

        if (sosData == null) {
          return SizedBox.shrink(); // No SOS data in the document
        }

        bool isSOSActive = sosData['isSOSActive'] ?? false;
        Timestamp? sosTimestamp = sosData['sosTimestamp'] as Timestamp?;
        GeoPoint? sosLocation = sosData['sosLocation'] as GeoPoint?;

        String sosStatus = isSOSActive ? 'Sending SOS' : 'Stopped SOS';
        String locationText = sosLocation != null ? 'Lat: ${sosLocation.latitude}, Lon: ${sosLocation.longitude}' : 'No location data';
        String timestampText = sosTimestamp != null ? sosTimestamp.toDate().toLocal().toString() : '';

        return Dismissible(
          key: Key('sos-${childID}'),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) {
            _deleteSOSNotification(childID);
          },
          background: Container(
            color: Colors.red,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Icon(Icons.delete, color: Colors.white),
              ),
            ),
          ),
          child: Card(
            margin: EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              contentPadding: EdgeInsets.all(12),
              title: Text('$childName: $sosStatus'),
              subtitle: Text('Location: $locationText\nTimestamp: $timestampText'),
              tileColor: isSOSActive ? Colors.red.shade100 : Colors.grey.shade100,
            ),
          ),
        );
      },
    );
  }

  Widget _buildRewardRequests(String childID, String childName) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('parents')
          .doc(widget.parentID)
          .collection('children')
          .doc(childID)
          .collection('rewardRequests')
          .where('isApproved', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        List<QueryDocumentSnapshot> requestDocs = snapshot.data!.docs;

        if (requestDocs.isEmpty) {
          return ListTile(
            title: Text(''),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Text(
                'Reward Requests for $childName',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ...requestDocs.map((doc) {
              String requestID = doc.id;
              String taskName = doc['taskName'];
              String taskDescription = doc['taskDescription'] ?? '';
              int timeReward = doc['timeReward'];

              return Dismissible(
                key: Key('reward-${requestID}'),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) {
                  _rejectReward(childID, requestID);
                },
                background: Container(
                  color: Colors.red,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Icon(Icons.delete, color: Colors.white),
                    ),
                  ),
                ),
                child: Card(
                  margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: ListTile(
                    contentPadding: EdgeInsets.all(12),
                    title: Text(taskName),
                    subtitle: Text('$taskDescription\nReward: $timeReward minutes'),
                    trailing: IconButton(
                      icon: Icon(Icons.check, color: Colors.green),
                      onPressed: () => _approveReward(childID, requestID, timeReward),
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildGeofenceNotifications() {
  return StreamBuilder<List<Map<String, dynamic>>>(
    stream: _notificationsStream,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return Center(child: CircularProgressIndicator());
      }

      List<Map<String, dynamic>> notifications = snapshot.data!;

      if (notifications.isEmpty) {
        return Center(child: Text(''));
      }

      return Column(
        children: notifications.map((notification) {
          // Handle potential null or wrong type for notificationID
          String notificationID = notification['notificationID'] as String? ?? 'Unknown ID';

          // Handle potential null or wrong type for message
          String message = notification['message'] as String? ?? 'No message';

          // Safely handle Timestamp type
          Timestamp? timestamp = notification['timestamp'] as Timestamp?;
          String formattedTime = timestamp != null
              ? timestamp.toDate().toLocal().toString()
              : 'No timestamp';

          return Dismissible(
            key: Key('geofence-${notificationID}'),
            direction: DismissDirection.endToStart,
            onDismissed: (direction) {
              _deleteGeofenceNotification(notificationID);
            },
            background: Container(
              color: Colors.red,
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Icon(Icons.delete, color: Colors.white),
                ),
              ),
            ),
            child: Card(
              margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ListTile(
                contentPadding: EdgeInsets.all(12),
                title: Text(message),
                subtitle: Text('Timestamp: $formattedTime'),
              ),
            ),
          );
        }).toList(),
      );
    },
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('parents')
            .doc(widget.parentID)
            .collection('children')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          List<QueryDocumentSnapshot> childrenDocs = snapshot.data!.docs;

          return ListView(
            children: [
              ...childrenDocs.map((doc) {
                String childID = doc.id;
                String childName = doc['childrenName'] ?? 'Unknown';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSOSNotification(childID, childName),
                    _buildRewardRequests(childID, childName),
                  ],
                );
              }).toList(),
              _buildGeofenceNotifications(),
            ],
          );
        },
      ),
    );
  }
}
