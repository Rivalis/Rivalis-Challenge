import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "AIzaSyB5HnrM6izJeJ3ZQ3pk6SH5Z-TDDHzt5JA",
      authDomain: "rivalis-73117.firebaseapp.com",
      projectId: "rivalis-73117",
      storageBucket: "rivalis-73117.firebasestorage.app",
      messagingSenderId: "818308848308",
      appId: "1:818308848308:web:4b5771dea721b434f795e1",
      measurementId: "G-1B8PEJ9BZF",
    ),
  );
  runApp(RivalisApp());
}

// --- App ---
class RivalisApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rivalis',
      theme: ThemeData(primarySwatch: Colors.red),
      home: AuthScreen(),
    );
  }
}

// --- Authentication ---
class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool isLogin = true;

  Future<void> submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
        await FirebaseFirestore.instance.collection('leaderboard').doc(email).set({'username': email, 'points': 0});
      }
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isLogin ? 'Login' : 'Register')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _emailController, decoration: InputDecoration(labelText: 'Email')),
            TextField(controller: _passwordController, decoration: InputDecoration(labelText: 'Password'), obscureText: true),
            SizedBox(height: 20),
            ElevatedButton(onPressed: submit, child: Text(isLogin ? 'Login' : 'Register')),
            TextButton(
              onPressed: () => setState(() => isLogin = !isLogin),
              child: Text(isLogin ? 'Create new account' : 'I already have an account'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Models ---
class CardData {
  final String suit;
  final String exercise;
  final String description;
  final int rank; // 1-13
  CardData({required this.suit, required this.exercise, required this.description, required this.rank});
}

enum Mode { Solo, Burnout, Multiplayer }

// --- Home Screen ---
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: Text('Rivalis - ${user?.email ?? ''}')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen(mode: Mode.Solo))),
              child: Text('Solo Mode'),
            ),
            ElevatedButton(
              onPressed: () => _showBurnoutSuitSelection(context),
              child: Text('Burnout Mode'),
            ),
            ElevatedButton(
              onPressed: () => _startMultiplayer(context),
              child: Text('Multiplayer Mode'),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LeaderboardScreen())),
              child: Text('View Leaderboard'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBurnoutSuitSelection(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Choose Muscle Group'),
          content: Text('Select which muscle group to focus on for Burnout mode:'),
          actions: [
            TextButton(
              onPressed: () { Navigator.of(context).pop(); Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen(mode: Mode.Burnout, selectedSuit: "Hearts"))); },
              child: Text('💪 Arms (Hearts)'),
            ),
            TextButton(
              onPressed: () { Navigator.of(context).pop(); Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen(mode: Mode.Burnout, selectedSuit: "Diamonds"))); },
              child: Text('🦵 Legs (Diamonds)'),
            ),
            TextButton(
              onPressed: () { Navigator.of(context).pop(); Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen(mode: Mode.Burnout, selectedSuit: "Clubs"))); },
              child: Text('🏋️ Core (Clubs)'),
            ),
            TextButton(
              onPressed: () { Navigator.of(context).pop(); Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen(mode: Mode.Burnout, selectedSuit: "Spades"))); },
              child: Text('🔥 Cardio (Spades)'),
            ),
          ],
        );
      },
    );
  }

  void _startMultiplayer(BuildContext context) {
    final sessionId = Random().nextInt(100000).toString();
    Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen(mode: Mode.Multiplayer, sessionId: sessionId)));
  }
}

// --- Leaderboard ---
class LeaderboardScreen extends StatelessWidget {
  final CollectionReference leaderboardRef = FirebaseFirestore.instance.collection('leaderboard');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Leaderboard')),
      body: StreamBuilder<QuerySnapshot>(
        stream: leaderboardRef.orderBy('points', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index];
              return ListTile(
                title: Text(data['username'] ?? 'Unknown'),
                trailing: Text('${data['points'] ?? 0} pts'),
              );
            },
          );
        },
      ),
    );
  }
}

// --- GameScreen ---
class GameScreen extends StatefulWidget {
  final Mode mode;
  final String? selectedSuit;
  final String? sessionId; // Multiplayer
  GameScreen({required this.mode, this.selectedSuit, this.sessionId});
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late List<CardData> deck;
  int currentIndex = 0;
  int cycleNumber = 1;
  int points = 0;
  Timer? timer;
  int timeLeft = 0;
  bool showCompleteButton = true;
  String? selectedSuit;

  final List<String> rankNames = ["Ace","2","3","4","5","6","7","8","9","10","Jack","Queen","King"];
  final Map<String, String> suitSymbols = {"Hearts":"♥","Diamonds":"♦","Clubs":"♣","Spades":"♠"};

  @override
  void initState() {
    super.initState();
    selectedSuit = widget.selectedSuit;
    deck = generateDeck(widget.mode);
    deck.shuffle();
    startCard();
  }

  List<CardData> generateDeck(Mode mode) {
    Map<String, List<String>> muscleExercises = {
      "Hearts": ["Push-ups ×15", "Shoulder Taps ×20", "Arm Circles ×20", "Wall Push-ups ×15"],
      "Diamonds": ["Squats ×20", "Lunges ×15 per leg", "High Knees ×25", "Glute Bridges ×15"],
      "Clubs": ["Plank 30s", "Sit-ups ×15", "Mountain Climbers ×20", "Leg Raises ×15"],
      "Spades": ["Burpees ×10", "Jumping Jacks ×25", "Burpee + Jump ×10", "High Knees ×30"],
    };
    Map<String, String> descriptions = {
      "Push-ups ×15": "Hands shoulder-width apart, lower chest to floor, push back up.",
      "Shoulder Taps ×20": "In plank, tap left shoulder with right hand, alternate.",
      "Arm Circles ×20": "Extend arms sideways, make small circles forward and backward.",
      "Wall Push-ups ×15": "Stand facing wall, hands on wall, bend elbows to bring chest close, push back.",
      "Squats ×20": "Feet shoulder-width apart, bend knees, push hips back, return.",
      "Lunges ×15 per leg": "Step forward, bend knees 90°, return.",
      "High Knees ×25": "Jog in place lifting knees as high as possible.",
      "Glute Bridges ×15": "Lie on back, knees bent, lift hips toward ceiling, lower.",
      "Plank 30s": "Hold a push-up position on elbows, keep body straight.",
