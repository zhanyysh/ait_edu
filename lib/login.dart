import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Для динамического изменения фона
  List<Color> _backgroundColors = [
    const Color(0xFF1A1A2E),
    const Color(0xFF16213E),
  ];

  void _onFocusChange(String field) {
    setState(() {
      switch (field) {
        case 'email':
          _backgroundColors = [
            const Color(0xFF1A1A2E),
            const Color(0xFF3E2A5E), // Лёгкий фиолетовый оттенок
          ];
          break;
        case 'password':
          _backgroundColors = [
            const Color(0xFF1A1A2E),
            const Color(0xFF5E3E2A), // Лёгкий оранжевый оттенок
          ];
          break;
        default:
          _backgroundColors = [
            const Color(0xFF1A1A2E),
            const Color(0xFF16213E),
          ];
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
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
        debugPrint('LoginPage: Успешный вход для ${user.email}');
        if (_emailController.text.trim() == 'admin@gmail.com') {
          try {
            QuerySnapshot userDocs = await FirebaseFirestore.instance
                .collection('users')
                .where('email', isEqualTo: 'admin@gmail.com')
                .get();
            
            if (userDocs.docs.isNotEmpty) {
              DocumentSnapshot userDoc = userDocs.docs.first;
              if (userDoc.exists && userDoc['role'] == 'admin') {
                debugPrint('LoginPage: Админ авторизован, перенаправление на /admin_panel');
                Navigator.pushNamedAndRemoveUntil(context, '/admin_panel', (route) => false);
              } else {
                debugPrint('LoginPage: Ошибка: Данные админа в Firestore: exists=${userDoc.exists}, role=${userDoc.exists ? userDoc['role'] : 'нет данных'}');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Доступ для админа ограничен')),
                );
                await _auth.signOut();
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            } else {
              debugPrint('LoginPage: Ошибка: Документ для admin@gmail.com не найден в Firestore');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Админ не найден в базе данных')),
              );
              await _auth.signOut();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            }
          } catch (e) {
            debugPrint('LoginPage: Ошибка при запросе к Firestore: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ошибка доступа к данным: $e')),
            );
            await _auth.signOut();
            Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
          }
        } else {
          debugPrint('LoginPage: Обычный пользователь, перенаправление на /home');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Вход успешен')),
          );
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        }
      } else {
        debugPrint('LoginPage: Ошибка: Пользователь null после входа');
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Вход не удался';
      if (e.code == 'user-not-found') {
        message = 'Пользователь с таким email не найден.';
      } else if (e.code == 'wrong-password') {
        message = 'Неверный пароль.';
      }
      debugPrint('LoginPage: Ошибка авторизации: ${e.code} - ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Вход',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _backgroundColors,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextFormField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
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
                        borderSide: const BorderSide(color: Color(0xFFFF6F61), width: 2),
                      ),
                    ),
                    onTap: () => _onFocusChange('email'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Введите email';
                      }
                      if (!value.contains('@')) {
                        return 'Введите действительный email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Пароль',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
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
                        borderSide: const BorderSide(color: Color(0xFFFF6F61), width: 2),
                      ),
                    ),
                    onTap: () => _onFocusChange('password'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Введите пароль';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _isLoading
                      ? Container(
                          padding: const EdgeInsets.all(10),
                          child: const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6F61)),
                          ),
                        )
                      : AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          child: ElevatedButton(
                            onPressed: _login,
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
                                  colors: [
                                    Color(0xFFFF6F61),
                                    Color(0xFFDE4B7C),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                              child: const Text(
                                'Войти',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                  const SizedBox(height: 10),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/register');
                      },
                      child: const Text(
                        'Нет аккаунта? Зарегистрироваться',
                        style: TextStyle(
                          color: Color(0xFFFF6F61),
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
      ),
    );
  }
}