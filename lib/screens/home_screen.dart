import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../widgets/profile_dialog.dart';
import '../services/database_service.dart';
import '../models/game_model.dart';
import 'loading_screen.dart';
import '../widgets/game_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _dbService = DatabaseService();

  bool _hasClaimedLegacy = false;
  bool _isLoading = false;

  // Dashboard Data
  List<Game> _topGames = [];
  List<Map<String, dynamic>> _topReviewers = [];
  bool _isLoadingDashboard = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkProfileCompletion();
      _checkLegacyStatus();
    });
    _fetchDashboardData();
  }

  Future<void> _checkLegacyStatus() async {
    final claimed = await _dbService.hasClaimedLegacy();
    if (mounted) setState(() => _hasClaimedLegacy = claimed);
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoadingDashboard = true);
    try {
      final games = await _dbService.getAppGamesRanking();
      final reviewers = await _dbService.getTopReviewers();

      if (mounted) {
        setState(() {
          _topGames = games.take(5).toList();
          _topReviewers = reviewers.take(5).toList();
          _isLoadingDashboard = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
      if (mounted) setState(() => _isLoadingDashboard = false);
    }
  }

  void _checkProfileCompletion() {
    final user = context.read<AuthService>().currentUser;
    final username = user?.userMetadata?['username'] as String?;

    if (username == null || username.isEmpty) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const ProfileDialog(isMandatory: true),
      );
    }
  }

  Future<void> _showClaimDialog() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Resgatar Histórico',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Insira seu código de acesso para recuperar suas avaliações antigas.',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Código de Acesso',
                hintText: 'Ex: 1234',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE94560),
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Resgatar',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (code != null && code.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        final result = await _dbService.claimLegacyRatings(code);
        if (mounted) {
          final success = result['success'] as bool;
          final message = result['message'] as String;
          final count = result['count'] as int?;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? '$message ($count avaliações)' : message),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );

          if (success) {
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoadingScreen()),
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Resetar Conta (DEBUG)',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        content: Text(
          'Isso apagará TODAS as suas avaliações, coleção e lista de desejos. O histórico poderá ser resgatado novamente.\n\nTem certeza?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Resetar Tudo'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _dbService.resetAccount();
        if (mounted) {
          setState(() {
            _hasClaimedLegacy = false;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Conta resetada com sucesso!')),
          );
          _fetchDashboardData(); // Refresh dashboard
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao resetar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final username = user?.userMetadata?['username'] as String? ?? 'Jogador';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header
              Text(
                'Olá, $username!',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                'Bem-vindo ao seu painel.',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),

              // Stats Grid
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Coleção',
                      Icons.grid_view_rounded,
                      Colors.blue,
                      _dbService.getCollectionStream(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Desejos',
                      Icons.favorite_rounded,
                      Colors.pink,
                      _dbService.getWishlistStream(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Avaliados',
                      Icons.star_rounded,
                      Colors.amber,
                      _dbService.getRatedGamesStream(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Top 5 Games
              Text(
                'Top 5 Jogos',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              _isLoadingDashboard
                  ? const Center(child: CircularProgressIndicator())
                  : _topGames.isEmpty
                  ? const Text('Nenhum jogo encontrado.')
                  : Column(
                      children: _topGames
                          .map((game) => _buildGameTile(game))
                          .toList(),
                    ),

              const SizedBox(height: 32),

              // Top 5 Reviewers
              Text(
                'Top 5 Avaliadores',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              _isLoadingDashboard
                  ? const Center(child: CircularProgressIndicator())
                  : _topReviewers.isEmpty
                  ? const Text('Nenhum avaliador encontrado.')
                  : Column(
                      children: _topReviewers
                          .asMap()
                          .entries
                          .map(
                            (entry) =>
                                _buildReviewerTile(entry.value, entry.key + 1),
                          )
                          .toList(),
                    ),

              const SizedBox(height: 32),

              // Actions Section
              Text(
                'Ações Rápidas',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              if (!_hasClaimedLegacy)
                _buildActionTile(
                  'Resgatar Histórico',
                  'Importe suas avaliações antigas',
                  Icons.history_edu,
                  Colors.purple,
                  _showClaimDialog,
                ),

              const SizedBox(height: 16),

              // Debug Actions
              ExpansionTile(
                title: Text(
                  'Opções de Desenvolvedor',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever,
                      color: Colors.red,
                    ),
                    title: Text(
                      'Resetar Conta',
                      style: GoogleFonts.poppins(color: Colors.red),
                    ),
                    onTap: _resetAccount,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    IconData icon,
    Color color,
    Stream<List<dynamic>> stream,
  ) {
    return StreamBuilder<List<dynamic>>(
      stream: stream,
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.length : 0;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(color: color.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                count.toString(),
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionTile(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildGameTile(Game game) {
    return GameCard(game: game, layout: GameCardLayout.list, showRank: true);
  }

  Widget _buildReviewerTile(Map<String, dynamic> reviewer, int rank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rank <= 3 ? const Color(0xFFE94560) : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Text(
              '#$rank',
              style: GoogleFonts.poppins(
                color: rank <= 3 ? Colors.white : Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: reviewer['avatar_url'] != null
                ? NetworkImage(reviewer['avatar_url'])
                : null,
            child: reviewer['avatar_url'] == null
                ? Text(
                    (reviewer['username'] as String)[0].toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reviewer['username'],
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${reviewer['count']} avaliações',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
