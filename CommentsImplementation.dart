import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:notifye/components/ru_alertmaker.dart';
import 'package:notifye/components/ru_personmarker.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// for the sharing
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;

class AlertDetailsPage extends StatefulWidget {
  final Map<String, dynamic>? data;
  final String circleId;
  final String? imageUrl;

  AlertDetailsPage(
      {super.key, required this.data, required this.circleId, this.imageUrl});

  @override
  _AlertDetailsPageState createState() => _AlertDetailsPageState();
}

class _AlertDetailsPageState extends State<AlertDetailsPage> {
  final GlobalKey globalKey = GlobalKey();
  final TextEditingController _commentController = TextEditingController();

  Future<void> _captureScreenShot() async {
    RenderRepaintBoundary boundary =
        globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 2);
    ByteData byteData =
        await image.toByteData(format: ui.ImageByteFormat.png) as ByteData;
    Uint8List pngBytes = byteData.buffer.asUint8List();
    await Share.shareXFiles([XFile.fromData(pngBytes, mimeType: 'image/png')]);
  }

  void incrementViews() async {
    String alertId = widget.data?['alertId'];
    CollectionReference alerts =
        FirebaseFirestore.instance.collection('alerts');

    try {
      await alerts.doc(alertId).update({
        'views': FieldValue.increment(1),
      });
      print('Views incremented successfully');
    } catch (e) {
      print('Error incrementing views: $e');
    }
  }

  void addComment(String alertId, String commentText) async {
    if (commentText.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('Alerts')
            .doc(alertId)
            .collection('comments')
            .add({
          'text': commentText,
          'postedBy': 'User', // You might want to replace 'User' with the actual username
          'createdAt': Timestamp.now(),
        });
        _commentController.clear();
        print('Comment added successfully');
      } catch (e) {
        print('Error adding comment: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String alertId = widget.data?['alertId'] ?? '';

    return Scaffold(
      appBar: AppBar(
        actions: <Widget>[
          IconButton(
            icon: const Icon(
              Icons.campaign_sharp,
              color: Color(0xFFad8de3),
            ),
            onPressed: () {
              _captureScreenShot();
            },
          ),
        ],
      ),
      body: RepaintBoundary(
        key: globalKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: Theme.of(context).colorScheme.surface,
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AlertDetails(data: widget.data),
                    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
                      Container(
                        width: 300,
                        height: 300,
                        padding: const EdgeInsets.all(10),
                        child: Image.network(
                          widget.imageUrl!,
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(10.0),
                      child: widget.data != null
                          ? MapSection(data: widget.data!, circleId: widget.circleId)
                          : const SizedBox(),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Comments:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('Alerts')
                                .doc(alertId)
                                .collection('comments')
                                .orderBy('createdAt', descending: true)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }

                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                return const Text('No comments yet.');
                              }

                              return Column(
                                children: snapshot.data!.docs.map((doc) {
                                  final commentData = doc.data() as Map<String, dynamic>;
                                  final text = commentData['text'] ?? '';
                                  final postedBy = commentData['postedBy'] ?? '';
                                  final createdAt = (commentData['createdAt'] as Timestamp).toDate();

                                  return ListTile(
                                    title: Text(text),
                                    subtitle: Text('Posted by $postedBy on ${DateFormat('MMMM dd, yyyy \'at\' hh:mm a').format(createdAt)}'),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _commentController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Add a comment...',
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () {
                              addComment(alertId, _commentController.text);
                            },
                            child: const Text('Submit'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AlertDetails extends StatelessWidget {
  final Map<String, dynamic>? data;

  const AlertDetails({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PersonMarker(),
              Text(
                '${data?['postedBy'] ?? 'No data'}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Padding(
            padding:
                const EdgeInsets.only(left: 7.0),
            child: Text(
              '${data?['alert'] ?? 'No data'}',
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class MapSection extends StatelessWidget {
  final Map<String, dynamic> data;
  final String circleId;

  const MapSection({super.key, required this.data, required this.circleId});

  void _launchMapsUrl(double lat, double lon) async {
    String url;
    if (Platform.isIOS) {
      url = 'http://maps.apple.com/?ll=$lat,$lon';
    } else {
      url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
    }

    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    DateTime getCreatedAtDateTime() {
      Timestamp timestamp = data['createdAt'];
      return timestamp.toDate();
    }

    String formatDateTime(DateTime dateTime) {
      return DateFormat('MMMM dd, yyyy \'at\' hh:mm a').format(dateTime);
    }

    final latitude = data['circle']['center']['latitude'];
    final longitude = data['circle']['center']['longitude'];

    return GestureDetector(
      onTap: () => _launchMapsUrl(latitude, longitude),
      child: SizedBox(
        height: 200,
        child: Stack(
          children: [
            IgnorePointer(
              child: FlutterMap(
                options: MapOptions(
                  center: LatLng(latitude, longitude),
                  zoom: 16,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(latitude, longitude),
                        width: 60,
                        height: 60,
                        child: const AlertMarker(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: 5.0,
              right: 5.0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatDateTime(getCreatedAtDateTime()),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
