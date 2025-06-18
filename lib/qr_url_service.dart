// lib/qr_url_service.dart

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';

/// Si [input] es una cadena con campos separados por '|' y 'key:value',
/// la parsea a un Map<String, String>. Si no encuentra pares válidos,
/// devuelve null.
Map<String, String>? parsePipeDelimited(String input) {
  final parts = input
      .split('|')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  final Map<String, String> out = {};
  for (var part in parts) {
    final idx = part.indexOf(':');
    if (idx > 0 && idx < part.length - 1) {
      final key = part.substring(0, idx).trim();
      final val = part.substring(idx + 1).trim();
      out[key] = val;
    }
  }
  return out.isEmpty ? null : out;
}

/// Recibe un string [qr].
/// 1) Si al “pipe‐parsearlo” obtenemos un único par
///    {'http'|'https': '//...'}, lo reconstruimos como URL.
/// 2) Si es una URL válida (http/https), hace GET y trata de extraer
///    todas las filas de <tr><td><span>Clave:</span></td><td>Valor</td></tr>.
///    Si responde 200 y hay al menos un campo, devuelve {'url': ..., clave: valor, ...}.
///    Si falla la petición (status != 200) o no hay campos, devuelve {'value': qr}.
/// 3) Si no era URL, y parsePipeDelimited devuelve campos útiles,
///    devuelve directamente ese Map<String, String>.
/// 4) En cualquier otro caso, devuelve {'value': qr}.
Future<Map<String, dynamic>> fetchQrUrlData(String qr) async {
  // 1) Detectar casos tipo {"https": "//..."} generados por parsePipeDelimited
  final pipeParsed = parsePipeDelimited(qr);
  var qrToProcess = qr;
  if (pipeParsed != null && pipeParsed.length == 1) {
    final scheme = pipeParsed.keys.first;
    final rest = pipeParsed.values.first;
    if ((scheme == 'http' || scheme == 'https') && rest.startsWith('//')) {
      qrToProcess = '$scheme:$rest';
    }
  }

  // 2) Intentar tratar qrToProcess como URL
  final uri = Uri.tryParse(qrToProcess);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    try {
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final document = parse(resp.body);
        final data = <String, dynamic>{ 'url': qrToProcess };

        for (final row in document.querySelectorAll('tr')) {
          final cols = row.querySelectorAll('td');
          if (cols.length >= 2) {
            final span = cols[0].querySelector('span');
            final key = span?.text.trim().replaceAll(':', '') ?? '';
            final val = cols[1].text.trim();
            if (key.isNotEmpty && val.isNotEmpty) {
              data[key] = val;
            }
          }
        }

        if (data.length > 1) {
          return data;
        }
      }
      // Si status != 200 o no extrajo campos, devolvemos crudo
      return {'value': qr};
    } catch (_) {
      return {'value': qr};
    }
  }

  // 3) No es URL o no pudo procesarse como tal: intentar pipe‐parsing
  if (pipeParsed != null) {
    return pipeParsed;
  }

  // 4) Fallback final: valor crudo
  return {'value': qr};
}
