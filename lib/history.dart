import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

class HistoryPageState extends State<HistoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  DocumentSnapshot? _lastDoc;
  List<Map<String, dynamic>> _tests = []; // Список тестов с категориями
  bool _hasMore = true;
  bool _isLoading = true;
  final int _pageSize = 10;

  // Поля для фильтров
  HistoryFilters _filters = HistoryFilters();
  List<String> _testTypes = [];
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadTestTypes();
    _loadSelectedFilters();
    _loadHistory(reset: true);
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
      if (userDoc.exists && userDoc['history_filters'] != null) {
        Map<String, dynamic> filters = userDoc['history_filters'] as Map<String, dynamic>;
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
          'start_date': _filters.startDate?.toIso8601String(),
          'end_date': _filters.endDate?.toIso8601String(),
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
          .orderBy('date', descending: true) // Сортировка по убыванию даты
          .limit(_pageSize);

      if (_lastDoc != null && !reset) {
        query = query.startAfterDocument(_lastDoc!);
      }

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

      // Загружаем категории для каждого теста
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
            // Удаляем подколлекцию categories
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
            // Удаляем сам тест
            await doc.reference.delete();
          }
          if (mounted) {
            setState(() {
              _tests.clear();
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

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Чтобы модальное окно могло растягиваться
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Фильтры',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Выберите вид теста',
                ),
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
                              startDate: _filters.startDate,
                              endDate: picked,
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
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Применить'),
                  ),
                  TextButton(
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
                    child: const Text(
                      'Сбросить',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
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

    // Группируем тесты по test_type
    Map<String, List<Map<String, dynamic>>> groupedByTestType = {};
    for (var test in _tests) {
      String testType = test['test_type'] as String;
      if (!groupedByTestType.containsKey(testType)) {
        groupedByTestType[testType] = [];
      }
      groupedByTestType[testType]!.add(test);
    }

    // Для каждого test_type создаём отдельную карточку статистики
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groupedByTestType.entries.map((entry) {
        String testType = entry.key;
        List<Map<String, dynamic>> testsOfType = entry.value;

        // Подсчитываем общее количество тестов этого типа
        int totalTests = testsOfType.length;

        // Вычисляем статистику для этого типа
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

        // Подготовка данных для графика
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

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Статистика: $testType',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return const Center(child: Text('Пользователь не авторизован'));
    }

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
                          icon: const Icon(
                            Icons.filter_alt,
                            color: Colors.blue,
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
                const SizedBox(height: 8),
                _buildStatistics(),
                const SizedBox(height: 8),
                if (_isLoading && _tests.isEmpty)
                  const Center(child: CircularProgressIndicator())
                else if (_tests.isEmpty)
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
                        itemCount: _tests.length,
                        itemBuilder: (context, index) {
                          final test = _tests[index];
                          final testType = test['test_type'] as String;
                          final date = DateTime.parse(test['date'] as String);

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
                                List<Map<String, dynamic>> categories = test['categories'] as List<Map<String, dynamic>>;
                                // Считаем общий балл теста
                                double testTotalPoints = categories.fold(
                                    0.0, (sum, cat) => sum + (cat['points'] as double));

                                showModalBottomSheet(
                                  context: context,
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
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                'Общий балл: ${testTotalPoints.toStringAsFixed(1)}',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
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
                                                  title: Text(
                                                    '$catName ${timeSpent ~/ 60}/${totalTime ~/ 60} мин',
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
                                                        title: Text('Результат: $testType - $catName'),
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