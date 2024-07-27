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
  bool _isCameraInitialized = false;

  // Zoom and flash
  bool _isFlashOn = false;
  bool _showFocusCircle = false;  // For displaying the focus circle
  double _focusX = 0;  // X position of the focus circle
  double _focusY = 0;  // Y position of the focus circle
  double _currentZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 8.0;

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.cameras != null && widget.cameras!.isNotEmpty) {
      // Initialize camera controller
      _cameraController = CameraController(
        widget.cameras![0],
        ResolutionPreset.high,
      );
      _cameraController.initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _isCameraInitialized = true;
        });
      });
    } else {
      debugPrint("No cameras available.");
    }
  }

  Future<void> takePicture() async {
    if (!_cameraController.value.isInitialized) {
      return;
    }
    if (_cameraController.value.isTakingPicture) {
      return;
    }
    try {
      await _cameraController.setFlashMode(FlashMode.off);
      XFile picture = await _cameraController.takePicture();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PreviewPage(
            picture: picture,
          ),
        ),
      );
    } on CameraException catch (e) {
      debugPrint('Error occurred while taking picture: $e');
      return;
    }
  }

  Future<void> initCamera(CameraDescription cameraDescription) async {
    _cameraController = CameraController(cameraDescription, ResolutionPreset.high);
    try {
      await _cameraController.initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _isCameraInitialized = true;
        });
      });
    } on CameraException catch (e) {
      debugPrint("Camera error $e");
    }
  }

  void _toggleFlash() async {
    if (_isFlashOn) {
      await _cameraController.setFlashMode(FlashMode.off);
    } else {
      await _cameraController.setFlashMode(FlashMode.torch);
    }
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details) async {
    double zoomLevel = _currentZoomLevel * details.scale;

    if (zoomLevel < _minZoomLevel) {
      zoomLevel = _minZoomLevel;
    } else if (zoomLevel > _maxZoomLevel) {
      zoomLevel = _maxZoomLevel;
    }

    setState(() {
      _currentZoomLevel = zoomLevel;
    });

    try {
      await _cameraController.setZoomLevel(_currentZoomLevel);
    } on CameraException catch (e) {
      debugPrint('Error occurred while setting zoom: $e');
    }
  }

  Future<void> _onTap(TapUpDetails details) async {
    if (_cameraController.value.isInitialized) {
      setState(() {
        _showFocusCircle = true;
        _focusX = details.localPosition.dx;
        _focusY = details.localPosition.dy;
      });

      double fullWidth = MediaQuery.of(context).size.width;
      double cameraHeight = fullWidth * _cameraController.value.aspectRatio;

      double xp = _focusX / fullWidth;
      double yp = _focusY / cameraHeight;

      Offset point = Offset(xp, yp);

      print("Focus point: $point");

      // Manually focus
      await _cameraController.setFocusPoint(point);

      // Optionally set light exposure
      // await _cameraController.setExposurePoint(point);

      // Hide focus circle after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showFocusCircle = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GestureDetector(
            onScaleUpdate: _onScaleUpdate,
            onTapUp: _onTap,  // Handle taps to focus
            child: Column(
              children: [
                Expanded(
                  child: _isCameraInitialized
                      ? CameraPreview(_cameraController)
                      : Container(
                          color: Colors.black,
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                ),
              ],
            ),
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
                if (widget.cameras != null && widget.cameras!.length > 1) {
                  initCamera(widget.cameras![_isRearCameraSelected ? 0 : 1]);
                } else {
                  debugPrint("Not enough cameras available.");
                }
              },
            ),
          ),
          Positioned(
            bottom: 16.0,
            right: 16.0,
            child: IconButton(
              icon: Icon(
                _isFlashOn ? Icons.flash_on : Icons.flash_off,
                color: Colors.white,
              ),
              onPressed: _toggleFlash,
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
          if (_showFocusCircle)
            Positioned(
              top: _focusY - 20,
              left: _focusX - 20,
              child: Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
