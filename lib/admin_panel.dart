import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    _tabController = TabController(length: 6, vsync: this);
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
            Tab(text: 'Добавить язык'),
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
          LanguagesTab(),
          CategoriesTab(),
          QuestionsTab(),
          ContestsTab(),
          StudyMaterialsTab(),
        ],
      ),
    );
  }
}

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
      debugPrint('TestTypesTab: Ошибка валидации: Название вида теста пустое');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название вида теста')),
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('TestTypesTab: Ошибка: Пользователь не авторизован');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пользователь не авторизован')),
      );
      return;
    }

    try {
      IdTokenResult tokenResult = await user.getIdTokenResult(true);
      debugPrint('TestTypesTab: Токен авторизации: ${tokenResult.token}');
      debugPrint('TestTypesTab: Пользователь: ${user.uid}');

      if (_editingTestTypeId == null) {
        await _firestore.collection('test_types').add({
          'name': _testTypeNameController.text,
          'created_by': user.uid,
          'created_at': DateTime.now().toIso8601String(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Вид теста добавлен')),
        );
      } else {
        await _firestore.collection('test_types').doc(_editingTestTypeId).update({
          'name': _testTypeNameController.text,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Вид теста обновлён')),
        );
      }

      _testTypeNameController.clear();
      setState(() {
        _editingTestTypeId = null;
      });
    } catch (e) {
      debugPrint('TestTypesTab: Ошибка: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _deleteTestType(String testTypeId) async {
    try {
      await _firestore.collection('test_types').doc(testTypeId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вид теста удалён')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при удалении: $e')),
      );
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
            'Управление видами тестов',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _testTypeNameController,
            decoration: InputDecoration(
              labelText: 'Название вида теста',
              border: const OutlineInputBorder(),
              suffixIcon: _editingTestTypeId != null
                  ? IconButton(
                      icon: const Icon(Icons.cancel),
                      onPressed: () {
                        setState(() {
                          _editingTestTypeId = null;
                          _testTypeNameController.clear();
                        });
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _addOrUpdateTestType,
            child: Text(_editingTestTypeId == null ? 'Добавить' : 'Обновить'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('test_types').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Ошибка: ${snapshot.error}');
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final testTypes = snapshot.data!.docs;
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
                            onPressed: () {
                              setState(() {
                                _editingTestTypeId = testTypeId;
                                _testTypeNameController.text = testTypeName;
                              });
                            },
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

class LanguagesTab extends StatefulWidget {
  const LanguagesTab({Key? key}) : super(key: key);

  @override
  _LanguagesTabState createState() => _LanguagesTabState();
}

class _LanguagesTabState extends State<LanguagesTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedTestTypeId;
  final TextEditingController _languageNameController = TextEditingController();
  final TextEditingController _languageCodeController = TextEditingController();

  Future<void> _addLanguage() async {
    if (_selectedTestTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите вид теста')),
      );
      return;
    }

    if (_languageNameController.text.isEmpty || _languageCodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название и код языка')),
      );
      return;
    }

    try {
      await _firestore
          .collection('test_types')
          .doc(_selectedTestTypeId)
          .collection('languages')
          .add({
        'name': _languageNameController.text,
        'code': _languageCodeController.text,
        'created_at': DateTime.now().toIso8601String(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Язык добавлен')),
      );

      _languageNameController.clear();
      _languageCodeController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при добавлении языка: $e')),
      );
    }
  }

  Future<void> _deleteLanguage(String languageId) async {
    try {
      await _firestore
          .collection('test_types')
          .doc(_selectedTestTypeId)
          .collection('languages')
          .doc(languageId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Язык удалён')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при удалении языка: $e')),
      );
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
            'Управление языками',
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
                    _languageNameController.clear();
                    _languageCodeController.clear();
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
              controller: _languageNameController,
              decoration: const InputDecoration(
                labelText: 'Название языка (например, Русский)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _languageCodeController,
              decoration: const InputDecoration(
                labelText: 'Код языка (например, ru)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _addLanguage,
              child: const Text('Добавить язык'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('test_types')
                    .doc(_selectedTestTypeId)
                    .collection('languages')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Ошибка: ${snapshot.error}');
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final languages = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: languages.length,
                    itemBuilder: (context, index) {
                      final language = languages[index];
                      final languageId = language.id;
                      final languageName = language['name'] as String;
                      final languageCode = language['code'] as String;
                      return ListTile(
                        title: Text('$languageName ($languageCode)'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteLanguage(languageId),
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

class CategoriesTab extends StatefulWidget {
  const CategoriesTab({Key? key}) : super(key: key);

  @override
  _CategoriesTabState createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<CategoriesTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedTestTypeId;
  final TextEditingController _categoryNameController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _pointsPerQuestionController = TextEditingController();
  final TextEditingController _numberOfQuestionsController = TextEditingController();
  List<String> _selectedLanguages = [];
  String? _editingCategoryId;
  String _selectedTestType = 'multiple-choice'; // Новое поле для типа теста

  Future<void> _addOrUpdateCategory() async {
    if (_selectedTestTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите вид теста')),
      );
      return;
    }

    if (_categoryNameController.text.isEmpty ||
        _durationController.text.isEmpty ||
        _pointsPerQuestionController.text.isEmpty ||
        _numberOfQuestionsController.text.isEmpty ||
        _selectedLanguages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля')),
      );
      return;
    }

    try {
      double duration = double.parse(_durationController.text);
      double pointsPerQuestion = double.parse(_pointsPerQuestionController.text);
      int numberOfQuestions = int.parse(_numberOfQuestionsController.text);

      if (_editingCategoryId == null) {
        await _firestore
            .collection('test_types')
            .doc(_selectedTestTypeId)
            .collection('categories')
            .add({
          'name': _categoryNameController.text,
          'duration': duration,
          'points_per_question': pointsPerQuestion,
          'number_of_questions': numberOfQuestions,
          'languages': _selectedLanguages,
          'test_type': _selectedTestType, // Сохраняем тип теста
          'created_at': DateTime.now().toIso8601String(),
          'created_by': FirebaseAuth.instance.currentUser?.uid,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Категория добавлена')),
        );
      } else {
        await _firestore
            .collection('test_types')
            .doc(_selectedTestTypeId)
            .collection('categories')
            .doc(_editingCategoryId)
            .update({
          'name': _categoryNameController.text,
          'duration': duration,
          'points_per_question': pointsPerQuestion,
          'number_of_questions': numberOfQuestions,
          'languages': _selectedLanguages,
          'test_type': _selectedTestType, // Обновляем тип теста
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Категория обновлена')),
        );
      }

      _categoryNameController.clear();
      _durationController.clear();
      _pointsPerQuestionController.clear();
      _numberOfQuestionsController.clear();
      setState(() {
        _selectedLanguages = [];
        _editingCategoryId = null;
        _selectedTestType = 'multiple-choice';
      });
    } catch (e) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Категория удалена')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при удалении: $e')),
      );
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
            'Управление категориями',
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
                    _editingCategoryId = null;
                    _categoryNameController.clear();
                    _durationController.clear();
                    _pointsPerQuestionController.clear();
                    _numberOfQuestionsController.clear();
                    _selectedLanguages = [];
                    _selectedTestType = 'multiple-choice';
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
              decoration: const InputDecoration(
                labelText: 'Название категории',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Длительность (в минутах)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pointsPerQuestionController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Баллы за вопрос',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _numberOfQuestionsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Количество вопросов',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedTestType,
              decoration: const InputDecoration(
                labelText: 'Тип теста',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'multiple-choice',
                  child: Text('Multiple Choice'),
                ),
                DropdownMenuItem(
                  value: 'reading',
                  child: Text('Reading'),
                ),
                DropdownMenuItem(
                  value: 'writing',
                  child: Text('Writing'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedTestType = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('test_types')
                  .doc(_selectedTestTypeId)
                  .collection('languages')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Ошибка загрузки языков: ${snapshot.error}');
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                final languages = snapshot.data!.docs;
                if (languages.isEmpty) {
                  return const Text(
                    'Нет доступных языков. Сначала добавьте языки для этого теста.',
                    style: TextStyle(color: Colors.red),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Выберите языки:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...languages.map((lang) {
                      final languageName = lang['name'] as String;
                      final languageCode = lang['code'] as String;
                      return CheckboxListTile(
                        title: Text('$languageName ($languageCode)'),
                        value: _selectedLanguages.contains(languageCode),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedLanguages.add(languageCode);
                            } else {
                              _selectedLanguages.remove(languageCode);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _addOrUpdateCategory,
              child: Text(_editingCategoryId == null ? 'Добавить' : 'Обновить'),
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
                    return Text('Ошибка: ${snapshot.error}');
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final categories = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final categoryId = category.id;
                      final categoryName = category['name'] as String;
                      final duration = category['duration'] as double;
                      final pointsPerQuestion = category['points_per_question'] as double;
                      final numberOfQuestions = category['number_of_questions'] as int;
                      final languages = List<String>.from(category['languages']);
                      final testType = category['test_type'] as String? ?? 'multiple-choice';
                      return ListTile(
                        title: Text(categoryName),
                        subtitle: Text(
                          'Тип: $testType\n'
                          'Длительность: $duration мин, Баллы: $pointsPerQuestion, Вопросов: $numberOfQuestions, Языки: ${languages.join(', ')}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () {
                                setState(() {
                                  _editingCategoryId = categoryId;
                                  _categoryNameController.text = categoryName;
                                  _durationController.text = duration.toString();
                                  _pointsPerQuestionController.text = pointsPerQuestion.toString();
                                  _numberOfQuestionsController.text = numberOfQuestions.toString();
                                  _selectedLanguages = languages;
                                  _selectedTestType = testType;
                                });
                              },
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

class QuestionsTab extends StatefulWidget {
  const QuestionsTab({Key? key}) : super(key: key);

  @override
  _QuestionsTabState createState() => _QuestionsTabState();
}

class _QuestionsTabState extends State<QuestionsTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedTestTypeId;
  String? _selectedCategoryId;
  String? _selectedLanguage;
  String? _selectedTestType;
  final TextEditingController _questionTextController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  String? _correctAnswer;
  final TextEditingController _explanationController = TextEditingController();
  String? _editingQuestionId;
  // Поля для reading
  String? _selectedTextId;
  final TextEditingController _readingTextTitleController = TextEditingController();
  final TextEditingController _readingTextContentController = TextEditingController();
  // Поля для writing
  final TextEditingController _writingAnswerController = TextEditingController();

  @override
  void dispose() {
    // Очищаем контроллеры при удалении виджета
    _questionTextController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    _explanationController.dispose();
    _readingTextTitleController.dispose();
    _readingTextContentController.dispose();
    _writingAnswerController.dispose();
    super.dispose();
  }

  Future<void> _addOrUpdateQuestion() async {
    if (_selectedTestTypeId == null || _selectedCategoryId == null || _selectedLanguage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите вид теста, категорию и язык')),
      );
      return;
    }

    if (_questionTextController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите текст вопроса')),
      );
      return;
    }

    try {
      Map<String, dynamic> questionData = {
        'text': _questionTextController.text,
        'explanation': _explanationController.text,
        'language': _selectedLanguage,
        'created_at': DateTime.now().toIso8601String(),
        'created_by': FirebaseAuth.instance.currentUser?.uid,
      };

      if (_selectedTestType == 'multiple-choice') {
        if (_optionControllers.any((controller) => controller.text.isEmpty) || _correctAnswer == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Заполните все варианты ответа и выберите правильный')),
          );
          return;
        }
        questionData['options'] = _optionControllers.map((controller) => controller.text).toList();
        questionData['correct_answer'] = _correctAnswer;
      } else if (_selectedTestType == 'reading') {
        if (_selectedTextId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Выберите текст для вопроса')),
          );
          return;
        }
        if (_optionControllers.any((controller) => controller.text.isEmpty) || _correctAnswer == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Заполните все варианты ответа и выберите правильный')),
          );
          return;
        }
        questionData['reading_text_id'] = _selectedTextId;
        questionData['options'] = _optionControllers.map((controller) => controller.text).toList();
        questionData['correct_answer'] = _correctAnswer;
      } else if (_selectedTestType == 'writing') {
        if (_writingAnswerController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Введите шаблон ответа для writing')),
          );
          return;
        }
        questionData['answer_text'] = _writingAnswerController.text;
      }

      if (_editingQuestionId == null) {
        await _firestore
            .collection('test_types')
            .doc(_selectedTestTypeId)
            .collection('categories')
            .doc(_selectedCategoryId)
            .collection('questions')
            .add(questionData);
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
            .update(questionData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Вопрос обновлён')),
        );
      }

      _resetQuestionForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _addReadingText() async {
    if (_selectedTestTypeId == null || _selectedCategoryId == null || _selectedLanguage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите вид теста, категорию и язык')),
      );
      return;
    }

    if (_readingTextContentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите текст')),
      );
      return;
    }

    try {
      await _firestore
          .collection('test_types')
          .doc(_selectedTestTypeId)
          .collection('categories')
          .doc(_selectedCategoryId)
          .collection('texts')
          .add({
        'title': _readingTextTitleController.text.isEmpty
            ? null
            : _readingTextTitleController.text,
        'content': _readingTextContentController.text,
        'language': _selectedLanguage,
        'created_at': DateTime.now().toIso8601String(),
        'created_by': FirebaseAuth.instance.currentUser?.uid,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Текст добавлен')),
      );
      _readingTextTitleController.clear();
      _readingTextContentController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при добавлении текста: $e')),
      );
    }
  }

  Future<void> _deleteQuestion(String questionId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить вопрос?'),
        content: const Text('Вы уверены, что хотите удалить этот вопрос?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true) {
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
          const SnackBar(content: Text('Вопрос удалён')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при удалении: $e')),
        );
      }
    }
  }

  Future<void> _deleteReadingText(String textId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить текст?'),
        content: const Text('Вы уверены, что хотите удалить этот текст?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore
            .collection('test_types')
            .doc(_selectedTestTypeId)
            .collection('categories')
            .doc(_selectedCategoryId)
            .collection('texts')
            .doc(textId)
            .delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Текст удалён')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при удалении текста: $e')),
        );
      }
    }
  }

  void _resetQuestionForm() {
    _questionTextController.clear();
    for (var controller in _optionControllers) {
      controller.clear();
    }
    _correctAnswer = null;
    _explanationController.clear();
    _writingAnswerController.clear();
    _selectedTextId = null;
    setState(() {
      _editingQuestionId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Управление вопросами',
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
                      _selectedCategoryId = null;
                      _selectedLanguage = null;
                      _selectedTestType = null;
                      _resetQuestionForm();
                      _readingTextTitleController.clear();
                      _readingTextContentController.clear();
                    });
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
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
                        _selectedTestType = null;
                        _resetQuestionForm();
                        _readingTextTitleController.clear();
                        _readingTextContentController.clear();
                      });
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
            if (_selectedCategoryId != null)
              StreamBuilder<DocumentSnapshot>(
                stream: _firestore
                    .collection('test_types')
                    .doc(_selectedTestTypeId)
                    .collection('categories')
                    .doc(_selectedCategoryId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Ошибка: ${snapshot.error}');
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  final category = snapshot.data!;
                  final languages = List<String>.from(category['languages']);
                  _selectedTestType = category['test_type'] as String? ?? 'multiple-choice';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedLanguage,
                        hint: const Text('Выберите язык'),
                        items: languages.map((lang) {
                          return DropdownMenuItem<String>(
                            value: lang,
                            child: Text(lang),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedLanguage = value;
                            _resetQuestionForm();
                            _readingTextTitleController.clear();
                            _readingTextContentController.clear();
                          });
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (_selectedLanguage == null) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Пожалуйста, выберите язык для отображения вопросов',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                      if (_selectedTestType == 'reading' && _selectedLanguage != null) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Добавить текст для чтения',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _readingTextTitleController,
                          decoration: const InputDecoration(
                            labelText: 'Заголовок текста (необязательно)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _readingTextContentController,
                          decoration: const InputDecoration(
                            labelText: 'Содержимое текста',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 5,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _addReadingText,
                          child: const Text('Добавить текст'),
                        ),
                        const SizedBox(height: 16),
                        StreamBuilder<QuerySnapshot>(
                          stream: _firestore
                              .collection('test_types')
                              .doc(_selectedTestTypeId)
                              .collection('categories')
                              .doc(_selectedCategoryId)
                              .collection('texts')
                              .where('language', isEqualTo: _selectedLanguage)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Text('Ошибка: ${snapshot.error}');
                            }
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            final texts = snapshot.data!.docs;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Существующие тексты:',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                ...texts.map((text) {
                                  final textId = text.id;
                                  final title = text['title'] as String? ?? 'Без заголовка';
                                  final content = text['content'] as String;
                                  return ListTile(
                                    title: Text(title),
                                    subtitle: Text(
                                      content.length > 50
                                          ? '${content.substring(0, 50)}...'
                                          : content,
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => _deleteReadingText(textId),
                                    ),
                                  );
                                }).toList(),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        StreamBuilder<QuerySnapshot>(
                          stream: _firestore
                              .collection('test_types')
                              .doc(_selectedTestTypeId)
                              .collection('categories')
                              .doc(_selectedCategoryId)
                              .collection('texts')
                              .where('language', isEqualTo: _selectedLanguage)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Text('Ошибка: ${snapshot.error}');
                            }
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const CircularProgressIndicator();
                            }
                            final texts = snapshot.data!.docs;
                            return DropdownButtonFormField<String>(
                              value: _selectedTextId,
                              hint: const Text('Выберите текст для вопроса'),
                              items: texts.map((text) {
                                final title = text['title'] as String? ?? 'Без заголовка';
                                return DropdownMenuItem<String>(
                                  value: text.id,
                                  child: Text(title),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedTextId = value;
                                });
                              },
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                            );
                          },
                        ),
                      ],
                      if (_selectedLanguage != null) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _questionTextController,
                          decoration: const InputDecoration(
                            labelText: 'Текст вопроса',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        if (_selectedTestType == 'multiple-choice' || _selectedTestType == 'reading') ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Варианты ответа:',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          OptionsInputWidget(
                            optionControllers: _optionControllers,
                            correctAnswer: _correctAnswer,
                            onCorrectAnswerChanged: (value) {
                              setState(() {
                                _correctAnswer = value;
                              });
                            },
                          ),
                        ],
                        if (_selectedTestType == 'writing') ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: _writingAnswerController,
                            decoration: const InputDecoration(
                              labelText: 'Шаблон ответа',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextField(
                          controller: _explanationController,
                          decoration: const InputDecoration(
                            labelText: 'Объяснение',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _addOrUpdateQuestion,
                          child: Text(_editingQuestionId == null ? 'Добавить' : 'Обновить'),
                        ),
                        const SizedBox(height: 16),
                        StreamBuilder<QuerySnapshot>(
                          stream: _firestore
                              .collection('test_types')
                              .doc(_selectedTestTypeId)
                              .collection('categories')
                              .doc(_selectedCategoryId)
                              .collection('questions')
                              .where('language', isEqualTo: _selectedLanguage)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Text('Ошибка: ${snapshot.error}');
                            }
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            final questions = snapshot.data!.docs;
                            if (questions.isEmpty) {
                              return const Center(
                                child: Text(
                                  'Вопросы не найдены. Добавьте новые вопросы или проверьте выбранный язык.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              );
                            }
                            print('Загруженные вопросы: ${questions.map((q) => q.data()).toList()}');
                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: questions.length,
                              itemBuilder: (context, index) {
                                final question = questions[index];
                                final questionId = question.id;
                                final questionText = question['text'] as String;
                                final options = question['options'] != null
                                    ? List<String>.from(question['options'])
                                    : null;
                                final correctAnswer = question['correct_answer'] as String?;
                                final explanation = question['explanation'] as String? ?? 'Нет объяснения';
                                final readingTextId = question.data() != null &&
                                        (question.data() as Map<String, dynamic>).containsKey('reading_text_id')
                                    ? question['reading_text_id'] as String?
                                    : null;
                                final answerText = question.data() != null &&
                                        (question.data() as Map<String, dynamic>).containsKey('answer_text')
                                    ? question['answer_text'] as String?
                                    : null;

                                return ListTile(
                                  title: Text(questionText),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (options != null)
                                        Text('Варианты: ${options.join(', ')}'),
                                      if (correctAnswer != null)
                                        Text('Правильный: $correctAnswer'),
                                      if (readingTextId != null)
                                        Text('Текст ID: $readingTextId'),
                                      if (answerText != null)
                                        Text('Шаблон ответа: $answerText'),
                                      Text('Объяснение: $explanation'),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () {
                                          setState(() {
                                            _editingQuestionId = questionId;
                                            _questionTextController.text = questionText;
                                            if (options != null) {
                                              for (int i = 0; i < _optionControllers.length; i++) {
                                                _optionControllers[i].text = options.length > i ? options[i] : '';
                                              }
                                            }
                                            _correctAnswer = correctAnswer;
                                            _explanationController.text = explanation;
                                            _selectedTextId = readingTextId;
                                            _writingAnswerController.text = answerText ?? '';
                                          });
                                        },
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
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// Новый виджет для управления вариантами ответа и выбором правильного ответа
class OptionsInputWidget extends StatefulWidget {
  final List<TextEditingController> optionControllers;
  final String? correctAnswer;
  final ValueChanged<String?> onCorrectAnswerChanged;

  const OptionsInputWidget({
    Key? key,
    required this.optionControllers,
    required this.correctAnswer,
    required this.onCorrectAnswerChanged,
  }) : super(key: key);

  @override
  _OptionsInputWidgetState createState() => _OptionsInputWidgetState();
}

class _OptionsInputWidgetState extends State<OptionsInputWidget> {
  @override
  void initState() {
    super.initState();
    // Добавляем слушатели к каждому контроллеру
    for (var controller in widget.optionControllers) {
      controller.addListener(_onOptionTextChanged);
    }
  }

  @override
  void dispose() {
    // Удаляем слушатели при удалении виджета
    for (var controller in widget.optionControllers) {
      controller.removeListener(_onOptionTextChanged);
    }
    super.dispose();
  }

  void _onOptionTextChanged() {
    // Обновляем только этот виджет при изменении текста в TextField
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...widget.optionControllers.asMap().entries.map((entry) {
          int index = entry.key;
          TextEditingController controller = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: TextField(
              key: ValueKey('option_$index'),
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Вариант ${index + 1}',
                border: const OutlineInputBorder(),
              ),
            ),
          );
        }).toList(),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: widget.correctAnswer,
          hint: const Text('Правильный ответ'),
          items: widget.optionControllers
              .map((controller) => controller.text)
              .where((text) => text.isNotEmpty)
              .map((option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(option),
            );
          }).toList(),
          onChanged: (value) {
            widget.onCorrectAnswerChanged(value);
          },
          decoration: const InputDecoration(
            labelText: 'Правильный ответ',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}

class ContestsTab extends StatefulWidget {
  const ContestsTab({Key? key}) : super(key: key);

  @override
  _ContestsTabState createState() => _ContestsTabState();
}

class _ContestsTabState extends State<ContestsTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedTestTypeId;
  String? _selectedLanguage;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isRestricted = false;
  final TextEditingController _passwordController = TextEditingController();
  List<Map<String, String>> _availableLanguages = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadLanguages(String testTypeId) async {
    try {
      QuerySnapshot languagesSnapshot = await _firestore
          .collection('test_types')
          .doc(testTypeId)
          .collection('languages')
          .get();
      setState(() {
        _availableLanguages = languagesSnapshot.docs.map((doc) {
          return {
            'name': doc['name'] as String,
            'code': doc['code'] as String,
          };
        }).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки языков: $e')),
      );
    }
  }

  Future<void> _addContest() async {
    if (_selectedTestTypeId == null || _selectedLanguage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите вид теста и язык')),
      );
      return;
    }

    if (_isRestricted && _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите пароль для ограниченного контеста')),
      );
      return;
    }

    try {
      final contestDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      await _firestore.collection('contests').add({
        'test_type_id': _selectedTestTypeId,
        'language': _selectedLanguage,
        'date': contestDateTime.toIso8601String(),
        'is_restricted': _isRestricted,
        'password': _isRestricted ? _passwordController.text : null,
        'participants': [],
        'created_at': DateTime.now().toIso8601String(),
        'created_by': FirebaseAuth.instance.currentUser?.uid,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Контест добавлен')),
      );

      setState(() {
        _selectedTestTypeId = null;
        _selectedLanguage = null;
        _selectedDate = DateTime.now();
        _selectedTime = TimeOfDay.now();
        _isRestricted = false;
        _passwordController.clear();
        _availableLanguages = [];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при добавлении контеста: $e')),
      );
    }
  }

  Future<void> _deleteContest(String contestId) async {
    try {
      await _firestore.collection('contests').doc(contestId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Контест удалён')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при удалении контеста: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
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
                      _selectedLanguage = null;
                      _availableLanguages = [];
                      if (value != null) {
                        _loadLanguages(value);
                      }
                    });
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            if (_selectedTestTypeId != null && _availableLanguages.isNotEmpty)
              DropdownButtonFormField<String>(
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
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Дата: ${_selectedDate.toIso8601String().split('T').first}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (pickedDate != null) {
                      setState(() {
                        _selectedDate = pickedDate;
                      });
                    }
                  },
                  child: const Text('Выбрать дату'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Время: ${_selectedTime.format(context)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: _selectedTime,
                    );
                    if (pickedTime != null) {
                      setState(() {
                        _selectedTime = pickedTime;
                      });
                    }
                  },
                  child: const Text('Выбрать время'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Ограниченный контест:'),
                Checkbox(
                  value: _isRestricted,
                  onChanged: (value) {
                    setState(() {
                      _isRestricted = value ?? false;
                      if (!_isRestricted) {
                        _passwordController.clear();
                      }
                    });
                  },
                ),
              ],
            ),
            if (_isRestricted) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Пароль для контеста',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _addContest,
              child: const Text('Добавить контест'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Существующие контесты:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('contests').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Ошибка: ${snapshot.error}');
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final contests = snapshot.data!.docs;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: contests.length,
                  itemBuilder: (context, index) {
                    final contest = contests[index];
                    final contestId = contest.id;
                    final testTypeId = contest['test_type_id'] as String;
                    final language = contest['language'] as String? ?? 'Не указан';
                    final date = DateTime.parse(contest['date']);
                    final isRestricted = contest['is_restricted'] as bool;
                    final participants = List<String>.from(contest['participants']);

                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('test_types').doc(testTypeId).get(),
                      builder: (context, testTypeSnapshot) {
                        if (testTypeSnapshot.connectionState == ConnectionState.waiting) {
                          return const ListTile(title: Text('Загрузка...'));
                        }
                        final testTypeName = testTypeSnapshot.data?['name'] ?? 'Неизвестный тест';
                        return ListTile(
                          title: Text('Контест: $testTypeName ($language)'),
                          subtitle: Text(
                            'Дата: ${DateFormat('d MMMM yyyy, HH:mm', 'ru').format(date)}\n'
                            'Тип: ${isRestricted ? 'Ограниченный' : 'Открытый'}\n'
                            'Участников: ${participants.length}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteContest(contestId),
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
    );
  }
}

class StudyMaterialsTab extends StatefulWidget {
  const StudyMaterialsTab({Key? key}) : super(key: key);

  @override
  _StudyMaterialsTabState createState() => _StudyMaterialsTabState();
}

class _StudyMaterialsTabState extends State<StudyMaterialsTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedTestTypeId;
  String? _selectedLanguage;
  final TextEditingController _materialTitleController = TextEditingController();
  final TextEditingController _materialContentController = TextEditingController();
  final TextEditingController _miniTestQuestionController = TextEditingController();
  final List<TextEditingController> _miniTestOptionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  String? _miniTestCorrectAnswer;
  final TextEditingController _miniTestExplanationController = TextEditingController();
  String? _editingMaterialId;
  String? _editingMiniTestId;

  Future<void> _addOrUpdateMaterial() async {
    if (_selectedTestTypeId == null || _selectedLanguage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите вид теста и язык')),
      );
      return;
    }

    if (_materialTitleController.text.isEmpty || _materialContentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля')),
      );
      return;
    }

    try {
      if (_editingMaterialId == null) {
        await _firestore
            .collection('test_types')
            .doc(_selectedTestTypeId)
            .collection('study_materials')
            .add({
          'title': _materialTitleController.text,
          'content': _materialContentController.text,
          'language': _selectedLanguage,
          'created_at': DateTime.now().toIso8601String(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Материал добавлен')),
        );
      } else {
        await _firestore
            .collection('test_types')
            .doc(_selectedTestTypeId)
            .collection('study_materials')
            .doc(_editingMaterialId)
            .update({
          'title': _materialTitleController.text,
          'content': _materialContentController.text,
          'language': _selectedLanguage,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Материал обновлён')),
        );
      }

      _materialTitleController.clear();
      _materialContentController.clear();
      setState(() {
        _editingMaterialId = null;
      });
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
        const SnackBar(content: Text('Материал удалён')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при удалении: $e')),
      );
    }
  }

  Future<void> _addOrUpdateMiniTest(String materialId) async {
    if (_miniTestQuestionController.text.isEmpty ||
        _miniTestOptionControllers.any((controller) => controller.text.isEmpty) ||
        _miniTestCorrectAnswer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля мини-теста')),
      );
      return;
    }

    try {
      final options = _miniTestOptionControllers.map((controller) => controller.text).toList();

      if (_editingMiniTestId == null) {
        await _firestore
            .collection('test_types')
            .doc(_selectedTestTypeId)
            .collection('study_materials')
            .doc(materialId)
            .collection('mini_tests')
            .add({
          'text': _miniTestQuestionController.text,
          'options': options,
          'correct_answer': _miniTestCorrectAnswer,
          'explanation': _miniTestExplanationController.text,
          'language': _selectedLanguage,
          'created_at': DateTime.now().toIso8601String(),
          'created_by': FirebaseAuth.instance.currentUser?.uid,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Мини-тест добавлен')),
        );
      } else {
        await _firestore
            .collection('test_types')
            .doc(_selectedTestTypeId)
            .collection('study_materials')
            .doc(materialId)
            .collection('mini_tests')
            .doc(_editingMiniTestId)
            .update({
          'text': _miniTestQuestionController.text,
          'options': options,
          'correct_answer': _miniTestCorrectAnswer,
          'explanation': _miniTestExplanationController.text,
          'language': _selectedLanguage,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Мини-тест обновлён')),
        );
      }

      _miniTestQuestionController.clear();
      for (var controller in _miniTestOptionControllers) {
        controller.clear();
      }
      _miniTestCorrectAnswer = null;
      _miniTestExplanationController.clear();
      setState(() {
        _editingMiniTestId = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _deleteMiniTest(String materialId, String miniTestId) async {
    try {
      await _firestore
          .collection('test_types')
          .doc(_selectedTestTypeId)
          .collection('study_materials')
          .doc(materialId)
          .collection('mini_tests')
          .doc(miniTestId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Мини-тест удалён')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при удалении: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Управление материалами',
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
                      _selectedLanguage = null;
                      _editingMaterialId = null;
                      _editingMiniTestId = null;
                      _materialTitleController.clear();
                      _materialContentController.clear();
                      _miniTestQuestionController.clear();
                      for (var controller in _miniTestOptionControllers) {
                        controller.clear();
                      }
                      _miniTestCorrectAnswer = null;
                      _miniTestExplanationController.clear();
                    });
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            if (_selectedTestTypeId != null)
              StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('test_types')
                    .doc(_selectedTestTypeId)
                    .collection('languages')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Ошибка: ${snapshot.error}');
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  final languages = snapshot.data!.docs;
                  return DropdownButtonFormField<String>(
                    value: _selectedLanguage,
                    hint: const Text('Выберите язык'),
                    items: languages.map((lang) {
                      return DropdownMenuItem<String>(
                        value: lang['code'],
                        child: Text(lang['name']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedLanguage = value;
                        _editingMaterialId = null;
                        _editingMiniTestId = null;
                        _materialTitleController.clear();
                        _materialContentController.clear();
                        _miniTestQuestionController.clear();
                        for (var controller in _miniTestOptionControllers) {
                          controller.clear();
                        }
                        _miniTestCorrectAnswer = null;
                        _miniTestExplanationController.clear();
                      });
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
            if (_selectedLanguage != null) ...[
              TextField(
                controller: _materialTitleController,
                decoration: const InputDecoration(
                  labelText: 'Заголовок материала',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _materialContentController,
                decoration: const InputDecoration(
                  labelText: 'Содержимое материала',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _addOrUpdateMaterial,
                child: Text(_editingMaterialId == null ? 'Добавить материал' : 'Обновить материал'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Мини-тесты',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _miniTestQuestionController,
                decoration: const InputDecoration(
                  labelText: 'Текст вопроса мини-теста',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Варианты ответа:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._miniTestOptionControllers.asMap().entries.map((entry) {
                int index = entry.key;
                TextEditingController controller = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Вариант ${index + 1}',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _miniTestCorrectAnswer = null;
                      });
                    },
                  ),
                );
              }).toList(),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _miniTestCorrectAnswer,
                hint: const Text('Правильный ответ'),
                items: _miniTestOptionControllers
                    .map((controller) => controller.text)
                    .where((text) => text.isNotEmpty)
                    .map((option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _miniTestCorrectAnswer = value;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Правильный ответ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _miniTestExplanationController,
                decoration: const InputDecoration(
                  labelText: 'Объяснение',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Существующие материалы:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('test_types')
                    .doc(_selectedTestTypeId)
                    .collection('study_materials')
                    .where('language', isEqualTo: _selectedLanguage)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Ошибка: ${snapshot.error}');
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final materials = snapshot.data!.docs;
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: materials.length,
                    itemBuilder: (context, index) {
                      final material = materials[index];
                      final materialId = material.id;
                      final title = material['title'] as String;
                      final content = material['content'] as String;
                      return ExpansionTile(
                        title: Text(title),
                        subtitle: Text(content),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () {
                                        setState(() {
                                          _editingMaterialId = materialId;
                                          _materialTitleController.text = title;
                                          _materialContentController.text = content;
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => _deleteMaterial(materialId),
                                    ),
                                  ],
                                ),
                                ElevatedButton(
                                  onPressed: () => _addOrUpdateMiniTest(materialId),
                                  child: Text(_editingMiniTestId == null ? 'Добавить мини-тест' : 'Обновить мини-тест'),
                                ),
                                const SizedBox(height: 16),
                                StreamBuilder<QuerySnapshot>(
                                  stream: _firestore
                                      .collection('test_types')
                                      .doc(_selectedTestTypeId)
                                      .collection('study_materials')
                                      .doc(materialId)
                                      .collection('mini_tests')
                                      .snapshots(),
                                  builder: (context, miniTestSnapshot) {
                                    if (miniTestSnapshot.hasError) {
                                      return Text('Ошибка: ${miniTestSnapshot.error}');
                                    }
                                    if (miniTestSnapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(child: CircularProgressIndicator());
                                    }
                                    final miniTests = miniTestSnapshot.data!.docs;
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
                                        return ListTile(
                                          title: Text(questionText),
                                          subtitle: Text(
                                            'Варианты: ${options.join(', ')}\n'
                                            'Правильный: $correctAnswer\n'
                                            'Объяснение: $explanation',
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit),
                                                onPressed: () {
                                                  setState(() {
                                                    _editingMiniTestId = miniTestId;
                                                    _miniTestQuestionController.text = questionText;
                                                    for (int i = 0; i < _miniTestOptionControllers.length; i++) {
                                                      _miniTestOptionControllers[i].text = options[i];
                                                    }
                                                    _miniTestCorrectAnswer = correctAnswer;
                                                    _miniTestExplanationController.text = explanation;
                                                  });
                                                },
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete),
                                                onPressed: () => _deleteMiniTest(materialId, miniTestId),
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
                        ],
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