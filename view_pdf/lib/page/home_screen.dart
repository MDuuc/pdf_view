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
                _imagePath = signaturePath; // Use signature as image
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
          'PDF Editor',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal.shade50, Colors.white],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Welcome Header
                Text(
                  'Chỉnh sửa PDF dễ dàng',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade900,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Chọn tệp, thêm chữ ký hoặc hình ảnh, và xem trước PDF.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.teal.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32),

                // PDF Button
                _buildActionCard(
                  icon: Icons.picture_as_pdf,
                  title: 'Chọn file PDF',
                  subtitle: _pdfPath != null
                      ? _pdfPath!.split('/').last
                      : 'Chưa chọn tệp PDF',
                  onTap: _isProcessing ? null : _pickPDF,
                  color: Colors.teal,
                ),

                // Image Button
                _buildActionCard(
                  icon: Icons.image,
                  title: 'Chọn ảnh',
                  subtitle: _imagePath != null
                      ? _imagePath!.split('/').last
                      : 'Chưa chọn hình ảnh',
                  onTap: _isProcessing ? null : _pickImage,
                  color: Colors.blue,
                ),

                // Signature Button
                _buildActionCard(
                  icon: Icons.edit,
                  title: 'Vẽ chữ ký',
                  subtitle: _imagePath != null && _imagePath!.contains('signature')
                      ? 'Chữ ký đã được vẽ'
                      : 'Tạo chữ ký mới',
                  onTap: _isProcessing ? null : _drawSignature,
                  color: Colors.purple,
                ),

                // View PDF Button
                _buildActionCard(
                  icon: Icons.visibility,
                  title: 'Xem PDF',
                  subtitle: 'Xem và chỉnh sửa PDF với hình ảnh hoặc chữ ký',
                  onTap: _isProcessing ? null : _viewPDF,
                  color: Colors.orange,
                ),

                // Open PDF Button
                _buildActionCard(
                  icon: Icons.open_in_new,
                  title: 'Mở file PDF',
                  subtitle: 'Mở PDF trong ứng dụng mặc định',
                  onTap: _isProcessing ? null : _openPDF,
                  color: Colors.green,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.1),
                  child: Icon(icon, color: color, size: 28),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal.shade900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}