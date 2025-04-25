import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'home.dart'; // Импорт home.dart для доступа к TestPage

class ContestsPage extends StatefulWidget {
  const ContestsPage({super.key});

  @override
  _ContestsPageState createState() => _ContestsPageState();
}

class _ContestsPageState extends State<ContestsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _registerForContest(String contestId, bool isRestricted, String? password) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вы должны войти, чтобы зарегистрироваться')),
      );
      return;
    }

    if (isRestricted) {
      final TextEditingController passwordController = TextEditingController();
      final bool? passwordCorrect = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Введите пароль'),
          content: TextField(
            controller: passwordController,
            decoration: const InputDecoration(labelText: 'Пароль'),
            obscureText: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () async {
                DocumentSnapshot contestDoc = await _firestore.collection('contests').doc(contestId).get();
                if (contestDoc['password'] == passwordController.text) {
                  Navigator.pop(context, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Неверный пароль')),
                  );
                  Navigator.pop(context, false);
                }
              },
              child: const Text('Подтвердить'),
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
        const SnackBar(content: Text('Вы зарегистрированы на контест')),
      );
      setState(() {}); // Обновляем UI
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при регистрации: $e')),
      );
    }
  }

  void _startContest(String contestId, String testTypeId, String language) {
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

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Контесты',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: firestore.collection('contests').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final contests = snapshot.data!.docs;
                if (contests.isEmpty) {
                  return const Center(child: Text('Нет доступных контестов'));
                }
                return ListView.builder(
                  itemCount: contests.length,
                  itemBuilder: (context, index) {
                    final contest = contests[index];
                    final contestId = contest.id;
                    final testTypeId = contest['test_type_id'] as String;
                    // Безопасно получаем language
                    final contestData = contest.data() as Map<String, dynamic>;
                    final language = contestData.containsKey('language') ? contestData['language'] as String? ?? 'Не указан' : 'Не указан';
                    final date = DateTime.parse(contest['date']);
                    // Безопасно получаем duration
                    final duration = contestData.containsKey('duration') ? contestData['duration'] as int? ?? 60 : 60;
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
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ListTile(
                            title: Text('Контест: $testTypeName ($language)'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Дата: ${DateFormat('d MMMM yyyy, HH:mm', 'ru').format(date)}',
                                ),
                                Text(
                                  'Длительность: $duration мин',
                                ),
                                Text(
                                  'Тип: ${isRestricted ? 'Ограниченный' : 'Открытый'}',
                                ),
                                Text(
                                  'Участников: ${participants.length}',
                                ),
                                if (isParticipant && !isContestStarted)
                                  Text(
                                    _formatTimeUntil(date),
                                    style: const TextStyle(color: Colors.blue),
                                  ),
                              ],
                            ),
                            trailing: isContestEnded
                                ? ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ContestResultsPage(contestId: contestId),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Результаты'),
                                  )
                                : isContestStarted && isParticipant
                                    ? ElevatedButton(
                                        onPressed: () => _startContest(contestId, testTypeId, language),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Начать'),
                                      )
                                    : isParticipant
                                        ? const Text(
                                            'Зарегистрирован',
                                            style: TextStyle(color: Colors.green),
                                          )
                                        : ElevatedButton(
                                            onPressed: () => _registerForContest(contestId, isRestricted, contest['password']),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.blue,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Зарегистрироваться'),
                                          ),
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

class ContestResultsPage extends StatelessWidget {
  final String contestId;

  const ContestResultsPage({super.key, required this.contestId});

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Результаты контеста'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<DocumentSnapshot>(
          stream: firestore.collection('contests').doc(contestId).snapshots(),
          builder: (context, contestSnapshot) {
            if (contestSnapshot.hasError) {
              return Center(child: Text('Ошибка: ${contestSnapshot.error}'));
            }
            if (contestSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final contest = contestSnapshot.data!;
            final testTypeId = contest['test_type_id'] as String;
            // Безопасно получаем language
            final contestData = contest.data() as Map<String, dynamic>;
            final language = contestData.containsKey('language') ? contestData['language'] as String? ?? 'Не указан' : 'Не указан';
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
                    Text(
                      'Контест: $testTypeName ($language)',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Участников: ${participants.length}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: firestore
                            .collection('contest_results')
                            .doc(contestId)
                            .collection('results')
                            .orderBy('points', descending: true)
                            .snapshots(),
                        builder: (context, resultsSnapshot) {
                          if (resultsSnapshot.hasError) {
                            return Center(child: Text('Ошибка: ${resultsSnapshot.error}'));
                          }
                          if (resultsSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final results = resultsSnapshot.data!.docs;
                          if (results.isEmpty) {
                            return const Center(child: Text('Результаты отсутствуют'));
                          }

                          return ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (context, index) {
                              final result = results[index];
                              final userId = result.id;
                              final points = (result['points'] as num).toDouble();
                              final timeSpent = result['time_spent'] as int;
                              final correctAnswers = result['correct_answers'] as int;
                              final totalQuestions = result['total_questions'] as int;
                              final completedAt = result['completed_at'] != null
                                  ? DateTime.parse(result['completed_at'])
                                  : null;

                              return FutureBuilder<DocumentSnapshot>(
                                future: firestore.collection('users').doc(userId).get(),
                                builder: (context, userSnapshot) {
                                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                                    return const ListTile(title: Text('Загрузка...'));
                                  }
                                  if (userSnapshot.hasError) {
                                    return const ListTile(title: Text('Ошибка загрузки пользователя'));
                                  }
                                  final userData = userSnapshot.data!;
                                  final firstName = userData['first_name'] as String? ?? 'Неизвестно';
                                  final lastName = userData['last_name'] as String? ?? '';

                                  return Card(
                                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        child: Text('${index + 1}'),
                                        backgroundColor: index == 0
                                            ? Colors.amber
                                            : index == 1
                                                ? Colors.grey
                                                : index == 2
                                                    ? Colors.brown
                                                    : Colors.blue,
                                      ),
                                      title: Text('$firstName $lastName'),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Баллы: ${points.toStringAsFixed(1)}'),
                                          Text('Правильных: $correctAnswers/$totalQuestions'),
                                          Text('Время: ${timeSpent ~/ 60} мин ${timeSpent % 60} сек'),
                                          if (completedAt != null)
                                            Text(
                                              'Завершено: ${DateFormat('d MMMM yyyy, HH:mm', 'ru').format(completedAt)}',
                                            ),
                                        ],
                                      ),
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
                );
              },
            );
          },
        ),
      ),
    );
  }
}