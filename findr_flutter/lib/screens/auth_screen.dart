import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/design_system.dart';

TextStyle _outfit({
  double fontSize = 14,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
  double? letterSpacing,
  double? height,
}) {
  return GoogleFonts.outfit(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  ).copyWith(shadows: const <Shadow>[]);
}

enum _AuthMode { signIn, signUp, forgotPassword }

/// Full auth screen: email/password sign-in, sign-up, forgot password, Google.
class AuthScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onSuccess;

  const AuthScreen({super.key, this.onBack, this.onSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  _AuthMode _mode = _AuthMode.signIn;
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _switchMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _error = null;
      _success = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    String? err;

    switch (_mode) {
      case _AuthMode.signIn:
        err = await auth.signInWithEmail(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
        break;

      case _AuthMode.signUp:
        err = await auth.signUpWithEmail(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          displayName: _nameCtrl.text.trim().isEmpty
              ? null
              : _nameCtrl.text.trim(),
        );
        break;

      case _AuthMode.forgotPassword:
        err = await auth.sendPasswordReset(_emailCtrl.text.trim());
        if (err == null && mounted) {
          setState(() {
            _success = 'Password reset email sent! Check your inbox.';
            _loading = false;
          });
          return;
        }
        break;
    }

    if (!mounted) return;

    if (err != null) {
      setState(() {
        _error = err;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
      widget.onSuccess?.call();
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ok = await auth.signInWithGoogle();
    if (!mounted) return;
    if (ok) {
      widget.onSuccess?.call();
    } else {
      setState(() {
        _error = 'Google sign-in was cancelled or failed.';
        _loading = false;
      });
    }
  }

  Future<void> _continueAsGuest() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.signInAnonymously();
    if (mounted) widget.onSuccess?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 500;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 24 : 40,
              vertical: 32,
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Back button
                  if (widget.onBack != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: widget.onBack,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: SupplyMapColors.borderSubtle),
                          ),
                          child:
                              const Icon(Icons.arrow_back, size: 18),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Logo
                  Text(
                    'Waymark',
                    style: _outfit(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -2,
                      color: SupplyMapColors.textBlack,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _mode == _AuthMode.signIn
                        ? 'Welcome back'
                        : _mode == _AuthMode.signUp
                            ? 'Create your account'
                            : 'Reset your password',
                    style: _outfit(
                      fontSize: 16,
                      color: SupplyMapColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Form card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(kRadiusLg),
                      border: Border.all(
                          color: SupplyMapColors.borderSubtle),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A1A1918),
                          blurRadius: 24,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          // Error / success messages
                          if (_error != null)
                            _MessageBanner(
                                message: _error!, isError: true),
                          if (_success != null)
                            _MessageBanner(
                                message: _success!, isError: false),

                          // Name field (sign-up only)
                          if (_mode == _AuthMode.signUp) ...[
                            _InputField(
                              controller: _nameCtrl,
                              label: 'Display name',
                              hint: 'Your name (optional)',
                              icon: Icons.person_outline,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Email field
                          _InputField(
                            controller: _emailCtrl,
                            label: 'Email',
                            hint: 'you@example.com',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction:
                                _mode == _AuthMode.forgotPassword
                                    ? TextInputAction.done
                                    : TextInputAction.next,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Enter your email';
                              }
                              if (!v.contains('@') ||
                                  !v.contains('.')) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),

                          // Password fields (not for forgot password)
                          if (_mode != _AuthMode.forgotPassword) ...[
                            const SizedBox(height: 14),
                            _InputField(
                              controller: _passwordCtrl,
                              label: 'Password',
                              hint: 'At least 6 characters',
                              icon: Icons.lock_outline,
                              obscure: _obscurePassword,
                              suffixIcon: GestureDetector(
                                onTap: () => setState(() =>
                                    _obscurePassword =
                                        !_obscurePassword),
                                child: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 18,
                                  color:
                                      SupplyMapColors.textTertiary,
                                ),
                              ),
                              textInputAction:
                                  _mode == _AuthMode.signIn
                                      ? TextInputAction.done
                                      : TextInputAction.next,
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Enter your password';
                                }
                                if (_mode == _AuthMode.signUp &&
                                    v.length < 6) {
                                  return 'At least 6 characters';
                                }
                                return null;
                              },
                              onSubmitted: _mode == _AuthMode.signIn
                                  ? (_) => _submit()
                                  : null,
                            ),
                          ],

                          // Confirm password (sign-up only)
                          if (_mode == _AuthMode.signUp) ...[
                            const SizedBox(height: 14),
                            _InputField(
                              controller: _confirmCtrl,
                              label: 'Confirm password',
                              hint: 'Re-enter your password',
                              icon: Icons.lock_outline,
                              obscure: _obscureConfirm,
                              suffixIcon: GestureDetector(
                                onTap: () => setState(() =>
                                    _obscureConfirm =
                                        !_obscureConfirm),
                                child: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 18,
                                  color:
                                      SupplyMapColors.textTertiary,
                                ),
                              ),
                              textInputAction: TextInputAction.done,
                              validator: (v) {
                                if (v != _passwordCtrl.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                              onSubmitted: (_) => _submit(),
                            ),
                          ],

                          // Forgot password link (sign-in mode)
                          if (_mode == _AuthMode.signIn) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () => _switchMode(
                                    _AuthMode.forgotPassword),
                                child: Text(
                                  'Forgot password?',
                                  style: _outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        SupplyMapColors.accentGreen,
                                  ),
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Submit button
                          GestureDetector(
                            onTap: _loading ? null : _submit,
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: _loading
                                    ? SupplyMapColors.borderStrong
                                    : SupplyMapColors.accentGreen,
                                borderRadius:
                                    BorderRadius.circular(kRadiusMd),
                              ),
                              child: Center(
                                child: _loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        _mode == _AuthMode.signIn
                                            ? 'Sign In'
                                            : _mode ==
                                                    _AuthMode.signUp
                                                ? 'Create Account'
                                                : 'Send Reset Link',
                                        style: _outfit(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ),

                          // Divider + Google (not for forgot password)
                          if (_mode != _AuthMode.forgotPassword) ...[
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                const Expanded(
                                    child: Divider(
                                        color: SupplyMapColors
                                            .borderSubtle)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Text(
                                    'or',
                                    style: _outfit(
                                      fontSize: 12,
                                      color: SupplyMapColors
                                          .textTertiary,
                                    ),
                                  ),
                                ),
                                const Expanded(
                                    child: Divider(
                                        color: SupplyMapColors
                                            .borderSubtle)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Google button
                            GestureDetector(
                              onTap:
                                  _loading ? null : _signInWithGoogle,
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(kRadiusMd),
                                  border: Border.all(
                                      color: SupplyMapColors
                                          .borderSubtle),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    // Google "G" icon
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(3),
                                      ),
                                      child: const Icon(
                                        Icons.g_mobiledata,
                                        size: 24,
                                        color: Color(0xFF4285F4),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Continue with Google',
                                      style: _outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: SupplyMapColors
                                            .textBlack,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Mode toggle
                  if (_mode == _AuthMode.signIn) ...[
                    _TextLink(
                      text: "Don't have an account? ",
                      linkText: 'Sign up',
                      onTap: () =>
                          _switchMode(_AuthMode.signUp),
                    ),
                  ] else if (_mode == _AuthMode.signUp) ...[
                    _TextLink(
                      text: 'Already have an account? ',
                      linkText: 'Sign in',
                      onTap: () =>
                          _switchMode(_AuthMode.signIn),
                    ),
                  ] else ...[
                    _TextLink(
                      text: 'Remember your password? ',
                      linkText: 'Sign in',
                      onTap: () =>
                          _switchMode(_AuthMode.signIn),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Continue as guest
                  GestureDetector(
                    onTap: _loading ? null : _continueAsGuest,
                    child: Text(
                      'Continue as guest',
                      style: _outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: SupplyMapColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: _outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: SupplyMapColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          validator: validator,
          style: _outfit(fontSize: 14, color: SupplyMapColors.textBlack),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                _outfit(fontSize: 14, color: SupplyMapColors.textTertiary),
            prefixIcon: Icon(icon,
                size: 18, color: SupplyMapColors.textTertiary),
            suffixIcon: suffixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: suffixIcon,
                  )
                : null,
            suffixIconConstraints:
                const BoxConstraints(minWidth: 36, minHeight: 36),
            filled: true,
            fillColor: SupplyMapColors.bodyBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kRadiusMd),
              borderSide:
                  const BorderSide(color: SupplyMapColors.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kRadiusMd),
              borderSide:
                  const BorderSide(color: SupplyMapColors.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kRadiusMd),
              borderSide: const BorderSide(
                  color: SupplyMapColors.accentGreen, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kRadiusMd),
              borderSide: const BorderSide(color: SupplyMapColors.red),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.isError});
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isError
              ? SupplyMapColors.red.withValues(alpha: 0.08)
              : SupplyMapColors.accentGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(kRadiusSm),
          border: Border.all(
            color: isError
                ? SupplyMapColors.red.withValues(alpha: 0.3)
                : SupplyMapColors.accentGreen.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              size: 18,
              color:
                  isError ? SupplyMapColors.red : SupplyMapColors.accentGreen,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: _outfit(
                  fontSize: 13,
                  color: isError
                      ? SupplyMapColors.red
                      : SupplyMapColors.accentGreen,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextLink extends StatelessWidget {
  const _TextLink({
    required this.text,
    required this.linkText,
    required this.onTap,
  });
  final String text, linkText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(text,
            style:
                _outfit(fontSize: 13, color: SupplyMapColors.textSecondary)),
        GestureDetector(
          onTap: onTap,
          child: Text(
            linkText,
            style: _outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: SupplyMapColors.accentGreen,
            ),
          ),
        ),
      ],
    );
  }
}
