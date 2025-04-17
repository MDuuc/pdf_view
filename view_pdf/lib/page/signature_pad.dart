import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';

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

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  // Load list of points from JSON file
  Future<void> _loadPoints() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final pointsFile = File('${tempDir.path}/signature_points.json');
      if (await pointsFile.exists()) {
        final jsonString = await pointsFile.readAsString();
        final List<dynamic> jsonData = jsonDecode(jsonString);
        setState(() {
          points = jsonData.map((item) {
            if (item == null) return null;
            return Offset(item['dx'], item['dy']);
          }).toList();
        });
        print("Loaded points: ${points.length}");
      }
    } catch (e) {
      print("Error loading points: $e");
    }
  }

  // Save the points list to a JSON file
  Future<void> _savePoints() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final pointsFile = File('${tempDir.path}/signature_points.json');
      final jsonData = points.map((point) {
        if (point == null) return null;
        return {'dx': point.dx, 'dy': point.dy};
      }).toList();
      await pointsFile.writeAsString(jsonEncode(jsonData));
      print("Saved points to: ${pointsFile.path}");
    } catch (e) {
      print("Error saving points: $e");
    }
  }

  Future<void> _saveSignature() async {
    setState(() {
      _isSaving = true;
    });

    try {
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
          double scale = min(
              (canvasWidth - 2 * padding) / bboxWidth, (canvasHeight - 2 * padding) / bboxHeight);

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

          // Save file PNG with a random name
          final tempDir = await getTemporaryDirectory();
          final randomString = DateTime.now().millisecondsSinceEpoch.toString();
          final signaturePath = '${tempDir.path}/signature_$randomString.png';
          await File(signaturePath).writeAsBytes(buffer);

          // Save points to JSON
          await _savePoints();

          print("Saved signature at: $signaturePath");
          print("File size: ${File(signaturePath).lengthSync()} bytes");

          widget.onSignatureSaved(signaturePath);
          Navigator.pop(context);
        } else {
          print("No valid points to save");
          _showSnackBar('Vui lòng vẽ chữ ký trước khi lưu');
        }
      } else {
        print("Points list is empty");
        _showSnackBar('Vui lòng vẽ chữ ký trước khi lưu');
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
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
        backgroundColor: Colors.blue.shade700,
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
          'Vẽ chữ ký',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade300,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.delete, color: Colors.white),
            onPressed: points.isEmpty
                ? null
                : () async {
                    setState(() {
                      points.clear();
                    });
                    final tempDir = await getTemporaryDirectory();
                    final pointsFile = File('${tempDir.path}/signature_points.json');
                    if (await pointsFile.exists()) {
                      await pointsFile.delete();
                    }
                    _showSnackBar('Đã xóa chữ ký');
                  },
            tooltip: 'Xóa chữ ký',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Instruction Text
            Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Vẽ chữ ký của bạn bên dưới',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.blue.shade900,
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
                      color: Colors.blue.shade200,
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
                        : () async {
                            setState(() {
                              points.clear();
                            });
                            final tempDir = await getTemporaryDirectory();
                            final pointsFile = File('${tempDir.path}/signature_points.json');
                            if (await pointsFile.exists()) {
                              await pointsFile.delete();
                            }
                            _showSnackBar('Đã xóa chữ ký');
                          },
                    icon: Icon(Icons.clear, size: 20, color: Colors.white),
                    label: Text('Xóa'),
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
                        : Icon(Icons.save, size: 20, color: Colors.white),
                    label: Text('Lưu'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
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