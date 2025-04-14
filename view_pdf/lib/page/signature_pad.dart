import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// Custom painter class for drawing the signature
class SignaturePainter extends CustomPainter {
  final List<Offset?> points;

  SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) => true;
}

class SignaturePad extends StatefulWidget {
  final Function(String) onSignatureSaved;

  const SignaturePad({required this.onSignatureSaved, Key? key}) : super(key: key);

  @override
  _SignaturePadState createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  List<Offset?> points = [];
  bool _isSaving = false;

  Future<void> _saveSignature() async {
    if (points.isNotEmpty) {
      // Calculate signature frame
      double minX = double.infinity;
      double minY = double.infinity;
      double maxX = -double.infinity;
      double maxY = -double.infinity;

      for (var point in points) {
        if (point != null) {
          if (point.dx < minX) minX = point.dx;
          if (point.dy < minY) minY = point.dy;
          if (point.dx > maxX) maxX = point.dx;
          if (point.dy > maxY) maxY = point.dy;
        }
      }

      if (minX.isFinite && minY.isFinite && maxX.isFinite && maxY.isFinite) {
        double bboxWidth = maxX - minX;
        double bboxHeight = maxY - minY;

        // Canvas size and padding
        const double canvasWidth = 300;
        const double canvasHeight = 200;
        const double padding = 10;

      // Calculate the shrink ratio so that the signature fits the canvas (with padding)
        double scale = min((canvasWidth - 2 * padding) / bboxWidth, (canvasHeight - 2 * padding) / bboxHeight);

        // Calculate offset to center signature
        double offsetX = (canvasWidth - bboxWidth * scale) / 2;
        double offsetY = (canvasHeight - bboxHeight * scale) / 2;

        // Transform the points
        List<Offset?> transformedPoints = points.map((point) {
          if (point == null) return null;
          double x = (point.dx - minX) * scale + offsetX;
          double y = (point.dy - minY) * scale + offsetY;
          return Offset(x, y);
        }).toList();

        // Draw the signature on the canvas with transformed points
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, canvasWidth, canvasHeight));
        SignaturePainter(transformedPoints).paint(canvas, Size(canvasWidth, canvasHeight));
        final picture = recorder.endRecording();
        final img = await picture.toImage(canvasWidth.toInt(), canvasHeight.toInt());
        final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
        final buffer = byteData!.buffer.asUint8List();

        // Save file PNG
        final tempDir = await getTemporaryDirectory();
        final signaturePath = '${tempDir.path}/signature.png';
        await File(signaturePath).writeAsBytes(buffer);

        print("Saved signature at: $signaturePath");
        print("File size: ${File(signaturePath).lengthSync()} bytes");

        widget.onSignatureSaved(signaturePath);
        Navigator.pop(context);
      } else {
        print("No valid points to save");
        _showSnackBar('Please draw a signature before saving');
      }
    } else {
      print("Points list is empty");
      _showSnackBar('Please draw a signature before saving');
    }
  }

  // Show styled snackbar
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.teal.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Draw Your Signature',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: points.isEmpty
                ? null
                : () {
                    setState(() {
                      points.clear();
                    });
                    _showSnackBar('Signature cleared');
                  },
            tooltip: 'Clear Signature',
          ),
        ],
      ),
      body: Container(
        color: Colors.teal.shade50,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Instruction Text
            Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Draw your signature below',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.teal.shade900,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Signature Area
            Expanded(
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.teal.shade200,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        setState(() {
                          RenderBox renderBox = context.findRenderObject() as RenderBox;
                          Offset localPosition = renderBox.globalToLocal(details.globalPosition);
                          //change Postion of drawing
                          double appBarHeight = AppBar().preferredSize.height; 
                          double statusBarHeight = MediaQuery.of(context).padding.top; 
                          double paddingTop = 16; 
                          localPosition = Offset(
                            localPosition.dx - 16, 
                            localPosition.dy - (appBarHeight + statusBarHeight + paddingTop),
                          );
                          points.add(localPosition);
                        });
                      },
                      onPanEnd: (details) {
                        points.add(null);
                      },
                      child: CustomPaint(
                        painter: SignaturePainter(points),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Action Buttons
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: points.isEmpty
                        ? null
                        : () {
                            setState(() {
                              points.clear();
                            });
                            _showSnackBar('Signature cleared');
                          },
                    icon: Icon(Icons.clear, size: 20, color: Colors.white,),
                    label: Text('Clear'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveSignature,
                    icon: _isSaving
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(Icons.save, size: 20, color: Colors.white,),
                    label: Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}