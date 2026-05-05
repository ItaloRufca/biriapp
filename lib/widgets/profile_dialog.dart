import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

class ProfileDialog extends StatefulWidget {
  final bool isMandatory;
  const ProfileDialog({super.key, this.isMandatory = false});

  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  late TextEditingController _usernameController;
  late TextEditingController _avatarUrlController;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    _usernameController = TextEditingController(
      text: user?.userMetadata?['username'] as String? ?? '',
    );
    _avatarUrlController = TextEditingController(
      text: user?.userMetadata?['avatar_url'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() => _errorMessage = 'Nome de usuário é obrigatório');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await context.read<AuthService>().updateProfile(
        username: username,
        avatarUrl: _avatarUrlController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context); // Close dialog on success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil atualizado com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Erro ao atualizar perfil: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final userEmail = user?.email ?? 'Usuário';
    final userAvatarUrl = user?.userMetadata?['avatar_url'] as String?;
    final username = user?.userMetadata?['username'] as String?;
    final displayName = username != null && username.isNotEmpty
        ? username
        : userEmail;

    return PopScope(
      canPop: !widget.isMandatory,
      child: Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isMandatory)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      'Complete seu perfil para continuar',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFE94560),
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                // Avatar
                CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFFE94560),
                  backgroundImage:
                      userAvatarUrl != null && userAvatarUrl.isNotEmpty
                      ? NetworkImage(userAvatarUrl)
                      : null,
                  child: (userAvatarUrl == null || userAvatarUrl.isEmpty)
                      ? Text(
                          displayName.substring(0, 1).toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 32,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  userEmail,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                // Username Field
                TextField(
                  controller: _usernameController,
                  style: GoogleFonts.poppins(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Nome de Usuário *',
                    labelStyle: GoogleFonts.poppins(color: Colors.white70),
                    errorText: _errorMessage,
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white24),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE94560)),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.red),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Avatar URL Field
                TextField(
                  controller: _avatarUrlController,
                  style: GoogleFonts.poppins(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'URL da Foto de Perfil (Opcional)',
                    labelStyle: GoogleFonts.poppins(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white24),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE94560)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!widget.isMandatory) ...[
                      TextButton(
                        onPressed: () {
                          context.read<AuthService>().signOut();
                          Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst);
                        },
                        child: Text(
                          'Sair',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFE94560),
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancelar',
                          style: GoogleFonts.poppins(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    ElevatedButton(
                      onPressed: _isLoading ? null : _updateProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE94560),
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text('Salvar', style: GoogleFonts.poppins()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
