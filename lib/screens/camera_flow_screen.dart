import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CameraFlowScreen extends StatefulWidget {
  const CameraFlowScreen({super.key});

  @override
  State<CameraFlowScreen> createState() => _CameraFlowScreenState();
}

class _CameraFlowScreenState extends State<CameraFlowScreen> {
  final List<XFile> _images = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Launch camera immediately on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _takePicture();
    });
  }

  Future<void> _takePicture() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 50,
        maxWidth: 1024,
      );
      if (photo != null) {
        setState(() {
          _images.add(photo);
        });
      } else if (_images.isEmpty) {
        // User backed out of the camera on the very first try without taking a photo
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint("Camera error: $e");
    }
  }

  void _finish() {
    if (_images.isEmpty) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pop(_images);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_images.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Pages'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.7,
              ),
              itemCount: _images.length,
              itemBuilder: (context, index) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_images[index].path),
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.black54,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                )
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFF10B981), width: 2),
                        foregroundColor: const Color(0xFF10B981),
                      ),
                      onPressed: _takePicture,
                      icon: const Icon(Icons.add_a_photo),
                      label: const Text('Add Page', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: _finish,
                      icon: const Icon(Icons.check),
                      label: const Text('Scan Now', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
