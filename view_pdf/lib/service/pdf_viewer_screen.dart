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
  int _currentPage = 1;
  bool _isSaving = false;

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
    _updateTotalPages();
    _initializePdfDimensions();
  }

  Future<void> _updateTotalPages() async {
    final pdfFile = File(widget.filePath);
    final px.PdfDocument pdfDocument = await px.PdfDocument.openFile(pdfFile.path);
    setState(() {
    });
    await pdfDocument.close();
  }

  Future<void> _initializePdfDimensions() async {
    final pdfFile = File(widget.filePath);
    final px.PdfDocument pdfDocument = await px.PdfDocument.openFile(pdfFile.path);
    final page = await pdfDocument.getPage(1);
    setState(() {
      _pdfWidthInPoints = page.width.toDouble();
      _pdfHeightInPoints = page.height.toDouble();
    });
    await page.close();
    await pdfDocument.close();
  }

  Offset _convertToPdfCoordinates(Offset flutterPosition) {
    _screenWidthInPixels = MediaQuery.of(context).size.width;
    _screenHeightInPixels = MediaQuery.of(context).size.height -
        AppBar().preferredSize.height -
        MediaQuery.of(context).padding.top;

    final scaleX = _pdfWidthInPoints / _screenWidthInPixels;
    final scaleY = _pdfHeightInPoints / _screenHeightInPixels;

    final pdfX = flutterPosition.dx * scaleX;
    final pdfY = _pdfHeightInPoints - (flutterPosition.dy * scaleY);

    return Offset(pdfX, pdfY);
  }

  // Updated size conversion: Keep size closer to pixel values
  Size _convertToPdfSize(double width, double height) {
    const double dpiFactor = 1.0; // 1 pixel = 1 point (adjust this value if needed)
    return Size(width * dpiFactor, height * dpiFactor);
  }

  Future<void> _savePDF() async {
    if (widget.imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select an image to save')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final pdfFile = File(widget.filePath);
      final px.PdfDocument pdfDocument = await px.PdfDocument.openFile(pdfFile.path);
      final pdfPageCount = pdfDocument.pagesCount;
      final pdf = pw.Document();

      final imageBytes = await File(widget.imagePath!).readAsBytes();
      final pw.MemoryImage overlayImage = pw.MemoryImage(imageBytes);

      final pdfPosition = _convertToPdfCoordinates(_currentPosition);
      final pdfSize = _convertToPdfSize(_currentWidth, _currentHeight);

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
                  pw.Image(pw.MemoryImage(pageBytes)),
                  if (context.pageNumber == _currentPage)
                    pw.Positioned(
                      left: pdfPosition.dx,
                      top: pdfPosition.dy - pdfSize.height,
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
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF saved at $newPdfPath')),
        );
        Navigator.pop(context, newPdfPath);
      }

      await pdfDocument.close();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("View and Edit PDF"),
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
            tooltip: 'Save PDF',
          ),
        ],
      ),
      body: Stack(
        children: [
          PDFView(
            filePath: widget.filePath,
            swipeHorizontal: false,
            fitPolicy: FitPolicy.BOTH,
            pageFling: false,
            pageSnap: false,
            autoSpacing: false,
            onViewCreated: (PDFViewController controller) {
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