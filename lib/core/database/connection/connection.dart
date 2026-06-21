import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolve o caminho do banco `pauloflix.db` no diretório de documentos do
/// app. No Android, preserva o path legacy `<docs parent>/databases/` que
/// era usado pelo `sqflite` em versões anteriores do app, para que
/// instalações existentes não percam dados.
///
/// Se o banco legado `<docs parent>/databases/pauloflix.db` existir, ele é
/// preferido. Caso contrário, usa `<docs>/pauloflix.db`.
Future<String> resolvePauloflixDbPath() async {
  final docsDir = await getApplicationDocumentsDirectory();

  if (Platform.isAndroid) {
    final legacyDir = Directory(p.join(docsDir.parent.path, 'databases'));
    final legacyPath = p.join(legacyDir.path, 'pauloflix.db');
    if (File(legacyPath).existsSync()) {
      return legacyPath;
    }
    if (!legacyDir.existsSync()) {
      legacyDir.createSync(recursive: true);
    }
    return legacyPath;
  }

  return p.join(docsDir.path, 'pauloflix.db');
}

/// Abre a conexão com o banco `pauloflix.db` em background (não bloqueia
/// a isolate principal). `beforeOpen` ativa WAL e foreign_keys — ambos
/// validados pelos testes de fumaça em `test/database/app_database_test.dart`.
LazyDatabase openConnection() {
  return LazyDatabase(() async {
    final dbPath = await resolvePauloflixDbPath();
    final file = File(dbPath);
    return NativeDatabase.createInBackground(file);
  });
}
