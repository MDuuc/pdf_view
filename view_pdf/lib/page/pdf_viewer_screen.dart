import 'dart:io';
import 'package:flutter/material.dart';
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
   GlobalKey _listViewKey = GlobalKey();
  late ValueNotifier<Offset> _positionNotifier;
  late ValueNotifier<double> _zoomNotifier;
  late ValueNotifier<int> _pageIndexNotifier;
  late double _currentWidth;
  late double _currentHeight;
  int _totalPages = 1;
  bool _isSaving = false;
  bool _isLoading = true;
  late px.PdfDocument _pdfDocument;
  List<Size> _pageSizes = [];
  List<GlobalKey> _pageKeys = [];

  @override
  void initState() {
    super.initState();
    _resetState();
  _initialize();
  }

  void _resetState() {
    _listViewKey = GlobalKey();
  _positionNotifier = ValueNotifier(widget.imagePosition);
  _zoomNotifier = ValueNotifier(1.0);
  _pageIndexNotifier = ValueNotifier(0);
  _currentWidth = widget.imageWidth;
  _currentHeight = widget.imageHeight;
  _pageSizes = [];
  _pageKeys = [];
  _totalPages = 1;
  _isLoading = true;
  _isSaving = false;
}

  Future<void> _initialize() async {
    try {
      await _initializePdfDocument();
      setState(() => _isLoading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageKeys.isNotEmpty && _pageKeys[0].currentContext != null) {
          Scrollable.ensureVisible(_pageKeys[0].currentContext!);
        }
      });
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error initializing PDF: $e');
      }
    }
  }

// Loads the PDF file, retrieves the total number of pages, and calculates the size of each page.
// Creates global keys for each page to track their positions in the UI.
  Future<void> _initializePdfDocument() async {
    try {
      final pdfFile = File(widget.filePath);
      if (!await pdfFile.exists()) {
        throw FileSystemException('PDF file not found');
      }
      _pdfDocument = await px.PdfDocument.openFile(pdfFile.path);
      _totalPages = _pdfDocument.pagesCount;
      _pageSizes = [];
      _pageKeys = List.generate(_totalPages, (_) => GlobalKey());
      for (int i = 1; i <= _totalPages; i++) {
        final page = await _pdfDocument.getPage(i);
        _pageSizes.add(Size(page.width.toDouble(), page.height.toDouble()));
        await page.close();
      }
    } catch (e) {
      rethrow;
    }
  }

// Converts Flutter widget coordinates to PDF coordinates for accurate placement of the overlay image.
// Takes into account the page size, scaling, and rendering context.
  Offset _convertToPdfCoordinates(Offset flutterPosition, int pageIndex) {
    if (_pageSizes.isEmpty || pageIndex >= _pageSizes.length) {
      return flutterPosition;
    }

    final pageSize = _pageSizes[pageIndex];
    final context = _pageKeys[pageIndex].currentContext;
    if (context == null || !mounted) return flutterPosition;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return flutterPosition;

    final pageSizeInPixels = renderBox.size;
    final scaleX = pageSizeInPixels.width > 0 ? pageSize.width / pageSizeInPixels.width : 1.0;
    final scaleY = pageSizeInPixels.height > 0 ? pageSize.height / pageSizeInPixels.height : 1.0;

    final localPosition = renderBox.globalToLocal(flutterPosition);
    final adjustedDy = localPosition.dy.clamp(0.0, pageSizeInPixels.height);
    final pdfSize = _convertToPdfSize(_currentWidth, _currentHeight);
    final double pdfX = (localPosition.dx * scaleX).clamp(0, pageSize.width - pdfSize.width);
    final double pdfY = (pageSize.height - (adjustedDy * scaleY)).clamp(pdfSize.height, pageSize.height);

    print('Coordinate conversion:');
    print('  pageSize: $pageSize');
    print('  pageSizeInPixels: $pageSizeInPixels');
    print('  scaleX: $scaleX, scaleY: $scaleY');
    print('  flutterPosition: $flutterPosition');
    print('  localPosition: $localPosition');
    print('  adjustedDy: $adjustedDy');
    print('  pdfX: $pdfX, pdfY: $pdfY');

    return Offset(pdfX, pdfY);
  }

