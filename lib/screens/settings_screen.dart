import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/locale_service.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../widgets/focusable_widget.dart';

class SettingsScreen extends StatelessWidget {
  final VoidCallback? onBackPressed;

  const SettingsScreen({super.key, this.onBackPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeService = Provider.of<LocaleService>(context);
    final canPop = Navigator.canPop(context);
    final isTV = Responsive.isTV(context);

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
                  } else if (onBackPressed != null) {
                    onBackPressed!();
                  }
                },
              ),
        // : FocusableWidget(
        //     onSelect: () {
        //       if (canPop) {
        //         Navigator.pop(context);
        //       } else if (onBackPressed != null) {
        //         onBackPressed!();
        //       }
        //     },
        //     child: Container(
        //       padding: const EdgeInsets.all(8),
        //       decoration: BoxDecoration(
        //         color: Colors.black.withValues(alpha: 0.3),
        //         borderRadius: BorderRadius.circular(12),
        //       ),
        //       child: const Icon(Icons.arrow_back, color: Colors.white),
        //     ),
        //   ),
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
                    'GoAnime',
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

          if (isTV) ...[
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
}
