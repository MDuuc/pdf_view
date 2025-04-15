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
  final GlobalKey _pdfViewKey = GlobalKey();
  late Offset _currentPosition;
  late double _currentWidth;
  late double _currentHeight;
  double _imageZoomLevel = 1.0;
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isSaving = false;
  bool _isLoading = true;
  late PDFViewController _pdfController;

  double _pdfWidthInPoints = 0;
  double _pdfHeightInPoints = 0;
  double _pdfViewWidthInPixels = 0;
  double _pdfViewHeightInPixels = 0;
  double _pdfContentWidthInPixels = 0;
  double _pdfContentHeightInPixels = 0;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.imagePosition;
    _currentWidth = widget.imageWidth;
    _currentHeight = widget.imageHeight;
    _initialize();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updatePdfViewSize());
  }

  // Asynchronously initialize the PDF viewer
  Future<void> _initialize() async {
    try {
      await Future.wait([
        _updateTotalPages(),
        _initializePdfDimensions(),
      ]);
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error initializing PDF: $e');
      }
    }
  }

  // Update the total number of pages in the PDF
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

  // Update the size of the PDF view
  void _updatePdfViewSize() {
    final RenderBox? renderBox = _pdfViewKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && mounted) {
      setState(() {
        _pdfViewWidthInPixels = renderBox.size.width;
        _pdfViewHeightInPixels = renderBox.size.height;

        final pdfAspectRatio = _pdfWidthInPoints / _pdfHeightInPoints;
        final viewAspectRatio = _pdfViewWidthInPixels / _pdfViewHeightInPixels;

        if (pdfAspectRatio > viewAspectRatio) {
          _pdfContentWidthInPixels = _pdfViewWidthInPixels;
          _pdfContentHeightInPixels = _pdfViewWidthInPixels / pdfAspectRatio;
        } else {
          _pdfContentHeightInPixels = _pdfViewHeightInPixels;
          _pdfContentWidthInPixels = _pdfViewHeightInPixels * pdfAspectRatio;
        }
      });
    }
  }

  // Initialize PDF dimensions
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

  // Convert Flutter screen coordinates to PDF coordinates
  Offset _convertToPdfCoordinates(Offset flutterPosition) {
    if (_pdfViewWidthInPixels == 0 || _pdfViewHeightInPixels == 0) {
      return flutterPosition;
    }
    final scaleX = _pdfWidthInPoints / _pdfContentWidthInPixels;
    final scaleY = _pdfHeightInPoints / _pdfContentHeightInPixels;

    final pdfContentTopOffset = (_pdfViewHeightInPixels - _pdfContentHeightInPixels) / 2;
    final adjustedY = flutterPosition.dy - pdfContentTopOffset;

    final double pdfX = (flutterPosition.dx * scaleX).clamp(0, _pdfWidthInPoints);
    final double pdfY = (_pdfHeightInPoints - (adjustedY * scaleY)).clamp(0, _pdfHeightInPoints);
    return Offset(pdfX, pdfY);
  }

  // Convert image size to PDF points
  Size _convertToPdfSize(double width, double height) {
    const double dpiFactor = 1.5;
    final double pdfWidth = (width * dpiFactor * _imageZoomLevel).clamp(50, _pdfWidthInPoints);
    final double pdfHeight = (height * dpiFactor * _imageZoomLevel).clamp(50, _pdfHeightInPoints);
    return Size(pdfWidth, pdfHeight);
  }

  // Save the modified PDF
