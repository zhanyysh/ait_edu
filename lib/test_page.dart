import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';

class TestPage extends StatefulWidget {
  final String testTypeId;
  final String language;
  final String? contestId;
  final String currentTheme;

  const TestPage({
    super.key,
    required this.testTypeId,
    required this.language,
    this.contestId,
    required this.currentTheme,
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
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  List<Color> get _backgroundColors {
    if (widget.currentTheme == 'light') {
      return [
        Colors.white,
        const Color(0xFFF5E6FF),
      ];
    } else {
      return [
        const Color(0xFF1A1A2E),
        const Color(0xFF16213E),
      ];
    }
  }

  Color get _textColor => widget.currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white;
  Color get _secondaryTextColor => widget.currentTheme == 'light' ? Colors.grey : Colors.white70;
  Color get _cardColor => widget.currentTheme == 'light' ? Colors.white : Colors.white.withOpacity(0.05);
  Color get _borderColor => widget.currentTheme == 'light' ? Colors.grey[200]! : Colors.transparent;
  Color get _fieldFillColor => widget.currentTheme == 'light' ? Colors.grey[100]! : Colors.white.withOpacity(0.08);
  static const Color _primaryColor = Color(0xFFFF6F61);
  static const List<Color> _buttonGradientColors = [
    Color(0xFFFF6F61),
    Color(0xFFDE4B7C),
  ];

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
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _loadCategories();
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
      debugPrint('TestPage: Ошибка загрузки категорий: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки категорий: $e')));
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
      Map<String, dynamic>? categoryData = categoryDoc.data() as Map<String, dynamic>?;
      String categoryId = categoryDoc.id;
      _testType = categoryData?['test_type'] as String? ?? 'multiple-choice';
      _duration = (categoryData?['duration'] as num?)?.toDouble() ?? 0.0;
      int numberOfQuestions = (categoryData?['number_of_questions'] as int?) ?? 30;
      _timeRemaining = (_duration * 60).toInt();

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
            },
        };
      }

      QuerySnapshot questionsSnapshot = await _firestore
          .collection('test_types')
          .doc(widget.testTypeId)
          .collection('categories')
          .doc(categoryId)
          .collection('questions')
          .where('language', isEqualTo: widget.language)
          .get();

      List<DocumentSnapshot> questions = questionsSnapshot.docs.where((doc) {
        Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
        if (_testType == 'multiple-choice' || _testType == 'reading') {
          return data?['options'] != null && (data!['options'] as List).isNotEmpty;
        }
        return true;
      }).toList();

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

      _selectedAnswers = List<dynamic>.filled(_questions.length, _testType == 'writing' ? '' : null);

      setState(() {
        _isLoading = false;
      });

      _startTimer();
      _animationController.reset();
      _animationController.forward();
    } catch (e) {
      debugPrint('TestPage: Ошибка загрузки вопросов: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки вопросов: $e')));
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
    if (_selectedAnswers.contains(null) ||
        (_testType == 'writing' && _selectedAnswers.any((answer) => (answer as String).isEmpty))) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ответьте на все вопросы перед продолжением')),
        );
      }
      return;
    }

    try {
      DocumentSnapshot categoryDoc = _categories[_currentCategoryIndex];
      Map<String, dynamic>? categoryData = categoryDoc.data() as Map<String, dynamic>?;
      String categoryName = categoryData?['name'] as String? ?? 'Неизвестная категория';
      double pointsPerQuestion = (categoryData?['points_per_question'] as num?)?.toDouble() ?? 0.0;

      _categoryNames.add(categoryName);
      _pointsPerQuestionByCategory.add(pointsPerQuestion);
      _questionsPerCategory.add(_questions.length);
      _testTypesByCategory.add(_testType);

      int categoryCorrectAnswers = 0;
      for (int i = 0; i < _questions.length; i++) {
        DocumentSnapshot question = _questions[i];
        Map<String, dynamic>? questionData = question.data() as Map<String, dynamic>?;
        String? correctAnswer = questionData?['correct_answer'] as String?;
        String? readingTextId = questionData?['reading_text_id'] as String?;
        dynamic userAnswer = _selectedAnswers[i];
        _allQuestions.add(question);
        _allCorrectAnswers.add(correctAnswer ?? '');
        _allSelectedAnswers.add(userAnswer);

        if (_testType == 'multiple-choice' || _testType == 'reading') {
          final options = (questionData?['options'] as List?)?.map((option) => option.toString()).toList() ?? [];
          String? userAnswerText;
          if (userAnswer != null && options.isNotEmpty && userAnswer is int && userAnswer < options.length) {
            userAnswerText = options[userAnswer];
          }
          if (userAnswerText != null && userAnswerText == correctAnswer) {
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
    } catch (e) {
      debugPrint('TestPage: Ошибка завершения категории: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка завершения категории: $e')));
      }
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
      String testName = testTypeDoc.exists ? (testTypeDoc['name'] as String? ?? 'Неизвестный тест') : 'Неизвестный тест';

      String? contestName;
      if (widget.contestId != null) {
        DocumentSnapshot contestDoc = await _firestore.collection('contests').doc(widget.contestId).get();
        if (contestDoc.exists) {
          contestName = 'Контест: $testName (${contestDoc['language'] ?? 'Не указан'})';
        }
      }

      await _firestore.collection('users').doc(user.uid).collection('test_history').doc(_testId).set({
        'test_type': testName,
        'date': DateTime.now().toIso8601String(),
        'is_contest': widget.contestId != null,
        'contest_id': widget.contestId,
        'contest_name': contestName ?? testName,
        'total_points': _totalPoints,
        'correct_answers': _correctAnswers,
        'total_questions': _allQuestions.length,
      });

      for (int categoryIndex = 0; categoryIndex < _categoryNames.length; categoryIndex++) {
        String categoryName = _categoryNames[categoryIndex];
        String categoryTestType = _testTypesByCategory[categoryIndex];
        double pointsPerQuestion = _pointsPerQuestionByCategory[categoryIndex];
        int startIndex =
        categoryIndex == 0 ? 0 : _questionsPerCategory.sublist(0, categoryIndex).fold(0, (sum, count) => sum + count);
        int endIndex = startIndex + _questionsPerCategory[categoryIndex];

        int categoryCorrectAnswers = 0;
        List<Map<String, dynamic>> answers = [];
        for (int i = startIndex; i < endIndex; i++) {
          DocumentSnapshot question = _allQuestions[i];
          Map<String, dynamic>? questionData = question.data() as Map<String, dynamic>?;
          String? correctAnswer = questionData?['correct_answer'] as String?;
          dynamic userAnswer = _allSelectedAnswers[i];
          String? readingTextId = questionData?['reading_text_id'] as String?;
          String? answerText = questionData?.containsKey('answer_text') == true ? questionData!['answer_text'] as String? : null;

          if (categoryTestType == 'multiple-choice' || categoryTestType == 'reading') {
            final options = (questionData?['options'] as List?)?.map((option) => option.toString()).toList() ?? [];
            String? userAnswerText;
            if (userAnswer != null && options.isNotEmpty && userAnswer is int && userAnswer < options.length) {
              userAnswerText = options[userAnswer];
            }
            if (userAnswerText != null && userAnswerText == correctAnswer) {
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка сохранения результатов: $e')));
      }
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
            'Тест',
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
            onPressed: () {
              _timer?.cancel();
              Navigator.pop(context);
            },
          ),
        ),
        body: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
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
                                  style: TextStyle(color: _textColor, fontSize: 16),
                                ),
                              )
                            else if (_entireTestFinished) ...[
                                Text(
                                  'ТЕСТ ЗАВЕРШЁН',
                                  style: GoogleFonts.orbitron(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: _textColor,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Card(
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
                                            Icon(
                                              Icons.check_circle_outline,
                                              color: widget.currentTheme == 'light' ? Colors.green : Colors.greenAccent,
                                              size: 24,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Правильных ответов: $_correctAnswers из ${_allQuestions.length}',
                                              style: TextStyle(fontSize: 18, color: _textColor),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.star_border,
                                              color: widget.currentTheme == 'light' ? Colors.amber : Colors.amberAccent,
                                              size: 24,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Всего баллов: ${_totalPoints.toStringAsFixed(1)}',
                                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor),
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
                                  style: GoogleFonts.orbitron(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: _textColor,
                                    letterSpacing: 1.2,
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
                                      : _questionsPerCategory.sublist(0, categoryIndex).fold(0, (sum, count) => sum + count);
                                  int endIndex = startIndex + _questionsPerCategory[categoryIndex];

                                  int categoryCorrectAnswers = 0;
                                  for (int i = startIndex; i < endIndex; i++) {
                                    Map<String, dynamic>? questionData = _allQuestions[i].data() as Map<String, dynamic>?;
                                    String? correctAnswer = questionData?['correct_answer'] as String?;
                                    dynamic userAnswer = _allSelectedAnswers[i];
                                    if (categoryTestType == 'multiple-choice' || categoryTestType == 'reading') {
                                      final options =
                                          (questionData?['options'] as List?)?.map((option) => option.toString()).toList() ?? [];
                                      String? userAnswerText;
                                      if (userAnswer != null && options.isNotEmpty && userAnswer is int && userAnswer < options.length) {
                                        userAnswerText = options[userAnswer];
                                      }
                                      if (userAnswerText != null && userAnswerText == correctAnswer) {
                                        categoryCorrectAnswers++;
                                      }
                                    }
                                  }

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Card(
                                        color: _cardColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(15),
                                          side: BorderSide(color: _borderColor, width: 1),
                                        ),
                                        elevation: widget.currentTheme == 'light' ? 4 : 0,
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Row(
                                            children: [
                                              Icon(Icons.category, color: _secondaryTextColor, size: 20),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  '$categoryName: $categoryCorrectAnswers/${endIndex - startIndex} правильных',
                                                  style: GoogleFonts.orbitron(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: _textColor,
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
                                        Map<String, dynamic>? questionData = question.data() as Map<String, dynamic>?;
                                        String questionText = questionData?['text'] as String? ?? 'Вопрос отсутствует';
                                        String? correctAnswer = questionData?['correct_answer'] as String?;
                                        dynamic userAnswer = _allSelectedAnswers[index];
                                        String? readingTextId = questionData?['reading_text_id'] as String?;
                                        String? explanation = questionData?['explanation'] as String? ?? 'Объяснение отсутствует';
                                        bool isCorrect = false;

                                        String? userAnswerText;
                                        if (categoryTestType == 'multiple-choice' || categoryTestType == 'reading') {
                                          final options = (questionData?['options'] as List?)?.map((option) => option.toString()).toList() ?? [];
                                          if (userAnswer != null && options.isNotEmpty && userAnswer is int && userAnswer < options.length) {
                                            userAnswerText = options[userAnswer];
                                          }
                                          isCorrect = userAnswerText != null && userAnswerText == correctAnswer;
                                        } else if (categoryTestType == 'writing') {
                                          userAnswerText = userAnswer as String? ?? 'Не введено';
                                        }

                                        String? readingTextContent;
                                        String? readingTextTitle;
                                        if (readingTextId != null && _readingTexts.containsKey(readingTextId)) {
                                          final text = _readingTexts[readingTextId]!;
                                          readingTextTitle = text['title'] as String?;
                                          readingTextContent = text['content'] as String? ?? 'Текст отсутствует';
                                        }

                                        return Card(
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
                                                if (readingTextId != null && readingTextContent != null) ...[
                                                  Text(
                                                    readingTextTitle ?? 'Текст',
                                                    style: GoogleFonts.orbitron(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                      color: _textColor,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    readingTextContent,
                                                    style: TextStyle(fontSize: 14, color: _secondaryTextColor),
                                                  ),
                                                  const SizedBox(height: 16),
                                                ],
                                                Text(
                                                  'Вопрос ${index - startIndex + 1}: $questionText',
                                                  style: GoogleFonts.orbitron(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: _textColor,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Ваш ответ: ${userAnswerText ?? 'Не выбран'}',
                                                  style: TextStyle(
                                                    color: categoryTestType == 'writing'
                                                        ? _secondaryTextColor
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
                                                    style: TextStyle(fontSize: 14, color: Colors.green),
                                                  ),
                                                ],
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Объяснение: $explanation',
                                                  style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: _secondaryTextColor),
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
                                Center(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      backgroundColor: _primaryColor,
                                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                    child: Text(
                                      'Вернуться',
                                      style: GoogleFonts.orbitron(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ] else ...[
                                Builder(builder: (BuildContext context) {
                                  final category = _categories[_currentCategoryIndex];
                                  Map<String, dynamic>? categoryData = category.data() as Map<String, dynamic>?;
                                  String categoryName = categoryData?['name'] as String? ?? 'Неизвестная категория';

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Card(
                                        color: _cardColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(15),
                                          side: BorderSide(color: _borderColor, width: 1),
                                        ),
                                        elevation: widget.currentTheme == 'light' ? 4 : 0,
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Row(
                                            children: [
                                              Icon(Icons.category, color: _secondaryTextColor, size: 20),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Категория: $categoryName (${_testType.toUpperCase()})',
                                                  style: GoogleFonts.orbitron(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: _textColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      if (_testType == 'reading' && _readingTexts.isNotEmpty)
                                        ..._readingTexts.entries.map((entry) {
                                          String textId = entry.key;
                                          Map<String, dynamic> text = entry.value;
                                          String? textTitle = text['title'] as String?;
                                          String textContent = text['content'] as String;
                                          List<DocumentSnapshot> textQuestions =
                                          _questions.where((q) => q['reading_text_id'] == textId).toList();

                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Card(
                                                color: _cardColor,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(15),
                                                  side: BorderSide(color: _borderColor, width: 1),
                                                ),
                                                elevation: widget.currentTheme == 'light' ? 4 : 0,
                                                child: ExpansionTile(
                                                  title: Text(
                                                    textTitle ?? 'Текст для чтения',
                                                    style: GoogleFonts.orbitron(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                      color: _textColor,
                                                    ),
                                                  ),
                                                  children: [
                                                    Padding(
                                                      padding: const EdgeInsets.all(16.0),
                                                      child: Text(
                                                        textContent,
                                                        style: TextStyle(fontSize: 14, color: _secondaryTextColor),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              ...textQuestions.asMap().entries.map((entry) {
                                                int questionIndex = _questions.indexOf(entry.value);
                                                DocumentSnapshot question = entry.value;
                                                Map<String, dynamic>? questionData = question.data() as Map<String, dynamic>?;
                                                String questionText = questionData?['text'] as String? ?? 'Вопрос отсутствует';
                                                final options =
                                                    (questionData?['options'] as List?)?.map((option) => option.toString()).toList() ?? [];

                                                if (options.isEmpty) {
                                                  return Center(
                                                    child: Text(
                                                      'Ошибка: Вопрос не содержит вариантов ответа. Обратитесь к администратору.',
                                                      style: TextStyle(
                                                        color: widget.currentTheme == 'light' ? Colors.red : Colors.redAccent,
                                                        fontSize: 14,
                                                      ),
                                                      textAlign: TextAlign.center,
                                                    ),
                                                  );
                                                }

                                                return Card(
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
                                                        Text(
                                                          'Вопрос ${questionIndex + 1}: $questionText',
                                                          style: GoogleFonts.orbitron(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold,
                                                            color: _textColor,
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
                                                                style: TextStyle(fontSize: 16, color: _textColor),
                                                              ),
                                                              value: optionIndex,
                                                              groupValue: _selectedAnswers[questionIndex] as int?,
                                                              onChanged: (value) {
                                                                if (value != null) {
                                                                  _selectAnswer(questionIndex, value);
                                                                }
                                                              },
                                                              contentPadding: EdgeInsets.zero,
                                                              activeColor: _primaryColor,
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
                                          Map<String, dynamic>? questionData = question.data() as Map<String, dynamic>?;
                                          String questionText = questionData?['text'] as String? ?? 'Вопрос отсутствует';

                                          if (_testType == 'multiple-choice') {
                                            final options =
                                                (questionData?['options'] as List?)?.map((option) => option.toString()).toList() ?? [];

                                            if (options.isEmpty) {
                                              return Center(
                                                child: Text(
                                                  'Ошибка: Вопрос не содержит вариантов ответа. Обратитесь к администратору.',
                                                  style: TextStyle(
                                                    color: widget.currentTheme == 'light' ? Colors.red : Colors.redAccent,
                                                    fontSize: 14,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              );
                                            }

                                            return Card(
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
                                                    Text(
                                                      'Вопрос ${questionIndex + 1}: $questionText',
                                                      style: GoogleFonts.orbitron(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: _textColor,
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
                                                            style: TextStyle(fontSize: 16, color: _textColor),
                                                          ),
                                                          value: optionIndex,
                                                          groupValue: _selectedAnswers[questionIndex] as int?,
                                                          onChanged: (value) {
                                                            if (value != null) {
                                                              _selectAnswer(questionIndex, value);
                                                            }
                                                          },
                                                          contentPadding: EdgeInsets.zero,
                                                          activeColor: _primaryColor,
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ],
                                                ),
                                              ),
                                            );
                                          } else if (_testType == 'writing') {
                                            return Card(
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
                                                    Text(
                                                      'Вопрос ${questionIndex + 1}: $questionText',
                                                      style: GoogleFonts.orbitron(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: _textColor,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    TextField(
                                                      maxLines: 5,
                                                      decoration: InputDecoration(
                                                        hintText: 'Введите ваш ответ',
                                                        hintStyle: TextStyle(color: _secondaryTextColor),
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
                                                            color: _primaryColor,
                                                            width: 2,
                                                          ),
                                                        ),
                                                      ),
                                                      style: TextStyle(color: _textColor),
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
                                        child: ElevatedButton(
                                          onPressed: _finishCategory,
                                          style: ElevatedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            backgroundColor: _primaryColor,
                                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(15),
                                            ),
                                          ),
                                          child: Text(
                                            'Закончил категорию',
                                            style: GoogleFonts.orbitron(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (!_entireTestFinished && !_isLoading)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${_timeRemaining ~/ 60}:${(_timeRemaining % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 16, color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}