import 'package:flutter/foundation.dart';

import '../../../data/services/pauloflix_service.dart';
import '../../../domain/models/pauloflix_content.dart';
import '../../../domain/repositories/paulo_flix_episode_progress_repository.dart';
import '../../../domain/repositories/pauloflix_repository.dart';
import '../../core/utils/pagination.dart';

enum PauloFlixStatus { initial, loading, loaded, error }

/// Provider da área PauloFlix animes.
///
/// Consome `PauloFlixRepository` (Drift). O sync é feito via
/// `PauloFlixService.syncContent` que lê o JSON index.
class PauloFlixProvider extends ChangeNotifier {
  final PauloFlixRepository _repository;
  final PauloFlixEpisodeProgressRepository? _episodeProgressRepository;

  /// Ctor padrão — provider sem dependência (usado em testes/legado).
  PauloFlixProvider()
    : _repository = _NullPauloFlixRepository(),
      _episodeProgressRepository = null;

  /// Ctor com repository — injeta o repositório de progresso para que
  /// `syncContent` popule seasons/episódios diretamente do JSON index.
  PauloFlixProvider.withRepository({
    required PauloFlixRepository repository,
    PauloFlixEpisodeProgressRepository? episodeProgressRepository,
  }) : _repository = repository,
       _episodeProgressRepository = episodeProgressRepository;

  PauloFlixStatus _status = PauloFlixStatus.initial;
  List<PauloFlixContent> _contents = [];
  String? _errorMessage;
  String _syncProgress = '';

  /// `null` = última sync foi bem-sucedida; `String` = mensagem do erro.
  String? _lastSyncError;

  /// Query de busca ativa. `null` ou vazio = sem filtro.
  String _searchQuery = '';

  PauloFlixStatus get status => _status;

  /// Retorna a lista completa ou filtrada conforme _searchQuery.
  /// Evita manter `_filteredContents` duplicada em memória.
  List<PauloFlixContent> get contents {
    if (_searchQuery.isEmpty) return _contents;
    final q = _searchQuery.toLowerCase();
    return _contents.where(
      (c) =>
          c.displayName.toLowerCase().contains(q) ||
          c.genres.any((g) => g.toLowerCase().contains(q)),
    ).toList();
  }

  String? get errorMessage => _errorMessage;
  String get syncProgress => _syncProgress;
  bool get isSyncing => _status == PauloFlixStatus.loading;

  /// `null` se a última sync foi bem-sucedida (ou nunca foi tentada).
  /// String não-vazia se houve erro na última sync.
  String? get lastSyncError => _lastSyncError;

  /// `true` se a última sync falhou. Usado pelo sidebar para mostrar
  /// indicador vermelho.
  bool get hasSyncError => _lastSyncError != null;

  Future<void> loadContents() async {
    _status = PauloFlixStatus.loading;
    notifyListeners();
    try {
      _contents = await _repository.getAll();
      _status = PauloFlixStatus.loaded;
    } catch (e) {
      _errorMessage = 'Erro ao carregar conteúdo: $e';
      _status = PauloFlixStatus.error;
    }
    notifyListeners();
  }

  /// Sync com o servidor via `PauloFlixService` (JSON index).
  Future<void> syncContent() async {
    _status = PauloFlixStatus.loading;
    _syncProgress = 'Iniciando sincronização...';
    _lastSyncError = null;
    notifyListeners();
    try {
      final sync = await PauloFlixService.syncContent(
        repository: _repository,
        onProgress: (progress) {
          _syncProgress = progress;
          notifyListeners();
        },
        onError: (error) {
          _errorMessage = 'Erro na sincronização: $error';
          _lastSyncError = error;
          _status = PauloFlixStatus.error;
          notifyListeners();
        },
        episodeRepository: _episodeProgressRepository,
      );
      if (!sync) {
        _errorMessage = 'Sincronização falhou por motivos desconhecidos.';
        _lastSyncError = _errorMessage;
        _status = PauloFlixStatus.error;
        notifyListeners();
        return;
      }
      _status = PauloFlixStatus.loaded;
    } catch (e) {
      _errorMessage = 'Erro na sincronização: $e';
      _lastSyncError = _errorMessage;
      _status = PauloFlixStatus.error;
    }
    notifyListeners();
  }

  void search(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<List<PauloFlixContent>> searchByName(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    try {
      return await _repository.searchByName(q);
    } catch (e) {
      debugPrint('searchByName falhou: $e');
      return const [];
    }
  }


  // ─── Métodos puros de agrupamento/paginação ───────────────────────────

  static PauloFlixContent? pickFeaturedContent(
    List<PauloFlixContent> contents,
  ) {
    if (contents.isEmpty) return null;
    final sorted = [...contents]
      ..sort((a, b) {
        final scoreCmp = (b.score ?? 0).compareTo(a.score ?? 0);
        if (scoreCmp != 0) return scoreCmp;
        return a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        );
      });
    return sorted.first;
  }

  static Map<String, List<PauloFlixContent>> groupByTopGenres(
    List<PauloFlixContent> contents, {
    int perGenre = 12,
    int minPerGenre = 3,
  }) {
    if (contents.isEmpty) return const {};

    final genreCount = <String, int>{};
    for (final c in contents) {
      for (final g in c.genres) {
        if (g.isEmpty) continue;
        genreCount[g] = (genreCount[g] ?? 0) + 1;
      }
    }

    final topGenres =
        genreCount.entries.where((e) => e.value >= minPerGenre).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final selected = topGenres.map((e) => e.key).toList();

    final result = <String, List<PauloFlixContent>>{};
    for (final g in selected) {
      final filtered = contents.where((c) => c.genres.contains(g)).toList()
        ..sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));
      result[g] = filtered.take(perGenre).toList();
    }
    return result;
  }

  static PaginationResult<PauloFlixContent> paginateByLetter(
    List<PauloFlixContent> contents, {
    int perPage = 24,
  }) {
    if (contents.isEmpty) {
      return const PaginationResult<PauloFlixContent>(
        pages: [],
        letterToPageIndex: {},
        availableLetters: [],
      );
    }

    final sorted = [...contents]
      ..sort((a, b) {
        final aKey = _sortKey(a.displayName);
        final bKey = _sortKey(b.displayName);
        final cmp = aKey.compareTo(bKey);
        if (cmp != 0) return cmp;
        return a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        );
      });

    final pages = <List<PauloFlixContent>>[];
    for (var i = 0; i < sorted.length; i += perPage) {
      final end = i + perPage > sorted.length ? sorted.length : i + perPage;
      pages.add(sorted.sublist(i, end));
    }

    final letterToPageIndex = <String, int>{};
    final availableLetters = <String>[];
    for (var i = 0; i < pages.length; i++) {
      for (final c in pages[i]) {
        final letter = _normalizeFirstChar(c.displayName);
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

    return PaginationResult<PauloFlixContent>(
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

/// Fallback no-op para o ctor sem dependência.
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
