import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RewardScreen extends StatefulWidget {
  final String childID;
  final String parentID;

  RewardScreen({
    required this.childID,
    required this.parentID,
  });

  @override
  _RewardScreenState createState() => _RewardScreenState();
}

Future<void> createRewardRequest({
  required String parentID,
  required String childID,
  required String taskName,
  required int timeReward,
  String? taskDescription,
}) async {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference rewardRequests = _firestore
      .collection('parents')
      .doc(parentID)
      .collection('children')
      .doc(childID)
      .collection('rewardRequests');

  DocumentReference rewardDoc = rewardRequests.doc();
  String rewardID = rewardDoc.id;

  Map<String, dynamic> rewardData = {
    'rewardID': rewardID,
    'taskName': taskName,
    'taskDescription': taskDescription ?? '',
    'timeReward': timeReward,
    'isApproved': false,
    'isRejected': false,
    'isClaimed': false,
    'requestDate': Timestamp.now(),
    'childID': childID,
    'parentID': parentID,
  };

  await rewardDoc.set(rewardData);
  print('Reward request created with ID: $rewardID');
}

class _RewardScreenState extends State<RewardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _approvedRewards = [];
  bool _hasRequestedToday = false;
  bool _hasClaimedToday = false;
  Map<String, bool> _taskCompletionStatus = {};

  List<Map<String, dynamic>> _availableTasks = [
    {
      'taskName': 'Reading book 1 hour',
      'timeReward': 30,
      'taskDescription': 'Completed reading a book for 1 hour',
    },
    {
      'taskName': 'Sporting 30 minutes',
      'timeReward': 10,
      'taskDescription': 'Completed 30 minutes of sporting activity',
    },
    {
      'taskName': 'Doing housework',
      'timeReward': 10,
      'taskDescription': 'Helped with housework',
    },
    {
      'taskName': 'Complete homeworks',
      'timeReward': 10,
      'taskDescription': 'Completed all homework',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadApprovedRewards();
    _checkTaskCompletionStatusForToday();
  }

  Future<void> _loadApprovedRewards() async {
    try {
      QuerySnapshot rewardDocs = await _firestore
          .collection('parents')
          .doc(widget.parentID)
          .collection('children')
          .doc(widget.childID)
          .collection('rewardRequests')
          .where('isApproved', isEqualTo: true)
          .get();

      setState(() {
        _approvedRewards = rewardDocs.docs.map((doc) {
          return doc.data() as Map<String, dynamic>;
        }).toList();
        _hasClaimedToday = _approvedRewards.any((reward) {
          return reward['isClaimed'] == true &&
              _isToday(reward['requestDate'].toDate());
        });
      });
    } catch (e) {
      print(e);
    }
  }

  Future<void> _checkTaskCompletionStatusForToday() async {
    DateTime today = DateTime.now();
    DateTime startOfDay = DateTime(today.year, today.month, today.day);
    DateTime endOfDay = startOfDay.add(Duration(days: 1));

    try {
      QuerySnapshot rewardDocs = await _firestore
          .collection('parents')
          .doc(widget.parentID)
          .collection('children')
          .doc(widget.childID)
          .collection('rewardRequests')
          .where('requestDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('requestDate', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      setState(() {
        for (var doc in rewardDocs.docs) {
          Map<String, dynamic> reward = doc.data() as Map<String, dynamic>;
          String taskName = reward['taskName'];
          _taskCompletionStatus[taskName] = true; // Mark task as completed today
        }
      });
    } catch (e) {
      print(e);
    }
  }

  Future<void> _requestReward(Map<String, dynamic> task) async {
    if (_taskCompletionStatus[task['taskName']] ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('This task has already been requested today.')),
      );
      return;
    }

    try {
      await createRewardRequest(
        parentID: widget.parentID,
        childID: widget.childID,
        taskName: task['taskName'],
        timeReward: task['timeReward'],
        taskDescription: task['taskDescription'],
      );

      setState(() {
        _taskCompletionStatus[task['taskName']] = true; // Mark task as completed today
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reward request sent to parent for approval.')),
      );
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send reward request.')),
      );
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rewards'),
      ),
      body: Column(
        children: [
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(text: 'Tasks'),
                      Tab(text: 'Rewards'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Tasks Tab
                        ListView.builder(
                          itemCount: _availableTasks.length,
                          itemBuilder: (context, index) {
                            final task = _availableTasks[index];
                            bool isCompleted = _taskCompletionStatus[task['taskName']] ?? false;

                            return ListTile(
                              title: Text(task['taskName']),
                              subtitle: Text('${task['timeReward']} minutes'),
                              trailing: ElevatedButton(
                                onPressed: isCompleted || _hasClaimedToday
                                    ? null
                                    : () => _requestReward(task),
                                child: Text(isCompleted ? 'Requested' : 'Mark as Done'),
                              ),
                            );
                          },
                        ),
                        // Rewards Tab
                        ListView.builder(
                          itemCount: _approvedRewards.length,
                          itemBuilder: (context, index) {
                            final reward = _approvedRewards[index];
                            bool isClaimed = reward['isClaimed'] ?? false;

                            return ListTile(
                              title: Text(reward['taskName']),
                              subtitle: Text('${reward['timeReward']} minutes'),
                              trailing: isClaimed || _hasClaimedToday
    ? Text('Claimed', style: TextStyle(color: Colors.green))
    : ElevatedButton(
        onPressed: () async {
          try {
            // Fetch the child's current remaining time
            DocumentSnapshot childDoc = await _firestore
                .collection('parents')
                .doc(widget.parentID)
                .collection('children')
                .doc(widget.childID)
                .get();

            if (childDoc.exists) {
              int remainingTime = childDoc['usageLimit']['remainingTime'] ?? 0;
              remainingTime += reward['timeReward'] as int;

              // Update the child's remaining time in Firestore
              await _firestore
                  .collection('parents')
                  .doc(widget.parentID)
                  .collection('children')
                  .doc(widget.childID)
                  .update({
                'usageLimit.remainingTime': remainingTime,
              });

              // Mark the reward as claimed
              await _firestore
                  .collection('parents')
                  .doc(widget.parentID)
                  .collection('children')
                  .doc(widget.childID)
                  .collection('rewardRequests')
                  .doc(reward['rewardID'])
                  .update({'isClaimed': true});

              // Update the local state to reflect the claim
              setState(() {
                reward['isClaimed'] = true;
                _hasClaimedToday = true;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Reward claimed successfully!')),
              );
            }
          } catch (e) {
            print(e);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to claim reward.')),
            );
          }
        },
        child: Text('Claim'),
      ),

                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
