import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/logger/app_logger.dart';
import '../../../domain/models/paulo_flix_movie_progress_record.dart';
import '../../../domain/repositories/paulo_flix_movie_progress_repository.dart';

/// ViewModel da seção "Continue assistindo" da home de filmes.
///
/// Assina `repo.watchInProgressMovies(limit)` e expõe a lista
/// reativa. A UI consome via `Consumer` ou `context.watch`.
///
/// **Comportamento:**
/// - `loading = true` antes do primeiro evento do stream.
/// - `contents` é a lista atualizada automaticamente quando o banco
///   muda.
/// - `isEmpty` é `true` se a lista está vazia. Usado pelo widget
///   para renderizar `SizedBox.shrink()`.
class PauloFlixMovieContinueWatchingViewModel extends ChangeNotifier {
  final PauloFlixMovieProgressRepository _repository;
  final int _limit;

  StreamSubscription<List<PauloFlixMovieProgressRecord>>? _sub;

  List<PauloFlixMovieProgressRecord> _contents = const [];
  bool _loading = true;
  bool _disposed = false;

  PauloFlixMovieContinueWatchingViewModel({
    required PauloFlixMovieProgressRepository repository,
    int limit = 12,
  })  : _repository = repository,
        _limit = limit {
    _sub = _repository.watchInProgressMovies(limit: _limit).listen(
      _onUpdate,
      onError: (Object e, StackTrace st) {
        AppLogger('MovieContinueWatching').error('Stream error', e);
      },
    );
  }

  void _onUpdate(List<PauloFlixMovieProgressRecord> next) {
    if (_disposed) return;
    _contents = next;
    _loading = false;
    notifyListeners();
  }

  List<PauloFlixMovieProgressRecord> get contents => _contents;
  bool get loading => _loading;
  bool get isEmpty => !_loading && _contents.isEmpty;
  bool get hasContent => _contents.isNotEmpty;

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }
}
