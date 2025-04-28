import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _agreeToTerms = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Fixed colors
  static const Color _primaryColor = Color(0xFFFF6F61);
  static const Color _textColor = Colors.white;
  static const Color _secondaryTextColor = Colors.white70;
  static const Color _fieldFillColor = Color.fromRGBO(255, 255, 255, 0.1);
  static const List<Color> _backgroundColors = [
    Color(0xFF1A1A2E),
    Color(0xFF16213E),
  ];

  // Input decoration factory
  InputDecoration _buildInputDecoration(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _secondaryTextColor),
      filled: true,
      fillColor: _fieldFillColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryColor, width: 2),
      ),
      suffixIcon: suffixIcon,
    );
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      _showError('Пожалуйста, согласитесь с условиями конфиденциальности');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      User? user = userCredential.user;

      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'email': _emailController.text.trim(),
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'role': 'user',
          'created_at': DateTime.now().toIso8601String(),
          'preferred_tests': [],
        });
        debugPrint('RegisterPage: User data saved to Firestore for UID: ${user.uid}');
        _showSuccess('Регистрация успешна');
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Регистрация не удалась';
      switch (e.code) {
        case 'email-already-in-use':
          message = 'Этот email уже используется';
          break;
        case 'weak-password':
          message = 'Пароль слишком слабый';
          break;
        case 'invalid-email':
          message = 'Недействительный формат email';
          break;
        case 'operation-not-allowed':
          message = 'Регистрация отключена';
          break;
      }
      debugPrint('RegisterPage: Auth error: ${e.code} - ${e.message}');
      _showError(message);
    } on FirebaseException catch (e) {
      debugPrint('RegisterPage: Firestore error: ${e.code} - ${e.message}');
      _showError('Ошибка сохранения данных: ${e.message}');
    } catch (e) {
      debugPrint('RegisterPage: Unexpected error: $e');
      _showError('Произошла неизвестная ошибка');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: _textColor)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: _textColor)),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return WillPopScope(
      onWillPop: () async {
        SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _backgroundColors,
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Logo or App Name
                          Center(
                            child: ScaleTransition(
                              scale: _scaleAnimation,
                              child: FadeTransition(
                                opacity: _fadeAnimation,
                                child: Text(
                                  'AiATesTing',
                                  style: GoogleFonts.orbitron(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: _textColor,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Form Card
                          Card(
                            color: _fieldFillColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Email
                                    TextFormField(
                                      controller: _emailController,
                                      style: const TextStyle(color: _textColor),
                                      decoration: _buildInputDecoration('Email'),
                                      keyboardType: TextInputType.emailAddress,
                                      autofillHints: const [AutofillHints.email],
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Введите email';
                                        }
                                        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                        if (!emailRegex.hasMatch(value)) {
                                          return 'Введите действительный email';
                                        }
                                        return null;
                                      },
                                      textInputAction: TextInputAction.next,
                                    ),
                                    const SizedBox(height: 16),
                                    // First Name
                                    TextFormField(
                                      controller: _firstNameController,
                                      style: const TextStyle(color: _textColor),
                                      decoration: _buildInputDecoration('Имя'),
                                      textCapitalization: TextCapitalization.words,
                                      autofillHints: const [AutofillHints.givenName],
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Введите ваше имя';
                                        }
                                        if (value.length < 2) {
                                          return 'Имя должно содержать минимум 2 символа';
                                        }
                                        return null;
                                      },
                                      textInputAction: TextInputAction.next,
                                    ),
                                    const SizedBox(height: 16),
                                    // Last Name
                                    TextFormField(
                                      controller: _lastNameController,
                                      style: const TextStyle(color: _textColor),
                                      decoration: _buildInputDecoration('Фамилия'),
                                      textCapitalization: TextCapitalization.words,
                                      autofillHints: const [AutofillHints.familyName],
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Введите вашу фамилию';
                                        }
                                        if (value.length < 2) {
                                          return 'Фамилия должна содержать минимум 2 символа';
                                        }
                                        return null;
                                      },
                                      textInputAction: TextInputAction.next,
                                    ),
                                    const SizedBox(height: 16),
                                    // Password
                                    TextFormField(
                                      controller: _passwordController,
                                      style: const TextStyle(color: _textColor),
                                      decoration: _buildInputDecoration(
                                        'Пароль',
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _passwordVisible ? Icons.visibility : Icons.visibility_off,
                                            color: _secondaryTextColor,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _passwordVisible = !_passwordVisible;
                                            });
                                          },
                                        ),
                                      ),
                                      obscureText: !_passwordVisible,
                                      autofillHints: const [AutofillHints.newPassword],
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Введите пароль';
                                        }
                                        if (value.length < 6) {
                                          return 'Пароль должен содержать минимум 6 символов';
                                        }
                                        return null;
                                      },
                                      onChanged: (value) {
                                        if (_confirmPasswordController.text.isNotEmpty) {
                                          _formKey.currentState?.validate();
                                        }
                                      },
                                      textInputAction: TextInputAction.next,
                                    ),
                                    const SizedBox(height: 16),
                                    // Confirm Password
                                    TextFormField(
                                      controller: _confirmPasswordController,
                                      style: const TextStyle(color: _textColor),
                                      decoration: _buildInputDecoration(
                                        'Подтвердите пароль',
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _confirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                            color: _secondaryTextColor,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _confirmPasswordVisible = !_confirmPasswordVisible;
                                            });
                                          },
                                        ),
                                      ),
                                      obscureText: !_confirmPasswordVisible,
                                      autofillHints: const [AutofillHints.newPassword],
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Подтвердите пароль';
                                        }
                                        if (value != _passwordController.text) {
                                          return 'Пароли не совпадают';
                                        }
                                        return null;
                                      },
                                      textInputAction: TextInputAction.done,
                                    ),
                                    const SizedBox(height: 16),
                                    // Privacy Policy
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: _agreeToTerms,
                                          onChanged: (value) {
                                            setState(() {
                                              _agreeToTerms = value ?? false;
                                            });
                                          },
                                          activeColor: _primaryColor,
                                        ),
                                        Expanded(
                                          child: RichText(
                                            text: TextSpan(
                                              text: 'Я согласен с ',
                                              style: const TextStyle(color: _textColor, fontSize: 14),
                                              children: [
                                                TextSpan(
                                                  text: 'условиями конфиденциальности',
                                                  style: TextStyle(
                                                    color: _primaryColor,
                                                    fontSize: 14,
                                                    decoration: TextDecoration.underline,
                                                  ),
                                                  recognizer: TapGestureRecognizer()
                                                    ..onTap = () {
                                                      showDialog(
                                                        context: context,
                                                        builder: (context) => AlertDialog(
                                                          backgroundColor: _fieldFillColor,
                                                          title: Text(
                                                            'Политика конфиденциальности',
                                                            style: TextStyle(color: _textColor),
                                                          ),
                                                          content: Text(
                                                            'Здесь будет текст политики конфиденциальности вашего приложения.',
                                                            style: TextStyle(color: _secondaryTextColor),
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () => Navigator.pop(context),
                                                              child: Text(
                                                                'Закрыть',
                                                                style: TextStyle(color: _primaryColor),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    // Register Button
                                    Semantics(
                                      label: 'Зарегистрироваться',
                                      button: true,
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        child: ElevatedButton(
                                          onPressed: _isLoading ? null : _register,
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [_primaryColor, Color(0xFFDE4B7C)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                                            child: const Text(
                                              'Зарегистрироваться',
                                              style: TextStyle(
                                                color: _textColor,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // Login Link
                                    Semantics(
                                      label: 'Перейти к входу',
                                      button: true,
                                      child: TextButton(
                                        onPressed: () {
                                          Navigator.pushReplacementNamed(context, '/login');
                                        },
                                        child: const Text(
                                          'Уже есть аккаунт? Войти',
                                          style: TextStyle(
                                            color: _primaryColor,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Loading Overlay
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}