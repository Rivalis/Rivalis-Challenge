// lib/main.dart
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

// -------------------- Hardcoded Firebase config --------------------
const FirebaseOptions firebaseOptions = FirebaseOptions(
  apiKey: "AIzaSyB5HnrM6izJeJ3ZQ3pk6SH5Z-TDDHzt5JA",
  authDomain: "rivalis-73117.firebaseapp.com",
  projectId: "rivalis-73117",
  storageBucket: "rivalis-73117.firebasestorage.app",
  messagingSenderId: "818308848308",
  appId: "1:818308848308:web:4b5771dea721b434f795e1",
  measurementId: "G-1B8PEJ9BZF",
);

// -------------------- Globals --------------------
final FirebaseAuth auth = FirebaseAuth.instance;
final FirebaseFirestore firestore = FirebaseFirestore.instance;
final CollectionReference usersCol = firestore.collection('users');
final CollectionReference leaderboardCol = firestore.collection('leaderboard');
final CollectionReference sessionsCol = firestore.collection('multiplayer_sessions');
final GoogleSignIn googleSignIn = GoogleSignIn();

// -------------------- Main --------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);
  runApp(RivalisApp());
}

class RivalisApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rivalis',
      theme: ThemeData(primarySwatch: Colors.red),
      home: AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// -------------------- AuthGate --------------------
class AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: auth.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null) return SignInScreen();
        return FutureBuilder<DocumentSnapshot>(
          future: usersCol.doc(user.uid).get(),
          builder: (c, s) {
            if (s.connectionState == ConnectionState.waiting) {
              return Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final doc = s.data;
            final hasName = doc != null && doc.exists && ((doc.data() as Map<String, dynamic>?)?['displayName'] != null);
            if (!hasName) {
              return ProfileSetupScreen(uid: user.uid, email: user.email ?? '');
            }
            return HomeScreen();
          },
        );
      },
    );
  }
}

// -------------------- SignInScreen --------------------
class SignInScreen extends StatefulWidget {
  @override
  _SignInScreenState createState() => _SignInScreenState();
}
class _SignInScreenState extends State<SignInScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _googleSignIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        await auth.signInWithPopup(provider);
      } else {
        final account = await googleSignIn.signIn();
        if (account == null) { setState(() { _loading = false; }); return; }
        final authn = await account.authentication;
        final credential = GoogleAuthProvider.credential(idToken: authn.idToken, accessToken: authn.accessToken);
        await auth.signInWithCredential(credential);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in — Rivalis')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 180,
              child: Image.asset('assets/images/background.png', fit: BoxFit.cover, height: 80),
            ),
            SizedBox(height: 20),
            Text('Welcome to Rivalis', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            _loading
                ? CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _googleSignIn,
                    icon: Icon(Icons.login),
                    label: Text('Sign in with Google'),
                  ),
            if (_error != null) ...[SizedBox(height: 12), Text(_error!, style: TextStyle(color: Colors.red))],
            SizedBox(height: 12),
            Text('You will be asked to choose a display name after first sign-in.'),
          ]),
        ),
      ),
    );
  }
}

// -------------------- ProfileSetupScreen --------------------
class ProfileSetupScreen extends StatefulWidget {
  final String uid;
  final String email;
  ProfileSetupScreen({required this.uid, required this.email});
  @override
  _ProfileSetupScreenState createState() => _ProfileSetupScreenState();
}
class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { setState(() { _error = 'Please enter a display name.'; }); return; }
    setState(() { _saving = true; _error = null; });
    try {
      await usersCol.doc(widget.uid).set({'displayName': name, 'email': widget.email}, SetOptions(merge: true));
      final lbDoc = leaderboardCol.doc(widget.uid);
      final snap = await lbDoc.get();
      if (!snap.exists) await lbDoc.set({'username': name, 'points': 0});
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose display name')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(children: [
          Text('Pick a display name that will appear in multiplayer and on the leaderboard.'),
          SizedBox(height: 12),
          TextField(controller: _nameCtrl, decoration: InputDecoration(labelText: 'Display name')),
          SizedBox(height: 12),
          _saving ? CircularProgressIndicator() : ElevatedButton(onPressed: _save, child: Text('Save')),
          if (_error != null) ...[SizedBox(height: 8), Text(_error!, style: TextStyle(color: Colors.red))],
        ]),
      ),
    );
  }
}

