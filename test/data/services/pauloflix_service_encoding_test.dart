// Testes de Fase 8 do plano NFO Enrichment V2 — encoding fixes.
//
// Cobre:
//   - `safeDecodeComponent` do `lib/core/utils/url_codec.dart` (6 casos).
//   - `detectHtmlCharset` do `lib/core/utils/url_codec.dart` (5 casos).
// Total: 11 casos.
//
// Ver plano `.hermes/plans/2026-06-23_225500-pauloflix-nfo-enrichment-v2.md`.

import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/core/utils/url_codec.dart';

void main() {
  // ============================================================
  // safeDecodeComponent
  // ============================================================
  group('safeDecodeComponent', () {
    test('decodes single %XX sequence once (é → %C3%A9)', () {
      // %C3%A9 é UTF-8 para "é" (U+00E9). A função deve decodificar
      // uma única vez, não duas (Uri.decodeComponent direto faria
      // a mesma coisa, mas verificamos o happy path).
      expect(safeDecodeComponent('S%C3%A9rie'), 'Série');
    });

    test('decodes multiple %XX sequences (éé → %C3%A9%C3%A9)', () {
      expect(
        safeDecodeComponent('S%C3%A9rie%20Brasileira%C3%A9'),
        'Série Brasileiraé',
      );
    });

    test('decodes space (%20) → " "', () {
      expect(safeDecodeComponent('Naruto%20Shippuuden'), 'Naruto Shippuuden');
    });

    test('preserves invalid %XY literal (does not throw)', () {
      // %XY não é hex válido. Uri.decodeComponent lança ArgumentError.
      // safeDecodeComponent deve cair no fallback e manter %XY literal.
      expect(safeDecodeComponent('100% completo'), '100% completo');
    });

    test(
      'preserves partial invalid: % followed by non-hex (just a % char)',
      () {
        // %G1 não é hex — deve virar "G1" e o % ser mantido.
        expect(safeDecodeComponent('100%G1resto'), '100%G1resto');
      },
    );

    test('returns empty string unchanged (early return)', () {
      expect(safeDecodeComponent(''), '');
    });

    test('returns plain string without % unchanged (no modification)', () {
      expect(safeDecodeComponent('S01E01'), 'S01E01');
    });

    test('mixes valid + invalid %: decodes only the valid ones', () {
      // %20 (espaço) e %XY (inválido) juntos. Deve decodificar %20
      // e manter %XY.
      expect(
        safeDecodeComponent('100%XY %20resto'),
        '100%XY  resto', // 2 espaços: 1 literal antes + 1 decoded de %20
      );
    });
  });

  // ============================================================
  // detectHtmlCharset
  // ============================================================
  group('detectHtmlCharset', () {
    test('detects <meta charset="utf-8">', () {
      const html =
          '<!DOCTYPE html><html><head><meta charset="utf-8"></head></html>';
      expect(detectHtmlCharset(html), 'utf-8');
    });

    test('detects <meta charset="UTF-8"> (case-insensitive)', () {
      const html =
          '<!DOCTYPE html><html><head><meta charset="UTF-8"></head></html>';
      expect(detectHtmlCharset(html), 'UTF-8');
    });

    test('detects <meta charset="ISO-8859-1"> (Latin-1)', () {
      const html =
          '<!DOCTYPE html><html><head><meta charset="ISO-8859-1">'
          '</head></html>';
      expect(detectHtmlCharset(html), 'ISO-8859-1');
    });

    test(
      'detects <meta http-equiv="Content-Type" content="...charset=ISO-8859-1">',
      () {
        const html =
            '<!DOCTYPE html><html><head>'
            '<meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-1">'
            '</head></html>';
        expect(detectHtmlCharset(html), 'ISO-8859-1');
      },
    );

    test('falls back to Content-Type header when no <meta> charset', () {
      // HTML sem <meta charset> (raro, mas o body pode estar vazio).
      const html = '<html><body>x</body></html>';
      final headers = <String, String>{
        'content-type': 'text/html; charset=ISO-8859-1',
      };
      expect(detectHtmlCharset(html, responseHeaders: headers), 'ISO-8859-1');
    });

    test('returns null when no charset is declared anywhere', () {
      const html = '<html><body>x</body></html>';
      expect(detectHtmlCharset(html), isNull);
    });

    test(
      'prefers <meta charset> over Content-Type header (header ignored)',
      () {
        const html =
            '<!DOCTYPE html><html><head><meta charset="utf-8"></head></html>';
        final headers = <String, String>{
          'content-type': 'text/html; charset=ISO-8859-1',
        };
        // A spec manda: meta tag > HTTP header.
        expect(detectHtmlCharset(html, responseHeaders: headers), 'utf-8');
      },
    );
  });
}
