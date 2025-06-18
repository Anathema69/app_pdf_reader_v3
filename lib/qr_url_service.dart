// lib/qr_url_service.dart

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

/// Si [qr] no es URL válida o hay error/Access Denied,
/// devuelve {'value': qr}.
/// Si la URL responde 200 y contiene tablas (<tr><td>clave</td><td>valor</td>…),
/// devuelve {'url': qr, 'clave1': 'valor1', …}.
Future<Map<String, dynamic>> fetchQrUrlData(String qr) async {
  final uri = Uri.tryParse(qr);
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
    return {'value': qr};
  }

  try {
    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      return {'value': qr};
    }

    final doc = parse(resp.body);
    final data = <String, dynamic>{ 'url': qr };
    final rows = doc.querySelectorAll('tr');

    for (var row in rows) {
      final cols = row.querySelectorAll('td');
      if (cols.length >= 2) {
        final key = cols[0].text.trim().replaceAll(':', '');
        final val = cols[1].text.trim();
        if (key.isNotEmpty && val.isNotEmpty) {
          data[key] = val;
        }
      }
    }

    // Si no encontró filas útiles, devolvemos el valor crudo
    if (data.length == 1) {
      return {'value': qr};
    }
    return data;
  } catch (_) {
    return {'value': qr};
  }
}
