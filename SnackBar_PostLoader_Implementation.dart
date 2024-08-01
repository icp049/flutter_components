import 'package:firebase_auth/firebase_auth.dart';

import 'package:firebase_storage/firebase_storage.dart';

import 'package:flutter/material.dart';

import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

import 'package:geolocator/geolocator.dart';

import 'package:flutter_map/flutter_map.dart';

import 'package:latlong2/latlong.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:notifye/components/ru_usermarker.dart';

import 'dart:async';

import 'package:notifye/helper/helper_functions.dart';

import 'package:image_picker/image_picker.dart';

import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:notifye/components/ru_alertmaker.dart';

import 'package:notifye/pages/alertdetail.dart';

import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:uuid/uuid.dart';

import 'package:camera/camera.dart';

import 'package:notifye/pages/cameraPage.dart';

 

final _postKey = GlobalKey<FormState>();


class MapPage extends StatelessWidget {




  final Uint8List? imageBytes; // Define imageBytes parameter



  const MapPage({super.key, this.imageBytes});

 

  @override

  Widget build(BuildContext context) {

    return const Scaffold(

      body: Center(

        child: LocationWidget(),

      ),

    );

  }

}

 

class LocationWidget extends StatefulWidget {

  

  const LocationWidget({super.key});

 

  @override

  State<LocationWidget> createState() => _LocationWidgetState();

}

 

class _LocationWidgetState extends State<LocationWidget> {

  String locationMessage = 'Current Location of User';



  String? apiKey = dotenv.env['MAP_API_KEY'];



  final TextEditingController postController = TextEditingController();

 

  double? lat;

 

  double? long;

 

  int views = 0;

 

  late bool isContainerVisible = false; // Declare isContainerVisible

  late bool isPosting = false;

 

  final MapController controller = MapController();

 

  final db = FirebaseFirestore.instance;

  double radiusInKm = 20;

  String field = 'geo';

  late GeoFirePoint center = const GeoFirePoint(GeoPoint(0.0, 0.0));

  late String circleId = '';

 

  Uint8List? _image;

  File? selectedIMage;

 

  late bool permissionIsGranted = false;

  List<CameraDescription>? cameras;

  late bool isMapInteracting = false;

 

  final LocationSettings locationSettings = const LocationSettings(

    accuracy: LocationAccuracy.best,

    distanceFilter: 10,

  );



 

