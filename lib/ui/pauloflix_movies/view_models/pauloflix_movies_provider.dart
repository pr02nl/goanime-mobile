import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/services/api_key_settings_service.dart';
import '../../../data/services/pauloflix_movies_service.dart';
import '../../../data/services/tmdb_service.dart';
import '../../../domain/models/pauloflix_movie.dart';
import '../../../domain/repositories/pauloflix_movies_repository.dart';

enum PauloFlixMoviesStatus { initial, loading, loaded, error }

/// Provider da área de filmes PauloFlix (Fase 3 do plano
/// `docs/DATABASE_REFACTORING.md`).
///
/// Consome `PauloFlixMoviesRepository` (Drift) em vez de
/// `PauloFlixMoviesDatabaseService` (sqlite3 FFI). O `TmdbService`
/// e o `PauloFlixMoviesService` (scraping HTML) continuam usados
/// pelo `syncContent`.
class PauloFlixMoviesProvider extends ChangeNotifier {
  final PauloFlixMoviesRepository _repository;
  final TmdbService _tmdb;
  final ApiKeySettingsService _settings;

  /// Ctor padrão (compat) — usa um no-op repository.
  PauloFlixMoviesProvider()
      : _repository = _NullPauloFlixMoviesRepository(),
        _tmdb = TmdbService(),
        _settings = ApiKeySettingsService();

  /// Ctor com repository + services opcionais (testes).
  PauloFlixMoviesProvider.withServices({
    required PauloFlixMoviesRepository repository,
    TmdbService? tmdbService,
    ApiKeySettingsService? settingsService,
  })  : _repository = repository,
        _tmdb = tmdbService ?? TmdbService(),
        _settings = settingsService ?? ApiKeySettingsService();

  PauloFlixMoviesStatus _status = PauloFlixMoviesStatus.initial;
  List<PauloFlixMovie> _contents = [];
  List<PauloFlixMovie> _filteredContents = [];
  String? _errorMessage;
  String _syncProgress = '';
  Timer? _searchDebounce;

  PauloFlixMoviesStatus get status => _status;
  List<PauloFlixMovie> get contents => _filteredContents;
  String? get errorMessage => _errorMessage;
  String get syncProgress => _syncProgress;
  bool get isSyncing => _status == PauloFlixMoviesStatus.loading;

  /// Carrega do banco local (sem chamada de rede).
  Future<void> loadContents() async {
    _status = PauloFlixMoviesStatus.loading;
    notifyListeners();
    try {
      _contents = await _repository.getAll();
      _filteredContents = _contents;
      _status = PauloFlixMoviesStatus.loaded;
    } catch (e) {
      _errorMessage = 'Erro ao carregar filmes: $e';
      _status = PauloFlixMoviesStatus.error;
    }
    notifyListeners();
  }

  /// Verifica se TMDB está configurado (chave persistida).
  Future<bool> isTmdbConfigured() => _settings.isTmdbConfigured();

  /// Sincroniza filmes do PauloFlix + enriquece com TMDB.
  Future<bool> syncContent() async {
    if (!_tmdb.isConfigured) {
      _errorMessage = 'TMDB não configurado. Vá em Configurações → API Keys.';
      _status = PauloFlixMoviesStatus.error;
      notifyListeners();
      return false;
    }
    _status = PauloFlixMoviesStatus.loading;
    _syncProgress = 'Iniciando sincronização de filmes...';
    notifyListeners();
    try {
      final success = await PauloFlixMoviesService.syncContent(
        onProgress: (msg) {
          _syncProgress = msg;
          notifyListeners();
        },
        onError: (err) {
          _errorMessage = err;
          notifyListeners();
        },
      );
      if (success) {
        await loadContents();
      } else {
        _status = PauloFlixMoviesStatus.error;
        notifyListeners();
      }
      return success;
    } catch (e) {
      _errorMessage = 'Erro na sincronização de filmes: $e';
      _status = PauloFlixMoviesStatus.error;
      notifyListeners();
      return false;
    }
  }

  void search(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      final q = query.toLowerCase().trim();
      if (q.isEmpty) {
        _filteredContents = _contents;
      } else {
        _filteredContents = _contents.where((c) {
          return c.displayName.toLowerCase().contains(q) ||
              c.genres.any((g) => g.toLowerCase().contains(q));
        }).toList();
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
}

class _NullPauloFlixMoviesRepository implements PauloFlixMoviesRepository {
  @override
  Future<List<PauloFlixMovie>> getAll() async => [];
  @override
  Future<List<PauloFlixMovie>> searchByName(String query) async => [];
  @override
  Future<PauloFlixMovie?> getByFolderName(String folderName) async => null;
  @override
  Future<PauloFlixMovie?> getByTmdbId(int tmdbId) async => null;
  @override
  Future<void> saveContent(PauloFlixMovie content) async {}
  @override
  Future<void> saveBatch(List<PauloFlixMovie> contents) async {}
  @override
  Future<void> markAsUnavailable(String folderName) async {}
  @override
  Future<Map<String, int>> getStats() async =>
      {'total': 0, 'available': 0, 'withMetadata': 0, 'collections': 0};
  @override
  Stream<List<PauloFlixMovie>> watch() => const Stream.empty();
}
