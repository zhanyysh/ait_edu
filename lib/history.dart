import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'custom_animated_button.dart';

// Модель для хранения фильтров
class HistoryFilters {
  final String? testType;
  final DateTime? startDate;
  final DateTime? endDate;

  HistoryFilters({
    this.testType,
    this.startDate,
    this.endDate,
  });
}

// Модель для данных графика
class ProgressPoint {
  final DateTime date;
  final double value; // Represents accuracy percentage

  ProgressPoint(this.date, this.value);
}

class HistoryPage extends StatefulWidget {
  final String currentTheme;

  const HistoryPage({super.key, required this.currentTheme});

  @override
  HistoryPageState createState() => HistoryPageState();
}

class HistoryPageState extends State<HistoryPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _allTests = []; // Cache all history
  List<Map<String, dynamic>> _tests = []; // Filtered tests
  bool _isLoading = true;
  HistoryFilters _filters = HistoryFilters();
  List<String> _testTypes = [];
  DateTime? _startDate;
  DateTime? _endDate;
  String? _dateError; // For date validation feedback
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
    _loadTestTypes();
    _loadSelectedFilters();
    _loadHistory();
    print('HistoryPage initialized with История tab (index 0)');
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
          _testTypes = testTypesSnapshot.docs.map((doc) => doc['name'] as String).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('Ошибка загрузки видов тестов: $e');
      }
    }
  }

  Future<void> _loadSelectedFilters() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        await _firestore.collection('users').doc(user.uid).set({
          'history_filters': {
            'test_type': null,
            'start_date': null,
            'end_date': null,
          },
        }, SetOptions(merge: true));
        return;
      }

      Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;
      if (data == null || !data.containsKey('history_filters')) {
        await _firestore.collection('users').doc(user.uid).set({
          'history_filters': {
            'test_type': null,
            'start_date': null,
            'end_date': null,
          },
        }, SetOptions(merge: true));
        return;
      }

      Map<String, dynamic> filters = data['history_filters'] as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _filters = HistoryFilters(
            testType: filters['test_type'] as String?,
            startDate: filters['start_date'] != null ? DateTime.parse(filters['start_date']) : null,
            endDate: filters['end_date'] != null ? DateTime.parse(filters['end_date']) : null,
          );
          _startDate = _filters.startDate;
          _endDate = _filters.endDate;
        });
        _applyFilters(); // Apply loaded filters to cached data
      }
    } catch (e) {
      if (mounted) {
        _showError('Ошибка загрузки фильтров: $e');
      }
    }
  }

  Future<void> _saveFilters() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'history_filters': {
          'test_type': _filters.testType,
          'start_date': _filters.startDate?.toIso8601String(),
          'end_date': _filters.endDate?.toIso8601String(),
        },
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        _showError('Ошибка сохранения фильтров: $e');
      }
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // Load all test history without pagination
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('test_history')
          .orderBy('date', descending: true)
          .get();

      List<Map<String, dynamic>> loadedTests = [];
      for (var testDoc in snapshot.docs) {
        QuerySnapshot categoriesSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('test_history')
            .doc(testDoc.id)
            .collection('categories')
            .get();

        List<Map<String, dynamic>> categories = categoriesSnapshot.docs.map((catDoc) {
          return {
            'category': catDoc['category'] as String,
            'points': (catDoc['points'] as num).toDouble(),
            'correct_answers': catDoc['correct_answers'] as int,
            'total_questions': catDoc['total_questions'] as int,
            'time_spent': catDoc['time_spent'] as int,
            'total_time': catDoc['total_time'] as int,
          };
        }).toList();

        loadedTests.add({
          'test_id': testDoc.id,
          'test_type': testDoc['test_type'] as String,
          'date': testDoc['date'] as String,
          'is_contest': testDoc['is_contest'] as bool? ?? false,
          'contest_id': testDoc['contest_id'] as String?,
          'contest_name': testDoc['contest_name'] as String?,
          'categories': categories,
        });
      }

      if (mounted) {
        setState(() {
          _allTests = loadedTests;
          _applyFilters(); // Apply current filters to cached data
          _isLoading = false;
        });
        _animationController.reset();
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        _showError('Ошибка загрузки истории: $e');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _tests = _allTests.where((test) {
        bool matches = true;

        // Filter by test_type
        if (_filters.testType != null && test['test_type'] != _filters.testType) {
          matches = false;
        }

        // Filter by date range
        if (_filters.startDate != null || _filters.endDate != null) {
          DateTime testDate = DateTime.parse(test['date'] as String);
          if (_filters.startDate != null && testDate.isBefore(_filters.startDate!)) {
            matches = false;
          }
          if (_filters.endDate != null && testDate.isAfter(_filters.endDate!)) {
            matches = false;
          }
        }

        return matches;
      }).toList();
    });
    _animationController.reset();
    _animationController.forward();
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: TextStyle(color: _textColor)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _clearHistory() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          'Очистить историю?',
          style: GoogleFonts.orbitron(
            color: _textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 1.2,
          ),
        ),
        content: Text(
          'Вы уверены, что хотите удалить всю историю тестов? Это действие нельзя отменить.',
          style: TextStyle(color: _secondaryTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Отмена', style: TextStyle(color: _secondaryTextColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Очистить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final user = _auth.currentUser;
      if (user != null) {
        try {
          QuerySnapshot historySnapshot = await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('test_history')
              .get();
          for (var doc in historySnapshot.docs) {
            QuerySnapshot categoriesSnapshot = await _firestore
                .collection('users')
                .doc(user.uid)
                .collection('test_history')
                .doc(doc.id)
                .collection('categories')
                .get();
            for (var catDoc in categoriesSnapshot.docs) {
              await catDoc.reference.delete();
            }
            await doc.reference.delete();
          }
          if (mounted) {
            setState(() {
              _allTests.clear();
              _tests.clear();
            });
            _showError('История очищена');
            _animationController.reset();
            _animationController.forward();
          }
        } catch (e) {
          if (mounted) {
            _showError('Ошибка очистки истории: $e');
          }
        }
      }
    }
  }

  void _showFilterModal() {
    setState(() {
      _dateError = null; // Reset error message
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Фильтры',
                    style: GoogleFonts.orbitron(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _filters.testType,
                    hint: Text('Вид теста', style: TextStyle(color: _secondaryTextColor)),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Все тесты'),
                      ),
                      ..._testTypes.map((testType) {
                        return DropdownMenuItem<String>(
                          value: testType,
                          child: Text(testType, style: TextStyle(color: _textColor)),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      modalSetState(() {
                        _filters = HistoryFilters(
                          testType: value,
                          startDate: _filters.startDate,
                          endDate: _filters.endDate,
                        );
                      });
                    },
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.filter_alt, color: _secondaryTextColor),
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
                        borderSide: const BorderSide(
                          color: Color(0xFFFF6F61),
                          width: 2,
                        ),
                      ),
                      labelText: 'Выберите вид теста',
                      labelStyle: TextStyle(color: _secondaryTextColor),
                    ),
                    style: TextStyle(color: _textColor),
                    dropdownColor: _cardColor,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _startDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: _endDate ?? DateTime.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: ThemeData.light().copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: Color(0xFFFF6F61),
                                      onPrimary: Colors.white,
                                    ),
                                    dialogBackgroundColor: _cardColor,
                                    textTheme: TextTheme(
                                      bodyMedium: TextStyle(color: _textColor),
                                      labelLarge: TextStyle(color: _textColor),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null && mounted) {
                              modalSetState(() {
                                if (_endDate != null && picked.isAfter(_endDate!)) {
                                  _dateError = 'Дата начала не может быть позже даты окончания';
                                } else {
                                  _dateError = null;
                                  _startDate = picked;
                                  _filters = HistoryFilters(
                                    testType: _filters.testType,
                                    startDate: picked,
                                    endDate: _filters.endDate,
                                  );
                                }
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Дата начала',
                              labelStyle: TextStyle(color: _secondaryTextColor),
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
                                borderSide: const BorderSide(
                                  color: Color(0xFFFF6F61),
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Text(
                              _startDate != null
                                  ? DateFormat('d MMMM yyyy', 'ru').format(_startDate!)
                                  : 'Выберите дату',
                              style: TextStyle(color: _textColor),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _endDate ?? DateTime.now(),
                              firstDate: _startDate ?? DateTime(2000),
                              lastDate: DateTime.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: ThemeData.light().copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: Color(0xFFFF6F61),
                                      onPrimary: Colors.white,
                                    ),
                                    dialogBackgroundColor: _cardColor,
                                    textTheme: TextTheme(
                                      bodyMedium: TextStyle(color: _textColor),
                                      labelLarge: TextStyle(color: _textColor),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null && mounted) {
                              modalSetState(() {
                                if (_startDate != null && picked.isBefore(_startDate!)) {
                                  _dateError = 'Дата окончания не может быть раньше даты начала';
                                } else {
                                  _dateError = null;
                                  _endDate = picked;
                                  _filters = HistoryFilters(
                                    testType: _filters.testType,
                                    startDate: _filters.startDate,
                                    endDate: picked,
                                  );
                                }
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Дата окончания',
                              labelStyle: TextStyle(color: _secondaryTextColor),
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
                                borderSide: const BorderSide(
                                  color: Color(0xFFFF6F61),
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Text(
                              _endDate != null
                                  ? DateFormat('d MMMM yyyy', 'ru').format(_endDate!)
                                  : 'Выберите дату',
                              style: TextStyle(color: _textColor),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_dateError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _dateError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: CustomAnimatedButton(
                          onPressed: _dateError != null
                              ? null
                              : () async {
                            setState(() {
                              _isLoading = true;
                            });
                            await _saveFilters();
                            _applyFilters();
                            setState(() {
                              _isLoading = false;
                            });
                            Navigator.pop(context);
                          },
                          gradientColors: _buttonGradientColors,
                          label: 'Применить',
                          currentTheme: widget.currentTheme,
                          isHeader: false,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CustomAnimatedButton(
                          onPressed: () async {
                            modalSetState(() {
                              _filters = HistoryFilters();
                              _startDate = null;
                              _endDate = null;
                              _dateError = null;
                            });
                            setState(() {
                              _isLoading = true;
                            });
                            await _saveFilters();
                            _applyFilters();
                            setState(() {
                              _isLoading = false;
                            });
                            Navigator.pop(context);
                            _showError('Фильтры сброшены');
                          },
                          gradientColors: _buttonGradientColors,
                          label: 'Сбросить',
                          currentTheme: widget.currentTheme,
                          isHeader: false,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CustomAnimatedButton(
                          onPressed: () => Navigator.pop(context),
                          gradientColors: _buttonGradientColors,
                          label: 'Закрыть',
                          currentTheme: widget.currentTheme,
                          isHeader: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatistics() {
    if (_tests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Text(
                  'Нет данных для прогресса',
                  style: GoogleFonts.orbitron(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Text(
                  'Пройдите тесты, чтобы увидеть статистику.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: _secondaryTextColor),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Map<String, List<Map<String, dynamic>>> groupedByTestType = {};
    for (var test in _tests) {
      String key = test['is_contest'] == true ? (test['contest_name'] as String? ?? test['test_type']) : test['test_type'] as String;
      if (!groupedByTestType.containsKey(key)) {
        groupedByTestType[key] = [];
      }
      groupedByTestType[key]!.add(test);
    }

    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: groupedByTestType.entries.map((entry) {
        String displayName = entry.key;
        List<Map<String, dynamic>> testsOfType = entry.value;

        int totalTests = testsOfType.length;
        double totalPoints = 0.0;
        int totalCorrect = 0;
        int totalQuestions = 0;

        for (var test in testsOfType) {
          List<Map<String, dynamic>> categories = test['categories'] as List<Map<String, dynamic>>;
          double testPoints = categories.fold(0.0, (sum, cat) => sum + (cat['points'] as double));
          totalPoints += testPoints;
          totalCorrect += categories.fold(0, (sum, cat) => sum + (cat['correct_answers'] as int));
          totalQuestions += categories.fold(0, (sum, cat) => sum + (cat['total_questions'] as int));
        }

        double avgPoints = totalTests > 0 ? totalPoints / totalTests : 0.0;
        double avgCorrectPercentage = totalQuestions > 0 ? (totalCorrect / totalQuestions * 100) : 0.0;

        // Group tests by date and calculate average accuracy per day
        Map<DateTime, List<Map<String, dynamic>>> testsByDate = {};
        for (var test in testsOfType) {
          DateTime testDate = DateTime.parse(test['date'] as String);
          // Normalize to date only (remove time)
          DateTime normalizedDate = DateTime(testDate.year, testDate.month, testDate.day);
          if (!testsByDate.containsKey(normalizedDate)) {
            testsByDate[normalizedDate] = [];
          }
          testsByDate[normalizedDate]!.add(test);
        }

        List<ProgressPoint> progressData = testsByDate.entries.map((entry) {
          DateTime date = entry.key;
          List<Map<String, dynamic>> dailyTests = entry.value;
          double totalAccuracy = 0.0;
          int testCount = dailyTests.length;

          for (var test in dailyTests) {
            List<Map<String, dynamic>> categories = test['categories'] as List<Map<String, dynamic>>;
            int testCorrect = categories.fold(0, (sum, cat) => sum + (cat['correct_answers'] as int));
            int testQuestions = categories.fold(0, (sum, cat) => sum + (cat['total_questions'] as int));
            double testAccuracy = testQuestions > 0 ? (testCorrect / testQuestions * 100) : 0.0;
            totalAccuracy += testAccuracy;
          }

          double avgAccuracy = testCount > 0 ? totalAccuracy / testCount : 0.0;
          return ProgressPoint(date, avgAccuracy);
        }).toList()
          ..sort((a, b) => a.date.compareTo(b.date));

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
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.analytics, color: Color(0xFFFF6F61), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Статистика: $displayName',
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
                      Row(
                        children: [
                          Icon(Icons.format_list_numbered, color: _secondaryTextColor, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Всего тестов: $totalTests',
                            style: TextStyle(color: _textColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Средний балл: ${avgPoints.toStringAsFixed(1)}',
                            style: TextStyle(color: _textColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Средняя точность: ${avgCorrectPercentage.toStringAsFixed(1)}%',
                            style: TextStyle(color: _textColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 150,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            final height = 150.0;
                            final maxValue = 100.0; // Accuracy percentage
                            final minDate = progressData.isNotEmpty ? progressData.first.date : DateTime.now();
                            final maxDate = progressData.isNotEmpty ? progressData.last.date : DateTime.now();
                            final dateRange = progressData.isNotEmpty
                                ? maxDate.difference(minDate).inDays.toDouble()
                                : 1.0;
                            final widthPerDay = dateRange > 0 ? (width - 60) / dateRange : width - 60;

                            // X-axis labels (dates)
                            final List<Widget> xAxisLabels = [];
                            if (progressData.isNotEmpty) {
                              final labelCount = progressData.length > 5 ? 5 : progressData.length;
                              final step = progressData.length > 1 ? (progressData.length - 1) / (labelCount - 1) : 1;
                              for (int i = 0; i < labelCount; i++) {
                                final index = (i * step).round().clamp(0, progressData.length - 1);
                                final point = progressData[index];
                                final date = point.date;
                                final x = 60 + date.difference(minDate).inDays * widthPerDay;
                                xAxisLabels.add(
                                  Positioned(
                                    left: x - 20, // Approximate centering
                                    bottom: 0,
                                    child: SizedBox(
                                      width: 40,
                                      child: Text(
                                        DateFormat('d MMM', 'ru').format(date),
                                        style: TextStyle(
                                          color: _secondaryTextColor,
                                          fontSize: 10, // Options: 8 (small), 12 (normal)
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                );
                              }
                            }

                            // Y-axis labels (percentages)
                            final List<Widget> yAxisLabels = [];
                            for (int i = 0; i <= 4; i++) {
                              final percentage = i * 25;
                              final y = (height - 60) * (1 - i / 4) + 20;
                              yAxisLabels.add(
                                Positioned(
                                  left: 10,
                                  top: y - 10, // Center vertically
                                  child: SizedBox(
                                    width: 40,
                                    child: Text(
                                      '$percentage%',
                                      style: TextStyle(
                                        color: _secondaryTextColor,
                                        fontSize: 10, // Options: 8 (small), 12 (normal)
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ),
                              );
                            }

                            return Stack(
                              children: [
                                CustomPaint(
                                  size: Size(width, height),
                                  painter: ProgressLinePainter(
                                    progressData,
                                    lineColor: Color(0xFFFF6F61),
                                  ),
                                ),
                                ...yAxisLabels,
                                ...xAxisLabels,
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ));
      }).toList(),
    );
  }

  Widget _buildHistory() {
    if (_isLoading && _allTests.isEmpty) {
      return Center(child: CircularProgressIndicator(color: _textColor));
    } else if (_tests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Text(
                  'История пуста',
                  style: GoogleFonts.orbitron(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Text(
                  'Пройдите тест, чтобы увидеть результаты здесь.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: _secondaryTextColor),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _tests.length,
      itemBuilder: (context, index) {
        final test = _tests[index];
        final displayName = test['is_contest'] == true
            ? (test['contest_name'] as String? ?? test['test_type'])
            : test['test_type'] as String;
        final date = DateTime.parse(test['date'] as String);

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
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                leading: Icon(
                  test['is_contest'] == true ? Icons.emoji_events : Icons.history,
                  color: test['is_contest'] == true ? Colors.amber : _secondaryTextColor,
                ),
                title: Text(
                  displayName,
                  style: GoogleFonts.orbitron(
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                    fontSize: 16,
                    letterSpacing: 1.2,
                  ),
                ),
                subtitle: Text(
                  'Дата: ${DateFormat('d MMMM yyyy, HH:mm', 'ru').format(date)}',
                  style: TextStyle(color: _secondaryTextColor),
                ),
                trailing: Icon(Icons.arrow_forward_ios, size: 16, color: _secondaryTextColor),
                onTap: () {
                  List<Map<String, dynamic>> categories = test['categories'] as List<Map<String, dynamic>>;
                  double testTotalPoints = categories.fold(0.0, (sum, cat) => sum + (cat['points'] as double));

                  showModalBottomSheet(
                    context: context,
                    backgroundColor: _cardColor,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                    ),
                    builder: (context) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Результаты: $displayName',
                                    style: GoogleFonts.orbitron(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _textColor,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Балл: ${testTotalPoints.toStringAsFixed(1)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFF6F61),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: categories.length,
                                itemBuilder: (context, idx) {
                                  final category = categories[idx];
                                  final catName = category['category'] as String;
                                  final points = (category['points'] as double);
                                  final correctAnswers = category['correct_answers'] as int;
                                  final totalQuestions = category['total_questions'] as int;
                                  final timeSpent = category['time_spent'] as int;
                                  final totalTime = category['total_time'] as int;
                                  final percentage = totalQuestions > 0 ? (correctAnswers / totalQuestions * 100) : 0.0;

                                  return ListTile(
                                    leading: Icon(Icons.category, color: _secondaryTextColor),
                                    title: Text(
                                      '$catName ${timeSpent ~/ 60}/${totalTime ~/ 60} мин',
                                      style: GoogleFonts.orbitron(
                                        fontWeight: FontWeight.bold,
                                        color: _textColor,
                                        fontSize: 16,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Баллы: ${points.toStringAsFixed(1)}',
                                          style: TextStyle(color: _secondaryTextColor),
                                        ),
                                        Text(
                                          'Правильных: $correctAnswers/$totalQuestions (${percentage.toStringAsFixed(1)}%)',
                                          style: TextStyle(color: _secondaryTextColor),
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          backgroundColor: _cardColor,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                          title: Text(
                                            'Результат: $displayName - $catName',
                                            style: GoogleFonts.orbitron(
                                              color: _textColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                          content: SingleChildScrollView(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Дата: ${DateFormat('d MMMM yyyy, HH:mm', 'ru').format(date)}',
                                                  style: TextStyle(color: _secondaryTextColor),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Баллы: ${points.toStringAsFixed(1)}',
                                                  style: TextStyle(color: _secondaryTextColor),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Правильных: $correctAnswers/$totalQuestions (${percentage.toStringAsFixed(1)}%)',
                                                  style: TextStyle(color: _secondaryTextColor),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Время: ${timeSpent ~/ 60} мин из ${totalTime ~/ 60} мин',
                                                  style: TextStyle(color: _secondaryTextColor),
                                                ),
                                              ],
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: Text(
                                                'Закрыть',
                                                style: TextStyle(color: Color(0xFFFF6F61)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: CustomAnimatedButton(
                                onPressed: () => Navigator.pop(context),
                                gradientColors: _buttonGradientColors,
                                label: 'Закрыть',
                                currentTheme: widget.currentTheme,
                                isHeader: false,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
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
              'История и прогресс',
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
          body: Center(
            child: Text(
              'Пользователь не авторизован',
              style: TextStyle(color: _textColor, fontSize: 16),
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      initialIndex: 0, // Start with История tab
      child: AnimatedContainer(
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
              'История и прогресс',
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
            actions: [
              IconButton(
                icon: Icon(Icons.filter_alt, color: Color(0xFFFF6F61)),
                onPressed: _showFilterModal,
                tooltip: 'Фильтры',
              ),
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: _clearHistory,
                tooltip: 'Очистить историю',
              ),
            ],
            bottom: TabBar(
              labelColor: _textColor,
              unselectedLabelColor: _secondaryTextColor,
              indicatorColor: Color(0xFFFF6F61),
              tabs: const [
                Tab(text: 'История'),
                Tab(text: 'Прогресс'),
              ],
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(20.0),
            child: TabBarView(
              children: [
                SingleChildScrollView(child: _buildHistory()),
                SingleChildScrollView(child: _buildStatistics()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProgressLinePainter extends CustomPainter {
  final List<ProgressPoint> data;
  final Color lineColor;

  ProgressLinePainter(this.data, {required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    final axisPaint = Paint()
      ..color = lineColor.withOpacity(0.5)
      ..strokeWidth = 1;

    double maxValue = 100.0; // Accuracy percentage
    final minDate = data.first.date;
    final maxDate = data.last.date;
    final dateRange = maxDate.difference(minDate).inDays.toDouble();
    final widthPerDay = dateRange > 0 ? (size.width - 60) / dateRange : size.width - 60;

    // Draw path and points
    Path path = Path();
    for (int i = 0; i < data.length; i++) {
      final point = data[i];
      final x = 60 + point.date.difference(minDate).inDays * widthPerDay;
      final y = (size.height - 60) * (1 - point.value / maxValue) + 20;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
    }

    canvas.drawPath(path, paint);
    canvas.drawLine(Offset(60, size.height - 20), Offset(size.width, size.height - 20), axisPaint);
    canvas.drawLine(Offset(60, 20), Offset(60, size.height - 20), axisPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}