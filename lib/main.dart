import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';
import 'package:file_picker/file_picker.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF QR Detector',
      home: const PdfQrDetectorPage(),
    );
  }
}

class PdfQrDetectorPage extends StatefulWidget {
  const PdfQrDetectorPage({super.key});
  @override
  State<PdfQrDetectorPage> createState() => _PdfQrDetectorPageState();
}

class _PdfQrDetectorPageState extends State<PdfQrDetectorPage> {
  String _jsonResult = '';

  Future<void> _selectAndProcessPdf() async {
    try {
      // Abrimos el selector de archivos
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null || result.files.single.path == null) {
        // PDF no seleccionado: devolvemos JSON vacío formateado
        final emptyJson =
        JsonEncoder.withIndent('  ').convert(<String, dynamic>{});
        setState(() => _jsonResult = emptyJson);
        return;
      }

      // Cargamos el PDF
      final path = result.files.single.path!;
      final doc = await PdfDocument.openFile(path);
      final List<String> qrContents = [];


      // Recorremos cada página
      for (var i = 1; i <= doc.pagesCount; i++) {
        final page = await doc.getPage(i);
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: PdfPageImageFormat.png,
        );// Decodificamos el PNG a image.Image

        final baseImage = img.decodeImage(pageImage!.bytes);
        if (baseImage != null) {
          final bytes = baseImage
              .convert(numChannels: 4)
              .getBytes(order: img.ChannelOrder.abgr)
              .buffer
              .asInt32List();

          // Preparamos la fuente de luminancia y bitmap
          final source = RGBLuminanceSource(
            baseImage.width,
            baseImage.height,
            bytes,
          );

          // PROBÉ CON 'GlobalHistogramBinarizer' pero no funciona para algunos PDF
          final bitmap = BinaryBitmap(HybridBinarizer(source));

          try {
            // Intentamos leer el QR
            final reader = QRCodeReader();
            final result = reader.decode(bitmap);
            qrContents.add(result.text);
          } catch (_) {
            // No se encontró QR en esta página
          }
        }

        await page.close();
      }

      await doc.close();

      // Construimos el JSON con claves qr1, qr2, …
      final Map<String, dynamic> output = {};
      for (var i = 0; i < qrContents.length; i++) {
        output['qr${i + 1}'] = [qrContents[i]];
      }

      // Formateamos con indentación
      final formattedJson =
      JsonEncoder.withIndent('  ').convert(output);
      setState(() => _jsonResult = formattedJson);
    } catch (_) {
      // En caso de cualquier error, devolvemos JSON vacío formateado
      final emptyJson =
      JsonEncoder.withIndent('  ').convert(<String, dynamic>{});
      setState(() => _jsonResult = emptyJson);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detector de QR en PDF')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _selectAndProcessPdf,
              child: const Text('Seleccionar PDF'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  _jsonResult,
                  style: const TextStyle(fontFamily: 'Courier'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
