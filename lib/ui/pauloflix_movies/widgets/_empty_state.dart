import 'package:flutter/material.dart';

import '../../core/themes/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Estado vazio unificado para a home de filmes.
///
/// Mostra:
/// * Ícone grande (filme)
/// * Mensagem principal
/// * Mensagem secundária (hint sobre TMDB)
/// * Botão "Sincronizar Filmes" (vermelho PauloFlix)
class MoviesEmptyState extends StatelessWidget {
  final bool isSyncing;
  final VoidCallback onSync;

  const MoviesEmptyState({
    super.key,
    required this.isSyncing,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.moviesAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.moviesAccent.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.movie_outlined,
                color: Color(0xFFEF4444),
                size: 56,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.noMoviesAvailable,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Verifique se o TMDB está configurado nas Configurações',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            if (isSyncing)
              const CircularProgressIndicator(color: AppColors.moviesAccent)
            else
              ElevatedButton.icon(
                onPressed: onSync,
                icon: const Icon(Icons.sync),
                label: Text(l10n.syncMovies),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.moviesAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
