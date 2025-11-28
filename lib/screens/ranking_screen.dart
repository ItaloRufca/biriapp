import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/game_model.dart';
import '../services/bgg_service.dart';
import '../services/database_service.dart';
import '../widgets/game_card.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BggService _bggService = BggService();
  final DatabaseService _dbService = DatabaseService();

  // Games State
  List<Game> _allGames = [];
  List<Game> _games = [];
  bool _isLoadingGames = true;
  String? _gamesErrorMessage;
  Timer? _debounce;
  String _currentQuery = '';

  // Reviewers State
  List<Map<String, dynamic>> _reviewers = [];
  bool _isLoadingReviewers = true;
  String? _reviewersErrorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchGames();
    _fetchReviewers();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchGames() async {
    setState(() {
      _isLoadingGames = true;
      _gamesErrorMessage = null;
    });
    try {
      final games = await _dbService.getAppGamesRanking();
      if (mounted) {
        setState(() {
          _allGames = games;
          _games = games;
          _isLoadingGames = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _gamesErrorMessage = 'Erro ao carregar jogos: $e';
          _isLoadingGames = false;
        });
      }
    }
  }

  Future<void> _fetchReviewers() async {
    setState(() {
      _isLoadingReviewers = true;
      _reviewersErrorMessage = null;
    });
    try {
      final reviewers = await _dbService.getTopReviewers();
      if (mounted) {
        setState(() {
          _reviewers = reviewers;
          _isLoadingReviewers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _reviewersErrorMessage = 'Erro ao carregar avaliadores: $e';
          _isLoadingReviewers = false;
        });
      }
    }
  }

  Future<void> _searchGames(String query) async {
    if (query.trim().isEmpty) {
      _fetchGames();
      return;
    }

    setState(() {
      _isLoadingGames = true;
      _gamesErrorMessage = null;
    });

    try {
      final games = await _bggService.searchGames(query);
      if (mounted) {
        setState(() {
          _games = games;
          _isLoadingGames = false;
        });
      }
    } catch (e) {
      debugPrint('Global search failed: $e');
      // Fallback to local search
      final localResults = _allGames
          .where(
            (game) => game.name.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();

      if (mounted) {
        setState(() {
          _games = localResults;
          _isLoadingGames = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Busca global indisponível. Pesquisando nos carregados.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _currentQuery = query;
    });

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchGames(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header with Search and Tabs
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                children: [
                  // Search Bar (Only visible for Games tab for now)
                  if (_tabController.index == 0) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: TextField(
                        onChanged: _onSearchChanged,
                        style: GoogleFonts.poppins(color: Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'Pesquisar ranking...',
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.grey.shade500,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey.shade500,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFFE94560),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: const Color(0xFFE94560),
                    labelStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: (index) =>
                        setState(() {}), // Rebuild to toggle search bar
                    tabs: const [
                      Tab(text: 'Jogos'),
                      Tab(text: 'Avaliadores'),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildGamesList(), _buildReviewersList()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGamesList() {
    if (_isLoadingGames) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE94560)),
      );
    }
    if (_gamesErrorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _gamesErrorMessage!,
              style: GoogleFonts.poppins(color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchGames,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE94560),
                foregroundColor: Colors.white,
              ),
              child: Text('Tentar Novamente', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      );
    }
    if (_games.isEmpty) {
      return Center(
        child: Text(
          'Nenhum jogo encontrado',
          style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _games.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final game = _games[index];
        // Parse rank from game.rank string if available, otherwise use index + 1
        int? rank;
        if (game.rank != null && game.rank!.isNotEmpty) {
          rank = int.tryParse(game.rank!);
        }
        if (rank == null && _currentQuery.isEmpty) {
          rank = index + 1;
        }

        return GameCard(
          game: game.copyWith(rank: rank.toString()),
          layout: GameCardLayout.list,
          showRank: true,
          onReturn: _fetchGames,
        );
      },
    );
  }

  Widget _buildReviewersList() {
    if (_isLoadingReviewers) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE94560)),
      );
    }
    if (_reviewersErrorMessage != null) {
      return Center(
        child: Text(
          _reviewersErrorMessage!,
          style: GoogleFonts.poppins(color: Colors.red),
        ),
      );
    }
    if (_reviewers.isEmpty) {
      return Center(
        child: Text(
          'Nenhum avaliador encontrado',
          style: GoogleFonts.poppins(color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _reviewers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final reviewer = _reviewers[index];
        final rank = index + 1;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Rank Badge
              Container(
                constraints: const BoxConstraints(minWidth: 30),
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rank <= 3
                      ? const Color(0xFFE94560)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  '#$rank',
                  style: GoogleFonts.poppins(
                    color: rank <= 3 ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: reviewer['avatar_url'] != null
                    ? NetworkImage(reviewer['avatar_url'])
                    : null,
                child: reviewer['avatar_url'] == null
                    ? Text(
                        (reviewer['username'] as String)[0].toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            reviewer['username'],
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (reviewer['is_legacy'] == true) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'LEGACY',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${reviewer['count']} avaliações',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
