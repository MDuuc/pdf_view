import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:view_pdf/service/pdf_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _pdfPath;
  String? _imagePath;
  Offset _imagePosition = Offset(50, 50); // Default image position
  double _imageWidth = 100; // Default image width
  double _imageHeight = 100; // Default image height
  bool _isProcessing = false;

  // Choose file PDF from device
  Future<void> _pickPDF() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && mounted) {
      setState(() {
        _pdfPath = result.files.single.path;
      });
    }
  }

  // Choose image from device
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null && mounted) {
      setState(() {
        _imagePath = image.path;
      });
    }
  }

  // View PDF file with overlaid image and update _pdfPath if saved
  void _viewPDF() async {
    if (_pdfPath != null) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PDFViewerScreen(
            filePath: _pdfPath!,
            imagePath: _imagePath,
            imagePosition: _imagePosition,
            imageWidth: _imageWidth,
            imageHeight: _imageHeight,
            onPositionChanged: (newPosition) {
              if (mounted) setState(() => _imagePosition = newPosition);
            },
            onSizeChanged: (newWidth, newHeight) {
              if (mounted) setState(() {
                _imageWidth = newWidth;
                _imageHeight = newHeight;
              });
            },
          ),
        ),
      );
      if (result != null && mounted) {
        setState(() {
          _pdfPath = result; // Update _pdfPath with the new saved file path
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng chọn một file PDF')),
      );
    }
  }

  // Open PDF files in the program's default view (will open the latest _pdfPath)
  void _openPDF() {
    if (_pdfPath != null) {
      OpenFile.open(_pdfPath!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng chọn một file PDF')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('PDF Editor')),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _isProcessing ? null : _pickPDF,
                child: Text('Chọn file PDF'),
              ),
              if (_pdfPath != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('PDF: ${_pdfPath!.split('/').last}'),
                ),
              ElevatedButton(
                onPressed: _isProcessing ? null : _pickImage,
                child: Text('Chọn ảnh'),
              ),
              if (_imagePath != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('Ảnh: ${_imagePath!.split('/').last}'),
                ),
              ElevatedButton(
                onPressed: _isProcessing ? null : _viewPDF,
                child: Text('Xem PDF'),
              ),
              ElevatedButton(
                onPressed: _isProcessing ? null : _openPDF,
                child: Text('Mở file PDF'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}