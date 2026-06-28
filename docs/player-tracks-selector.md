# Player Tracks Selector — Seletor de Faixas de Vídeo/Áudio/Legenda

## Status: 🟡 Planejado — aguardando aprovação

## Motivação

Arquivos MKV (especialmente do PauloFlix) frequentemente contêm múltiplas faixas de áudio (ex: japonês, português), múltiplas faixas de legenda (ex: português, inglês, sinais) e até múltiplas faixas de vídeo (ex: 1080p, 4K). O player atualmente **auto-seleciona** a faixa de áudio português (`audiosBr`) e as legendas externas, mas o usuário não tem controle manual para trocar entre as faixas disponíveis.

Já existe um seletor de **legendas** (`video_player_subtitle_sheet.dart`), mas ele cobre apenas `SubtitleTrack` — faltam seletores para áudio e vídeo, e não há um ponto de entrada unificado na interface do player.

## Estado Atual

### `video_player_screen.dart` — já tem os dados
```dart
List<VideoTrack>? videos;
List<AudioTrack>? audios;
List<SubtitleTrack>? subtitles;
AudioTrack? audiosBr; // Faixa PT-BR detectada
```
Populados via `player.stream.tracks.listen(...)` no `_initializeVideoPlayer()`.

### `modern_video_player_controls.dart` — top bar atual
```
[← back]   título do episódio   [⏭ próximo]
```
O `ModernVideoPlayerControls` recebe o `Player` e tem acesso às tracks via `player.state.tracks`.

### `video_player_subtitle_sheet.dart` — seletor de legendas existente
Bottom sheet modal com opções: Auto, Desligado, legendas embutidas, legendas externas (.srt). Usa `player.setSubtitleTrack(track)`.

## O que será feito

### 1. Ícone de Configurações na Top Bar

Adicionar um `Icons.settings_rounded` ao lado do botão de próximo episódio (`⏭`) na `_buildTopBar()` do `ModernVideoPlayerControls`.

**Layout proposto:**
```
[← back]   título do episódio   [⚙️ settings]   [⏭ próximo]
```

O ícone de configurações só aparece quando há **pelo menos 2 faixas disponíveis** em qualquer categoria (vídeo, áudio ou legenda) — ou seja, quando o usuário tem algo para escolher.

### 2. Track Selector Sidebar (Bottom Sheet Unificado)

Um `showModalBottomSheet` com 3 abas/seções:

### 3. Track Selector Bottom Sheet — Detalhamento por Tipo

#### Aba 1: Vídeo

**Dados disponíveis (VideoTrack):**
| Campo | Tipo | Exibição |
|-------|------|----------|
| `id` | `String` | Identificador interno (não exibir) |
| `title` | `String?` | Nome amigável da faixa |
| `language` | `String?` | Código do idioma (ex: "eng", "jpn") |
| `width` x `height` | `int` | Resolução (ex: "1920x1080") |
| `codec` | `String?` | Codec (ex: "h264", "hevc") |

**Layout do item:**
```
┌─────────────────────────────────────┐
│ [check]  Título da faixa            │
│          1920x1080 • h264 • eng     │  ← subtitle smaller
└─────────────────────────────────────┘
```
- Ícone: `Icons.videocam_rounded`
- Subtítulo formatado como `{width}x{height} • {codec} • {language}`
- Ação: `player.setVideoTrack(track)`
- Destaque (check) na faixa atualmente selecionada

#### Aba 2: Áudio

**Dados disponíveis (AudioTrack):**
| Campo | Tipo | Exibição |
|-------|------|----------|
| `id` | `String` | Identificador interno (não exibir) |
| `title` | `String?` | Nome amigável da faixa |
| `language` | `String?` | Código do idioma (ex: "por", "jpn") |
| `codec` | `String?` | Codec (ex: "aac", "opus", "ac3") |

**Layout do item:**
```
┌─────────────────────────────────────┐
│ [check]  Título da faixa            │
│          aac • português            │  ← subtitle smaller
└─────────────────────────────────────┘
```
- Ícone: `Icons.audiotrack_rounded`
- Subtítulo formatado como `{codec} • {language}`
- Se `language` for "por" ou "pt-BR", badge **PT-BR** ao lado do título
- Ação: `player.setAudioTrack(track)`
- Destaque (check) na faixa atual

