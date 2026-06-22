import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/services/pauloflix_service.dart';
import '../../../domain/models/pauloflix_content.dart';
import '../../../domain/repositories/pauloflix_repository.dart';

enum PauloFlixStatus { initial, loading, loaded, error }

/// Provider da área PauloFlix animes (Fase 3 do plano
/// `docs/DATABASE_REFACTORING.md`).
///
/// Consome `PauloFlixRepository` (Drift) em vez de
/// `PauloFlixDatabaseService` (sqlite3 FFI). O `PauloFlixService`
/// (scraping HTML) ainda existe — este provider delega o sync
/// para ele e usa o repository como persistência.
class PauloFlixProvider extends ChangeNotifier {
  final PauloFlixRepository _repository;

  /// Ctor padrão — provider sem dependência (cria PauloFlixService
  /// internamente para o sync; usado em testes/legado).
  PauloFlixProvider() : _repository = _NullPauloFlixRepository();

  /// Ctor com repository (Fase 3) — usado pelo Provider do app.
  PauloFlixProvider.withRepository(this._repository);

  PauloFlixStatus _status = PauloFlixStatus.initial;
  List<PauloFlixContent> _contents = [];
  List<PauloFlixContent> _filteredContents = [];
  String? _errorMessage;
  String _syncProgress = '';
  Timer? _searchDebounce;

  PauloFlixStatus get status => _status;
  List<PauloFlixContent> get contents => _filteredContents;
  String? get errorMessage => _errorMessage;
  String get syncProgress => _syncProgress;
  bool get isSyncing => _status == PauloFlixStatus.loading;

  Future<void> loadContents() async {
    _status = PauloFlixStatus.loading;
    notifyListeners();
    try {
      _contents = await _repository.getAll();
      _filteredContents = _contents;
      _status = PauloFlixStatus.loaded;
    } catch (e) {
      _errorMessage = 'Erro ao carregar conteúdo: $e';
      _status = PauloFlixStatus.error;
    }
    notifyListeners();
  }

  /// Sync com o servidor via `PauloFlixService` (scraping) seguido de
  /// `saveContent` no repository. Mantido o comportamento do service
  /// legado.
  Future<void> syncContent() async {
    // Importação dinâmica para evitar ciclo: PauloFlixService importa
    // este provider via testes; em produção, a sync é sempre via service.
    _status = PauloFlixStatus.loading;
    _syncProgress = 'Iniciando sincronização...';
    notifyListeners();
    try {
      // Placeholder de compat: PauloFlixService.syncContent é chamado
      // pelo app; aqui apenas refletimos o estado. O repository já
      // estará populado pelo service (que internamente usa o repository
      // na Fase 3 completa).
      final sync = await PauloFlixService.syncContent(
        repository: _repository,
        onProgress: (progress) {
          _syncProgress = progress;
          notifyListeners();
        },
        onError: (error) {
          _errorMessage = 'Erro na sincronização: $error';
          _status = PauloFlixStatus.error;
          notifyListeners();
        },
      );
      if (!sync) {
        _errorMessage = 'Sincronização falhou por motivos desconhecidos.';
        _status = PauloFlixStatus.error;
        notifyListeners();
        return;
      }
      _status = PauloFlixStatus.loaded;
    } catch (e) {
      _errorMessage = 'Erro na sincronização: $e';
      _status = PauloFlixStatus.error;
    }
    notifyListeners();
  }

  void search(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      final searchQuery = query.toLowerCase();
      if (searchQuery.isEmpty) {
        _filteredContents = _contents;
      } else {
        _filteredContents = _contents
            .where(
              (c) =>
                  c.displayName.toLowerCase().contains(searchQuery) ||
                  c.genres.any((g) => g.toLowerCase().contains(searchQuery)),
            )
            .toList();
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void clearSearch() {
    _filteredContents = _contents;
    notifyListeners();
  }

  PauloFlixContent? getByMalId(int malId) {
    try {
      return _contents.firstWhere((c) => c.malId == malId);
    } catch (e) {
      debugPrint('getByMalId: $malId not found — $e');
      return null;
    }
  }

  bool isAvailableOnPauloFlix(String animeName) {
    return _contents.any(
      (c) =>
          c.displayName.toLowerCase() == animeName.toLowerCase() ||
          c.folderName.toLowerCase() == animeName.toLowerCase(),
    );
  }
}

/// Fallback no-op para o ctor sem dependência. Mantém PauloFlixProvider
/// funcionando em testes/legado até que o app use `withRepository`.
class _NullPauloFlixRepository implements PauloFlixRepository {
  @override
  Future<List<PauloFlixContent>> getAll() async => [];
  @override
  Future<List<PauloFlixContent>> searchByName(String query) async => [];
  @override
  Future<PauloFlixContent?> getByFolderName(String folderName) async => null;
  @override
  Future<PauloFlixContent?> getByMalId(int malId) async => null;
  @override
  Future<void> saveContent(PauloFlixContent content) async {}
  @override
  Future<void> saveBatch(List<PauloFlixContent> contents) async {}
  @override
  Future<void> markAsUnavailable(String folderName) async {}
  @override
  Future<Map<String, int>> getStats() async => {
    'total': 0,
    'available': 0,
    'withMetadata': 0,
  };
  @override
  Stream<List<PauloFlixContent>> watch() => const Stream.empty();
}
