import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  bool _passwordVisible = false;
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
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      User? user = userCredential.user;

      if (user != null) {
        debugPrint('LoginPage: Successful login for ${user.email}');
        if (_emailController.text.trim() == 'admin@gmail.com') {
          try {
            QuerySnapshot userDocs = await FirebaseFirestore.instance
                .collection('users')
                .where('email', isEqualTo: 'admin@gmail.com')
                .get();

            if (userDocs.docs.isNotEmpty) {
              DocumentSnapshot userDoc = userDocs.docs.first;
              if (userDoc.exists && userDoc['role'] == 'admin') {
                debugPrint('LoginPage: Admin authorized, redirecting to /admin_panel');
                _showSuccess('Вход успешен');
                Navigator.pushNamedAndRemoveUntil(context, '/admin_panel', (route) => false);
              } else {
                debugPrint(
                    'LoginPage: Error: Admin data in Firestore: exists=${userDoc.exists}, role=${userDoc.exists ? userDoc['role'] : 'no data'}');
                _showError('Доступ для админа ограничен');
                await _auth.signOut();
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            } else {
              debugPrint('LoginPage: Error: Document for admin@gmail.com not found in Firestore');
              _showError('Админ не найден в базе данных');
              await _auth.signOut();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            }
          } catch (e) {
            debugPrint('LoginPage: Firestore query error: $e');
            _showError('Ошибка доступа к данным: $e');
            await _auth.signOut();
            Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
          }
        } else {
          debugPrint('LoginPage: Regular user, redirecting to /home');
          _showSuccess('Вход успешен');
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        }
      } else {
        debugPrint('LoginPage: Error: User is null after login');
        _showError('Вход не удался');
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Вход не удался';
      switch (e.code) {
        case 'user-not-found':
          message = 'Пользователь с таким email не найден';
          break;
        case 'wrong-password':
          message = 'Неверный пароль';
          break;
        case 'invalid-email':
          message = 'Недействительный формат email';
          break;
        case 'user-disabled':
          message = 'Учетная запись отключена';
          break;
      }
      debugPrint('LoginPage: Auth error: ${e.code} - ${e.message}');
      _showError(message);
    } catch (e) {
      debugPrint('LoginPage: Unexpected error: $e');
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
  Widget build(context) {
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
                                      autofillHints: const [AutofillHints.password],
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Введите пароль';
                                        }
                                        return null;
                                      },
                                      textInputAction: TextInputAction.done,
                                    ),
                                    const SizedBox(height: 20),
                                    // Login Button
                                    Semantics(
                                      label: 'Войти',
                                      button: true,
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        child: ElevatedButton(
                                          onPressed: _isLoading ? null : _login,
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
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                                            child: const Text(
                                              'Войти',
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
                                    // Register Link
                                    Semantics(
                                      label: 'Перейти к регистрации',
                                      button: true,
                                      child: TextButton(
                                        onPressed: () {
                                          Navigator.pushReplacementNamed(context, '/register');
                                        },
                                        child: const Text(
                                          'Нет аккаунта? Зарегистрироваться',
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