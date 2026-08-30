import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/service/api_client.dart';
import '../../domain/provider/challenge_provider.dart';
import '../../domain/provider/user_provider.dart';

enum _Mode { login, signup }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _Mode _mode = _Mode.login;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final userProvider = context.read<UserProvider>();
    try {
      if (_mode == _Mode.login) {
        await userProvider.logIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await userProvider.signUp(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
      if (!mounted) return;
      await context.read<ChallengeProvider>().refresh();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() =>
          _error = 'Não foi possível conectar ao servidor. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == _Mode.login ? _Mode.signup : _Mode.login;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSignup = _mode == _Mode.signup;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 48),
                // Logo
                Column(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.accent, width: 2),
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
                const SizedBox(height: 40),

                if (isSignup) ...[
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Seu nome',
                      hintText: 'Como podemos te chamar?',
                      prefixIcon: Icon(Icons.person_outline,
                          color: AppColors.textSecond),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Insira seu nome'
                        : null,
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _emailController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    hintText: 'voce@exemplo.com',
                    prefixIcon: Icon(Icons.alternate_email,
                        color: AppColors.textSecond),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Insira seu e-mail';
                    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                        .hasMatch(v.trim())) {
                      return 'E-mail inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(
                    labelText: 'Senha',
                    hintText: 'Pelo menos 8 caracteres',
                    prefixIcon:
                        Icon(Icons.lock_outline, color: AppColors.textSecond),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Insira sua senha';
                    if (isSignup && v.length < 8)
                      return 'Mínimo de 8 caracteres';
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDE350B).withAlpha(26),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFFDE350B).withAlpha(102)),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                          color: Color(0xFFFF8B8B), fontSize: 13),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.background),
                        )
                      : Text(isSignup ? 'Criar conta' : 'Entrar'),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 16),

                TextButton(
                  onPressed: _loading ? null : _toggleMode,
                  child: Text(
                    isSignup
                        ? 'Já tenho conta — entrar'
                        : 'Ainda não tenho conta — cadastrar',
                    style: GoogleFonts.poppins(
                      color: AppColors.textSecond,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.textSecond,
                    ),
                  ),
                ).animate().fadeIn(delay: 300.ms),

                const SizedBox(height: 40),
                Text(
                  'Enterprise Challenge FIAP 2026 · Leroy Merlin',
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecond.withAlpha(128),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
