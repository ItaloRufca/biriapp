import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/database_service.dart';
import '../services/bgg_service.dart';
import 'main_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  final DatabaseService _dbService = DatabaseService();
  final BggService _bggService = BggService();

  double _progress = 0.0;
  String _statusMessage = 'Iniciando recuperação...';
  int _totalItems = 0;
  int _processedItems = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRecoveryProcess();
    });
  }

  Future<void> _startRecoveryProcess() async {
    try {
      if (mounted) setState(() => _statusMessage = 'Buscando sua coleção...');

      // 1. Fetch ALL user items (Brute force approach as requested)
      final items = await _dbService.getAllUserItems();
      _totalItems = items.length;

      if (_totalItems == 0) {
        _completeProcess();
        return;
      }

      // 2. Process one by one
      for (var game in items) {
        if (!mounted) return;

        setState(() {
          _statusMessage = 'Atualizando: ${game.name}';
        });

        try {
          // Fetch fresh details from BGG
          final freshGame = await _bggService.fetchGameDetails(game.id);

          if (freshGame != null &&
              freshGame.imageUrl != null &&
              freshGame.imageUrl!.isNotEmpty) {
            // Found new valid image, update it (overwriting whatever was there)
            await _dbService.updateGameMetadata(freshGame);
            if (mounted) {
              setState(() {
                _statusMessage = 'Capa atualizada: ${freshGame.name}';
              });
            }
          } else {
            // No image found in BGG, clear the existing one to remove legacy/broken URLs
            await _dbService.clearGameImage(game.id);
            if (mounted) {
              setState(() {
                _statusMessage = 'Sem imagem (BGG): ${game.name}';
              });
            }
            debugPrint(
              'No image found for ${game.name} (ID: ${game.id}) - Cleared',
            );
          }
        } catch (e) {
          debugPrint('Error updating ${game.name}: $e');
          if (mounted) {
            setState(() {
              _statusMessage = 'Erro: ${game.name}';
            });
          }
        }

        _processedItems++;

        if (mounted) {
          setState(() {
            _progress = _processedItems / _totalItems;
          });
        }

        // Rate limit delay (1 second per item to be safe)
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      _completeProcess();
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Erro geral: $e';
        });
        await Future.delayed(const Duration(seconds: 3));
        _completeProcess();
      }
    }
  }

  void _completeProcess() {
    if (!mounted) return;

    setState(() {
      _progress = 1.0;
      _statusMessage = 'Tudo pronto! Reiniciando...';
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFE94560).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_sync_rounded,
                  size: 64,
                  color: Color(0xFFE94560),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'Recuperando Histórico',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Estamos atualizando todas as capas. Isso pode demorar um pouco.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.grey.shade200,
                color: const Color(0xFFE94560),
                minHeight: 10,
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(height: 16),
              Text(
                _statusMessage,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${(_progress * 100).toInt()}%',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFE94560),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
