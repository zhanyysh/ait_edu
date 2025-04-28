import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'custom_animated_button.dart';

class SettingsPage extends StatefulWidget {
  final Function(String) onThemeChanged;
  final String currentTheme;

  const SettingsPage({super.key, required this.onThemeChanged, required this.currentTheme});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  bool _isLoading = true;
  bool _isEditing = false;
  String? _errorMessage;
  String? _email;
  String? _firstName;
  String? _lastName;
  bool _isEmailVerified = false;
  bool _verificationEmailSent = false;
  Timer? _verificationTimer;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Color schemes for light and dark themes
  List<Color> get _backgroundColors {
    if (widget.currentTheme == 'light') {
      return [Colors.white, const Color(0xFFF5E6FF)];
    } else {
      return [const Color(0xFF1A1A2E), const Color(0xFF16213E)];
    }
  }

  Color get _textColor => widget.currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white;
  Color get _secondaryTextColor => widget.currentTheme == 'light' ? Colors.grey[600]! : Colors.white70;
  Color get _cardColor => widget.currentTheme == 'light' ? Colors.white : Colors.white.withOpacity(0.05);
  Color get _borderColor => widget.currentTheme == 'light' ? Colors.grey[200]! : Colors.transparent;
  Color get _fieldFillColor => widget.currentTheme == 'light' ? Colors.grey[100]! : Colors.white.withOpacity(0.08);
  static const List<Color> _buttonGradientColors = [
    Color(0xFFFF6F61),
    Color(0xFFDE4B7C),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _loadUserData();
    _startVerificationCheck();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _verificationTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await user.reload();
        _isEmailVerified = user.emailVerified;

        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          setState(() {
            _email = userDoc['email'] as String? ?? 'Не указано';
            _firstName = userDoc['first_name'] as String? ?? 'Не указано';
            _lastName = userDoc['last_name'] as String? ?? 'Не указано';
            _emailController.text = _email!;
            _firstNameController.text = _firstName!;
            _lastNameController.text = _lastName!;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Данные пользователя не найдены';
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Ошибка загрузки данных: $e';
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _errorMessage = 'Пользователь не авторизован';
        _isLoading = false;
      });
    }
  }

  void _startVerificationCheck() {
    _verificationTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!_isEmailVerified) {
        final user = _auth.currentUser;
        if (user != null) {
          try {
            await user.reload();
            bool newVerificationStatus = user.emailVerified;
            if (newVerificationStatus != _isEmailVerified) {
              setState(() {
                _isEmailVerified = newVerificationStatus;
              });
              if (_isEmailVerified) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Email успешно верифицирован!', style: TextStyle(color: _textColor)),
                    backgroundColor: Colors.green,
                  ),
                );
                timer.cancel();
              }
            }
          } catch (e) {
            // Ignore errors
          }
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await user.sendEmailVerification();
        setState(() {
          _verificationEmailSent = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Письмо для верификации email отправлено. Пожалуйста, проверьте ваш email.',
              style: TextStyle(color: _textColor),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка отправки письма: $e', style: TextStyle(color: _textColor)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Пользователь не авторизован', style: TextStyle(color: _textColor)), backgroundColor: Colors.red),
      );
      return;
    }

    if (_emailController.text.trim().isEmpty ||
        _firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Заполните все поля', style: TextStyle(color: _textColor)), backgroundColor: Colors.red),
      );
      return;
    }

    if (!_emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Введите действительный email', style: TextStyle(color: _textColor)), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      if (_emailController.text.trim() != user.email) {
        try {
          await user.updateEmail(_emailController.text.trim());
        } on FirebaseAuthException catch (e) {
          if (e.code == 'requires-recent-login') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Для изменения email требуется повторный вход. Пожалуйста, выйдите и войдите снова.',
                  style: TextStyle(color: _textColor),
                ),
                backgroundColor: Colors.red,
              ),
            );
            return;
          } else if (e.code == 'email-already-in-use') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Этот email уже используется другим пользователем.', style: TextStyle(color: _textColor)),
                backgroundColor: Colors.red,
              ),
            );
            return;
          } else if (e.code == 'operation-not-allowed') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Изменение email не разрешено. Проверьте настройки Firebase Authentication.',
                  style: TextStyle(color: _textColor),
                ),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
          throw e;
        }
      }

      await _firestore.collection('users').doc(user.uid).update({
        'email': _emailController.text.trim(),
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
      });

      setState(() {
        _email = _emailController.text.trim();
        _firstName = _firstNameController.text.trim();
        _lastName = _lastNameController.text.trim();
        _isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Данные обновлены', style: TextStyle(color: _textColor)), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка обновления: $e', style: TextStyle(color: _textColor)), backgroundColor: Colors.red),
      );
    }
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _emailController.text = _email ?? 'Не указано';
      _firstNameController.text = _firstName ?? 'Не указано';
      _lastNameController.text = _lastName ?? 'Не указано';
    });
  }

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка выхода: $e', style: TextStyle(color: _textColor)), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _backgroundColors,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              'Настройки',
              style: GoogleFonts.orbitron(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: _textColor,
                letterSpacing: 1.2,
              ),
            ),
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _backgroundColors,
                ),
              ),
            ),
            elevation: 0,
            centerTitle: true,
          ),
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: _textColor))
                  : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red, fontSize: 16),
                        ),
                      ),
                    Card(
                      color: _cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: BorderSide(color: _borderColor, width: 1),
                      ),
                      elevation: widget.currentTheme == 'light' ? 4 : 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  color: Color(0xFFFF6F61),
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Профиль пользователя',
                                  style: GoogleFonts.orbitron(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _textColor,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Divider(color: _borderColor),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.email, color: _secondaryTextColor, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Email',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _textColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _isEditing
                                ? TextField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                hintText: 'Введите email',
                                hintStyle: TextStyle(color: _secondaryTextColor),
                                filled: true,
                                fillColor: _fieldFillColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(color: Colors.transparent),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFFF6F61),
                                    width: 2,
                                  ),
                                ),
                              ),
                              style: TextStyle(color: _textColor),
                            )
                                : Text(
                              _email ?? 'Не указано',
                              style: TextStyle(fontSize: 16, color: _secondaryTextColor),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.person_outline, color: _secondaryTextColor, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Имя',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _textColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _isEditing
                                ? TextField(
                              controller: _firstNameController,
                              decoration: InputDecoration(
                                hintText: 'Введите имя',
                                hintStyle: TextStyle(color: _secondaryTextColor),
                                filled: true,
                                fillColor: _fieldFillColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(color: Colors.transparent),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFFF6F61),
                                    width: 2,
                                  ),
                                ),
                              ),
                              style: TextStyle(color: _textColor),
                            )
                                : Text(
                              _firstName ?? 'Не указано',
                              style: TextStyle(fontSize: 16, color: _secondaryTextColor),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.person_outline, color: _secondaryTextColor, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Фамилия',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _textColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _isEditing
                                ? TextField(
                              controller: _lastNameController,
                              decoration: InputDecoration(
                                hintText: 'Введите фамилию',
                                hintStyle: TextStyle(color: _secondaryTextColor),
                                filled: true,
                                fillColor: _fieldFillColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(color: Colors.transparent),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFFF6F61),
                                    width: 2,
                                  ),
                                ),
                              ),
                              style: TextStyle(color: _textColor),
                            )
                                : Text(
                              _lastName ?? 'Не указано',
                              style: TextStyle(fontSize: 16, color: _secondaryTextColor),
                            ),
                            const SizedBox(height: 16),
                            Divider(color: _borderColor),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(
                                  _isEmailVerified ? Icons.verified : Icons.warning,
                                  color: _isEmailVerified ? Colors.green : Colors.red,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isEmailVerified ? 'Email верифицирован' : 'Email не верифицирован',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _isEmailVerified ? Colors.green : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            if (!_isEmailVerified) ...[
                              const SizedBox(height: 12),
                              CustomAnimatedButton(
                                onPressed: _sendVerificationEmail,
                                gradientColors: _buttonGradientColors,
                                label: _verificationEmailSent
                                    ? 'Отправить письмо повторно'
                                    : 'Отправить письмо для верификации',
                                currentTheme: widget.currentTheme,
                                isHeader: false,
                              ),
                            ],
                            const SizedBox(height: 20),
                            Divider(color: _borderColor),
                            const SizedBox(height: 20),
                            if (_isEditing) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: CustomAnimatedButton(
                                      onPressed: _updateUserData,
                                      gradientColors: _buttonGradientColors,
                                      label: 'Сохранить',
                                      currentTheme: widget.currentTheme,
                                      isHeader: false,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: CustomAnimatedButton(
                                      onPressed: _cancelEditing,
                                      gradientColors: _buttonGradientColors,
                                      label: 'Отмена',
                                      currentTheme: widget.currentTheme,
                                      isHeader: false,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ] else ...[
                              CustomAnimatedButton(
                                onPressed: () {
                                  setState(() {
                                    _isEditing = true;
                                  });
                                },
                                gradientColors: _buttonGradientColors,
                                label: 'Редактировать профиль',
                                currentTheme: widget.currentTheme,
                                isHeader: false,
                              ),
                              const SizedBox(height: 12),
                            ],
                            CustomAnimatedButton(
                              onPressed: _logout,
                              gradientColors: [
                                Colors.red,
                                Colors.redAccent,
                              ],
                              label: 'Выйти',
                              currentTheme: widget.currentTheme,
                              isHeader: false,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ));
  }
}