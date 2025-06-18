// lib/pdf_qr_service.dart

import 'package:pdfx/pdfx.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';
import 'qr_url_service.dart';

/// Extrae el primer QR del PDF y, si es URL, llama a fetchQrUrlData.
/// Siempre devuelve un Map listo para JSON.
Future<Map<String, dynamic>> extractQrJsonFromPdf(String path) async {
  final qr = await extractFirstQrFromPdf(path);
  if (qr == null) {
    return <String, dynamic>{};
  }
  return await fetchQrUrlData(qr);
}

/// Abre el PDF en [path], busca QRs y devuelve la primera coincidencia.
/// Si no hay QR o hay error, devuelve null.
Future<String?> extractFirstQrFromPdf(String path) async {
  try {
    final doc = await PdfDocument.openFile(path);

    for (var i = 1; i <= doc.pagesCount; i++) {
      final page = await doc.getPage(i);
      final pageImage = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: PdfPageImageFormat.png,
      );
      final baseImage = img.decodeImage(pageImage!.bytes);
      await page.close();

      if (baseImage == null) continue;
      final bytes = baseImage
          .convert(numChannels: 4)
          .getBytes(order: img.ChannelOrder.abgr)
          .buffer
          .asInt32List();
      final source = RGBLuminanceSource(
        baseImage.width,
        baseImage.height,
        bytes,
      );
      final bitmap = BinaryBitmap(HybridBinarizer(source));

      try {
        final reader = QRCodeReader();
        final result = reader.decode(bitmap);
        await doc.close();
        return result.text;
      } catch (_) {
        // sigue buscando en la próxima página
      }
    }

    await doc.close();
    return null;
  } catch (_) {
    return null;
  }
}