#### Aba 3: Legenda

Reaproveita a lógica existente do `SubtitleSelectorTag` / `_showSubtitleSheet`:

**Dados disponíveis (SubtitleTrack):**
| Campo | Tipo | Exibição |
|-------|------|----------|
| `id` | `String` | Identificador interno (não exibir) |
| `title` | `String?` | Nome amigável da faixa |
| `language` | `String?` | Código do idioma (ex: "por", "eng") |

**Opções sempre presentes:**
- **Auto** (`SubtitleTrack.auto()`) — ícone `Icons.auto_awesome_rounded`
- **Desligado** (`SubtitleTrack.no()`) — ícone `Icons.subtitles_off_rounded`

**Legendas embutidas no MKV (`player.state.tracks.subtitle`):**
- Ícone: `Icons.movie_outlined`
- Rótulo: `{title}` ou `{language}` ou `Track {id}`

**Legendas externas (.srt do Episode.subtitleTracks):**
- Ícone: `Icons.subtitles_rounded`
- Rótulo: `{displayName}`
- Subtítulo: `{language} • .srt`

**Ação:** `player.setSubtitleTrack(track)`

### 3. Passagem de Dados

O `ModernVideoPlayerControls` precisa receber as listas de tracks. Isso pode ser feito de duas formas:

**Opção A (recomendada):** O controle lê diretamente de `player.state.tracks` — as tracks já estão disponíveis como `Player.state.tracks.video`, `.audio`, `.subtitle`. Não precisa de props extras.

**Opção B:** O `video_player_screen.dart` passa explicitamente `videos`, `audios`, `subtitles` para os controls.

**Escolha: Opção A** — mais simples e evita duplicação de estado. O `stream.tracks` listener em `video_player_screen.dart` continuará existindo para o `audiosBr`, mas os controles lerão do `player.state.tracks` diretamente.

### 4. Fluxo TV (D-pad)

O bottom sheet deve ser navegável por D-pad:
- `FocusableWidget` em cada opção de track
- Setas sobem/descem entre as opções
- Select/Enter seleciona a track
- Back fecha o bottom sheet

### 5. Tratamento de Legendas Embutidas

As `_embeddedSubtitleTracks` (populadas via `_waitForEmbeddedSubtitleTracks`) também precisam estar acessíveis pelo controle. Como o controle já tem o `Player`, ele pode assinar `player.stream.tracks` para obter as tracks de legenda — mas as tracks só aparecem após `Media.open`. 

Solução: o controle pode ler `player.state.tracks.subtitle` diretamente no momento em que o bottom sheet é aberto (já que o vídeo já está tocando neste ponto).

## Arquivos a Modificar

| Arquivo | Mudança |
|---------|---------|
| `lib/ui/player/widgets/modern_video_player_controls.dart` | Adicionar `_ControlButton` settings na top bar + implementar o bottom sheet unificado de tracks |
| `lib/ui/player/widgets/video_player_screen.dart` | Nenhuma mudança necessária — dados já existem, controles lerão do `player.state.tracks` |
| `lib/ui/player/widgets/video_player_subtitle_sheet.dart` | Pode ser reutilizado ou substituído pela seção de legendas do novo bottom sheet unificado |

## Novos Arquivos

Nenhum — tudo será adicionado dentro de `modern_video_player_controls.dart` para manter a coesão.

## Riscos e Mitigações

| Risco | Mitigação |
|-------|-----------|
| `player.state.tracks` pode estar vazio se o vídeo ainda não carregou | O ícone de settings só aparece se houver tracks disponíveis (vazio = oculto) |
| Troca de faixa de vídeo pode causar flicker | `player.setVideoTrack()` é instantâneo no libmpv; testar em TV |
| Bottom sheet pode ser difícil de navegar em TV | Cada opção envolta em `FocusableWidget` com foco automático |

## Prioridade

1. Ícone de settings na top bar
2. Bottom sheet com seção de áudio (mais usado)
3. Seção de legendas (reaproveitar lógica existente)
4. Seção de vídeo (menos comum, mas útil)

## Dependências

- Nenhuma dependência externa nova
- API `media_kit` já usada: `player.setAudioTrack()`, `player.setVideoTrack()`, `player.setSubtitleTrack()`
- `player.state.tracks` já disponível em `Player.state`
