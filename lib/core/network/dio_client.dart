import 'package:dio/dio.dart';

import 'logging_interceptor.dart';
import 'rate_limit_interceptor.dart';
import 'retry_interceptor.dart';

class DioClient {
  DioClient._();

  static Dio create({
    Duration connectTimeout = const Duration(seconds: 10),
    Duration receiveTimeout = const Duration(seconds: 15),
    Duration minRateLimitInterval = const Duration(milliseconds: 400),
    int maxRetries = 3,
  }) {
    final dio = Dio(BaseOptions(
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));

    dio.interceptors.addAll([
      LoggingInterceptor(),
      RateLimitInterceptor(minInterval: minRateLimitInterval),
      RetryInterceptor(maxRetries: maxRetries),
    ]);

    return dio;
  }
}
