import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrainingPage extends StatefulWidget {
  const TrainingPage({super.key});

  @override
  _TrainingPageState createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, int?> _selectedAnswers = {};
  final Map<String, bool> _submittedAnswers = {};
  final Map<String, bool> _isCorrect = {};
  String? _selectedLanguage;
  List<Map<String, String>> _availableLanguages = [];
  final Map<String, bool> _isExpanded = {};
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
    _loadUserPreferredLanguage();
    _loadAvailableLanguages();
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Text(
                  'Обучающие материалы',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_availableLanguages.isNotEmpty)
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: DropdownButtonFormField<String>(
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
                      _animationController.reset();
                      _animationController.forward();
                    },
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.language, color: _currentTheme == 'light' ? Colors.grey : Colors.white70),
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
                ),
              ),
            const SizedBox(height: 20),
            if (_selectedLanguage != null)
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('test_types').snapshots(),
                  builder: (context, testTypesSnapshot) {
                    if (testTypesSnapshot.hasError) {
                      return Center(
                        child: Text(
                          'Ошибка: ${testTypesSnapshot.error}',
                          style: TextStyle(
                            color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                          ),
                        ),
                      );
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
                        return FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: Card(
                              color: _currentTheme == 'light' ? Colors.white : Colors.white.withOpacity(0.05),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: _currentTheme == 'light' ? Colors.grey[200]! : Colors.transparent,
                                  width: 1,
                                ),
                              ),
                              elevation: _currentTheme == 'light' ? 8 : 0,
                              child: ExpansionTile(
                                key: Key(testTypeKey),
                                initiallyExpanded: _isExpanded[testTypeKey] ?? false,
                                onExpansionChanged: (expanded) {
                                  setState(() {
                                    _isExpanded[testTypeKey] = expanded;
                                  });
                                  _animationController.reset();
                                  _animationController.forward();
                                },
                                leading: Icon(
                                  Icons.book,
                                  color: _currentTheme == 'light' ? Colors.grey : Colors.white70,
                                ),
                                title: Text(
                                  testTypeName,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                  ),
                                ),
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
                                        return Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            'Ошибка: ${materialsSnapshot.error}',
                                            style: TextStyle(
                                              color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                            ),
                                          ),
                                        );
                                      }
                                      if (materialsSnapshot.connectionState == ConnectionState.waiting) {
                                        return const Center(child: CircularProgressIndicator());
                                      }
                                      final materials = materialsSnapshot.data!.docs;
                                      if (materials.isEmpty) {
                                        return Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            'Нет материалов',
                                            style: TextStyle(
                                              color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                            ),
                                          ),
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
                                            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                            child: ExpansionTile(
                                              key: Key(materialKey),
                                              initiallyExpanded: _isExpanded[materialKey] ?? false,
                                              onExpansionChanged: (expanded) {
                                                setState(() {
                                                  _isExpanded[materialKey] = expanded;
                                                });
                                                _animationController.reset();
                                                _animationController.forward();
                                              },
                                              leading: Icon(
                                                Icons.article,
                                                color: _currentTheme == 'light' ? Colors.grey : Colors.white70,
                                              ),
                                              title: Text(
                                                title,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                                ),
                                              ),
                                              subtitle: Text(
                                                content,
                                                style: TextStyle(
                                                  color: _currentTheme == 'light' ? Colors.grey : Colors.white70,
                                                  fontSize: 14,
                                                ),
                                              ),
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
                                                      return Padding(
                                                        padding: const EdgeInsets.all(8.0),
                                                        child: Text(
                                                          'Ошибка: ${miniTestsSnapshot.error}',
                                                          style: TextStyle(
                                                            color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                    if (miniTestsSnapshot.connectionState == ConnectionState.waiting) {
                                                      return const Center(child: CircularProgressIndicator());
                                                    }
                                                    final miniTests = miniTestsSnapshot.data!.docs;
                                                    if (miniTests.isEmpty) {
                                                      return Padding(
                                                        padding: const EdgeInsets.all(8.0),
                                                        child: Text(
                                                          'Нет мини-тестов',
                                                          style: TextStyle(
                                                            color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                                          ),
                                                        ),
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

                                                        return FadeTransition(
                                                          opacity: _fadeAnimation,
                                                          child: SlideTransition(
                                                            position: _slideAnimation,
                                                            child: Padding(
                                                              padding: const EdgeInsets.all(8.0),
                                                              child: Card(
                                                                color: _currentTheme == 'light'
                                                                    ? Colors.white
                                                                    : Colors.white.withOpacity(0.05),
                                                                shape: RoundedRectangleBorder(
                                                                  borderRadius: BorderRadius.circular(15),
                                                                  side: BorderSide(
                                                                    color: _currentTheme == 'light'
                                                                        ? Colors.grey[200]!
                                                                        : Colors.transparent,
                                                                    width: 1,
                                                                  ),
                                                                ),
                                                                elevation: _currentTheme == 'light' ? 5 : 0,
                                                                child: Padding(
                                                                  padding: const EdgeInsets.all(16.0),
                                                                  child: Column(
                                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                                    children: [
                                                                      Text(
                                                                        'Мини-тест ${index + 1}: $questionText',
                                                                        style: TextStyle(
                                                                          fontSize: 16,
                                                                          fontWeight: FontWeight.bold,
                                                                          color: _currentTheme == 'light'
                                                                              ? const Color(0xFF2E2E2E)
                                                                              : Colors.white,
                                                                        ),
                                                                      ),
                                                                      const SizedBox(height: 12),
                                                                      ...options.asMap().entries.map((optionEntry) {
                                                                        final optionIndex = optionEntry.key;
                                                                        final option = optionEntry.value;
                                                                        return RadioListTile<int>(
                                                                          title: Text(
                                                                            option,
                                                                            style: TextStyle(
                                                                              fontSize: 16,
                                                                              color: _currentTheme == 'light'
                                                                                  ? const Color(0xFF2E2E2E)
                                                                                  : Colors.white,
                                                                            ),
                                                                          ),
                                                                          value: optionIndex,
                                                                          groupValue: _selectedAnswers[answerKey],
                                                                          onChanged: _submittedAnswers[answerKey] == true
                                                                              ? null
                                                                              : (value) {
                                                                                  setState(() {
                                                                                    _selectedAnswers[answerKey] = value;
                                                                                    _submittedAnswers[answerKey] = true;
                                                                                    _isCorrect[answerKey] =
                                                                                        options[value!] == correctAnswer;
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
                                                                          contentPadding: EdgeInsets.zero,
                                                                          activeColor: _currentTheme == 'light'
                                                                              ? const Color(0xFFFF6F61)
                                                                              : const Color(0xFF8E2DE2),
                                                                        );
                                                                      }).toList(),
                                                                      if (_submittedAnswers[answerKey] == true) ...[
                                                                        const SizedBox(height: 12),
                                                                        Row(
                                                                          children: [
                                                                            Icon(
                                                                              _isCorrect[answerKey]!
                                                                                  ? Icons.check_circle
                                                                                  : Icons.cancel,
                                                                              color: _isCorrect[answerKey]!
                                                                                  ? Colors.green
                                                                                  : Colors.red,
                                                                              size: 20,
                                                                            ),
                                                                            const SizedBox(width: 8),
                                                                            Text(
                                                                              _isCorrect[answerKey]!
                                                                                  ? 'Правильно!'
                                                                                  : 'Неправильно. Правильный ответ: $correctAnswer',
                                                                              style: TextStyle(
                                                                                color: _isCorrect[answerKey]!
                                                                                    ? Colors.green
                                                                                    : Colors.red,
                                                                                fontSize: 14,
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                        const SizedBox(height: 8),
                                                                        Text(
                                                                          'Объяснение: $explanation',
                                                                          style: TextStyle(
                                                                            fontSize: 14,
                                                                            fontStyle: FontStyle.italic,
                                                                            color: _currentTheme == 'light'
                                                                                ? Colors.grey
                                                                                : Colors.white70,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              )
            else
              Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    'Выберите язык для отображения материалов',
                    style: TextStyle(
                      color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                      fontSize: 16,
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