import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() => runApp(RivalisApp());

class RivalisApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rivalis',
      theme: ThemeData(primarySwatch: Colors.red),
      home: HomeScreen(),
    );
  }
}

// --- Models ---
class CardData {
  final String suit;
  final String exercise;
  final String description;
  final int rank;
  CardData({
    required this.suit,
    required this.exercise,
    required this.description,
    required this.rank,
  });
}

enum Mode { Solo, Burnout, Multiplayer }

// --- Home Screen ---
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Rivalis')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => GameScreen(mode: Mode.Solo))),
                child: Text('Solo Mode')),
            ElevatedButton(
                onPressed: () => _showBurnoutSuitSelection(context),
                child: Text('Burnout Mode')),
            ElevatedButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => GameScreen(mode: Mode.Multiplayer))),
                child: Text('Multiplayer Mode')),
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
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => GameScreen(mode: Mode.Burnout, selectedSuit: "Hearts")));
              },
              child: Text('💪 Arms (Hearts)'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => GameScreen(mode: Mode.Burnout, selectedSuit: "Diamonds")));
              },
              child: Text('🦵 Legs (Diamonds)'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => GameScreen(mode: Mode.Burnout, selectedSuit: "Clubs")));
              },
              child: Text('🏋️ Core (Clubs)'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => GameScreen(mode: Mode.Burnout, selectedSuit: "Spades")));
              },
              child: Text('🔥 Cardio (Spades)'),
            ),
          ],
        );
      },
    );
  }
}

// --- Rivalis Card Widget with Watermark ---
class RivalisCard extends StatelessWidget {
  final String suit;
  final int rank;
  final String exercise;
  final String description;
  final int timeLeft;
  final bool showDoneButton;
  final VoidCallback? onDone;

  const RivalisCard({
    Key? key,
    required this.suit,
    required this.rank,
    required this.exercise,
    required this.description,
    required this.timeLeft,
    required this.showDoneButton,
    this.onDone,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 300,
          height: 400,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
          ),
          child: Stack(
            children: [
              // Watermark Text
              Center(
                child: Text(
                  'Rivalis',
                  style: TextStyle(
                    fontSize: 72,
                    color: Colors.black.withOpacity(0.08),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Card Content
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "$suit - Rank $rank",
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    Text(
                      exercise,
                      style: TextStyle(fontSize: 20),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    Text(
                      description,
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24),
                    Text(
                      "Time Left: $timeLeft s",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    if (showDoneButton)
                      ElevatedButton(
                        onPressed: onDone,
                        child: Text(
                          'Done',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- Game Screen ---
class GameScreen extends StatefulWidget {
  final Mode mode;
  final String? selectedSuit;
  GameScreen({required this.mode, this.selectedSuit});
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
  bool showDoneButton = false;
  FlutterTts flutterTts = FlutterTts();
  String motivational = "You can do it!";
  String? selectedSuit; // For Burnout mode suit selection

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
      "Hearts": [
        "Push-ups ×15",
        "Shoulder Taps ×20",
        "Arm Circles ×20",
        "Wall Push-ups ×15"
      ],
      "Diamonds": [
        "Squats ×20",
        "Lunges ×15 per leg",
        "High Knees ×25",
        "Glute Bridges ×15"
      ],
      "Clubs": [
        "Plank 30s",
        "Sit-ups ×15",
        "Mountain Climbers ×20",
        "Leg Raises ×15"
      ],
      "Spades": [
        "Burpees ×10",
        "Jumping Jacks ×25",
        "Burpee + Jump ×10",
        "High Knees ×30"
      ],
    };

    Map<String, String> descriptions = {
      "Push-ups ×15":
          "Hands shoulder-width apart, lower chest to floor, push back up.",
      "Shoulder Taps ×20": "In plank, tap left shoulder with right hand, alternate.",
      "Arm Circles ×20": "Extend arms sideways, make small circles forward and backward.",
      "Wall Push-ups ×15":
          "Stand facing wall, hands on wall, bend elbows to bring chest close, push back.",
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

    List<CardData> deckList = [];
    if (mode == Mode.Burnout) {
      // Use the selectedSuit for Burnout mode, default to Hearts if not set
      String chosenSuit = selectedSuit ?? "Hearts";
      List<String>? exercises = muscleExercises[chosenSuit];
      if (exercises == null) {
        // Fallback to Hearts if invalid suit provided
        chosenSuit = "Hearts";
        exercises = muscleExercises[chosenSuit]!;
      }
      for (int i = 0; i < 13; i++) {
        for (int s = 0; s < 4; s++) {
          String ex = exercises[s % 4];
          deckList.add(CardData(
              suit: chosenSuit,
              exercise: ex,
              description: descriptions[ex]!,
              rank: (i % 13) + 1));
        }
      }
    } else {
      // Solo and Multiplayer: each suit = different muscle group
      muscleExercises.forEach((suit, exercises) {
        for (int i = 0; i < 13; i++) {
          String ex = exercises[i % 4];
          deckList.add(CardData(
              suit: suit,
              exercise: ex,
              description: descriptions[ex]!,
              rank: (i % 13) + 1));
        }
      });
    }
    return deckList;
  }

  void startCard() {
    if (currentIndex >= deck.length) {
      if (widget.mode == Mode.Burnout) cycleNumber++;
      currentIndex = 0;
      deck.shuffle();
    }

    if (!mounted) return;

    setState(() {
      timeLeft = widget.mode == Mode.Burnout ? 30 : 45;
      showDoneButton = false;
    });

    _speakWithErrorHandling(
        "${deck[currentIndex].exercise}. ${deck[currentIndex].description}. $motivational");

    timer?.cancel();
    timer = Timer.periodic(Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        timeLeft--;
        if ((widget.mode == Mode.Burnout && timeLeft <= 10) ||
            (widget.mode != Mode.Burnout && timeLeft <= 15)) {
          showDoneButton = true;
        }
        if (timeLeft <= 0) {
          t.cancel();
          completeCard();
        }
      });
    });
  }

  void completeCard() {
    if (!mounted) return;
    
    int cardPoints = deck[currentIndex].rank;
    if (widget.mode == Mode.Burnout && cycleNumber >= 2) cardPoints *= 2;
    points += cardPoints;
    currentIndex++;
    startCard();
  }

  @override
  void dispose() {
    timer?.cancel();
    timer = null;
    flutterTts.stop();
    super.dispose();
  }

  Future<void> _speakWithErrorHandling(String text) async {
    try {
      await flutterTts.stop(); // Stop any previous speech
      await flutterTts.speak(text);
    } catch (e) {
      // Graceful fallback for TTS errors (especially on web)
      print('TTS error: $e');
      // Could show a snackbar or other UI feedback here
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Text-to-Speech not available')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (deck.isEmpty) return Container();
    CardData card = deck[currentIndex];

    return Scaffold(
      appBar: AppBar(title: Text('Rivalis - Points: $points')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RivalisCard(
              suit: card.suit,
              rank: card.rank,
              exercise: card.exercise,
              description: card.description,
              timeLeft: timeLeft,
              showDoneButton: showDoneButton,
              onDone: completeCard,
            ),
          ],
        ),
      ),
    );
  }
}
