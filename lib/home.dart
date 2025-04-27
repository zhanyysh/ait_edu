import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _isLoading = true;

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
    _loadTheme();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    await _loadTestTypes();
    await _loadSelectedTests();
    setState(() {
      _isLoading = false;
    });
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
              _selectedTestTypeIds = selectedTests
                  .map((test) => test['test_type_id'] as String)
                  .where((testTypeId) =>
                      _testTypes.any((testType) => testType['id'] == testTypeId))
                  .toList();
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
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
                              final testType = _testTypes.firstWhere(
                                (testType) => testType['id'] == testTypeId,
                                orElse: () => {'id': testTypeId, 'name': 'Неизвестный тест'},
                              );
                              final testTypeName = testType['name']!;
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
  Map<String, Map<String, dynamic>> _readingTexts = {};
  List<dynamic> _selectedAnswers = [];
  int _correctAnswers = 0;
  double _duration = 0;
  int _timeRemaining = 0;
  bool _isLoading = true;
  bool _entireTestFinished = false;
  Timer? _timer;
  String _testType = 'multiple-choice';

  final List<DocumentSnapshot> _allQuestions = [];
  final List<dynamic> _allSelectedAnswers = [];
  final List<String> _allCorrectAnswers = [];
  final List<String> _categoryNames = [];
  final List<int> _questionsPerCategory = [];
  final List<double> _pointsPerQuestionByCategory = [];
  final List<String> _testTypesByCategory = [];
  double _totalPoints = 0;
  String? _testId;
  String _currentTheme = 'light';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
      _readingTexts = {};
    });

    try {
      DocumentSnapshot categoryDoc = _categories[_currentCategoryIndex];
      String categoryId = categoryDoc.id;
      _testType = categoryDoc['test_type'] as String? ?? 'multiple-choice';
      _duration = (categoryDoc['duration'] as num?)?.toDouble() ?? 0.0;
      int numberOfQuestions = (categoryDoc['number_of_questions'] as int?) ?? 30;
      _timeRemaining = (_duration * 60).toInt();

      debugPrint('TestPage: Загрузка вопросов для testTypeId=${widget.testTypeId}, categoryId=$categoryId, language=${widget.language}, testType=$_testType');
      debugPrint('TestPage: Количество вопросов для категории: $numberOfQuestions');

      if (_testType == 'reading') {
        QuerySnapshot textsSnapshot = await _firestore
            .collection('test_types')
            .doc(widget.testTypeId)
            .collection('categories')
            .doc(categoryId)
            .collection('texts')
            .where('language', isEqualTo: widget.language)
            .get();

        _readingTexts = {
          for (var doc in textsSnapshot.docs)
            doc.id: {
              'id': doc.id,
              'title': doc['title'] as String?,
              'content': doc['content'] as String? ?? 'Текст отсутствует',
            }
        };

        debugPrint('TestPage: Загружено текстов для reading: ${_readingTexts.length}');
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
          .where((doc) {
            if (_testType == 'multiple-choice' || _testType == 'reading') {
              return doc['options'] != null && (doc['options'] as List).isNotEmpty;
            }
            return true;
          })
          .toList();

      debugPrint('TestPage: Доступных вопросов: ${questions.length}');

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

      // Рандомизация вопросов
      questions.shuffle(Random());
      _questions = questions.length > numberOfQuestions
          ? questions.sublist(0, numberOfQuestions)
          : questions;

      debugPrint('TestPage: Итоговое количество вопросов для теста: ${_questions.length}');

      _selectedAnswers = List<dynamic>.filled(
        _questions.length,
        _testType == 'writing' ? '' : null,
      );

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

  void _selectAnswer(int questionIndex, dynamic answer) {
    setState(() {
      _selectedAnswers[questionIndex] = answer;
    });
  }

  Future<void> _finishCategory() async {
    _timer?.cancel();
    if (_selectedAnswers.contains(null) || (_testType == 'writing' && _selectedAnswers.any((answer) => (answer as String).isEmpty))) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ответьте на все вопросы перед продолжением')),
        );
      }
      return;
    }

    DocumentSnapshot categoryDoc = _categories[_currentCategoryIndex];
    String categoryName = categoryDoc['name'] as String? ?? 'Неизвестная категория';
    double pointsPerQuestion = (categoryDoc['points_per_question'] as num?)?.toDouble() ?? 0.0;

    _categoryNames.add(categoryName);
    _pointsPerQuestionByCategory.add(pointsPerQuestion);
    _questionsPerCategory.add(_questions.length);
    _testTypesByCategory.add(_testType);

    int categoryCorrectAnswers = 0;
    for (int i = 0; i < _questions.length; i++) {
      DocumentSnapshot question = _questions[i];
      String? correctAnswer = question['correct_answer'] as String?;
      String? readingTextId = question['reading_text_id'] as String?;
      dynamic userAnswer = _selectedAnswers[i];
      _allQuestions.add(question);
      _allCorrectAnswers.add(correctAnswer ?? '');
      _allSelectedAnswers.add(userAnswer);

      if (_testType == 'multiple-choice' || _testType == 'reading') {
        final options = (question['options'] as List?)?.map((option) => option.toString()).toList() ?? [];
        String? userAnswerText = userAnswer != null && options.isNotEmpty ? options[userAnswer as int] : null;
        if (userAnswerText == correctAnswer) {
          _correctAnswers++;
          categoryCorrectAnswers++;
        }
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
      String testTypeName = testTypeDoc.exists ? (testTypeDoc['name'] as String? ?? 'Неизвестный тест') : 'Неизвестный тест';

      String? contestName;
      if (widget.contestId != null) {
        DocumentSnapshot contestDoc = await _firestore.collection('contests').doc(widget.contestId).get();
        if (contestDoc.exists) {
          contestName = 'Контест: $testTypeName (${contestDoc['language'] ?? 'Не указан'})';
        }
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('test_history')
          .doc(_testId)
          .set({
        'test_type': testTypeName,
        'date': DateTime.now().toIso8601String(),
        'is_contest': widget.contestId != null,
        'contest_id': widget.contestId,
        'contest_name': contestName ?? testTypeName,
      });

      for (int categoryIndex = 0; categoryIndex < _categoryNames.length; categoryIndex++) {
        String categoryName = _categoryNames[categoryIndex];
        String categoryTestType = _testTypesByCategory[categoryIndex];
        double pointsPerQuestion = _pointsPerQuestionByCategory[categoryIndex];
        int startIndex = categoryIndex == 0
            ? 0
            : _questionsPerCategory.sublist(0, categoryIndex).fold(0, (sum, count) => sum + count);
        int endIndex = startIndex + _questionsPerCategory[categoryIndex];

        int categoryCorrectAnswers = 0;
        List<Map<String, dynamic>> answers = [];
        for (int i = startIndex; i < endIndex; i++) {
          DocumentSnapshot question = _allQuestions[i];
          String? correctAnswer = _allCorrectAnswers[i];
          dynamic userAnswer = _allSelectedAnswers[i];
          String? readingTextId = question['reading_text_id'] as String?;
          String? answerText = (question.data() as Map<String, dynamic>?)?.containsKey('answer_text') == true
              ? question['answer_text'] as String?
              : null;

          if (categoryTestType == 'multiple-choice' || categoryTestType == 'reading') {
            final options = (question['options'] as List?)?.map((option) => option.toString()).toList() ?? [];
            String? userAnswerText = userAnswer != null && options.isNotEmpty ? options[userAnswer as int] : null;
            if (userAnswerText == correctAnswer) {
              categoryCorrectAnswers++;
            }
            answers.add({
              'question_id': question.id,
              'user_answer': userAnswerText,
              'correct_answer': correctAnswer,
              'reading_text_id': readingTextId,
              'is_correct': userAnswerText == correctAnswer,
            });
          } else if (categoryTestType == 'writing') {
            answers.add({
              'question_id': question.id,
              'user_answer': userAnswer as String? ?? '',
              'correct_answer': answerText,
              'reading_text_id': null,
              'is_correct': null,
            });
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
          'test_type': categoryTestType,
          'correct_answers': categoryCorrectAnswers,
          'total_questions': _questionsPerCategory[categoryIndex],
          'points': categoryPoints,
          'time_spent': categoryTimeSpent,
          'total_time': categoryTotalTime,
          'answers': answers,
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
            'test_type': categoryTestType,
            'answers': answers,
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
                        String categoryTestType = _testTypesByCategory[categoryIndex];
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
                          dynamic userAnswer = _allSelectedAnswers[i];
                          if (categoryTestType == 'multiple-choice' || categoryTestType == 'reading') {
                            final options = (_allQuestions[i]['options'] as List?)?.map((option) => option.toString()).toList() ?? [];
                            String? userAnswerText = userAnswer != null && options.isNotEmpty ? options[userAnswer as int] : null;
                            if (userAnswerText == correctAnswer) {
                              categoryCorrectAnswers++;
                            }
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
                              String questionText = question['text'] as String? ?? 'Вопрос отсутствует';
                              String? correctAnswer = _allCorrectAnswers[index];
                              dynamic userAnswer = _allSelectedAnswers[index];
                              String? readingTextId = question['reading_text_id'] as String?;
                              String? explanation = question['explanation'] as String? ?? 'Объяснение отсутствует';
                              bool isCorrect = false;

                              String? userAnswerText;
                              if (categoryTestType == 'multiple-choice' || categoryTestType == 'reading') {
                                final options = (question['options'] as List?)?.map((option) => option.toString()).toList() ?? [];
                                userAnswerText = userAnswer != null && options.isNotEmpty ? options[userAnswer as int] : null;
                                isCorrect = userAnswerText == correctAnswer;
                              } else if (categoryTestType == 'writing') {
                                userAnswerText = userAnswer as String? ?? 'Не введено';
                              }

                              String? readingTextContent;
                              String? readingTextTitle;
                              if (readingTextId != null) {
                                final text = _readingTexts[readingTextId] ?? {'title': null, 'content': 'Текст не найден'};
                                readingTextTitle = text['title'] as String?;
                                readingTextContent = text['content'] as String? ?? 'Текст отсутствует';
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
                                      if (readingTextId != null) ...[
                                        Text(
                                          readingTextTitle ?? 'Текст',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          readingTextContent!,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: _currentTheme == 'light' ? Colors.grey[800] : Colors.white70,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                      Text(
                                        'Вопрос ${index - startIndex + 1}: $questionText',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Ваш ответ: ${userAnswerText ?? 'Не выбран'}',
                                        style: TextStyle(
                                          color: categoryTestType == 'writing'
                                              ? (_currentTheme == 'light' ? Colors.grey : Colors.white70)
                                              : isCorrect
                                                  ? Colors.green
                                                  : Colors.red,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (categoryTestType != 'writing') ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Правильный ответ: ${correctAnswer ?? 'Не указан'}',
                                          style: const TextStyle(fontSize: 14, color: Colors.green),
                                        ),
                                      ],
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
                                          'Категория: ${category['name']} (${_testType.toUpperCase()})',
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
                              if (_testType == 'reading' && _readingTexts.isNotEmpty)
                                ..._readingTexts.entries.map((entry) {
                                  String textId = entry.key;
                                  Map<String, dynamic> text = entry.value;
                                  String? textTitle = text['title'] as String?;
                                  String textContent = text['content'] as String;
                                  List<DocumentSnapshot> textQuestions = _questions
                                      .where((q) => q['reading_text_id'] == textId)
                                      .toList();

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ExpansionTile(
                                        title: Text(
                                          textTitle ?? 'Текст для чтения',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                          ),
                                        ),
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Text(
                                              textContent,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: _currentTheme == 'light' ? Colors.grey[800] : Colors.white70,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      ...textQuestions.asMap().entries.map((entry) {
                                        int questionIndex = _questions.indexOf(entry.value);
                                        DocumentSnapshot question = entry.value;
                                        String questionText = question['text'] as String? ?? 'Вопрос отсутствует';
                                        final options = (question['options'] as List?)?.map((option) => option.toString()).toList() ?? [];

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
                                                  'Вопрос ${questionIndex + 1}: $questionText',
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
                                                      groupValue: _selectedAnswers[questionIndex] as int?,
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
                                    ],
                                  );
                                }).toList(),
                              if (_testType == 'multiple-choice' || _testType == 'writing')
                                ..._questions.asMap().entries.map((entry) {
                                  int questionIndex = entry.key;
                                  DocumentSnapshot question = entry.value;
                                  String questionText = question['text'] as String? ?? 'Вопрос отсутствует';

                                  if (_testType == 'multiple-choice') {
                                    final options = (question['options'] as List?)?.map((option) => option.toString()).toList() ?? [];

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
                                              'Вопрос ${questionIndex + 1}: $questionText',
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
                                                  groupValue: _selectedAnswers[questionIndex] as int?,
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
                                  } else if (_testType == 'writing') {
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
                                              'Вопрос ${questionIndex + 1}: $questionText',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            TextField(
                                              maxLines: 5,
                                              decoration: InputDecoration(
                                                hintText: 'Введите ваш ответ',
                                                hintStyle: TextStyle(
                                                  color: _currentTheme == 'light' ? Colors.grey : Colors.white70,
                                                ),
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
                                                color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                              ),
                                              onChanged: (value) {
                                                _selectAnswer(questionIndex, value);
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
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