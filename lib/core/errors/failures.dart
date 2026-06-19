abstract class Failure {
  final String message;
  const Failure(this.message);
}

class ServerFailure extends Failure {
  final int? statusCode;
  const ServerFailure(super.message, {this.statusCode});
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Sem conexao com a internet']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Erro ao acessar cache local']);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Recurso nao encontrado']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Autenticacao invalida']);
}

class RateLimitFailure extends Failure {
  final Duration? retryAfter;
  const RateLimitFailure({this.retryAfter}) : super('Rate limit atingido');
}
