import 'package:dio/dio.dart';

class RateLimitInterceptor extends Interceptor {
  final Duration minInterval;
  DateTime? _lastRequest;

  RateLimitInterceptor({this.minInterval = const Duration(milliseconds: 400)});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (_lastRequest != null) {
      final elapsed = DateTime.now().difference(_lastRequest!);
      if (elapsed < minInterval) {
        await Future.delayed(minInterval - elapsed);
      }
    }
    _lastRequest = DateTime.now();
    handler.next(options);
  }
}
