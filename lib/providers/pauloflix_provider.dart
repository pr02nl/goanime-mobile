import 'dart:async';

import 'package:flutter/material.dart';

import '../models/pauloflix_content.dart';
import '../services/pauloflix_database_service.dart';
import '../services/pauloflix_service.dart';

enum PauloFlixStatus { initial, loading, loaded, error }

class PauloFlixProvider extends ChangeNotifier {
  final PauloFlixDatabaseService _dbService;

  PauloFlixProvider({PauloFlixDatabaseService? databaseService})
      : _dbService = databaseService ?? PauloFlixDatabaseService();

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
      _contents = await _dbService.getAllContent();
      _filteredContents = _contents;
      _status = PauloFlixStatus.loaded;
    } catch (e) {
      _errorMessage = 'Erro ao carregar conteúdo: $e';
      _status = PauloFlixStatus.error;
    }

    notifyListeners();
  }

  Future<void> syncContent() async {
    _status = PauloFlixStatus.loading;
    _syncProgress = 'Iniciando sincronização...';
    notifyListeners();

    try {
      final success = await PauloFlixService.syncContent(
        onProgress: (progress) {
          _syncProgress = progress;
          notifyListeners();
        },
        onError: (error) {
          _errorMessage = error;
          notifyListeners();
        },
      );

      if (success) {
        await loadContents();
      } else {
        _status = PauloFlixStatus.error;
      }
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
        _filteredContents = _contents.where((c) =>
          c.displayName.toLowerCase().contains(searchQuery) ||
          c.genres.any((g) => g.toLowerCase().contains(searchQuery))
        ).toList();
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
    return _contents.any((c) =>
      c.displayName.toLowerCase() == animeName.toLowerCase() ||
      c.folderName.toLowerCase() == animeName.toLowerCase()
    );
  }
}
