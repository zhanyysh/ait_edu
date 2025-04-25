
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'settings.dart';
import 'contests.dart'; // Импорт нового файла contests.dart
import 'dart:math';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const TestSelectionPage(),
    const TrainingPage(),
    const ContestsPage(), // Используем ContestsPage из contests.dart
    const HistoryPage(),
    const SettingsPage(),
    const MyResultsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тестировочная платформа'),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.quiz),
            label: 'Тесты',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Обучение',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'Контесты',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'История',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Настройки',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star),
            label: 'Результаты',
          ),
        ],
      ),
    );
  }
}

class TestSelectionPage extends StatefulWidget {
  const TestSelectionPage({super.key});

  @override
  TestSelectionPageState createState() => TestSelectionPageState();
}

class TestSelectionPageState extends State<TestSelectionPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<String> _selectedTestTypeIds = [];
  Map<String, String?> _selectedLanguages = {};
  Map<String, List<Map<String, String>>> _availableLanguages = {};
  List<Map<String, String>> _testTypes = [];
  String? _selectedTestTypeId;

  @override
  void initState() {
    super.initState();
    _loadTestTypes();
    _loadSelectedTests();
  }

  Future<void> _loadTestTypes() async {
    try {
      QuerySnapshot testTypesSnapshot = await _firestore.collection('test_types').get();
      if (mounted) {
        setState(() {
          _testTypes = testTypesSnapshot.docs.map((doc) {
            return {
              'id': doc.id,
              'name': doc['name'] as String,
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('TestSelectionPage: Ошибка загрузки видов тестов: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки тестов: $e')),
        );
      }
    }
  }

  Future<void> _loadSelectedTests() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        if (data.containsKey('selected_tests')) {
          List<dynamic> selectedTests = data['selected_tests'] as List<dynamic>;
          if (mounted) {
            setState(() {
              _selectedTestTypeIds = selectedTests.map((test) => test['test_type_id'] as String).toList();
              _selectedLanguages = {
                for (var test in selectedTests)
                  test['test_type_id'] as String: test['language'] as String?
              };
              for (var testTypeId in _selectedTestTypeIds) {
                _loadAvailableLanguages(testTypeId);
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint('TestSelectionPage: Ошибка загрузки выбранных тестов: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки выбранных тестов: $e')),
        );
      }
    }
  }

  Future<void> _saveSelectedTests() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      List<Map<String, dynamic>> selectedTests = _selectedTestTypeIds.map((testTypeId) {
        return {
          'test_type_id': testTypeId,
          'language': _selectedLanguages[testTypeId],
        };
      }).toList();

      await _firestore.collection('users').doc(user.uid).update({
        'selected_tests': selectedTests,
      });
    } catch (e) {
      debugPrint('TestSelectionPage: Ошибка сохранения выбранных тестов: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения выбранных тестов: $e')),
        );
      }
    }
  }

  Future<void> _loadAvailableLanguages(String testTypeId) async {
    try {
      QuerySnapshot languagesSnapshot = await _firestore
          .collection('test_types')
          .doc(testTypeId)
          .collection('languages')
          .get();

      if (mounted) {
        setState(() {
          _availableLanguages[testTypeId] = languagesSnapshot.docs.map((doc) {
            return {
              'name': doc['name'] as String,
              'code': doc['code'] as String,
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('TestSelectionPage: Ошибка загрузки языков для testTypeId $testTypeId: $e');
      if (mounted) {
        setState(() {
          _availableLanguages[testTypeId] = [];
        });
      }
    }
  }

  void _addTestType() {
    if (_selectedTestTypeId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Выберите вид теста')),
        );
      }
      return;
    }

    setState(() {
      if (!_selectedTestTypeIds.contains(_selectedTestTypeId)) {
        _selectedTestTypeIds.add(_selectedTestTypeId!);
        _selectedLanguages[_selectedTestTypeId!] = null;
        _loadAvailableLanguages(_selectedTestTypeId!);
      }
      _selectedTestTypeId = null;
    });

    _saveSelectedTests();
  }

  void _startTest(String testTypeId, String? language, {String? contestId}) {
    if (language == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Выберите язык')),
        );
      }
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TestPage(
          testTypeId: testTypeId,
          language: language,
          contestId: contestId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Прохождение тестов',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedTestTypeId,
              hint: const Text('Выберите вид теста'),
              items: _testTypes.map((testType) {
                return DropdownMenuItem<String>(
                  value: testType['id'],
                  child: Text(testType['name']!),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedTestTypeId = value;
                });
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: ElevatedButton(
                onPressed: _addTestType,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Добавить тест'),
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedTestTypeIds.isNotEmpty) ...[
              const Text(
                'Выбранные тесты:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Column(
                children: _selectedTestTypeIds.map((testTypeId) {
                  final testTypeName = _testTypes
                      .firstWhere((testType) => testType['id'] == testTypeId)['name']!;
                  final languages = _availableLanguages[testTypeId] ?? [];
                  final selectedLanguage = _selectedLanguages[testTypeId];

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Colors.grey, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      testTypeName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    if (languages.isNotEmpty)
                                      DropdownButtonFormField<String>(
                                        value: selectedLanguage,
                                        hint: const Text('Выберите язык'),
                                        items: languages.map((lang) {
                                          return DropdownMenuItem<String>(
                                            value: lang['code'],
                                            child: Text(lang['name']!),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedLanguages[testTypeId] = value;
                                          });
                                          _saveSelectedTests();
                                        },
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Colors.grey),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Colors.grey),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Colors.blue, width: 2),
                                          ),
                                        ),
                                      )
                                    else
                                      const Text(
                                        'Языки загружаются...',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _selectedTestTypeIds.remove(testTypeId);
                                    _selectedLanguages.remove(testTypeId);
                                    _availableLanguages.remove(testTypeId);
                                  });
                                  _saveSelectedTests();
                                },
                              ),
                            ],
                          ),
                          if (selectedLanguage != null) ...[
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => _startTest(testTypeId, selectedLanguage),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Начать тест'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class TestPage extends StatefulWidget {
  final String testTypeId;
  final String language;
  final String? contestId;

  const TestPage({
    super.key,
    required this.testTypeId,
    required this.language,
    this.contestId,
  });

  @override
  TestPageState createState() => TestPageState();
}

