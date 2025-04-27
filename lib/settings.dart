import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  final Function(String) onThemeChanged;

  const SettingsPage({super.key, required this.onThemeChanged});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  String _currentTheme = 'light';
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

  // Цветовые схемы для светлой и тёмной темы
  List<Color> get _backgroundColors {
    if (_currentTheme == 'light') {
      return [
        Colors.white,
        const Color(0xFFF5E6FF), // Легкий фиолетовый оттенок для градиента
      ];
    } else {
      return [
        const Color(0xFF1A0033), // Глубокий темный фон
        const Color(0xFF2E004F),
      ];
    }
  }

  Color get _textColor => _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white;
  Color get _secondaryTextColor => _currentTheme == 'light' ? Colors.grey[600]! : Colors.white70;
  Color get _cardColor => _currentTheme == 'light' ? Colors.white : Colors.white.withOpacity(0.05);
  Color get _borderColor => _currentTheme == 'light' ? Colors.grey[200]! : Colors.transparent;
  Color get _fieldFillColor => _currentTheme == 'light' ? Colors.grey[100]! : Colors.white.withOpacity(0.08);

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
    _loadTheme();
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

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentTheme = prefs.getString('theme') ?? 'light';
    });
  }

  void _toggleTheme() {
    String newTheme = _currentTheme == 'light' ? 'dark' : 'light';
    setState(() {
      _currentTheme = newTheme;
    });
    widget.onThemeChanged(newTheme);
    _animationController.reset();
    _animationController.forward();
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
                    content: Text(
                      'Email успешно верифицирован!',
                      style: TextStyle(color: _textColor),
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
                timer.cancel();
              }
            }
          } catch (e) {
            // Игнорируем ошибки
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
            content: Text(
              'Ошибка отправки письма: $e',
              style: TextStyle(color: _textColor),
            ),
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
        SnackBar(
          content: Text(
            'Пользователь не авторизован',
            style: TextStyle(color: _textColor),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_emailController.text.trim().isEmpty ||
        _firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Заполните все поля',
            style: TextStyle(color: _textColor),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Введите действительный email',
            style: TextStyle(color: _textColor),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await user.reload();
    setState(() {
      _isEmailVerified = user.emailVerified;
    });

    if (!_isEmailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Пожалуйста, подтвердите ваш email перед изменением данных.',
            style: TextStyle(color: _textColor),
          ),
          backgroundColor: Colors.red,
        ),
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
                content: Text(
                  'Этот email уже используется другим пользователем.',
                  style: TextStyle(color: _textColor),
                ),
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
        SnackBar(
          content: Text(
            'Данные обновлены',
            style: TextStyle(color: _textColor),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ошибка обновления: $e',
            style: TextStyle(color: _textColor),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            _currentTheme == 'light' ? const Color(0xFFFF6F61) : const Color(0xFFE6F0FA),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: TextStyle(color: _textColor, fontSize: 16),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _backgroundColors,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Настройки',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                      _buildAnimatedButton(
                        onPressed: _toggleTheme,
                        gradientColors: _currentTheme == 'light'
                            ? [const Color(0xFFFF6F61), const Color(0xFFFFB74D)]
                            : [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)],
                        label: _currentTheme == 'light' ? 'Светлая' : 'Тёмная',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (!_isEditing) ...[
                    _buildProfileCard(),
                    const SizedBox(height: 20),
                    Center(
                      child: Column(
                        children: [
                          if (!_isEmailVerified) ...[
                            _buildAnimatedButton(
                              onPressed: _verificationEmailSent ? null : _sendVerificationEmail,
                              gradientColors: _verificationEmailSent
                                  ? [Colors.grey, Colors.grey]
                                  : _currentTheme == 'light'
                                      ? [const Color(0xFFFF8C00), const Color(0xFFFFB74D)]
                                      : [const Color(0xFFDE4B7C), const Color(0xFFFF6F61)],
                              label: _verificationEmailSent ? 'Письмо отправлено' : 'Подтвердить почту',
                            ),
                            const SizedBox(height: 16),
                          ],
                          _buildAnimatedButton(
                            onPressed: () {
                              setState(() {
                                _isEditing = true;
                              });
                            },
                            gradientColors: _currentTheme == 'light'
                                ? [const Color(0xFF4A90E2), const Color(0xFF50C9C3)]
                                : [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)],
                            label: 'Редактировать профиль',
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    _buildEditProfileCard(),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildAnimatedButton(
                          onPressed: _updateUserData,
                          gradientColors: _currentTheme == 'light'
                              ? [const Color(0xFF4A90E2), const Color(0xFF50C9C3)]
                              : [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)],
                          label: 'Сохранить',
                        ),
                        const SizedBox(width: 16),
                        _buildAnimatedButton(
                          onPressed: () {
                            setState(() {
                              _isEditing = false;
                              _emailController.text = _email!;
                              _firstNameController.text = _firstName!;
                              _lastNameController.text = _lastName!;
                            });
                          },
                          gradientColors: [Colors.grey, Colors.grey],
                          label: 'Отмена',
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  Center(
                    child: _buildAnimatedButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                      },
                      gradientColors: [Colors.red, Colors.redAccent],
                      label: 'Выйти',
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

  Widget _buildAnimatedButton({
    required VoidCallback? onPressed,
    required List<Color> gradientColors,
    required String label,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 200),
          scale: onPressed != null ? 1.0 : 0.95,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: _currentTheme == 'light' && onPressed != null
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : [],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      color: _cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: _borderColor, width: 1),
      ),
      elevation: _currentTheme == 'light' ? 8 : 0,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.email_outlined, color: _secondaryTextColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Email',
                  style: TextStyle(fontSize: 14, color: _secondaryTextColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  _email!,
                  style: TextStyle(fontSize: 16, color: _textColor, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                Text(
                  _isEmailVerified ? '(верифицирован)' : '(не верифицирован)',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isEmailVerified ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.person_outline, color: _secondaryTextColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Имя',
                  style: TextStyle(fontSize: 14, color: _secondaryTextColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _firstName!,
              style: TextStyle(fontSize: 16, color: _textColor, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.person_outline, color: _secondaryTextColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Фамилия',
                  style: TextStyle(fontSize: 14, color: _secondaryTextColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _lastName!,
              style: TextStyle(fontSize: 16, color: _textColor, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditProfileCard() {
    return Card(
      color: _cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: _borderColor, width: 1),
      ),
      elevation: _currentTheme == 'light' ? 8 : 0,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              style: TextStyle(color: _textColor),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.email_outlined, color: _secondaryTextColor),
                labelText: 'Email',
                labelStyle: TextStyle(color: _secondaryTextColor),
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
                  borderSide: BorderSide(
                    color: _currentTheme == 'light'
                        ? const Color(0xFFFF6F61)
                        : const Color(0xFF8E2DE2),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _firstNameController,
              style: TextStyle(color: _textColor),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.person_outline, color: _secondaryTextColor),
                labelText: 'Имя',
                labelStyle: TextStyle(color: _secondaryTextColor),
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
                  borderSide: BorderSide(
                    color: _currentTheme == 'light'
                        ? const Color(0xFFFF6F61)
                        : const Color(0xFF8E2DE2),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _lastNameController,
              style: TextStyle(color: _textColor),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.person_outline, color: _secondaryTextColor),
                labelText: 'Фамилия',
                labelStyle: TextStyle(color: _secondaryTextColor),
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
                  borderSide: BorderSide(
                    color: _currentTheme == 'light'
                        ? const Color(0xFFFF6F61)
                        : const Color(0xFF8E2DE2),
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}