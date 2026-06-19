import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class RetryInterceptor extends Interceptor {
  final int maxRetries;

  RetryInterceptor({this.maxRetries = 3});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_shouldRetry(err) && (err.requestOptions.extra['retryCount'] ?? 0) < maxRetries) {
      final retryCount = (err.requestOptions.extra['retryCount'] ?? 0) + 1;
      final delay = _calculateDelay(err, retryCount);

      debugPrint('[RetryInterceptor] Retry $retryCount/$maxRetries after ${delay.inMilliseconds}ms');

      await Future.delayed(delay);
      err.requestOptions.extra['retryCount'] = retryCount;

      try {
        final response = await Dio().fetch(err.requestOptions);
        return handler.resolve(response);
      } catch (e) {
        return handler.next(err);
      }
    }
    handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.response?.statusCode == 429) ||
        (err.response?.statusCode != null &&
            err.response!.statusCode! >= 500);
  }

  Duration _calculateDelay(DioException err, int retryCount) {
    if (err.response?.statusCode == 429) {
      final retryAfter = err.response?.headers.value('retry-after');
      if (retryAfter != null) {
        final seconds = int.tryParse(retryAfter) ?? 2;
        return Duration(seconds: seconds);
      }
    }
    // Exponential backoff: 500ms, 1s, 2s
    return Duration(milliseconds: 500 << (retryCount - 1));
  }
}
