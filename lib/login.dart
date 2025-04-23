import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
            // Ищем документ в коллекции users, где email равен admin@gmail.com
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
      appBar: AppBar(title: const Text('Вход')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
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
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Пароль'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите пароль';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _login,
                      child: const Text('Войти'),
                    ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/register');
                },
                child: const Text('Нет аккаунта? Зарегистрироваться'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}