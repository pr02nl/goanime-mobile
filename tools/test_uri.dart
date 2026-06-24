import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

void main() async {
  const baseUrl = 'https://media.oliveira.braga.nom.br/tvshows/';
  final uri = Uri.parse(baseUrl);
  debugPrint('Parsed: $uri');
  debugPrint('path: "${uri.path}"');
  debugPrint('hasTrailingSlash: ${uri.path.endsWith('/')}');

  // Como o http.get lida com isso
  final request = http.Request('GET', uri);
  debugPrint('Request URL: ${request.url}');
  debugPrint('Request path: "${request.url.path}"');
  debugPrint('Request url.host: ${request.url.host}');
}
