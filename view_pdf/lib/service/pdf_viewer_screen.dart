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
  final GlobalKey _listViewKey = GlobalKey();
  late ValueNotifier<Offset> _positionNotifier;
  late ValueNotifier<double> _zoomNotifier;
  late ValueNotifier<int> _pageIndexNotifier;
  late double _currentWidth;
  late double _currentHeight;
  int _currentPage = 0;
  int _totalPages = 1;
  bool _isSaving = false;
  bool _isLoading = true;
  late px.PdfDocument _pdfDocument;
  List<Size> _pageSizes = [];
  List<GlobalKey> _pageKeys = [];

  @override
  void initState() {
    super.initState();
    _positionNotifier = ValueNotifier(widget.imagePosition);
    _zoomNotifier = ValueNotifier(1.0);
    _pageIndexNotifier = ValueNotifier(_currentPage);
    _currentWidth = widget.imageWidth;
    _currentHeight = widget.imageHeight;
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _initializePdfDocument();
      setState(() => _isLoading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageKeys.isNotEmpty && _pageKeys[1].currentContext != null) {
          Scrollable.ensureVisible(_pageKeys[1].currentContext!);
        }
      });
    } catch (e) {
      if (mounted) {
        _showSnackBar('Lỗi khi khởi tạo PDF: $e');
      }
    }
  }

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

  Offset _convertToPdfCoordinates(Offset flutterPosition, int pageIndex) {
    if (_pageSizes.isEmpty || pageIndex < 0 || pageIndex >= _pageSizes.length) {
      print('Invalid page index or empty page sizes: $pageIndex');
      return flutterPosition;
    }

    final pageSize = _pageSizes[pageIndex];
    final context = _pageKeys[pageIndex].currentContext;

    if (context == null) {
      print('Context is null for page $pageIndex');
      return flutterPosition;
    }

    RenderBox? renderBox;
    try {
      renderBox = context.findRenderObject() as RenderBox?;
    } catch (e) {
      print('Error getting renderObject for page $pageIndex: $e');
      return flutterPosition;
    }

    if (renderBox == null) {
      print('RenderBox not found for page $pageIndex');
      return flutterPosition;
    }

    final pageSizeInPixels = renderBox.size;
    final scaleX = pageSizeInPixels.width > 0 ? pageSize.width / pageSizeInPixels.width : 1.0;
    final scaleY = pageSizeInPixels.height > 0 ? pageSize.height / pageSizeInPixels.height : 1.0;

    final localPosition = renderBox.globalToLocal(flutterPosition);
    final adjustedDy = localPosition.dy.clamp(0.0, pageSizeInPixels.height);
    final double pdfX = (localPosition.dx * scaleX).clamp(0, pageSize.width);
    final double pdfY = (pageSize.height - (adjustedDy * scaleY)).clamp(0, pageSize.height);

    print('Page $pageIndex:');
    print('  pageSize: $pageSize');
    print('  pageSizeInPixels: $pageSizeInPixels');
    print('  scaleX: $scaleX, scaleY: $scaleY');
    print('  flutterPosition: $flutterPosition');
    print('  localPosition: $localPosition');
    print('  adjustedDy: $adjustedDy');
    print('  pdfX: $pdfX, pdfY: $pdfY');

    return Offset(pdfX, pdfY);
  }

  Offset _convertFromPdfToFlutterCoordinates(Offset pdfPosition, int pageIndex) {
    if (_pageSizes.isEmpty || pageIndex < 0 || pageIndex >= _pageSizes.length) {
      return pdfPosition;
    }
    final pageSize = _pageSizes[pageIndex];
    final context = _pageKeys[pageIndex].currentContext;

    if (context == null) {
      return pdfPosition;
    }

    RenderBox? renderBox;
    try {
      renderBox = context.findRenderObject() as RenderBox?;
    } catch (e) {
      print('Error getting renderObject for page $pageIndex: $e');
      return pdfPosition;
    }

    if (renderBox == null) {
      return pdfPosition;
    }

    final pageSizeInPixels = renderBox.size;
    final scaleX = pageSizeInPixels.width > 0 ? pageSize.width / pageSizeInPixels.width : 1.0;
    final scaleY = pageSizeInPixels.height > 0 ? pageSize.height / pageSizeInPixels.height : 1.0;

    final double flutterX = pdfPosition.dx / scaleX;
    final double flutterY = ((pageSize.height - pdfPosition.dy) / scaleY).clamp(0, pageSizeInPixels.height);
    return Offset(flutterX, flutterY);
  }

  Size _convertToPdfSize(double width, double height) {
    const double dpiFactor = 1.5;
    final double pdfWidth = (width * dpiFactor * _zoomNotifier.value).clamp(50, _pageSizes[_pageIndexNotifier.value].width);
    final double pdfHeight = (height * dpiFactor * _zoomNotifier.value).clamp(50, _pageSizes[_pageIndexNotifier.value].height);
    return Size(pdfWidth, pdfHeight);
  }

  Future<void> _savePDF() async {
    if (widget.imagePath == null) {
      _showSnackBar('Vui lòng chọn hình ảnh để lưu');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final pdf = pw.Document();
      final imageBytes = await File(widget.imagePath!).readAsBytes();
      final pw.MemoryImage overlayImage = pw.MemoryImage(imageBytes);

      final pdfPosition = _convertToPdfCoordinates(_positionNotifier.value, _pageIndexNotifier.value);
      final pdfSize = _convertToPdfSize(_currentWidth, _currentHeight);
      final isJpg = widget.imagePath!.toLowerCase().endsWith('.jpg') ||
          widget.imagePath!.toLowerCase().endsWith('.jpeg');

      print('Saving PDF: pdfPosition: $pdfPosition, pdfSize: $pdfSize, pageIndex: ${_pageIndexNotifier.value}');

      for (int i = 1; i <= _totalPages; i++) {
        final page = await _pdfDocument.getPage(i);
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
                  if (context.pageNumber == _pageIndexNotifier.value + 1)
                    pw.Positioned(
                      left: isJpg
                          ? pdfPosition.dx + (20 * _zoomNotifier.value)
                          : pdfPosition.dx + _zoomNotifier.value,
                      bottom: pdfPosition.dy - pdfSize.height,
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
        _showSnackBar('Đã lưu PDF thành công');
        Navigator.pop(context, newPdfPath);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Lỗi khi lưu PDF: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

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
        title: Text(
          'Ký tài liệu',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade300,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.zoom_in, color: Colors.white),
            onPressed: () {
              _zoomNotifier.value = (_zoomNotifier.value + 0.2).clamp(0.2, 2);
            },
            tooltip: 'Phóng to',
          ),
          IconButton(
            icon: Icon(Icons.zoom_out, color: Colors.white),
            onPressed: () {
              _zoomNotifier.value = (_zoomNotifier.value - 0.2).clamp(0.2, 2);
            },
            tooltip: 'Thu nhỏ',
          ),
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
                  : Icon(Icons.save, size: 20, color: Colors.white),
              label: Text('Lưu'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
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
                      'Đang tải PDF...',
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
                itemCount: _totalPages,
                itemBuilder: (context, index) {
                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                                  child: Center(
                                    child: CircularProgressIndicator(color: Colors.blue.shade700),
                                  ),
                                );
                              }
                              if (snapshot.hasError) {
                                return Center(
                                  child: Text(
                                    'Lỗi khi tải trang ${index + 1}',
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
                                                if (context != null) {
                                                  RenderBox? renderBox;
                                                  try {
                                                    renderBox = context.findRenderObject() as RenderBox?;
                                                  } catch (e) {
                                                    print('Error getting renderObject for page $newPageIndex: $e');
                                                    return;
                                                  }
                                                  if (renderBox != null) {
                                                    final localOffset = renderBox.globalToLocal(details.offset);
                                                    print('onDragEnd: globalOffset: ${details.offset}, localOffset: $localOffset, page: $newPageIndex');
                                                    final pdfPosition = _convertToPdfCoordinates(details.offset, newPageIndex);
                                                    _positionNotifier.value = pdfPosition;
                                                    _pageIndexNotifier.value = newPageIndex;
                                                    widget.onPositionChanged(pdfPosition);
                                                    print('New position: $pdfPosition, page: $newPageIndex');
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

  Future<px.PdfPageImage> _renderPage(int pageNumber) async {
    final page = await _pdfDocument.getPage(pageNumber);
    final pageImage = await page.render(
      width: page.width,
      height: page.height,
    );
    await page.close();
    return pageImage!;
  }

  int _findPageIndex(Offset globalOffset) {
    for (int i = 0; i < _pageKeys.length; i++) {
      final context = _pageKeys[i].currentContext;
      if (context == null) {
        print('Context is null for page $i');
        continue;
      }

      RenderBox? renderBox;
      try {
        renderBox = context.findRenderObject() as RenderBox?;
      } catch (e) {
        print('Error getting renderObject for page $i: $e');
        continue;
      }

      if (renderBox != null) {
        final position = renderBox.globalToLocal(globalOffset);
        print('Checking page $i: position: $position, size: ${renderBox.size}');
        if (position.dx >= 0 &&
            position.dx <= renderBox.size.width &&
            position.dy >= 0 &&
            position.dy <= renderBox.size.height) {
          print('Found page: $i');
          return i;
        }
      }
    }
    print('No page found, returning current: ${_pageIndexNotifier.value}');
    return _pageIndexNotifier.value;
  }

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
                'Lỗi khi tải hình ảnh',
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