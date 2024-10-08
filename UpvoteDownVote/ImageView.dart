 import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:notifye/helper/helper_functions.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';
import 'package:notifye/pages/home_page.dart';
import 'package:image/image.dart' as img;

class PreviewPage extends StatefulWidget {
  const PreviewPage({Key? key, required this.picture}) : super(key: key);

  final XFile picture;

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  final GlobalKey<FormState> _mypostKey = GlobalKey<FormState>();

  String locationMessage = 'Current Location of User';
  final TextEditingController postController = TextEditingController();
  double? lat;
  double? long;
  int views = 0;
  int numComments = 0;
  final db = FirebaseFirestore.instance;
  double radiusInKm = 20;
  String field = 'geo';
  late GeoFirePoint center = const GeoFirePoint(GeoPoint(0.0, 0.0));
  late String circleId = '';

  int rotationAngle = 0;

  Uint8List? _image;
  bool permissionIsGranted = false;
  bool isPosting = false; // New flag to track posting state

  final LocationSettings locationSettings = const LocationSettings(
    accuracy: LocationAccuracy.best,
    distanceFilter: 10,
  );

  StreamSubscription<Position>? positionStream;

  Future<void> _addLocation(
    double lat,
    double long,
    Uint8List? imageBytes,
  ) async {
    if (_mypostKey.currentState!.validate()) {
      try {
        setState(() {
          isPosting = true; // Start loading
        });
        FocusScope.of(context).unfocus();

        // Upload image to Firebase Storage if available
        String? imageUrl;
        if (imageBytes != null) {
          imageUrl = await uploadImageToStorage(imageBytes);
        }

        final GeoPoint geoPoint = GeoPoint(lat, long); // Create a GeoPoint
        final GeoFirePoint geoFirePoint = GeoFirePoint(geoPoint);

        const double circleRadius = 20;

        final Map<String, dynamic> circleData = {
          'center': {'latitude': lat, 'longitude': long},
          'radius': circleRadius,
        };

        String? username = getCurrentUserDisplayName();
        String alertId = const Uuid().v4(); // Generate a unique alertId
        String? userId = FirebaseAuth.instance.currentUser?.uid;

        // Specify the document ID as alertId
        await FirebaseFirestore.instance.collection('Alerts').doc(alertId).set({
          'alertId': alertId,
          'geo': geoFirePoint.data,
          'isInvisible': true,
          'alert': postController.text,
          'circle': circleData,
          'postedBy': username,
          'imageUrl': imageUrl,
          'createdAt': DateTime.now(),
          'views': views,
          'resolved': false,
          'posterId': userId,
          'numComments': numComments,
          'Likes': [],
          'numLikes':0,
          'Upvotes': [],
          'numUpvotes': 0,
          'Downvotes': [],
          'numDownvotes':0,
        });

        debugPrint('Location added successfully');

        postController.clear();

        setState(() {
          _image = null;
        });

        // Show confirmation message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your post has been added!'),
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate to the home page after a short delay
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => HomePage()),
          );
        }
      } catch (error) {
        setState(() {
          isPosting = false; // Stop loading on error
        });
        debugPrint('Error: $error');
      }
    }
  }

  final storageRef = FirebaseStorage.instance.ref();

  Future<String?> uploadImageToStorage(Uint8List imageBytes) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child('AlertPhotos');

      Uint8List? compressedImage = await FlutterImageCompress.compressWithList(
        imageBytes,
        minHeight: 800,
        minWidth: 800,
        quality: 60,
      );

      String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      await storageRef.child(fileName).putData(compressedImage!);
      String imageUrl = await storageRef.child(fileName).getDownloadURL();
      return imageUrl;
    } catch (error) {
      debugPrint('Error: $error');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  void _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();

        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best);

      if (!mounted) {
        return;
      }

      setState(() {
        lat = position.latitude;
        long = position.longitude;
        locationMessage = 'Latitude: $lat, Longitude: $long';
        GeoPoint centerLocation = GeoPoint(lat!, long!);
        center = GeoFirePoint(centerLocation);
        permissionIsGranted = true;
      });

      positionStream =
          Geolocator.getPositionStream(locationSettings: locationSettings)
              .listen((Position position) {
        if (!mounted) {
          return;
        }
        setState(() {
          lat = position.latitude;
          long = position.longitude;
          LatLng location = LatLng(lat!, long!);
        });
      });
    } catch (error) {
      debugPrint('Error: $error');
    }
  }

  @override
  void dispose() {
    positionStream?.cancel();
    super.dispose();
  }

Future<void> _convertAndUploadImage() async {
  // Read image file and rotate
  img.Image originalImage = img.decodeImage(await File(widget.picture.path).readAsBytes())!;
  img.Image rotatedImage = img.copyRotate(originalImage, angle: rotationAngle); // Use named parameter here
  final imageBytes = img.encodeJpg(rotatedImage);

  // Check if location is available before adding
  if (lat != null && long != null) {
    await _addLocation(lat!, long!, imageBytes);
  }
}




  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      backgroundColor: const Color(0xFFE4D5F7),
      actions: [
        IconButton(
          icon: const Icon(Icons.rotate_right),
          onPressed: () {
            setState(() {
              rotationAngle = (rotationAngle + 90) % 360;
            });
          },
        ),
      ],
    ),
    body: Container(
      color: const Color(0xFFE4D5F7),
      height: MediaQuery.of(context).size.height, // Make the container take the full height
      child: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: rotationAngle * (3.1415927 / 180), // Convert degrees to radians
                child: Image.file(
                  File(widget.picture.path),
                  fit: BoxFit.cover,
                  width: 250,
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Form(
                        key: _mypostKey,
                        child: TextFormField(
                          controller: postController,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            hintText: 'What is happening around you?',
                            border: InputBorder.none,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a description';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isPosting)
                            const CircularProgressIndicator()
                          else
                            ElevatedButton(
                              onPressed: _convertAndUploadImage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20.0, vertical: 10.0),
                              ),
                              child: const Text(
                                'POST',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.0,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
  );
}
}
