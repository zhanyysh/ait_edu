import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final double points;

  ProgressPoint(this.date, this.points);
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  HistoryPageState createState() => HistoryPageState();
}

class HistoryPageState extends State<HistoryPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  DocumentSnapshot? _lastDoc;
  List<Map<String, dynamic>> _tests = [];
  bool _hasMore = true;
  bool _isLoading = true;
  final int _pageSize = 10;

  // Поля для фильтров
  HistoryFilters _filters = HistoryFilters();
  List<String> _testTypes = [];
  DateTime? _startDate;
  DateTime? _endDate;
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
    _loadSelectedFilters();
    _loadHistory(reset: true);
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
        // Если документ пользователя не существует, создаём его с пустыми фильтрами
        await _firestore.collection('users').doc(user.uid).set({
          'history_filters': {
            'test_type': null,
            'start_date': null,
            'end_date': null,
          },
        }, SetOptions(merge: true));
        return;
      }

      // Получаем данные документа
      Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;
      if (data == null || !data.containsKey('history_filters')) {
        // Если поле history_filters отсутствует, создаём его
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
            startDate: filters['start_date'] != null
                ? DateTime.parse(filters['start_date'])
                : null,
            endDate: filters['end_date'] != null
                ? DateTime.parse(filters['end_date'])
                : null,
          );
          _startDate = _filters.startDate;
          _endDate = _filters.endDate;
        });
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

  Future<void> _loadHistory({bool reset = false}) async {
    if (!_hasMore && !reset) return;

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

      Query<Map<String, dynamic>> query = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('test_history')
          .orderBy('date', descending: true)
          .limit(_pageSize);

      if (_lastDoc != null && !reset) {
        query = query.startAfterDocument(_lastDoc!);
      }

      // Применяем фильтры
      try {
        if (_filters.testType != null) {
          query = query.where('test_type', isEqualTo: _filters.testType);
        }
        if (_filters.startDate != null) {
          query = query.where('date',
              isGreaterThanOrEqualTo: _filters.startDate!.toIso8601String());
        }
        if (_filters.endDate != null) {
          query = query.where('date',
              isLessThanOrEqualTo: _filters.endDate!.toIso8601String());
        }

        QuerySnapshot snapshot = await query.get();

        if (reset) {
          _tests.clear();
        }

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
            'categories': categories,
          });
        }

        if (mounted) {
          setState(() {
            _tests.addAll(loadedTests);
            _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
            _hasMore = snapshot.docs.length == _pageSize;
            _isLoading = false;
          });
          _animationController.reset();
          _animationController.forward();
        }
      } catch (e) {
        // Если Firestore требует индекс, загружаем данные без фильтров
        if (e.toString().contains('requires an index')) {
          if (mounted) {
            _showError(
                'Для использования фильтров требуется создать индекс в Firestore. Пожалуйста, обратитесь к администратору или загрузите данные без фильтров.');
          }
          // Загружаем без фильтров
          Query<Map<String, dynamic>> fallbackQuery = _firestore
              .collection('users')
              .doc(user.uid)
              .collection('test_history')
              .orderBy('date', descending: true)
              .limit(_pageSize);

          if (_lastDoc != null && !reset) {
            fallbackQuery = fallbackQuery.startAfterDocument(_lastDoc!);
          }

          QuerySnapshot snapshot = await fallbackQuery.get();

          if (reset) {
            _tests.clear();
          }

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
              'categories': categories,
            });
          }

          if (mounted) {
            setState(() {
              _tests.addAll(loadedTests);
              _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
              _hasMore = snapshot.docs.length == _pageSize;
              _isLoading = false;
            });
            _animationController.reset();
            _animationController.forward();
          }
        } else {
          throw e; // Перебрасываем другие ошибки
        }
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

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(color: _currentTheme == 'light' ? Colors.white : Colors.black),
          ),
          backgroundColor: _currentTheme == 'light' ? Colors.red : Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _clearHistory() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _currentTheme == 'light' ? Colors.white : const Color(0xFF2E004F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          'Очистить историю?',
          style: TextStyle(
            color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Вы уверены, что хотите удалить всю историю тестов? Это действие нельзя отменить.',
          style: TextStyle(
            color: _currentTheme == 'light' ? Colors.grey[800] : Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Отмена',
              style: TextStyle(
                color: _currentTheme == 'light' ? Colors.grey : Colors.white70,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Очистить',
              style: TextStyle(color: Colors.red),
            ),
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
              _tests.clear();
              _lastDoc = null;
              _hasMore = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'История очищена',
                  style: TextStyle(color: _currentTheme == 'light' ? Colors.white : Colors.black),
                ),
                backgroundColor: _currentTheme == 'light' ? Colors.green : Colors.greenAccent,
              ),
            );
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _currentTheme == 'light' ? Colors.white : const Color(0xFF2E004F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Фильтры',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _filters.testType,
                hint: const Text('Вид теста'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Все тесты'),
                  ),
                  ..._testTypes.map((testType) {
                    return DropdownMenuItem<String>(
                      value: testType,
                      child: Text(testType),
                    );
                  }).toList(),
                ],
                onChanged: (value) {
                  setState(() {
                    _filters = HistoryFilters(
                      testType: value,
                      startDate: _filters.startDate,
                      endDate: _filters.endDate,
                    );
                  });
                },
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.filter_alt, color: _currentTheme == 'light' ? Colors.grey : Colors.white70),
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
                  labelText: 'Выберите вид теста',
                  labelStyle: TextStyle(color: _currentTheme == 'light' ? Colors.grey : Colors.white70),
                ),
                style: TextStyle(color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white),
                dropdownColor: _currentTheme == 'light' ? Colors.white : const Color(0xFF2E004F),
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
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.light().copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: _currentTheme == 'light' ? const Color(0xFFFF6F61) : const Color(0xFF8E2DE2),
                                  onPrimary: Colors.white,
                                ),
                                dialogBackgroundColor: _currentTheme == 'light' ? Colors.white : const Color(0xFF2E004F),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null && mounted) {
                          setState(() {
                            _startDate = picked;
                            _filters = HistoryFilters(
                              testType: _filters.testType,
                              startDate: picked,
                              endDate: _filters.endDate,
                            );
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Дата начала',
                          labelStyle: TextStyle(color: _currentTheme == 'light' ? Colors.grey : Colors.white70),
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
                        child: Text(
                          _startDate != null
                              ? DateFormat('d MMMM yyyy', 'ru').format(_startDate!)
                              : 'Выберите дату',
                          style: TextStyle(
                            color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                          ),
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
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.light().copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: _currentTheme == 'light' ? const Color(0xFFFF6F61) : const Color(0xFF8E2DE2),
                                  onPrimary: Colors.white,
                                ),
                                dialogBackgroundColor: _currentTheme == 'light' ? Colors.white : const Color(0xFF2E004F),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null && mounted) {
                          setState(() {
                            _endDate = picked;
                            _filters = HistoryFilters(
                              testType: _filters.testType,
                              startDate: _filters.startDate,
                              endDate: picked,
                            );
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Дата окончания',
                          labelStyle: TextStyle(color: _currentTheme == 'light' ? Colors.grey : Colors.white70),
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
                        child: Text(
                          _endDate != null
                              ? DateFormat('d MMMM yyyy', 'ru').format(_endDate!)
                              : 'Выберите дату',
                          style: TextStyle(
                            color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildAnimatedButton(
                    onPressed: () async {
                      await _saveFilters();
                      await _loadHistory(reset: true);
                      Navigator.pop(context);
                    },
                    gradientColors: _currentTheme == 'light'
                        ? [const Color(0xFF4A90E2), const Color(0xFF50C9C3)]
                        : [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)],
                    label: 'Применить',
                  ),
                  const SizedBox(width: 16),
                  _buildAnimatedButton(
                    onPressed: () async {
                      setState(() {
                        _filters = HistoryFilters();
                        _startDate = null;
                        _endDate = null;
                      });
                      await _saveFilters();
                      await _loadHistory(reset: true);
                      Navigator.pop(context);
                    },
                    gradientColors: [Colors.grey, Colors.grey],
                    label: 'Сбросить',
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatistics() {
    if (_tests.isEmpty) {
      return const SizedBox.shrink();
    }

    Map<String, List<Map<String, dynamic>>> groupedByTestType = {};
    for (var test in _tests) {
      String testType = test['test_type'] as String;
      if (!groupedByTestType.containsKey(testType)) {
        groupedByTestType[testType] = [];
      }
      groupedByTestType[testType]!.add(test);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groupedByTestType.entries.map((entry) {
        String testType = entry.key;
        List<Map<String, dynamic>> testsOfType = entry.value;

        int totalTests = testsOfType.length;

        double totalPoints = 0.0;
        int totalCorrect = 0;
        int totalQuestions = 0;
        int totalTimeSpent = 0;

        for (var test in testsOfType) {
          List<Map<String, dynamic>> categories = test['categories'] as List<Map<String, dynamic>>;
          double testPoints = categories.fold(
              0.0, (sum, cat) => sum + (cat['points'] as double));
          totalPoints += testPoints;

          totalCorrect += categories.fold(
              0, (sum, cat) => sum + (cat['correct_answers'] as int));
          totalQuestions += categories.fold(
              0, (sum, cat) => sum + (cat['total_questions'] as int));
          totalTimeSpent += categories.fold(
              0, (sum, cat) => sum + (cat['time_spent'] as int));
        }

        double avgPoints = totalTests > 0 ? totalPoints / totalTests : 0.0;
        double avgCorrectPercentage =
            totalQuestions > 0 ? (totalCorrect / totalQuestions * 100) : 0.0;

        List<ProgressPoint> progressData = testsOfType.map((test) {
          List<Map<String, dynamic>> categories = test['categories'] as List<Map<String, dynamic>>;
          double testPoints = categories.fold(
              0.0, (sum, cat) => sum + (cat['points'] as double));
          return ProgressPoint(
            DateTime.parse(test['date'] as String),
            testPoints,
          );
        }).toList()
          ..sort((a, b) => a.date.compareTo(b.date));

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
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.analytics,
                          color: _currentTheme == 'light' ? Colors.grey : Colors.white70,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Статистика: $testType',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.format_list_numbered,
                          color: _currentTheme == 'light' ? Colors.grey : Colors.white70,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Всего тестов: $totalTests',
                          style: TextStyle(
                            color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          color: _currentTheme == 'light' ? Colors.amber : Colors.amberAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Средний балл: ${avgPoints.toStringAsFixed(1)}',
                          style: TextStyle(
                            color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: _currentTheme == 'light' ? Colors.green : Colors.greenAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Процент правильных: ${avgCorrectPercentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.timer,
                          color: _currentTheme == 'light' ? Colors.grey : Colors.white70,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Время: ${(totalTimeSpent ~/ 60)} мин',
                          style: TextStyle(
                            color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 150,
                      child: CustomPaint(
                        painter: ProgressLinePainter(
                          progressData,
                          textColor: _currentTheme == 'light' ? Colors.grey : Colors.white70,
                          lineColor: _currentTheme == 'light' ? const Color(0xFFFF6F61) : const Color(0xFF8E2DE2),
                        ),
                        child: Container(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return Center(
        child: Text(
          'Пользователь не авторизован',
          style: TextStyle(
            color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
            fontSize: 16,
          ),
        ),
      );
    }

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
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: RefreshIndicator(
          onRefresh: () async {
            await _loadHistory(reset: true);
          },
          color: _currentTheme == 'light' ? const Color(0xFFFF6F61) : const Color(0xFF8E2DE2),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'История тестов',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.filter_alt,
                              color: _currentTheme == 'light' ? const Color(0xFF4A90E2) : const Color(0xFF8E2DE2),
                            ),
                            onPressed: _showFilterModal,
                            tooltip: 'Фильтры',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: _clearHistory,
                            tooltip: 'Очистить историю',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildStatistics(),
                  const SizedBox(height: 16),
                  if (_isLoading && _tests.isEmpty)
                    const Center(child: CircularProgressIndicator())
                  else if (_tests.isEmpty)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: Text(
                                'История пуста',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
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
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _currentTheme == 'light' ? Colors.grey : Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _tests.length,
                          itemBuilder: (context, index) {
                            final test = _tests[index];
                            final testType = test['test_type'] as String;
                            final date = DateTime.parse(test['date'] as String);

                            return FadeTransition(
                              opacity: _fadeAnimation,
                              child: SlideTransition(
                                position: _slideAnimation,
                                child: Card(
                                  color: _currentTheme == 'light' ? Colors.white : Colors.white.withOpacity(0.05),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    side: BorderSide(
                                      color: _currentTheme == 'light' ? Colors.grey[200]! : Colors.transparent,
                                      width: 1,
                                    ),
                                  ),
                                  elevation: _currentTheme == 'light' ? 5 : 0,
                                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.history,
                                      color: _currentTheme == 'light' ? Colors.grey : Colors.white70,
                                    ),
                                    title: Text(
                                      testType,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Дата: ${DateFormat('d MMMM yyyy, HH:mm', 'ru').format(date)}',
                                      style: TextStyle(
                                        color: _currentTheme == 'light' ? Colors.grey : Colors.white70,
                                      ),
                                    ),
                                    trailing: Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: _currentTheme == 'light' ? Colors.grey : Colors.white70,
                                    ),
                                    onTap: () {
                                      List<Map<String, dynamic>> categories = test['categories'] as List<Map<String, dynamic>>;
                                      double testTotalPoints = categories.fold(
                                          0.0, (sum, cat) => sum + (cat['points'] as double));

                                      showModalBottomSheet(
                                        context: context,
                                        backgroundColor: _currentTheme == 'light' ? Colors.white : const Color(0xFF2E004F),
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                                                    Text(
                                                      'Результаты теста: $testType',
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.bold,
                                                        color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                                      ),
                                                    ),
                                                    Text(
                                                      'Общий балл: ${testTotalPoints.toStringAsFixed(1)}',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: _currentTheme == 'light'
                                                            ? const Color(0xFF4A90E2)
                                                            : const Color(0xFF8E2DE2),
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
                                                      final percentage = totalQuestions > 0
                                                          ? (correctAnswers / totalQuestions * 100)
                                                          : 0.0;

                                                      return ListTile(
                                                        leading: Icon(
                                                          Icons.category,
                                                          color: _currentTheme == 'light' ? Colors.grey : Colors.white70,
                                                        ),
                                                        title: Text(
                                                          '$catName ${timeSpent ~/ 60}/${totalTime ~/ 60} мин',
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                                          ),
                                                        ),
                                                        subtitle: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              'Баллы: ${points.toStringAsFixed(1)}',
                                                              style: TextStyle(
                                                                color: _currentTheme == 'light' ? Colors.grey : Colors.white70,
                                                              ),
                                                            ),
                                                            Text(
                                                              'Правильных: $correctAnswers/$totalQuestions (${percentage.toStringAsFixed(1)}%)',
                                                              style: TextStyle(
                                                                color: _currentTheme == 'light' ? Colors.grey : Colors.white70,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        onTap: () {
                                                          showDialog(
                                                            context: context,
                                                            builder: (context) => AlertDialog(
                                                              backgroundColor: _currentTheme == 'light'
                                                                  ? Colors.white
                                                                  : const Color(0xFF2E004F),
                                                              shape: RoundedRectangleBorder(
                                                                  borderRadius: BorderRadius.circular(15)),
                                                              title: Text(
                                                                'Результат: $testType - $catName',
                                                                style: TextStyle(
                                                                  color: _currentTheme == 'light'
                                                                      ? const Color(0xFF2E2E2E)
                                                                      : Colors.white,
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                              content: SingleChildScrollView(
                                                                child: Column(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    Text(
                                                                      'Дата: ${DateFormat('d MMMM yyyy, HH:mm', 'ru').format(date)}',
                                                                      style: TextStyle(
                                                                        color: _currentTheme == 'light'
                                                                            ? Colors.grey[800]
                                                                            : Colors.white70,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(height: 8),
                                                                    Text(
                                                                      'Баллы: ${points.toStringAsFixed(1)}',
                                                                      style: TextStyle(
                                                                        color: _currentTheme == 'light'
                                                                            ? Colors.grey[800]
                                                                            : Colors.white70,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(height: 8),
                                                                    Text(
                                                                      'Правильных: $correctAnswers/$totalQuestions (${percentage.toStringAsFixed(1)}%)',
                                                                      style: TextStyle(
                                                                        color: _currentTheme == 'light'
                                                                            ? Colors.grey[800]
                                                                            : Colors.white70,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(height: 8),
                                                                    Text(
                                                                      'Время: ${timeSpent ~/ 60} мин из ${totalTime ~/ 60} мин',
                                                                      style: TextStyle(
                                                                        color: _currentTheme == 'light'
                                                                            ? Colors.grey[800]
                                                                            : Colors.white70,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () => Navigator.pop(context),
                                                                  child: Text(
                                                                    'Закрыть',
                                                                    style: TextStyle(
                                                                      color: _currentTheme == 'light'
                                                                          ? const Color(0xFF4A90E2)
                                                                          : const Color(0xFF8E2DE2),
                                                                    ),
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
                                                  child: _buildAnimatedButton(
                                                    onPressed: () => Navigator.pop(context),
                                                    gradientColors: _currentTheme == 'light'
                                                        ? [const Color(0xFFFF6F61), const Color(0xFFFFB74D)]
                                                        : [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)],
                                                    label: 'Закрыть',
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
                        ),
                        if (_hasMore)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: _isLoading
                                ? const Center(child: CircularProgressIndicator())
                                : _buildAnimatedButton(
                                    onPressed: () async {
                                      await _loadHistory();
                                    },
                                    gradientColors: _currentTheme == 'light'
                                        ? [const Color(0xFF4A90E2), const Color(0xFF50C9C3)]
                                        : [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)],
                                    label: 'Загрузить ещё',
                                  ),
                          ),
                      ],
                    ),
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

class ProgressLinePainter extends CustomPainter {
  final List<ProgressPoint> data;
  final Color textColor;
  final Color lineColor;

  ProgressLinePainter(this.data, {required this.textColor, required this.lineColor});

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

    // Временно убираем TextPainter для проверки компиляции
    final axisPaint = Paint()
      ..color = textColor
      ..strokeWidth = 1;

    double maxPoints = data.map((p) => p.points).reduce((a, b) => a > b ? a : b);
    maxPoints = maxPoints == 0 ? 1 : maxPoints;
    final minDate = data.first.date;
    final maxDate = data.last.date;
    final dateRange = maxDate.difference(minDate).inDays.toDouble();
    final widthPerDay = dateRange > 0 ? (size.width - 40) / dateRange : size.width - 40;

    Path path = Path();
    for (int i = 0; i < data.length; i++) {
      final point = data[i];
      final x = 40 + point.date.difference(minDate).inDays * widthPerDay;
      final y = (size.height - 40) * (1 - point.points / maxPoints) + 20;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
    }

    canvas.drawPath(path, paint);

    // Оси
    canvas.drawLine(Offset(40, size.height - 20), Offset(size.width, size.height - 20), axisPaint);
    canvas.drawLine(Offset(40, 20), Offset(40, size.height - 20), axisPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}