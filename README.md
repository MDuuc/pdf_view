# Flutter PDF Editor

A Flutter application that allows users to load a PDF file, overlay an image on it, adjust the image's position and size, and save the modified PDF with the image embedded. This project demonstrates file handling, PDF manipulation, and interactive UI components in Flutter.

## Features

- **PDF Selection**: Pick a PDF file from the device using a file picker.
- **Image Overlay**: Select an image from the gallery and overlay it onto the PDF.
- **Interactive Editing**: Drag the image to reposition it, zoom in/out, and adjust its size on the PDF.
- **PDF Viewing**: Preview the PDF with the overlaid image using a PDF viewer.
- **Save Modified PDF**: Save the edited PDF with the image embedded at the specified position and size.
- **Open PDF**: Open the saved PDF using the device's default PDF viewer.

## How It Works

### Home Screen (HomeScreen)
- Users can pick a PDF file and an image from their device.
- Displays the selected file names and provides options to view or open the PDF.
- Navigates to the `PDFViewerScreen` for editing when "Xem PDF" is pressed.

### PDF Viewer Screen (PDFViewerScreen)
- Displays the selected PDF with the overlaid image (if selected).
- Allows dragging the image to reposition it and zooming in/out via buttons or pinch gestures.
- Converts screen coordinates and sizes to PDF coordinates for accurate embedding.
- Saves the modified PDF with the image overlaid on the specified page.

### Saving Mechanism
- Uses the `pdf` and `pdfx` libraries to render the original PDF pages and overlay the image.
- Saves the new PDF to the device's application documents directory with a timestamped filename.

### Usage
- Launch the app and click "Chọn file PDF" to select a PDF.
- Click "Chọn ảnh" to pick an image from your gallery.
- Press "Xem PDF" to view and edit the PDF with the overlaid image.
- In the viewer:
    - Drag the image to reposition it.
    - Use zoom in/out buttons or pinch to adjust the image size.
    - Navigate pages using the arrow buttons.
    - Click the save icon to save the modified PDF.
- Return to the home screen and press "Mở file PDF" to view the saved file.