// -------------------- Utilities --------------------
const List<String> rankNames = ["Ace","2","3","4","5","6","7","8","9","10","Jack","Queen","King"];
const Map<String,String> suitSymbols = {"Hearts":"♥","Diamonds":"♦","Clubs":"♣","Spades":"♠"};
Color suitColor(String suit) => (suit == "Hearts" || suit == "Diamonds") ? Colors.red : Colors.black;

class CardModel {
  final String suit;
  final int rank; // 1..13
  final String exercise;
  final String description;
  CardModel({required this.suit, required this.rank, required this.exercise, required this.description});
  Map<String,dynamic> toMap() => {'suit': suit, 'rank': rank, 'exercise': exercise, 'description': description};
  factory CardModel.fromMap(Map<String,dynamic> m) => CardModel(
    suit: m['suit'],
    rank: (m['rank'] as num).toInt(),
    exercise: m['exercise'],
    description: m['description'] ?? '',
  );
}

List<CardModel> generateDeck({String? onlySuit}) {
  final Map<String, List<String>> muscleExercises = {
    "Hearts": ["Push-ups ×15", "Shoulder Taps ×20", "Arm Circles ×20", "Wall Push-ups ×15"],
    "Diamonds": ["Squats ×20", "Lunges ×15 per leg", "High Knees ×25", "Glute Bridges ×15"],
    "Clubs": ["Plank 30s", "Sit-ups ×15", "Mountain Climbers ×20", "Leg Raises ×15"],
    "Spades": ["Burpees ×10", "Jumping Jacks ×25", "Burpee + Jump ×10", "High Knees ×30"],
  };
  final Map<String, String> descriptions = {
    "Push-ups ×15": "Hands shoulder-width apart, lower chest to floor, push back up.",
    "Shoulder Taps ×20": "In plank, tap left shoulder with right hand, alternate.",
    "Arm Circles ×20": "Extend arms sideways, make small circles forward and backward.",
    "Wall Push-ups ×15": "Stand facing wall, hands on wall, bend elbows to bring chest close, push back.",
    "Squats ×20": "Feet shoulder-width apart, bend knees, push hips back, return.",
    "Lunges ×15 per leg": "Step forward, bend knees 90°, return.",
    "High Knees ×25": "Jog in place lifting knees as high as possible.",
    "Glute Bridges ×15": "Lie on back, knees bent, lift hips toward ceiling, lower.",
    "Plank 30s": "Hold a push-up position on elbows, keep body straight.",
    "Sit-ups ×15": "Lie on back, bend knees, lift torso toward knees.",
    "Mountain Climbers ×20": "Plank position, drive knees alternately toward chest.",
    "Leg Raises ×15": "Lie on back, lift legs to 90°, lower slowly.",
    "Burpees ×10": "Stand, squat, kick legs back into plank, return, jump.",
    "Jumping Jacks ×25": "Jump legs apart, arms overhead, return.",
    "Burpee + Jump ×10": "Same as burpee but add high jump at end.",
    "High Knees ×30": "Jog in place lifting knees as high as possible."
  };

  final suits = onlySuit != null ? [onlySuit] : ["Hearts", "Diamonds", "Clubs", "Spades"];
  final deck = <CardModel>[];
  for (final suit in suits) {
    final exList = muscleExercises[suit]!;
    for (int i = 0; i < 13; i++) {
      final ex = exList[i % exList.length];
      deck.add(CardModel(suit: suit, rank: i + 1, exercise: ex, description: descriptions[ex] ?? ''));
    }
  }
  deck.shuffle();
  return deck;
}

