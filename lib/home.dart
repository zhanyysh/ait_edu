import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'settings.dart';

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
  String? _selectedTestTypeId;
  String? _selectedCategoryId;
  String? _selectedLanguage;
  final List<String> _languages = ['ru', 'en', 'ky'];

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
                onChanged: (value) {
                  setState(() {
                    _selectedTestTypeId = value;
                    _selectedCategoryId = null;
                    _selectedLanguage = null;
                  });
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          if (_selectedTestTypeId != null)
            StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('test_types')
                  .doc(_selectedTestTypeId)
                  .collection('categories')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Ошибка: ${snapshot.error}');
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                final categories = snapshot.data!.docs;
                return DropdownButtonFormField<String>(
                  value: _selectedCategoryId,
                  hint: const Text('Выберите категорию'),
                  items: categories.map((category) {
                    return DropdownMenuItem<String>(
                      value: category.id,
                      child: Text(category['name']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategoryId = value;
                      _selectedLanguage = null;
                    });
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
          if (_selectedCategoryId != null)
            DropdownButtonFormField<String>(
              value: _selectedLanguage,
              hint: const Text('Выберите язык'),
              items: _languages.map((lang) {
                return DropdownMenuItem<String>(
                  value: lang,
                  child: Text(lang == 'ru' ? 'Русский' : lang == 'en' ? 'Английский' : 'Кыргызский'),
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
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TestPage(
                        testTypeId: _selectedTestTypeId!,
                        categoryId: _selectedCategoryId!,
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
  final String categoryId;
  final String language;

  const TestPage({
    Key? key,
    required this.testTypeId,
    required this.categoryId,
    required this.language,
  }) : super(key: key);

  @override
  _TestPageState createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<DocumentSnapshot> _questions = [];
  int _currentQuestionIndex = 0;
  List<int?> _selectedAnswers = [];
  int _correctAnswers = 0;
  double _duration = 0;
  int _timeRemaining = 0;
  bool _isLoading = true;
  bool _testFinished = false;
  bool _timerStarted = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Получаем данные категории (в частности, duration)
      DocumentSnapshot categoryDoc = await _firestore
          .collection('test_types')
          .doc(widget.testTypeId)
          .collection('categories')
          .doc(widget.categoryId)
          .get();
      if (!categoryDoc.exists) {
        debugPrint('TestPage: Категория не найдена: testTypeId=${widget.testTypeId}, categoryId=${widget.categoryId}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Категория не найдена')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      _duration = (categoryDoc['duration'] as num).toDouble();
      _timeRemaining = (_duration * 60).toInt();
      debugPrint('TestPage: Длительность теста: $_duration минут');

      // Получаем использованные вопросы пользователя
      List<String> usedQuestionIds = [];
      final user = _auth.currentUser;
      if (user != null) {
        QuerySnapshot usedQuestions = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('used_questions')
            .where('test_type_id', isEqualTo: widget.testTypeId)
            .where('category_id', isEqualTo: widget.categoryId)
            .where('language', isEqualTo: widget.language)
            .get();
        usedQuestionIds = usedQuestions.docs.map((doc) => doc['question_id'] as String).toList();
        debugPrint('TestPage: Использованные вопросы: $usedQuestionIds');
      }

      // Загружаем вопросы, исключая использованные
      QuerySnapshot questionsSnapshot = await _firestore
          .collection('test_types')
          .doc(widget.testTypeId)
          .collection('categories')
          .doc(widget.categoryId)
          .collection('questions')
          .where('language', isEqualTo: widget.language)
          .orderBy('order')
          .get();

      debugPrint('TestPage: Всего вопросов в Firestore: ${questionsSnapshot.docs.length}');
      List<DocumentSnapshot> questions = questionsSnapshot.docs
          .where((doc) => !usedQuestionIds.contains(doc.id))
          .toList();
      debugPrint('TestPage: Доступных вопросов после фильтрации: ${questions.length}');

      // Если вопросов меньше 30, берём все доступные
      _questions = questions.length > 30 ? questions.sublist(0, 30) : questions;
      _selectedAnswers = List<int?>.filled(_questions.length, null);

      // Сохраняем использованные вопросы
      if (user != null && _questions.isNotEmpty) {
        for (var question in _questions) {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('used_questions')
              .add({
            'test_type_id': widget.testTypeId,
            'category_id': widget.categoryId,
            'language': widget.language,
            'question_id': question.id,
          });
        }
        debugPrint('TestPage: Сохранены использованные вопросы');
      }

      setState(() {
        _isLoading = false;
        _timerStarted = true;
      });

      if (_questions.isEmpty) {
        debugPrint('TestPage: Нет доступных вопросов для отображения');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет доступных вопросов')),
        );
      } else {
        _startTimer();
      }
    } catch (e) {
      debugPrint('TestPage: Ошибка загрузки вопросов: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки вопросов: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_timeRemaining > 0 && !_testFinished && mounted) {
        setState(() {
          _timeRemaining--;
        });
        _startTimer();
      } else if (_timeRemaining <= 0 && !_testFinished) {
        _finishTest();
      }
    });
  }

  void _selectAnswer(int answerIndex) {
    setState(() {
      _selectedAnswers[_currentQuestionIndex] = answerIndex;
    });
  }

  void _nextQuestion() {
    if (_selectedAnswers[_currentQuestionIndex] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите ответ перед продолжением')),
      );
      return;
    }

    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      _finishTest();
    }
  }

  void _finishTest() async {
    setState(() {
      _testFinished = true;
    });

    for (int i = 0; i < _questions.length; i++) {
      if (_selectedAnswers[i] == _questions[i]['correct_answer']) {
        _correctAnswers++;
      }
    }

    DocumentSnapshot categoryDoc = await _firestore
        .collection('test_types')
        .doc(widget.testTypeId)
        .collection('categories')
        .doc(widget.categoryId)
        .get();
    double pointsPerQuestion = (categoryDoc['points_per_question'] as num).toDouble();
    double totalPoints = _correctAnswers * pointsPerQuestion;

    final user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot testTypeDoc = await _firestore.collection('test_types').doc(widget.testTypeId).get();
      String testTypeName = testTypeDoc['name'] as String;
      String categoryName = categoryDoc['name'] as String;

      await _firestore.collection('users').doc(user.uid).collection('test_history').add({
        'date': DateTime.now().toIso8601String(),
        'test_type': testTypeName,
        'category': categoryName,
        'correct_answers': _correctAnswers,
        'total_questions': _questions.length,
        'points': totalPoints,
        'time_spent': (_duration * 60 - _timeRemaining).toInt(),
        'total_time': (_duration * 60).toInt(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_questions.isEmpty) {
      return const Center(child: Text('Вопросы не найдены'));
    }

    if (_testFinished) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Тест завершён!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('Правильных ответов: $_correctAnswers из ${_questions.length}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Вернуться'),
            ),
          ],
        ),
      );
    }

    final question = _questions[_currentQuestionIndex];
    final options = List<String>.from(question['options']);
    final correctAnswer = question['correct_answer'] as int;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Вопрос ${_currentQuestionIndex + 1} из ${_questions.length}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Оставшееся время: ${_timeRemaining ~/ 60}:${(_timeRemaining % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 16, color: Colors.red),
          ),
          const SizedBox(height: 16),
          Text(
            question['text'] as String,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          ...options.asMap().entries.map((entry) {
            int index = entry.key;
            String option = entry.value;
            return RadioListTile<int>(
              title: Text(option),
              value: index,
              groupValue: _selectedAnswers[_currentQuestionIndex],
              onChanged: (value) => _selectAnswer(value!),
            );
          }).toList(),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: _nextQuestion,
              child: Text(_currentQuestionIndex < _questions.length - 1 ? 'Далее' : 'Завершить'),
            ),
          ),
        ],
      ),
    );
  }
}

class TrainingPage extends StatelessWidget {
  const TrainingPage({Key? key}) : super(key: key);

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