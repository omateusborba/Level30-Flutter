import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../domain/provider/user_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _entrar() {
    if (!_formKey.currentState!.validate()) return;
    context.read<UserProvider>().setName(_nameController.text.trim());
    Navigator.pushReplacementNamed(context, '/home');
  }

  void _explorar() => Navigator.pushReplacementNamed(context, '/home');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const Spacer(flex: 2),
                // Logo
                Column(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surface,
                        border:
                            Border.all(color: AppColors.accent, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          '30',
                          style: GoogleFonts.poppins(
                            color: AppColors.accent,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Level30',
                      style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Smart HAS',
                      style: GoogleFonts.poppins(
                        color: AppColors.accent,
                        fontSize: 13,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.1),
                const Spacer(),
                // Campo nome
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Seu nome',
                    hintText: 'Como podemos te chamar?',
                    prefixIcon: Icon(Icons.person_outline,
                        color: AppColors.textSecond),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Por favor, insira seu nome';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _entrar(),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
                const SizedBox(height: 20),
                // Botão Entrar
                ElevatedButton(
                  onPressed: _entrar,
                  child: const Text('Entrar'),
                ).animate().fadeIn(delay: 300.ms),
                const SizedBox(height: 16),
                // Link explorar
                TextButton(
                  onPressed: _explorar,
                  child: Text(
                    'Explorar sem conta',
                    style: GoogleFonts.poppins(
                      color: AppColors.textSecond,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.textSecond,
                    ),
                  ),
                ).animate().fadeIn(delay: 400.ms),
                const Spacer(),
                Text(
                  'Enterprise Challenge FIAP 2026 · Leroy Merlin',
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecond.withAlpha(128),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
