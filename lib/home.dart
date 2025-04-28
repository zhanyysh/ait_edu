import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/test_selection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/settings.dart';
import 'package:flutter_application_1/contests.dart';
import 'package:flutter_application_1/training.dart';
import 'package:flutter_application_1/history.dart';
import 'package:flutter_application_1/custom_animated_button.dart';
import 'package:google_fonts/google_fonts.dart';

class HomePage extends StatefulWidget {
  final Function(String) onThemeChanged;

  const HomePage({super.key, required this.onThemeChanged});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late List<Widget> _pages;
  String _currentTheme = 'light';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  static const Color _primaryColor = Color(0xFFFF6F61);
  static const List<Color> _buttonGradientColors = [
    Color(0xFFFF6F61),
    Color(0xFFDE4B7C),
  ];

  List<Color> get _backgroundColors {
    if (_currentTheme == 'light') {
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

  Color get _textColor {
    return _currentTheme == 'light' ? const Color(0xFF2E2E2E) : Colors.white;
  }

  Color get _secondaryTextColor {
    return _currentTheme == 'light' ? Colors.grey : Colors.white70;
  }

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
    _animationController.forward();
    _loadTheme();
    _updatePages();
  }

  void _updatePages() {
    _pages = [
      TestSelectionPage(currentTheme: _currentTheme),
      TrainingPage(currentTheme: _currentTheme),
      ContestsPage(currentTheme: _currentTheme),
      HistoryPage(currentTheme: _currentTheme),
      SettingsPage(
        onThemeChanged: widget.onThemeChanged,
        currentTheme: _currentTheme,
      ),
    ];
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentTheme = prefs.getString('theme') ?? 'light';
      _updatePages();
    });
  }

  void _toggleTheme() async {
    String newTheme = _currentTheme == 'light' ? 'dark' : 'light';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', newTheme);
    setState(() {
      _currentTheme = newTheme;
      _updatePages();
    });
    widget.onThemeChanged(newTheme);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _animationController.reset();
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
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
            'AiATesTing',
            style: GoogleFonts.orbitron(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: _textColor,
              letterSpacing: 2,
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
            CustomAnimatedButton(
              onPressed: _toggleTheme,
              gradientColors: _buttonGradientColors,
              icon: _currentTheme == 'light' ? Icons.wb_sunny : Icons.nightlight_round,
              currentTheme: _currentTheme,
              horizontalPadding: 12.0,
              verticalPadding: 6.0,
              iconSize: 20.0,
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _pages[_selectedIndex],
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: _primaryColor,
          unselectedItemColor: _secondaryTextColor,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: TextStyle(color: _secondaryTextColor),
          items: [
            BottomNavigationBarItem(
              icon: Icon(
                Icons.quiz,
                color: _selectedIndex == 0 ? _primaryColor : _secondaryTextColor,
              ),
              label: 'Тесты',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.book,
                color: _selectedIndex == 1 ? _primaryColor : _secondaryTextColor,
              ),
              label: 'Обучение',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.event,
                color: _selectedIndex == 2 ? _primaryColor : _secondaryTextColor,
              ),
              label: 'Контесты',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.history,
                color: _selectedIndex == 3 ? _primaryColor : _secondaryTextColor,
              ),
              label: 'История',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.settings,
                color: _selectedIndex == 4 ? _primaryColor : _secondaryTextColor,
              ),
              label: 'Настройки',
            ),
          ],
        ),
      ),
    );
  }
}
