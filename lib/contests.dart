import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home.dart';

class ContestsPage extends StatefulWidget {
  const ContestsPage({super.key});

  @override
  _ContestsPageState createState() => _ContestsPageState();
}

class _ContestsPageState extends State<ContestsPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
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

  Future<void> _registerForContest(String contestId, bool isRestricted, String? password) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Вы должны войти, чтобы зарегистрироваться',
            style: TextStyle(color: _currentTheme == 'light' ? Colors.white : Colors.black),
          ),
          backgroundColor: _currentTheme == 'light' ? Colors.red : Colors.redAccent,
        ),
      );
      return;
    }

    if (isRestricted) {
      final TextEditingController passwordController = TextEditingController();
      final bool? passwordCorrect = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _currentTheme == 'light' ? Colors.white : const Color(0xFF2E004F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            'Введите пароль',
            style: TextStyle(
              color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: passwordController,
            decoration: InputDecoration(
              labelText: 'Пароль',
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
            obscureText: true,
            style: TextStyle(color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Отмена',
                style: TextStyle(color: _currentTheme == 'light' ? Colors.grey : Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () async {
                DocumentSnapshot contestDoc = await _firestore.collection('contests').doc(contestId).get();
                if (contestDoc['password'] == passwordController.text) {
                  Navigator.pop(context, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Неверный пароль',
                        style: TextStyle(color: _currentTheme == 'light' ? Colors.white : Colors.black),
                      ),
                      backgroundColor: _currentTheme == 'light' ? Colors.red : Colors.redAccent,
                    ),
                  );
                  Navigator.pop(context, false);
                }
              },
              child: Text(
                'Подтвердить',
                style: TextStyle(
                  color: _currentTheme == 'light' ? const Color(0xFF4A90E2) : const Color(0xFF8E2DE2),
                ),
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
          content: Text(
            'Вы зарегистрированы на контест',
            style: TextStyle(color: _currentTheme == 'light' ? Colors.white : Colors.black),
          ),
          backgroundColor: _currentTheme == 'light' ? Colors.green : Colors.greenAccent,
        ),
      );
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ошибка при регистрации: $e',
            style: TextStyle(color: _currentTheme == 'light' ? Colors.white : Colors.black),
          ),
          backgroundColor: _currentTheme == 'light' ? Colors.red : Colors.redAccent,
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
          content: Text(
            'Вы уже прошли этот тест. Посмотрите результаты.',
            style: TextStyle(color: _currentTheme == 'light' ? Colors.white : Colors.black),
          ),
          backgroundColor: _currentTheme == 'light' ? Colors.red : Colors.redAccent,
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
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Text(
                  'Контесты',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: firestore.collection('contests').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Ошибка: ${snapshot.error}',
                        style: TextStyle(
                          color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                        ),
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
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
                            style: TextStyle(
                              color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                              fontSize: 16,
                            ),
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
                                    color: _currentTheme == 'light' ? Colors.white : Colors.white.withOpacity(0.05),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      side: BorderSide(
                                        color: _currentTheme == 'light' ? Colors.grey[200]! : Colors.transparent,
                                        width: 1,
                                      ),
                                    ),
                                    elevation: _currentTheme == 'light' ? 5 : 0,
                                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.event,
                                        color: _currentTheme == 'light' ? Colors.grey : Colors.white70,
                                      ),
                                      title: Text(
                                        'Контест: $testTypeName ($language)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Дата: ${DateFormat('d MMMM yyyy, HH:mm', 'ru').format(date)}',
                                            style: TextStyle(
                                              color: _currentTheme == 'light' ? Colors.grey : Colors.white70,
                                            ),
                                          ),
                                          Text(
                                            'Длительность: $duration мин',
                                            style: TextStyle(
                                              color: _currentTheme == 'light' ? Colors.grey : Colors.white70,
                                            ),
                                          ),
                                          Text(
                                            'Тип: ${isRestricted ? 'Ограниченный' : 'Открытый'}',
                                            style: TextStyle(
                                              color: _currentTheme == 'light' ? Colors.grey : Colors.white70,
                                            ),
                                          ),
                                          Text(
                                            'Участников: ${participants.length}',
                                            style: TextStyle(
                                              color: _currentTheme == 'light' ? Colors.grey : Colors.white70,
                                            ),
                                          ),
                                          if (isParticipant && !isContestStarted)
                                            Text(
                                              _formatTimeUntil(date),
                                              style: TextStyle(
                                                color: _currentTheme == 'light' ? const Color(0xFF4A90E2) : const Color(0xFF8E2DE2),
                                              ),
                                            ),
                                        ],
                                      ),
                                      trailing: isContestEnded || hasCompleted
                                          ? _buildAnimatedButton(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => ContestResultsPage(contestId: contestId),
                                                  ),
                                                );
                                              },
                                              gradientColors: _currentTheme == 'light'
                                                  ? [const Color(0xFF4A90E2), const Color(0xFF50C9C3)]
                                                  : [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)],
                                              label: 'Результаты',
                                            )
                                          : isContestStarted && isParticipant
                                              ? _buildAnimatedButton(
                                                  onPressed: () => _startContest(contestId, testTypeId, language),
                                                  gradientColors: _currentTheme == 'light'
                                                      ? [Colors.green, Colors.greenAccent]
                                                      : [Colors.greenAccent, Colors.green],
                                                  label: 'Начать',
                                                )
                                              : isParticipant
                                                  ? Text(
                                                      'Зарегистрирован',
                                                      style: TextStyle(
                                                        color: _currentTheme == 'light' ? Colors.green : Colors.greenAccent,
                                                      ),
                                                    )
                                                  : _buildAnimatedButton(
                                                      onPressed: () =>
                                                          _registerForContest(contestId, isRestricted, contest['password']),
                                                      gradientColors: _currentTheme == 'light'
                                                          ? [const Color(0xFFFF6F61), const Color(0xFFFFB74D)]
                                                          : [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)],
                                                      label: 'Зарегистрироваться',
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
          ],
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
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

