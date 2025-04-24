import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  String? _selectedTheme = 'light';
  List<String> _preferredTests = [];
  List<String> _availableTestTypes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadTestTypes();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          setState(() {
            _emailController.text = userDoc['email'] as String? ?? '';
            _firstNameController.text = userDoc['first_name'] as String? ?? '';
            _selectedTheme = userDoc['theme'] as String? ?? 'light';
            _preferredTests = List<String>.from(userDoc['preferred_tests'] ?? []);
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

  Future<void> _loadTestTypes() async {
    try {
      QuerySnapshot testTypesSnapshot = await _firestore.collection('test_types').get();
      setState(() {
        _availableTestTypes = testTypesSnapshot.docs.map((doc) => doc['name'] as String).toList();
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка загрузки видов тестов: $e';
      });
    }
  }

  Future<void> _updateUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пользователь не авторизован')),
      );
      return;
    }

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'email': _emailController.text.trim(),
        'first_name': _firstNameController.text.trim(),
        'theme': _selectedTheme ?? 'light',
        'preferred_tests': _preferredTests,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Данные обновлены')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка обновления: $e')),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Настройки',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _firstNameController,
              decoration: const InputDecoration(
                labelText: 'Имя',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedTheme,
              hint: const Text('Выберите тему'),
              items: ['light', 'dark'].map((theme) {
                return DropdownMenuItem<String>(
                  value: theme,
                  child: Text(theme == 'light' ? 'Светлая' : 'Тёмная'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedTheme = value;
                });
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Выберите виды тестов для отображения:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _availableTestTypes.isEmpty
                ? const Text('Нет доступных тестов')
                : Wrap(
                    spacing: 8.0,
                    children: _availableTestTypes.map((testType) {
                      return FilterChip(
                        label: Text(testType),
                        selected: _preferredTests.contains(testType),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _preferredTests.add(testType);
                            } else {
                              _preferredTests.remove(testType);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: _updateUserData,
                child: const Text('Сохранить изменения'),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Выйти'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}