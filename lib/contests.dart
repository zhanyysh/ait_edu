import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'custom_animated_button.dart';
import 'test_page.dart';

class ContestsPage extends StatefulWidget {
  final String currentTheme;

  const ContestsPage({super.key, required this.currentTheme});

  @override
  _ContestsPageState createState() => _ContestsPageState();
}

class _ContestsPageState extends State<ContestsPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _registerForContest(String contestId, bool isRestricted, String? password) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Вы должны войти, чтобы зарегистрироваться', style: TextStyle(color: _textColor)),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (isRestricted) {
      final TextEditingController passwordController = TextEditingController();
      final bool? passwordCorrect = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            'Введите пароль',
            style: GoogleFonts.orbitron(
              color: _textColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: 1.2,
            ),
          ),
          content: TextField(
            controller: passwordController,
            decoration: InputDecoration(
              labelText: 'Пароль',
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
            obscureText: true,
            style: TextStyle(color: _textColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Отмена', style: TextStyle(color: _secondaryTextColor)),
            ),
            TextButton(
              onPressed: () async {
                DocumentSnapshot contestDoc = await _firestore.collection('contests').doc(contestId).get();
                if (contestDoc['password'] == passwordController.text) {
                  Navigator.pop(context, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Неверный пароль', style: TextStyle(color: _textColor)),
                      backgroundColor: Colors.red,
                    ),
                  );
                  Navigator.pop(context, false);
                }
              },
              child: Text(
                'Подтвердить',
                style: TextStyle(color: Color(0xFFFF6F61)),
              ),
            ),
          ],
        ),
      );

      if (passwordCorrect != true) return;
    }

    try {
      await _firestore.collection('contests').doc(contestId).update({
        'participants': FieldValue.arrayUnion([user.uid]),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Вы зарегистрированы на контест', style: TextStyle(color: _textColor)),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при регистрации: $e', style: TextStyle(color: _textColor)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _hasUserCompletedContest(String contestId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    DocumentSnapshot resultDoc = await _firestore
        .collection('contest_results')
        .doc(contestId)
        .collection('results')
        .doc(user.uid)
        .get();
    return resultDoc.exists;
  }

  void _startContest(String contestId, String testTypeId, String language) async {
    bool hasCompleted = await _hasUserCompletedContest(contestId);
    if (hasCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Вы уже прошли этот контест. Посмотрите результаты.', style: TextStyle(color: _textColor)),
          backgroundColor: Colors.red,
        ),
      );
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

  String _formatTimeUntil(DateTime contestDate) {
    final now = DateTime.now();
    final difference = contestDate.difference(now);

    if (difference.isNegative) {
      return 'Контест начался';
    }

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;

    List<String> parts = [];
    if (days > 0) parts.add('$days дн.');
    if (hours > 0 || days > 0) parts.add('$hours ч.');
    parts.add('$minutes мин.');

    return 'До начала: ${parts.join(' ')}';
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final firestore = _firestore;

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
            'Контесты',
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
          child: StreamBuilder<QuerySnapshot>(
            stream: firestore.collection('contests').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Ошибка: ${snapshot.error}', style: TextStyle(color: _textColor)));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: _textColor));
              }
              final contests = snapshot.data!.docs;
              if (contests.isEmpty) {
                return Center(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Text(
                        'Нет доступных контестов',
                        style: TextStyle(color: _textColor, fontSize: 16),
                      ),
                    ),
                  ),
                );
              }
              return ListView.builder(
                itemCount: contests.length,
                itemBuilder: (context, index) {
                  final contest = contests[index];
                  final contestId = contest.id;
                  final testTypeId = contest['test_type_id'] as String;
                  final contestData = contest.data() as Map<String, dynamic>;
                  final language = contestData.containsKey('language')
                      ? contestData['language'] as String? ?? 'Не указан'
                      : 'Не указан';
                  final date = DateTime.parse(contest['date']);
                  final duration = contestData.containsKey('duration')
                      ? contestData['duration'] as int? ?? 60
                      : 60;
                  final isRestricted = contest['is_restricted'] as bool;
                  final participants = List<String>.from(contest['participants']);
                  final isParticipant = user != null && participants.contains(user.uid);
                  final now = DateTime.now();
                  final isContestStarted = now.isAfter(date);
                  final isContestEnded = now.isAfter(date.add(Duration(minutes: duration)));

                  return FutureBuilder<DocumentSnapshot>(
                    future: firestore.collection('test_types').doc(testTypeId).get(),
                    builder: (context, testTypeSnapshot) {
                      if (testTypeSnapshot.connectionState == ConnectionState.waiting) {
                        return const ListTile(title: Text('Загрузка...'));
                      }
                      if (testTypeSnapshot.hasError) {
                        return const ListTile(title: Text('Ошибка загрузки типа теста'));
                      }
                      final testTypeName = testTypeSnapshot.data?['name'] ?? 'Неизвестный тест';
                      return FutureBuilder<bool>(
                        future: _hasUserCompletedContest(contestId),
                        builder: (context, completedSnapshot) {
                          if (completedSnapshot.connectionState == ConnectionState.waiting) {
                            return const ListTile(title: Text('Проверка статуса...'));
                          }
                          bool hasCompleted = completedSnapshot.data ?? false;
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
                                          Icon(
                                            Icons.event,
                                            color: Color(0xFFFF6F61),
                                            size: 24,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Контест: $testTypeName ($language)',
                                              style: GoogleFonts.orbitron(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                                color: _textColor,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Дата: ${DateFormat('d MMMM yyyy, HH:mm', 'ru').format(date)}',
                                        style: TextStyle(color: _secondaryTextColor),
                                      ),
                                      Text(
                                        'Длительность: $duration мин',
                                        style: TextStyle(color: _secondaryTextColor),
                                      ),
                                      Text(
                                        'Тип: ${isRestricted ? 'Ограниченный' : 'Открытый'}',
                                        style: TextStyle(color: _secondaryTextColor),
                                      ),
                                      Text(
                                        'Участников: ${participants.length}',
                                        style: TextStyle(color: _secondaryTextColor),
                                      ),
                                      if (isParticipant && !isContestStarted)
                                        Text(
                                          _formatTimeUntil(date),
                                          style: TextStyle(
                                            color: Color(0xFFFF6F61),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      const SizedBox(height: 16),
                                      Divider(color: _borderColor),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          if (hasCompleted || isContestEnded)
                                            CustomAnimatedButton(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => ContestResultsPage(
                                                      contestId: contestId,
                                                      currentTheme: widget.currentTheme,
                                                    ),
                                                  ),
                                                );
                                              },
                                              gradientColors: _buttonGradientColors,
                                              label: 'Результаты',
                                              currentTheme: widget.currentTheme,
                                              isHeader: false,
                                            ),
                                          if (!hasCompleted && isContestStarted && isParticipant && !isContestEnded)
                                            CustomAnimatedButton(
                                              onPressed: () => _startContest(contestId, testTypeId, language),
                                              gradientColors: _buttonGradientColors,
                                              label: 'Начать',
                                              currentTheme: widget.currentTheme,
                                              isHeader: false,
                                            ),
                                          if (!isParticipant && !isContestStarted && !isContestEnded)
                                            CustomAnimatedButton(
                                              onPressed: () => _registerForContest(contestId, isRestricted, contest['password']),
                                              gradientColors: _buttonGradientColors,
                                              label: 'Зарегистрироваться',
                                              currentTheme: widget.currentTheme,
                                              isHeader: false,
                                            ),
                                          if (isParticipant && !isContestStarted)
                                            Text(
                                              'Зарегистрирован',
                                              style: TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
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
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class ContestResultsPage extends StatefulWidget {
  final String contestId;
  final String currentTheme;

  const ContestResultsPage({super.key, required this.contestId, required this.currentTheme});

  @override
  _ContestResultsPageState createState() => _ContestResultsPageState();
}

class _ContestResultsPageState extends State<ContestResultsPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Map<String, dynamic>? _userResult;
  int? _userRank;

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
    _loadUserResult();
  }

  Future<void> _loadUserResult() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DocumentSnapshot userResultDoc = await FirebaseFirestore.instance
        .collection('contest_results')
        .doc(widget.contestId)
        .collection('results')
        .doc(user.uid)
        .get();

    if (userResultDoc.exists) {
      setState(() {
        _userResult = userResultDoc.data() as Map<String, dynamic>;
      });
    }

    QuerySnapshot resultsSnapshot = await FirebaseFirestore.instance
        .collection('contest_results')
        .doc(widget.contestId)
        .collection('results')
        .orderBy('points', descending: true)
        .get();

    int rank = 1;
    for (var doc in resultsSnapshot.docs) {
      if (doc.id == user.uid) {
        setState(() {
          _userRank = rank;
        });
        break;
      }
      rank++;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

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
            'Результаты контеста',
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
          child: StreamBuilder<DocumentSnapshot>(
            stream: firestore.collection('contests').doc(widget.contestId).snapshots(),
            builder: (context, contestSnapshot) {
              if (contestSnapshot.hasError) {
                return Center(child: Text('Ошибка: ${contestSnapshot.error}', style: TextStyle(color: _textColor)));
              }
              if (contestSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: _textColor));
              }
              final contest = contestSnapshot.data!;
              final testTypeId = contest['test_type_id'] as String;
              final contestData = contest.data() as Map<String, dynamic>;
              final language = contestData.containsKey('language')
                  ? contestData['language'] as String? ?? 'Не указан'
                  : 'Не указан';
              final participants = List<String>.from(contest['participants']);

              return FutureBuilder<DocumentSnapshot>(
                future: firestore.collection('test_types').doc(testTypeId).get(),
                builder: (context, testTypeSnapshot) {
                  if (testTypeSnapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: _textColor));
                  }
                  if (testTypeSnapshot.hasError) {
                    return const Center(child: Text('Ошибка загрузки типа теста'));
                  }
                  final testTypeName = testTypeSnapshot.data?['name'] ?? 'Неизвестный тест';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Text(
                            'Контест: $testTypeName ($language)',
                            style: GoogleFonts.orbitron(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _textColor,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Row(
                            children: [
                              Icon(Icons.people, color: _secondaryTextColor),
                              const SizedBox(width: 8),
                              Text(
                                'Участников: ${participants.length}',
                                style: TextStyle(fontSize: 16, color: _textColor),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_userResult != null && _userRank != null) ...[
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
                                    Text(
                                      'Ваш результат',
                                      style: GoogleFonts.orbitron(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: _textColor,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          _userRank == 1
                                              ? Icons.star
                                              : _userRank == 2
                                              ? Icons.star_border
                                              : _userRank == 3
                                              ? Icons.star_half
                                              : Icons.star_border,
                                          color: _userRank == 1
                                              ? Colors.amber
                                              : _userRank == 2
                                              ? Colors.grey
                                              : _userRank == 3
                                              ? Colors.brown
                                              : _secondaryTextColor,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Место: $_userRank из ${participants.length}',
                                          style: TextStyle(fontSize: 16, color: _textColor),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.score, color: _secondaryTextColor, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Баллы: ${_userResult!['points'].toStringAsFixed(1)}',
                                          style: TextStyle(fontSize: 16, color: _textColor),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Правильных: ${_userResult!['correct_answers']}/${_userResult!['total_questions']}',
                                          style: TextStyle(fontSize: 16, color: _textColor),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: firestore
                              .collection('contest_results')
                              .doc(widget.contestId)
                              .collection('results')
                              .orderBy('points', descending: true)
                              .snapshots(),
                          builder: (context, resultsSnapshot) {
                            if (resultsSnapshot.hasError) {
                              return Center(
                                child: Text('Ошибка: ${resultsSnapshot.error}', style: TextStyle(color: _textColor)),
                              );
                            }
                            if (resultsSnapshot.connectionState == ConnectionState.waiting) {
                              return Center(child: CircularProgressIndicator(color: _textColor));
                            }
                            final results = resultsSnapshot.data!.docs;
                            if (results.isEmpty) {
                              return Center(
                                child: FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: SlideTransition(
                                    position: _slideAnimation,
                                    child: Text(
                                      'Результаты отсутствуют',
                                      style: TextStyle(color: _textColor, fontSize: 16),
                                    ),
                                  ),
                                ),
                              );
                            }

                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  columnSpacing: 16,
                                  dataRowHeight: 56,
                                  headingRowHeight: 64,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: _borderColor),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  columns: [
                                    DataColumn(
                                      label: Text(
                                        'Место',
                                        style: GoogleFonts.orbitron(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: _textColor,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Имя',
                                        style: GoogleFonts.orbitron(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: _textColor,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Фамилия',
                                        style: GoogleFonts.orbitron(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: _textColor,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Баллы',
                                        style: GoogleFonts.orbitron(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: _textColor,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Правильные',
                                        style: GoogleFonts.orbitron(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: _textColor,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Время',
                                        style: GoogleFonts.orbitron(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: _textColor,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Дата завершения',
                                        style: GoogleFonts.orbitron(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: _textColor,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                  rows: results.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final result = entry.value;
                                    final userId = result.id;
                                    final points = (result['points'] as num).toDouble();
                                    final timeSpent = result['time_spent'] as int;
                                    final correctAnswers = result['correct_answers'] as int;
                                    final totalQuestions = result['total_questions'] as int;
                                    final completedAt = result['completed_at'] != null
                                        ? DateTime.parse(result['completed_at'])
                                        : null;

                                    return DataRow(
                                      color: MaterialStateProperty.resolveWith<Color?>((states) {
                                        if (index % 2 == 0) {
                                          return widget.currentTheme == 'light'
                                              ? Colors.grey[50]
                                              : Colors.white.withOpacity(0.03);
                                        }
                                        return null;
                                      }),
                                      cells: [
                                        DataCell(
                                          Row(
                                            children: [
                                              if (index == 0)
                                                Icon(Icons.star, color: Colors.amber, size: 20)
                                              else if (index == 1)
                                                Icon(Icons.star_border, color: Colors.grey, size: 20)
                                              else if (index == 2)
                                                  Icon(Icons.star_half, color: Colors.brown, size: 20),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${index + 1}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: _textColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        DataCell(
                                          FutureBuilder<DocumentSnapshot>(
                                            future: firestore.collection('users').doc(userId).get(),
                                            builder: (context, userSnapshot) {
                                              if (userSnapshot.connectionState == ConnectionState.waiting) {
                                                return const Text('Загрузка...');
                                              }
                                              if (userSnapshot.hasError) {
                                                return const Text('Ошибка');
                                              }
                                              final userData = userSnapshot.data!;
                                              final firstName = userData['first_name'] as String? ?? 'Неизвестно';
                                              return Text(
                                                firstName,
                                                style: TextStyle(color: _textColor),
                                              );
                                            },
                                          ),
                                        ),
                                        DataCell(
                                          FutureBuilder<DocumentSnapshot>(
                                            future: firestore.collection('users').doc(userId).get(),
                                            builder: (context, userSnapshot) {
                                              if (userSnapshot.connectionState == ConnectionState.waiting) {
                                                return const Text('Загрузка...');
                                              }
                                              if (userSnapshot.hasError) {
                                                return const Text('Ошибка');
                                              }
                                              final userData = userSnapshot.data!;
                                              final lastName = userData['last_name'] as String? ?? '';
                                              return Text(
                                                lastName,
                                                style: TextStyle(color: _textColor),
                                              );
                                            },
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            points.toStringAsFixed(1),
                                            style: TextStyle(color: _textColor, fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            '$correctAnswers/$totalQuestions',
                                            style: TextStyle(color: _textColor),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            '${timeSpent ~/ 60} мин ${timeSpent % 60} сек',
                                            style: TextStyle(color: _textColor),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            completedAt != null
                                                ? DateFormat('d MMMM yyyy, HH:mm', 'ru').format(completedAt)
                                                : 'Не завершено',
                                            style: TextStyle(color: _textColor),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}