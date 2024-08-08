import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:notifye/components/ru_personmarker.dart';
import 'package:notifye/pages/alertdetail.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyAlertsPage extends StatefulWidget {
  const MyAlertsPage({super.key});

  @override
  State<MyAlertsPage> createState() => _MyAlertsPageState();
}

class _MyAlertsPageState extends State<MyAlertsPage> {
  late String currentUserId = '';
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late String circleId = '';

  @override
  void initState() {
    super.initState();
    getCurrentUser();
  }

  void getCurrentUser() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        setState(() {
          currentUserId = user.uid;
        });
      } else {
        // Handle case where user is null
      }
    } catch (e) {
      print('Error getting current user: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Alerts'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('Alerts')
            .where('posterId', isEqualTo: currentUserId)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.thumb_down_outlined,
                    size: 100,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    "Y O U   H A V E   N O   P O S T S",
                    style: TextStyle(fontSize: 20),
                  ),
                ],
              ),
            );
          }

          List<QueryDocumentSnapshot> sortedAlerts = snapshot.data!.docs;
          sortedAlerts.sort((a, b) {
            Timestamp timestampA = a['createdAt'];
            Timestamp timestampB = b['createdAt'];
            return timestampB.compareTo(timestampA);
          });

          return ListView(
            children: sortedAlerts.map((doc) {
              return AlertItem(
                alertData: doc.data() as Map<String, dynamic>,
                documentId: doc.id,
                circleId: circleId,
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class AlertItem extends StatefulWidget {
  final Map<String, dynamic> alertData;
  final String documentId;
  final String circleId;

  const AlertItem({
    required this.alertData,
    required this.documentId,
    required this.circleId,
    Key? key,
  }) : super(key: key);

  @override
  _AlertItemState createState() => _AlertItemState();
}

class _AlertItemState extends State<AlertItem> {
  late bool isResolved;

  @override
  void initState() {
    super.initState();
    isResolved = widget.alertData['resolved'] ?? false;
  }

  String _formatTimeDifference(Timestamp createdAt) {
    DateTime createdAtDateTime = createdAt.toDate();
    DateTime now = DateTime.now();
    Duration difference = now.difference(createdAtDateTime);

    if (difference.inHours >= 24) {
      return DateFormat.yMMMMd().format(createdAtDateTime);
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h ${difference.inMinutes.remainder(60)}m';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m';
    } else {
      return 'Just now';
    }
  }

  void toggleResolved(bool newValue) {
    FirebaseFirestore.instance.collection('Alerts').doc(widget.documentId).update({
      'resolved': newValue,
    });

    setState(() {
      isResolved = newValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    String alert = widget.alertData['alert'] ?? '';
    String postedBy = widget.alertData['postedBy'] ?? '';
    String imageUrl = widget.alertData['imageUrl'] ?? '';
    Timestamp createdAt = widget.alertData['createdAt'];

    String formattedTime = _formatTimeDifference(createdAt);

    return Card(
      child: Stack(
        children: [
          ListTile(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const PersonMarker(),
                    Text(
                      postedBy,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 7.0),
                  child: Text(
                    formattedTime,
                    style: const TextStyle(
                      fontSize: 10.0,
                      fontWeight: FontWeight.normal,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 11),
                Padding(
                  padding: const EdgeInsets.only(left: 7.0),
                  child: Text(alert),
                ),
                const SizedBox(height: 15),
                if (imageUrl.isNotEmpty)
                  Center(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10.0),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 15),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Escalating'),
                      Switch(
                        value: isResolved,
                        onChanged: (bool newValue) {
                          toggleResolved(newValue);
                        },
                        activeColor: Colors.green,
                        inactiveThumbColor: Colors.red,
                        inactiveTrackColor: Colors.red[200],
                      ),
                      const Text('Resolved'),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AlertDetailsPage(
                    data: widget.alertData,
                    circleId: widget.circleId,
                    imageUrl: imageUrl,
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 0.0,
            right: 0.0,
            child: PopupMenuButton<String>(
              onSelected: (String value) {
                if (value == 'delete') {
                  FirebaseFirestore.instance.collection('Alerts').doc(widget.documentId).delete();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete),
                    title: Text('Delete'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
