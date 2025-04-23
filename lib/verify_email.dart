import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({Key? key}) : super(key: key);

  @override
  _VerifyEmailPageState createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final _codeController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Предполагаем, что email передается через Navigator или хранится в состоянии
      // Для простоты используем последний email из pending_users (в реальном приложении нужно передавать email)
      final pendingDocs = await _firestore.collection('pending_users').get();
      if (pendingDocs.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет данных для подтверждения')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final doc = pendingDocs.docs.first;
      final data = doc.data();
      final storedCode = data['verification_code'];

      if (_codeController.text.trim() == storedCode) {
        // Код верный, создаем пользователя в Firebase Authentication
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: data['email'],
          password: data['password'],
        );
        final user = userCredential.user;

        if (user != null) {
          // Переносим данные в коллекцию users
          await _firestore.collection('users').doc(user.uid).set({
            'email': data['email'],
            'first_name': data['first_name'],
            'last_name': data['last_name'],
            'role': 'user',
            'created_at': DateTime.now().toIso8601String(),
            'preferred_tests': [],
            'theme': 'light',
          });

          // Удаляем запись из pending_users
          await _firestore.collection('pending_users').doc(doc.id).delete();

          // Перенаправляем на главный экран
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Неверный код подтверждения')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при подтверждении: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Подтверждение Email')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Введите код подтверждения, отправленный на ваш email.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Код подтверждения'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Введите код';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _verifyCode,
                    child: const Text('Подтвердить'),
                  ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/login');
              },
              child: const Text('Отмена'),
            ),
          ],
        ),
      ),
    );
  }
}