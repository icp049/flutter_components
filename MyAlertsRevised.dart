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
  late String currentUserId = ''; // Initialize to empty string
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late String circleId = '';

  @override
  void initState() {
    super.initState();
    getCurrentUser(); // Initialize current user
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
        // For example, navigate to login screen or handle differently
      }
    } catch (e) {
      print('Error getting current user: $e');
    }
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

  void deleteAlert(String documentId) {
    // Implement delete alert functionality
    // Example:
    _db.collection('Alerts').doc(documentId).delete();
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

          // Sort alerts based on createdAt timestamp
          List<QueryDocumentSnapshot> sortedAlerts = snapshot.data!.docs;
          sortedAlerts.sort((a, b) {
            Timestamp timestampA = a['createdAt'];
            Timestamp timestampB = b['createdAt'];
            return timestampB.compareTo(timestampA); // Descending order
          });

          return ListView(
            children: sortedAlerts.map((doc) {
              Map<String, dynamic>? data =
                  doc.data() as Map<String, dynamic>?;

              String alert = data?['alert'] ?? '';
              String postedBy = data?['postedBy'] ?? '';
              String imageUrl = data?['imageUrl'] ?? '';
              String documentId = doc.id;
              Timestamp createdAt = data?['createdAt'];

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
                              // Removed PopupMenuButton from here
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
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AlertDetailsPage(
                              data: data,
                              circleId: circleId,
                              imageUrl: imageUrl,
                              // Pass any additional data needed
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
                            deleteAlert(documentId);
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
            }).toList(),
          );
        },
      ),
    );
  }
}
