import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/biri_scaffold.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BiriScaffold(
      title: 'Lista de Desejos',
      body: Center(
        child: Text(
          'Sua lista de desejos aparecerá aqui',
          style: GoogleFonts.poppins(fontSize: 18),
        ),
      ),
    );
  }
}
