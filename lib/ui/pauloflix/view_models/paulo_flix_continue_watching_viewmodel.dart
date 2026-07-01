import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/logger/app_logger.dart';
import '../../../domain/models/paulo_flix_progress_stats.dart';
import '../../../domain/models/pauloflix_content.dart';
import '../../../domain/repositories/paulo_flix_episode_progress_repository.dart';

/// ViewModel da seção "Continue assistindo" da home e See All
/// (Fase 5.1 do plano
/// `.hermes/plans/2026-06-22_2230-pauloflix-episodes-progress.md`).
///
/// Assina `repo.watchInProgressContents(limit)` e expõe a lista
/// reativa. A UI consome via `Consumer` ou `context.watch`.
///
/// **Comportamento:**
/// - `loading = true` antes do primeiro evento do stream.
/// - `contents` é a lista atualizada automaticamente quando o banco
///   muda (episode parou de ser parcial → some, novo episode parcial
///   → aparece).
/// - `isEmpty` é `true` se a lista está vazia (após o primeiro
///   evento). Usado pelo widget para renderizar `SizedBox.shrink()`
///   (não mostra a seção se vazia).
class PauloFlixContinueWatchingViewModel extends ChangeNotifier {
  final PauloFlixEpisodeProgressRepository _repository;
  final int _limit;

  StreamSubscription<List<PauloFlixContent>>? _sub;

  List<PauloFlixContent> _contents = const [];
  Map<int, PauloFlixProgressStats> _statsById = const {};
  bool _loading = true;
  bool _disposed = false;

  /// Limite de itens (default 12). Configurável por parâmetro.
  PauloFlixContinueWatchingViewModel({
    required PauloFlixEpisodeProgressRepository repository,
    int limit = 12,
  })  : _repository = repository,
        _limit = limit {
    _sub = _repository.watchInProgressContents(limit: _limit).listen(
      _onUpdate,
      onError: (Object e, StackTrace st) {
        const AppLogger('ContinueWatching').error('Stream error', e);
      },
    );
  }

  Future<void> _onUpdate(List<PauloFlixContent> next) async {
    if (_disposed) return;
    _contents = next;
    _loading = false;
    // Notifica imediatamente com a lista atualizada (conteúdos que
    // saíram da lista somem da UI sem delay).
    notifyListeners();

    // Busca stats em lote para todos os conteúdos com ID conhecido.
    final ids = next.map((c) => c.id).whereType<int>().toList();
    if (ids.isNotEmpty) {
      try {
        _statsById = await _repository.getProgressStatsForContents(ids);
      } catch (e, st) {
        const AppLogger('ContinueWatching').error('Erro ao buscar stats', e, st);
        _statsById = const {};
      }
    } else {
      _statsById = const {};
    }

    if (!_disposed) notifyListeners();
  }

  /// Lista de animes com episodes parciais (ordenados por
  /// `MAX(lastWatched) DESC`).
  List<PauloFlixContent> get contents => _contents;

  /// Mapa `contentId → stats` de progresso para cada anime.
  /// Usado pela section para exibir overlays nos cards.
  Map<int, PauloFlixProgressStats> get statsById => _statsById;

  /// `true` antes do primeiro evento do stream (banco ainda não
  /// consultado). Após o primeiro emit, fica `false` mesmo se a
  /// lista for vazia.
  bool get loading => _loading;

  /// `true` se a lista está vazia (e o primeiro evento já chegou).
  /// Usado pelo widget para decidir se renderiza a seção.
  bool get isEmpty => !_loading && _contents.isEmpty;

  /// `true` se há ao menos 1 anime em andamento.
  bool get hasContent => _contents.isNotEmpty;

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }
}
