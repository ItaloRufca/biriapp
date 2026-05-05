import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/database_service.dart';
import '../models/game_model.dart';
import '../widgets/game_card.dart';

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Coleção',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            labelColor: const Color(0xFFE94560),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFFE94560),
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Coleção'),
              Tab(text: 'Desejos'),
              Tab(text: 'Avaliações'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _GameList(stream: DatabaseService().getCollectionStream()),
            _GameList(stream: DatabaseService().getWishlistStream()),
            _GameList(
              stream: DatabaseService().getRatedGamesStream(),
              showRating: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _GameList extends StatelessWidget {
  final Stream<List<Map<String, dynamic>>> stream;
  final bool showRating;

  const _GameList({required this.stream, this.showRating = false});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFE94560)),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text('Erro: ${snapshot.error}'));
        }

        final games = snapshot.data ?? [];

        if (games.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.games_outlined,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'Nenhum jogo encontrado',
                  style: GoogleFonts.poppins(
                    color: Colors.grey.shade500,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            childAspectRatio: 0.7,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: games.length,
          itemBuilder: (context, index) {
            final data = games[index];
            final game = Game(
              id: data['game_id'],
              name: data['name'] ?? 'Unknown',
              imageUrl: data['image_url'],
              userRating: (data['rating'] as num?)?.toDouble(),
            );

            return GameCard(
              game: game,
              layout: GameCardLayout.grid,
              showRank: false,
            );
          },
        );
      },
    );
  }
}
