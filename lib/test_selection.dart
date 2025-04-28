import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'custom_animated_button.dart';
import 'test_page.dart';
import 'package:google_fonts/google_fonts.dart';

class TestSelectionPage extends StatefulWidget {
  final String currentTheme;

  const TestSelectionPage({super.key, required this.currentTheme});

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
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isLoading = true;

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

  Future<void> _loadTestTypes() async {
    try {
      QuerySnapshot testTypesSnapshot = await _firestore.collection('test_types').get();
      if (mounted) {
        setState(() {
          _testTypes = testTypesSnapshot.docs.map((doc) {
            return {'id': doc.id, 'name': doc['name'] as String};
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('TestSelectionPage: Ошибка загрузки видов тестов: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки тестов: $e')));
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
                  .where((testTypeId) => _testTypes.any((testType) => testType['id'] == testTypeId))
                  .toList();
              _selectedLanguages = {
                for (var test in selectedTests) test['test_type_id'] as String: test['language'] as String?,
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки выбранных тестов: $e')));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка сохранения выбранных тестов: $e')));
      }
    }
  }

  Future<void> _loadAvailableLanguages(String testTypeId) async {
    try {
      QuerySnapshot languagesSnapshot =
      await _firestore.collection('test_types').doc(testTypeId).collection('languages').get();

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Выберите вид теста')));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Выберите язык')));
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
          currentTheme: widget.currentTheme,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: SingleChildScrollView(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: _textColor))
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
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
                          'Выберите тест',
                          style: GoogleFonts.orbitron(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _textColor,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedTestTypeId,
                          hint: Text('Выберите вид теста', style: TextStyle(color: _secondaryTextColor)),
                          items: _testTypes.map((testType) {
                            return DropdownMenuItem<String>(
                              value: testType['id'],
                              child: Text(testType['name']!, style: TextStyle(color: _textColor)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedTestTypeId = value;
                            });
                          },
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.quiz, color: _secondaryTextColor),
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
                          dropdownColor: _cardColor,
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: CustomAnimatedButton(
                            onPressed: _addTestType,
                            gradientColors: _buttonGradientColors,
                            label: 'Добавить тест',
                            currentTheme: widget.currentTheme,
                            isHeader: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_selectedTestTypeIds.isNotEmpty) ...[
                  Text(
                    'Выбранные тесты',
                    style: GoogleFonts.orbitron(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.0, // Square cards (height == width)
                    ),
                    itemCount: _selectedTestTypeIds.length,
                    itemBuilder: (context, index) {
                      final testTypeId = _selectedTestTypeIds[index];
                      final testType = _testTypes.firstWhere(
                            (testType) => testType['id'] == testTypeId,
                        orElse: () => {'id': testTypeId, 'name': 'Неизвестный тест'},
                      );
                      final testTypeName = testType['name']!;
                      final languages = _availableLanguages[testTypeId] ?? [];
                      final selectedLanguage = _selectedLanguages[testTypeId];

                      return Card(
                        color: _cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(color: _borderColor, width: 1),
                        ),
                        elevation: widget.currentTheme == 'light' ? 4 : 0,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0), // Reduced padding for square cards
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      testTypeName,
                                      style: GoogleFonts.orbitron(
                                        fontSize: 14, // Reduced font size
                                        fontWeight: FontWeight.bold,
                                        color: _textColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.close, color: _secondaryTextColor, size: 18), // Smaller icon
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
                              const SizedBox(height: 4), // Reduced spacing
                              if (languages.isNotEmpty)
                                DropdownButtonFormField<String>(
                                  value: selectedLanguage,
                                  hint: Text('Выберите язык', style: TextStyle(color: _secondaryTextColor, fontSize: 12)),
                                  items: languages.map((lang) {
                                    return DropdownMenuItem<String>(
                                      value: lang['code'],
                                      child: Text(lang['name']!, style: TextStyle(color: _textColor, fontSize: 12)),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedLanguages[testTypeId] = value;
                                    });
                                    _saveSelectedTests();
                                  },
                                  decoration: InputDecoration(
                                    prefixIcon: Icon(Icons.language, color: _secondaryTextColor, size: 18), // Smaller icon
                                    filled: true,
                                    fillColor: _fieldFillColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Colors.transparent),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: _primaryColor,
                                        width: 1.5, // Thinner border
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12), // Compact padding
                                  ),
                                  style: TextStyle(color: _textColor),
                                  dropdownColor: _cardColor,
                                )
                              else
                                Text(
                                  'Языки загружаются...',
                                  style: TextStyle(color: _secondaryTextColor, fontSize: 12),
                                ),
                              if (selectedLanguage != null) ...[
                                const Spacer(),
                                CustomAnimatedButton(
                                  onPressed: () => _startTest(testTypeId, selectedLanguage),
                                  gradientColors: _buttonGradientColors,
                                  label: 'Начать',
                                  currentTheme: widget.currentTheme,
                                  horizontalPadding: 6.0, // Smaller button
                                  verticalPadding: 4.0,
                                  isHeader: false,
                                ),
                              ],
                            ],
                          ),
                        ),
                        clipBehavior: Clip.antiAlias, // Ensure rounded corners clip content
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}