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

  SignaturePad({required this.onSignatureSaved});

  @override
  _SignaturePadState createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  List<Offset?> points = [];

  Future<void> _saveSignature() async {
    if (points.isNotEmpty) {
      // Tính toán khung bao của chữ ký
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

        // Kích thước canvas và padding
        const double canvasWidth = 300;
        const double canvasHeight = 200;
        const double padding = 10;

        // Tính tỷ lệ thu nhỏ để chữ ký vừa với canvas (có padding)
        double scale = min((canvasWidth - 2 * padding) / bboxWidth, (canvasHeight - 2 * padding) / bboxHeight);

        // Tính toán offset để căn giữa chữ ký
        double offsetX = (canvasWidth - bboxWidth * scale) / 2;
        double offsetY = (canvasHeight - bboxHeight * scale) / 2;

        // Biến đổi các điểm
        List<Offset?> transformedPoints = points.map((point) {
          if (point == null) return null;
          double x = (point.dx - minX) * scale + offsetX;
          double y = (point.dy - minY) * scale + offsetY;
          return Offset(x, y);
        }).toList();

        // Vẽ chữ ký lên canvas với các điểm đã biến đổi
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, canvasWidth, canvasHeight));
        SignaturePainter(transformedPoints).paint(canvas, Size(canvasWidth, canvasHeight));
        final picture = recorder.endRecording();
        final img = await picture.toImage(canvasWidth.toInt(), canvasHeight.toInt());
        final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
        final buffer = byteData!.buffer.asUint8List();

        // Lưu file PNG
        final tempDir = await getTemporaryDirectory();
        final signaturePath = '${tempDir.path}/signature.png';
        await File(signaturePath).writeAsBytes(buffer);

        print("Saved signature at: $signaturePath");
        print("File size: ${File(signaturePath).lengthSync()} bytes");

        widget.onSignatureSaved(signaturePath);
        Navigator.pop(context);
      } else {
        print("No valid points to save");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please draw a signature before saving')),
        );
      }
    } else {
      print("Points list is empty");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please draw a signature before saving')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Draw Your Signature'),
      ),
      body: Container(
        color: Colors.white,
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black),
              ),
              child: ClipRect(
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      RenderBox renderBox = context.findRenderObject() as RenderBox;
                      Offset localPosition = renderBox.globalToLocal(details.globalPosition);
                      // Bù trừ lệch 20px (thử theo hướng dọc trước)
                      localPosition = Offset(localPosition.dx, localPosition.dy - 60); // Điều chỉnh Y
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
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _saveSignature,
            tooltip: 'Save Signature',
            child: Icon(Icons.save),
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            onPressed: () {
              setState(() {
                points.clear();
              });
            },
            tooltip: 'Clear',
            child: Icon(Icons.clear),
          ),
        ],
      ),
    );
  }
}