import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as px;

class PDFViewerScreen extends StatefulWidget {
  final String filePath;
  final String? imagePath;
  final Offset imagePosition;
  final double imageWidth;
  final double imageHeight;
  final Function(Offset) onPositionChanged;
  final Function(double, double) onSizeChanged;

  PDFViewerScreen({
    required this.filePath,
    this.imagePath,
    required this.imagePosition,
    required this.imageWidth,
    required this.imageHeight,
    required this.onPositionChanged,
    required this.onSizeChanged,
  });

  @override
  _PDFViewerScreenState createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  late Offset _currentPosition;
  late double _currentWidth;
  late double _currentHeight;
  int _selectedPage = 1; // Default page to add image
  int _totalPages = 1; // Total pages of the PDF
  bool _isSaving = false;
  late PDFViewController _pdfController; // Controller để điều khiển PDFView

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.imagePosition;
    _currentWidth = widget.imageWidth;
    _currentHeight = widget.imageHeight;
    _updateTotalPages(); // Get total number of pages when initializing
  }

  // Update total pages of the PDF
  Future<void> _updateTotalPages() async {
    final pdfFile = File(widget.filePath);
    final px.PdfDocument pdfDocument = await px.PdfDocument.openFile(pdfFile.path);
    setState(() {
      _totalPages = pdfDocument.pagesCount;
    });
    await pdfDocument.close();
  }

  // Save PDF with overlaid image
  Future<void> _savePDF() async {
    if (widget.imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng chọn một ảnh để lưu')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Open original PDF with pdfx and render as image
      final pdfFile = File(widget.filePath);
      final px.PdfDocument pdfDocument = await px.PdfDocument.openFile(pdfFile.path);
      final pdfPageCount = pdfDocument.pagesCount;

      // Create new PDF using pdf package
      final pdf = pw.Document();

      // Read image file to overlay
      final imageBytes = await File(widget.imagePath!).readAsBytes();
      final pw.MemoryImage overlayImage = pw.MemoryImage(imageBytes);

      // Unit conversion (assume 1 pixel = 1 point for simplicity)
      final double imgLeft = _currentPosition.dx;
      final double imgTop = _currentPosition.dy;
      final double imgWidth = _currentWidth;
      final double imgHeight = _currentHeight;

      // Add all pages from original PDF
      for (int i = 1; i <= pdfPageCount; i++) {
        final page = await pdfDocument.getPage(i);
        final pageImage = await page.render(
          width: page.width,
          height: page.height,
        );
        final pageBytes = pageImage!.bytes;

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(page.width, page.height),
            build: (pw.Context context) {
              return pw.Stack(
                children: [
                  // Original PDF page as image
                  pw.Image(pw.MemoryImage(pageBytes)),
                  // Add overlay image to the selected page
                  if (context.pageNumber == _selectedPage)
                    pw.Positioned(
                      left: imgLeft,
                      top: imgTop,
                      child: pw.Image(
                        overlayImage,
                        width: imgWidth,
                        height: imgHeight,
                      ),
                    ),
                ],
              );
            },
          ),
        );
        await page.close(); // Release resources
      }

      // Save new file
      final outputDir = await getApplicationDocumentsDirectory();
      final newPdfPath =
          "${outputDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.pdf";
      final newPdfFile = File(newPdfPath);
      await newPdfFile.writeAsBytes(await pdf.save());

      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF đã được lưu tại $newPdfPath')),
        );
        Navigator.pop(context, newPdfPath); // Return the new file path to HomeScreen
      }

      await pdfDocument.close(); // Release resources
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi lưu PDF: $e')),
        );
      }
    }
  }

  // Show dialog to select page
  Future<void> _showPageSelectorDialog() async {
    final TextEditingController pageController = TextEditingController(text: _selectedPage.toString());
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Chọn trang để thêm ảnh'),
          content: TextField(
            controller: pageController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Nhập số trang (1 - $_totalPages)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Hủy'),
            ),
            TextButton(
              onPressed: () async {
                final int? page = int.tryParse(pageController.text);
                if (page != null && page >= 1 && page <= _totalPages) {
                  setState(() {
                    _selectedPage = page;
                  });
                  await _pdfController.setPage(page - 1); // Switch to selected page (0-based index)
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Vui lòng nhập trang hợp lệ (1 - $_totalPages)')),
                  );
                }
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Xem và chỉnh sửa PDF"),
        actions: [
          IconButton(
            icon: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(Icons.save),
            onPressed: _isSaving ? null : _savePDF,
            tooltip: 'Lưu PDF',
          ),
          IconButton(
            icon: Icon(Icons.pageview),
            onPressed: _isSaving ? null : _showPageSelectorDialog,
            tooltip: 'Chọn trang',
          ),
        ],
      ),
      body: Stack(
        children: [
          PDFView(
            filePath: widget.filePath,
            swipeHorizontal: false,
            fitPolicy: FitPolicy.BOTH,
            autoSpacing: false,
            onViewCreated: (PDFViewController controller) {
              _pdfController = controller;
            },
            onPageChanged: (int? page, int? total) {
              if (page != null) {
                setState(() {
                  _selectedPage = page + 1; // Update selected page (1-based index)
                });
              }
            },
          ),
          if (widget.imagePath != null)
            Positioned(
              left: _currentPosition.dx,
              top: _currentPosition.dy,
              child: GestureDetector(
                onScaleUpdate: (details) {
                  setState(() {
                    _currentWidth = (_currentWidth * details.scale).clamp(50, 500);
                    _currentHeight = (_currentHeight * details.scale).clamp(50, 500);
                    widget.onSizeChanged(_currentWidth, _currentHeight);
                  });
                },
                child: Draggable(
                  feedback: Opacity(
                    opacity: 0.7,
                    child: Image.file(
                      File(widget.imagePath!),
                      width: _currentWidth,
                      height: _currentHeight,
                    ),
                  ),
                  childWhenDragging: Container(),
                  onDragEnd: (details) {
                    final renderBox = context.findRenderObject() as RenderBox?;
                    final offset = renderBox?.globalToLocal(details.offset) ?? details.offset;

                    final appBarHeight = AppBar().preferredSize.height;
                    final statusBarHeight = MediaQuery.of(context).padding.top;
                    final totalOffset = appBarHeight + statusBarHeight;

                    setState(() {
                      _currentPosition = Offset(
                        offset.dx,
                        offset.dy - totalOffset,
                      );
                      widget.onPositionChanged(_currentPosition);
                    });
                  },
                  child: Image.file(
                    File(widget.imagePath!),
                    width: _currentWidth,
                    height: _currentHeight,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}