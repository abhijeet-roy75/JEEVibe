import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../utils/image_compressor.dart';
import '../services/api_service.dart';
import 'solution_screen.dart';
import '../theme/jeevibe_theme.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isInitializing = false;
  final ImagePicker _picker = ImagePicker();
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentZoomLevel = 1.0;
  FlashMode _flashMode = FlashMode.off;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (!mounted) return;
    
    setState(() {
      _isInitializing = true;
    });
    
    try {
      _cameras = await availableCameras().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Camera initialization timed out');
        },
      );
      
      if (_cameras != null && _cameras!.isNotEmpty && mounted) {
        _controller = CameraController(
          _cameras![0],
          ResolutionPreset.high, // Higher resolution for better OCR
          enableAudio: false,
          imageFormatGroup: Platform.isIOS 
              ? ImageFormatGroup.jpeg 
              : ImageFormatGroup.yuv420,
        );
        
        await _controller!.initialize().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('Camera initialization timed out');
          },
        );

        if (mounted && _controller != null && _controller!.value.isInitialized) {
          _minAvailableZoom = await _controller!.getMinZoomLevel();
          _maxAvailableZoom = await _controller!.getMaxZoomLevel();
          
          // Enable autofocus for sharp images
          try {
            await _controller!.setFocusMode(FocusMode.auto);
          } catch (e) {
            debugPrint('Failed to set focus mode: $e');
          }
          
          setState(() {
            _isInitialized = true;
            _isInitializing = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _takePicture() async {
    if (!_isInitialized || _controller == null || _controller!.value.isTakingPicture) {
      return;
    }

    try {
      final XFile file = await _controller!.takePicture();
      await _processImage(File(file.path));
    } catch (e) {
      _showError('Failed to capture image: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        await _processImage(File(image.path));
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _processImage(File imageFile) async {
    // 1. Crop Image
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Question',
          toolbarColor: JVColors.primary,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'Crop Question',
          doneButtonTitle: 'Solve',
          cancelButtonTitle: 'Cancel',
          aspectRatioLockEnabled: false,
        ),
      ],
    );

    if (croppedFile == null) return; // User cancelled cropping

    try {
      final processedFile = File(croppedFile.path);
      
      // 3. Compress
      final compressedFile = await ImageCompressor.compressImage(processedFile);
      
      // 4. Start Solving (but don't wait)
      final solutionFuture = ApiService.solveQuestion(compressedFile);
      
      // 5. Dispose camera before navigation
      if (mounted) {
        setState(() {
          _isInitialized = false; // Prevent CameraPreview from rendering
        });
      }
      await _controller?.dispose();
      _controller = null;
      
      // 6. Navigate Immediately
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SolutionScreen(
              solutionFuture: solutionFuture,
              imageFile: processedFile, // Pass the cropped image
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to process image: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: JVColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _toggleFlash() {
    if (_controller != null) {
      setState(() {
        _flashMode = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
      });
      _controller!.setFlashMode(_flashMode);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: JVColors.primary)),
      );
    }

    if (!_isInitialized || _controller == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Camera not available',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializeCamera,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview with tap-to-focus
          GestureDetector(
            onTapDown: (TapDownDetails details) async {
              if (_controller != null && _controller!.value.isInitialized) {
                try {
                  // Calculate focus point (0.0 to 1.0)
                  final RenderBox renderBox = context.findRenderObject() as RenderBox;
                  final Offset localPosition = renderBox.globalToLocal(details.globalPosition);
                  final double x = localPosition.dx / renderBox.size.width;
                  final double y = localPosition.dy / renderBox.size.height;
                  
                  // Set focus point
                  await _controller!.setFocusPoint(Offset(x, y));
                  await _controller!.setFocusMode(FocusMode.auto);
                } catch (e) {
                  debugPrint('Failed to set focus point: $e');
                }
              }
            },
            child: Center(
              child: _controller != null && _controller!.value.isInitialized
                  ? CameraPreview(_controller!)
                  : const SizedBox.shrink(),
            ),
          ),

          // Grid Overlay
          CustomPaint(
            size: Size.infinite,
            painter: GridPainter(),
          ),

          // Overlay
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      IconButton(
                        icon: Icon(
                          _flashMode == FlashMode.off ? Icons.flash_off : Icons.flash_on,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: _toggleFlash,
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Instructions
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Center the question in the frame',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),

                const SizedBox(height: 32),

                // Controls
                Padding(
                  padding: const EdgeInsets.only(bottom: 40, left: 32, right: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Gallery Button
                      IconButton(
                        icon: const Icon(Icons.photo_library, color: Colors.white, size: 32),
                        onPressed: _pickImage,
                      ),

                      // Capture Button
                      GestureDetector(
                        onTap: _takePicture,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            color: Colors.white24,
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      // Spacer to balance layout
                      const SizedBox(width: 32),
                    ],
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

// Grid overlay painter
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1;

    // Draw grid lines (3x3)
    final thirdWidth = size.width / 3;
    final thirdHeight = size.height / 3;

    // Vertical lines
    canvas.drawLine(
      Offset(thirdWidth, 0),
      Offset(thirdWidth, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(thirdWidth * 2, 0),
      Offset(thirdWidth * 2, size.height),
      paint,
    );

    // Horizontal lines
    canvas.drawLine(
      Offset(0, thirdHeight),
      Offset(size.width, thirdHeight),
      paint,
    );
    canvas.drawLine(
      Offset(0, thirdHeight * 2),
      Offset(size.width, thirdHeight * 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


