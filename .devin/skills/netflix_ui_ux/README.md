# Netflix UI/UX Skill para PauloFlix

Skill especializada em criar interfaces Flutter responsivas inspiradas no Netflix, focada em design premium, animações suaves e experiência de usuário imersiva.

## 📋 Conteúdo

- **SKILL.md** - Documentação completa da skill com padrões de design
- **netflix_theme.dart** - Tema Netflix-inspired com cores e estilos
- **netflix_card.dart** - Cards com hover effects e animações
- **netflix_carousel.dart** - Carousels horizontais responsivos
- **INTEGRATION_EXAMPLE.md** - Exemplos de integração no projeto
- **README.md** - Este arquivo

## 🎨 Características

### Design Visual
- ✅ Tema escuro premium (preto puro #000000)
- ✅ Cores de accent vibrantes (vermelho, ciano, roxo)
- ✅ Cards imersivos com hover effects
- ✅ Gradientes suaves para melhor legibilidade
- ✅ Tipografia limpa e hierarquia visual clara

### Responsividade
- ✅ Mobile (< 600px) - Layout compacto
- ✅ Tablet (600px - 1200px) - Grid adaptativo
- ✅ TV (> 1200px) - Navegação por D-pad
- ✅ Web - Layout fluido com breakpoints

### Animações
- ✅ Hero carousel com parallax
- ✅ Scale animation no hover/tap
- ✅ Page transitions suaves
- ✅ Shimmer loading effects
- ✅ Curvas de animação estilo Netflix

## 🚀 Como Usar

### 1. Ativar a Skill

```bash
# A skill será automaticamente ativada quando você pedir
# "criar uma interface Netflix-inspired" ou similar
```

### 2. Integrar no Projeto

Copie os arquivos da skill para o projeto:

```bash
# Tema
cp .devin/skills/netflix_ui_ux/netflix_theme.dart lib/theme/

# Componentes
cp .devin/skills/netflix_ui_ux/netflix_card.dart lib/widgets/
cp .devin/skills/netflix_ui_ux/netflix_carousel.dart lib/widgets/
```

### 3. Aplicar o Tema

No `main.dart`:

```dart
import 'theme/netflix_theme.dart';

MaterialApp(
  theme: NetflixTheme.lightTheme,
  darkTheme: NetflixTheme.darkTheme,
  themeMode: ThemeMode.dark,
  home: const HomeScreen(),
)
```

### 4. Usar os Componentes

```dart
// Hero Card
NetflixHeroCard(
  imageUrl: 'url',
  title: 'Anime Title',
  description: 'Synopsis',
  onPlay: () {},
  onMyList: () {},
)

// Carousel
NetflixCarousel(
  title: 'Trending Now',
  items: animeList.map((anime) => NetflixCard(...)).toList(),
)

// Card Individual
NetflixCard(
  imageUrl: 'url',
  title: 'Title',
  rating: 8.5,
  onTap: () {},
)
```

## 📦 Componentes Disponíveis

### NetflixTheme
- Tema claro e escuro
- Paleta de cores Netflix-inspired
- Animações e transições
- Sombras e gradientes

### NetflixCard
- Card com hover effect
- Scale animation
- Rating badge
- Suporte a TV navigation
- Overlay widgets customizáveis

### NetflixHeroCard
- Hero section para featured content
- Background image com gradient
- Call-to-action buttons
- Responsive height

### NetflixCarousel
- Lista horizontal responsiva
- Scroll suave
- Gradient fades nas bordas
- Navigation buttons (desktop/TV)
- Shimmer loading placeholder

### NetflixGrid
- Layout em grid responsivo
- Adaptive column count
- Custom aspect ratio
- Title e trailing widgets

## 🎯 Padrões de Design

### Cores
```dart
// Netflix Brand
netflixRed: #E50914
background: #000000
surface: #141414
textPrimary: #FFFFFF
textSecondary: #B3B3B3
```

### Spacing
```dart
xs: 4.0
sm: 8.0
md: 16.0
lg: 24.0
xl: 32.0
xxl: 48.0
```

### Border Radius
```dart
sm: 4.0
md: 8.0
lg: 12.0
xl: 16.0
```

### Animações
```dart
fastDuration: 150ms
mediumDuration: 300ms
slowDuration: 500ms
defaultCurve: easeInOutCubic
```

## 🔧 Customização

### Cores Personalizadas

Edite `netflix_theme.dart` para usar cores do PauloFlix:

```dart
class PauloFlixTheme extends NetflixTheme {
  static const Color goAnimeCyan = Color(0xFF00BCD4);
  static const Color goAnimePurple = Color(0xFF7C4DFF);
  
  static ThemeData get goAnimeDarkTheme {
    return NetflixTheme.darkTheme.copyWith(
      primaryColor: goAnimeCyan,
      colorScheme: NetflixTheme.darkTheme.colorScheme.copyWith(
        primary: goAnimeCyan,
        secondary: goAnimePurple,
      ),
    );
  }
}
```

### Componentes Customizados

Estenda os componentes existentes:

```dart
class PauloFlixCard extends NetflixCard {
  final String quality; // HD, 4K, etc.
  
  const PauloFlixCard({
    required super.imageUrl,
    required this.quality,
    super.title,
    super.rating,
    super.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return NetflixCard(
      imageUrl: imageUrl,
      title: title,
      rating: rating,
      onTap: onTap,
      overlayWidget: Positioned(
        top: 8,
        left: 8,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            quality,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
```

## 📱 Responsividade

A skill se integra com o sistema de responsividade existente do projeto:

```dart
import '../utils/responsive.dart';

// Usar helpers existentes
NetflixCard(
  width: Responsive.getHorizontalListItemWidth(context),
  height: Responsive.getCardHeight(context),
  isTV: await Responsive.isTV(context),
)

NetflixCarousel(
  height: Responsive.getSectionHeight(context),
  isTV: await Responsive.isTV(context),
)
```

## 🎮 TV Navigation

Os componentes suportam navegação por D-pad para Android TV:

```dart
NetflixCard(
  isTV: true, // Ativa focus management
  // O componente gerencia FocusNode automaticamente
)

NetflixCarousel(
  isTV: true, // Remove navigation buttons, usa D-pad
)
```

## 🌐 Exemplos de Uso

Veja `INTEGRATION_EXAMPLE.md` para exemplos completos de:

- Integração no Home Screen
- Uso no Anime Detail Screen
- Loading states com Shimmer
- Customização de tema
- Animações customizadas

## 📚 Referências

- [Netflix Design System](https://www.netflixdesign.com/)
- [Flutter Adaptive & Responsive](https://docs.flutter.dev/ui/adaptive-responsive)
- [Material Design 3](https://m3.material.io/)

## 🚧 Próximas Melhorias

- [ ] Adicionar mais componentes (bottom nav, search bar, etc.)
- [ ] Implementar page transitions
- [ ] Adicionar mais animações
- [ ] Criar componentes de busca
- [ ] Implementar skeleton screens
- [ ] Adicionar suporte a Picture-in-Picture

## 💡 Dicas

1. **Performance**: Use `const` widgets onde possível
2. **Imagens**: Sempre use `CachedNetworkImage` com cache otimizado
3. **TV**: Teste navegação por D-pad em Android TV
4. **Responsividade**: Use helpers de `Responsive` para layouts adaptativos
5. **Animações**: Mantenha animações suaves e curtas
6. **Acessibilidade**: Adicione labels semânticos

## 🤝 Contribuindo

Para adicionar novos componentes ou melhorias:

1. Edite os arquivos da skill em `.devin/skills/netflix_ui_ux/`
2. Atualize a documentação em `SKILL.md`
3. Adicione exemplos em `INTEGRATION_EXAMPLE.md`
4. Teste em diferentes dispositivos (mobile, tablet, TV)

## 📄 Licença

Esta skill é parte do projeto PauloFlix e segue a mesma licença.