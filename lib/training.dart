import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'custom_animated_button.dart';

class TrainingPage extends StatefulWidget {
  final String currentTheme;

  const TrainingPage({super.key, required this.currentTheme});

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
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

// Color schemes for light and dark themes
  List<Color> get _backgroundColors {
    if (widget.currentTheme == 'light') {
      return [Colors.white, const Color(0xFFF5E6FF)];
    } else {
      return [const Color(0xFF1A1A2E), const Color(0xFF16213E)];
    }
  }

  Color get _textColor => widget.currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white;
  Color get _secondaryTextColor => widget.currentTheme == 'light' ? Colors.grey[600]! : Colors.white70;
  Color get _cardColor => widget.currentTheme == 'light' ? Colors.white : Colors.white.withOpacity(0.05);
  Color get _borderColor => widget.currentTheme == 'light' ? Colors.grey[200]! : Colors.transparent;
  Color get _fieldFillColor => widget.currentTheme == 'light' ? Colors.grey[100]! : Colors.white.withOpacity(0.08);
  static const List<Color> _buttonGradientColors = [
    Color(0xFFFF6F61),
    Color(0xFFDE4B7C),
  ];

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
        SnackBar(
          content: Text('Ошибка сохранения результата: $e', style: TextStyle(color: _textColor)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _backgroundColors,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Обучающие материалы',
            style: GoogleFonts.orbitron(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: _textColor,
              letterSpacing: 1.2,
            ),
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _backgroundColors,
              ),
            ),
          ),
          elevation: 0,
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Выберите материалы',
                style: GoogleFonts.orbitron(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              if (_availableLanguages.isNotEmpty)
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: DropdownButtonFormField<String>(
                      value: _selectedLanguage,
                      hint: Text('Выберите язык', style: TextStyle(color: _secondaryTextColor)),
                      items: _availableLanguages.map((lang) {
                        return DropdownMenuItem<String>(
                          value: lang['code'],
                          child: Text(lang['name']!, style: TextStyle(color: _textColor)),
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
                        prefixIcon: Icon(Icons.language, color: _secondaryTextColor),
                        filled: true,
                        fillColor: _fieldFillColor,
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
                            color: const Color(0xFFFF6F61),
                            width: 2,
                          ),
                        ),
                      ),
                      style: TextStyle(color: _textColor),
                      dropdownColor: _cardColor,
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
                        return Center(child: Text('Ошибка: ${testTypesSnapshot.error}', style: TextStyle(color: _textColor)));
                      }
                      if (testTypesSnapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: _textColor));
                      }
                      final testTypes = testTypesSnapshot.data!.docs;
                      return ListView.builder(
                        itemCount: testTypes.length,
                        itemBuilder: (context, index) {
                          final testType = testTypes[index];
                          final testTypeId = testType.id;
                          final testTypeName = testType['name'] as String;
                          return FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: Card(
                                color: _cardColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  side: BorderSide(color: _borderColor, width: 1),
                                ),
                                elevation: widget.currentTheme == 'light' ? 4 : 0,
                                margin: const EdgeInsets.symmetric(vertical: 8.0),
                                child: ExpansionTile(
                                  leading: Icon(Icons.book, color: _secondaryTextColor),
                                  title: Text(
                                    testTypeName,
                                    style: GoogleFonts.orbitron(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _textColor,
                                      letterSpacing: 1.2,
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
                                            child: Text('Ошибка: ${materialsSnapshot.error}', style: TextStyle(color: _textColor)),
                                          );
                                        }
                                        if (materialsSnapshot.connectionState == ConnectionState.waiting) {
                                          return const Center(child: CircularProgressIndicator());
                                        }
                                        final materials = materialsSnapshot.data!.docs;
                                        if (materials.isEmpty) {
                                          return Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text('Нет материалов', style: TextStyle(color: _textColor)),
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
                                            return ListTile(
                                              leading: Icon(Icons.article, color: _secondaryTextColor),
                                              title: Text(
                                                title,
                                                style: GoogleFonts.orbitron(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: _textColor,
                                                  letterSpacing: 1.2,
                                                ),
                                              ),
                                              subtitle: Text(
                                                content.length > 50 ? '${content.substring(0, 50)}...' : content,
                                                style: TextStyle(color: _secondaryTextColor, fontSize: 14),
                                              ),
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => MaterialPage(
                                                      testTypeId: testTypeId,
                                                      testTypeName: testTypeName,
                                                      materialId: materialId,
                                                      title: title,
                                                      content: content,
                                                      language: _selectedLanguage!,
                                                      currentTheme: widget.currentTheme,
                                                    ),
                                                  ),
                                                );
                                              },
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
                      style: TextStyle(color: _textColor, fontSize: 16),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class MaterialPage extends StatefulWidget {
  final String testTypeId;
  final String testTypeName;
  final String materialId;
  final String title;
  final String content;
  final String language;
  final String currentTheme;

  const MaterialPage({
    super.key,
    required this.testTypeId,
    required this.testTypeName,
    required this.materialId,
    required this.title,
    required this.content,
    required this.language,
    required this.currentTheme,
  });

  @override
  _MaterialPageState createState() => _MaterialPageState();
}

class _MaterialPageState extends State<MaterialPage> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, int?> _selectedAnswers = {};
  final Map<String, bool> _submittedAnswers = {};
  final Map<String, bool> _isCorrect = {};
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

// Color schemes for light and dark themes
  List<Color> get _backgroundColors {
    if (widget.currentTheme == 'light') {
      return [Colors.white, const Color(0xFFF5E6FF)];
    } else {
      return [const Color(0xFF1A1A2E), const Color(0xFF16213E)];
    }
  }

  Color get _textColor => widget.currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white;
  Color get _secondaryTextColor => widget.currentTheme == 'light' ? Colors.grey[600]! : Colors.white70;
  Color get _cardColor => widget.currentTheme == 'light' ? Colors.white : Colors.white.withOpacity(0.05);
  Color get _borderColor => widget.currentTheme == 'light' ? Colors.grey[200]! : Colors.transparent;
  static const List<Color> _buttonGradientColors = [
    Color(0xFFFF6F61),
    Color(0xFFDE4B7C),
  ];

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _saveMiniTestResult({
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
        'test_type_id': widget.testTypeId,
        'test_type_name': widget.testTypeName,
        'material_id': widget.materialId,
        'material_title': widget.title,
        'mini_test_id': miniTestId,
        'question_text': questionText,
        'user_answer': userAnswer,
        'correct_answer': correctAnswer,
        'is_correct': isCorrect,
        'timestamp': DateTime.now().toIso8601String(),
      });
      debugPrint('MaterialPage: Результат мини-теста сохранён');
    } catch (e) {
      debugPrint('MaterialPage: Ошибка сохранения результата мини-теста: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка сохранения результата: $e', style: TextStyle(color: _textColor)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _backgroundColors,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            widget.title,
            style: GoogleFonts.orbitron(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: _textColor,
              letterSpacing: 1.2,
            ),
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _backgroundColors,
              ),
            ),
          ),
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: _textColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Card(
                            color: _cardColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                              side: BorderSide(color: _borderColor, width: 1),
                            ),
                            elevation: widget.currentTheme == 'light' ? 4 : 0,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.article, color: _secondaryTextColor, size: 24),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          widget.title,
                                          style: GoogleFonts.orbitron(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: _textColor,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Divider(color: _borderColor),
                                  const SizedBox(height: 12),
                                  Text(
                                    widget.content,
                                    style: TextStyle(fontSize: 16, color: _textColor),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Text(
                            'Мини-тесты',
                            style: GoogleFonts.orbitron(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _textColor,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('test_types')
                            .doc(widget.testTypeId)
                            .collection('study_materials')
                            .doc(widget.materialId)
                            .collection('mini_tests')
                            .snapshots(),
                        builder: (context, miniTestsSnapshot) {
                          if (miniTestsSnapshot.hasError) {
                            return Text('Ошибка: ${miniTestsSnapshot.error}', style: TextStyle(color: _textColor));
                          }
                          if (miniTestsSnapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator(color: _textColor));
                          }
                          final miniTests = miniTestsSnapshot.data!.docs;
                          if (miniTests.isEmpty) {
                            return Text('Нет мини-тестов', style: TextStyle(color: _textColor));
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
                              final answerKey = '${widget.materialId}-$miniTestId';

                              return FadeTransition(
                                opacity: _fadeAnimation,
                                child: SlideTransition(
                                  position: _slideAnimation,
                                  child: Card(
                                    color: _cardColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      side: BorderSide(color: _borderColor, width: 1),
                                    ),
                                    elevation: widget.currentTheme == 'light' ? 4 : 0,
                                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.quiz, color: _secondaryTextColor, size: 20),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Мини-тест ${index + 1}: $questionText',
                                                  style: GoogleFonts.orbitron(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: _textColor,
                                                    letterSpacing: 1.2,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Divider(color: _borderColor),
                                          const SizedBox(height: 12),
                                          ...options.asMap().entries.map((optionEntry) {
                                            final optionIndex = optionEntry.key;
                                            final option = optionEntry.value;
                                            return RadioListTile<int>(
                                              title: Text(
                                                option,
                                                style: TextStyle(fontSize: 16, color: _textColor),
                                              ),
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
                                                  miniTestId: miniTestId,
                                                  questionText: questionText,
                                                  userAnswer: options[value!],
                                                  correctAnswer: correctAnswer,
                                                  isCorrect: _isCorrect[answerKey]!,
                                                );
                                              },
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                                              activeColor: const Color(0xFFFF6F61),
                                            );
                                          }).toList(),
                                          if (_submittedAnswers[answerKey] == true) ...[
                                            const SizedBox(height: 12),
                                            Divider(color: _borderColor),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                Icon(
                                                  _isCorrect[answerKey]! ? Icons.check_circle : Icons.cancel,
                                                  color: _isCorrect[answerKey]! ? Colors.green : Colors.red,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    _isCorrect[answerKey]!
                                                        ? 'Правильно!'
                                                        : 'Неправильно. Правильный ответ: $correctAnswer',
                                                    style: TextStyle(
                                                      color: _isCorrect[answerKey]! ? Colors.green : Colors.red,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                    ),
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
                                                color: _secondaryTextColor,
                                              ),
                                            ),
                                          ],
                                        ],
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
                ),
              ),
              const SizedBox(height: 16),
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: CustomAnimatedButton(
                    onPressed: () => Navigator.pop(context),
                    gradientColors: _buttonGradientColors,
                    label: 'Закрыть',
                    currentTheme: widget.currentTheme,
                    isHeader: false, // Non-header button
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}