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
  final db = FirebaseFirestore.instance;
  double radiusInKm = 20;
  String field = 'geo';
  late GeoFirePoint center = const GeoFirePoint(GeoPoint(0.0, 0.0));
  late String circleId = '';

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
      String alertId = const Uuid().v4();
      String? userId = FirebaseAuth.instance.currentUser?.uid;

      await FirebaseFirestore.instance.collection('Alerts').add({
        'alertId': alertId,
        'geo': geoFirePoint.data,
        'isInvisible': true, // Corrected the spelling of 'isInvisible'
        'alert': postController.text,
        'circle': circleData,
        'postedBy': username,
        'imageUrl': imageUrl,
        'createdAt': DateTime.now(),
        'views': views,
        'posterId': userId,
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
    final imageBytes = await File(widget.picture.path).readAsBytes();
    if (lat != null && long != null) {
      await _addLocation(lat!, long!, imageBytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE4D5F7),
      ),
      body: Container(
        color: const Color(0xFFE4D5F7),
        height: MediaQuery.of(context).size.height, // Make the container take the full height
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.file(
                  File(widget.picture.path),
                  fit: BoxFit.cover,
                  width: 250,
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0), // Add horizontal padding
                  child: Container(
                    padding: const EdgeInsets.all(16.0), // Internal padding for the content
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.0), // Rounded corners
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
                              const CircularProgressIndicator() // Show loading indicator
                            else
                              IconButton(
                                icon: const Icon(
                                  Icons.arrow_forward_sharp,
                                  color: Colors.blue,
                                  size: 35.0, // Adjust the size as needed
                                ),
                                onPressed: _convertAndUploadImage,
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
