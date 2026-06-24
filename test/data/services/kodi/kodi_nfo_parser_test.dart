// Testes do `KodiNfoParser` (Fase 1 do plano NFO enrichment).
//
// Estratégia TDD red → impl → green. Estes testes são escritos ANTES
// da implementação e devem FALHAR (RED) até que o parser seja criado.
//
// Cobre:
//   - `KodiNfoParser.parseShow` (root `<tvshow>`): 6 casos.
//   - `KodiNfoParser.parseMovie` (root `<movie>`): 4 casos.
//   - `KodiNfoParser.parseEpisode` (root `<episodedetails>`): 4 casos.
// Total: 14 casos.
//
// Ver plano `.hermes/plans/2026-06-23_224213-pauloflix-nfo-enrichment.md`.

import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/data/services/kodi/kodi_nfo_parser.dart';

void main() {
  // ============================================================
  // KodiNfoParser.parseShow (root <tvshow>)
  // ============================================================
  group('KodiNfoParser.parseShow', () {
    test('parses valid complete tvshow.nfo with all fields populated', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<tvshow>
  <title>Mushoku Tensei</title>
  <plot>Um homem... reencarna em outro mundo.</plot>
  <genre>Action</genre>
  <genre>Adventure</genre>
  <genre>Fantasy</genre>
  <year>2021</year>
  <rating>8.4</rating>
  <thumb aspect="poster">poster.jpg</thumb>
  <thumb aspect="banner">banner.jpg</thumb>
  <thumb aspect="fanart">fanart.jpg</thumb>
</tvshow>''';

      final result = KodiNfoParser.parseShow(xml);

      expect(result, isNotNull);
      expect(result!.title, 'Mushoku Tensei');
      expect(result.plot, 'Um homem... reencarna em outro mundo.');
      expect(result.genres, ['Action', 'Adventure', 'Fantasy']);
      expect(result.year, 2021);
      expect(result.rating, 8.4);
      expect(result.posterThumb, 'poster.jpg');
      expect(result.bannerThumb, 'banner.jpg');
      expect(result.fanartThumb, 'fanart.jpg');
    });

    test('returns null on invalid XML', () {
      const xml = 'this is not valid xml at all <<<>>>';

      final result = KodiNfoParser.parseShow(xml);

      expect(result, isNull);
    });

    test('returns KodiShowNfo with nulls when only title is present', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<tvshow>
  <title>Minimal Show</title>
</tvshow>''';

      final result = KodiNfoParser.parseShow(xml);

      expect(result, isNotNull);
      expect(result!.title, 'Minimal Show');
      expect(result.plot, isNull);
      expect(result.genres, isEmpty);
      expect(result.year, isNull);
      expect(result.rating, isNull);
      expect(result.posterThumb, isNull);
      expect(result.bannerThumb, isNull);
      expect(result.fanartThumb, isNull);
    });

    test('handles multiple <thumb> with different aspects correctly', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<tvshow>
  <title>Test</title>
  <thumb aspect="banner">b1.jpg</thumb>
  <thumb aspect="poster">p1.jpg</thumb>
  <thumb aspect="fanart">f1.jpg</thumb>
  <thumb aspect="poster">p2.jpg</thumb>
</tvshow>''';

      final result = KodiNfoParser.parseShow(xml);

      expect(result, isNotNull);
      // Pega o primeiro thumb de cada aspect.
      expect(result!.posterThumb, 'p1.jpg');
      expect(result.bannerThumb, 'b1.jpg');
      expect(result.fanartThumb, 'f1.jpg');
    });

    test('preserves multiline plot with CDATA', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<tvshow>
  <title>Test</title>
  <plot><![CDATA[Line 1
Line 2
Line 3]]></plot>
</tvshow>''';

      final result = KodiNfoParser.parseShow(xml);

      expect(result, isNotNull);
      expect(result!.plot, contains('Line 1'));
      expect(result.plot, contains('Line 2'));
      expect(result.plot, contains('Line 3'));
      // Verifica que quebras de linha foram preservadas.
      expect(result.plot!.contains('\n'), isTrue);
    });

    test('handles non-numeric year gracefully (year="unknown" -> null)', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<tvshow>
  <title>Test</title>
  <year>unknown</year>
  <rating>N/A</rating>
</tvshow>''';

      final result = KodiNfoParser.parseShow(xml);

      expect(result, isNotNull);
      expect(result!.year, isNull);
      expect(result.rating, isNull);
    });
  });

  // ============================================================
  // KodiNfoParser.parseMovie (root <movie>)
  // ============================================================
  group('KodiNfoParser.parseMovie', () {
    test('parses valid complete movie.nfo with all fields populated', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<movie>
  <title>The Matrix</title>
  <plot>A computer hacker learns about the true nature of reality.</plot>
  <genre>Action</genre>
  <genre>Sci-Fi</genre>
  <year>1999</year>
  <rating>8.7</rating>
  <thumb aspect="poster">poster.jpg</thumb>
  <thumb aspect="fanart">fanart.jpg</thumb>
</movie>''';

      final result = KodiNfoParser.parseMovie(xml);

      expect(result, isNotNull);
      expect(result!.title, 'The Matrix');
      expect(result.plot, contains('computer hacker'));
      expect(result.genres, ['Action', 'Sci-Fi']);
      expect(result.year, 1999);
      expect(result.rating, 8.7);
      expect(result.posterThumb, 'poster.jpg');
      expect(result.fanartThumb, 'fanart.jpg');
    });

    test('returns KodiShowNfo with nulls when only title is present', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<movie>
  <title>Minimal Movie</title>
</movie>''';

      final result = KodiNfoParser.parseMovie(xml);

      expect(result, isNotNull);
      expect(result!.title, 'Minimal Movie');
      expect(result.plot, isNull);
      expect(result.genres, isEmpty);
      expect(result.year, isNull);
    });

    test('returns null on invalid XML', () {
      const xml = '<<<not xml>>>';

      final result = KodiNfoParser.parseMovie(xml);

      expect(result, isNull);
    });

    test('returns null when root is <tvshow> (root mismatch)', () {
      // Movies parser deve rejeitar tvshow root.
      const xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<tvshow>
  <title>Wrong root for movie</title>
</tvshow>''';

      final result = KodiNfoParser.parseMovie(xml);

      expect(result, isNull);
    });
  });

  // ============================================================
  // KodiNfoParser.parseEpisode (root <episodedetails>)
  // ============================================================
  group('KodiNfoParser.parseEpisode', () {
    test('parses valid complete episodedetails.nfo', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<episodedetails>
  <season>1</season>
  <episode>5</episode>
  <title>The First Mission</title>
  <plot>The team embarks on their first mission together.</plot>
  <thumb>episode5.jpg</thumb>
</episodedetails>''';

      final result = KodiNfoParser.parseEpisode(xml);

      expect(result, isNotNull);
      expect(result!.season, 1);
      expect(result.episode, 5);
      expect(result.title, 'The First Mission');
      expect(result.plot, contains('first mission'));
    });

    test('returns null on invalid XML', () {
      const xml = '<<<not xml>>>';

      final result = KodiNfoParser.parseEpisode(xml);

      expect(result, isNull);
    });

    test('parses season=1, episode=5 with title and plot', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<episodedetails>
  <season>1</season>
  <episode>5</episode>
  <title>Episode 5 Title</title>
  <plot>Plot for episode 5.</plot>
</episodedetails>''';

      final result = KodiNfoParser.parseEpisode(xml);

      expect(result, isNotNull);
      expect(result!.season, 1);
      expect(result.episode, 5);
      expect(result.title, 'Episode 5 Title');
      expect(result.plot, 'Plot for episode 5.');
    });

    test('returns null fields when season/episode are absent', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<episodedetails>
  <title>Untitled</title>
</episodedetails>''';

      final result = KodiNfoParser.parseEpisode(xml);

      expect(result, isNotNull);
      expect(result!.season, isNull);
      expect(result.episode, isNull);
      expect(result.title, 'Untitled');
      expect(result.plot, isNull);
    });
  });

  // ============================================================
  // Cobertura extra (Task 1.4)
  // ============================================================
  group('KodiNfoParser - extra coverage', () {
    test('<thumb> without aspect returns null (no posterThumb)', () {
      // Decisão documentada: <thumb> sem aspect não é mapeado para
      // nenhum dos campos de aspect. Só é usado em `KodiEpisodeNfo`
      // ou `KodiSeasonNfo` (escopo futuro).
      const xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<tvshow>
  <title>No aspect thumbs</title>
  <thumb>plain.jpg</thumb>
</tvshow>''';

      final result = KodiNfoParser.parseShow(xml);

      expect(result, isNotNull);
      expect(result!.posterThumb, isNull);
      expect(result.bannerThumb, isNull);
      expect(result.fanartThumb, isNull);
    });

    test('parseMovie with <tvshow> root returns null (root mismatch)', () {
      // Re-garante que o root mismatch do movie parser continua
      // funcionando (Task 1.4 explicita este caso).
      const xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<tvshow>
  <title>Should be a movie</title>
</tvshow>''';

      final result = KodiNfoParser.parseMovie(xml);

      expect(result, isNull);
    });

    test('parseEpisode with season=1, episode=5 returns the correct tuple', () {
      // Re-garante Task 1.4: tuple (1, 5, title, plot).
      const xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<episodedetails>
  <season>1</season>
  <episode>5</episode>
  <title>First Steps</title>
  <plot>The hero takes their first steps.</plot>
</episodedetails>''';

      final result = KodiNfoParser.parseEpisode(xml);

      expect(result, isNotNull);
      expect(result!.season, 1);
      expect(result.episode, 5);
      expect(result.title, 'First Steps');
      expect(result.plot, 'The hero takes their first steps.');
    });

    test('parseEpisode with season/episode absent returns null fields', () {
      // Re-garante Task 1.4: campos season/episode ausentes → null.
      const xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<episodedetails>
  <plot>Just a plot, no season or episode numbers.</plot>
</episodedetails>''';

      final result = KodiNfoParser.parseEpisode(xml);

      expect(result, isNotNull);
      expect(result!.season, isNull);
      expect(result.episode, isNull);
      expect(result.title, isNull);
      expect(result.plot, contains('no season or episode'));
    });
  });
}
