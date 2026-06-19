class ServerException implements Exception {
  final String message;
  final int? statusCode;
  const ServerException(this.message, {this.statusCode});
}

class CacheException implements Exception {
  final String message;
  const CacheException([this.message = 'Cache error']);
}

class NetworkException implements Exception {
  final String message;
  const NetworkException([this.message = 'Network error']);
}

class RateLimitException implements Exception {
  final Duration? retryAfter;
  const RateLimitException({this.retryAfter, this.message = 'Rate limit atingido'});
  final String message;
}

class AuthException implements Exception {
  final String message;
  const AuthException([this.message = 'Autenticacao invalida']);
}

class NotFoundException implements Exception {
  final String message;
  const NotFoundException([this.message = 'Recurso nao encontrado']);
}