class ContestResultsPage extends StatefulWidget {
  final String contestId;

  const ContestResultsPage({super.key, required this.contestId});

  @override
  _ContestResultsPageState createState() => _ContestResultsPageState();
}

class _ContestResultsPageState extends State<ContestResultsPage> with SingleTickerProviderStateMixin {
  String _currentTheme = 'light';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Map<String, dynamic>? _userResult;
  int? _userRank;

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
    _loadTheme();
    _loadUserResult();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentTheme = prefs.getString('theme') ?? 'light';
    });
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Результаты контеста',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
          ),
        ),
        backgroundColor: _currentTheme == 'light' ? Colors.white : const Color(0xFF1A0033),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _currentTheme == 'light'
                ? [Colors.white, const Color(0xFFF5E6FF)]
                : [const Color(0xFF1A0033), const Color(0xFF2E004F)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: StreamBuilder<DocumentSnapshot>(
            stream: firestore.collection('contests').doc(widget.contestId).snapshots(),
            builder: (context, contestSnapshot) {
              if (contestSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Ошибка: ${contestSnapshot.error}',
                    style: TextStyle(
                      color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                    ),
                  ),
                );
              }
              if (contestSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
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
                    return const Center(child: CircularProgressIndicator());
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
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
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
                              Icon(
                                Icons.people,
                                color: _currentTheme == 'light' ? Colors.grey : Colors.white70,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Участников: ${participants.length}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                ),
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
                              color: _currentTheme == 'light' ? Colors.white : Colors.white.withOpacity(0.05),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                                side: BorderSide(
                                  color: _currentTheme == 'light' ? Colors.grey[200]! : Colors.transparent,
                                  width: 1,
                                ),
                              ),
                              elevation: _currentTheme == 'light' ? 5 : 0,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ваш результат',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.star,
                                          color: _currentTheme == 'light' ? Colors.amber : Colors.amberAccent,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Место: $_userRank из ${participants.length}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.score,
                                          color: _currentTheme == 'light' ? Colors.grey : Colors.white70,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Баллы: ${_userResult!['points'].toStringAsFixed(1)}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: _currentTheme == 'light' ? Colors.green : Colors.greenAccent,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Правильных: ${_userResult!['correct_answers']}/${_userResult!['total_questions']}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
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
                                child: Text(
                                  'Ошибка: ${resultsSnapshot.error}',
                                  style: TextStyle(
                                    color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                  ),
                                ),
                              );
                            }
                            if (resultsSnapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
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
                                      style: TextStyle(
                                        color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  dataRowHeight: 60,
                                  columns: [
                                    DataColumn(
                                      label: Text(
                                        'Место',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Имя',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Фамилия',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Баллы',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Правильные',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Время',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Дата завершения',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white,
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
                                      cells: [
                                        DataCell(
                                          Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              color: index == 0
                                                  ? Colors.amber
                                                  : index == 1
                                                      ? Colors.grey
                                                      : index == 2
                                                          ? Colors.brown
                                                          : (_currentTheme == 'light'
                                                              ? const Color(0xFF2E2E2E)
                                                              : Colors.white),
                                            ),
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
                                                style: TextStyle(
                                                  color: _currentTheme == 'light'
                                                      ? const Color(0xFF2E2E2E)
                                                      : Colors.white,
                                                ),
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
                                                style: TextStyle(
                                                  color: _currentTheme == 'light'
                                                      ? const Color(0xFF2E2E2E)
                                                      : Colors.white,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            points.toStringAsFixed(1),
                                            style: TextStyle(
                                              color: _currentTheme == 'light'
                                                  ? const Color(0xFF2E2E2E)
                                                  : Colors.white,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            '$correctAnswers/$totalQuestions',
                                            style: TextStyle(
                                              color: _currentTheme == 'light'
                                                  ? const Color(0xFF2E2E2E)
                                                  : Colors.white,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            '${timeSpent ~/ 60} мин ${timeSpent % 60} сек',
                                            style: TextStyle(
                                              color: _currentTheme == 'light'
                                                  ? const Color(0xFF2E2E2E)
                                                  : Colors.white,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            completedAt != null
                                                ? DateFormat('d MMMM yyyy, HH:mm', 'ru').format(completedAt)
                                                : 'Не завершено',
                                            style: TextStyle(
                                              color: _currentTheme == 'light'
                                                  ? const Color(0xFF2E2E2E)
                                                  : Colors.white,
                                            ),
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