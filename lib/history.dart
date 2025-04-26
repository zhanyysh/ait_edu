import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Модель для хранения фильтров
class HistoryFilters {
  final String? testType;
  final String? category;
  final String? language;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? minPoints;
  final double? maxPoints;
  final String sortBy;

  HistoryFilters({
    this.testType,
    this.category,
    this.language,
    this.startDate,
    this.endDate,
    this.minPoints,
    this.maxPoints,
    this.sortBy = 'date_desc',
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

class HistoryPageState extends State<HistoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, String>> _testTypes = [];
  List<Map<String, String>> _categories = [];
  List<Map<String, String>> _languages = [];
  HistoryFilters _filters = HistoryFilters();
  bool _isLoading = true;
  bool _showFilters = false;
  DocumentSnapshot? _lastDoc;
  List<QueryDocumentSnapshot> _history = [];
  bool _hasMore = true;
  final int _pageSize = 10;

  // Контроллеры для фильтров
  final TextEditingController _minPointsController = TextEditingController();
  final TextEditingController _maxPointsController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await Future.wait([
        _loadTestTypes(),
        _loadLanguages(),
        _loadSelectedFilters(),
      ]);
      await _loadHistory(reset: true);
    } catch (e) {
      if (mounted) {
        _showError('Ошибка загрузки данных: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
      if (mounted) {
        _showError('Ошибка загрузки видов тестов: $e');
      }
    }
  }

  Future<void> _loadLanguages() async {
    try {
      Set<String> languageCodes = {};
      List<Map<String, String>> languages = [];
      for (var testType in _testTypes) {
        QuerySnapshot langSnapshot = await _firestore
            .collection('test_types')
            .doc(testType['id'])
            .collection('languages')
            .get();
        for (var lang in langSnapshot.docs) {
          String code = lang['code'] as String;
          if (!languageCodes.contains(code)) {
            languageCodes.add(code);
            languages.add({
              'code': code,
              'name': lang['name'] as String,
            });
          }
        }
      }
      if (mounted) {
        setState(() {
          _languages = languages;
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('Ошибка загрузки языков: $e');
      }
    }
  }

  Future<void> _loadCategories(String? testType) async {
    try {
      List<Map<String, String>> categories = [];
      if (testType == null) {
        for (var testTypeMap in _testTypes) {
          QuerySnapshot categoriesSnapshot = await _firestore
              .collection('test_types')
              .doc(testTypeMap['id'])
              .collection('categories')
              .get();
          categories.addAll(categoriesSnapshot.docs.map((doc) => {
                'test_type': testTypeMap['name']!,
                'category': doc['name'] as String,
              }));
        }
      } else {
        final testTypeId = _testTypes.firstWhere((t) => t['name'] == testType)['id']!;
        QuerySnapshot categoriesSnapshot = await _firestore
            .collection('test_types')
            .doc(testTypeId)
            .collection('categories')
            .get();
        categories = categoriesSnapshot.docs.map((doc) => {
              'test_type': testType,
              'category': doc['name'] as String,
            }).toList();
      }
      if (mounted) {
        setState(() {
          _categories = categories;
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('Ошибка загрузки категорий: $e');
      }
    }
  }

  Future<void> _loadSelectedFilters() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc['history_filters'] != null) {
        Map<String, dynamic> filters = userDoc['history_filters'] as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _filters = HistoryFilters(
              testType: filters['test_type'] as String?,
              category: filters['category'] as String?,
              language: filters['language'] as String?,
              startDate: filters['start_date'] != null
                  ? DateTime.parse(filters['start_date'])
                  : null,
              endDate: filters['end_date'] != null
                  ? DateTime.parse(filters['end_date'])
                  : null,
              minPoints: filters['min_points'] as double?,
              maxPoints: filters['max_points'] as double?,
              sortBy: filters['sort_by'] as String? ?? 'date_desc',
            );
            _minPointsController.text = _filters.minPoints?.toString() ?? '';
            _maxPointsController.text = _filters.maxPoints?.toString() ?? '';
            _startDate = _filters.startDate;
            _endDate = _filters.endDate;
          });
          await _loadCategories(_filters.testType);
        }
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
      await _firestore.collection('users').doc(user.uid).update({
        'history_filters': {
          'test_type': _filters.testType,
          'category': _filters.category,
          'language': _filters.language,
          'start_date': _filters.startDate?.toIso8601String(),
          'end_date': _filters.endDate?.toIso8601String(),
          'min_points': _filters.minPoints,
          'max_points': _filters.maxPoints,
          'sort_by': _filters.sortBy,
        },
      });
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
          .orderBy('date', descending: _filters.sortBy == 'date_desc')
          .limit(_pageSize);

      if (_lastDoc != null && !reset) {
        query = query.startAfterDocument(_lastDoc!);
      }

      if (_filters.testType != null) {
        query = query.where('test_type', isEqualTo: _filters.testType);
      }
      if (_filters.category != null) {
        query = query.where('category', isEqualTo: _filters.category);
      }
      if (_filters.language != null) {
        query = query.where('language', isEqualTo: _filters.language);
      }
      if (_filters.startDate != null) {
        query = query.where('date',
            isGreaterThanOrEqualTo: _filters.startDate!.toIso8601String());
      }
      if (_filters.endDate != null) {
        query = query.where('date',
            isLessThanOrEqualTo: _filters.endDate!.toIso8601String());
      }
      if (_filters.minPoints != null) {
        query = query.where('points',
            isGreaterThanOrEqualTo: _filters.minPoints);
      }
      if (_filters.maxPoints != null) {
        query = query.where('points',
            isLessThanOrEqualTo: _filters.maxPoints);
      }

      QuerySnapshot snapshot = await query.get();

      if (reset) {
        _history.clear();
      }

      if (mounted) {
        setState(() {
          _history.addAll(snapshot.docs);
          _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
          _hasMore = snapshot.docs.length == _pageSize;
          _isLoading = false;
        });
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
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _clearHistory() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить историю?'),
        content: const Text(
            'Вы уверены, что хотите удалить всю историю тестов? Это действие нельзя отменить.'),
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
      final user = _auth.currentUser;
      if (user != null) {
        try {
          QuerySnapshot historySnapshot = await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('test_history')
              .get();
          for (var doc in historySnapshot.docs) {
            await doc.reference.delete();
          }
          if (mounted) {
            setState(() {
              _history.clear();
              _lastDoc = null;
              _hasMore = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('История очищена')),
            );
          }
        } catch (e) {
          if (mounted) {
            _showError('Ошибка очистки истории: $e');
          }
        }
      }
    }
  }

  Widget _buildStatistics() {
    if (_history.isEmpty) {
      return const SizedBox.shrink();
    }

    // Группируем записи по test_type для подсчёта количества тестов
    Map<String, List<QueryDocumentSnapshot>> groupedTests = {};
    for (var record in _history) {
      String testType = record['test_type'] as String;
      if (!groupedTests.containsKey(testType)) {
        groupedTests[testType] = [];
      }
      groupedTests[testType]!.add(record);
    }
    int totalTests = groupedTests.length; // Количество уникальных тестов

    double totalPoints = _history.fold(
        0.0, (sum, doc) => sum + (doc['points'] as num).toDouble());
    int totalCorrect = _history.fold(
        0, (sum, doc) => sum + (doc['correct_answers'] as int));
    int totalQuestions = _history.fold(
        0, (sum, doc) => sum + (doc['total_questions'] as int));
    int totalTimeSpent = _history.fold(
        0, (sum, doc) => sum + (doc['time_spent'] as int));

    double avgPoints = _history.isNotEmpty ? totalPoints / _history.length : 0.0;
    double avgCorrectPercentage =
        totalQuestions > 0 ? (totalCorrect / totalQuestions * 100) : 0.0;

    // Подготовка данных для графика
    List<ProgressPoint> progressData = _history
        .map((doc) => ProgressPoint(
              DateTime.parse(doc['date']),
              (doc['points'] as num).toDouble(),
            ))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Статистика',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Всего тестов: $totalTests'),
            Text('Средний балл: ${avgPoints.toStringAsFixed(1)}'),
            Text('Процент правильных: ${avgCorrectPercentage.toStringAsFixed(1)}%'),
            Text('Время: ${(totalTimeSpent ~/ 60)} мин'),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: CustomPaint(
                painter: ProgressLinePainter(progressData),
                child: Container(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _showFilters ? null : 0,
      child: _showFilters
          ? Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Фильтры',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
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
                            value: testType['name'],
                            child: Text(testType['name']!),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) async {
                        if (mounted) {
                          setState(() {
                            _filters = HistoryFilters(
                              testType: value,
                              category: null,
                              language: _filters.language,
                              startDate: _filters.startDate,
                              endDate: _filters.endDate,
                              minPoints: _filters.minPoints,
                              maxPoints: _filters.maxPoints,
                              sortBy: _filters.sortBy,
                            );
                          });
                          await _loadCategories(value);
                          await _saveFilters();
                          await _loadHistory(reset: true);
                        }
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _filters.category,
                      hint: const Text('Категория'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Все категории'),
                        ),
                        ..._categories.map((cat) {
                          return DropdownMenuItem<String>(
                            value: cat['category'],
                            child: Text('${cat['test_type']}: ${cat['category']}'),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) async {
                        if (mounted) {
                          setState(() {
                            _filters = HistoryFilters(
                              testType: _filters.testType,
                              category: value,
                              language: _filters.language,
                              startDate: _filters.startDate,
                              endDate: _filters.endDate,
                              minPoints: _filters.minPoints,
                              maxPoints: _filters.maxPoints,
                              sortBy: _filters.sortBy,
                            );
                          });
                          await _saveFilters();
                          await _loadHistory(reset: true);
                        }
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _filters.language,
                      hint: const Text('Язык'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Все языки'),
                        ),
                        ..._languages.map((lang) {
                          return DropdownMenuItem<String>(
                            value: lang['code'],
                            child: Text(lang['name']!),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) async {
                        if (mounted) {
                          setState(() {
                            _filters = HistoryFilters(
                              testType: _filters.testType,
                              category: _filters.category,
                              language: value,
                              startDate: _filters.startDate,
                              endDate: _filters.endDate,
                              minPoints: _filters.minPoints,
                              maxPoints: _filters.maxPoints,
                              sortBy: _filters.sortBy,
                            );
                          });
                          await _saveFilters();
                          await _loadHistory(reset: true);
                        }
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minPointsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Мин. баллы',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              if (mounted) {
                                setState(() {
                                  _filters = HistoryFilters(
                                    testType: _filters.testType,
                                    category: _filters.category,
                                    language: _filters.language,
                                    startDate: _filters.startDate,
                                    endDate: _filters.endDate,
                                    minPoints: double.tryParse(value),
                                    maxPoints: _filters.maxPoints,
                                    sortBy: _filters.sortBy,
                                  );
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _maxPointsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Макс. баллы',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              if (mounted) {
                                setState(() {
                                  _filters = HistoryFilters(
                                    testType: _filters.testType,
                                    category: _filters.category,
                                    language: _filters.language,
                                    startDate: _filters.startDate,
                                    endDate: _filters.endDate,
                                    minPoints: _filters.minPoints,
                                    maxPoints: double.tryParse(value),
                                    sortBy: _filters.sortBy,
                                  );
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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
                              );
                              if (picked != null && mounted) {
                                setState(() {
                                  _startDate = picked;
                                  _filters = HistoryFilters(
                                    testType: _filters.testType,
                                    category: _filters.category,
                                    language: _filters.language,
                                    startDate: picked,
                                    endDate: _filters.endDate,
                                    minPoints: _filters.minPoints,
                                    maxPoints: _filters.maxPoints,
                                    sortBy: _filters.sortBy,
                                  );
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Дата начала',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                _startDate != null
                                    ? DateFormat('d MMMM yyyy', 'ru').format(_startDate!)
                                    : 'Выберите дату',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: _endDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null && mounted) {
                                setState(() {
                                  _endDate = picked;
                                  _filters = HistoryFilters(
                                    testType: _filters.testType,
                                    category: _filters.category,
                                    language: _filters.language,
                                    startDate: _filters.startDate,
                                    endDate: picked,
                                    minPoints: _filters.minPoints,
                                    maxPoints: _filters.maxPoints,
                                    sortBy: _filters.sortBy,
                                  );
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Дата окончания',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                _endDate != null
                                    ? DateFormat('d MMMM yyyy', 'ru').format(_endDate!)
                                    : 'Выберите дату',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            await _saveFilters();
                            await _loadHistory(reset: true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Применить'),
                        ),
                        TextButton(
                          onPressed: () async {
                            if (mounted) {
                              setState(() {
                                _filters = HistoryFilters(sortBy: 'date_desc');
                                _minPointsController.clear();
                                _maxPointsController.clear();
                                _startDate = null;
                                _endDate = null;
                                _categories = [];
                              });
                              await _saveFilters();
                              await _loadHistory(reset: true);
                            }
                          },
                          child: const Text(
                            'Сбросить',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return const Center(child: Text('Пользователь не авторизован'));
    }

    // Группируем записи по test_type
    Map<String, List<QueryDocumentSnapshot>> groupedTests = {};
    for (var record in _history) {
      String testType = record['test_type'] as String;
      if (!groupedTests.containsKey(testType)) {
        groupedTests[testType] = [];
      }
      groupedTests[testType]!.add(record);
    }

    // Сортируем тесты по дате последнего прохождения
    var sortedTests = groupedTests.entries.toList()
      ..sort((a, b) {
        DateTime dateA = DateTime.parse(a.value.last['date']);
        DateTime dateB = DateTime.parse(b.value.last['date']);
        return _filters.sortBy == 'date_desc'
            ? dateB.compareTo(dateA)
            : dateA.compareTo(dateB);
      });

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadHistory(reset: true);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
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
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _showFilters ? Icons.filter_alt_off : Icons.filter_alt,
                            color: Colors.blue,
                          ),
                          onPressed: () {
                            setState(() {
                              _showFilters = !_showFilters;
                            });
                          },
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
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _filters.sortBy,
                  items: const [
                    DropdownMenuItem(value: 'date_desc', child: Text('Дата (убыв.)')),
                    DropdownMenuItem(value: 'date_asc', child: Text('Дата (возр.)')),
                    DropdownMenuItem(value: 'points_desc', child: Text('Баллы (убыв.)')),
                    DropdownMenuItem(value: 'points_asc', child: Text('Баллы (возр.)')),
                    DropdownMenuItem(value: 'percent_desc', child: Text('Процент (убыв.)')),
                    DropdownMenuItem(value: 'percent_asc', child: Text('Процент (возр.)')),
                  ],
                  onChanged: (value) async {
                    if (mounted) {
                      setState(() {
                        _filters = HistoryFilters(
                          testType: _filters.testType,
                          category: _filters.category,
                          language: _filters.language,
                          startDate: _filters.startDate,
                          endDate: _filters.endDate,
                          minPoints: _filters.minPoints,
                          maxPoints: _filters.maxPoints,
                          sortBy: value!,
                        );
                      });
                      await _saveFilters();
                      await _loadHistory(reset: true);
                    }
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Сортировка',
                  ),
                ),
                const SizedBox(height: 8),
                _buildFilters(),
                const SizedBox(height: 8),
                _buildStatistics(),
                const SizedBox(height: 8),
                if (_isLoading && _history.isEmpty)
                  const Center(child: CircularProgressIndicator())
                else if (_history.isEmpty)
                  const Center(
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
                  )
                else
                  Column(
                    children: [
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: sortedTests.length,
                        itemBuilder: (context, index) {
                          final testType = sortedTests[index].key;
                          final testRecords = sortedTests[index].value;
                          final latestRecord = testRecords.last; // Самая поздняя запись для даты
                          final date = DateTime.parse(latestRecord['date']);

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 4.0),
                            child: ListTile(
                              title: Text(testType),
                              subtitle: Text(
                                'Дата: ${DateFormat('d MMMM yyyy, HH:mm', 'ru').format(date)}',
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  builder: (context) {
                                    return Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Результаты теста: $testType',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Expanded(
                                            child: ListView.builder(
                                              shrinkWrap: true,
                                              itemCount: testRecords.length,
                                              itemBuilder: (context, idx) {
                                                final record = testRecords[idx];
                                                final category = record['category'] as String;
                                                final points = (record['points'] as num).toDouble();
                                                final correctAnswers = record['correct_answers'] as int;
                                                final totalQuestions = record['total_questions'] as int;
                                                final timeSpent = record['time_spent'] as int;
                                                final totalTime = record['total_time'] as int;
                                                final percentage = totalQuestions > 0
                                                    ? (correctAnswers / totalQuestions * 100)
                                                    : 0.0;

                                                return ListTile(
                                                  title: Text(
                                                    '$category ${timeSpent ~/ 60}/${totalTime ~/ 60} мин',
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                  subtitle: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text('Баллы: ${points.toStringAsFixed(1)}'),
                                                      Text(
                                                          'Правильных: $correctAnswers/$totalQuestions (${percentage.toStringAsFixed(1)}%)'),
                                                    ],
                                                  ),
                                                  onTap: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (context) => AlertDialog(
                                                        title: Text('Результат: $testType - $category'),
                                                        content: SingleChildScrollView(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Text(
                                                                  'Дата: ${DateFormat('d MMMM yyyy, HH:mm', 'ru').format(date)}'),
                                                              const SizedBox(height: 8),
                                                              Text('Баллы: ${points.toStringAsFixed(1)}'),
                                                              const SizedBox(height: 8),
                                                              Text(
                                                                  'Правильных: $correctAnswers/$totalQuestions (${percentage.toStringAsFixed(1)}%)'),
                                                              const SizedBox(height: 8),
                                                              Text('Время: ${timeSpent ~/ 60} мин из ${totalTime ~/ 60} мин'),
                                                            ],
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
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Center(
                                            child: TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('Закрыть', style: TextStyle(color: Colors.blue)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          );
                        },
                      ),
                      if (_hasMore)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton(
                                  onPressed: () async {
                                    await _loadHistory();
                                  },
                                  child: const Text('Загрузить ещё'),
                                ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _minPointsController.dispose();
    _maxPointsController.dispose();
    super.dispose();
  }
}

// Простой линейный график с использованием CustomPainter
class ProgressLinePainter extends CustomPainter {
  final List<ProgressPoint> data;

  ProgressLinePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    // Нормализация данных
    double maxPoints = data.map((p) => p.points).reduce((a, b) => a > b ? a : b);
    maxPoints = maxPoints == 0 ? 1 : maxPoints;
    final minDate = data.first.date;
    final maxDate = data.last.date;
    final dateRange = maxDate.difference(minDate).inDays.toDouble();
    final widthPerDay = dateRange > 0 ? size.width / dateRange : size.width;

    // Построение пути
    Path path = Path();
    for (int i = 0; i < data.length; i++) {
      final point = data[i];
      final x = point.date.difference(minDate).inDays * widthPerDay;
      final y = size.height * (1 - point.points / maxPoints);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      // Рисуем точки
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
    }

    canvas.drawPath(path, paint);

    // Оси
    final axisPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), axisPaint);
    canvas.drawLine(Offset(0, 0), Offset(0, size.height), axisPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}