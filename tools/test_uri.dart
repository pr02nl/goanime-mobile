import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://media.oliveira.braga.nom.br/tvshows/';
  final uri = Uri.parse(baseUrl);
  print('Parsed: $uri');
  print('path: "${uri.path}"');
  print('hasTrailingSlash: ${uri.path.endsWith('/')}');

  // Como o http.get lida com isso
  final request = http.Request('GET', uri);
  print('Request URL: ${request.url}');
  print('Request path: "${request.url.path}"');
  print('Request url.host: ${request.url.host}');
}
