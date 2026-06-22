/// Resultado genérico de paginação por letra.
///
/// Usado por grids paginados com índice A–Z lateral (e.g.
/// `PauloFlixProvider.paginateByLetter`). Genérico sobre [T] para
/// acomodar diferentes tipos de conteúdo (`PauloFlixMovie`,
/// `PauloFlixContent`, etc.).
///
/// ## Estrutura
/// * [pages]: lista de páginas (cada uma com até `perPage` items).
/// * [letterToPageIndex]: mapa `letra → índice da primeira página com
///   essa letra`. Usado pelo `LetterIndex` para `scrollToLetter('A')`.
/// * [availableLetters]: letras (A–Z + "#") que têm ≥1 item, em ordem
///   alfabética ("#" sempre no fim). Letras não-presentes são omitidas
///   (não clicáveis).
///
/// Filmes com `displayName` iniciando com número/símbolo caem em "#".
/// Ordenação é case-insensitive.
class PaginationResult<T> {
  /// Páginas de items (cada uma com até `perPage` items).
  final List<List<T>> pages;

  /// Mapa `letra → índice da primeira página com essa letra`.
  final Map<String, int> letterToPageIndex;

  /// Letras que têm ≥1 item, em ordem alfabética (A–Z + "#" no fim).
  final List<String> availableLetters;

  const PaginationResult({
    required this.pages,
    required this.letterToPageIndex,
    required this.availableLetters,
  });
}
