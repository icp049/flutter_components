import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:notifye/components/ru_downvotebutton.dart';
import 'package:notifye/components/ru_personmarker.dart';
import 'package:notifye/components/ru_upvotebutton.dart';
import 'package:notifye/pages/alertdetail.dart';
import 'package:intl/intl.dart';
import 'package:notifye/components/ru_likebutton.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  late double lat = 0.0;
  late double long = 0.0;
  late String locationMessage = '';
  late GeoFirePoint center = const GeoFirePoint(GeoPoint(0.0, 0.0));

  final db = FirebaseFirestore.instance;
  double radiusInKm = 20;
  String field = 'geo';

  List<DocumentSnapshot> alerts = [];
  bool isLoading = true; // Track loading state
  final currentUser = FirebaseAuth.instance.currentUser;

  Map<String, bool> likedAlerts = {}; // Track liked status locally
  Map<String, int> likeCounts = {}; // Track like counts locally

  Map<String, bool> upvotedAlerts = {}; // Track liked status locally
  Map<String, int> upvoteCounts = {};

  Map<String, bool> downvotedAlerts = {}; // Track liked status locally
  Map<String, int> downvoteCounts = {};

  bool isHottestSelected = false; // Track segmented button selection

  @override
  void initState() {
    super.initState();
    _getCurrentLocationAndFetchAlerts();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      setState(() {
        locationMessage = 'Location services are disabled';
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        locationMessage = 'Location permissions are permanently denied';
      });
      return;
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        setState(() {
          locationMessage =
              'Location permissions are denied (actual value: $permission).';
        });
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition();

    setState(() {
      lat = position.latitude;
      long = position.longitude;
      GeoPoint centerLocation = GeoPoint(lat, long); // Create GeoPoint object
      center = GeoFirePoint(centerLocation);
    });
  }

  Future<void> _getCurrentLocationAndFetchAlerts() async {
  setState(() {
    isLoading = true; // Start loading
  });

  await _getCurrentLocation();

  GeoCollectionReference collectionRef =
      GeoCollectionReference<Map<String, dynamic>>(db.collection('Alerts'));

  final List<DocumentSnapshot> result = await collectionRef
      .subscribeWithin(
        center: center,
        radiusInKm: radiusInKm,
        field: field,
        geopointFrom: (data) =>
            (data['geo'] as Map<String, dynamic>)['geopoint'] as GeoPoint,
      )
      .first; // Only fetch once, no stream

  // Sort based on the selected filter
  result.sort((a, b) {
    final Timestamp createdAtA =
        (a.data() as Map<String, dynamic>)['createdAt'];
    final Timestamp createdAtB =
        (b.data() as Map<String, dynamic>)['createdAt'];

    if (isHottestSelected) {
      final numUpvotesA =
          (a.data() as Map<String, dynamic>)['numUpvotes'] ?? 0;
      final numUpvotesB =
          (b.data() as Map<String, dynamic>)['numUpvotes'] ?? 0;
      final numDownvotesA =
          (a.data() as Map<String, dynamic>)['numDownvotes'] ?? 0;
      final numDownvotesB =
          (b.data() as Map<String, dynamic>)['numDownvotes'] ?? 0;

      // Calculate the score based on upvotes and downvotes
      final scoreA = numUpvotesA - numDownvotesA;
      final scoreB = numUpvotesB - numDownvotesB;

      return scoreB.compareTo(scoreA); // Higher scores come first
    } else {
      return createdAtB
          .compareTo(createdAtA); // Sort by creation time descending
    }
  });

  setState(() {
    alerts = result;
    isLoading = false;

    // Initialize the likedAlerts map
    likedAlerts = {
      for (var alert in alerts)
        alert.id: (alert.data() as Map<String, dynamic>?)?['Likes']
                ?.contains(currentUser?.email) ??
            false
    };

    likeCounts = {
      for (var alert in alerts)
        alert.id:
            (alert.data() as Map<String, dynamic>?)?['Likes']?.length ?? 0
    };

    //upvotes

    upvotedAlerts = {
      for (var alert in alerts)
        alert.id: (alert.data() as Map<String, dynamic>?)?['Upvotes']
                ?.contains(currentUser?.email) ??
            false
    };

    upvoteCounts = {
      for (var alert in alerts)
        alert.id:
            (alert.data() as Map<String, dynamic>?)?['Upvotes']?.length ?? 0
    };

    downvotedAlerts = {
      for (var alert in alerts)
        alert.id: (alert.data() as Map<String, dynamic>?)?['Downvotes']
                ?.contains(currentUser?.email) ??
            false
    };

    downvoteCounts = {
      for (var alert in alerts)
        alert.id:
            (alert.data() as Map<String, dynamic>?)?['Downvotes']?.length ?? 0
    };
  });
}


  String _formatTimeDifference(Timestamp createdAt) {
    DateTime createdAtDateTime =
        createdAt.toDate(); // Convert Timestamp to DateTime
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

  Future<void> _toggleLike(String alertId) async {
    final docRef = db.collection('Alerts').doc(alertId);
    final doc = await docRef.get();
    final data = doc.data() as Map<String, dynamic>?;

    if (data != null) {
      final likes = List<String>.from(data['Likes'] ?? []);
      final hasLiked = likes.contains(currentUser?.email);

      if (hasLiked) {
        likes.remove(currentUser?.email);
      } else {
        likes.add(currentUser?.email ?? '');
      }

      await docRef.update({
        'Likes': likes,
        'numLikes': likes.length, // Update the numLikes field
      });

      // Update local state to reflect the like change
      setState(() {
        likedAlerts[alertId] = !hasLiked;
        likeCounts[alertId] = likes.length;
      });
    }
  }

  Future<void> _toggleUpvote(String alertId) async {
    final docRef = db.collection('Alerts').doc(alertId);
    final doc = await docRef.get();
    final data = doc.data() as Map<String, dynamic>?;

    if (data != null) {
      final upvotes = List<String>.from(data['Upvotes'] ?? []);
      final downvotes = List<String>.from(data['Downvotes'] ?? []);
      final hasUpvoted = upvotes.contains(currentUser?.email);
      final hasDownvoted = downvotes.contains(currentUser?.email);

      if (hasDownvoted) {
        downvotes.remove(currentUser?.email);
      }

      if (hasUpvoted) {
        upvotes.remove(currentUser?.email);
      } else {
        upvotes.add(currentUser?.email ?? '');
      }

      await docRef.update({
        'Upvotes': upvotes,
        'Downvotes': downvotes,
        'numUpvotes': upvotes.length,
        'numDownvotes': downvotes.length,
      });

      setState(() {
        upvotedAlerts[alertId] = !hasUpvoted;
        upvoteCounts[alertId] = upvotes.length;
        downvotedAlerts[alertId] = false;
        downvoteCounts[alertId] = downvotes.length;
      });
    }
  }

  Future<void> _toggleDownvote(String alertId) async {
    final docRef = db.collection('Alerts').doc(alertId);
    final doc = await docRef.get();
    final data = doc.data() as Map<String, dynamic>?;

    if (data != null) {
      final downvotes = List<String>.from(data['Downvotes'] ?? []);
      final upvotes = List<String>.from(data['Upvotes'] ?? []);
      final hasDownvoted = downvotes.contains(currentUser?.email);
      final hasUpvoted = upvotes.contains(currentUser?.email);

      if (hasUpvoted) {
        upvotes.remove(currentUser?.email);
      }

      if (hasDownvoted) {
        downvotes.remove(currentUser?.email);
      } else {
        downvotes.add(currentUser?.email ?? '');
      }

      await docRef.update({
        'Downvotes': downvotes,
        'Upvotes': upvotes,
        'numDownvotes': downvotes.length,
        'numUpvotes': upvotes.length,
      });

      setState(() {
        downvotedAlerts[alertId] = !hasDownvoted;
        downvoteCounts[alertId] = downvotes.length;
        upvotedAlerts[alertId] = false;
        upvoteCounts[alertId] = upvotes.length;
      });
    }
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    body: Column(
      children: [
        // Segmented button for 'All' and 'Hottest' views
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ToggleButtons(
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('All'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('Hottest'),
              ),
            ],
            isSelected: [!isHottestSelected, isHottestSelected],
            onPressed: (index) {
              setState(() {
                isHottestSelected = index == 1;
                _getCurrentLocationAndFetchAlerts(); // Refresh the alerts
              });
            },
            color: Colors.black,
            selectedColor: Colors.white,
            fillColor: Colors.blue,
            borderRadius: BorderRadius.circular(8.0),
            borderWidth: 2.0,
            borderColor: Colors.blue,
            selectedBorderColor: Colors.blue,
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _getCurrentLocationAndFetchAlerts,
            child: isLoading
                ? Center(child: CircularProgressIndicator()) // Show loader while loading
                : alerts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 150,
                              height: 150,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF4CBA73),
                              ),
                              child: Icon(Icons.thumb_up_outlined,
                                  size: 100, color: Colors.white),
                            ),
                            const SizedBox(height: 25),
                            const Text(
                              "N O   A L E R T S   A R O U N D   Y O U",
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: alerts.length,
                        itemBuilder: (context, index) {
                          final doc = alerts[index];
                          final data = doc.data() as Map<String, dynamic>?;
                          final String alert = data?['alert'] ?? '';
                          final String postedBy = data?['postedBy'] ?? 'Unknown';
                          final String imageUrl = data?['imageUrl'] ?? '';
                          final String formattedTime =
                              _formatTimeDifference(data?['createdAt']);
                          final String alertId = doc.id; // Document ID for likes

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
                                              borderRadius:
                                                  BorderRadius.circular(10.0),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10.0),
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
                                            Icon(Icons.visibility,
                                                size: 20, color: Colors.grey),
                                            const SizedBox(width: 5),
                                            Text(
                                              '${data?['views'] ?? 0}',
                                              style: const TextStyle(
                                                color: Color.fromARGB(
                                                    255, 114, 113, 113),
                                              ),
                                            ),
                                            const SizedBox(width: 20),
                                            Icon(Icons.comment,
                                                size: 20, color: Colors.grey),
                                            const SizedBox(width: 5),
                                            Text(
                                              '${data?['numComments'] ?? 0}',
                                              style: const TextStyle(
                                                color: Color.fromARGB(
                                                    255, 114, 113, 113),
                                              ),
                                            ),
                                            const SizedBox(width: 20),
                                            LikeButton(
                                              isLiked:
                                                  likedAlerts[alertId] ?? false,
                                              onTap: () => _toggleLike(alertId),
                                            ),
                                            Text(
                                              '${likeCounts[alertId] ?? 0}', // Display the number of likes
                                              style: const TextStyle(
                                                color: Color.fromARGB(
                                                    255, 114, 113, 113),
                                              ),
                                            ),
                                            const SizedBox(width: 20),
                                            UpvoteButton(
                                              isUpvoted:
                                                  upvotedAlerts[alertId] ?? false,
                                              onTap: () => _toggleUpvote(alertId),
                                            ),
                                            Text(
                                              '${upvoteCounts[alertId] ?? 0}', // Display the number of likes
                                              style: const TextStyle(
                                                color: Color.fromARGB(
                                                    255, 114, 113, 113),
                                              ),
                                            ),
                                            const SizedBox(width: 20),
                                            DownvoteButton(
                                              isDownvoted:
                                                  downvotedAlerts[alertId] ?? false,
                                              onTap: () => _toggleDownvote(alertId),
                                            ),
                                            Text(
                                              '${downvoteCounts[alertId] ?? 0}', // Display the number of likes
                                              style: const TextStyle(
                                                color: Color.fromARGB(
                                                    255, 114, 113, 113),
                                              ),
                                            ),
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
                                          data: data ?? {},
                                          circleId: '',
                                          imageUrl: imageUrl,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                Positioned(
                                  top: 8.0,
                                  right: 8.0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0, vertical: 4.0),
                                    decoration: BoxDecoration(
                                      color: data?['resolved'] == true
                                          ? Colors.green
                                          : Colors.orange,
                                      borderRadius: BorderRadius.circular(10.0),
                                    ),
                                    child: Text(
                                      data?['resolved'] == true
                                          ? 'Resolved'
                                          : 'Ongoing',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ),
      ],
    ),
  );
}
}
