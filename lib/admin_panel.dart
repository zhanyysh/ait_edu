import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({Key? key}) : super(key: key);

  @override
  _AdminPanelPageState createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Админ-панель'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
            tooltip: 'Выйти',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Виды тестов'),
            Tab(text: 'Категории'),
            Tab(text: 'Вопросы'),
            Tab(text: 'Контесты'),
            Tab(text: 'Материалы'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          TestTypesTab(),
          CategoriesTab(),
          QuestionsTab(),
          ContestsTab(),
          StudyMaterialsTab(),
        ],
      ),
    );
  }
}

// Вкладка "Виды тестов"
class TestTypesTab extends StatefulWidget {
  const TestTypesTab({Key? key}) : super(key: key);

  @override
  _TestTypesTabState createState() => _TestTypesTabState();
}

class _TestTypesTabState extends State<TestTypesTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _testTypeNameController = TextEditingController();
  String? _editingTestTypeId;

  Future<void> _addOrUpdateTestType() async {
    if (_testTypeNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название вида теста')),
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null) return;

    final data = {
      'name': _testTypeNameController.text.trim(),
      'created_by': user.uid,
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      if (_editingTestTypeId == null) {
        await _firestore.collection('test_types').add(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Вид теста добавлен')),
        );
      } else {
        await _firestore.collection('test_types').doc(_editingTestTypeId).update(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Вид теста обновлен')),
        );
        setState(() {
          _editingTestTypeId = null;
        });
      }
      _testTypeNameController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _deleteTestType(String testTypeId) async {
    try {
      await _firestore.collection('test_types').doc(testTypeId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вид теста удален')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при удалении: $e')),
      );
    }
  }

  void _editTestType(String testTypeId, String name) {
    setState(() {
      _editingTestTypeId = testTypeId;
      _testTypeNameController.text = name;
    });
  }

  @override
  void dispose() {
    _testTypeNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Управление видами тестов',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _testTypeNameController,
                  decoration: InputDecoration(
                    labelText: _editingTestTypeId == null
                        ? 'Новый вид теста'
                        : 'Редактировать вид теста',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addOrUpdateTestType,
                child: Text(_editingTestTypeId == null ? 'Добавить' : 'Сохранить'),
              ),
              if (_editingTestTypeId != null) ...[
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _editingTestTypeId = null;
                      _testTypeNameController.clear();
                    });
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  child: const Text('Отмена'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('test_types').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final testTypes = snapshot.data!.docs;
                if (testTypes.isEmpty) {
                  return const Center(child: Text('Нет видов тестов'));
                }
                return ListView.builder(
                  itemCount: testTypes.length,
                  itemBuilder: (context, index) {
                    final testType = testTypes[index];
                    final testTypeId = testType.id;
                    final testTypeName = testType['name'] as String;
                    return ListTile(
                      title: Text(testTypeName),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editTestType(testTypeId, testTypeName),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteTestType(testTypeId),
                          ),
                        ],
                      ),
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

// Вкладка "Категории"
class CategoriesTab extends StatefulWidget {
  const CategoriesTab({Key? key}) : super(key: key);

  @override
  _CategoriesTabState createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<CategoriesTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _categoryNameController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();
  String? _selectedTestTypeId;
  List<String> _selectedLanguages = [];
  String? _editingCategoryId;

  final List<String> _languages = ['ru', 'en', 'ky'];

  Future<void> _addOrUpdateCategory() async {
    // Проверка заполненности полей
    if (_selectedTestTypeId == null) {
      debugPrint('CategoriesTab: Ошибка валидации: _selectedTestTypeId is null');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите вид теста')),
      );
      return;
    }
    if (_categoryNameController.text.isEmpty) {
      debugPrint('CategoriesTab: Ошибка валидации: Название категории пустое');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название категории')),
      );
      return;
    }
    if (_durationController.text.isEmpty) {
      debugPrint('CategoriesTab: Ошибка валидации: Время пустое');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите время')),
      );
      return;
    }
    if (_pointsController.text.isEmpty) {
      debugPrint('CategoriesTab: Ошибка валидации: Баллы пустые');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите баллы за вопрос')),
      );
      return;
    }
    if (_selectedLanguages.isEmpty) {
      debugPrint('CategoriesTab: Ошибка валидации: Языки не выбраны');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите хотя бы один язык')),
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('CategoriesTab: Ошибка: Пользователь не авторизован');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пользователь не авторизован')),
      );
      return;
    }

    try {
      // Парсим время и баллы как double
      final duration = double.parse(_durationController.text);
      final points = double.parse(_pointsController.text);

      final data = {
        'name': _categoryNameController.text.trim(),
        'duration': duration,
        'points_per_question': points,
        'languages': _selectedLanguages,
        'created_by': user.uid,
        'created_at': DateTime.now().toIso8601String(),
      };

      debugPrint('CategoriesTab: Попытка сохранить категорию: $data');

      if (_editingCategoryId == null) {
        await _firestore
            .collection('test_types')
            .doc(_selectedTestTypeId)
            .collection('categories')
            .add(data);
        debugPrint('CategoriesTab: Категория успешно добавлена');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Категория добавлена')),
        );
      } else {
        await _firestore
            .collection('test_types')
            .doc(_selectedTestTypeId)
            .collection('categories')
            .doc(_editingCategoryId)
            .update(data);
        debugPrint('CategoriesTab: Категория успешно обновлена');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Категория обновлена')),
        );
        setState(() {
          _editingCategoryId = null;
        });
      }
      _categoryNameController.clear();
      _durationController.clear();
      _pointsController.clear();
      _selectedLanguages.clear();
    } catch (e) {
      debugPrint('CategoriesTab: Ошибка при сохранении категории: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _deleteCategory(String categoryId) async {
    try {
      await _firestore
          .collection('test_types')
          .doc(_selectedTestTypeId)
          .collection('categories')
          .doc(categoryId)
          .delete();
      debugPrint('CategoriesTab: Категория успешно удалена');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Категория удалена')),
      );
    } catch (e) {
      debugPrint('CategoriesTab: Ошибка при удалении категории: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при удалении: $e')),
      );
    }
  }

  void _editCategory(DocumentSnapshot category) {
    setState(() {
      _editingCategoryId = category.id;
      _categoryNameController.text = category['name'];
      _durationController.text = category['duration'].toString();
      _pointsController.text = category['points_per_question'].toString();
      _selectedLanguages = List<String>.from(category['languages']);
    });
  }

  @override
  void dispose() {
    _categoryNameController.dispose();
    _durationController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Управление категориями',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Выбор вида теста
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
                    _editingCategoryId = null;
                    _categoryNameController.clear();
                    _durationController.clear();
                    _pointsController.clear();
                    _selectedLanguages.clear();
                  });
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          if (_selectedTestTypeId != null) ...[
            TextField(
              controller: _categoryNameController,
              decoration: InputDecoration(
                labelText: _editingCategoryId == null ? 'Название категории' : 'Редактировать категорию',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Время (в минутах)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pointsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Баллы за вопрос',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Выберите языки:'),
            Wrap(
              spacing: 8.0,
              children: _languages.map((lang) {
                return FilterChip(
                  label: Text(lang == 'ru' ? 'Русский' : lang == 'en' ? 'Английский' : 'Кыргызский'),
                  selected: _selectedLanguages.contains(lang),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedLanguages.add(lang);
                      } else {
                        _selectedLanguages.remove(lang);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _addOrUpdateCategory,
                  child: Text(_editingCategoryId == null ? 'Добавить' : 'Сохранить'),
                ),
                if (_editingCategoryId != null) ...[
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _editingCategoryId = null;
                        _categoryNameController.clear();
                        _durationController.clear();
                        _pointsController.clear();
                        _selectedLanguages.clear();
                      });
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                    child: const Text('Отмена'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('test_types')
                    .doc(_selectedTestTypeId)
                    .collection('categories')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Ошибка: ${snapshot.error}'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final categories = snapshot.data!.docs;
                  if (categories.isEmpty) {
                    return const Center(child: Text('Нет категорий'));
                  }
                  return ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final categoryId = category.id;
                      final categoryName = category['name'] as String;
                      final duration = category['duration'] as double;
                      final points = category['points_per_question'] as double;
                      final languages = List<String>.from(category['languages']);
                      return ListTile(
                        title: Text(categoryName),
                        subtitle: Text(
                          'Время: $duration мин, Баллы: $points, Языки: ${languages.join(", ")}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editCategory(category),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteCategory(categoryId),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Вкладка "Вопросы"
class QuestionsTab extends StatefulWidget {
  const QuestionsTab({Key? key}) : super(key: key);

  @override
  _QuestionsTabState createState() => _QuestionsTabState();
}

class _QuestionsTabState extends State<QuestionsTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _questionTextController = TextEditingController();
  final List<TextEditingController> _optionControllers = List.generate(4, (_) => TextEditingController());
  final TextEditingController _orderController = TextEditingController();
  String? _selectedTestTypeId;
  String? _selectedCategoryId;
  String? _selectedLanguage;
  int? _correctAnswerIndex;
  String? _editingQuestionId;

  final List<String> _languages = ['ru', 'en', 'ky'];

  Future<void> _addOrUpdateQuestion() async {
    if (_selectedTestTypeId == null ||
        _selectedCategoryId == null ||
        _selectedLanguage == null ||
        _questionTextController.text.isEmpty ||
        _optionControllers.any((controller) => controller.text.isEmpty) ||
        _correctAnswerIndex == null ||
        _orderController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля')),
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null) return;

    final data = {
      'language': _selectedLanguage,
      'text': _questionTextController.text.trim(),
      'options': _optionControllers.map((controller) => controller.text.trim()).toList(),
      'correct_answer': _correctAnswerIndex,
      'order': int.parse(_orderController.text),
      'created_by': user.uid,
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      if (_editingQuestionId == null) {
        await _firestore
            .collection('test_types')
            .doc(_selectedTestTypeId)
            .collection('categories')
            .doc(_selectedCategoryId)
            .collection('questions')
            .add(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Вопрос добавлен')),
        );
      } else {
        await _firestore
            .collection('test_types')
            .doc(_selectedTestTypeId)
            .collection('categories')
            .doc(_selectedCategoryId)
            .collection('questions')
            .doc(_editingQuestionId)
            .update(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Вопрос обновлен')),
        );
        setState(() {
          _editingQuestionId = null;
        });
      }
      _questionTextController.clear();
      for (var controller in _optionControllers) {
        controller.clear();
      }
      _orderController.clear();
      _correctAnswerIndex = null;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _deleteQuestion(String questionId) async {
    try {
      await _firestore
          .collection('test_types')
          .doc(_selectedTestTypeId)
          .collection('categories')
          .doc(_selectedCategoryId)
          .collection('questions')
          .doc(questionId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вопрос удален')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при удалении: $e')),
      );
    }
  }

  void _editQuestion(DocumentSnapshot question) {
    setState(() {
      _editingQuestionId = question.id;
      _selectedLanguage = question['language'];
      _questionTextController.text = question['text'];
      final options = List<String>.from(question['options']);
      for (int i = 0; i < 4; i++) {
        _optionControllers[i].text = options[i];
      }
      _correctAnswerIndex = question['correct_answer'];
      _orderController.text = question['order'].toString();
    });
  }

  @override
  void dispose() {
    _questionTextController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    _orderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Управление вопросами',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Выбор вида теста
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
                      _editingQuestionId = null;
                      _questionTextController.clear();
                      for (var controller in _optionControllers) {
                        controller.clear();
                      }
                      _orderController.clear();
                      _correctAnswerIndex = null;
                    });
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // Выбор категории
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
                        _editingQuestionId = null;
                        _questionTextController.clear();
                        for (var controller in _optionControllers) {
                          controller.clear();
                        }
                        _orderController.clear();
                        _correctAnswerIndex = null;
                      });
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
            if (_selectedCategoryId != null) ...[
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
              TextField(
                controller: _questionTextController,
                decoration: InputDecoration(
                  labelText: _editingQuestionId == null ? 'Текст вопроса' : 'Редактировать вопрос',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              for (int i = 0; i < 4; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: TextField(
                    controller: _optionControllers[i],
                    decoration: InputDecoration(
                      labelText: 'Вариант ${i + 1}',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _correctAnswerIndex,
                hint: const Text('Правильный ответ'),
                items: List.generate(4, (index) {
                  return DropdownMenuItem<int>(
                    value: index,
                    child: Text('Вариант ${index + 1}'),
                  );
                }),
                onChanged: (value) {
                  setState(() {
                    _correctAnswerIndex = value;
                  });
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _orderController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Порядок вопроса',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _addOrUpdateQuestion,
                    child: Text(_editingQuestionId == null ? 'Добавить' : 'Сохранить'),
                  ),
                  if (_editingQuestionId != null) ...[
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _editingQuestionId = null;
                          _selectedLanguage = null;
                          _questionTextController.clear();
                          for (var controller in _optionControllers) {
                            controller.clear();
                          }
                          _orderController.clear();
                          _correctAnswerIndex = null;
                        });
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                      child: const Text('Отмена'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('test_types')
                    .doc(_selectedTestTypeId)
                    .collection('categories')
                    .doc(_selectedCategoryId)
                    .collection('questions')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Ошибка: ${snapshot.error}'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final questions = snapshot.data!.docs;
                  if (questions.isEmpty) {
                    return const Center(child: Text('Нет вопросов'));
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: questions.length,
                    itemBuilder: (context, index) {
                      final question = questions[index];
                      final questionId = question.id;
                      final questionText = question['text'] as String;
                      final options = List<String>.from(question['options']);
                      final correctAnswer = question['correct_answer'] as int;
                      final language = question['language'] as String;
                      final order = question['order'] as int;
                      return ListTile(
                        title: Text(questionText),
                        subtitle: Text(
                          'Язык: $language, Правильный: ${options[correctAnswer]}, Порядок: $order',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editQuestion(question),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteQuestion(questionId),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Вкладка "Контесты"
class ContestsTab extends StatefulWidget {
  const ContestsTab({Key? key}) : super(key: key);

  @override
  _ContestsTabState createState() => _ContestsTabState();
}

class _ContestsTabState extends State<ContestsTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _selectedTestTypeId;
  DateTime? _selectedDateTime;
  String? _editingContestId;

  Future<void> _addOrUpdateContest() async {
    if (_selectedTestTypeId == null || _selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите вид теста и дату')),
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null) return;

    final data = {
      'test_type_id': _selectedTestTypeId,
      'date': _selectedDateTime!.toIso8601String(),
      'created_by': user.uid,
      'participants': [],
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      if (_editingContestId == null) {
        await _firestore.collection('contests').add(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Контест добавлен')),
        );
      } else {
        await _firestore.collection('contests').doc(_editingContestId).update(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Контест обновлен')),
        );
        setState(() {
          _editingContestId = null;
        });
      }
      setState(() {
        _selectedTestTypeId = null;
        _selectedDateTime = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _deleteContest(String contestId) async {
    try {
      await _firestore.collection('contests').doc(contestId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Контест удален')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при удалении: $e')),
      );
    }
  }

  void _editContest(DocumentSnapshot contest) {
    setState(() {
      _editingContestId = contest.id;
      _selectedTestTypeId = contest['test_type_id'];
      _selectedDateTime = DateTime.parse(contest['date']);
    });
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime ?? DateTime.now()),
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Управление контестами',
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
                    _editingContestId = null;
                    _selectedDateTime = null;
                  });
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _selectDateTime(context),
            child: Text(
              _selectedDateTime == null
                  ? 'Выберите дату и время'
                  : 'Дата: ${_selectedDateTime!.toIso8601String()}',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton(
                onPressed: _addOrUpdateContest,
                child: Text(_editingContestId == null ? 'Добавить' : 'Сохранить'),
              ),
              if (_editingContestId != null) ...[
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _editingContestId = null;
                      _selectedTestTypeId = null;
                      _selectedDateTime = null;
                    });
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  child: const Text('Отмена'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('contests').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final contests = snapshot.data!.docs;
                if (contests.isEmpty) {
                  return const Center(child: Text('Нет контестов'));
                }
                return ListView.builder(
                  itemCount: contests.length,
                  itemBuilder: (context, index) {
                    final contest = contests[index];
                    final contestId = contest.id;
                    final testTypeId = contest['test_type_id'] as String;
                    final date = DateTime.parse(contest['date']);
                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('test_types').doc(testTypeId).get(),
                      builder: (context, testTypeSnapshot) {
                        if (testTypeSnapshot.connectionState == ConnectionState.waiting) {
                          return const ListTile(title: Text('Загрузка...'));
                        }
                        final testTypeName = testTypeSnapshot.data?['name'] ?? 'Неизвестный тест';
                        return ListTile(
                          title: Text('Контест: $testTypeName'),
                          subtitle: Text('Дата: ${date.toIso8601String()}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editContest(contest),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteContest(contestId),
                              ),
                            ],
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

// Вкладка "Обучающие материалы"
class StudyMaterialsTab extends StatefulWidget {
  const StudyMaterialsTab({Key? key}) : super(key: key);

  @override
  _StudyMaterialsTabState createState() => _StudyMaterialsTabState();
}

class _StudyMaterialsTabState extends State<StudyMaterialsTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String? _selectedTestTypeId;
  String? _editingMaterialId;

  Future<void> _addOrUpdateMaterial() async {
    if (_selectedTestTypeId == null ||
        _titleController.text.isEmpty ||
        _contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля')),
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null) return;

    final data = {
      'title': _titleController.text.trim(),
      'content': _contentController.text.trim(),
      'created_by': user.uid,
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      if (_editingMaterialId == null) {
        await _firestore
            .collection('test_types')
            .doc(_selectedTestTypeId)
            .collection('study_materials')
            .add(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Материал добавлен')),
        );
      } else {
        await _firestore
            .collection('test_types')
            .doc(_selectedTestTypeId)
            .collection('study_materials')
            .doc(_editingMaterialId)
            .update(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Материал обновлен')),
        );
        setState(() {
          _editingMaterialId = null;
        });
      }
      _titleController.clear();
      _contentController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _deleteMaterial(String materialId) async {
    try {
      await _firestore
          .collection('test_types')
          .doc(_selectedTestTypeId)
          .collection('study_materials')
          .doc(materialId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Материал удален')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при удалении: $e')),
      );
    }
  }

  void _editMaterial(DocumentSnapshot material) {
    setState(() {
      _editingMaterialId = material.id;
      _titleController.text = material['title'];
      _contentController.text = material['content'];
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Управление обучающими материалами',
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
                    _editingMaterialId = null;
                    _titleController.clear();
                    _contentController.clear();
                  });
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          if (_selectedTestTypeId != null) ...[
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: _editingMaterialId == null ? 'Название материала' : 'Редактировать материал',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Содержимое (текст или ссылка)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _addOrUpdateMaterial,
                  child: Text(_editingMaterialId == null ? 'Добавить' : 'Сохранить'),
                ),
                if (_editingMaterialId != null) ...[
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _editingMaterialId = null;
                        _titleController.clear();
                        _contentController.clear();
                      });
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                    child: const Text('Отмена'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('test_types')
                    .doc(_selectedTestTypeId)
                    .collection('study_materials')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Ошибка: ${snapshot.error}'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final materials = snapshot.data!.docs;
                  if (materials.isEmpty) {
                    return const Center(child: Text('Нет материалов'));
                  }
                  return ListView.builder(
                    itemCount: materials.length,
                    itemBuilder: (context, index) {
                      final material = materials[index];
                      final materialId = material.id;
                      final title = material['title'] as String;
                      final content = material['content'] as String;
                      return ListTile(
                        title: Text(title),
                        subtitle: Text(content),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editMaterial(material),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteMaterial(materialId),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}