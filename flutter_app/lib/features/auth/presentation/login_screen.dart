import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:agentteam/features/auth/presentation/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  // Light-theme login palette
  static const Color _surfacePrimary = Color(0xFFFFFFFF);
  static const Color _accentPrimary = Color(0xFF2196F3);
  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _inputBorder = Color(0xFFD1D5DB);
  static const Color _placeholder = Color(0xFF9CA3AF);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authStateProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    ref.listen(authStateProvider, (prev, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.error.toString(),
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      if (next.hasValue && next.value != null) {
        context.go('/threads');
      }
    });

    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: _surfacePrimary,
      body: Stack(
        children: [
          // Scrollable centered content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Form(
                key: _formKey,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 60),

                      // --- Branding Section ---
                      Center(
                        child: Column(
                          children: [
                            // Accent bar
                            Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: _accentPrimary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Title
                            Text(
                              'MECCA-COLA',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.anton(
                                fontSize: 36,
                                color: _accentPrimary,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Subtitle
                            Text(
                              'AI Agent Management Platform',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: _textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),

                      // --- Form Section ---
                      // Email label
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'Email',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _textPrimary,
                          ),
                        ),
                      ),
                      // Email input
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !isLoading,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: _textPrimary,
                        ),
                        decoration: _buildInputDecoration(
                          hintText: 'you@example.com',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!value.contains('@')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password label
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'Password',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _textPrimary,
                          ),
                        ),
                      ),
                      // Password input
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        enabled: !isLoading,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: _textPrimary,
                        ),
                        decoration: _buildInputDecoration(
                          hintText: '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
                        ).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: _placeholder,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password is required';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _handleLogin(),
                      ),
                      const SizedBox(height: 8),

                      // Forgot Password
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () {
                            // TODO: Implement forgot password
                          },
                          child: Text(
                            'Forgot Password?',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: _accentPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Log In button
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentPrimary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                _accentPrimary.withValues(alpha: 0.4),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Log In',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // --- Footer ---
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: Text(
                '\u00A9 2026 Mecca-Cola',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: _textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.inter(
        fontSize: 14,
        color: _placeholder,
      ),
      filled: true,
      fillColor: _surfacePrimary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _inputBorder, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _inputBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _accentPrimary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
      ),
      errorStyle: TextStyle(color: Colors.red.shade600, fontSize: 12),
    );
  }
}