// -------------------- HomeScreen --------------------
class HomeScreen extends StatelessWidget {
  void _startMultiplayer(BuildContext c) async {
    final doc = sessionsCol.doc();
    final deck = generateDeck();
    await doc.set({
      'deck': deck.map((d) => d.toMap()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'players': {},
    });
    Navigator.push(c, MaterialPageRoute(builder: (_) => GameScreen(mode: GameMode.Multiplayer, sessionId: doc.id)));
  }

  void _openBurnout(BuildContext c) {
    showDialog(context: c, builder: (_) {
      return AlertDialog(
        title: Text('Choose Muscle Group'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextButton(onPressed: () { Navigator.pop(c); Navigator.push(c, MaterialPageRoute(builder: (_) => GameScreen(mode: GameMode.Burnout, burnoutSuit: 'Hearts'))); }, child: Text('💪 Arms (Hearts)')),
          TextButton(onPressed: () { Navigator.pop(c); Navigator.push(c, MaterialPageRoute(builder: (_) => GameScreen(mode: GameMode.Burnout, burnoutSuit: 'Diamonds'))); }, child: Text('🦵 Legs (Diamonds)')),
          TextButton(onPressed: () { Navigator.pop(c); Navigator.push(c, MaterialPageRoute(builder: (_) => GameScreen(mode: GameMode.Burnout, burnoutSuit: 'Clubs'))); }, child: Text('🏋️ Core (Clubs)')),
          TextButton(onPressed: () { Navigator.pop(c); Navigator.push(c, MaterialPageRoute(builder: (_) => GameScreen(mode: GameMode.Burnout, burnoutSuit: 'Spades'))); }, child: Text('🔥 Cardio (Spades)')),
        ]),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final u = auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Text('Rivalis - ${u?.email ?? ''}'),
        actions: [
          IconButton(icon: Icon(Icons.person), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfileScreen()))),
          IconButton(icon: Icon(Icons.logout), onPressed: () => auth.signOut()),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(height: 10),
            ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen(mode: GameMode.Solo))), child: Text('Solo Mode')),
            SizedBox(height: 12),
            ElevatedButton(onPressed: () => _openBurnout(context), child: Text('Burnout Mode')),
            SizedBox(height: 12),
            ElevatedButton(onPressed: () => _startMultiplayer(context), child: Text('Start Multiplayer Session')),
            SizedBox(height: 20),
            ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LeaderboardScreen())), child: Text('View Leaderboard')),
          ]),
        ),
      ),
    );
  }
}

// -------------------- EditProfileScreen --------------------
class EditProfileScreen extends StatefulWidget {
  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}
class _EditProfileScreenState extends State<EditProfileScreen> {
  final _name = TextEditingController();
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    final u = auth.currentUser;
    if (u != null) {
      usersCol.doc(u.uid).get().then((doc) {
        if (doc.exists && doc.data() != null) {
          final data = doc.data() as Map<String,dynamic>;
          _name.text = data['displayName'] ?? '';
        }
      });
    }
  }
  Future<void> _save() async {
    final u = auth.currentUser;
    if (u == null) return;
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _loading = true);
    await usersCol.doc(u.uid).set({'displayName': name, 'email': u.email}, SetOptions(merge: true));
    await leaderboardCol.doc(u.uid).set({'username': name}, SetOptions(merge: true));
    setState(() => _loading = false);
    if (mounted) Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          TextField(controller: _name, decoration: InputDecoration(labelText: 'Display name')),
          SizedBox(height: 12),
          _loading ? CircularProgressIndicator() : ElevatedButton(onPressed: _save, child: Text('Save')),
        ]),
      ),
    );
  }
}

// -------------------- LeaderboardScreen --------------------
class LeaderboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: StreamBuilder<QuerySnapshot>(
        stream: leaderboardCol.orderBy('points', descending: true).limit(200).snapshots(),
        builder: (c, snap) {
          if (!snap.hasData) return Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return Center(child: Text('No scores yet'));
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_,__) => Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i];
              final name = (d['username'] ?? 'Unknown').toString();
              final pts = (d['points'] ?? 0).toString();
              return ListTile(
                leading: CircleAvatar(child: Text('${i+1}')),
                title: Text(name),
                trailing: Text('$pts pts', style: TextStyle(fontWeight: FontWeight.bold)),
              );
            }
          );
        },
      ),
    );
  }
}

// -------------------- GameScreen --------------------
enum GameMode { Solo, Burnout, Multiplayer }

