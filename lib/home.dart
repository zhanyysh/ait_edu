import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'settings.dart';
import 'dart:math';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const TestSelectionPage(),
    const TrainingPage(),
    const ContestsPage(),
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
  const TestSelectionPage({Key? key}) : super(key: key);

  @override
  _TestSelectionPageState createState() => _TestSelectionPageState();
}

class _TestSelectionPageState extends State<TestSelectionPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _selectedTestTypeId;
  String? _selectedLanguage;
  List<Map<String, String>> _availableLanguages = [];

  Future<void> _loadAvailableLanguages(String testTypeId) async {
    try {
      QuerySnapshot languagesSnapshot = await _firestore
          .collection('test_types')
          .doc(testTypeId)
          .collection('languages')
          .get();

      setState(() {
        _availableLanguages = languagesSnapshot.docs.map((doc) {
          return {
            'name': doc['name'] as String,
            'code': doc['code'] as String,
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('TestSelectionPage: Ошибка загрузки языков: $e');
      setState(() {
        _availableLanguages = [];
      });
    }
  }

  Future<void> _resetProgress() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пользователь не авторизован')),
      );
      return;
    }

    if (_selectedTestTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите вид теста')),
      );
      return;
    }

    try {
      QuerySnapshot usedQuestions = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('used_questions')
          .where('test_type_id', isEqualTo: _selectedTestTypeId)
          .where('language', isEqualTo: _selectedLanguage)
          .get();

      for (var doc in usedQuestions.docs) {
        await doc.reference.delete();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Прогресс сброшен')),
      );

      await _loadAvailableLanguages(_selectedTestTypeId!);
      setState(() {
        _selectedLanguage = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при сбросе прогресса: $e')),
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
            'Прохождение тестов',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('test_types').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Ошибка: ${snapshot.error}');
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }
              final testTypes = snapshot.data!.docs;
              return DropdownButtonFormField<String>(
                value: _selectedTestTypeId,
                hint: const Text('Выберите вид теста'),
                items: testTypes.map((testType) {
                  return DropdownMenuItem<String>(
                    value: testType.id,
                    child: Text(testType['name']),
                  );
                }).toList(),
                onChanged: (value) async {
                  setState(() {
                    _selectedTestTypeId = value;
                    _selectedLanguage = null;
                    _availableLanguages = [];
                  });
                  if (value != null) {
                    await _loadAvailableLanguages(value);
                  }
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          if (_selectedTestTypeId != null && _availableLanguages.isNotEmpty)
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
          if (_selectedTestTypeId != null && _availableLanguages.isEmpty)
            const Text(
              'Нет доступных языков для этого теста',
              style: TextStyle(color: Colors.red),
            ),
          const SizedBox(height: 16),
          if (_selectedTestTypeId != null)
            Center(
              child: ElevatedButton(
                onPressed: _resetProgress,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Сбросить прогресс'),
              ),
            ),
          const SizedBox(height: 16),
          if (_selectedLanguage != null)
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TestPage(
                        testTypeId: _selectedTestTypeId!,
                        language: _selectedLanguage!,
                      ),
                    ),
                  );
                },
                child: const Text('Начать тест'),
              ),
            ),
        ],
      ),
    );
  }
}

class TestPage extends StatefulWidget {
  final String testTypeId;
  final String language;

  const TestPage({
    Key? key,
    required this.testTypeId,
    required this.language,
  }) : super(key: key);

  @override
  _TestPageState createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
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

