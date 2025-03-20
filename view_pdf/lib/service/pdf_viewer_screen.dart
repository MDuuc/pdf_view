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

  const PDFViewerScreen({
    required this.filePath,
    this.imagePath,
    required this.imagePosition,
    required this.imageWidth,
    required this.imageHeight,
    required this.onPositionChanged,
    required this.onSizeChanged,
    Key? key,
  }) : super(key: key);

  @override
  _PDFViewerScreenState createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  late Offset _currentPosition;
  late double _currentWidth;
  late double _currentHeight;
  double _imageZoomLevel = 1.0; // Biến để theo dõi mức zoom của hình ảnh
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isSaving = false;
  bool _isLoading = true;
  late PDFViewController _pdfController;

  double _pdfWidthInPoints = 0;
  double _pdfHeightInPoints = 0;
  double _screenWidthInPixels = 0;
  double _screenHeightInPixels = 0;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.imagePosition;
    _currentWidth = widget.imageWidth;
    _currentHeight = widget.imageHeight;
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await Future.wait([
        _updateTotalPages(),
        _initializePdfDimensions(),
      ]);
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing PDF: $e')),
        );
      }
    }
  }

  Future<void> _updateTotalPages() async {
    try {
      final pdfFile = File(widget.filePath);
      if (!await pdfFile.exists()) {
        throw FileSystemException('PDF file not found');
      }
      final px.PdfDocument pdfDocument = await px.PdfDocument.openFile(pdfFile.path);
      setState(() {
        _totalPages = pdfDocument.pagesCount;
      });
      await pdfDocument.close();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _initializePdfDimensions() async {
    try {
      final pdfFile = File(widget.filePath);
      final px.PdfDocument pdfDocument = await px.PdfDocument.openFile(pdfFile.path);
      final page = await pdfDocument.getPage(1);
      setState(() {
        _pdfWidthInPoints = page.width.toDouble();
        _pdfHeightInPoints = page.height.toDouble();
      });
      await page.close();
      await pdfDocument.close();
    } catch (e) {
      rethrow;
    }
  }

  Offset _convertToPdfCoordinates(Offset flutterPosition) {
    if (_screenWidthInPixels == 0 || _screenHeightInPixels == 0) {
      return flutterPosition;
    }

    final scaleX = _pdfWidthInPoints / _screenWidthInPixels;
    final scaleY = _pdfHeightInPoints / _screenHeightInPixels;

    final double pdfX = (flutterPosition.dx * scaleX).clamp(0, _pdfWidthInPoints);
    final double pdfY = (_pdfHeightInPoints - (flutterPosition.dy * scaleY)).clamp(0, _pdfHeightInPoints);
    return Offset(pdfX, pdfY);
  }

  Size _convertToPdfSize(double width, double height) {
    const double dpiFactor = 1.75;
    // Áp dụng zoom level vào kích thước khi lưu
    final double pdfWidth = (width * dpiFactor * _imageZoomLevel).clamp(50, _pdfWidthInPoints);
    final double pdfHeight = (height * dpiFactor * _imageZoomLevel).clamp(50, _pdfHeightInPoints);
    return Size(pdfWidth, pdfHeight);
  }

  Future<void> _savePDF() async {
    if (widget.imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image to save')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final pdfFile = File(widget.filePath);
      final px.PdfDocument pdfDocument = await px.PdfDocument.openFile(pdfFile.path);
      final pdf = pw.Document();

      final imageBytes = await File(widget.imagePath!).readAsBytes();
      final pw.MemoryImage overlayImage = pw.MemoryImage(imageBytes);

      final pdfPosition = _convertToPdfCoordinates(_currentPosition);
      final pdfSize = _convertToPdfSize(_currentWidth, _currentHeight);

      for (int i = 1; i <= pdfDocument.pagesCount; i++) {
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
                  pw.Image(pw.MemoryImage(pageBytes)),
                  if (context.pageNumber == _currentPage)
                    pw.Positioned(
                    left: pdfPosition.dx + (35 * _imageZoomLevel),
                      bottom: pdfPosition.dy - pdfSize.height - (12 * _imageZoomLevel),
                      child: pw.Image(
                        overlayImage,
                        width: pdfSize.width,
                        height: pdfSize.height,
                      ),
                    ),
                ],
              );
            },
          ),
        );
        await page.close();
      }

      final outputDir = await getApplicationDocumentsDirectory();
      final newPdfPath =
          "${outputDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.pdf";
      final newPdfFile = File(newPdfPath);
      await newPdfFile.writeAsBytes(await pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF saved at $newPdfPath')),
        );
        Navigator.pop(context, newPdfPath);
      }

      await pdfDocument.close();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving PDF: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _screenWidthInPixels = MediaQuery.of(context).size.width;
    _screenHeightInPixels = MediaQuery.of(context).size.height -
        AppBar().preferredSize.height -
        MediaQuery.of(context).padding.top;

    return Scaffold(
      appBar: AppBar(
        title: const Text("View and Edit PDF"),
        actions: [
          IconButton(
            icon: const Icon(Icons.navigate_before),
            onPressed: _currentPage > 1 ? () => _pdfController.setPage(_currentPage - 2) : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text('Page $_currentPage / $_totalPages'),
          ),
          IconButton(
            icon: const Icon(Icons.navigate_next),
            onPressed: _currentPage < _totalPages ? () => _pdfController.setPage(_currentPage) : null,
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () {
              setState(() {
                _imageZoomLevel = (_imageZoomLevel + 0.2).clamp(0.2, 2); // Zoom in
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () {
              setState(() {
                _imageZoomLevel = (_imageZoomLevel - 0.2).clamp(0.2, 2); // Zoom out
              });
            },
          ),
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _savePDF,
            tooltip: 'Save PDF',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                PDFView(
                  filePath: widget.filePath,
                  swipeHorizontal: false,
                  fitPolicy: FitPolicy.BOTH,
                  pageFling: true,
                  pageSnap: true,
                  autoSpacing: true,
                  onViewCreated: (PDFViewController controller) {
                    _pdfController = controller;
                  },
                  onPageChanged: (int? page, int? total) {
                    if (page != null) {
                      setState(() {
                        _currentPage = page + 1;
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
                          _imageZoomLevel = (_imageZoomLevel * details.scale).clamp(0.2, 2);
                        });
                      },
                      child: Draggable(
                        feedback: Opacity(
                          opacity: 0.7,
                          child: Image.file(
                            File(widget.imagePath!),
                            width: _currentWidth * _imageZoomLevel,
                            height: _currentHeight * _imageZoomLevel,
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
                              offset.dx.clamp(0, _screenWidthInPixels - (_currentWidth * _imageZoomLevel)),
                              (offset.dy - totalOffset).clamp(0, _screenHeightInPixels - (_currentHeight * _imageZoomLevel)),
                            );
                            widget.onPositionChanged(_currentPosition);
                          });
                        },
                        child: Image.file(
                          File(widget.imagePath!),
                          width: _currentWidth * _imageZoomLevel,
                          height: _currentHeight * _imageZoomLevel,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}