import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:path_provider/path_provider.dart';

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
  final PdfViewerController _pdfViewerController = PdfViewerController();
  late ValueNotifier<Offset> _positionNotifier;
  late ValueNotifier<double> _zoomNotifier;
  late ValueNotifier<int> _pageIndexNotifier;
  late double _currentWidth;
  late double _currentHeight;
  int _totalPages = 1;
  bool _isSaving = false;
  bool _isLoading = true;
  late PdfDocument _pdfDocument;
  List<Size> _pageSizes = [];
  final GlobalKey _pdfViewerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _positionNotifier = ValueNotifier(widget.imagePosition);
    _zoomNotifier = ValueNotifier(1.0);
    _pageIndexNotifier = ValueNotifier(0);
    _currentWidth = widget.imageWidth;
    _currentHeight = widget.imageHeight;
    print('Đường dẫn ảnh: ${widget.imagePath}');
    print('Tọa độ ban đầu: ${widget.imagePosition}');
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _initializePdfDocument();
      setState(() => _isLoading = false);
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
      final bytes = await pdfFile.readAsBytes();
      _pdfDocument = PdfDocument(inputBytes: bytes);
      _totalPages = _pdfDocument.pages.count;
      _pageSizes = [];
      for (int i = 0; i < _totalPages; i++) {
        final page = _pdfDocument.pages[i];
        _pageSizes.add(Size(page.size.width, page.size.height));
      }
      print('Tổng số trang: $_totalPages');
      print('Kích thước các trang: $_pageSizes');
    } catch (e) {
      print('Lỗi khởi tạo PDF: $e');
      rethrow;
    }
  }

  Offset _convertToPdfCoordinates(Offset flutterPosition, int pageIndex) {
    if (_pageSizes.isEmpty || pageIndex < 0 || pageIndex >= _pageSizes.length) {
      print('Lỗi: Trang không hợp lệ hoặc danh sách kích thước trang rỗng');
      return flutterPosition;
    }

    final pageSize = _pageSizes[pageIndex];
    final context = _pdfViewerKey.currentContext;

    if (context == null) {
      print('Lỗi: Context của SfPdfViewer là null');
      return flutterPosition;
    }

    RenderBox? renderBox;
    try {
      renderBox = context.findRenderObject() as RenderBox?;
    } catch (e) {
      print('Lỗi lấy RenderBox: $e');
      return flutterPosition;
    }

    if (renderBox == null) {
      print('Lỗi: RenderBox không tồn tại');
      return flutterPosition;
    }

    final pageSizeInPixels = renderBox.size;
    final scaleX = pageSize.width / pageSizeInPixels.width;
    final scaleY = pageSize.height / pageSizeInPixels.height;

    final localPosition = renderBox.globalToLocal(flutterPosition);
    final adjustedDy = localPosition.dy.clamp(0.0, pageSizeInPixels.height);
    final double pdfX = (localPosition.dx * scaleX).clamp(0, pageSize.width);
    final double pdfY = (adjustedDy * scaleY).clamp(0, pageSize.height);

    print('Chuyển đổi tọa độ:');
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
      print('Lỗi: Trang không hợp lệ hoặc danh sách kích thước trang rỗng');
      return pdfPosition;
    }

    final pageSize = _pageSizes[pageIndex];
    final context = _pdfViewerKey.currentContext;

    if (context == null) {
      print('Lỗi: Context của SfPdfViewer là null');
      return pdfPosition;
    }

    RenderBox? renderBox;
    try {
      renderBox = context.findRenderObject() as RenderBox?;
    } catch (e) {
      print('Lỗi lấy RenderBox: $e');
      return pdfPosition;
    }

    if (renderBox == null) {
      print('Lỗi: RenderBox không tồn tại');
      return pdfPosition;
    }

    final pageSizeInPixels = renderBox.size;
    final scaleX = pageSizeInPixels.width / pageSize.width;
    final scaleY = pageSizeInPixels.height / pageSize.height;

    final double flutterX = (pdfPosition.dx * scaleX).clamp(0, pageSizeInPixels.width);
    final double flutterY = (pdfPosition.dy * scaleY).clamp(0, pageSizeInPixels.height);

    print('Chuyển đổi tọa độ ngược:');
    print('  pageSize: $pageSize');
    print('  pageSizeInPixels: $pageSizeInPixels');
    print('  scaleX: $scaleX, scaleY: $scaleY');
    print('  pdfPosition: $pdfPosition');
    print('  flutterX: $flutterX, flutterY: $flutterY');

    return Offset(flutterX, flutterY);
  }

  Size _convertToPdfSize(double width, double height) {
    const double dpiFactor = 1.25;
    final double pdfWidth = (width * dpiFactor * _zoomNotifier.value).clamp(50, _pageSizes[_pageIndexNotifier.value].width);
    final double pdfHeight = (height * dpiFactor * _zoomNotifier.value).clamp(50, _pageSizes[_pageIndexNotifier.value].height);
    print('Kích thước PDF: ($pdfWidth, $pdfHeight)');
    return Size(pdfWidth, pdfHeight);
  }

  Future<void> _savePDF() async {
    if (widget.imagePath == null) {
      _showSnackBar('Vui lòng chọn hình ảnh để lưu');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final pdf = PdfDocument(inputBytes: await File(widget.filePath).readAsBytes());
      final imageBytes = await File(widget.imagePath!).readAsBytes();
      final pdfImage = PdfBitmap(imageBytes);
      final pdfPosition = _positionNotifier.value;
      final pdfSize = _convertToPdfSize(_currentWidth, _currentHeight);

      print('Lưu PDF: Vị trí $pdfPosition, Kích thước $pdfSize, Trang ${_pageIndexNotifier.value}');

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
        _showSnackBar('Đã lưu PDF thành công');
        Navigator.pop(context, newPdfPath);
      }
    } catch (e) {
      print('Lỗi lưu PDF: $e');
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
    _pdfDocument.dispose();
    _positionNotifier.dispose();
    _zoomNotifier.dispose();
    _pageIndexNotifier.dispose();
    _pdfViewerController.dispose();
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
              print('Phóng to: ${_zoomNotifier.value}');
            },
            tooltip: 'Phóng to',
          ),
          IconButton(
            icon: Icon(Icons.zoom_out, color: Colors.white),
            onPressed: () {
              _zoomNotifier.value = (_zoomNotifier.value - 0.2).clamp(0.2, 2);
              print('Thu nhỏ: ${_zoomNotifier.value}');
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
            : Stack(
                children: [
                  SfPdfViewer.file(
                    File(widget.filePath),
                    key: _pdfViewerKey,
                    controller: _pdfViewerController,
                    onDocumentLoaded: (details) {
                      setState(() {
                        _totalPages = details.document.pages.count;
                        print('PDF đã tải, tổng số trang: $_totalPages');
                      });
                    },
                    onPageChanged: (details) {
                      _pageIndexNotifier.value = details.newPageNumber - 1;
                      print('Trang hiện tại: ${_pageIndexNotifier.value}');
                    },
                  ),
                  if (widget.imagePath != null && File(widget.imagePath!).existsSync())
                    ValueListenableBuilder<int>(
                      valueListenable: _pageIndexNotifier,
                      builder: (context, pageIndex, child) {
                        return ValueListenableBuilder<Offset>(
                          valueListenable: _positionNotifier,
                          builder: (context, position, child) {
                            print('Hiển thị ảnh tại PDF: $position, trang: $pageIndex');
                            return ValueListenableBuilder<double>(
                              valueListenable: _zoomNotifier,
                              builder: (context, zoom, child) {
                                final flutterPosition = _convertFromPdfToFlutterCoordinates(position, pageIndex);
                                print('Vị trí Flutter: $flutterPosition');
                                return Positioned(
                                  left: flutterPosition.dx,
                                  top: flutterPosition.dy,
                                  child: GestureDetector(
                                    onScaleUpdate: (details) {
                                      _zoomNotifier.value = (_zoomNotifier.value * details.scale).clamp(0.2, 2);
                                      print('Zoom cập nhật: ${_zoomNotifier.value}');
                                    },
                                    child: Draggable(
                                      feedback: AnimatedOpacity(
                                        opacity: 0.7,
                                        duration: Duration(milliseconds: 100),
                                        child: _buildImageContainer(zoom),
                                      ),
                                      childWhenDragging: Container(),
                                      onDragEnd: (details) {
                                        final currentPageIndex = _pdfViewerController.pageNumber - 1;
                                        final pageSizeInPixels = _pageSizes[currentPageIndex];
                                        final newPosition = details.offset;

                                        // Chuyển đổi vị trí từ Flutter sang tọa độ PDF
                                        final pdfPosition = _convertToPdfCoordinates(newPosition, currentPageIndex);

                                        // Kiểm tra nếu vị trí mới nằm ngoài phạm vi trang hiện tại
                                        if (pdfPosition.dy > pageSizeInPixels.height && currentPageIndex < _totalPages - 1) {
                                          // Ảnh được kéo xuống dưới cùng của trang hiện tại, chuyển sang trang tiếp theo
                                          final nextPageIndex = currentPageIndex + 1;
                                          final nextPageSize = _pageSizes[nextPageIndex];
                                          final newPdfPosition = Offset(pdfPosition.dx, pdfPosition.dy - pageSizeInPixels.height);

                                          setState(() {
                                            _positionNotifier.value = newPdfPosition;
                                            _pageIndexNotifier.value = nextPageIndex;
                                            _pdfViewerController.jumpToPage(nextPageIndex + 1); // Chuyển sang trang tiếp theo
                                          });
                                          widget.onPositionChanged(newPdfPosition);
                                          print('Chuyển sang trang tiếp theo: $nextPageIndex, vị trí mới: $newPdfPosition');
                                        } else if (pdfPosition.dy < 0 && currentPageIndex > 0) {
                                          // Ảnh được kéo lên trên cùng của trang hiện tại, chuyển sang trang trước
                                          final previousPageIndex = currentPageIndex - 1;
                                          final previousPageSize = _pageSizes[previousPageIndex];
                                          final newPdfPosition = Offset(pdfPosition.dx, previousPageSize.height + pdfPosition.dy);

                                          setState(() {
                                            _positionNotifier.value = newPdfPosition;
                                            _pageIndexNotifier.value = previousPageIndex;
                                            _pdfViewerController.jumpToPage(previousPageIndex + 1); // Chuyển sang trang trước
                                          });
                                          widget.onPositionChanged(newPdfPosition);
                                          print('Chuyển sang trang trước: $previousPageIndex, vị trí mới: $newPdfPosition');
                                        } else {
                                          // Vị trí mới vẫn trong phạm vi trang hiện tại
                                          setState(() {
                                            _positionNotifier.value = pdfPosition;
                                          });
                                          widget.onPositionChanged(pdfPosition);
                                          print('Cập nhật vị trí trong trang hiện tại: $pdfPosition');
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
  }

  Widget _buildImageContainer(double zoom) {
    print('Kích thước ảnh: ${_currentWidth * zoom} x ${_currentHeight * zoom}');
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
            print('Lỗi tải ảnh: $error');
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