class TestPageState extends State<TestPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<DocumentSnapshot> _categories = [];
  int _currentCategoryIndex = 0;
  List<DocumentSnapshot> _questions = [];
  List<int?> _selectedAnswers = [];
  int _correctAnswers = 0;
  double _duration = 0;
  int _timeRemaining = 0;
  bool _isLoading = true;
  bool _entireTestFinished = false;

  List<DocumentSnapshot> _allQuestions = [];
  List<int?> _allSelectedAnswers = [];
  List<String> _allCorrectAnswers = [];
  List<String> _categoryNames = [];
  List<int> _questionsPerCategory = [];
  List<double> _pointsPerQuestionByCategory = [];
  double _totalPoints = 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      QuerySnapshot categoriesSnapshot = await _firestore
          .collection('test_types')
          .doc(widget.testTypeId)
          .collection('categories')
          .orderBy('created_at')
          .get();

      _categories = categoriesSnapshot.docs;

      if (_categories.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Нет доступных категорий для этого теста')),
          );
          Navigator.pop(context);
        }
        return;
      }

      await _loadQuestionsForCurrentCategory();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки категорий: $e')),
        );
      }
    }
  }

  Future<void> _loadQuestionsForCurrentCategory() async {
    setState(() {
      _isLoading = true;
      _questions = [];
      _selectedAnswers = [];
    });

    try {
      DocumentSnapshot categoryDoc = _categories[_currentCategoryIndex];
      String categoryId = categoryDoc.id;
      _duration = (categoryDoc['duration'] as num).toDouble();
      int numberOfQuestions = (categoryDoc['number_of_questions'] as int? ?? 30);
      _timeRemaining = (_duration * 60).toInt();

      debugPrint('TestPage: Загрузка вопросов для testTypeId=${widget.testTypeId}, categoryId=$categoryId, language=${widget.language}');
      debugPrint('TestPage: Количество вопросов для категории: $numberOfQuestions');

      List<String> usedQuestionIds = [];
      final user = _auth.currentUser;
      if (user != null) {
        QuerySnapshot usedQuestions = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('used_questions')
            .where('test_type_id', isEqualTo: widget.testTypeId)
            .where('category_id', isEqualTo: categoryId)
            .where('language', isEqualTo: widget.language)
            .get();
        usedQuestionIds = usedQuestions.docs.map((doc) => doc['question_id'] as String).toList();
        debugPrint('TestPage: Использованные вопросы: $usedQuestionIds');
      }

      QuerySnapshot questionsSnapshot = await _firestore
          .collection('test_types')
          .doc(widget.testTypeId)
          .collection('categories')
          .doc(categoryId)
          .collection('questions')
          .where('language', isEqualTo: widget.language)
          .get();

      debugPrint('TestPage: Всего вопросов в базе: ${questionsSnapshot.docs.length}');

      List<DocumentSnapshot> questions = questionsSnapshot.docs
          .where((doc) => !usedQuestionIds.contains(doc.id))
          .where((doc) => doc['options'] != null && (doc['options'] as List).isNotEmpty)
          .toList();

      debugPrint('TestPage: Доступных вопросов после исключения использованных: ${questions.length}');

      if (questions.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        if (_currentCategoryIndex + 1 < _categories.length) {
          setState(() {
            _currentCategoryIndex++;
          });
          await _loadQuestionsForCurrentCategory();
        } else {
          _finishEntireTest();
        }
        return;
      }

      questions.shuffle(Random());
      _questions = questions.length > numberOfQuestions ? questions.sublist(0, numberOfQuestions) : questions;

      debugPrint('TestPage: Итоговое количество вопросов для теста: ${_questions.length}');

      _selectedAnswers = List<int?>.filled(_questions.length, null);

      if (user != null) {
        for (var question in _questions) {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('used_questions')
              .add({
            'test_type_id': widget.testTypeId,
            'category_id': categoryId,
            'language': widget.language,
            'question_id': question.id,
          });
        }
      }

      setState(() {
        _isLoading = false;
      });

      _startTimer();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки вопросов: $e')),
        );
      }
    }
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_timeRemaining > 0 && !_entireTestFinished && mounted) {
        setState(() {
          _timeRemaining--;
        });
        _startTimer();
      } else if (_timeRemaining <= 0 && !_entireTestFinished) {
        _finishCategory();
      }
    });
  }

  void _selectAnswer(int questionIndex, int answerIndex) {
    setState(() {
      _selectedAnswers[questionIndex] = answerIndex;
    });
  }

  Future<void> _finishCategory() async {
    if (_selectedAnswers.contains(null)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ответьте на все вопросы перед продолжением')),
        );
      }
      return;
    }

    DocumentSnapshot categoryDoc = _categories[_currentCategoryIndex];
    String categoryName = categoryDoc['name'] as String;
    double pointsPerQuestion = (categoryDoc['points_per_question'] as num).toDouble();

    _categoryNames.add(categoryName);
    _pointsPerQuestionByCategory.add(pointsPerQuestion);
    _questionsPerCategory.add(_questions.length);

    int categoryCorrectAnswers = 0;
    for (int i = 0; i < _questions.length; i++) {
      DocumentSnapshot question = _questions[i];
      String correctAnswer = question['correct_answer'] as String;
      _allQuestions.add(question);
      _allCorrectAnswers.add(correctAnswer);
      int? userAnswerIndex = _selectedAnswers[i];
      _allSelectedAnswers.add(userAnswerIndex);
      final options = (question['options'] as List).map((option) => option.toString()).toList();
      String? userAnswer = userAnswerIndex != null ? options[userAnswerIndex] : null;
      if (userAnswer == correctAnswer) {
        _correctAnswers++;
        categoryCorrectAnswers++;
      }
    }

    double categoryPoints = categoryCorrectAnswers * pointsPerQuestion;
    _totalPoints += categoryPoints;

    if (_questions.isNotEmpty) {
      await _saveCategoryResult();
    }

    if (_currentCategoryIndex + 1 < _categories.length) {
      setState(() {
        _currentCategoryIndex++;
      });
      await _loadQuestionsForCurrentCategory();
    } else {
      _finishEntireTest();
    }
  }

  Future<void> _saveCategoryResult() async {
    final user = _auth.currentUser;
    if (user == null) return;

    DocumentSnapshot categoryDoc = _categories[_currentCategoryIndex];
    double pointsPerQuestion = (categoryDoc['points_per_question'] as num).toDouble();
    int categoryCorrectAnswers = 0;

    for (int i = 0; i < _questions.length; i++) {
      final options = (_questions[i]['options'] as List).map((option) => option.toString()).toList();
      String correctAnswer = _questions[i]['correct_answer'] as String;
      int? userAnswerIndex = _selectedAnswers[i];
      String? userAnswer = userAnswerIndex != null ? options[userAnswerIndex] : null;
      if (userAnswer == correctAnswer) {
        categoryCorrectAnswers++;
      }
    }

    double categoryPoints = categoryCorrectAnswers * pointsPerQuestion;

    DocumentSnapshot testTypeDoc = await _firestore.collection('test_types').doc(widget.testTypeId).get();
    String testTypeName = testTypeDoc['name'] as String;
    String categoryName = categoryDoc['name'] as String;

    // Сохранение в историю пользователя
    await _firestore.collection('users').doc(user.uid).collection('test_history').add({
      'date': DateTime.now().toIso8601String(),
      'test_type': testTypeName,
      'category': categoryName,
      'correct_answers': categoryCorrectAnswers,
      'total_questions': _questions.length,
      'points': categoryPoints,
      'time_spent': (_duration * 60 - _timeRemaining).toInt(),
      'total_time': (_duration * 60).toInt(),
    });

    // Сохранение в результаты контеста, если это контест
    if (widget.contestId != null) {
      await _firestore
          .collection('contest_results')
          .doc(widget.contestId)
          .collection('results')
          .doc(user.uid)
          .set({
        'correct_answers': categoryCorrectAnswers,
        'total_questions': _questions.length,
        'points': categoryPoints,
        'time_spent': (_duration * 60 - _timeRemaining).toInt(),
        'completed_at': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    }
  }

  void _finishEntireTest() {
    if (mounted) {
      setState(() {
        _entireTestFinished = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тест'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_questions.isEmpty && !_entireTestFinished)
                const Center(child: Text('Вопросы не найдены'))
              else if (_entireTestFinished) ...[
                const Text(
                  'ТЕСТ ЗАВЕРШЁН',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  'Правильных ответов: $_correctAnswers из ${_allQuestions.length}',
                  style: const TextStyle(fontSize: 18),
                ),
                Text(
                  'Всего баллов: ${_totalPoints.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Результаты:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._categoryNames.asMap().entries.map((categoryEntry) {
                  int categoryIndex = categoryEntry.key;
                  String categoryName = categoryEntry.value;
                  double pointsPerQuestion = _pointsPerQuestionByCategory[categoryIndex];

                  int startIndex = categoryIndex == 0
                      ? 0
                      : _questionsPerCategory
                          .sublist(0, categoryIndex)
                          .fold(0, (sum, count) => sum + count);
                  int endIndex = startIndex + _questionsPerCategory[categoryIndex];

                  int categoryCorrectAnswers = 0;
                  for (int i = startIndex; i < endIndex; i++) {
                    String correctAnswer = _allCorrectAnswers[i];
                    int? userAnswerIndex = _allSelectedAnswers[i];
                    final options = (_allQuestions[i]['options'] as List).map((option) => option.toString()).toList();
                    String? userAnswer = userAnswerIndex != null ? options[userAnswerIndex] : null;
                    if (userAnswer == correctAnswer) {
                      categoryCorrectAnswers++;
                    }
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$categoryName: $categoryCorrectAnswers/${endIndex - startIndex} правильных',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ..._allQuestions.asMap().entries.where((entry) => entry.key >= startIndex && entry.key < endIndex).map((entry) {
                        int index = entry.key;
                        DocumentSnapshot question = entry.value;
                        final options = (question['options'] as List).map((option) => option.toString()).toList();
                        String correctAnswer = _allCorrectAnswers[index];
                        int? userAnswerIndex = _allSelectedAnswers[index];
                        String? userAnswer = userAnswerIndex != null ? options[userAnswerIndex] : null;
                        String explanation = question['explanation'] as String? ?? 'Объяснение отсутствует';

                        bool isCorrect = userAnswer == correctAnswer;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Вопрос ${index - startIndex + 1}: ${question['text']}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ваш ответ: ${userAnswer ?? 'Не выбран'}',
                                style: TextStyle(
                                  color: isCorrect ? Colors.green : Colors.red,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Правильный ответ: $correctAnswer',
                                style: const TextStyle(fontSize: 14, color: Colors.green),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Объяснение: $explanation',
                                style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                              ),
                              const Divider(),
                            ],
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 16),
                    ],
                  );
                }).toList(),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Вернуться'),
                ),
              ]
              else ...[
                Builder(
                  builder: (BuildContext context) {
                    final category = _categories[_currentCategoryIndex];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Категория: ${category['name']}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Оставшееся время: ${_timeRemaining ~/ 60}:${(_timeRemaining % 60).toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 16, color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ..._questions.asMap().entries.map((entry) {
                          int questionIndex = entry.key;
                          DocumentSnapshot question = entry.value;

                          final rawOptions = question['options'];
                          final options = rawOptions != null && rawOptions is List
                              ? rawOptions.map((option) => option.toString()).toList()
                              : <String>[];

                          if (options.isEmpty) {
                            return const Center(
                              child: Text(
                                'Ошибка: Вопрос не содержит вариантов ответа. Обратитесь к администратору.',
                                style: TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Вопрос ${questionIndex + 1}: ${question['text']}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              ...options.asMap().entries.map((optionEntry) {
                                int optionIndex = optionEntry.key;
                                String option = optionEntry.value;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: RadioListTile<int>(
                                    title: Text(option, style: const TextStyle(fontSize: 16)),
                                    value: optionIndex,
                                    groupValue: _selectedAnswers[questionIndex],
                                    onChanged: (value) => _selectAnswer(questionIndex, value!),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                );
                              }).toList(),
                              const SizedBox(height: 16),
                            ],
                          );
                        }).toList(),
                        const SizedBox(height: 16),
                        Center(
                          child: ElevatedButton(
                            onPressed: _finishCategory,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text(
                              'Закончил категорию',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class TrainingPage extends StatelessWidget {
  const TrainingPage({super.key});

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
                    return ExpansionTile(
                      title: Text(testTypeName),
                      children: [
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('test_types')
                              .doc(testTypeId)
                              .collection('study_materials')
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
                                final title = material['title'] as String;
                                final content = material['content'] as String;
                                return ListTile(
                                  title: Text(title),
                                  subtitle: Text(content),
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
          ),
        ],
      ),
    );
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  HistoryPageState createState() => HistoryPageState();
}

class HistoryPageState extends State<HistoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, String>> _testTypes = [];
  String? _selectedTestType;
  List<Map<String, String>> _categories = [];
  String _sortBy = 'date_desc';

  @override
  void initState() {
    super.initState();
    _loadTestTypes();
    _loadSelectedTestType();
  }

  Future<void> _loadTestTypes() async {
    try {
      QuerySnapshot testTypesSnapshot = await _firestore.collection('test_types').get();
      if (mounted) {
        setState(() {
          _testTypes = testTypesSnapshot.docs.map((doc) {
            return {
              'id': doc.id,
              'name': doc['name'] as String,
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('HistoryPage: Ошибка загрузки видов тестов: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки видов тестов: $e')),
        );
      }
    }
  }

  Future<void> _loadCategories(String? testType) async {
    try {
      List<Map<String, String>> categories = [];
      if (testType == null) {
        for (var testTypeMap in _testTypes) {
          final testTypeId = testTypeMap['id']!;
          final testTypeName = testTypeMap['name']!;
          QuerySnapshot categoriesSnapshot = await _firestore
              .collection('test_types')
              .doc(testTypeId)
              .collection('categories')
              .get();
          categories.addAll(categoriesSnapshot.docs.map((doc) => {
                'test_type': testTypeName,
                'category': doc['name'] as String,
              }));
        }
      } else {
        final testTypeId = _testTypes.firstWhere((t) => t['name'] == testType)['id']!;
        final testTypeName = testType;
        QuerySnapshot categoriesSnapshot = await _firestore
            .collection('test_types')
            .doc(testTypeId)
            .collection('categories')
            .get();
        categories = categoriesSnapshot.docs.map((doc) => {
              'test_type': testTypeName,
              'category': doc['name'] as String,
            }).toList();
      }
      if (mounted) {
        setState(() {
          _categories = categories;
        });
      }
    } catch (e) {
      debugPrint('HistoryPage: Ошибка загрузки категорий: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки категорий: $e')),
        );
      }
    }
  }

  Future<void> _loadSelectedTestType() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        if (data.containsKey('history_filter')) {
          String? selectedTestType = data['history_filter'] as String?;
          if (mounted) {
            setState(() {
              _selectedTestType = selectedTestType;
            });
            await _loadCategories(selectedTestType);
          }
        }
      }
    } catch (e) {
      debugPrint('HistoryPage: Ошибка загрузки фильтра истории: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки фильтра истории: $e')),
        );
      }
    }
  }

  Future<void> _saveSelectedTestType() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'history_filter': _selectedTestType,
      });
    } catch (e) {
      debugPrint('HistoryPage: Ошибка сохранения фильтра истории: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения фильтра истории: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return const Center(child: Text('Пользователь не авторизован'));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'История тестов',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () async {
                  bool? confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Очистить историю?'),
                      content: const Text('Вы уверены, что хотите удалить всю историю тестов? Это действие нельзя отменить.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Отмена'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Очистить', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    QuerySnapshot historySnapshot = await _firestore
                        .collection('users')
                        .doc(user.uid)
                        .collection('test_history')
                        .get();
                    for (var doc in historySnapshot.docs) {
                      await doc.reference.delete();
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('История очищена')),
                    );
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Очистить историю'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedTestType,
                  hint: const Text('Выберите вид теста'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Все тесты'),
                    ),
                    ..._testTypes.map((testType) {
                      return DropdownMenuItem<String>(
                        value: testType['name'],
                        child: Text(testType['name']!),
                      );
                    }).toList(),
                  ],
                  onChanged: (value) async {
                    setState(() {
                      _selectedTestType = value;
                    });
                    await _loadCategories(value);
                    await _saveSelectedTestType();
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _sortBy,
                  items: const [
                    DropdownMenuItem<String>(
                      value: 'date_desc',
                      child: Text('Дата (убыв.)'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'date_asc',
                      child: Text('Дата (возр.)'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'points_desc',
                      child: Text('Баллы (убыв.)'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'points_asc',
                      child: Text('Баллы (возр.)'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'percent_desc',
                      child: Text('Процент (убыв.)'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'percent_asc',
                      child: Text('Процент (возр.)'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _sortBy = value!;
                    });
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(user.uid)
                  .collection('test_history')
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Ошибка: ${snapshot.error}');
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final history = snapshot.data!.docs;

                final filteredHistory = _selectedTestType == null
                    ? history
                    : history.where((doc) => doc['test_type'] == _selectedTestType).toList();

                if (filteredHistory.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'История пуста',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Пройдите тест, чтобы увидеть результаты здесь.',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                int totalTimeSpent = 0;
                int totalTime = 0;
                double totalPoints = 0;

                for (var record in filteredHistory) {
                  totalTimeSpent += record['time_spent'] as int;
                  totalTime += record['total_time'] as int;
                  totalPoints += (record['points'] as num).toDouble();
                }

                final Map<String, List<Map<String, dynamic>>> groupedHistory = {};
                for (var record in filteredHistory) {
                  final date = DateTime.parse(record['date']).toString().split(' ')[0];
                  if (!groupedHistory.containsKey(date)) {
                    groupedHistory[date] = [];
                  }
                  groupedHistory[date]!.add({
                    'record': record,
                    'test_type': record['test_type'] as String,
                    'category': record['category'] as String,
                    'points': (record['points'] as num).toDouble(),
                    'correct_answers': record['correct_answers'] as int,
                    'total_questions': record['total_questions'] as int,
                    'time_spent': record['time_spent'] as int,
                    'total_time': record['total_time'] as int,
                  });
                }

                List<Map<String, dynamic>> historyEntries = groupedHistory.entries.map((entry) {
                  final date = entry.key;
                  final records = entry.value;

                  final totalPointsForDate = records.fold<double>(
                    0.0,
                    (sum, r) => sum + (r['points'] as double),
                  );

                  final totalCorrectAnswers = records.fold<int>(
                    0,
                    (sum, r) => sum + (r['correct_answers'] as int),
                  );
                  final totalQuestions = records.fold<int>(
                    0,
                    (sum, r) => sum + (r['total_questions'] as int),
                  );
                  final percentage = totalQuestions > 0 ? (totalCorrectAnswers / totalQuestions * 100) : 0.0;

                  final totalTimeSpentForDate = records.fold<int>(
                    0,
                    (sum, r) => sum + (r['time_spent'] as int),
                  );

                  final Map<String, double> categoryPoints = {};
                  for (var record in records) {
                    final testType = record['test_type'] as String;
                    final category = record['category'] as String;
                    final key = '$testType:$category';
                    final points = record['points'] as double;
                    categoryPoints[key] = points;
                  }

                  return {
                    'date': DateTime.parse(date),
                    'records': records,
                    'total_points': totalPointsForDate,
                    'percentage': percentage,
                    'time_spent': totalTimeSpentForDate,
                    'category_points': categoryPoints,
                  };
                }).toList();

                if (_sortBy == 'date_asc') {
                  historyEntries.sort((a, b) => a['date'].compareTo(b['date']));
                } else if (_sortBy == 'date_desc') {
                  historyEntries.sort((a, b) => b['date'].compareTo(a['date']));
                } else if (_sortBy == 'points_asc') {
                  historyEntries.sort((a, b) => a['total_points'].compareTo(b['total_points']));
                } else if (_sortBy == 'points_desc') {
                  historyEntries.sort((a, b) => b['total_points'].compareTo(a['total_points']));
                } else if (_sortBy == 'percent_asc') {
                  historyEntries.sort((a, b) => a['percentage'].compareTo(b['percentage']));
                } else if (_sortBy == 'percent_desc') {
                  historyEntries.sort((a, b) => b['percentage'].compareTo(a['percentage']));
                }

                List<DataColumn> columns = [
                  const DataColumn(
                    label: Text(
                      'Дата',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ..._categories.map((categoryMap) => DataColumn(
                        label: SizedBox(
                          width: 100,
                          child: Text(
                            '${categoryMap['test_type']}: ${categoryMap['category']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )),
                  const DataColumn(
                    label: Text(
                      'Процент правильных',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'Время',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'Общий балл',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ];

                List<DataRow> rows = historyEntries.map((entry) {
                  final date = entry['date'] as DateTime;
                  final records = entry['records'] as List<Map<String, dynamic>>;
                  final totalPointsForDate = entry['total_points'] as double;
                  final percentage = entry['percentage'] as double;
                  final timeSpent = entry['time_spent'] as int;
                  final categoryPoints = entry['category_points'] as Map<String, double>;

                  final formattedDate = DateFormat('d MMMM yyyy', 'ru').format(date);

                  List<DataCell> cells = [
                    DataCell(Text(formattedDate)),
                    ..._categories.map((categoryMap) {
                      final key = '${categoryMap['test_type']}:${categoryMap['category']}';
                      return DataCell(
                        Text(
                          categoryPoints.containsKey(key)
                              ? categoryPoints[key]!.toStringAsFixed(1)
                              : 'N/A',
                          style: TextStyle(
                            color: categoryPoints.containsKey(key)
                                ? (categoryPoints[key]! >= 80
                                    ? Colors.green
                                    : categoryPoints[key]! < 50
                                        ? Colors.red
                                        : Colors.orange)
                                : Colors.grey,
                          ),
                        ),
                      );
                    }),
                    DataCell(Text('${percentage.toStringAsFixed(1)}%')),
                    DataCell(Text('${timeSpent ~/ 60} мин')),
                    DataCell(Text(totalPointsForDate.toStringAsFixed(1))),
                  ];

                  return DataRow(
                    cells: cells,
                    onSelectChanged: (selected) {
                      if (selected == true) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Результаты за $formattedDate'),
                            content: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: records.map((r) {
                                  final record = r['record'] as QueryDocumentSnapshot;
                                  final testType = record['test_type'] as String;
                                  final category = record['category'] as String;
                                  final correctAnswers = record['correct_answers'] as int;
                                  final totalQuestions = record['total_questions'] as int;
                                  final points = (record['points'] as num).toDouble();
                                  final timeSpentRecord = record['time_spent'] as int;
                                  final totalTime = record['total_time'] as int;
                                  final percentageRecord = totalQuestions > 0
                                      ? (correctAnswers / totalQuestions * 100).toStringAsFixed(1)
                                      : '0.0';

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$testType: $category',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 8),
                                        Text('Правильных ответов: $correctAnswers/$totalQuestions ($percentageRecord%)'),
                                        const SizedBox(height: 4),
                                        Text('Баллы: $points'),
                                        const SizedBox(height: 4),
                                        Text('Время: ${timeSpentRecord ~/ 60} мин из ${totalTime ~/ 60} мин'),
                                        const Divider(),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Закрыть'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  );
                }).toList();

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: columns,
                          rows: rows,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Общий итог: ${totalTimeSpent ~/ 60} мин/${totalTime ~/ 60} мин, общий балл: $totalPoints',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MyResultsPage extends StatelessWidget {
  const MyResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Мои результаты (заглушка, уточните функционал)'),
    );
  }
}