  Future<void> _addLocation(

    double lat,

    double long,

    Uint8List? imageBytes,

  ) async {

    if (_postKey.currentState!.validate()) {

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

 

        toggleContainerVisibility();

 

        setState(() {

          _image = null;
          isPosting = false;

        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your post has been added!'),
            duration: Duration(seconds: 2),
          ),
        );

      } catch (error) {

         setState(() {
          isPosting = false; // Stop loading on error
        });

        //catch caluse comment

      }

    }

  }

 

  final storageRef = FirebaseStorage.instance.ref();

  Future<String?> uploadImageToStorage(Uint8List imageBytes) async {

    try {

      // Create a reference to the folder named "locationPhotos"

 

      final storageRef = FirebaseStorage.instance.ref().child('AlertPhotos');

 

      Uint8List? compressedImage = await FlutterImageCompress.compressWithList(

        imageBytes,

        minHeight: 800,

        minWidth: 800,

        quality: 60,

      );

 

      // Generate a unique filename for the image

      String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

 

      // Upload the image to the "locationPhotos" folder with the generated filename

      await storageRef.child(fileName).putData(compressedImage);

 

      // Get download URL for the uploaded image

      String imageUrl = await storageRef.child(fileName).getDownloadURL();

 

      return imageUrl;

    } catch (error) {

      return null;

    }

  }

 

  @override

  void initState() {

    super.initState();

// Initialize cameras in initState

    _getCurrentLocation();

    _initializeCameras();

  }

   
  Future<void> _initializeCameras() async {
    try {
      cameras = await availableCameras();
    } catch (e) {
      debugPrint('Error initializing cameras: $e');
    }
  }


  StreamSubscription<Position>? positionStream;

  void _getCurrentLocation() async {

    try {

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

 

      if (!serviceEnabled) {

        return null;

      }

 

      LocationPermission permission = await Geolocator.checkPermission();

 

      if (permission == LocationPermission.deniedForever) {

        return null;

      }

 

      if (permission == LocationPermission.denied) {

        permission = await Geolocator.requestPermission();

 

        if (permission != LocationPermission.whileInUse &&

            permission != LocationPermission.always) {

          return null;

        }

      }

 

      Position? position = await Geolocator.getCurrentPosition(

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

        permissionIsGranted = true; // Set permissionIsGranted to true

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

          LatLng location = LatLng(lat!, long!); //part of og

 

          final bounds = controller.camera.visibleBounds; //delete if bneeded

          // Check if the user marker's position is within the bounds

          if (!isMapInteracting && bounds.contains(location)) {

            controller.move(location, controller.camera.zoom);

          }

 

          //testing and can be removbed

 

          Marker(

            point: location,

            width: 60,

            height: 60,

            child: const UserMarker(),

          );

        });

      });

    } catch (e) {

      setState(() {

        locationMessage = 'Unable to fetch location';

      });

    }

  }

  

  void toggleContainerVisibility() {

    setState(() {

      isContainerVisible = !isContainerVisible;

      if (!isContainerVisible) {

        // Unfocus the keyboard

        FocusScope.of(context).unfocus();

      }

    });

  }

 

  @override

  Widget build(BuildContext context) {

    if (!permissionIsGranted) {

      return const Center(

        child: CircularProgressIndicator(),

      );

    }

    return StreamBuilder<List<DocumentSnapshot>>(

      stream: GeoCollectionReference<Map<String, dynamic>>(

        db.collection('Alerts'),

      ).subscribeWithin(

        center: center,

        radiusInKm: radiusInKm,

        field: field,

        geopointFrom: (data) =>

            (data['geo'] as Map<String, dynamic>?)?['geopoint'] as GeoPoint,

      ),

      builder: (context, AsyncSnapshot<List<DocumentSnapshot>> snapshot) {

        if (snapshot.hasError) {

          return Center(

            child: Text('Error: ${snapshot.error}'),

          );

        }

 

        if (!snapshot.hasData || snapshot.data == null) {

          return const CircularProgressIndicator();

        }

        return Listener(

            onPointerDown: (event) {

              setState(() {

                isMapInteracting = true;

              });

            },

            onPointerUp: (event) {

              setState(() {

                isMapInteracting = false;

              });

            },

            child: Stack(

              children: [

                if (lat != null && long != null)

                  FlutterMap(

                    mapController: controller,

                    options: MapOptions(

                      initialCenter: LatLng(lat!, long!),

                      initialZoom: 16,

                    ),

                    children: [

                      TileLayer(

                        urlTemplate:

                            'https://{s}.tile.jawg.io/{style}/{z}/{x}/{y}.png?access-token={accessToken}',

                        additionalOptions: {

                          'accessToken': dotenv.env['MAP_API_KEY'] ?? '',

                          'style': 'jawg-light',

                          // Choose the appropriate style here

                        },

 

                        // Set userAgentPackageName if needed

                        userAgentPackageName: 'com.example.app',

                      ),

                      MarkerLayer(

                        markers: [

                          for (DocumentSnapshot<Object?> doc in snapshot.data!)

                            Marker(

                              width: 60,

                              height: 60,

                              point: LatLng(

                                (doc.data() as Map<String, dynamic>?)?['circle']

                                        ?['center']?['latitude'] ??

                                    0.0,

                                (doc.data() as Map<String, dynamic>?)?['circle']

                                        ?['center']?['longitude'] ??

                                    0.0,

                              ),

                              child: GestureDetector(

                                onTap: () {

                                  String? imageUrl = (doc.data()

                                      as Map<String, dynamic>?)?['imageUrl'];

 

                                  Navigator.push(

                                    context,

                                    MaterialPageRoute(

                                      builder: (context) => AlertDetailsPage(

                                        data:

                                            doc.data() as Map<String, dynamic>,

                                        circleId: circleId,

                                        imageUrl: imageUrl,

                                      ),

                                    ),

                                  );

                                },

                                child: const AlertMarker(),

                              ),

                            ),

                        ],

                      ),

                      MarkerLayer(

                        markers: [

                          Marker(

                            point: LatLng(lat!, long!), // center of 't Gooi

                            width: 60,

                            height: 60,

 

                            // Add a child widget for your Marker

                            child: const UserMarker(),

                          ),

                        ],

                      ),

                    ],

                  ),

                Positioned(

                  top: 20.0,

                  right: 20.0,

                  child: FloatingActionButton(

                    onPressed: () {

                      controller.move(LatLng(lat!, long!), 16);

                    },

                    child: const Icon(Icons.gps_fixed),

                  ),

                ),

                Positioned(

                  bottom: 85.0,

                  left: 20.0,

                  right: 20.0,

                  child: AnimatedOpacity(

                    opacity: isContainerVisible ? 1.0 : 0.0,

                    duration: const Duration(milliseconds: 500),

                    child: IgnorePointer(

                      ignoring: !isContainerVisible,

                      child: Container(

                        padding: const EdgeInsets.all(10.0),

                        decoration: BoxDecoration(

                          color: Colors.white,

                          borderRadius: BorderRadius.circular(10.0),

                          boxShadow: [

                            BoxShadow(

                              color: Colors.grey.withOpacity(0.5),

                              spreadRadius: 1,

                              blurRadius: 3,

                              offset: const Offset(0, 2),

                            ),

                          ],

                        ),

                        child: Column(

                          crossAxisAlignment: CrossAxisAlignment.stretch,

                          children: [

                            if (_image != null)

                              Container(

                                width: 300,

                                height: 300,

                                padding: const EdgeInsets.all(10),

                                decoration: BoxDecoration(

                                  color: Colors.white,

                                  borderRadius: BorderRadius.circular(10),

                                  boxShadow: [

                                    BoxShadow(

                                      color: Colors.grey.withOpacity(0.5),

                                      spreadRadius: 1,

                                      blurRadius: 3,

                                      offset: const Offset(0, 2),

                                    ),

                                  ],

                                ),

                                child: Stack(

                                  alignment: Alignment.center,

                                  children: [

                                    Image.memory(_image!),

 

                                    // Delete button

                                    Positioned(

                                      top: 0,

                                      right: 0,

                                      child: IconButton(

                                        icon: const Icon(

                                          Icons.cancel,

                                          color: Colors.red,

                                        ),

                                        onPressed: () {

                                          setState(() {

                                            _image = null; // Remove _image

                                          });

                                        },

                                      ),

                                    ),

                                  ],

                                ),

                              ),

                            SingleChildScrollView(

                              child: Form(

                                key: _postKey,

                                child: TextFormField(

                                  controller: postController,

                                  maxLines: 5,

                                  validator: (value) {

                                    if (value == null || value.isEmpty) {

                                      return 'Please enter some text';

                                    }

                                    return null; // Return null if the input is valid

                                  },

                                  decoration: const InputDecoration(

                                    hintText: 'What is happening around you?',

                                    border: InputBorder.none,

                                  ),

                                ),

                              ),

                            ),

                            const SizedBox(height: 10),

                            Row(

                              children: [

                                IconButton(

                                  onPressed: () async {

                                    await availableCameras().then((value) =>

                                        Navigator.push(

                                            context,

                                            MaterialPageRoute(

                                                builder: (_) => CameraPage(

                                                    cameras: value))));

                                  },

                                  icon: const Icon(Icons.camera_alt_rounded),

                                  color: Colors.blue,

                                ),

                                IconButton(

                                  onPressed: () {

                                    _pickImageFromGallery();

                                  },

                                  icon: const Icon(Icons.add_photo_alternate),

                                  color: Colors.blue,

                                ),

 

                                const Spacer(),
                                
                                
                                 // Added Spacer to push icons to the right

                               if (isPosting)
                      const CircularProgressIndicator() // Show loading indicator
                    else
                      IconButton(
                        onPressed: () {
                          _addLocation(lat!, long!, _image);
                        },
                        icon: const Icon(
                          Icons.arrow_forward_sharp,
                          color: Colors.blue,
                          size: 35.0, // Adjust the size as needed
                        ),
                      ),

                              ],

                            ),

                          ],

                        ),

                      ),

                    ),

                  ),

                ),

                Positioned(

                  bottom: 20.0,

                  right: 20.0,

                  child: Container(

                    width: 60.0,

                    height: 60.0,

                    decoration: BoxDecoration(

                      shape: BoxShape.circle,

                      color: Colors.black.withOpacity(0.9),

                    ),

                    child: IconButton(

                      onPressed: toggleContainerVisibility,

                      icon: Icon(

                        isContainerVisible ? Icons.close : Icons.add,

                        color: Colors.white,

                      ),

                    ),

                  ),

                ),

              ],

            ));

      },

    );

  }

 

  Future<void> _pickImageFromGallery() async {

    final pickedFile =

        await ImagePicker().pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {

      final imageBytes = await pickedFile.readAsBytes();

      setState(() {

        _image = imageBytes;

      });

    }

  }

}

 
