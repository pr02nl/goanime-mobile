import 'package:flutter/foundation.dart';

import '../../../core/logger/app_logger.dart';
import '../../../data/services/image_precache_service.dart';
import '../../../data/services/pauloflix_movies_service.dart';
import '../../../domain/models/pauloflix_movie.dart';
import '../../../domain/repositories/pauloflix_movies_repository.dart';
import '../../core/utils/pagination.dart';

enum PauloFlixMoviesStatus { initial, loading, loaded, error }

/// Provider da área de filmes PauloFlix.
class PauloFlixMoviesProvider extends ChangeNotifier {
  final PauloFlixMoviesRepository _repository;

  /// Ctor padrão (compat) — usa um no-op repository.
  PauloFlixMoviesProvider() : _repository = _NullPauloFlixMoviesRepository();

  /// Ctor com repository (testes / produção).
  PauloFlixMoviesProvider.withServices({
    required PauloFlixMoviesRepository repository,
  }) : _repository = repository;

  PauloFlixMoviesStatus _status = PauloFlixMoviesStatus.initial;
  List<PauloFlixMovie> _contents = [];
  String? _errorMessage;
  String _syncProgress = '';

  /// `null` = última sync foi bem-sucedida; `String` = mensagem do erro.
  String? _lastSyncError;

  /// Query de busca ativa. Vazio = sem filtro.
  String _searchQuery = '';

  PauloFlixMoviesStatus get status => _status;

  /// Retorna a lista completa ou filtrada conforme _searchQuery.
  /// Evita manter `_filteredContents` duplicada em memória.
  List<PauloFlixMovie> get contents {
    if (_searchQuery.isEmpty) return _contents;
    final q = _searchQuery.toLowerCase();
    return _contents.where((c) {
      return c.displayName.toLowerCase().contains(q) ||
          c.genres.any((g) => g.toLowerCase().contains(q));
    }).toList();
  }

  String? get errorMessage => _errorMessage;
  String get syncProgress => _syncProgress;
  bool get isSyncing => _status == PauloFlixMoviesStatus.loading;

  /// `null` se a última sync foi bem-sucedida (ou nunca foi tentada).
  /// String não-vazia se houve erro na última sync.
  String? get lastSyncError => _lastSyncError;

  /// `true` se a última sync falhou. Usado pelo sidebar para mostrar
  /// indicador vermelho.
  bool get hasSyncError => _lastSyncError != null;

  Future<void> loadContents() async {
    _status = PauloFlixMoviesStatus.loading;
    notifyListeners();
    try {
      _contents = await _repository.getAll();
      _status = PauloFlixMoviesStatus.loaded;

      _precacheImages();
    } catch (e) {
      _errorMessage = 'Erro ao carregar filmes: $e';
      _status = PauloFlixMoviesStatus.error;
    }
    notifyListeners();
  }

  Future<bool> syncContent() async {
    _status = PauloFlixMoviesStatus.loading;
    _syncProgress = 'Iniciando sincronização de filmes...';
    _lastSyncError = null;
    notifyListeners();
    try {
      final success = await PauloFlixMoviesService.syncContent(
        repository: _repository,
        onProgress: (msg) {
          _syncProgress = msg;
          notifyListeners();
        },
        onError: (err) {
          _errorMessage = err;
          _lastSyncError = err;
          notifyListeners();
        },
      );
      if (success) {
        await loadContents();
      } else {
        _lastSyncError = _errorMessage;
        _status = PauloFlixMoviesStatus.error;
        notifyListeners();
      }
      return success;
    } catch (e) {
      _errorMessage = 'Erro na sincronização de filmes: $e';
      _lastSyncError = _errorMessage;
      _status = PauloFlixMoviesStatus.error;
      notifyListeners();
      return false;
    }
  }

