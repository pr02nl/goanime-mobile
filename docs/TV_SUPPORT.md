# Suporte a Android TV

O PauloFlix agora possui suporte completo para Android TV (Leanback), permitindo que você assista seus animes favoritos na tela grande da sua televisão.

## Funcionalidades da TV

### Navegação com Controle Remoto
- **D-Pad (Setas)**: Navegue entre os itens do menu, cards de anime e botões
- **Botão Central (OK/Select)**: Selecione o item focado
- **Botão Voltar**: Retorna à tela anterior ou fecha menus

### Foco Visual
- Todos os elementos interativos possuem indicador visual de foco
- Escala aumentada (1.05x - 1.1x) no item focado
- Borda colorida e sombra para melhor visibilidade
- Animações suaves ao navegar

### Layout Adaptativo
- **Smartphones**: 2 colunas, cards 140x200
- **Tablets**: 4 colunas, cards 160x240
- **TV**: 6 colunas, cards 200x300
- Textos 30-40% maiores para melhor legibilidade na TV
- Espaçamentos aumentados para facilitar navegação

## Arquivos de Suporte a TV

```
lib/├── ui/
│   ├── core/utils/
│   │   ├── tv_detector.dart      # Detecção de dispositivo TV
│   │   └── responsive.dart       # Layouts responsivos (atualizado para TV)
│   ├── core/widgets/
│   │   ├── focusable_widget.dart # Widgets com suporte a foco
│   │   └── tv_grid_view.dart     # Grid otimizado para navegação TV
│   ├── core/themes/
│   │   └── tv_theme.dart         # Tema com fontes e espaçamentos para TV
│   └── navigation/
│       └── main_navigation_screen.dart # Navegação adaptada para TV
└──
    └── navigation/main_navigation_screen.dart # Navegação adaptada para TV
```

## Configuração Android TV

### AndroidManifest.xml
O manifesto foi configurado com:
- `android.software.leanback`: Suporte a Android TV
- `android.hardware.touchscreen`: Não obrigatório (TV usa controle remoto)
- `LEANBACK_LAUNCHER`: Permite aparecer no launcher de TV
- Banner para Android TV

### Banner da TV
- Local: `android/app/src/main/res/drawable/tv_banner.xml`
- Resolução recomendada: 320x180px
- Formato: XML vetorial ou PNG

## Detecção de TV

A classe `TVDetector` fornece métodos para verificar se o app está rodando em uma TV:

```dart
import 'utils/tv_detector.dart';
import 'utils/responsive.dart';

// Verificar se é TV
if (TVDetector.isTV) {
  // Ajustar comportamento para TV
}

// Ou usando Responsive
if (Responsive.isTV(context)) {
  // Ajustar layout
}
```

## Tema TV

O arquivo `lib/ui/core/themes/tv_theme.dart` contém:

### Tamanhos de Fonte
```dart
fontSizeSmall = 16.0;      // vs 12 no mobile
fontSizeRegular = 20.0;    // vs 14 no mobile
fontSizeMedium = 24.0;     // vs 18 no mobile
fontSizeLarge = 28.0;      // vs 22 no mobile
fontSizeTitle = 40.0;      // vs 28 no mobile
```

### Espaçamentos
```dart
spacingSmall = 12.0;
spacingRegular = 20.0;
spacingMedium = 28.0;
spacingLarge = 36.0;
```

### Tamanhos de Botões
```dart
buttonHeight = 56.0;       // vs 40 no mobile
buttonMinWidth = 160.0;    // vs 120 no mobile
iconSizeRegular = 32.0;    // vs 24 no mobile
```

## Uso de Widgets Focáveis

Para adicionar suporte a controle remoto em qualquer widget:

```dart
import 'widgets/focusable_widget.dart';

// Card focável
FocusableWidget(
  onSelect: () => navegarParaDetalhes(anime),
  child: AnimeCard(anime: anime),
)

// Botão focável
TVButton(
  onPressed: () => executarAcao(),
  child: Text('Assistir'),
)

// Grid focável para TV
TVGridView(
  items: animes,
  crossAxisCount: 6,  // Mais colunas na TV
  itemBuilder: (context, anime, index) => AnimeCard(anime),
  onItemSelected: (anime, index) => navegarParaDetalhes(anime),
)
```

## Compilação para Android TV

### Debug
```bash
flutter build apk --debug
```

### Release
```bash
flutter build apk --release
```

### Bundle para Play Store
```bash
flutter build appbundle
```

## Instalação na TV

1. Habilite "Modo de Desenvolvedor" na TV:
   - Configurações > Sobre > Build (clique 7 vezes)

2. Habilite "Depuração USB" ou "Depuração de Rede"

3. Instale via ADB:
   ```bash
   adb connect <ip-da-tv>:5555
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```

## Testando em TV Real

### Via Wi-Fi (ADB)
```bash
# Conectar à TV
adb connect 192.168.1.100:5555

# Instalar
adb install build/app/outputs/flutter-apk/app-debug.apk

# Ver logs
adb logcat | grep flutter
```

### Testando Navegação
1. Use as setas do controle remoto para navegar
2. O item focado deve ter:
   - Borda colorida (primária)
   - Sombra suave
   - Escala levemente maior
3. Botão OK seleciona o item
4. Botão Voltar retorna à tela anterior

## Troubleshooting

### App não aparece no launcher da TV
- Verifique se `LEANBACK_LAUNCHER` está no AndroidManifest.xml
- Confira se o banner está definido

### Navegação não funciona com controle remoto
- Verifique se os widgets usam `FocusableWidget`
- Confira se `TVDetector.isTV` está retornando true
- Teste com `TVDetector.forceTVMode(true)`

### Elementos muito pequenos na TV
- Verifique se está usando `TVTheme`
- Use `Responsive` para tamanhos adaptativos
- Aumente o padding para `isTV ? 24 : 16`

## Melhores Práticas

1. **Sempre use `FocusableWidget`** para elementos clicáveis em telas TV
2. **Teste em diferentes tamanhos** de tela (720p, 1080p, 4K)
3. **Mantenha o foco visível** com contraste adequado
4. **Use tamanhos mínimos** de 48dp para touch targets (64dp na TV)
5. **Espaçamento generoso** entre elementos interativos
6. **Texto legível** de longa distância (tamanho mínimo 16sp na TV)

## Recursos Adicionais

- [Android TV Guidelines](https://developer.android.com/training/tv/start)
- [Flutter TV Development](https://flutter.dev/multi-platform)
- [TV Input Framework](https://source.android.com/devices/tv)

## Notas

- O app é compatível com Android TV 5.0+ (API 21+)
- Requer Leanback launcher para aparecer na Play Store de TV
- A navegação D-pad é obrigatória para certificação Android TV
- Suporte a gamepad é opcional mas recomendado
