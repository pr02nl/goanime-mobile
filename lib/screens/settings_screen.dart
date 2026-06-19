import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/api_key_settings_service.dart';
import '../services/locale_service.dart';
import '../services/tmdb_service.dart';
import '../screens/tv_qr_setup_dialog.dart';
import '../theme/app_colors.dart';
import '../utils/tv_detector.dart';
import '../widgets/focusable_widget.dart';
import '../widgets/tv_safe_text_field.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;

  const SettingsScreen({super.key, this.onBackPressed});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isTV = false;
  final ApiKeySettingsService _apiKeys = ApiKeySettingsService();
  final TextEditingController _tmdbKeyController = TextEditingController();
  bool _isTmdbConfigured = false;
  String _maskedTmdbKey = '';
  bool _showTmdbField = false;

  @override
  void initState() {
    super.initState();
    _detectTVMode();
    _loadTmdbStatus();
  }

  Future<void> _loadTmdbStatus() async {
    final key = await _apiKeys.getTmdbApiKey();
    if (!mounted) return;
    setState(() {
      _isTmdbConfigured = key != null && key.isNotEmpty;
      _maskedTmdbKey = _maskKey(key);
    });
  }

  String _maskKey(String? key) {
    if (key == null || key.isEmpty) return '';
    if (key.length <= 8) return '••••••••';
    return '${key.substring(0, 4)}${'•' * (key.length - 8)}${key.substring(key.length - 4)}';
  }

  @override
  void dispose() {
    _tmdbKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveTmdbKey() async {
    final raw = _tmdbKeyController.text.trim();
    if (raw.isEmpty) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.validKeyRequired)),
      );
      return;
    }
    await _apiKeys.setTmdbApiKey(raw);
    TmdbService().setApiKey(raw);
    _tmdbKeyController.clear();
    await _loadTmdbStatus();
    if (!mounted) return;
    setState(() => _showTmdbField = false);
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.tmdbKeySaved),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _removeTmdbKey() async {
    await _apiKeys.clearTmdbApiKey();
    TmdbService().setApiKey(null);
    _tmdbKeyController.clear();
    await _loadTmdbStatus();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.tmdbKeyRemoved)),
    );
  }

  /// Abre o dialog QR code para configurar a API key via celular (TV only)
  Future<void> _showQrSetup() async {
    final success = await TvQrSetupDialog.show(context);
    if (success && mounted) {
      await _loadTmdbStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('API key configurada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _detectTVMode() async {
    final isTV = await TVDetector.isTV;
    if (mounted) {
      setState(() {
        _isTV = isTV;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeService = Provider.of<LocaleService>(context);
    final canPop = Navigator.canPop(context);
    final isTV = _isTV;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          l10n.settings,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isTV ? 28 : 20,
          ),
        ),
        leading: isTV
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  if (canPop) {
                    Navigator.pop(context);
                  } else if (widget.onBackPressed != null) {
                    widget.onBackPressed!();
                  }
                },
              ),
      ),
      body: ListView(
        padding: EdgeInsets.all(isTV ? 24 : 16),
        children: [
          // Language Section
          _buildSectionCard(
            context,
            title: l10n.language,
            icon: Icons.language,
            iconColor: Colors.blue,
            isTV: isTV,
            child: Column(
              children: [
                _buildLanguageTile(
                  context,
                  title: l10n.english,
                  subtitle: 'English (US)',
                  flag: '🇺🇸',
                  isSelected: localeService.isEnglish,
                  isTV: isTV,
                  onTap: () async {
                    await localeService.setEnglish();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.languageChanged),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                    }
                  },
                ),
                const Divider(height: 1, color: Colors.white12),
                _buildLanguageTile(
                  context,
                  title: l10n.portuguese,
                  subtitle: 'Português (Brasil)',
                  flag: '🇧🇷',
                  isSelected: localeService.isPortuguese,
                  isTV: isTV,
                  onTap: () async {
                    await localeService.setPortuguese();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.languageChanged),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          SizedBox(height: isTV ? 28 : 20),

          _buildApiKeysSection(isTV: isTV),

          SizedBox(height: isTV ? 28 : 20),

          // About Section
          _buildSectionCard(
            context,
            title: l10n.about,
            icon: Icons.info_outline,
            iconColor: AppColors.primary,
            isTV: isTV,
            child: Padding(
              padding: EdgeInsets.all(isTV ? 24 : 16),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(isTV ? 28 : 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                      ),
                      borderRadius: BorderRadius.circular(isTV ? 20 : 16),
                    ),
                    child: Icon(
                      Icons.play_circle_filled,
                      size: isTV ? 80 : 60,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: isTV ? 20 : 16),
                  Text(
                    'PauloFlix',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isTV ? 32 : 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: isTV ? 12 : 8),
                  Text(
                    '${l10n.version} 1.0.0',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: isTV ? 18 : 14,
                    ),
                  ),
                  SizedBox(height: isTV ? 20 : 16),
                  Text(
                    'Anime streaming app built with Flutter\nNow with Android TV support!',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: isTV ? 16 : 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          if (isTV) _buildTVModeSection(isTV: isTV),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
    required bool isTV,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isTV ? 24 : 20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(isTV ? 24 : 20),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isTV ? 14 : 10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(isTV ? 16 : 12),
                  ),
                  child: Icon(icon, color: iconColor, size: isTV ? 32 : 24),
                ),
                SizedBox(width: isTV ? 16 : 12),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isTV ? 24 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildLanguageTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String flag,
    required bool isSelected,
    required bool isTV,
    required VoidCallback onTap,
  }) {
    final content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTV ? 28 : 20,
        vertical: isTV ? 20 : 16,
      ),
      child: Row(
        children: [
          Text(flag, style: TextStyle(fontSize: isTV ? 40 : 32)),
          SizedBox(width: isTV ? 20 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isTV ? 20 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: isTV ? 4 : 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: isTV ? 16 : 13,
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            Container(
              padding: EdgeInsets.all(isTV ? 12 : 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check,
                color: Colors.green,
                size: isTV ? 28 : 20,
              ),
            ),
        ],
      ),
    );

    if (isTV) {
      return FocusableWidget(onSelect: onTap, borderRadius: 12, child: content);
    }

    return InkWell(onTap: onTap, child: content);
  }

  Widget _buildApiKeysSection({required bool isTV}) {
    final l10n = AppLocalizations.of(context);
    return _buildSectionCard(
      context,
      title: l10n.apiKeys,
      icon: Icons.vpn_key_outlined,
      iconColor: const Color(0xFFDC2626),
      isTV: isTV,
      child: Padding(
        padding: EdgeInsets.all(isTV ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.movie_outlined,
                  color: Color(0xFFDC2626),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.theMovieDatabase,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isTmdbConfigured
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _isTmdbConfigured ? l10n.configured : l10n.notConfigured,
                    style: TextStyle(
                      color: _isTmdbConfigured ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _isTmdbConfigured
                  ? '${l10n.configured}: $_maskedTmdbKey'
                  : l10n.addYourKey,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            if (_showTmdbField) ...[
              TVSafeTextField(
                controller: _tmdbKeyController,
                obscureText: false,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: l10n.pasteApiKeyHint,
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFFDC2626),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveTmdbKey,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(l10n.save),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _showTmdbField = false);
                        _tmdbKeyController.clear();
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        l10n.cancel,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (isTV)
              // TV: Mostra botão QR code para configurar via celular
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showQrSetup,
                      icon: const Icon(Icons.qr_code_2, size: 20),
                      label: Text(
                        _isTmdbConfigured
                            ? 'Reconfigurar via QR Code'
                            : 'Configurar via QR Code',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  if (_isTmdbConfigured) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Remover chave',
                      onPressed: _removeTmdbKey,
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                    ),
                  ],
                ],
              )
            else
              // Mobile: Mostra input de texto
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => setState(() => _showTmdbField = true),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(
                        _isTmdbConfigured
                            ? 'Atualizar chave'
                            : 'Adicionar chave',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (_isTmdbConfigured) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Remover chave',
                      onPressed: _removeTmdbKey,
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 12),
            FocusableWidget(
              onSelect: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Gere sua chave em: https://www.themoviedb.org/settings/api',
                    ),
                    duration: Duration(seconds: 5),
                  ),
                );
              },
              borderRadius: 6,
              focusPadding: EdgeInsets.zero,
              focusScale: 1.0,
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Como obter uma chave?',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTVModeSection({required bool isTV}) {
    return Column(
      children: [
        SizedBox(height: isTV ? 28 : 20),
        _buildSectionCard(
          context,
          title: 'TV Mode',
          icon: Icons.tv,
          iconColor: AppColors.accent,
          isTV: isTV,
          child: Padding(
            padding: EdgeInsets.all(isTV ? 24 : 16),
            child: Text(
              'Use your remote control to navigate:\n'
              '• D-Pad: Navigate between items\n'
              '• Center button: Select\n'
              '• Back button: Go back',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: isTV ? 16 : 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
