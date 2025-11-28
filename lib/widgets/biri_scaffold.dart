import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'profile_dialog.dart';
import '../screens/collection_screen.dart';
import '../screens/wishlist_screen.dart';
import '../screens/home_screen.dart';

class BiriScaffold extends StatelessWidget {
  final Widget body;
  final String title;
  final Widget? floatingActionButton;

  const BiriScaffold({
    super.key,
    required this.body,
    this.title = 'BiriApp',
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final userEmail = user?.email ?? 'Usuário';
    final userAvatarUrl = user?.userMetadata?['avatar_url'] as String?;
    final username = user?.userMetadata?['username'] as String?;
    final displayName = username != null && username.isNotEmpty
        ? username
        : userEmail;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => const ProfileDialog(),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: userAvatarUrl != null
                  ? CircleAvatar(
                      backgroundImage: NetworkImage(userAvatarUrl),
                      radius: 18,
                    )
                  : CircleAvatar(
                      backgroundColor: const Color(0xFFE94560),
                      radius: 18,
                      child: Text(
                        displayName.substring(0, 1).toUpperCase(),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E1E1E),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF121212)),
              accountName: Text(
                'Bem-vindo',
                style: GoogleFonts.poppins(color: Colors.white70),
              ),
              accountEmail: Text(
                displayName,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: const Color(0xFFE94560),
                backgroundImage: userAvatarUrl != null
                    ? NetworkImage(userAvatarUrl)
                    : null,
                child: userAvatarUrl == null
                    ? Text(
                        displayName.substring(0, 1).toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home, color: Colors.white70),
              title: Text(
                'Início',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context); // Close drawer
                // Navigate only if not already on HomeScreen
                // This is a simple check, could be more robust
                if (title != 'BiriApp') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.grid_view, color: Colors.white70),
              title: Text(
                'Minha Coleção',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                if (title != 'Minha Coleção') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CollectionScreen(),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite, color: Colors.white70),
              title: Text(
                'Lista de Desejos',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                if (title != 'Lista de Desejos') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WishlistScreen(),
                    ),
                  );
                }
              },
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFFE94560)),
              title: Text(
                'Sair',
                style: GoogleFonts.poppins(color: const Color(0xFFE94560)),
              ),
              onTap: () {
                context.read<AuthService>().signOut();
              },
            ),
          ],
        ),
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
