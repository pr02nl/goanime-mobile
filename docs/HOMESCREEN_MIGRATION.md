# Guia de Migração do HomeScreen para Netflix Style

## 📋 O Que Precisa Ser Feito

Substituir as chamadas de `_buildModernSection` por `_buildNetflixSection` (ou `AnimeSection` com `useNetflixStyle: true`) no arquivo `lib/screens/home_screen.dart`.

## 🔧 Passo 1: Adicionar o Novo Método

Adicione este método após o `_buildModernSection` (aproximadamente linha 551):

```dart
// NOVO: Método para criar seções com Netflix style
Widget _buildNetflixSection({
  required String title,
  required List<JikanAnime> animes,
  required bool isLoading,
  int? genreId,
}) {
  return AnimatedOpacity(
    opacity: isLoading ? 0.6 : 1.0,
    duration: const Duration(milliseconds: 300),
    child: AnimeSection(
      title: title,
      animes: animes,
      isLoading: isLoading,
      useNetflixStyle: true,
      onSeeAll: genreId != null
          ? () {
              final l10n = AppLocalizations.of(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GenreAnimesScreen(
                    title: title,
                    icon: Icons.movie,
                    gradient: AppColors.getPrimaryGradient(),
                    genreId: genreId,
                  ),
                ),
              );
            }
          : null,
      onAnimeTap: _onAnimeTap,
    ),
  );
}
```

## 🔧 Passo 2: Substituir as Chamadas no Método build

Encontre o método `build` (aproximadamente linha 193) e substitua as chamadas de `_buildModernSection` por `_buildNetflixSection`:

### ANTES:
```dart
// Seção: Destaques da Temporada
_buildModernSection(
  title: l10n.seasonHighlights,
  icon: Icons.trending_up_outlined,
  gradient: LinearGradient(
    colors: [AppColors.primary, AppColors.secondary],
  ),
  animes: _seasonAnimes,
  isLoading: _isLoading && _seasonAnimes.isEmpty,
  sectionId: 'season',
  genreId: null,
),

// Seção: Top Animes
_buildModernSection(
  title: l10n.topAnime,
  icon: Icons.emoji_events,
  gradient: const LinearGradient(
    colors: [Color(0xFFFFD93D), Color(0xFFFFA500)],
  ),
  animes: _topAnimes,
  isLoading: _isLoading && _topAnimes.isEmpty,
  sectionId: 'top',
  genreId: null,
),

// Seção: Ação
_buildModernSection(
  title: l10n.action,
  icon: Icons.hardware,
  gradient: const LinearGradient(
    colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
  ),
  animes: _actionAnimes,
  isLoading: _isLoading && _actionAnimes.isEmpty,
  sectionId: 'action',
  genreId: JikanGenreIds.action,
),

// Seção: Romance
_buildModernSection(
  title: l10n.romance,
  icon: Icons.favorite,
  gradient: const LinearGradient(
    colors: [Color(0xFFFF6B9D), Color(0xFFC44569)],
  ),
  animes: _romanceAnimes,
  isLoading: _isLoading && _romanceAnimes.isEmpty,
  sectionId: 'romance',
  genreId: JikanGenreIds.romance,
),

// Seção: Comédia
_buildModernSection(
  title: l10n.comedy,
  icon: Icons.sentiment_very_satisfied,
  gradient: const LinearGradient(
    colors: [Color(0xFF00D2FF), Color(0xFF3A7BD5)],
  ),
  animes: _comedyAnimes,
  isLoading: _isLoading && _comedyAnimes.isEmpty,
  sectionId: 'comedy',
  genreId: JikanGenreIds.comedy,
),

// Seção: Fantasia
_buildModernSection(
  title: l10n.fantasy,
  icon: Icons.auto_fix_high,
  gradient: const LinearGradient(
    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
  ),
  animes: _fantasyAnimes,
  isLoading: _isLoading && _fantasyAnimes.isEmpty,
  sectionId: 'fantasy',
  genreId: JikanGenreIds.fantasy,
),
```

### DEPOIS:
```dart
// Seção: Destaques da Temporada (Netflix Style)
_buildNetflixSection(
  title: l10n.seasonHighlights,
  animes: _seasonAnimes,
  isLoading: _isLoading && _seasonAnimes.isEmpty,
  genreId: null,
),

// Seção: Top Animes (Netflix Style)
_buildNetflixSection(
  title: l10n.topAnime,
  animes: _topAnimes,
  isLoading: _isLoading && _topAnimes.isEmpty,
  genreId: null,
),

// Seção: Ação (Netflix Style)
_buildNetflixSection(
  title: l10n.action,
  animes: _actionAnimes,
  isLoading: _isLoading && _actionAnimes.isEmpty,
  genreId: JikanGenreIds.action,
),

// Seção: Romance (Netflix Style)
_buildNetflixSection(
  title: l10n.romance,
  animes: _romanceAnimes,
  isLoading: _isLoading && _romanceAnimes.isEmpty,
  genreId: JikanGenreIds.romance,
),

// Seção: Comédia (Netflix Style)
_buildNetflixSection(
  title: l10n.comedy,
  animes: _comedyAnimes,
  isLoading: _isLoading && _comedyAnimes.isEmpty,
  genreId: JikanGenreIds.comedy,
),

// Seção: Fantasia (Netflix Style)
_buildNetflixSection(
  title: l10n.fantasy,
  animes: _fantasyAnimes,
  isLoading: _isLoading && _fantasyAnimes.isEmpty,
  genreId: JikanGenreIds.fantasy,
),
```

## 🔧 Passo 3: Testar

Após fazer as alterações:

```bash
flutter analyze
flutter run
```

## 🎨 O Que Você Verá

Após a migração, as seções do HomeScreen terão:

- ✅ Hover effects com scale animation
- ✅ Gradient overlays nos cards
- ✅ Scroll suave com gradient fades
- ✅ Navigation buttons em desktop
- ✅ Layout responsivo automático
- ✅ Shadow dinâmica no hover
- ✅ Animações suaves (300ms)

## 🔄 Alternativa: Migração Gradual

Se você quiser testar apenas algumas seções primeiro, substitua apenas uma ou duas chamadas:

```dart
// Testar apenas a primeira seção
_buildNetflixSection(
  title: l10n.seasonHighlights,
  animes: _seasonAnimes,
  isLoading: _isLoading && _seasonAnimes.isEmpty,
  genreId: null,
),

// Manter as outras como estão
_buildModernSection(
  title: l10n.topAnime,
  // ... resto do código
),
```

## 📝 Notas

- O método `_buildModernSection` original pode ser removido após a migração completa
- A migração é reversível - você pode voltar para `_buildModernSection` a qualquer momento
- Todos os parâmetros de `genreId` são mantidos para funcionalidade "Ver Todos"
- A funcionalidade `_onAnimeTap` é preservada

## ✅ Validação

Após a migração, verifique:

- [ ] Seções aparecem corretamente
- [ ] Hover effects funcionam (desktop)
- [ ] Scroll é suave
- [ ] Cards responsivos em diferentes tamanhos
- [ ] "Ver Todos" ainda funciona para gêneros
- [ ] Loading states funcionam corretamente
- [ ] Sem erros no console