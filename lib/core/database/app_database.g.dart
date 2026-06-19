// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $WatchlistItemsTable extends WatchlistItems
    with TableInfo<$WatchlistItemsTable, WatchlistItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchlistItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _animeIdMeta = const VerificationMeta(
    'animeId',
  );
  @override
  late final GeneratedColumn<String> animeId = GeneratedColumn<String>(
    'anime_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverImageMeta = const VerificationMeta(
    'coverImage',
  );
  @override
  late final GeneratedColumn<String> coverImage = GeneratedColumn<String>(
    'cover_image',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _myAnimeListUrlMeta = const VerificationMeta(
    'myAnimeListUrl',
  );
  @override
  late final GeneratedColumn<String> myAnimeListUrl = GeneratedColumn<String>(
    'my_anime_list_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    animeId,
    title,
    coverImage,
    myAnimeListUrl,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watchlist_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<WatchlistItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('anime_id')) {
      context.handle(
        _animeIdMeta,
        animeId.isAcceptableOrUnknown(data['anime_id']!, _animeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_animeIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('cover_image')) {
      context.handle(
        _coverImageMeta,
        coverImage.isAcceptableOrUnknown(data['cover_image']!, _coverImageMeta),
      );
    } else if (isInserting) {
      context.missing(_coverImageMeta);
    }
    if (data.containsKey('my_anime_list_url')) {
      context.handle(
        _myAnimeListUrlMeta,
        myAnimeListUrl.isAcceptableOrUnknown(
          data['my_anime_list_url']!,
          _myAnimeListUrlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_myAnimeListUrlMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WatchlistItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchlistItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      animeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}anime_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      coverImage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_image'],
      )!,
      myAnimeListUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}my_anime_list_url'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $WatchlistItemsTable createAlias(String alias) {
    return $WatchlistItemsTable(attachedDatabase, alias);
  }
}

class WatchlistItem extends DataClass implements Insertable<WatchlistItem> {
  final int id;
  final String animeId;
  final String title;
  final String coverImage;
  final String myAnimeListUrl;
  final DateTime addedAt;
  const WatchlistItem({
    required this.id,
    required this.animeId,
    required this.title,
    required this.coverImage,
    required this.myAnimeListUrl,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['anime_id'] = Variable<String>(animeId);
    map['title'] = Variable<String>(title);
    map['cover_image'] = Variable<String>(coverImage);
    map['my_anime_list_url'] = Variable<String>(myAnimeListUrl);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  WatchlistItemsCompanion toCompanion(bool nullToAbsent) {
    return WatchlistItemsCompanion(
      id: Value(id),
      animeId: Value(animeId),
      title: Value(title),
      coverImage: Value(coverImage),
      myAnimeListUrl: Value(myAnimeListUrl),
      addedAt: Value(addedAt),
    );
  }

  factory WatchlistItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchlistItem(
      id: serializer.fromJson<int>(json['id']),
      animeId: serializer.fromJson<String>(json['animeId']),
      title: serializer.fromJson<String>(json['title']),
      coverImage: serializer.fromJson<String>(json['coverImage']),
      myAnimeListUrl: serializer.fromJson<String>(json['myAnimeListUrl']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'animeId': serializer.toJson<String>(animeId),
      'title': serializer.toJson<String>(title),
      'coverImage': serializer.toJson<String>(coverImage),
      'myAnimeListUrl': serializer.toJson<String>(myAnimeListUrl),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  WatchlistItem copyWith({
    int? id,
    String? animeId,
    String? title,
    String? coverImage,
    String? myAnimeListUrl,
    DateTime? addedAt,
  }) => WatchlistItem(
    id: id ?? this.id,
    animeId: animeId ?? this.animeId,
    title: title ?? this.title,
    coverImage: coverImage ?? this.coverImage,
    myAnimeListUrl: myAnimeListUrl ?? this.myAnimeListUrl,
    addedAt: addedAt ?? this.addedAt,
  );
  WatchlistItem copyWithCompanion(WatchlistItemsCompanion data) {
    return WatchlistItem(
      id: data.id.present ? data.id.value : this.id,
      animeId: data.animeId.present ? data.animeId.value : this.animeId,
      title: data.title.present ? data.title.value : this.title,
      coverImage: data.coverImage.present
          ? data.coverImage.value
          : this.coverImage,
      myAnimeListUrl: data.myAnimeListUrl.present
          ? data.myAnimeListUrl.value
          : this.myAnimeListUrl,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchlistItem(')
          ..write('id: $id, ')
          ..write('animeId: $animeId, ')
          ..write('title: $title, ')
          ..write('coverImage: $coverImage, ')
          ..write('myAnimeListUrl: $myAnimeListUrl, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, animeId, title, coverImage, myAnimeListUrl, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchlistItem &&
          other.id == this.id &&
          other.animeId == this.animeId &&
          other.title == this.title &&
          other.coverImage == this.coverImage &&
          other.myAnimeListUrl == this.myAnimeListUrl &&
          other.addedAt == this.addedAt);
}

class WatchlistItemsCompanion extends UpdateCompanion<WatchlistItem> {
  final Value<int> id;
  final Value<String> animeId;
  final Value<String> title;
  final Value<String> coverImage;
  final Value<String> myAnimeListUrl;
  final Value<DateTime> addedAt;
  const WatchlistItemsCompanion({
    this.id = const Value.absent(),
    this.animeId = const Value.absent(),
    this.title = const Value.absent(),
    this.coverImage = const Value.absent(),
    this.myAnimeListUrl = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  WatchlistItemsCompanion.insert({
    this.id = const Value.absent(),
    required String animeId,
    required String title,
    required String coverImage,
    required String myAnimeListUrl,
    this.addedAt = const Value.absent(),
  }) : animeId = Value(animeId),
       title = Value(title),
       coverImage = Value(coverImage),
       myAnimeListUrl = Value(myAnimeListUrl);
  static Insertable<WatchlistItem> custom({
    Expression<int>? id,
    Expression<String>? animeId,
    Expression<String>? title,
    Expression<String>? coverImage,
    Expression<String>? myAnimeListUrl,
    Expression<DateTime>? addedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (animeId != null) 'anime_id': animeId,
      if (title != null) 'title': title,
      if (coverImage != null) 'cover_image': coverImage,
      if (myAnimeListUrl != null) 'my_anime_list_url': myAnimeListUrl,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  WatchlistItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? animeId,
    Value<String>? title,
    Value<String>? coverImage,
    Value<String>? myAnimeListUrl,
    Value<DateTime>? addedAt,
  }) {
    return WatchlistItemsCompanion(
      id: id ?? this.id,
      animeId: animeId ?? this.animeId,
      title: title ?? this.title,
      coverImage: coverImage ?? this.coverImage,
      myAnimeListUrl: myAnimeListUrl ?? this.myAnimeListUrl,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (animeId.present) {
      map['anime_id'] = Variable<String>(animeId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (coverImage.present) {
      map['cover_image'] = Variable<String>(coverImage.value);
    }
    if (myAnimeListUrl.present) {
      map['my_anime_list_url'] = Variable<String>(myAnimeListUrl.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchlistItemsCompanion(')
          ..write('id: $id, ')
          ..write('animeId: $animeId, ')
          ..write('title: $title, ')
          ..write('coverImage: $coverImage, ')
          ..write('myAnimeListUrl: $myAnimeListUrl, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

class $DownloadsTable extends Downloads
    with TableInfo<$DownloadsTable, Download> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _downloadIdMeta = const VerificationMeta(
    'downloadId',
  );
  @override
  late final GeneratedColumn<String> downloadId = GeneratedColumn<String>(
    'download_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _animeIdMeta = const VerificationMeta(
    'animeId',
  );
  @override
  late final GeneratedColumn<String> animeId = GeneratedColumn<String>(
    'anime_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _animeNameMeta = const VerificationMeta(
    'animeName',
  );
  @override
  late final GeneratedColumn<String> animeName = GeneratedColumn<String>(
    'anime_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _episodeNumberMeta = const VerificationMeta(
    'episodeNumber',
  );
  @override
  late final GeneratedColumn<String> episodeNumber = GeneratedColumn<String>(
    'episode_number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _episodeTitleMeta = const VerificationMeta(
    'episodeTitle',
  );
  @override
  late final GeneratedColumn<String> episodeTitle = GeneratedColumn<String>(
    'episode_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _videoUrlMeta = const VerificationMeta(
    'videoUrl',
  );
  @override
  late final GeneratedColumn<String> videoUrl = GeneratedColumn<String>(
    'video_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thumbnailUrlMeta = const VerificationMeta(
    'thumbnailUrl',
  );
  @override
  late final GeneratedColumn<String> thumbnailUrl = GeneratedColumn<String>(
    'thumbnail_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qualityMeta = const VerificationMeta(
    'quality',
  );
  @override
  late final GeneratedColumn<int> quality = GeneratedColumn<int>(
    'quality',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _bytesDownloadedMeta = const VerificationMeta(
    'bytesDownloaded',
  );
  @override
  late final GeneratedColumn<int> bytesDownloaded = GeneratedColumn<int>(
    'bytes_downloaded',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalBytesMeta = const VerificationMeta(
    'totalBytes',
  );
  @override
  late final GeneratedColumn<int> totalBytes = GeneratedColumn<int>(
    'total_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    downloadId,
    animeId,
    animeName,
    episodeNumber,
    episodeTitle,
    videoUrl,
    thumbnailUrl,
    quality,
    status,
    progress,
    bytesDownloaded,
    totalBytes,
    filePath,
    error,
    createdAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'downloads';
  @override
  VerificationContext validateIntegrity(
    Insertable<Download> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('download_id')) {
      context.handle(
        _downloadIdMeta,
        downloadId.isAcceptableOrUnknown(data['download_id']!, _downloadIdMeta),
      );
    } else if (isInserting) {
      context.missing(_downloadIdMeta);
    }
    if (data.containsKey('anime_id')) {
      context.handle(
        _animeIdMeta,
        animeId.isAcceptableOrUnknown(data['anime_id']!, _animeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_animeIdMeta);
    }
    if (data.containsKey('anime_name')) {
      context.handle(
        _animeNameMeta,
        animeName.isAcceptableOrUnknown(data['anime_name']!, _animeNameMeta),
      );
    } else if (isInserting) {
      context.missing(_animeNameMeta);
    }
    if (data.containsKey('episode_number')) {
      context.handle(
        _episodeNumberMeta,
        episodeNumber.isAcceptableOrUnknown(
          data['episode_number']!,
          _episodeNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_episodeNumberMeta);
    }
    if (data.containsKey('episode_title')) {
      context.handle(
        _episodeTitleMeta,
        episodeTitle.isAcceptableOrUnknown(
          data['episode_title']!,
          _episodeTitleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_episodeTitleMeta);
    }
    if (data.containsKey('video_url')) {
      context.handle(
        _videoUrlMeta,
        videoUrl.isAcceptableOrUnknown(data['video_url']!, _videoUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_videoUrlMeta);
    }
    if (data.containsKey('thumbnail_url')) {
      context.handle(
        _thumbnailUrlMeta,
        thumbnailUrl.isAcceptableOrUnknown(
          data['thumbnail_url']!,
          _thumbnailUrlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_thumbnailUrlMeta);
    }
    if (data.containsKey('quality')) {
      context.handle(
        _qualityMeta,
        quality.isAcceptableOrUnknown(data['quality']!, _qualityMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('bytes_downloaded')) {
      context.handle(
        _bytesDownloadedMeta,
        bytesDownloaded.isAcceptableOrUnknown(
          data['bytes_downloaded']!,
          _bytesDownloadedMeta,
        ),
      );
    }
    if (data.containsKey('total_bytes')) {
      context.handle(
        _totalBytesMeta,
        totalBytes.isAcceptableOrUnknown(data['total_bytes']!, _totalBytesMeta),
      );
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Download map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Download(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      downloadId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}download_id'],
      )!,
      animeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}anime_id'],
      )!,
      animeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}anime_name'],
      )!,
      episodeNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_number'],
      )!,
      episodeTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_title'],
      )!,
      videoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_url'],
      )!,
      thumbnailUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_url'],
      )!,
      quality: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quality'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress'],
      )!,
      bytesDownloaded: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes_downloaded'],
      )!,
      totalBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_bytes'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      ),
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $DownloadsTable createAlias(String alias) {
    return $DownloadsTable(attachedDatabase, alias);
  }
}

class Download extends DataClass implements Insertable<Download> {
  final int id;
  final String downloadId;
  final String animeId;
  final String animeName;
  final String episodeNumber;
  final String episodeTitle;
  final String videoUrl;
  final String thumbnailUrl;
  final int quality;
  final int status;
  final double progress;
  final int bytesDownloaded;
  final int totalBytes;
  final String? filePath;
  final String? error;
  final DateTime createdAt;
  final DateTime? completedAt;
  const Download({
    required this.id,
    required this.downloadId,
    required this.animeId,
    required this.animeName,
    required this.episodeNumber,
    required this.episodeTitle,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.quality,
    required this.status,
    required this.progress,
    required this.bytesDownloaded,
    required this.totalBytes,
    this.filePath,
    this.error,
    required this.createdAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['download_id'] = Variable<String>(downloadId);
    map['anime_id'] = Variable<String>(animeId);
    map['anime_name'] = Variable<String>(animeName);
    map['episode_number'] = Variable<String>(episodeNumber);
    map['episode_title'] = Variable<String>(episodeTitle);
    map['video_url'] = Variable<String>(videoUrl);
    map['thumbnail_url'] = Variable<String>(thumbnailUrl);
    map['quality'] = Variable<int>(quality);
    map['status'] = Variable<int>(status);
    map['progress'] = Variable<double>(progress);
    map['bytes_downloaded'] = Variable<int>(bytesDownloaded);
    map['total_bytes'] = Variable<int>(totalBytes);
    if (!nullToAbsent || filePath != null) {
      map['file_path'] = Variable<String>(filePath);
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  DownloadsCompanion toCompanion(bool nullToAbsent) {
    return DownloadsCompanion(
      id: Value(id),
      downloadId: Value(downloadId),
      animeId: Value(animeId),
      animeName: Value(animeName),
      episodeNumber: Value(episodeNumber),
      episodeTitle: Value(episodeTitle),
      videoUrl: Value(videoUrl),
      thumbnailUrl: Value(thumbnailUrl),
      quality: Value(quality),
      status: Value(status),
      progress: Value(progress),
      bytesDownloaded: Value(bytesDownloaded),
      totalBytes: Value(totalBytes),
      filePath: filePath == null && nullToAbsent
          ? const Value.absent()
          : Value(filePath),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      createdAt: Value(createdAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory Download.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Download(
      id: serializer.fromJson<int>(json['id']),
      downloadId: serializer.fromJson<String>(json['downloadId']),
      animeId: serializer.fromJson<String>(json['animeId']),
      animeName: serializer.fromJson<String>(json['animeName']),
      episodeNumber: serializer.fromJson<String>(json['episodeNumber']),
      episodeTitle: serializer.fromJson<String>(json['episodeTitle']),
      videoUrl: serializer.fromJson<String>(json['videoUrl']),
      thumbnailUrl: serializer.fromJson<String>(json['thumbnailUrl']),
      quality: serializer.fromJson<int>(json['quality']),
      status: serializer.fromJson<int>(json['status']),
      progress: serializer.fromJson<double>(json['progress']),
      bytesDownloaded: serializer.fromJson<int>(json['bytesDownloaded']),
      totalBytes: serializer.fromJson<int>(json['totalBytes']),
      filePath: serializer.fromJson<String?>(json['filePath']),
      error: serializer.fromJson<String?>(json['error']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'downloadId': serializer.toJson<String>(downloadId),
      'animeId': serializer.toJson<String>(animeId),
      'animeName': serializer.toJson<String>(animeName),
      'episodeNumber': serializer.toJson<String>(episodeNumber),
      'episodeTitle': serializer.toJson<String>(episodeTitle),
      'videoUrl': serializer.toJson<String>(videoUrl),
      'thumbnailUrl': serializer.toJson<String>(thumbnailUrl),
      'quality': serializer.toJson<int>(quality),
      'status': serializer.toJson<int>(status),
      'progress': serializer.toJson<double>(progress),
      'bytesDownloaded': serializer.toJson<int>(bytesDownloaded),
      'totalBytes': serializer.toJson<int>(totalBytes),
      'filePath': serializer.toJson<String?>(filePath),
      'error': serializer.toJson<String?>(error),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  Download copyWith({
    int? id,
    String? downloadId,
    String? animeId,
    String? animeName,
    String? episodeNumber,
    String? episodeTitle,
    String? videoUrl,
    String? thumbnailUrl,
    int? quality,
    int? status,
    double? progress,
    int? bytesDownloaded,
    int? totalBytes,
    Value<String?> filePath = const Value.absent(),
    Value<String?> error = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => Download(
    id: id ?? this.id,
    downloadId: downloadId ?? this.downloadId,
    animeId: animeId ?? this.animeId,
    animeName: animeName ?? this.animeName,
    episodeNumber: episodeNumber ?? this.episodeNumber,
    episodeTitle: episodeTitle ?? this.episodeTitle,
    videoUrl: videoUrl ?? this.videoUrl,
    thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    quality: quality ?? this.quality,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
    totalBytes: totalBytes ?? this.totalBytes,
    filePath: filePath.present ? filePath.value : this.filePath,
    error: error.present ? error.value : this.error,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  Download copyWithCompanion(DownloadsCompanion data) {
    return Download(
      id: data.id.present ? data.id.value : this.id,
      downloadId: data.downloadId.present
          ? data.downloadId.value
          : this.downloadId,
      animeId: data.animeId.present ? data.animeId.value : this.animeId,
      animeName: data.animeName.present ? data.animeName.value : this.animeName,
      episodeNumber: data.episodeNumber.present
          ? data.episodeNumber.value
          : this.episodeNumber,
      episodeTitle: data.episodeTitle.present
          ? data.episodeTitle.value
          : this.episodeTitle,
      videoUrl: data.videoUrl.present ? data.videoUrl.value : this.videoUrl,
      thumbnailUrl: data.thumbnailUrl.present
          ? data.thumbnailUrl.value
          : this.thumbnailUrl,
      quality: data.quality.present ? data.quality.value : this.quality,
      status: data.status.present ? data.status.value : this.status,
      progress: data.progress.present ? data.progress.value : this.progress,
      bytesDownloaded: data.bytesDownloaded.present
          ? data.bytesDownloaded.value
          : this.bytesDownloaded,
      totalBytes: data.totalBytes.present
          ? data.totalBytes.value
          : this.totalBytes,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      error: data.error.present ? data.error.value : this.error,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Download(')
          ..write('id: $id, ')
          ..write('downloadId: $downloadId, ')
          ..write('animeId: $animeId, ')
          ..write('animeName: $animeName, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('episodeTitle: $episodeTitle, ')
          ..write('videoUrl: $videoUrl, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('quality: $quality, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('bytesDownloaded: $bytesDownloaded, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('filePath: $filePath, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    downloadId,
    animeId,
    animeName,
    episodeNumber,
    episodeTitle,
    videoUrl,
    thumbnailUrl,
    quality,
    status,
    progress,
    bytesDownloaded,
    totalBytes,
    filePath,
    error,
    createdAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Download &&
          other.id == this.id &&
          other.downloadId == this.downloadId &&
          other.animeId == this.animeId &&
          other.animeName == this.animeName &&
          other.episodeNumber == this.episodeNumber &&
          other.episodeTitle == this.episodeTitle &&
          other.videoUrl == this.videoUrl &&
          other.thumbnailUrl == this.thumbnailUrl &&
          other.quality == this.quality &&
          other.status == this.status &&
          other.progress == this.progress &&
          other.bytesDownloaded == this.bytesDownloaded &&
          other.totalBytes == this.totalBytes &&
          other.filePath == this.filePath &&
          other.error == this.error &&
          other.createdAt == this.createdAt &&
          other.completedAt == this.completedAt);
}

class DownloadsCompanion extends UpdateCompanion<Download> {
  final Value<int> id;
  final Value<String> downloadId;
  final Value<String> animeId;
  final Value<String> animeName;
  final Value<String> episodeNumber;
  final Value<String> episodeTitle;
  final Value<String> videoUrl;
  final Value<String> thumbnailUrl;
  final Value<int> quality;
  final Value<int> status;
  final Value<double> progress;
  final Value<int> bytesDownloaded;
  final Value<int> totalBytes;
  final Value<String?> filePath;
  final Value<String?> error;
  final Value<DateTime> createdAt;
  final Value<DateTime?> completedAt;
  const DownloadsCompanion({
    this.id = const Value.absent(),
    this.downloadId = const Value.absent(),
    this.animeId = const Value.absent(),
    this.animeName = const Value.absent(),
    this.episodeNumber = const Value.absent(),
    this.episodeTitle = const Value.absent(),
    this.videoUrl = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.quality = const Value.absent(),
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    this.bytesDownloaded = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.filePath = const Value.absent(),
    this.error = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
  });
  DownloadsCompanion.insert({
    this.id = const Value.absent(),
    required String downloadId,
    required String animeId,
    required String animeName,
    required String episodeNumber,
    required String episodeTitle,
    required String videoUrl,
    required String thumbnailUrl,
    this.quality = const Value.absent(),
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    this.bytesDownloaded = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.filePath = const Value.absent(),
    this.error = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
  }) : downloadId = Value(downloadId),
       animeId = Value(animeId),
       animeName = Value(animeName),
       episodeNumber = Value(episodeNumber),
       episodeTitle = Value(episodeTitle),
       videoUrl = Value(videoUrl),
       thumbnailUrl = Value(thumbnailUrl);
  static Insertable<Download> custom({
    Expression<int>? id,
    Expression<String>? downloadId,
    Expression<String>? animeId,
    Expression<String>? animeName,
    Expression<String>? episodeNumber,
    Expression<String>? episodeTitle,
    Expression<String>? videoUrl,
    Expression<String>? thumbnailUrl,
    Expression<int>? quality,
    Expression<int>? status,
    Expression<double>? progress,
    Expression<int>? bytesDownloaded,
    Expression<int>? totalBytes,
    Expression<String>? filePath,
    Expression<String>? error,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? completedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (downloadId != null) 'download_id': downloadId,
      if (animeId != null) 'anime_id': animeId,
      if (animeName != null) 'anime_name': animeName,
      if (episodeNumber != null) 'episode_number': episodeNumber,
      if (episodeTitle != null) 'episode_title': episodeTitle,
      if (videoUrl != null) 'video_url': videoUrl,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (quality != null) 'quality': quality,
      if (status != null) 'status': status,
      if (progress != null) 'progress': progress,
      if (bytesDownloaded != null) 'bytes_downloaded': bytesDownloaded,
      if (totalBytes != null) 'total_bytes': totalBytes,
      if (filePath != null) 'file_path': filePath,
      if (error != null) 'error': error,
      if (createdAt != null) 'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
    });
  }

  DownloadsCompanion copyWith({
    Value<int>? id,
    Value<String>? downloadId,
    Value<String>? animeId,
    Value<String>? animeName,
    Value<String>? episodeNumber,
    Value<String>? episodeTitle,
    Value<String>? videoUrl,
    Value<String>? thumbnailUrl,
    Value<int>? quality,
    Value<int>? status,
    Value<double>? progress,
    Value<int>? bytesDownloaded,
    Value<int>? totalBytes,
    Value<String?>? filePath,
    Value<String?>? error,
    Value<DateTime>? createdAt,
    Value<DateTime?>? completedAt,
  }) {
    return DownloadsCompanion(
      id: id ?? this.id,
      downloadId: downloadId ?? this.downloadId,
      animeId: animeId ?? this.animeId,
      animeName: animeName ?? this.animeName,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      episodeTitle: episodeTitle ?? this.episodeTitle,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      quality: quality ?? this.quality,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytes: totalBytes ?? this.totalBytes,
      filePath: filePath ?? this.filePath,
      error: error ?? this.error,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (downloadId.present) {
      map['download_id'] = Variable<String>(downloadId.value);
    }
    if (animeId.present) {
      map['anime_id'] = Variable<String>(animeId.value);
    }
    if (animeName.present) {
      map['anime_name'] = Variable<String>(animeName.value);
    }
    if (episodeNumber.present) {
      map['episode_number'] = Variable<String>(episodeNumber.value);
    }
    if (episodeTitle.present) {
      map['episode_title'] = Variable<String>(episodeTitle.value);
    }
    if (videoUrl.present) {
      map['video_url'] = Variable<String>(videoUrl.value);
    }
    if (thumbnailUrl.present) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl.value);
    }
    if (quality.present) {
      map['quality'] = Variable<int>(quality.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (bytesDownloaded.present) {
      map['bytes_downloaded'] = Variable<int>(bytesDownloaded.value);
    }
    if (totalBytes.present) {
      map['total_bytes'] = Variable<int>(totalBytes.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadsCompanion(')
          ..write('id: $id, ')
          ..write('downloadId: $downloadId, ')
          ..write('animeId: $animeId, ')
          ..write('animeName: $animeName, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('episodeTitle: $episodeTitle, ')
          ..write('videoUrl: $videoUrl, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('quality: $quality, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('bytesDownloaded: $bytesDownloaded, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('filePath: $filePath, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }
}

class $PauloFlixContentTable extends PauloFlixContent
    with TableInfo<$PauloFlixContentTable, PauloFlixContentData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PauloFlixContentTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _folderNameMeta = const VerificationMeta(
    'folderName',
  );
  @override
  late final GeneratedColumn<String> folderName = GeneratedColumn<String>(
    'folder_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverUrlMeta = const VerificationMeta(
    'serverUrl',
  );
  @override
  late final GeneratedColumn<String> serverUrl = GeneratedColumn<String>(
    'server_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bannerUrlMeta = const VerificationMeta(
    'bannerUrl',
  );
  @override
  late final GeneratedColumn<String> bannerUrl = GeneratedColumn<String>(
    'banner_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<double> score = GeneratedColumn<double>(
    'score',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genresMeta = const VerificationMeta('genres');
  @override
  late final GeneratedColumn<String> genres = GeneratedColumn<String>(
    'genres',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeCountMeta = const VerificationMeta(
    'episodeCount',
  );
  @override
  late final GeneratedColumn<int> episodeCount = GeneratedColumn<int>(
    'episode_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _malIdMeta = const VerificationMeta('malId');
  @override
  late final GeneratedColumn<int> malId = GeneratedColumn<int>(
    'mal_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _anilistIdMeta = const VerificationMeta(
    'anilistId',
  );
  @override
  late final GeneratedColumn<int> anilistId = GeneratedColumn<int>(
    'anilist_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncedMeta = const VerificationMeta(
    'lastSynced',
  );
  @override
  late final GeneratedColumn<DateTime> lastSynced = GeneratedColumn<DateTime>(
    'last_synced',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isAvailableMeta = const VerificationMeta(
    'isAvailable',
  );
  @override
  late final GeneratedColumn<bool> isAvailable = GeneratedColumn<bool>(
    'is_available',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_available" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    folderName,
    displayName,
    serverUrl,
    imageUrl,
    bannerUrl,
    description,
    score,
    genres,
    status,
    episodeCount,
    malId,
    anilistId,
    lastSynced,
    isAvailable,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'paulo_flix_content';
  @override
  VerificationContext validateIntegrity(
    Insertable<PauloFlixContentData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('folder_name')) {
      context.handle(
        _folderNameMeta,
        folderName.isAcceptableOrUnknown(data['folder_name']!, _folderNameMeta),
      );
    } else if (isInserting) {
      context.missing(_folderNameMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('server_url')) {
      context.handle(
        _serverUrlMeta,
        serverUrl.isAcceptableOrUnknown(data['server_url']!, _serverUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_serverUrlMeta);
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('banner_url')) {
      context.handle(
        _bannerUrlMeta,
        bannerUrl.isAcceptableOrUnknown(data['banner_url']!, _bannerUrlMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    }
    if (data.containsKey('genres')) {
      context.handle(
        _genresMeta,
        genres.isAcceptableOrUnknown(data['genres']!, _genresMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('episode_count')) {
      context.handle(
        _episodeCountMeta,
        episodeCount.isAcceptableOrUnknown(
          data['episode_count']!,
          _episodeCountMeta,
        ),
      );
    }
    if (data.containsKey('mal_id')) {
      context.handle(
        _malIdMeta,
        malId.isAcceptableOrUnknown(data['mal_id']!, _malIdMeta),
      );
    }
    if (data.containsKey('anilist_id')) {
      context.handle(
        _anilistIdMeta,
        anilistId.isAcceptableOrUnknown(data['anilist_id']!, _anilistIdMeta),
      );
    }
    if (data.containsKey('last_synced')) {
      context.handle(
        _lastSyncedMeta,
        lastSynced.isAcceptableOrUnknown(data['last_synced']!, _lastSyncedMeta),
      );
    } else if (isInserting) {
      context.missing(_lastSyncedMeta);
    }
    if (data.containsKey('is_available')) {
      context.handle(
        _isAvailableMeta,
        isAvailable.isAcceptableOrUnknown(
          data['is_available']!,
          _isAvailableMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PauloFlixContentData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PauloFlixContentData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      folderName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_name'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      serverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_url'],
      )!,
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      bannerUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}banner_url'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}score'],
      ),
      genres: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genres'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      ),
      episodeCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode_count'],
      ),
      malId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mal_id'],
      ),
      anilistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}anilist_id'],
      ),
      lastSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced'],
      )!,
      isAvailable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_available'],
      )!,
    );
  }

  @override
  $PauloFlixContentTable createAlias(String alias) {
    return $PauloFlixContentTable(attachedDatabase, alias);
  }
}

class PauloFlixContentData extends DataClass
    implements Insertable<PauloFlixContentData> {
  final int id;
  final String folderName;
  final String displayName;
  final String serverUrl;
  final String? imageUrl;
  final String? bannerUrl;
  final String? description;
  final double? score;
  final String? genres;
  final String? status;
  final int? episodeCount;
  final int? malId;
  final int? anilistId;
  final DateTime lastSynced;
  final bool isAvailable;
  const PauloFlixContentData({
    required this.id,
    required this.folderName,
    required this.displayName,
    required this.serverUrl,
    this.imageUrl,
    this.bannerUrl,
    this.description,
    this.score,
    this.genres,
    this.status,
    this.episodeCount,
    this.malId,
    this.anilistId,
    required this.lastSynced,
    required this.isAvailable,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['folder_name'] = Variable<String>(folderName);
    map['display_name'] = Variable<String>(displayName);
    map['server_url'] = Variable<String>(serverUrl);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || bannerUrl != null) {
      map['banner_url'] = Variable<String>(bannerUrl);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || score != null) {
      map['score'] = Variable<double>(score);
    }
    if (!nullToAbsent || genres != null) {
      map['genres'] = Variable<String>(genres);
    }
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(status);
    }
    if (!nullToAbsent || episodeCount != null) {
      map['episode_count'] = Variable<int>(episodeCount);
    }
    if (!nullToAbsent || malId != null) {
      map['mal_id'] = Variable<int>(malId);
    }
    if (!nullToAbsent || anilistId != null) {
      map['anilist_id'] = Variable<int>(anilistId);
    }
    map['last_synced'] = Variable<DateTime>(lastSynced);
    map['is_available'] = Variable<bool>(isAvailable);
    return map;
  }

  PauloFlixContentCompanion toCompanion(bool nullToAbsent) {
    return PauloFlixContentCompanion(
      id: Value(id),
      folderName: Value(folderName),
      displayName: Value(displayName),
      serverUrl: Value(serverUrl),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      bannerUrl: bannerUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(bannerUrl),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      score: score == null && nullToAbsent
          ? const Value.absent()
          : Value(score),
      genres: genres == null && nullToAbsent
          ? const Value.absent()
          : Value(genres),
      status: status == null && nullToAbsent
          ? const Value.absent()
          : Value(status),
      episodeCount: episodeCount == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeCount),
      malId: malId == null && nullToAbsent
          ? const Value.absent()
          : Value(malId),
      anilistId: anilistId == null && nullToAbsent
          ? const Value.absent()
          : Value(anilistId),
      lastSynced: Value(lastSynced),
      isAvailable: Value(isAvailable),
    );
  }

  factory PauloFlixContentData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PauloFlixContentData(
      id: serializer.fromJson<int>(json['id']),
      folderName: serializer.fromJson<String>(json['folderName']),
      displayName: serializer.fromJson<String>(json['displayName']),
      serverUrl: serializer.fromJson<String>(json['serverUrl']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      bannerUrl: serializer.fromJson<String?>(json['bannerUrl']),
      description: serializer.fromJson<String?>(json['description']),
      score: serializer.fromJson<double?>(json['score']),
      genres: serializer.fromJson<String?>(json['genres']),
      status: serializer.fromJson<String?>(json['status']),
      episodeCount: serializer.fromJson<int?>(json['episodeCount']),
      malId: serializer.fromJson<int?>(json['malId']),
      anilistId: serializer.fromJson<int?>(json['anilistId']),
      lastSynced: serializer.fromJson<DateTime>(json['lastSynced']),
      isAvailable: serializer.fromJson<bool>(json['isAvailable']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'folderName': serializer.toJson<String>(folderName),
      'displayName': serializer.toJson<String>(displayName),
      'serverUrl': serializer.toJson<String>(serverUrl),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'bannerUrl': serializer.toJson<String?>(bannerUrl),
      'description': serializer.toJson<String?>(description),
      'score': serializer.toJson<double?>(score),
      'genres': serializer.toJson<String?>(genres),
      'status': serializer.toJson<String?>(status),
      'episodeCount': serializer.toJson<int?>(episodeCount),
      'malId': serializer.toJson<int?>(malId),
      'anilistId': serializer.toJson<int?>(anilistId),
      'lastSynced': serializer.toJson<DateTime>(lastSynced),
      'isAvailable': serializer.toJson<bool>(isAvailable),
    };
  }

  PauloFlixContentData copyWith({
    int? id,
    String? folderName,
    String? displayName,
    String? serverUrl,
    Value<String?> imageUrl = const Value.absent(),
    Value<String?> bannerUrl = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<double?> score = const Value.absent(),
    Value<String?> genres = const Value.absent(),
    Value<String?> status = const Value.absent(),
    Value<int?> episodeCount = const Value.absent(),
    Value<int?> malId = const Value.absent(),
    Value<int?> anilistId = const Value.absent(),
    DateTime? lastSynced,
    bool? isAvailable,
  }) => PauloFlixContentData(
    id: id ?? this.id,
    folderName: folderName ?? this.folderName,
    displayName: displayName ?? this.displayName,
    serverUrl: serverUrl ?? this.serverUrl,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    bannerUrl: bannerUrl.present ? bannerUrl.value : this.bannerUrl,
    description: description.present ? description.value : this.description,
    score: score.present ? score.value : this.score,
    genres: genres.present ? genres.value : this.genres,
    status: status.present ? status.value : this.status,
    episodeCount: episodeCount.present ? episodeCount.value : this.episodeCount,
    malId: malId.present ? malId.value : this.malId,
    anilistId: anilistId.present ? anilistId.value : this.anilistId,
    lastSynced: lastSynced ?? this.lastSynced,
    isAvailable: isAvailable ?? this.isAvailable,
  );
  PauloFlixContentData copyWithCompanion(PauloFlixContentCompanion data) {
    return PauloFlixContentData(
      id: data.id.present ? data.id.value : this.id,
      folderName: data.folderName.present
          ? data.folderName.value
          : this.folderName,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      serverUrl: data.serverUrl.present ? data.serverUrl.value : this.serverUrl,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      bannerUrl: data.bannerUrl.present ? data.bannerUrl.value : this.bannerUrl,
      description: data.description.present
          ? data.description.value
          : this.description,
      score: data.score.present ? data.score.value : this.score,
      genres: data.genres.present ? data.genres.value : this.genres,
      status: data.status.present ? data.status.value : this.status,
      episodeCount: data.episodeCount.present
          ? data.episodeCount.value
          : this.episodeCount,
      malId: data.malId.present ? data.malId.value : this.malId,
      anilistId: data.anilistId.present ? data.anilistId.value : this.anilistId,
      lastSynced: data.lastSynced.present
          ? data.lastSynced.value
          : this.lastSynced,
      isAvailable: data.isAvailable.present
          ? data.isAvailable.value
          : this.isAvailable,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PauloFlixContentData(')
          ..write('id: $id, ')
          ..write('folderName: $folderName, ')
          ..write('displayName: $displayName, ')
          ..write('serverUrl: $serverUrl, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('bannerUrl: $bannerUrl, ')
          ..write('description: $description, ')
          ..write('score: $score, ')
          ..write('genres: $genres, ')
          ..write('status: $status, ')
          ..write('episodeCount: $episodeCount, ')
          ..write('malId: $malId, ')
          ..write('anilistId: $anilistId, ')
          ..write('lastSynced: $lastSynced, ')
          ..write('isAvailable: $isAvailable')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    folderName,
    displayName,
    serverUrl,
    imageUrl,
    bannerUrl,
    description,
    score,
    genres,
    status,
    episodeCount,
    malId,
    anilistId,
    lastSynced,
    isAvailable,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PauloFlixContentData &&
          other.id == this.id &&
          other.folderName == this.folderName &&
          other.displayName == this.displayName &&
          other.serverUrl == this.serverUrl &&
          other.imageUrl == this.imageUrl &&
          other.bannerUrl == this.bannerUrl &&
          other.description == this.description &&
          other.score == this.score &&
          other.genres == this.genres &&
          other.status == this.status &&
          other.episodeCount == this.episodeCount &&
          other.malId == this.malId &&
          other.anilistId == this.anilistId &&
          other.lastSynced == this.lastSynced &&
          other.isAvailable == this.isAvailable);
}

class PauloFlixContentCompanion extends UpdateCompanion<PauloFlixContentData> {
  final Value<int> id;
  final Value<String> folderName;
  final Value<String> displayName;
  final Value<String> serverUrl;
  final Value<String?> imageUrl;
  final Value<String?> bannerUrl;
  final Value<String?> description;
  final Value<double?> score;
  final Value<String?> genres;
  final Value<String?> status;
  final Value<int?> episodeCount;
  final Value<int?> malId;
  final Value<int?> anilistId;
  final Value<DateTime> lastSynced;
  final Value<bool> isAvailable;
  const PauloFlixContentCompanion({
    this.id = const Value.absent(),
    this.folderName = const Value.absent(),
    this.displayName = const Value.absent(),
    this.serverUrl = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.bannerUrl = const Value.absent(),
    this.description = const Value.absent(),
    this.score = const Value.absent(),
    this.genres = const Value.absent(),
    this.status = const Value.absent(),
    this.episodeCount = const Value.absent(),
    this.malId = const Value.absent(),
    this.anilistId = const Value.absent(),
    this.lastSynced = const Value.absent(),
    this.isAvailable = const Value.absent(),
  });
  PauloFlixContentCompanion.insert({
    this.id = const Value.absent(),
    required String folderName,
    required String displayName,
    required String serverUrl,
    this.imageUrl = const Value.absent(),
    this.bannerUrl = const Value.absent(),
    this.description = const Value.absent(),
    this.score = const Value.absent(),
    this.genres = const Value.absent(),
    this.status = const Value.absent(),
    this.episodeCount = const Value.absent(),
    this.malId = const Value.absent(),
    this.anilistId = const Value.absent(),
    required DateTime lastSynced,
    this.isAvailable = const Value.absent(),
  }) : folderName = Value(folderName),
       displayName = Value(displayName),
       serverUrl = Value(serverUrl),
       lastSynced = Value(lastSynced);
  static Insertable<PauloFlixContentData> custom({
    Expression<int>? id,
    Expression<String>? folderName,
    Expression<String>? displayName,
    Expression<String>? serverUrl,
    Expression<String>? imageUrl,
    Expression<String>? bannerUrl,
    Expression<String>? description,
    Expression<double>? score,
    Expression<String>? genres,
    Expression<String>? status,
    Expression<int>? episodeCount,
    Expression<int>? malId,
    Expression<int>? anilistId,
    Expression<DateTime>? lastSynced,
    Expression<bool>? isAvailable,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (folderName != null) 'folder_name': folderName,
      if (displayName != null) 'display_name': displayName,
      if (serverUrl != null) 'server_url': serverUrl,
      if (imageUrl != null) 'image_url': imageUrl,
      if (bannerUrl != null) 'banner_url': bannerUrl,
      if (description != null) 'description': description,
      if (score != null) 'score': score,
      if (genres != null) 'genres': genres,
      if (status != null) 'status': status,
      if (episodeCount != null) 'episode_count': episodeCount,
      if (malId != null) 'mal_id': malId,
      if (anilistId != null) 'anilist_id': anilistId,
      if (lastSynced != null) 'last_synced': lastSynced,
      if (isAvailable != null) 'is_available': isAvailable,
    });
  }

  PauloFlixContentCompanion copyWith({
    Value<int>? id,
    Value<String>? folderName,
    Value<String>? displayName,
    Value<String>? serverUrl,
    Value<String?>? imageUrl,
    Value<String?>? bannerUrl,
    Value<String?>? description,
    Value<double?>? score,
    Value<String?>? genres,
    Value<String?>? status,
    Value<int?>? episodeCount,
    Value<int?>? malId,
    Value<int?>? anilistId,
    Value<DateTime>? lastSynced,
    Value<bool>? isAvailable,
  }) {
    return PauloFlixContentCompanion(
      id: id ?? this.id,
      folderName: folderName ?? this.folderName,
      displayName: displayName ?? this.displayName,
      serverUrl: serverUrl ?? this.serverUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      description: description ?? this.description,
      score: score ?? this.score,
      genres: genres ?? this.genres,
      status: status ?? this.status,
      episodeCount: episodeCount ?? this.episodeCount,
      malId: malId ?? this.malId,
      anilistId: anilistId ?? this.anilistId,
      lastSynced: lastSynced ?? this.lastSynced,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (folderName.present) {
      map['folder_name'] = Variable<String>(folderName.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (serverUrl.present) {
      map['server_url'] = Variable<String>(serverUrl.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (bannerUrl.present) {
      map['banner_url'] = Variable<String>(bannerUrl.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (score.present) {
      map['score'] = Variable<double>(score.value);
    }
    if (genres.present) {
      map['genres'] = Variable<String>(genres.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (episodeCount.present) {
      map['episode_count'] = Variable<int>(episodeCount.value);
    }
    if (malId.present) {
      map['mal_id'] = Variable<int>(malId.value);
    }
    if (anilistId.present) {
      map['anilist_id'] = Variable<int>(anilistId.value);
    }
    if (lastSynced.present) {
      map['last_synced'] = Variable<DateTime>(lastSynced.value);
    }
    if (isAvailable.present) {
      map['is_available'] = Variable<bool>(isAvailable.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PauloFlixContentCompanion(')
          ..write('id: $id, ')
          ..write('folderName: $folderName, ')
          ..write('displayName: $displayName, ')
          ..write('serverUrl: $serverUrl, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('bannerUrl: $bannerUrl, ')
          ..write('description: $description, ')
          ..write('score: $score, ')
          ..write('genres: $genres, ')
          ..write('status: $status, ')
          ..write('episodeCount: $episodeCount, ')
          ..write('malId: $malId, ')
          ..write('anilistId: $anilistId, ')
          ..write('lastSynced: $lastSynced, ')
          ..write('isAvailable: $isAvailable')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $WatchlistItemsTable watchlistItems = $WatchlistItemsTable(this);
  late final $DownloadsTable downloads = $DownloadsTable(this);
  late final $PauloFlixContentTable pauloFlixContent = $PauloFlixContentTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    watchlistItems,
    downloads,
    pauloFlixContent,
  ];
}

typedef $$WatchlistItemsTableCreateCompanionBuilder =
    WatchlistItemsCompanion Function({
      Value<int> id,
      required String animeId,
      required String title,
      required String coverImage,
      required String myAnimeListUrl,
      Value<DateTime> addedAt,
    });
typedef $$WatchlistItemsTableUpdateCompanionBuilder =
    WatchlistItemsCompanion Function({
      Value<int> id,
      Value<String> animeId,
      Value<String> title,
      Value<String> coverImage,
      Value<String> myAnimeListUrl,
      Value<DateTime> addedAt,
    });

class $$WatchlistItemsTableFilterComposer
    extends Composer<_$AppDatabase, $WatchlistItemsTable> {
  $$WatchlistItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get animeId => $composableBuilder(
    column: $table.animeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverImage => $composableBuilder(
    column: $table.coverImage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get myAnimeListUrl => $composableBuilder(
    column: $table.myAnimeListUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WatchlistItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $WatchlistItemsTable> {
  $$WatchlistItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get animeId => $composableBuilder(
    column: $table.animeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverImage => $composableBuilder(
    column: $table.coverImage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get myAnimeListUrl => $composableBuilder(
    column: $table.myAnimeListUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WatchlistItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WatchlistItemsTable> {
  $$WatchlistItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get animeId =>
      $composableBuilder(column: $table.animeId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get coverImage => $composableBuilder(
    column: $table.coverImage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get myAnimeListUrl => $composableBuilder(
    column: $table.myAnimeListUrl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$WatchlistItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WatchlistItemsTable,
          WatchlistItem,
          $$WatchlistItemsTableFilterComposer,
          $$WatchlistItemsTableOrderingComposer,
          $$WatchlistItemsTableAnnotationComposer,
          $$WatchlistItemsTableCreateCompanionBuilder,
          $$WatchlistItemsTableUpdateCompanionBuilder,
          (
            WatchlistItem,
            BaseReferences<_$AppDatabase, $WatchlistItemsTable, WatchlistItem>,
          ),
          WatchlistItem,
          PrefetchHooks Function()
        > {
  $$WatchlistItemsTableTableManager(
    _$AppDatabase db,
    $WatchlistItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchlistItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchlistItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchlistItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> animeId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> coverImage = const Value.absent(),
                Value<String> myAnimeListUrl = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
              }) => WatchlistItemsCompanion(
                id: id,
                animeId: animeId,
                title: title,
                coverImage: coverImage,
                myAnimeListUrl: myAnimeListUrl,
                addedAt: addedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String animeId,
                required String title,
                required String coverImage,
                required String myAnimeListUrl,
                Value<DateTime> addedAt = const Value.absent(),
              }) => WatchlistItemsCompanion.insert(
                id: id,
                animeId: animeId,
                title: title,
                coverImage: coverImage,
                myAnimeListUrl: myAnimeListUrl,
                addedAt: addedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WatchlistItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WatchlistItemsTable,
      WatchlistItem,
      $$WatchlistItemsTableFilterComposer,
      $$WatchlistItemsTableOrderingComposer,
      $$WatchlistItemsTableAnnotationComposer,
      $$WatchlistItemsTableCreateCompanionBuilder,
      $$WatchlistItemsTableUpdateCompanionBuilder,
      (
        WatchlistItem,
        BaseReferences<_$AppDatabase, $WatchlistItemsTable, WatchlistItem>,
      ),
      WatchlistItem,
      PrefetchHooks Function()
    >;
typedef $$DownloadsTableCreateCompanionBuilder =
    DownloadsCompanion Function({
      Value<int> id,
      required String downloadId,
      required String animeId,
      required String animeName,
      required String episodeNumber,
      required String episodeTitle,
      required String videoUrl,
      required String thumbnailUrl,
      Value<int> quality,
      Value<int> status,
      Value<double> progress,
      Value<int> bytesDownloaded,
      Value<int> totalBytes,
      Value<String?> filePath,
      Value<String?> error,
      Value<DateTime> createdAt,
      Value<DateTime?> completedAt,
    });
typedef $$DownloadsTableUpdateCompanionBuilder =
    DownloadsCompanion Function({
      Value<int> id,
      Value<String> downloadId,
      Value<String> animeId,
      Value<String> animeName,
      Value<String> episodeNumber,
      Value<String> episodeTitle,
      Value<String> videoUrl,
      Value<String> thumbnailUrl,
      Value<int> quality,
      Value<int> status,
      Value<double> progress,
      Value<int> bytesDownloaded,
      Value<int> totalBytes,
      Value<String?> filePath,
      Value<String?> error,
      Value<DateTime> createdAt,
      Value<DateTime?> completedAt,
    });

class $$DownloadsTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get downloadId => $composableBuilder(
    column: $table.downloadId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get animeId => $composableBuilder(
    column: $table.animeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get animeName => $composableBuilder(
    column: $table.animeName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodeTitle => $composableBuilder(
    column: $table.episodeTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoUrl => $composableBuilder(
    column: $table.videoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytesDownloaded => $composableBuilder(
    column: $table.bytesDownloaded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadsTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get downloadId => $composableBuilder(
    column: $table.downloadId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get animeId => $composableBuilder(
    column: $table.animeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get animeName => $composableBuilder(
    column: $table.animeName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodeTitle => $composableBuilder(
    column: $table.episodeTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoUrl => $composableBuilder(
    column: $table.videoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytesDownloaded => $composableBuilder(
    column: $table.bytesDownloaded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get downloadId => $composableBuilder(
    column: $table.downloadId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get animeId =>
      $composableBuilder(column: $table.animeId, builder: (column) => column);

  GeneratedColumn<String> get animeName =>
      $composableBuilder(column: $table.animeName, builder: (column) => column);

  GeneratedColumn<String> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get episodeTitle => $composableBuilder(
    column: $table.episodeTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get videoUrl =>
      $composableBuilder(column: $table.videoUrl, builder: (column) => column);

  GeneratedColumn<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => column,
  );

  GeneratedColumn<int> get quality =>
      $composableBuilder(column: $table.quality, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<int> get bytesDownloaded => $composableBuilder(
    column: $table.bytesDownloaded,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$DownloadsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadsTable,
          Download,
          $$DownloadsTableFilterComposer,
          $$DownloadsTableOrderingComposer,
          $$DownloadsTableAnnotationComposer,
          $$DownloadsTableCreateCompanionBuilder,
          $$DownloadsTableUpdateCompanionBuilder,
          (Download, BaseReferences<_$AppDatabase, $DownloadsTable, Download>),
          Download,
          PrefetchHooks Function()
        > {
  $$DownloadsTableTableManager(_$AppDatabase db, $DownloadsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> downloadId = const Value.absent(),
                Value<String> animeId = const Value.absent(),
                Value<String> animeName = const Value.absent(),
                Value<String> episodeNumber = const Value.absent(),
                Value<String> episodeTitle = const Value.absent(),
                Value<String> videoUrl = const Value.absent(),
                Value<String> thumbnailUrl = const Value.absent(),
                Value<int> quality = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<int> bytesDownloaded = const Value.absent(),
                Value<int> totalBytes = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
              }) => DownloadsCompanion(
                id: id,
                downloadId: downloadId,
                animeId: animeId,
                animeName: animeName,
                episodeNumber: episodeNumber,
                episodeTitle: episodeTitle,
                videoUrl: videoUrl,
                thumbnailUrl: thumbnailUrl,
                quality: quality,
                status: status,
                progress: progress,
                bytesDownloaded: bytesDownloaded,
                totalBytes: totalBytes,
                filePath: filePath,
                error: error,
                createdAt: createdAt,
                completedAt: completedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String downloadId,
                required String animeId,
                required String animeName,
                required String episodeNumber,
                required String episodeTitle,
                required String videoUrl,
                required String thumbnailUrl,
                Value<int> quality = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<int> bytesDownloaded = const Value.absent(),
                Value<int> totalBytes = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
              }) => DownloadsCompanion.insert(
                id: id,
                downloadId: downloadId,
                animeId: animeId,
                animeName: animeName,
                episodeNumber: episodeNumber,
                episodeTitle: episodeTitle,
                videoUrl: videoUrl,
                thumbnailUrl: thumbnailUrl,
                quality: quality,
                status: status,
                progress: progress,
                bytesDownloaded: bytesDownloaded,
                totalBytes: totalBytes,
                filePath: filePath,
                error: error,
                createdAt: createdAt,
                completedAt: completedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadsTable,
      Download,
      $$DownloadsTableFilterComposer,
      $$DownloadsTableOrderingComposer,
      $$DownloadsTableAnnotationComposer,
      $$DownloadsTableCreateCompanionBuilder,
      $$DownloadsTableUpdateCompanionBuilder,
      (Download, BaseReferences<_$AppDatabase, $DownloadsTable, Download>),
      Download,
      PrefetchHooks Function()
    >;
typedef $$PauloFlixContentTableCreateCompanionBuilder =
    PauloFlixContentCompanion Function({
      Value<int> id,
      required String folderName,
      required String displayName,
      required String serverUrl,
      Value<String?> imageUrl,
      Value<String?> bannerUrl,
      Value<String?> description,
      Value<double?> score,
      Value<String?> genres,
      Value<String?> status,
      Value<int?> episodeCount,
      Value<int?> malId,
      Value<int?> anilistId,
      required DateTime lastSynced,
      Value<bool> isAvailable,
    });
typedef $$PauloFlixContentTableUpdateCompanionBuilder =
    PauloFlixContentCompanion Function({
      Value<int> id,
      Value<String> folderName,
      Value<String> displayName,
      Value<String> serverUrl,
      Value<String?> imageUrl,
      Value<String?> bannerUrl,
      Value<String?> description,
      Value<double?> score,
      Value<String?> genres,
      Value<String?> status,
      Value<int?> episodeCount,
      Value<int?> malId,
      Value<int?> anilistId,
      Value<DateTime> lastSynced,
      Value<bool> isAvailable,
    });

class $$PauloFlixContentTableFilterComposer
    extends Composer<_$AppDatabase, $PauloFlixContentTable> {
  $$PauloFlixContentTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderName => $composableBuilder(
    column: $table.folderName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverUrl => $composableBuilder(
    column: $table.serverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bannerUrl => $composableBuilder(
    column: $table.bannerUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genres => $composableBuilder(
    column: $table.genres,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episodeCount => $composableBuilder(
    column: $table.episodeCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get malId => $composableBuilder(
    column: $table.malId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get anilistId => $composableBuilder(
    column: $table.anilistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSynced => $composableBuilder(
    column: $table.lastSynced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAvailable => $composableBuilder(
    column: $table.isAvailable,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PauloFlixContentTableOrderingComposer
    extends Composer<_$AppDatabase, $PauloFlixContentTable> {
  $$PauloFlixContentTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderName => $composableBuilder(
    column: $table.folderName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverUrl => $composableBuilder(
    column: $table.serverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bannerUrl => $composableBuilder(
    column: $table.bannerUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genres => $composableBuilder(
    column: $table.genres,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episodeCount => $composableBuilder(
    column: $table.episodeCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get malId => $composableBuilder(
    column: $table.malId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get anilistId => $composableBuilder(
    column: $table.anilistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSynced => $composableBuilder(
    column: $table.lastSynced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAvailable => $composableBuilder(
    column: $table.isAvailable,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PauloFlixContentTableAnnotationComposer
    extends Composer<_$AppDatabase, $PauloFlixContentTable> {
  $$PauloFlixContentTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get folderName => $composableBuilder(
    column: $table.folderName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverUrl =>
      $composableBuilder(column: $table.serverUrl, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get bannerUrl =>
      $composableBuilder(column: $table.bannerUrl, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<String> get genres =>
      $composableBuilder(column: $table.genres, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get episodeCount => $composableBuilder(
    column: $table.episodeCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get malId =>
      $composableBuilder(column: $table.malId, builder: (column) => column);

  GeneratedColumn<int> get anilistId =>
      $composableBuilder(column: $table.anilistId, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSynced => $composableBuilder(
    column: $table.lastSynced,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isAvailable => $composableBuilder(
    column: $table.isAvailable,
    builder: (column) => column,
  );
}

class $$PauloFlixContentTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PauloFlixContentTable,
          PauloFlixContentData,
          $$PauloFlixContentTableFilterComposer,
          $$PauloFlixContentTableOrderingComposer,
          $$PauloFlixContentTableAnnotationComposer,
          $$PauloFlixContentTableCreateCompanionBuilder,
          $$PauloFlixContentTableUpdateCompanionBuilder,
          (
            PauloFlixContentData,
            BaseReferences<
              _$AppDatabase,
              $PauloFlixContentTable,
              PauloFlixContentData
            >,
          ),
          PauloFlixContentData,
          PrefetchHooks Function()
        > {
  $$PauloFlixContentTableTableManager(
    _$AppDatabase db,
    $PauloFlixContentTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PauloFlixContentTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PauloFlixContentTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PauloFlixContentTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> folderName = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> serverUrl = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> bannerUrl = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<double?> score = const Value.absent(),
                Value<String?> genres = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<int?> episodeCount = const Value.absent(),
                Value<int?> malId = const Value.absent(),
                Value<int?> anilistId = const Value.absent(),
                Value<DateTime> lastSynced = const Value.absent(),
                Value<bool> isAvailable = const Value.absent(),
              }) => PauloFlixContentCompanion(
                id: id,
                folderName: folderName,
                displayName: displayName,
                serverUrl: serverUrl,
                imageUrl: imageUrl,
                bannerUrl: bannerUrl,
                description: description,
                score: score,
                genres: genres,
                status: status,
                episodeCount: episodeCount,
                malId: malId,
                anilistId: anilistId,
                lastSynced: lastSynced,
                isAvailable: isAvailable,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String folderName,
                required String displayName,
                required String serverUrl,
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> bannerUrl = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<double?> score = const Value.absent(),
                Value<String?> genres = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<int?> episodeCount = const Value.absent(),
                Value<int?> malId = const Value.absent(),
                Value<int?> anilistId = const Value.absent(),
                required DateTime lastSynced,
                Value<bool> isAvailable = const Value.absent(),
              }) => PauloFlixContentCompanion.insert(
                id: id,
                folderName: folderName,
                displayName: displayName,
                serverUrl: serverUrl,
                imageUrl: imageUrl,
                bannerUrl: bannerUrl,
                description: description,
                score: score,
                genres: genres,
                status: status,
                episodeCount: episodeCount,
                malId: malId,
                anilistId: anilistId,
                lastSynced: lastSynced,
                isAvailable: isAvailable,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PauloFlixContentTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PauloFlixContentTable,
      PauloFlixContentData,
      $$PauloFlixContentTableFilterComposer,
      $$PauloFlixContentTableOrderingComposer,
      $$PauloFlixContentTableAnnotationComposer,
      $$PauloFlixContentTableCreateCompanionBuilder,
      $$PauloFlixContentTableUpdateCompanionBuilder,
      (
        PauloFlixContentData,
        BaseReferences<
          _$AppDatabase,
          $PauloFlixContentTable,
          PauloFlixContentData
        >,
      ),
      PauloFlixContentData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$WatchlistItemsTableTableManager get watchlistItems =>
      $$WatchlistItemsTableTableManager(_db, _db.watchlistItems);
  $$DownloadsTableTableManager get downloads =>
      $$DownloadsTableTableManager(_db, _db.downloads);
  $$PauloFlixContentTableTableManager get pauloFlixContent =>
      $$PauloFlixContentTableTableManager(_db, _db.pauloFlixContent);
}
