import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Добавляем импорт
import 'settings.dart';
import 'contests.dart';
import 'training.dart';
import 'history.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  final Function(String) onThemeChanged;

  const HomePage({super.key, required this.onThemeChanged});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late final List<Widget> _pages;
  String _currentTheme = 'light';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
    _animationController.forward();
    _pages = [
      const TestSelectionPage(),
      const TrainingPage(),
      const ContestsPage(),
      const HistoryPage(),
      SettingsPage(onThemeChanged: widget.onThemeChanged),
    ];
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentTheme = prefs.getString('theme') ?? 'light';
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _animationController.reset();
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Тестировочная платформа',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: _currentTheme == 'light' ? Colors.white : const Color(0xFF1A0033),
        elevation: 0,
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _pages[_selectedIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: _currentTheme == 'light' ? Colors.white : const Color(0xFF1A0033),
        selectedItemColor: _currentTheme == 'light' ? const Color(0xFFFF6F61) : const Color(0xFF8E2DE2),
        unselectedItemColor: _currentTheme == 'light' ? Colors.grey : Colors.white70,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
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

class TestSelectionPageState extends State<TestSelectionPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<String> _selectedTestTypeIds = [];
  Map<String, String?> _selectedLanguages = {};
  Map<String, List<Map<String, String>>> _availableLanguages = {};
  List<Map<String, String>> _testTypes = [];
  String? _selectedTestTypeId;
  String _currentTheme = 'light';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
    _loadTestTypes();
    _loadSelectedTests();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentTheme = prefs.getString('theme') ?? 'light';
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
    _animationController.reset();
    _animationController.forward();
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _currentTheme == 'light'
              ? [Colors.white, const Color(0xFFF5E6FF)]
              : [const Color(0xFF1A0033), const Color(0xFF2E004F)],
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
                  Text(
                    'Прохождение тестов',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 20),
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
                      prefixIcon: Icon(Icons.quiz, color: _currentTheme == 'light' ? Colors.grey : Colors.white70),
                      filled: true,
                      fillColor: _currentTheme == 'light' ? Colors.grey[100] : Colors.white.withOpacity(0.08),
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
                          color: _currentTheme == 'light' ? const Color(0xFFFF6F61) : const Color(0xFF8E2DE2),
                          width: 2,
                        ),
                      ),
                    ),
                    style: TextStyle(color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white),
                    dropdownColor: _currentTheme == 'light' ? Colors.white : const Color(0xFF2E004F),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: _buildAnimatedButton(
                      onPressed: _addTestType,
                      gradientColors: _currentTheme == 'light'
                          ? [const Color(0xFFFF6F61), const Color(0xFFFFB74D)]
                          : [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)],
                      label: 'Добавить тест',
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_selectedTestTypeIds.isNotEmpty) ...[
                    Text(
                      'Выбранные тесты:',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: _selectedTestTypeIds.map((testTypeId) {
                        final testTypeName = _testTypes
                            .firstWhere((testType) => testType['id'] == testTypeId)['name']!;
                        final languages = _availableLanguages[testTypeId] ?? [];
                        final selectedLanguage = _selectedLanguages[testTypeId];

                        return Card(
                          color: _currentTheme == 'light' ? Colors.white : Colors.white.withOpacity(0.05),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: _currentTheme == 'light' ? Colors.grey[200]! : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          elevation: _currentTheme == 'light' ? 8 : 0,
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
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
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
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
                                                prefixIcon: Icon(Icons.language,
                                                    color: _currentTheme == 'light' ? Colors.grey : Colors.white70),
                                                filled: true,
                                                fillColor: _currentTheme == 'light'
                                                    ? Colors.grey[100]
                                                    : Colors.white.withOpacity(0.08),
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
                                              style: TextStyle(
                                                  color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white),
                                              dropdownColor: _currentTheme == 'light' ? Colors.white : const Color(0xFF2E004F),
                                            )
                                          else
                                            Text(
                                              'Языки загружаются...',
                                              style: TextStyle(
                                                  color: _currentTheme == 'light' ? Colors.grey : Colors.white70),
                                            ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.close,
                                          color: _currentTheme == 'light' ? Colors.grey : Colors.white70, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          _selectedTestTypeIds.remove(testTypeId);
                                          _selectedLanguages.remove(testTypeId);
                                          _availableLanguages.remove(testTypeId);
                                        });
                                        _saveSelectedTests();
                                        _animationController.reset();
                                        _animationController.forward();
                                      },
                                    ),
                                  ],
                                ),
                                if (selectedLanguage != null) ...[
                                  const SizedBox(height: 12),
                                  _buildAnimatedButton(
                                    onPressed: () => _startTest(testTypeId, selectedLanguage),
                                    gradientColors: _currentTheme == 'light'
                                        ? [const Color(0xFF4A90E2), const Color(0xFF50C9C3)]
                                        : [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)],
                                    label: 'Начать тест',
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

class TestPageState extends State<TestPage> with SingleTickerProviderStateMixin {
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
  Timer? _timer;

  final List<DocumentSnapshot> _allQuestions = [];
  final List<int?> _allSelectedAnswers = [];
  final List<String> _allCorrectAnswers = [];
  final List<String> _categoryNames = [];
  final List<int> _questionsPerCategory = [];
  final List<double> _pointsPerQuestionByCategory = [];
  double _totalPoints = 0;
  String? _testId;
  String _currentTheme = 'light';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  get pesticulate => null;

  @override
  void initState() {
    super.initState();
    _testId = DateTime.now().millisecondsSinceEpoch.toString();
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
    _loadCategories();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentTheme = prefs.getString('theme') ?? 'light';
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
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
      _animationController.reset();
      _animationController.forward();
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
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining > 0 && !_entireTestFinished && mounted) {
        setState(() {
          _timeRemaining--;
        });
      } else if (_timeRemaining <= 0 && !_entireTestFinished) {
        _finishCategory();
        timer.cancel();
      } else {
        timer.cancel();
      }
    });
  }

  void _selectAnswer(int questionIndex, int answerIndex) {
    setState(() {
      _selectedAnswers[questionIndex] = answerIndex;
    });
  }

  Future<void> _finishCategory() async {
    _timer?.cancel();
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

    if (_currentCategoryIndex + 1 < _categories.length) {
      setState(() {
        _currentCategoryIndex++;
      });
      await _loadQuestionsForCurrentCategory();
    } else {
      _finishEntireTest();
    }
  }

  Future<void> _finishEntireTest() async {
    _timer?.cancel();
    if (mounted) {
      setState(() {
        _entireTestFinished = true;
      });
    }

    await _saveTestResult();

    if (mounted) {
      setState(() {});
      _animationController.reset();
      _animationController.forward();
    }
  }

  Future<void> _saveTestResult() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      DocumentSnapshot testTypeDoc = await _firestore.collection('test_types').doc(widget.testTypeId).get();
      String testTypeName = testTypeDoc['name'] as String;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('test_history')
          .doc(_testId)
          .set({
        'test_type': testTypeName,
        'date': DateTime.now().toIso8601String(),
      });

      for (int categoryIndex = 0; categoryIndex < _categoryNames.length; categoryIndex++) {
        String categoryName = _categoryNames[categoryIndex];
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

        double categoryPoints = categoryCorrectAnswers * pointsPerQuestion;
        int categoryTimeSpent = (_duration * 60 - _timeRemaining).toInt();
        int categoryTotalTime = (_duration * 60).toInt();

        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('test_history')
            .doc(_testId)
            .collection('categories')
            .add({
          'category': categoryName,
          'correct_answers': categoryCorrectAnswers,
          'total_questions': _questionsPerCategory[categoryIndex],
          'points': categoryPoints,
          'time_spent': categoryTimeSpent,
          'total_time': categoryTotalTime,
        });

        if (widget.contestId != null) {
          await _firestore
              .collection('contest_results')
              .doc(widget.contestId)
              .collection('results')
              .doc(user.uid)
              .set({
            'correct_answers': categoryCorrectAnswers,
            'total_questions': _questionsPerCategory[categoryIndex],
            'points': categoryPoints,
            'time_spent': categoryTimeSpent,
            'completed_at': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      debugPrint('TestPage: Ошибка сохранения результатов теста: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения результатов: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Тест',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: _currentTheme == 'light' ? Colors.white : const Color(0xFF1A0033),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white),
          onPressed: () {
            _timer?.cancel();
            Navigator.pop(context);
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _currentTheme == 'light'
                ? [Colors.white, const Color(0xFFF5E6FF)]
                : [const Color(0xFF1A0033), const Color(0xFF2E004F)],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_questions.isEmpty && !_entireTestFinished)
                      Center(
                        child: Text(
                          'Вопросы не найдены',
                          style: TextStyle(
                            color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      )
                    else if (_entireTestFinished) ...[
                      Text(
                        'ТЕСТ ЗАВЕРШЁН',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        color: _currentTheme == 'light' ? Colors.white : Colors.white.withOpacity(0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: _currentTheme == 'light' ? Colors.grey[200]! : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        elevation: _currentTheme == 'light' ? 8 : 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    color: _currentTheme == 'light' ? Colors.green : Colors.greenAccent,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Правильных ответов: $_correctAnswers из ${_allQuestions.length}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.star_border,
                                    color: _currentTheme == 'light' ? Colors.amber : Colors.amberAccent,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Всего баллов: ${_totalPoints.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Результаты:',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
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
                            Card(
                              color: _currentTheme == 'light' ? Colors.white : Colors.white.withOpacity(0.05),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: _currentTheme == 'light' ? Colors.grey[200]! : Colors.transparent,
                                  width: 1,
                                ),
                              ),
                              elevation: _currentTheme == 'light' ? 8 : 0,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.category,
                                      color: _currentTheme == 'light' ? Colors.grey : Colors.white70,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '$categoryName: $categoryCorrectAnswers/${endIndex - startIndex} правильных',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._allQuestions.asMap().entries.where((entry) => entry.key >= startIndex && entry.key < endIndex).map((entry) {
                              int index = entry.key;
                              DocumentSnapshot question = entry.value;
                              final options = (question['options'] as List).map((option) => option.toString()).toList();
                              String correctAnswer = _allCorrectAnswers[index];
                              int? userAnswerIndex = _allSelectedAnswers[index];
                              String? userAnswer = userAnswerIndex != null ? options[userAnswerIndex] : null;
                              String explanation = question['explanation'] as String? ?? pesticulate; 'Объяснение отсутствует';

                              bool isCorrect = userAnswer == correctAnswer;

                              return Card(
                                color: _currentTheme == 'light' ? Colors.white : Colors.white.withOpacity(0.05),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  side: BorderSide(
                                    color: _currentTheme == 'light' ? Colors.grey[200]! : Colors.transparent,
                                    width: 1,
                                  ),
                                ),
                                elevation: _currentTheme == 'light' ? 5 : 0,
                                margin: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Вопрос ${index - startIndex + 1}: ${question['text']}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                        ),
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
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontStyle: FontStyle.italic,
                                          color: _currentTheme == 'light' ? Colors.grey : Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                            const SizedBox(height: 16),
                          ],
                        );
                      }).toList(),
                      const SizedBox(height: 20),
                      _buildAnimatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        gradientColors: _currentTheme == 'light'
                            ? [const Color(0xFFFF6F61), const Color(0xFFFFB74D)]
                            : [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)],
                        label: 'Вернуться',
                      ),
                    ]
                    else ...[
                      Builder(
                        builder: (BuildContext context) {
                          final category = _categories[_currentCategoryIndex];

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Card(
                                color: _currentTheme == 'light' ? Colors.white : Colors.white.withOpacity(0.05),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: _currentTheme == 'light' ? Colors.grey[200]! : Colors.transparent,
                                    width: 1,
                                  ),
                                ),
                                elevation: _currentTheme == 'light' ? 8 : 0,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.category,
                                        color: _currentTheme == 'light' ? Colors.grey : Colors.white70,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Категория: ${category['name']}',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Card(
                                color: _currentTheme == 'light' ? Colors.white : Colors.white.withOpacity(0.05),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  side: BorderSide(
                                    color: _currentTheme == 'light' ? Colors.grey[200]! : Colors.transparent,
                                    width: 1,
                                  ),
                                ),
                                elevation: _currentTheme == 'light' ? 5 : 0,
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.timer,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Оставшееся время: ${_timeRemaining ~/ 60}:${(_timeRemaining % 60).toString().padLeft(2, '0')}',
                                        style: const TextStyle(fontSize: 16, color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              ..._questions.asMap().entries.map((entry) {
                                int questionIndex = entry.key;
                                DocumentSnapshot question = entry.value;

                                final rawOptions = question['options'];
                                final options = rawOptions != null && rawOptions is List
                                    ? rawOptions.map((option) => option.toString()).toList()
                                    : <String>[];

                                if (options.isEmpty) {
                                  return Center(
                                    child: Text(
                                      'Ошибка: Вопрос не содержит вариантов ответа. Обратитесь к администратору.',
                                      style: TextStyle(
                                        color: _currentTheme == 'light' ? Colors.red : Colors.redAccent,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                }

                                return Card(
                                  color: _currentTheme == 'light' ? Colors.white : Colors.white.withOpacity(0.05),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    side: BorderSide(
                                      color: _currentTheme == 'light' ? Colors.grey[200]! : Colors.transparent,
                                      width: 1,
                                    ),
                                  ),
                                  elevation: _currentTheme == 'light' ? 5 : 0,
                                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Вопрос ${questionIndex + 1}: ${question['text']}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        ...options.asMap().entries.map((optionEntry) {
                                          int optionIndex = optionEntry.key;
                                          String option = optionEntry.value;
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                                            child: RadioListTile<int>(
                                              title: Text(
                                                option,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                                ),
                                              ),
                                              value: optionIndex,
                                              groupValue: _selectedAnswers[questionIndex],
                                              onChanged: (value) => _selectAnswer(questionIndex, value!),
                                              contentPadding: EdgeInsets.zero,
                                              activeColor: _currentTheme == 'light'
                                                  ? const Color(0xFFFF6F61)
                                                  : const Color(0xFF8E2DE2),
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                              const SizedBox(height: 20),
                              Center(
                                child: _buildAnimatedButton(
                                  onPressed: _finishCategory,
                                  gradientColors: _currentTheme == 'light'
                                      ? [const Color(0xFF4A90E2), const Color(0xFF50C9C3)]
                                      : [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)],
                                  label: 'Закончил категорию',
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
}