// Converts PDF coordinates back to Flutter widget coordinates for rendering the overlay image
// in the correct position on the screen.
  Offset _convertFromPdfToFlutterCoordinates(Offset pdfPosition, int pageIndex) {
    if (_pageSizes.isEmpty || pageIndex >= _pageSizes.length) {
      return pdfPosition;
    }
    final pageSize = _pageSizes[pageIndex];
    final context = _pageKeys[pageIndex].currentContext;
    if (context == null) return pdfPosition;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return pdfPosition;

    final pageSizeInPixels = renderBox.size;
    final scaleX = pageSizeInPixels.width > 0 ? pageSize.width / pageSizeInPixels.width : 1.0;
    final scaleY = pageSizeInPixels.height > 0 ? pageSize.height / pageSizeInPixels.height : 1.0;

    final double flutterX = pdfPosition.dx / scaleX;
    final double flutterY = ((pageSize.height - pdfPosition.dy) / scaleY).clamp(0, pageSizeInPixels.height);
    return Offset(flutterX, flutterY);
  }

// Converts the image size from Flutter dimensions to PDF dimensions, applying a DPI factor
// and zoom level, ensuring the size stays within page boundaries.
  Size _convertToPdfSize(double width, double height) {
    const double dpiFactor = 1.5;
    final double pdfWidth = (width * dpiFactor * _zoomNotifier.value).clamp(50, _pageSizes[_pageIndexNotifier.value].width);
    final double pdfHeight = (height * dpiFactor * _zoomNotifier.value).clamp(50, _pageSizes[_pageIndexNotifier.value].height);
    return Size(pdfWidth, pdfHeight);
  }

