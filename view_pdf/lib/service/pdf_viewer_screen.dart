import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;
import 'package:path_provider/path_provider.dart';

/// Constants for PDF processing
class PdfConstants {
  static const double dpiFactor = 1.25;
  static const double minDimension = 50.0;
  static const int margin = 8;
  static const double zoomStep = 0.2;
}

/// A screen for viewing and editing a PDF with an overlay image.
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
    super.key,
  });

  @override
  _PDFViewerScreenState createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  late PdfViewerController _controller;
  late ValueNotifier<Offset> _positionNotifier;
  late ValueNotifier<double> _zoomNotifier;
  late ValueNotifier<int> _pageIndexNotifier;
  late double _currentWidth;
  late double _currentHeight;
  bool _isSaving = false;
  bool _isLoading = true;
  String? _errorMessage;
  List<Size> _pageSizes = [];
  List<Rect> _pageLayouts = [];
  final GlobalKey _pdfViewerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
    _positionNotifier = ValueNotifier(widget.imagePosition);
    _zoomNotifier = ValueNotifier(1.0);
    _pageIndexNotifier = ValueNotifier(0);
    _currentWidth = widget.imageWidth;
    _currentHeight = widget.imageHeight;
    _controller.addListener(_onControllerChanged);
    _initialize();
  }

  /// Initializes PDF document and checks file access.
  Future<void> _initialize() async {
    try {
      await _checkFileAccess();
      if (_controller.document == null) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (_controller.document == null) {
          throw Exception('Failed to load PDF document');
        }
      }
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  /// Checks if the PDF and image files are accessible.
  Future<void> _checkFileAccess() async {
    final pdfFile = File(widget.filePath);
    if (!await pdfFile.exists()) {
      throw FileSystemException('PDF file not found at ${widget.filePath}');
    }
    final pdfBytes = await pdfFile.readAsBytes();
    if (pdfBytes.isEmpty) {
      throw FileSystemException('PDF file is empty');
    }

    if (widget.imagePath != null) {
      final imageFile = File(widget.imagePath!);
      if (!await imageFile.exists()) {
        throw FileSystemException('Image file not found at ${widget.imagePath}');
      }
    }
  }

  /// Handles changes in the PDF controller state.
  void _onControllerChanged() {
    if (_controller.document != null && _pageSizes.isEmpty) {
      setState(() {
        _pageSizes = _controller.document!.pages
            .map((page) => Size(page.width.toDouble(), page.height.toDouble()))
            .toList();
      });
      print('PDF loaded, page sizes: $_pageSizes');
    } else if (_controller.document == null && !_isLoading) {
      setState(() {
        _errorMessage = 'Failed to load PDF document';
      });
    }
  }

  /// Converts Flutter coordinates to PDF coordinates for a given page.
  Offset _convertToPdfCoordinates(Offset flutterPosition, int pageIndex) {
    if (_pageSizes.isEmpty || pageIndex >= _pageSizes.length || pageIndex < 0) {
      print('Warning: Invalid page or empty page sizes list');
      return flutterPosition;
    }

    final pageSize = _pageSizes[pageIndex];
    final pageLayout = _pageLayouts[pageIndex];
    final renderBox = _pdfViewerKey.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox == null) {
      print('Warning: RenderBox not available for PDF viewer');
      return flutterPosition;
    }

    final localPosition = renderBox.globalToLocal(flutterPosition);
    final relativeY = localPosition.dy - pageLayout.top;
    final scaleX = pageSize.width / pageLayout.width;
    final scaleY = pageSize.height / pageLayout.height;

    final pdfX = (localPosition.dx * scaleX).clamp(0, pageSize.width).toDouble();
    final pdfY = (relativeY * scaleY).clamp(0, pageSize.height).toDouble();

    print('Convert Flutter ($flutterPosition) -> PDF ($pdfX, $pdfY) on page $pageIndex');
    return Offset(pdfX, pdfY);
  }

  /// Converts PDF coordinates to Flutter coordinates for a given page.
  Offset _convertFromPdfToFlutterCoordinates(Offset pdfPosition, int pageIndex) {
    if (_pageSizes.isEmpty || pageIndex < 0 || pageIndex >= _pageSizes.length) {
      print('Warning: Invalid page or empty page sizes list');
      return pdfPosition;
    }

    final pageSize = _pageSizes[pageIndex];
    final pageLayout = _pageLayouts[pageIndex];
    final renderBox = _pdfViewerKey.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox == null) {
      print('Warning: RenderBox not available for PDF viewer');
      return pdfPosition;
    }

    final scaleX = pageLayout.width / pageSize.width;
    final scaleY = pageLayout.height / pageSize.height;

    final flutterX = pdfPosition.dx * scaleX;
    final flutterY = pageLayout.top + (pdfPosition.dy * scaleY);
    return Offset(flutterX, flutterY);
  }

  /// Converts Flutter image size to PDF size with DPI adjustment.
  Size _convertToPdfSize(double width, double height) {
    final pdfWidth = (width * PdfConstants.dpiFactor * _zoomNotifier.value)
        .clamp(PdfConstants.minDimension, _pageSizes[_pageIndexNotifier.value].width);
    final pdfHeight = (height * PdfConstants.dpiFactor * _zoomNotifier.value)
        .clamp(PdfConstants.minDimension, _pageSizes[_pageIndexNotifier.value].height);
    return Size(pdfWidth, pdfHeight);
  }

  /// Finds the page index corresponding to a global offset.
  int _findPageIndex(Offset globalOffset) {
    final renderBox = _pdfViewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      print('Warning: RenderBox not available for PDF viewer');
      return _pageIndexNotifier.value;
    }

    final localPosition = renderBox.globalToLocal(globalOffset);
    for (int i = 0; i < _pageLayouts.length; i++) {
      final layout = _pageLayouts[i];
      if (localPosition.dy >= layout.top &&
          localPosition.dy <= layout.bottom &&
          localPosition.dx >= layout.left &&
          localPosition.dx <= layout.right) {
        print('Found page: $i at offset: $globalOffset');
        return i;
      }
    }

    print('No page found, returning current: ${_pageIndexNotifier.value}');
    return _pageIndexNotifier.value;
  }

  /// Saves the edited PDF with the overlay image using syncfusion.
  Future<void> _savePDF() async {
    if (widget.imagePath == null) {
      _showSnackBar('Please select an image to save');
      return;
    }

    final shouldSave = await _showSaveConfirmationDialog();
    if (!shouldSave) return;

    setState(() => _isSaving = true);

    syncfusion.PdfDocument? pdf;
    try {
      pdf = syncfusion.PdfDocument(inputBytes: await File(widget.filePath).readAsBytes());
      final imageBytes = await File(widget.imagePath!).readAsBytes();
      final pdfImage = syncfusion.PdfBitmap(imageBytes);
      final pdfPosition = _positionNotifier.value;
      final pdfSize = _convertToPdfSize(_currentWidth, _currentHeight);

      final page = pdf.pages[_pageIndexNotifier.value];
      page.graphics.drawImage(
        pdfImage,
        Rect.fromLTWH(
          pdfPosition.dx,
          pdfPosition.dy,
          pdfSize.width,
          pdfSize.height,
        ),
      );

      final outputDir = await getApplicationDocumentsDirectory();
      final newPdfPath = "${outputDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.pdf";
      final newPdfFile = File(newPdfPath);
      await newPdfFile.writeAsBytes(await pdf.save());

      if (mounted) {
        _showSnackBar('PDF saved successfully at $newPdfPath');
        Navigator.pop(context, newPdfPath);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error saving PDF: $e');
      }
    } finally {
      pdf?.dispose();
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Shows a confirmation dialog before saving the PDF.
  Future<bool> _showSaveConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Save PDF'),
            content: const Text('Do you want to save the edited PDF?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Displays a snackbar with the given message.
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _positionNotifier.dispose();
    _zoomNotifier.dispose();
    _pageIndexNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sign Document',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade300,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              _zoomNotifier.value = (_zoomNotifier.value + PdfConstants.zoomStep).clamp(0.2, 2);
            },
            icon: const Icon(Icons.zoom_in, color: Colors.white),
            tooltip: 'Zoom In Signature',
          ),
          IconButton(
            onPressed: () {
              _zoomNotifier.value = (_zoomNotifier.value - PdfConstants.zoomStep).clamp(0.2, 2);
            },
            icon: const Icon(Icons.zoom_out, color: Colors.white),
            tooltip: 'Zoom Out Signature',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _savePDF,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save, size: 20, color: Colors.white),
              label: const Text('Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage ?? 'Loading PDF...',
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_errorMessage != null)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _errorMessage = null;
                          });
                          _initialize();
                        },
                        child: const Text('Retry'),
                      ),
                  ],
                ),
              )
            : Stack(
                children: [
                  PdfViewer.file(
                    widget.filePath,
                    key: _pdfViewerKey,
                    controller: _controller,
                    params: PdfViewerParams(
                      margin: PdfConstants.margin.toDouble(),
                      layoutPages: (pages, params) {
                        double offsetY = 0;
                        _pageLayouts = <Rect>[];
                        for (var page in pages) {
                          final rect = Rect.fromLTWH(0, offsetY, page.width, page.height);
                          _pageLayouts.add(rect);
                          offsetY += page.height + params.margin;
                        }
                        final documentHeight = pages.fold<double>(
                              0,
                              (sum, page) => sum + page.height + params.margin,
                            ) - params.margin;
                        final documentWidth = pages.isNotEmpty
                            ? pages.map((page) => page.width).reduce((a, b) => a > b ? a : b)
                            : 0.0;
                        return PdfPageLayout(
                          pageLayouts: _pageLayouts,
                          documentSize: Size(documentWidth, documentHeight),
                        );
                      },
                      onPageChanged: (pageNumber) {
                        if (pageNumber != null && pageNumber - 1 != _pageIndexNotifier.value) {
                          setState(() {
                            _pageIndexNotifier.value = pageNumber - 1;
                          });
                          print('Page changed to: ${_pageIndexNotifier.value}');
                        }
                      },
                    ),
                    initialPageNumber: 1,
                    passwordProvider: () async => null,
                  ),
                  if (widget.imagePath != null && File(widget.imagePath!).existsSync())
                    ValueListenableBuilder<int>(
                      valueListenable: _pageIndexNotifier,
                      builder: (context, pageIndex, child) {
                        return ValueListenableBuilder<Offset>(
                          valueListenable: _positionNotifier,
                          builder: (context, position, child) {
                            return ValueListenableBuilder<double>(
                              valueListenable: _zoomNotifier,
                              builder: (context, zoom, child) {
                                final flutterPosition =
                                    _convertFromPdfToFlutterCoordinates(position, pageIndex);
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
                                        duration: const Duration(milliseconds: 100),
                                        child: _buildImageContainer(zoom),
                                      ),
                                      childWhenDragging: Container(),
                                      onDragEnd: (details) {
                                        final newPageIndex = _findPageIndex(details.offset);
                                        final pdfPosition =
                                            _convertToPdfCoordinates(details.offset, newPageIndex);
                                        setState(() {
                                          _positionNotifier.value = pdfPosition;
                                          _pageIndexNotifier.value = newPageIndex;
                                        });
                                        _controller.goToPage(pageNumber: newPageIndex + 1);
                                        widget.onPositionChanged(pdfPosition);
                                        print('Moved to page: $newPageIndex, Position: $pdfPosition');
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
  }

  /// Builds the image container with zoom support.
  Widget _buildImageContainer(double zoom) {
    return Container(
      width: _currentWidth * zoom,
      height: _currentHeight * zoom,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.blue.shade700,
          width: 2,
        ),
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
                'Error loading image: $error',
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