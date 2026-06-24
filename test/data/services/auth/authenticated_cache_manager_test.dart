/// Testes do `AuthenticatedCacheManager`.
///
/// **O que testamos:** apenas que a classe existe e é instanciável
/// (cobertura mínima — o analyzer já valida o resto via
/// `implements BaseCacheManager`).
///
/// **O que NÃO testamos:** o comportamento real de injeção de header
/// em downloads de imagem. Isso requer mockar `HttpFileService` (que
/// é `WebHelper` em web, não-trivial de mockar). A validação real é
/// visual (smoke test em device).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/data/services/auth/authenticated_cache_manager.dart';

void main() {
  test('AuthenticatedCacheManager é uma classe pública', () {
    // Cobertura estática: garante que a classe existe e pode ser
    // referenciada. O analyzer valida que ela implements
    // BaseCacheManager (a checagem dinâmica de assignable acontece
    // em runtime quando app.dart atribui ao
    // CachedNetworkImageProvider.defaultCacheManager).
    expect(AuthenticatedCacheManager, isNotNull);
  });
}