  // Lists to store all questions, answers, and category info across categories
  List<DocumentSnapshot> _allQuestions = [];
  List<int?> _allSelectedAnswers = [];
  List<String> _allCorrectAnswers = [];
  List<String> _categoryNames = []; // Store category names for grouping
  List<int> _questionsPerCategory = []; // Store the number of questions per category
  List<double> _pointsPerQuestionByCategory = []; // Store points per question for each category
  double _totalPoints = 0; // Store the total points

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет доступных категорий для этого теста')),
        );
        Navigator.pop(context);
        return;
      }

      await _loadQuestionsForCurrentCategory();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки категорий: $e')),
      );
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
        // If no questions in this category, move to the next category or finish
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

      // Инициализируем _selectedAnswers с количеством вопросов
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки вопросов: $e')),
      );
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

  void _finishCategory() {
    // Check if all questions have been answered
    if (_selectedAnswers.contains(null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ответьте на все вопросы перед продолжением')),
      );
      return;
    }

    // Accumulate questions and answers for this category
    DocumentSnapshot categoryDoc = _categories[_currentCategoryIndex];
    String categoryName = categoryDoc['name'] as String;
    double pointsPerQuestion = (categoryDoc['points_per_question'] as num).toDouble();

    // Add category info for grouping later
    _categoryNames.add(categoryName);
    _pointsPerQuestionByCategory.add(pointsPerQuestion);
    _questionsPerCategory.add(_questions.length); // Store the number of questions in this category

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

    // Calculate points for this category and add to total
    double categoryPoints = categoryCorrectAnswers * pointsPerQuestion;
    _totalPoints += categoryPoints;

    // Save category results to test history
    _saveCategoryResult();

    // Check if there are more categories
    if (_currentCategoryIndex + 1 < _categories.length) {
      setState(() {
        _currentCategoryIndex++;
      });
      _loadQuestionsForCurrentCategory();
    } else {
      _finishEntireTest();
    }
  }

  void _saveCategoryResult() async {
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
  }

  void _finishEntireTest() {
    setState(() {
      _entireTestFinished = true;
    });
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
                // Group questions by category
                ..._categoryNames.asMap().entries.map((categoryEntry) {
                  int categoryIndex = categoryEntry.key;
                  String categoryName = categoryEntry.value;
                  double pointsPerQuestion = _pointsPerQuestionByCategory[categoryIndex];

                  // Find the range of questions for this category
                  int startIndex = categoryIndex == 0
                      ? 0
                      : _questionsPerCategory
                          .sublist(0, categoryIndex)
                          .fold(0, (sum, count) => sum + count);
                  int endIndex = startIndex + _questionsPerCategory[categoryIndex];

                  // Calculate correct answers for this category
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
                        // Display all questions for the current category
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
  const TrainingPage({super.key}); // Use super.key to address the lint warning

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
                    final testType = testTypes[index]; // Fix typo: 'terus' to 'testTypes'
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

class ContestsPage extends StatelessWidget {
  const ContestsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firestore = FirebaseFirestore.instance;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Контесты',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: firestore.collection('contests').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Ошибка: ${snapshot.error}');
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final contests = snapshot.data!.docs;
                if (contests.isEmpty) {
                  return const Center(child: Text('Нет доступных контестов'));
                }
                return ListView.builder(
                  itemCount: contests.length,
                  itemBuilder: (context, index) {
                    final contest = contests[index];
                    final contestId = contest.id;
                    final testTypeId = contest['test_type_id'] as String;
                    final date = DateTime.parse(contest['date']);
                    final participants = List<String>.from(contest['participants']);
                    final isParticipant = user != null && participants.contains(user.uid);

                    return FutureBuilder<DocumentSnapshot>(
                      future: firestore.collection('test_types').doc(testTypeId).get(),
                      builder: (context, testTypeSnapshot) {
                        if (testTypeSnapshot.connectionState == ConnectionState.waiting) {
                          return const ListTile(title: Text('Загрузка...'));
                        }
                        final testTypeName = testTypeSnapshot.data?['name'] ?? 'Неизвестный тест';
                        return ListTile(
                          title: Text('Контест: $testTypeName'),
                          subtitle: Text('Дата: ${date.toIso8601String()}'),
                          trailing: isParticipant
                              ? const Text('Вы участвуете')
                              : ElevatedButton(
                                  onPressed: () async {
                                    if (user != null) {
                                      await firestore.collection('contests').doc(contestId).update({
                                        'participants': FieldValue.arrayUnion([user.uid]),
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Вы записались на контест')),
                                      );
                                    }
                                  },
                                  child: const Text('Записаться'),
                                ),
                        );
                      },
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

class HistoryPage extends StatelessWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firestore = FirebaseFirestore.instance;

    if (user == null) {
      return const Center(child: Text('Пользователь не авторизован'));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'История тестов',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: firestore
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
                if (history.isEmpty) {
                  return const Center(child: Text('История пуста'));
                }

                int totalTimeSpent = 0;
                int totalTime = 0;
                double totalPoints = 0;

                for (var record in history) {
                  totalTimeSpent += record['time_spent'] as int;
                  totalTime += record['total_time'] as int;
                  totalPoints += (record['points'] as num).toDouble();
                }

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          final record = history[index];
                          final date = DateTime.parse(record['date']);
                          final testType = record['test_type'] as String;
                          final category = record['category'] as String;
                          final correctAnswers = record['correct_answers'] as int;
                          final totalQuestions = record['total_questions'] as int;
                          final points = (record['points'] as num).toDouble();
                          final timeSpent = record['time_spent'] as int;
                          final totalTimeRecord = record['total_time'] as int;

                          return ListTile(
                            title: Text('$testType - $category'),
                            subtitle: Text(
                              '${date.toIso8601String()}\n'
                              '$correctAnswers/$totalQuestions ответов, $points баллов, '
                              '${timeSpent ~/ 60} мин/${totalTimeRecord ~/ 60} мин',
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Общий итог: ${totalTimeSpent ~/ 60} мин/${totalTime ~/ 60} мин, '
                        'общий балл: $totalPoints',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
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
  const MyResultsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Мои результаты (заглушка, уточните функционал)'),
    );
  }
}