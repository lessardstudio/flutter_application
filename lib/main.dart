import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const NathanApp());
}

class NathanApp extends StatelessWidget {
  const NathanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainScreen(),
    );
  }
}

class FoodEntry {
  final String name;
  final int calories;
  FoodEntry({required this.name, required this.calories});
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  List<FoodEntry> todayFood = [];
  final int calorieLimit = 2200;
  late final ChatScreen _chatScreen;

  @override
  void initState() {
    super.initState();
    _chatScreen = ChatScreen(addFood: addFood);
  }

  void addFood(FoodEntry food) {
    setState(() {
      todayFood.add(food);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _chatScreen,
      ProfileScreen(todayFood: todayFood, calorieLimit: calorieLimit),
    ];
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.orange,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Чат'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Профиль'),
        ],
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final Function(FoodEntry) addFood;
  const ChatScreen({super.key, required this.addFood});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  bool _isSending = false;

  void _showTopSnack(String text) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final media = MediaQuery.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          left: 12,
          right: 12,
          top: kToolbarHeight + 12,
          bottom: media.size.height - (kToolbarHeight + 12 + 48),
        ),
      ),
    );
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    _controller.clear();

    setState(() {
      _isSending = true;
      messages.add({"text": text, "isNathan": false, "food": []});
      messages.add({"text": "Nathan печатает…", "isNathan": true, "food": [], "loading": true});
    });
    final int loadingIndex = messages.length - 1;

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"user_id": 1, "message": text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          messages[loadingIndex] = {
            "text": data['reply'] ?? '',
            "isNathan": true,
            "food": data['food_suggestions'] ?? [],
            "loading": false
          };
        });
      } else {
        setState(() {
          messages[loadingIndex] = {
            "text": "Ошибка: не удалось связаться с Nathan 😢",
            "isNathan": true,
            "food": [],
            "loading": false
          };
        });
      }
    } catch (e) {
      setState(() {
        messages[loadingIndex] = {
          "text": "Ошибка: ${e.toString()}",
          "isNathan": true,
          "food": [],
          "loading": false
        };
      });
    }

    setState(() {
      _isSending = false;
    });
  }

  void addFoodToProfile(Map<String, dynamic> food) {
    widget.addFood(FoodEntry(name: food['name'], calories: food['calories']));
    _showTopSnack('${food['name']} добавлено 🍴');
  }

  void addAllFoods(List<dynamic> foods) {
    for (final f in foods) {
      addFoodToProfile(f);
    }
    _showTopSnack('Добавлено ${foods.length} позиций 🍴');
  }
  List<dynamic> lastNathanFoods() {
    for (int i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (m['isNathan'] == true && m['food'] != null && (m['food'] as List).isNotEmpty) {
        return m['food'];
      }
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nathan 🦊'), backgroundColor: Colors.orange),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isNathan = msg['isNathan'] == true;
                final isLoading = msg['loading'] == true;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment:
                      isNathan ? MainAxisAlignment.start : MainAxisAlignment.end,
                  children: [
                    if (isNathan)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.orange.shade300,
                          child: const Text('🦊', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    Flexible(
                      child: Column(
                        crossAxisAlignment:
                            isNathan ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                        children: [
                          if (isNathan)
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 2),
                              child: Text(
                                'Nathan',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isNathan
                                  ? Colors.orange.shade100
                                  : Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: isLoading
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                      SizedBox(width: 8),
                                      Text('Печатает…'),
                                    ],
                                  )
                                : Text(msg['text'] ?? ''),
                          ),
                          if (!isLoading &&
                              msg['food'] != null &&
                              (msg['food'] as List).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: ElevatedButton(
                                onPressed: () => addAllFoods(msg['food']),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade300,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                ),
                                child: const Text('Добавить всё'),
                              ),
                            ),
                          if (!isLoading &&
                              msg['food'] != null &&
                              (msg['food'] as List).isNotEmpty)
                            Wrap(
                              spacing: 6,
                              children: List.generate(msg['food'].length, (i) {
                                final food = msg['food'][i];
                                return ElevatedButton(
                                  onPressed: () => addFoodToProfile(food),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange.shade200,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20)),
                                  ),
                                  child: Text(
                                      'Добавить ${food['name']} (${food['calories']} ккал)'),
                                );
                              }),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Builder(builder: (context) {
            final foods = lastNathanFoods();
            if (foods.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: () => addAllFoods(foods),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade400,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('Добавить всё в профиль'),
                ),
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                        hintText: 'Напиши что-нибудь...', border: OutlineInputBorder()),
                    onSubmitted: sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                _isSending
                    ? const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () => sendMessage(_controller.text),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  final List<FoodEntry> todayFood;
  final int calorieLimit;
  const ProfileScreen({super.key, required this.todayFood, required this.calorieLimit});

  String nathanComment() {
    int totalCalories = todayFood.fold(0, (sum, item) => sum + item.calories);
    double ratio = totalCalories / calorieLimit;
    if (ratio < 0.8) return 'День пока лёгкий 🦊';
    if (ratio <= 1.0) return 'Хорошо держимся 👍';
    return 'Перебор 😅 Но завтра всё исправим';
  }

  @override
  Widget build(BuildContext context) {
    int totalCalories = todayFood.fold(0, (sum, item) => sum + item.calories);
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль / День'), backgroundColor: Colors.orange),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Калории за день: $totalCalories / $calorieLimit',
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            Text('Съедено:', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                itemCount: todayFood.length,
                itemBuilder: (context, index) {
                  final item = todayFood[index];
                  return ListTile(title: Text(item.name), trailing: Text('${item.calories} ккал'));
                },
              ),
            ),
            const SizedBox(height: 12),
            Text('Комментарий Nathan:',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(nathanComment(), style: const TextStyle(fontSize: 16, color: Colors.orange)),
          ],
        ),
      ),
    );
  }
}