// Saves the modified PDF with the overlay image placed on the specified page at the specified position.
// Creates a new PDF file and writes it to the application documents directory.
  Future<void> _savePDF() async {
    if (widget.imagePath == null) {
      _showSnackBar('Please select an image to save');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final pdf = pw.Document();
      final imageBytes = await File(widget.imagePath!).readAsBytes();
      final pw.MemoryImage overlayImage = pw.MemoryImage(imageBytes);

      final pdfPosition = _convertToPdfCoordinates(_positionNotifier.value, _pageIndexNotifier.value);
      final pdfSize = _convertToPdfSize(_currentWidth, _currentHeight);

      for (int i = 1; i <= _totalPages; i++) {
        final page = await _pdfDocument.getPage(i);
        final pageImage = await page.render(
          width: page.width * 2, 
          height: page.height * 2,
        );
        final pageBytes = pageImage!.bytes;

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(page.width, page.height),
            build: (pw.Context context) {
              return pw.Stack(
                children: [
                  pw.Image(pw.MemoryImage(pageBytes), fit: pw.BoxFit.contain),
                  if (context.pageNumber == _pageIndexNotifier.value + 1)
                    pw.Positioned(
                      left: pdfPosition.dx,
                      bottom: pdfPosition.dy - 0.84*pdfSize.height,
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
      final newPdfPath = "${outputDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.pdf";
      final newPdfFile = File(newPdfPath);
      await newPdfFile.writeAsBytes(await pdf.save());

      if (mounted) {
      widget.onPositionChanged(Offset(50, 50));
      widget.onSizeChanged(100, 100);
      _pdfDocument.close();
      _resetState();
        _showSnackBar('PDF saved successfully');
        Navigator.pop(context, newPdfPath);
      }
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

// Displays a snackbar with the provided message, styled with a blue background and rounded corners.
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }


// Renders a specific PDF page as an image for display in the UI Closes the page after rendering.
  Future<px.PdfPageImage> _renderPage(int pageNumber) async {
    final page = await _pdfDocument.getPage(pageNumber);
    final pageImage = await page.render(
      width: page.width,
      height: page.height,
    );
    await page.close();
    return pageImage!;
  }

// Determines which PDF page the dragged image is over based on the global offset.
// Returns the index of the page or the current page if no valid page is found.
int _findPageIndex(Offset globalOffset) {
  for (int i = 0; i < _pageKeys.length; i++) {
    final context = _pageKeys[i].currentContext;
    if (context == null || !context.mounted) continue;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final position = renderBox.globalToLocal(globalOffset);
      if (position.dx >= 0 &&
          position.dx <= renderBox.size.width &&
          position.dy >= 0 &&
          position.dy <= renderBox.size.height) {
        print("Image is on page: ${i + 1}"); 
        return i;
      }
    }
  }
  print("No matching page found, returning current page: ${_pageIndexNotifier.value + 1}");
  return _pageIndexNotifier.value;
}

// Builds the container for the overlay image, applying zoom, borders, and rounded corners.
// Handles image loading errors gracefully.
  Widget _buildImageContainer(double zoom) {
    return Container(
      width: _currentWidth * zoom,
      height: _currentHeight * zoom,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade700, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(widget.imagePath!),
          width: _currentWidth * zoom,
          height: _currentHeight * zoom,
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
  @override
  void dispose() {
    _pdfDocument.close();
    _positionNotifier.dispose();
    _zoomNotifier.dispose();
    _pageIndexNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sign Document', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue.shade300,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.zoom_in, color: Colors.white),
            onPressed: () {
              _zoomNotifier.value = (_zoomNotifier.value + 0.2).clamp(0.2, 2);
            },
            tooltip: 'Zoom In',
          ),
          IconButton(
            icon: Icon(Icons.zoom_out, color: Colors.white),
            onPressed: () {
              _zoomNotifier.value = (_zoomNotifier.value - 0.2).clamp(0.2, 2);
            },
            tooltip: 'Zoom Out',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _savePDF,
              icon: _isSaving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(Icons.save, size: 20, color: Colors.white),
              label: Text('Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
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
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.blue.shade700),
                    SizedBox(height: 16),
                    Text(
                      'Loading PDF...',
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                key: _listViewKey,
                // key: ValueKey(widget.filePath), 
                itemCount: _totalPages,
                itemBuilder: (context, index) {
                  _pageKeys[index] = GlobalKey();
                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          FutureBuilder<px.PdfPageImage>(
                            future: _renderPage(index + 1),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Container(
                                  height: 400,
                                  child: Center(child: CircularProgressIndicator(color: Colors.blue.shade700)),
                                );
                              }
                              if (snapshot.hasError) {
                                return Center(
                                  child: Text(
                                    'Error loading page ${index + 1}',
                                    style: TextStyle(color: Colors.red.shade700),
                                  ),
                                );
                              }
                              return Container(
                                key: _pageKeys[index],
                                child: Image.memory(
                                  snapshot.data!.bytes,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  scale: 1 / _zoomNotifier.value, 
                                ),
                              );
                            },
                          ),
                          if (widget.imagePath != null)
                            ValueListenableBuilder<int>(
                              valueListenable: _pageIndexNotifier,
                              builder: (context, pageIndex, child) {
                                if (index != pageIndex) return SizedBox.shrink();
                                return ValueListenableBuilder<Offset>(
                                  valueListenable: _positionNotifier,
                                  builder: (context, position, child) {
                                    return ValueListenableBuilder<double>(
                                      valueListenable: _zoomNotifier,
                                      builder: (context, zoom, child) {
                                        final flutterPosition = _convertFromPdfToFlutterCoordinates(position, pageIndex);
                                        return Positioned(
                                          left: flutterPosition.dx,
                                          top: flutterPosition.dy,
                                          child: GestureDetector(
                                            onScaleUpdate: (details) {
                                              _zoomNotifier.value = (_zoomNotifier.value * details.scale).clamp(0.2, 2);
                                            },
                                            child: Draggable(
                                              feedback: AnimatedOpacity(
                                                opacity: 0.7,
                                                duration: Duration(milliseconds: 100),
                                                child: _buildImageContainer(zoom),
                                              ),
                                              childWhenDragging: Container(),
                                              onDragEnd: (details) {
                                                int newPageIndex = _findPageIndex(details.offset);
                                                final context = _pageKeys[newPageIndex].currentContext;
                                                if (context != null && context.mounted) {
                                                  final renderBox = context.findRenderObject() as RenderBox?;
                                                  if (renderBox != null) {
                                                     renderBox.globalToLocal(details.offset);
                                                    final pdfPosition = _convertToPdfCoordinates(details.offset, newPageIndex);
                                                    _positionNotifier.value = pdfPosition;
                                                    _pageIndexNotifier.value = newPageIndex;
                                                    widget.onPositionChanged(pdfPosition);
                                                  }
                                                }
                                              },
                                              child: _buildImageContainer(zoom),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}