Future<void> _savePDF() async {
  if (widget.imagePath == null) {
    _showSnackBar('Please select an image to save');
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
    double appBarHeight = AppBar().preferredSize.height;
    double padding_horizontal = 12;
    double padding_veritcal = 12;

    // Determine image file type
    final isJpg = widget.imagePath!.toLowerCase().endsWith('.jpg') ||
                  widget.imagePath!.toLowerCase().endsWith('.jpeg');

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
                    left: isJpg
                        ? pdfPosition.dx + (20 * _imageZoomLevel)
                        : pdfPosition.dx + _imageZoomLevel-padding_horizontal*2,
                    bottom: isJpg
                        ? pdfPosition.dy - pdfSize.height + appBarHeight / 2
                        : pdfPosition.dy - pdfSize.height + appBarHeight -padding_veritcal,
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
      _showSnackBar('PDF saved successfully');
      Navigator.pop(context, newPdfPath);
    }

    await pdfDocument.close();
  } catch (e) {
    if (mounted) {
      _showSnackBar('Error saving PDF: $e');
    }
  } finally {
    if (mounted) {
      setState(() => _isSaving = false);
    }
  }
}

  // Show snackbar with custom styling
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double padding_horizontal =12;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'PDF Editor',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
        centerTitle: true,
        actions: [
          // Page Navigation
          IconButton(
            icon: Icon(Icons.navigate_before),
            onPressed: _currentPage > 1 ? () => _pdfController.setPage(_currentPage - 2) : null,
            tooltip: 'Previous Page',
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: padding_horizontal, vertical: 8),
            margin: EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.teal.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$_currentPage / $_totalPages',
              style: TextStyle(
                color: Colors.teal.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.navigate_next),
            onPressed: _currentPage < _totalPages ? () => _pdfController.setPage(_currentPage) : null,
            tooltip: 'Next Page',
          ),
          // Zoom Controls
          IconButton(
            icon: Icon(Icons.zoom_in),
            onPressed: () {
              setState(() {
                _imageZoomLevel = (_imageZoomLevel + 0.2).clamp(0.2, 2);
              });
            },
            tooltip: 'Zoom In',
          ),
          IconButton(
            icon: Icon(Icons.zoom_out),
            onPressed: () {
              setState(() {
                _imageZoomLevel = (_imageZoomLevel - 0.2).clamp(0.2, 2);
              });
            },
            tooltip: 'Zoom Out',
          ),
          // Save Button
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _savePDF,
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
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        color: Colors.teal.shade50,
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.teal),
                    SizedBox(height: 16),
                    Text(
                      'Loading PDF...',
                      style: TextStyle(
                        color: Colors.teal.shade900,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            : Stack(
                children: [
                  // PDF Viewer
                  Card(
                    margin: EdgeInsets.all(16),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: PDFView(
                        key: _pdfViewKey,
                        filePath: widget.filePath,
                        swipeHorizontal: false,
                        fitPolicy: FitPolicy.BOTH,
                        pageFling: true,
                        pageSnap: true,
                        autoSpacing: true,
                        onViewCreated: (PDFViewController controller) {
                          _pdfController = controller;
                          WidgetsBinding.instance.addPostFrameCallback((_) => _updatePdfViewSize());
                        },
                        onPageChanged: (int? page, int? total) {
                          if (page != null) {
                            setState(() {
                              _currentPage = page + 1;
                            });
                          }
                        },
                        onError: (error) {
                          _showSnackBar('Error loading PDF: $error');
                        },
                      ),
                    ),
                  ),
                  // Draggable Image
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
                          feedback: AnimatedOpacity(
                            opacity: 0.7,
                            duration: Duration(milliseconds: 100),
                            child: _buildImageContainer(),
                          ),
                          childWhenDragging: Container(),
                          onDragEnd: (details) {
                            final renderBox = context.findRenderObject() as RenderBox?;
                            final offset = renderBox?.globalToLocal(details.offset) ?? details.offset;

                            final appBarHeight = AppBar().preferredSize.height;
                            final statusBarHeight = MediaQuery.of(context).padding.top;
                            final totalOffset = appBarHeight + statusBarHeight;

                            final pdfContentTopOffset = (_pdfViewHeightInPixels - _pdfContentHeightInPixels) / 2;
                            final pdfContentBottomOffset = pdfContentTopOffset + _pdfContentHeightInPixels;

                            setState(() {
                              _currentPosition = Offset(
                                offset.dx.clamp(12, _pdfContentWidthInPixels),
                                (offset.dy - totalOffset).clamp(pdfContentTopOffset, pdfContentBottomOffset - (_currentHeight * _imageZoomLevel)),
                              );
                              widget.onPositionChanged(_currentPosition);
                            });
                          },
                          child: _buildImageContainer(),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  // Build the image container with consistent styling
Widget _buildImageContainer() {
  return Container(
    width: _currentWidth * _imageZoomLevel,
    height: _currentHeight * _imageZoomLevel,
    decoration: BoxDecoration(
      border: Border.all(
        color: Colors.teal.shade700,
        width: 2,
      ),
      borderRadius: BorderRadius.circular(12),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.file(
        File(widget.imagePath!),
        width: _currentWidth * _imageZoomLevel,
        height: _currentWidth * _imageZoomLevel,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Text(
              'Error loading image',
              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          );
        },
      ),
    ),
  );
}
}