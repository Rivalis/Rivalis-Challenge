import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyB5HnrM6izJeJ3ZQ3pk6SH5Z-TDDHzt5JA",
      authDomain: "rivalis-73117.firebaseapp.com",
      projectId: "rivalis-73117",
      storageBucket: "rivalis-73117.firebasestorage.app",
      messagingSenderId: "818308848308",
      appId: "1:818308848308:web:4b5771dea721b434f795e1",
      measurementId: "G-1B8PEJ9BZF",
    ),
  );

  runApp(const MyApp());
}

// ---------------- Card Model ----------------

class PlayingCard {
  final String suit;
  final String rank;
  PlayingCard({required this.suit, required this.rank});

  Map<String, dynamic> toMap() => {'suit': suit, 'rank': rank};
  factory PlayingCard.fromMap(Map<String, dynamic> map) =>
      PlayingCard(suit: map['suit'], rank: map['rank']);
}

// ---------------- Main App ----------------

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rivalis',
      home: LoginScreen(),
    );
  }
}

// ---------------- Login Screen ----------------

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String message = '';

  Future<void> signUp() async {
    try {
      UserCredential user = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim());

      await FirebaseFirestore.instance.collection('users').doc(user.user!.uid).set({
        'email': user.user!.email,
        'score': 0,
      });

      setState(() {
        message = 'Registered: ${user.user!.email}';
      });
    } catch (e) {
      setState(() => message = 'Error: $e');
    }
  }

  Future<void> signIn() async {
    try {
      UserCredential user = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim());

      Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => GameScreen())
      );
    } catch (e) {
      setState(() => message = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rivalis Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
          TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: signUp, child: const Text('Sign Up')),
          ElevatedButton(onPressed: signIn, child: const Text('Sign In')),
          const SizedBox(height: 20),
          Text(message),
        ]),
      ),
    );
  }
}

// ---------------- Game Screen ----------------

class GameScreen extends StatefulWidget {
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final String userId = FirebaseAuth.instance.currentUser!.uid;
  final String gameId = 'game_1234'; // shared game

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  Future<void> _initializeGame() async {
    final gameRef = FirebaseFirestore.instance.collection('games').doc(gameId);
    final doc = await gameRef.get();

    if (!doc.exists) {
      // Create and shuffle 52-card deck
      final suits = ['hearts','diamonds','clubs','spades'];
      final ranks = ['Ace','2','3','4','5','6','7','8','9','10','Jack','Queen','King'];
      List<Map<String,dynamic>> deck = [];
      for (var suit in suits) for (var rank in ranks) deck.add({'suit': suit,'rank': rank});
      deck.shuffle(Random());

      await gameRef.set({
        'deck': deck,
        'hands': {userId: []},
        'active': true,
      });
    } else {
      final hands = Map<String,dynamic>.from(doc['hands']);
      if (!hands.containsKey(userId)) {
        hands[userId] = [];
        await gameRef.update({'hands': hands});
      }
    }
  }

  Future<void> _drawCard() async {
    final gameRef = FirebaseFirestore.instance.collection('games').doc(gameId);
    final doc = await gameRef.get();
    final data = doc.data()!;
    if (!(data['active'] ?? true)) return;

    final deck = List<Map<String,dynamic>>.from(data['deck']);
    if (deck.isEmpty) return _endGame();

    final card = deck.removeAt(0);
    final hands = Map<String,dynamic>.from(data['hands']);
    final hand = List<Map<String,dynamic>>.from(hands[userId] ?? []);
    hand.add(card);
    hands[userId] = hand;

    await gameRef.update({'deck': deck, 'hands': hands});

    if (deck.isEmpty) await _endGame();
  }

  Future<void> _endGame() async {
    final gameRef = FirebaseFirestore.instance.collection('games').doc(gameId);
    final data = (await gameRef.get()).data()!;
    final hands = Map<String,dynamic>.from(data['hands']);

    for (final uid in hands.keys) {
      final score = hands[uid].length; // 1 point per card
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'score': score});
    }

    await gameRef.update({'active': false});
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen()));
  }

  Widget _cardWidget(Map<String,dynamic> cardData) {
    final card = PlayingCard.fromMap(cardData);
    final suitSymbols = {'hearts':'♥','diamonds':'♦','clubs':'♣','spades':'♠'};
    final color = (card.suit=='hearts'||card.suit=='diamonds')?Colors.red:Colors.black;

    return Container(
      width: 70, height: 100, margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black),
        boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(2,2), blurRadius: 3)]
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text('${card.rank}\n${suitSymbols[card.suit]}', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(suitSymbols[card.suit]!, style: TextStyle(color: color, fontSize: 24)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameRef = FirebaseFirestore.instance.collection('games').doc(gameId);

    return Scaffold(
      appBar: AppBar(title: const Text('Rivalis Game')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: gameRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!.data() as Map<String,dynamic>;
          final handData = List<Map<String,dynamic>>.from(data['hands'][userId] ?? []);
          final active = data['active'] ?? true;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: handData.map(_cardWidget).toList()),
                ),
              ),
              const SizedBox(height: 10),
              if (active)
                ElevatedButton(onPressed: _drawCard, child: const Text('Draw Card')),
              const SizedBox(height: 10),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _endGame,
        tooltip: 'End Session',
        child: const Icon(Icons.stop_circle),
      ),
    );
  }
}

// ---------------- Leaderboard ----------------

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rivalis Leaderboard')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').orderBy('score', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final users = snapshot.data!.docs;
          if (users.isEmpty) return const Center(child: Text('No users yet.'));

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final email = user['email'] ?? 'Unknown';
              final score = user['score'] ?? 0;
              return ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(email),
                trailing: Text(score.toString()),
              );
            },
          );
        },
      ),
    );
  }
}
