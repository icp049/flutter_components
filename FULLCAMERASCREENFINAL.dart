import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:notifye/pages/imageView.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({Key? key, required this.cameras}) : super(key: key);

  final List<CameraDescription>? cameras;

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late CameraController _cameraController;
  bool _isRearCameraSelected = true;

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    initCamera(widget.cameras![0]);
  }

  Future<void> takePicture() async {
    if (!_cameraController.value.isInitialized || _cameraController.value.isTakingPicture) {
      return null;
    }
    try {
      await _cameraController.setFlashMode(FlashMode.off);
      XFile picture = await _cameraController.takePicture();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PreviewPage(picture: picture),
        ),
      );
    } on CameraException catch (e) {
      debugPrint('Error occurred while taking picture: $e');
      return null;
    }
  }

  Future<void> initCamera(CameraDescription cameraDescription) async {
    _cameraController = CameraController(cameraDescription, ResolutionPreset.high);
    try {
      await _cameraController.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
      });
    } on CameraException catch (e) {
      debugPrint("camera error $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: (_cameraController.value.isInitialized)
                    ? CameraPreview(_cameraController)
                    : Container(
                        color: Colors.black,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
              ),
            ],
          ),
          Positioned(
            top: 35.0,
            left: 16.0,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ),
          Positioned(
           bottom: 16.0,
            left: 16.0,
            child: IconButton(
              icon: Icon(
                _isRearCameraSelected ? CupertinoIcons.switch_camera : CupertinoIcons.switch_camera_solid,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() => _isRearCameraSelected = !_isRearCameraSelected);
                initCamera(widget.cameras![_isRearCameraSelected ? 0 : 1]);
              },
            ),
          ),
          
Positioned(
            bottom: 16.0,
            left: MediaQuery.of(context).size.width / 2 - 35,
            child: GestureDetector(
              onTap: takePicture,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.white.withOpacity(0.5), Colors.white],
                    stops: [0.4, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      offset: Offset(0, 4),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                   
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
