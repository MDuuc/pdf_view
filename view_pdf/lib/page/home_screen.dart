import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:view_pdf/page/signature_pad.dart';
import 'package:view_pdf/service/pdf_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _pdfPath;
  String? _imagePath;
  Offset _imagePosition = Offset(50, 50);
  double _imageWidth = 100;
  double _imageHeight = 100;
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

  // Open SignaturePad to draw signature
  Future<void> _drawSignature() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SignaturePad(
          onSignatureSaved: (signaturePath) {
            if (mounted) {
              setState(() {
                _imagePath = signaturePath;
              });
            }
          },
        ),
      ),
    );
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
          _pdfPath = result;
          _imagePath = null;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng chọn một file PDF')),
      );
    }
  }

  // Open PDF files in the program's default view
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
      appBar: AppBar(
        title: Text(
          'Tải tài liệu',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade300,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // PDF Selection Section
                Text(
                  'Ẩn để chọn file để tải lên',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue.shade200, style: BorderStyle.solid, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.upload_file, color: Colors.blue),
                      SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          _pickPDF();
                        },
                        child: Text(
                          'Chọn file',
                          style: TextStyle(color: Colors.blue, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),

                // Document Name
                Text(
                  'Tên tài liệu',
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _pdfPath != null ? _pdfPath!.split('/').last : 'Chưa chọn tệp PDF',
                          style: TextStyle(color: Colors.black54),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_pdfPath != null)
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey),
                          onPressed: () {
                            setState(() {
                              _pdfPath = null;
                            });
                          },
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 16),

                // Image and Signature Buttons (on the same row)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _pickImage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade100,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Chọn hình ảnh',
                          style: TextStyle(color: Colors.blue.shade900),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _drawSignature,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade100,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Vẽ chữ ký',
                          style: TextStyle(color: Colors.blue.shade900),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Image Name (always shown)
                Text(
                  'Tên ảnh',
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _imagePath != null ? _imagePath!.split('/').last : 'Chưa chọn hình ảnh',
                          style: TextStyle(color: Colors.black54),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_imagePath != null)
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey),
                          onPressed: () {
                            setState(() {
                              _imagePath = null;
                            });
                          },
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 16),

                // Open PDF Section (always shown)
                Text(
                  'Mở file PDF',
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _pdfPath != null ? _pdfPath!.split('/').last : 'Chưa chọn tệp PDF',
                          style: TextStyle(color: Colors.black54),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_pdfPath != null)
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _pdfPath = null;
                            });
                          },
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 32),

                // Continue Button
                ElevatedButton(
                  onPressed: _isProcessing ? null : _viewPDF,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade300,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Đi tiếp',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}