class GameScreen extends StatefulWidget {
  final GameMode mode;
  final bool isBurnout;
  final String? burnoutSuit;
  final String? sessionId;
  GameScreen({required this.mode, this.isBurnout = false, this.burnoutSuit, this.sessionId});

  @override
  _GameScreenState createState() => _GameScreenState();
}
class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  List<CardModel> deck = [];
  int currentIndex = 0;
  int timeLeft = 45;
  int points = 0;
  Timer? _timer;
  late AnimationController _flipController;

  String get sessionId => widget.sessionId ?? '';

  @override
  void initState() {
    super.initState();
    deck = generateDeck(onlySuit: widget.isBurnout ? widget.burnoutSuit : null);
    if (widget.mode == GameMode.Multiplayer && widget.sessionId != null) _joinSession(widget.sessionId!);
    _startTimer();
    _flipController = AnimationController(vsync: this, duration: Duration(milliseconds: 500));
  }

  Future<void> _joinSession(String id) async {
    final u = auth.currentUser;
    if (u == null) return;
    final userDoc = await usersCol.doc(u.uid).get();
    final name = (userDoc.data() as Map<String,dynamic>?)?['displayName'] ?? u.email ?? u.uid;
    final docRef = sessionsCol.doc(id);
    await docRef.set({'players.${u.uid}': {'displayName': name, 'points': 0, 'lastCardIndex': 0}}, SetOptions(merge: true));
    final snap = await docRef.get();
    if (snap.exists && snap.data() != null) {
      final data = snap.data() as Map<String,dynamic>;
      if (data['deck'] != null) {
        final d = (data['deck'] as List).map((e) => CardModel.fromMap(Map<String,dynamic>.from(e))).toList();
        setState(() { deck = d; });
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() { timeLeft = widget.isBurnout ? 30 : 45; });
    _timer = Timer.periodic(Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (timeLeft > 0) timeLeft--;
        if (timeLeft <= 0) _onTimeExpired();
      });
    });
  }

  Future<void> _onTimeExpired() async {
    await _flipAndAdvance();
  }

  Future<void> _flipAndAdvance() async {
    await _flipController.forward();
    final prevIndex = currentIndex;
    setState(() {
      points += deck[prevIndex].rank;
      currentIndex = (currentIndex + 1) % deck.length;
    });
    await _postProgress(deck[prevIndex].rank);
    _flipController.reset();
    _startTimer();
  }

  Future<void> _postProgress(int gained) async {
    final u = auth.currentUser;
    if (u == null) return;
    if (widget.mode == GameMode.Multiplayer && widget.sessionId != null) {
      final docRef = sessionsCol.doc(sessionId);
      await firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) return;
        final data = snap.data() as Map<String,dynamic>;
        final players = Map<String,dynamic>.from(data['players'] ?? {});
        final entry = Map<String,dynamic>.from(players[u.uid] ?? {'displayName': (await usersCol.doc(u.uid).get()).data()?['displayName'] ?? u.uid, 'points':0, 'lastCardIndex':0});
        entry['points'] = (entry['points'] ?? 0) + gained;
        entry['lastCardIndex'] = (entry['lastCardIndex'] ?? 0) + 1;
        players[u.uid] = entry;
        tx.update(docRef, {'players': players});
      });
    }
    final lbDoc = leaderboardCol.doc(u.uid);
    await firestore.runTransaction((tx) async {
      final snap = await tx.get(lbDoc);
      if (!snap.exists) {
        tx.set(lbDoc, {'username': (await usersCol.doc(u.uid).get()).data()?['displayName'] ?? u.uid, 'points': gained});
      } else {
        final old = (snap.data()!['points'] ?? 0) as int;
        tx.update(lbDoc, {'points': old + gained});
      }
    });
  }

  Future<void> _onDonePressed() async {
    await _flipAndAdvance();
  }

  Future<void> _onCompleteSession() async {
    final u = auth.currentUser;
    if (u != null && widget.mode == GameMode.Multiplayer && widget.sessionId != null) {
      final docRef = sessionsCol.doc(sessionId);
  
