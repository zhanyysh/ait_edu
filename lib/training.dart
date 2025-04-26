import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TrainingPage extends StatefulWidget {
  const TrainingPage({super.key});

  @override
  _TrainingPageState createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, int?> _selectedAnswers = {};
  final Map<String, bool> _submittedAnswers = {};
  final Map<String, bool> _isCorrect = {};
  String? _selectedLanguage;
  List<Map<String, String>> _availableLanguages = [];
  final Map<String, bool> _isExpanded = {};

  @override
  void initState() {
    super.initState();
    _loadUserPreferredLanguage();
    _loadAvailableLanguages();
  }

  Future<void> _loadUserPreferredLanguage() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        if (data.containsKey('preferred_language')) {
          setState(() {
            _selectedLanguage = data['preferred_language'] as String?;
          });
        } else if (data.containsKey('selected_tests')) {
          List<dynamic> selectedTests = data['selected_tests'] as List<dynamic>;
          if (selectedTests.isNotEmpty) {
            setState(() {
              _selectedLanguage = selectedTests.first['language'] as String?;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('TrainingPage: Ошибка загрузки предпочтительного языка: $e');
    }
  }

  Future<void> _loadAvailableLanguages() async {
    try {
      QuerySnapshot testTypesSnapshot = await _firestore.collection('test_types').get();
      Set<String> languageCodes = {};
      List<String> languageNames = [];

      for (var testType in testTypesSnapshot.docs) {
        QuerySnapshot languagesSnapshot = await _firestore
            .collection('test_types')
            .doc(testType.id)
            .collection('languages')
            .get();
        for (var lang in languagesSnapshot.docs) {
          String code = lang['code'] as String;
          String name = lang['name'] as String;
          if (!languageCodes.contains(code)) {
            languageCodes.add(code);
            languageNames.add(name);
          }
        }
      }

      setState(() {
        _availableLanguages = languageCodes.map((code) {
          int index = languageCodes.toList().indexOf(code);
          return {
            'code': code,
            'name': languageNames[index],
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('TrainingPage: Ошибка загрузки языков: $e');
    }
  }

  Future<void> _saveMiniTestResult({
    required String testTypeId,
    required String testTypeName,
    required String materialId,
    required String materialTitle,
    required String miniTestId,
    required String questionText,
    required String userAnswer,
    required String correctAnswer,
    required bool isCorrect,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).collection('mini_test_results').add({
        'test_type_id': testTypeId,
        'test_type_name': testTypeName,
        'material_id': materialId,
        'material_title': materialTitle,
        'mini_test_id': miniTestId,
        'question_text': questionText,
        'user_answer': userAnswer,
        'correct_answer': correctAnswer,
        'is_correct': isCorrect,
        'timestamp': DateTime.now().toIso8601String(),
      });
      debugPrint('TrainingPage: Результат мини-теста сохранён');
    } catch (e) {
      debugPrint('TrainingPage: Ошибка сохранения результата мини-теста: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сохранения результата: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Обучающие материалы',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (_availableLanguages.isNotEmpty)
            DropdownButtonFormField<String>(
              value: _selectedLanguage,
              hint: const Text('Выберите язык'),
              items: _availableLanguages.map((lang) {
                return DropdownMenuItem<String>(
                  value: lang['code'],
                  child: Text(lang['name']!),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedLanguage = value;
                });
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
          const SizedBox(height: 16),
          if (_selectedLanguage != null)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('test_types').snapshots(),
                builder: (context, testTypesSnapshot) {
                  if (testTypesSnapshot.hasError) {
                    return Text('Ошибка: ${testTypesSnapshot.error}');
                  }
                  if (testTypesSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final testTypes = testTypesSnapshot.data!.docs;
                  return ListView.builder(
                    itemCount: testTypes.length,
                    itemBuilder: (context, index) {
                      final testType = testTypes[index];
                      final testTypeId = testType.id;
                      final testTypeName = testType['name'] as String;
                      final testTypeKey = 'testType-$testTypeId';
                      return ExpansionTile(
                        key: Key(testTypeKey),
                        initiallyExpanded: _isExpanded[testTypeKey] ?? false,
                        onExpansionChanged: (expanded) {
                          setState(() {
                            _isExpanded[testTypeKey] = expanded;
                          });
                        },
                        title: Text(testTypeName),
                        children: [
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('test_types')
                                .doc(testTypeId)
                                .collection('study_materials')
                                .where('language', isEqualTo: _selectedLanguage)
                                .snapshots(),
                            builder: (context, materialsSnapshot) {
                              if (materialsSnapshot.hasError) {
                                return Text('Ошибка: ${materialsSnapshot.error}');
                              }
                              if (materialsSnapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              final materials = materialsSnapshot.data!.docs;
                              if (materials.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text('Нет материалов'),
                                );
                              }
                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: materials.length,
                                itemBuilder: (context, index) {
                                  final material = materials[index];
                                  final materialId = material.id;
                                  final title = material['title'] as String;
                                  final content = material['content'] as String;
                                  final materialKey = 'material-$materialId';
                                  return ExpansionTile(
                                    key: Key(materialKey),
                                    initiallyExpanded: _isExpanded[materialKey] ?? false,
                                    onExpansionChanged: (expanded) {
                                      setState(() {
                                        _isExpanded[materialKey] = expanded;
                                      });
                                    },
                                    title: Text(title),
                                    subtitle: Text(content),
                                    children: [
                                      StreamBuilder<QuerySnapshot>(
                                        stream: FirebaseFirestore.instance
                                            .collection('test_types')
                                            .doc(testTypeId)
                                            .collection('study_materials')
                                            .doc(materialId)
                                            .collection('mini_tests')
                                            .snapshots(),
                                        builder: (context, miniTestsSnapshot) {
                                          if (miniTestsSnapshot.hasError) {
                                            return Text('Ошибка: ${miniTestsSnapshot.error}');
                                          }
                                          if (miniTestsSnapshot.connectionState == ConnectionState.waiting) {
                                            return const Center(child: CircularProgressIndicator());
                                          }
                                          final miniTests = miniTestsSnapshot.data!.docs;
                                          if (miniTests.isEmpty) {
                                            return const Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: Text('Нет мини-тестов'),
                                            );
                                          }
                                          return ListView.builder(
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            itemCount: miniTests.length,
                                            itemBuilder: (context, index) {
                                              final miniTest = miniTests[index];
                                              final miniTestId = miniTest.id;
                                              final questionText = miniTest['text'] as String;
                                              final options = List<String>.from(miniTest['options']);
                                              final correctAnswer = miniTest['correct_answer'] as String;
                                              final explanation = miniTest['explanation'] as String? ?? 'Нет объяснения';
                                              final answerKey = '$materialId-$miniTestId';

                                              return Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Мини-тест ${index + 1}: $questionText',
                                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    ...options.asMap().entries.map((optionEntry) {
                                                      final optionIndex = optionEntry.key;
                                                      final option = optionEntry.value;
                                                      return RadioListTile<int>(
                                                        title: Text(option),
                                                        value: optionIndex,
                                                        groupValue: _selectedAnswers[answerKey],
                                                        onChanged: _submittedAnswers[answerKey] == true
                                                            ? null
                                                            : (value) {
                                                                setState(() {
                                                                  _selectedAnswers[answerKey] = value;
                                                                  _submittedAnswers[answerKey] = true;
                                                                  _isCorrect[answerKey] = options[value!] == correctAnswer;
                                                                });

                                                                _saveMiniTestResult(
                                                                  testTypeId: testTypeId,
                                                                  testTypeName: testTypeName,
                                                                  materialId: materialId,
                                                                  materialTitle: title,
                                                                  miniTestId: miniTestId,
                                                                  questionText: questionText,
                                                                  userAnswer: options[value!],
                                                                  correctAnswer: correctAnswer,
                                                                  isCorrect: _isCorrect[answerKey]!,
                                                                );
                                                              },
                                                      );
                                                    }).toList(),
                                                    if (_submittedAnswers[answerKey] == true) ...[
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        _isCorrect[answerKey]!
                                                            ? 'Правильно!'
                                                            : 'Неправильно. Правильный ответ: $correctAnswer',
                                                        style: TextStyle(
                                                          color: _isCorrect[answerKey]! ? Colors.green : Colors.red,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text('Объяснение: $explanation'),
                                                    ],
                                                    const Divider(),
                                                  ],
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            )
          else
            const Center(child: Text('Выберите язык для отображения материалов')),
        ],
      ),
    );
  }
}