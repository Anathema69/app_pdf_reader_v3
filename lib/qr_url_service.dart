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

/// Recibe un string [qr]. Si es URL válida (http/https) e
/// imprime un HTML con tablas de <tr><td>Clave:</td><td>Valor</td></tr>,
/// extrae esos pares. Si obtiene datos retorna {'url': qr, ...campos...}.
/// Si status != 200 o no halla filas, o no es URL, intenta parsePipeDelimited.
/// Si todo falla, retorna {'value': qr}.
Future<Map<String, dynamic>> fetchQrUrlData(String qr) async {
  // 1) Intentamos tratarlo como URL
  final uri = Uri.tryParse(qr);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    try {
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final document = parse(resp.body);
        final data = <String, dynamic>{ 'url': qr };
        // Buscamos todas las filas de tabla
        for (final row in document.querySelectorAll('tr')) {
          final cols = row.querySelectorAll('td');
          if (cols.length >= 2) {
            // La primera <td> contiene el <span> con la clave
            final span = cols[0].querySelector('span');
            final key = span?.text.trim().replaceAll(':', '') ?? '';
            final val = cols[1].text.trim();
            if (key.isNotEmpty && val.isNotEmpty) {
              data[key] = val;
            }
          }
        }
        // Si encontramos al menos un campo, devolvemos el mapa
        if (data.length > 1) {
          return data;
        }
      }
    } catch (_) {
      // cualquier error en HTTP o parseo, caemos al fallback
    }
  }

  // 2) No es URL o no devolvió campos útiles: probamos parsePipeDelimited
  final parsed = parsePipeDelimited(qr);
  if (parsed != null) {
    return parsed;
  }

  // 3) Tampoco: devolvemos el valor crudo
  return {'value': qr};
}