  void search(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<List<PauloFlixMovie>> searchByName(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    try {
      return await _repository.searchByName(q);
    } catch (e) {
      AppLogger('PauloFlixMoviesProvider').warning('searchByName falhou', e);
      return const [];
    }
  }


  // ─── Métodos puros de agrupamento/ordenação ─────────────────────────

  static PauloFlixMovie? pickFeaturedMovie(List<PauloFlixMovie> movies) {
    if (movies.isEmpty) return null;
    final sorted = [...movies]
      ..sort((a, b) {
        final scoreCmp = (b.score ?? 0).compareTo(a.score ?? 0);
        if (scoreCmp != 0) return scoreCmp;
        final yearCmp = (b.year ?? 0).compareTo(a.year ?? 0);
        if (yearCmp != 0) return yearCmp;
        return a.folderName.compareTo(b.folderName);
      });
    return sorted.first;
  }

  static Map<String, List<PauloFlixMovie>> groupByTopGenres(
    List<PauloFlixMovie> movies, {
    int maxGenres = 4,
    int perGenre = 12,
    int minPerGenre = 3,
  }) {
    if (movies.isEmpty) return const {};

    final genreCount = <String, int>{};
    for (final m in movies) {
      for (final g in m.genres) {
        if (g.isEmpty) continue;
        genreCount[g] = (genreCount[g] ?? 0) + 1;
      }
    }

    final topGenres =
        genreCount.entries.where((e) => e.value >= minPerGenre).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final selected = topGenres.take(maxGenres).map((e) => e.key).toList();

    final result = <String, List<PauloFlixMovie>>{};
    for (final g in selected) {
      final filtered = movies.where((m) => m.genres.contains(g)).toList()
        ..sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));
      result[g] = filtered.take(perGenre).toList();
    }
    return result;
  }

  static String genreIcon(String genre) {
    const map = {
      'Action': 'flash_on',
      'Adventure': 'explore',
      'Animation': 'animation',
      'Comedy': 'sentiment_very_satisfied',
      'Crime': 'gavel',
      'Documentary': 'article',
      'Drama': 'theater_comedy',
      'Family': 'family_restroom',
      'Fantasy': 'auto_awesome',
      'History': 'history_edu',
      'Horror': 'dark_mode',
      'Music': 'music_note',
      'Mystery': 'search',
      'Romance': 'favorite',
      'Science Fiction': 'rocket_launch',
      'Sci-Fi': 'rocket_launch',
      'TV Movie': 'tv',
      'Thriller': 'psychology',
      'War': 'military_tech',
      'Western': 'landscape',
    };
    return map[genre] ?? 'movie_outlined';
  }

  static PaginationResult<PauloFlixMovie> paginateByLetter(
    List<PauloFlixMovie> movies, {
    int perPage = 24,
  }) {
    if (movies.isEmpty) {
      return const PaginationResult<PauloFlixMovie>(
        pages: [],
        letterToPageIndex: {},
        availableLetters: [],
      );
    }

    final sorted = [...movies]
      ..sort((a, b) {
        final aKey = _sortKey(a.displayName);
        final bKey = _sortKey(b.displayName);
        final cmp = aKey.compareTo(bKey);
        if (cmp != 0) return cmp;
        return a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        );
      });

    final pages = <List<PauloFlixMovie>>[];
    for (var i = 0; i < sorted.length; i += perPage) {
      final end = i + perPage > sorted.length ? sorted.length : i + perPage;
      pages.add(sorted.sublist(i, end));
    }

    final letterToPageIndex = <String, int>{};
    final availableLetters = <String>[];
    for (var i = 0; i < pages.length; i++) {
      for (final m in pages[i]) {
        final letter = _normalizeFirstChar(m.displayName);
        if (!letterToPageIndex.containsKey(letter)) {
          letterToPageIndex[letter] = i;
          availableLetters.add(letter);
        }
      }
    }
    availableLetters.sort((a, b) {
      if (a == '#') return 1;
      if (b == '#') return -1;
      return a.compareTo(b);
    });

    return PaginationResult<PauloFlixMovie>(
      pages: pages,
      letterToPageIndex: letterToPageIndex,
      availableLetters: availableLetters,
    );
  }

  static String _normalizeFirstChar(String name) {
    if (name.isEmpty) return '#';
    final first = name[0].toUpperCase();
    final isLetter = RegExp(r'^[A-Z]$').hasMatch(first);
    return isLetter ? first : '#';
  }

  static String _sortKey(String name) {
    final first = _normalizeFirstChar(name);
    return first == '#' ? '~' : first;
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  /// Pré-carrega imagens dos cards em background após o load.
  void _precacheImages() {
    ImagePrecacheService.prefetchImages(
      _contents.map((m) => m.imageUrl ?? ''),
    );
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
  Future<Map<String, int>> getStats() async => {
    'total': 0,
    'available': 0,
    'withMetadata': 0,
    'collections': 0,
  };
  @override
  Stream<List<PauloFlixMovie>> watch() => const Stream.empty();
}
