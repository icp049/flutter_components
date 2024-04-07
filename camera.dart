
//camerapage.dart 

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:vitto/pages/preview_page.dart';

class CameraPage extends StatefulWidget {
  final List<CameraDescription>? cameras;
  const CameraPage({Key? key, required this.cameras}) : super(key: key);

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late CameraController _cameraController;
  bool _isRearCameraSelected = true;

  @override
  void initState() {
    super.initState();
    // Initialize the camera when the widget is initialized
    initCamera(widget.cameras![0]);
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> initCamera(CameraDescription cameraDescription) async {
    // Create a CameraController
    _cameraController = CameraController(cameraDescription, ResolutionPreset.high);

    // Next, initialize the controller. This returns a Future.
    try {
      await _cameraController.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
      });
    } on CameraException catch (e) {
      debugPrint("camera error $e");
    }
  }

  Future<void> takePicture() async {
    if (!_cameraController.value.isInitialized) {
      return null;
    }
    if (_cameraController.value.isTakingPicture) {
      return null;
    }
    try {
      await _cameraController.setFlashMode(FlashMode.off);
      XFile picture = await _cameraController.takePicture();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PreviewPage(picture: picture)),
      );
    } on CameraException catch (e) {
      debugPrint('Error occurred while taking picture: $e');
      return null;
    }
  }

 @override
Widget build(BuildContext context) {
  return Scaffold(
    body: _cameraController.value.isInitialized
        ? Stack(
            children: [
              Positioned.fill(
                child: CameraPreview(_cameraController),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FloatingActionButton(
                        onPressed: takePicture,
                        child: const Icon(Icons.camera_alt),
                      ),
                      SizedBox(height: 16),
                      FloatingActionButton(
                        onPressed: () {
                          setState(() {
                            _isRearCameraSelected = !_isRearCameraSelected;
                          });
                          initCamera(
                              widget.cameras![_isRearCameraSelected ? 0 : 1]);
                        },
                        child: Icon(
                          _isRearCameraSelected
                              ? Icons.switch_camera
                              : Icons.switch_camera_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )
        : Center(child: CircularProgressIndicator()),
  );
}

}


//previewpage.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vitto/pages/test_page.dart';
class PreviewPage extends StatelessWidget {
  final XFile picture;

  const PreviewPage({Key? key, required this.picture}) : super(key: key);

  @override
    Widget build(BuildContext context) {
    File file = File(picture.path); // Convert XFile to File
    return Scaffold(
      appBar: AppBar(
        title: Text('Preview'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Display the image
            Image.file(
              file, // Use the File object here
              fit: BoxFit.cover,
            ),
            SizedBox(height: 20),
            // Button to navigate back to TestPage
 ElevatedButton(
              onPressed: () async {
                final imageBytes = await File(picture.path).readAsBytes();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Testpage(imageBytes: imageBytes),
                  ),
                ); // Navigate to TestPage with image bytes
              },
              child: Text('Go to TestPage'),
            ),
            
          ],
        ),
      ),
    );
  
}
}

//controller in another page and call to button 

  void _navigateToCameraPage(BuildContext context) async {
  final cameras = await availableCameras();
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => CameraPage(cameras: cameras)),
  );
}



