import 'dart:async';
import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:markdown/markdown.dart' as md;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers:[ChangeNotifierProvider(create: (_) => AppState()..initSystem())],
      child: const ProNotesApp(),
    ),
  );
}

// ==========================================
// AST MARKDOWN EXTENSIONS FOR LATEX
// ==========================================
class BlockLatexSyntax extends md.InlineSyntax {
  BlockLatexSyntax() : super(r'\$\$([^\$]+)\$\$');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('latex_block', match[1]!));
    return true;
  }
}

class InlineLatexSyntax extends md.InlineSyntax {
  InlineLatexSyntax() : super(r'\$([^\$]+)\$');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('latex_inline', match[1]!));
    return true;
  }
}

class LatexElementBuilder extends MarkdownElementBuilder {
  final MathStyle mathStyle;
  LatexElementBuilder({required this.mathStyle});
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return Math.tex(
      element.textContent,
      mathStyle: mathStyle,
      textStyle: preferredStyle?.copyWith(fontSize: 16),
    );
  }
}

class BrutalistMarkdown extends StatelessWidget {
  final String data;
  final TextStyle? pStyle;
  final TextStyle? codeStyle;
  final BoxDecoration? codeBlockDecoration;

  const BrutalistMarkdown({super.key, required this.data, this.pStyle, this.codeStyle, this.codeBlockDecoration});

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: data,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: pStyle ?? TextStyle(fontSize: 16, height: 1.5, fontFamily: 'Courier', color: inkBlack),
        code: codeStyle ?? TextStyle(backgroundColor: Colors.black12, fontFamily: 'Courier', color: inkBlack),
        codeblockDecoration: codeBlockDecoration ?? const BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.zero),
      ),
      extensionSet: md.ExtensionSet(
        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        <md.InlineSyntax>[
          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
          BlockLatexSyntax(),
          InlineLatexSyntax(),
        ],
      ),
      builders: {
        'latex_block': LatexElementBuilder(mathStyle: MathStyle.display),
        'latex_inline': LatexElementBuilder(mathStyle: MathStyle.text),
      },
    );
  }
}

// ==========================================
// THEME: BRUTALIST LIGHT PURPLE PAPER
// ==========================================
final Color paperBg = const Color(0xFFE5DDF0);
final Color inkBlack = const Color(0xFF1E1E1E);
final Color brassAccent = const Color(0xFFB58840);
final Color rustRed = const Color(0xFF9E3C27);
final Color steamGreen = const Color(0xFF385E38);

final ThemeData brutalistTheme = ThemeData(
  fontFamily: 'Courier',
  scaffoldBackgroundColor: paperBg,
  colorScheme: ColorScheme.light(
    primary: inkBlack, secondary: brassAccent, surface: paperBg,
    error: rustRed, onPrimary: paperBg, onSecondary: inkBlack, onSurface: inkBlack,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: paperBg, foregroundColor: inkBlack, elevation: 0, centerTitle: true,
    shape: Border(bottom: BorderSide(color: inkBlack, width: 3)),
  ),
  cardTheme: CardThemeData(
    color: paperBg, elevation: 0, margin: const EdgeInsets.only(bottom: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: inkBlack, width: 2)),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: inkBlack, foregroundColor: paperBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      side: BorderSide(color: inkBlack, width: 2), padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: inkBlack,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      side: BorderSide(color: inkBlack, width: 2), padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true, fillColor: paperBg,
    border: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Colors.black, width: 2)),
    enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Colors.black, width: 2)),
    focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Colors.black, width: 3)),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: paperBg, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: Colors.black, width: 3))
  ),
  drawerTheme: DrawerThemeData(
    backgroundColor: paperBg, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: Colors.black, width: 2))
  ),
  dividerTheme: DividerThemeData(color: inkBlack, thickness: 2),
);

class ProNotesApp extends StatelessWidget {
  const ProNotesApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'PRO NOTES', debugShowCheckedModeBanner: false, theme: brutalistTheme, home: const MainNavigationScreen());
  }
}

// ==========================================
// MODELS (FLASHCARDS)
// ==========================================
class UserProfile {
  final String id;
  final String name;
  UserProfile({required this.id, required this.name});
  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(id: json['id'], name: json['name']);
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class Flashcard {
  final String id;
  String category;
  String subCategory;
  String front;
  String back;
  int correctHits;
  int wrongHits;

  Flashcard({required this.id, required this.category, required this.subCategory, required this.front, required this.back, this.correctHits = 0, this.wrongHits = 0});
  factory Flashcard.fromJson(Map<String, dynamic> json) => Flashcard(
    id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
    category: json['category'] ?? 'Uncategorized', subCategory: json['subCategory'] ?? 'General',
    front: json['front'] ?? '', back: json['back'] ?? '',
    correctHits: json['correctHits'] ?? 0, wrongHits: json['wrongHits'] ?? 0,
  );
  Map<String, dynamic> toJson() => {'id': id, 'category': category, 'subCategory': subCategory, 'front': front, 'back': back, 'correctHits': correctHits, 'wrongHits': wrongHits};
  
  double get accuracy => (correctHits + wrongHits) == 0 ? 0 : (correctHits / (correctHits + wrongHits)) * 100;
}

class StudySession {
  final String id;
  String category; 
  String subCategory; 
  final int cardsReviewed;
  final int correctRecalls;
  final int durationSeconds;
  final int timestamp;

  StudySession({required this.id, required this.category, required this.subCategory, required this.cardsReviewed, required this.correctRecalls, required this.durationSeconds, required this.timestamp});
  factory StudySession.fromJson(Map<String, dynamic> json) => StudySession(
    id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
    category: json['category'] ?? '', subCategory: json['subCategory'] ?? '',
    cardsReviewed: json['cardsReviewed'] ?? 0, correctRecalls: json['correctRecalls'] ?? 0,
    durationSeconds: json['durationSeconds'] ?? 0, timestamp: json['timestamp'] ?? 0,
  );
  Map<String, dynamic> toJson() => {'id': id, 'category': category, 'subCategory': subCategory, 'cardsReviewed': cardsReviewed, 'correctRecalls': correctRecalls, 'durationSeconds': durationSeconds, 'timestamp': timestamp};
}

enum SortMode { defaultOrder, timeAsc, timeDesc }

// ==========================================
// STATE MANAGEMENT (PROVIDER)
// ==========================================
class AppState extends ChangeNotifier {
  List<UserProfile> _users =[];
  UserProfile? _currentUser;
  List<Flashcard> _cards =[];
  List<StudySession> _sessions =[];
  List<String> _categoryOrder =[];
  Map<String, List<String>> _subCategoryOrder = {};
  bool _isLoading = true;

  List<UserProfile> get users => _users;
  UserProfile? get currentUser => _currentUser;
  List<Flashcard> get cards => _cards;
  List<StudySession> get sessions => _sessions;
  bool get isLoading => _isLoading;

  Future<void> initSystem() async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString('sys_users');
    if (usersJson != null) _users = (jsonDecode(usersJson) as List).map((u) => UserProfile.fromJson(u)).toList();
    if (_users.isEmpty) {
      _users.add(UserProfile(id: 'usr_${DateTime.now().millisecondsSinceEpoch}', name: 'OPERATOR_01'));
      await prefs.setString('sys_users', jsonEncode(_users.map((u) => u.toJson()).toList()));
    }
    final lastUserId = prefs.getString('last_user_id') ?? _users.first.id;
    _currentUser = _users.firstWhere((u) => u.id == lastUserId, orElse: () => _users.first);
    await loadUserData(_currentUser!.id);
  }

  Future<void> createUser(String name) async {
    final newUser = UserProfile(id: 'usr_${DateTime.now().millisecondsSinceEpoch}', name: name);
    _users.add(newUser);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sys_users', jsonEncode(_users.map((u) => u.toJson()).toList()));
    notifyListeners();
  }

  Future<void> switchUser(String id) async {
    _isLoading = true; notifyListeners();
    _currentUser = _users.firstWhere((u) => u.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_user_id', _currentUser!.id);
    await loadUserData(_currentUser!.id);
  }

  Future<void> loadUserData(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final cJson = prefs.getString('c_$uid');
    _cards = cJson != null ? (jsonDecode(cJson) as List).map((q) => Flashcard.fromJson(q)).toList() :[];

    final sJson = prefs.getString('ss_$uid');
    _sessions = sJson != null ? (jsonDecode(sJson) as List).map((s) => StudySession.fromJson(s)).toList() :[];

    final catOrder = prefs.getString('catOrd_$uid');
    _categoryOrder = catOrder != null ? List<String>.from(jsonDecode(catOrder)) :[];

    final subCatOrder = prefs.getString('subCatOrd_$uid');
    if (subCatOrder != null) {
      Map<String, dynamic> dec = jsonDecode(subCatOrder);
      _subCategoryOrder = dec.map((k, v) => MapEntry(k, List<String>.from(v)));
    } else { _subCategoryOrder = {}; }

    _isLoading = false; notifyListeners();
  }

  Future<void> saveUserData() async {
    if (_currentUser == null) return;
    final uid = _currentUser!.id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('c_$uid', jsonEncode(_cards.map((q) => q.toJson()).toList()));
    await prefs.setString('ss_$uid', jsonEncode(_sessions.map((s) => s.toJson()).toList()));
    await prefs.setString('catOrd_$uid', jsonEncode(_categoryOrder));
    await prefs.setString('subCatOrd_$uid', jsonEncode(_subCategoryOrder));
  }

  List<String> getCategories() {
    Set<String> existing = _cards.map((q) => q.category).toSet();
    _categoryOrder.removeWhere((c) => !existing.contains(c));
    for (var c in existing) { if (!_categoryOrder.contains(c)) _categoryOrder.add(c); }
    saveUserData(); return List.from(_categoryOrder);
  }

  void reorderCategory(int oldIdx, int newIdx) {
    if (newIdx > oldIdx) newIdx -= 1;
    final item = _categoryOrder.removeAt(oldIdx);
    _categoryOrder.insert(newIdx, item);
    saveUserData(); notifyListeners();
  }

  List<String> getSubCategories(String cat) {
    Set<String> existing = _cards.where((q) => q.category == cat).map((q) => q.subCategory).toSet();
    if (!_subCategoryOrder.containsKey(cat)) _subCategoryOrder[cat] =[];
    _subCategoryOrder[cat]!.removeWhere((c) => !existing.contains(c));
    for (var c in existing) { if (!_subCategoryOrder[cat]!.contains(c)) _subCategoryOrder[cat]!.add(c); }
    saveUserData(); return List.from(_subCategoryOrder[cat]!);
  }

  void moveSubCategoryUp(String cat, String subCat) {
    List<String> list = _subCategoryOrder[cat]!; int idx = list.indexOf(subCat);
    if (idx > 0) { list.removeAt(idx); list.insert(idx - 1, subCat); saveUserData(); notifyListeners(); }
  }

  void moveSubCategoryDown(String cat, String subCat) {
    List<String> list = _subCategoryOrder[cat]!; int idx = list.indexOf(subCat);
    if (idx != -1 && idx < list.length - 1) { list.removeAt(idx); list.insert(idx + 1, subCat); saveUserData(); notifyListeners(); }
  }

  List<Flashcard> getCardsBySubCategory(String cat, String subCat) => _cards.where((q) => q.category == cat && q.subCategory == subCat).toList();

  Future<bool> importCardsFromString(String jsonString) async {
    try {
      String sanitized = jsonString.trim();
      if (sanitized.startsWith('```')) {
        List<String> lines = sanitized.split('\n');
        if (lines.isNotEmpty && lines.first.trim().startsWith('```')) lines.removeAt(0);
        if (lines.isNotEmpty && lines.last.trim() == '```') lines.removeLast();
        sanitized = lines.join('\n').trim();
      }
      if (sanitized.isEmpty) return false;
      final List<dynamic> decoded = jsonDecode(sanitized);
      final newQs = decoded.map((q) => Flashcard.fromJson(q)).toList();
      final Map<String, Flashcard> existingMap = {for (var q in _cards) q.id: q};
      for (var q in newQs) existingMap[q.id] = q;
      _cards = existingMap.values.toList();
      await saveUserData(); notifyListeners();
      return true;
    } catch (e) { return false; }
  }

  void createManualCard(String cat, String subCat, String front, String back) {
    _cards.add(Flashcard(id: DateTime.now().millisecondsSinceEpoch.toString(), category: cat, subCategory: subCat, front: front, back: back));
    saveUserData(); notifyListeners();
  }

  void updateCardStats(String id, bool correct) {
    int idx = _cards.indexWhere((c) => c.id == id);
    if (idx != -1) {
      if (correct) _cards[idx].correctHits++;
      else _cards[idx].wrongHits++;
    }
  }

  void addSession(StudySession session) {
    _sessions.add(session);
    saveUserData(); notifyListeners();
  }

  StudySession? getLatestSession(String cat, String subCat) {
    try { return _sessions.lastWhere((s) => s.category == cat && s.subCategory == subCat); } catch(e) { return null; }
  }

  void renameCategory(String oldName, String newName) {
    for (var q in _cards) { if (q.category == oldName) q.category = newName; }
    for (var s in _sessions) { if (s.category == oldName) s.category = newName; } 
    int idx = _categoryOrder.indexOf(oldName);
    if(idx != -1) _categoryOrder[idx] = newName;
    if(_subCategoryOrder.containsKey(oldName)) _subCategoryOrder[newName] = _subCategoryOrder.remove(oldName)!;
    saveUserData(); notifyListeners();
  }

  void renameSubCategory(String cat, String oldSub, String newSub) {
    for (var q in _cards) { if (q.category == cat && q.subCategory == oldSub) q.subCategory = newSub; }
    for (var s in _sessions) { if (s.category == cat && s.subCategory == oldSub) s.subCategory = newSub; } 
    int idx = _subCategoryOrder[cat]!.indexOf(oldSub);
    if(idx != -1) _subCategoryOrder[cat]![idx] = newSub;
    saveUserData(); notifyListeners();
  }

  void moveCard(String id, String newCat, String newSubCat) {
    int idx = _cards.indexWhere((q) => q.id == id);
    if (idx != -1) { _cards[idx].category = newCat; _cards[idx].subCategory = newSubCat; saveUserData(); notifyListeners(); }
  }

  void deleteCategory(String cat) { 
    _cards.removeWhere((q) => q.category == cat); 
    _sessions.removeWhere((s) => s.category == cat);
    _categoryOrder.remove(cat); _subCategoryOrder.remove(cat);
    saveUserData(); notifyListeners(); 
  }

  void deleteSubCategory(String cat, String subCat) { 
    _cards.removeWhere((q) => q.category == cat && q.subCategory == subCat); 
    _sessions.removeWhere((s) => s.category == cat && s.subCategory == subCat);
    _subCategoryOrder[cat]?.remove(subCat);
    saveUserData(); notifyListeners(); 
  }

  void deleteSessionHistory(String cat, String subCat) {
    _sessions.removeWhere((s) => s.category == cat && s.subCategory == subCat);
    saveUserData(); notifyListeners();
  }

  void deleteCard(String id) { _cards.removeWhere((q) => q.id == id); saveUserData(); notifyListeners(); }
}

// ==========================================
// MAIN NAVIGATION
// ==========================================
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = const[HomeScreen(), OrganizeScreen(), CreateImportScreen(), AnalysisBaseScreen(), ProfileScreen()];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: inkBlack, width: 3))),
        child: NavigationBar(
          backgroundColor: paperBg, indicatorColor: brassAccent.withOpacity(0.5),
          selectedIndex: _currentIndex,
          onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
          destinations: const[
            NavigationDestination(icon: Icon(Icons.style_outlined), label: 'DECKS'),
            NavigationDestination(icon: Icon(Icons.folder_special_outlined), label: 'ORGANIZE'),
            NavigationDestination(icon: Icon(Icons.add_box_outlined), label: 'ADD'),
            NavigationDestination(icon: Icon(Icons.query_stats), label: 'GLOBAL'),
            NavigationDestination(icon: Icon(Icons.person_outline), label: 'PROFILE'),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// PROFILE SCREEN
// ==========================================
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    if (appState.isLoading || appState.currentUser == null) return const Center(child: CircularProgressIndicator(color: Colors.black));

    int totalSessions = appState.sessions.length;
    int totalCards = appState.cards.length;
    int totalReviewed = appState.sessions.fold(0, (s, e) => s + e.cardsReviewed);
    int totalCor = appState.sessions.fold(0, (s, e) => s + e.correctRecalls);
    double acc = totalReviewed == 0 ? 0 : (totalCor / totalReviewed) * 100;
    int totalTime = appState.sessions.fold(0, (s, e) => s + e.durationSeconds);

    return Scaffold(
      appBar: AppBar(title: const Text('USER_PROFILE')),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16 + MediaQuery.of(context).padding.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children:[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(border: Border.all(color: inkBlack, width: 2), color: brassAccent.withOpacity(0.2)),
              child: Column(
                children:[
                  const Icon(Icons.person, size: 64, color: Colors.black),
                  const SizedBox(height: 8),
                  Text('ACTIVE: ${appState.currentUser!.name}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const Divider(height: 32),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[const Text('TOTAL_CARDS_DB:', style: TextStyle(fontWeight: FontWeight.bold)), Text('$totalCards')]),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[const Text('STUDY_SESSIONS:', style: TextStyle(fontWeight: FontWeight.bold)), Text('$totalSessions')]),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[const Text('RECALL_ACCURACY:', style: TextStyle(fontWeight: FontWeight.bold)), Text('${acc.toStringAsFixed(1)}%')]),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[const Text('TOTAL_TIME_SPENT:', style: TextStyle(fontWeight: FontWeight.bold)), Text('${(totalTime / 60).toStringAsFixed(1)} MIN')]),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('REGISTERED_OPERATORS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...appState.users.map((u) => Card(
              color: u.id == appState.currentUser!.id ? steamGreen.withOpacity(0.2) : paperBg,
              child: ListTile(
                title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('ID: ${u.id}', style: const TextStyle(fontSize: 10)),
                trailing: u.id == appState.currentUser!.id ? const Icon(Icons.check_circle, color: Colors.black) : OutlinedButton(
                  onPressed: () => appState.switchUser(u.id),
                  child: const Text('SWITCH'),
                ),
              ),
            )),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _showNewUserDialog(context),
              icon: const Icon(Icons.person_add),
              label: const Text('CREATE_NEW_USER'),
            )
          ],
        ),
      ),
    );
  }

  void _showNewUserDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('NEW_OPERATOR'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'NAME')),
        actions:[
          OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          FilledButton(onPressed: () {
            if (ctrl.text.trim().isNotEmpty) context.read<AppState>().createUser(ctrl.text.trim().toUpperCase());
            Navigator.pop(ctx);
          }, child: const Text('CREATE')),
        ],
      ),
    );
  }
}

// ==========================================
// IMPORT & CREATE SCREEN
// ==========================================
class CreateImportScreen extends StatefulWidget {
  const CreateImportScreen({super.key});
  @override
  State<CreateImportScreen> createState() => _CreateImportScreenState();
}

class _CreateImportScreenState extends State<CreateImportScreen> {
  final _frontCtrl = TextEditingController();
  final _backCtrl = TextEditingController();
  final _catCtrl = TextEditingController();
  final _subCatCtrl = TextEditingController();
  final _jsonCtrl = TextEditingController();

  final String templateJson = r'''[
  {
    "id": "c1",
    "category": "Physics",
    "subCategory": "Formulas",
    "front": "What is the formula for force?\n\n$$F = ?$$",
    "back": "Force equals mass times acceleration.\n\n$$F = ma$$"
  }
]''';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ADD_DATA'),
          bottom: TabBar(
            indicator: BoxDecoration(color: inkBlack), labelColor: paperBg, unselectedLabelColor: inkBlack,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Courier'),
            tabs: const[Tab(text: 'MANUAL'), Tab(text: 'JSON_IMPORT')],
          ),
        ),
        body: TabBarView(
          children:[
            _buildManualEntry(),
            _buildJsonImport(),
          ],
        ),
      ),
    );
  }

  Widget _buildManualEntry() {
    return SingleChildScrollView(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16 + MediaQuery.of(context).padding.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children:[
          TextField(controller: _catCtrl, decoration: const InputDecoration(labelText: 'DIRECTORY (Category)')),
          const SizedBox(height: 16),
          TextField(controller: _subCatCtrl, decoration: const InputDecoration(labelText: 'SUB_DIR (Deck Name)')),
          const SizedBox(height: 16),
          TextField(controller: _frontCtrl, maxLines: 4, decoration: const InputDecoration(labelText: 'FRONT (Question / Markdown)')),
          const SizedBox(height: 16),
          TextField(controller: _backCtrl, maxLines: 4, decoration: const InputDecoration(labelText: 'BACK (Answer / Notes)')),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('SAVE CARD'),
            onPressed: () {
              if (_catCtrl.text.isEmpty || _subCatCtrl.text.isEmpty || _frontCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('MISSING_REQUIRED_FIELDS'), backgroundColor: Colors.red));
                return;
              }
              context.read<AppState>().createManualCard(_catCtrl.text.trim(), _subCatCtrl.text.trim(), _frontCtrl.text.trim(), _backCtrl.text.trim());
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CARD_SAVED_SUCCESSFULLY'), backgroundColor: Colors.green));
              _frontCtrl.clear(); _backCtrl.clear(); // Keep cat/subCat for quick entry
            },
          )
        ],
      ),
    );
  }

  Widget _buildJsonImport() {
    return SingleChildScrollView(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16 + MediaQuery.of(context).padding.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children:[
          Container(
            decoration: BoxDecoration(border: Border.all(color: inkBlack, width: 2), color: brassAccent.withOpacity(0.2)),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:[
                const Text('REFERENCE_JSON_STRUCTURE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Text(templateJson, style: const TextStyle(fontSize: 10, height: 1.3)),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: templateJson));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('COPIED TO CLIPBOARD'), backgroundColor: Colors.black));
                  },
                  icon: const Icon(Icons.copy, size: 16), label: const Text('COPY TEMPLATE'),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextField(controller: _jsonCtrl, maxLines: 12, decoration: const InputDecoration(hintText: 'PASTE_JSON_HERE...', labelText: 'DATA_INPUT')),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              bool success = await context.read<AppState>().importCardsFromString(_jsonCtrl.text);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? 'SYSTEM: IMPORT SUCCESSFUL' : 'ERROR: INVALID FORMAT'), backgroundColor: success ? steamGreen : rustRed));
                if(success) _jsonCtrl.clear();
              }
            },
            child: const Text('EXECUTE IMPORT'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// HOME SCREEN (Decks)
// ==========================================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final categories = appState.getCategories();

    return Scaffold(
      appBar: AppBar(title: const Text('INDEX: DIRECTORIES')),
      body: appState.isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : categories.isEmpty
              ? const Center(child: Text('NO DECKS FOUND. PROCEED TO ADD.', style: TextStyle(fontWeight: FontWeight.bold)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.folder_open, color: Colors.black),
                        title: Text(category.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.black),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubCategoryScreen(category: category))),
                      ),
                    );
                  },
                ),
    );
  }
}

class SubCategoryScreen extends StatelessWidget {
  final String category;
  const SubCategoryScreen({super.key, required this.category});

  void _confirmClearRecord(BuildContext context, AppState appState, String subCat) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('CLEAR_RECORD'),
      content: const Text('THIS WILL DELETE ALL STUDY SESSIONS/STATS FOR THIS DECK. PROCEED?'),
      actions:[
        OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: rustRed), onPressed: () {
          appState.deleteSessionHistory(category, subCat);
          Navigator.pop(ctx);
        }, child: const Text('CONFIRM')),
      ]
    ));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    List<String> subCats = appState.getSubCategories(category);

    return Scaffold(
      appBar: AppBar(title: Text('DIR: ${category.toUpperCase()}')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: subCats.length,
        itemBuilder: (context, index) {
          final subCat = subCats[index];
          final cards = appState.getCardsBySubCategory(category, subCat);
          final session = appState.getLatestSession(category, subCat);
          
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children:[
                      Expanded(child: Text(subCat.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                      if (session != null) IconButton(icon: const Icon(Icons.delete_sweep, color: Colors.red), onPressed: () => _confirmClearRecord(context, appState, subCat)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('CARDS: ${cards.length} | LAST REVIEW: ${session != null ? DateFormat('MMM dd').format(DateTime.fromMillisecondsSinceEpoch(session.timestamp)) : 'NEVER'}'),
                  const Divider(),
                  Row(
                    children:[
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.menu_book), label: const Text('READ NOTES'),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoteViewScreen(deckName: subCat, cards: cards))),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.psychology), label: const Text('STUDY'),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudyScreen(category: category, subCategory: subCat, cards: cards..shuffle()))),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// NOTE VIEW SCREEN (Read Mode)
// ==========================================
class NoteViewScreen extends StatelessWidget {
  final String deckName;
  final List<Flashcard> cards;
  const NoteViewScreen({super.key, required this.deckName, required this.cards});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('READ: ${deckName.toUpperCase()}')),
      body: ListView.builder(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16 + MediaQuery.of(context).padding.bottom),
        itemCount: cards.length,
        itemBuilder: (context, index) {
          final c = cards[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:[
                  BrutalistMarkdown(data: c.front, pStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Courier')),
                  if (c.back.isNotEmpty) ...[
                    const Divider(height: 24),
                    BrutalistMarkdown(data: c.back),
                  ]
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// STUDY SCREEN (Flashcard Mode)
// ==========================================
class StudyScreen extends StatefulWidget {
  final String category;
  final String subCategory;
  final List<Flashcard> cards;
  const StudyScreen({super.key, required this.category, required this.subCategory, required this.cards});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  int _currentIndex = 0;
  bool _isFlipped = false;
  int _correctHits = 0;
  int _totalElapsed = 0;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) { if(mounted) setState(() => _totalElapsed++); });
  }

  @override
  void dispose() { _timer.cancel(); super.dispose(); }

  void _handleScore(bool correct) {
    final appState = context.read<AppState>();
    appState.updateCardStats(widget.cards[_currentIndex].id, correct);
    if (correct) _correctHits++;

    if (_currentIndex < widget.cards.length - 1) {
      setState(() { _currentIndex++; _isFlipped = false; });
    } else {
      _timer.cancel();
      final session = StudySession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        category: widget.category, subCategory: widget.subCategory,
        cardsReviewed: widget.cards.length, correctRecalls: _correctHits,
        durationSeconds: _totalElapsed, timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      appState.addSession(session);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ResultScreen(session: session)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) return Scaffold(appBar: AppBar(title: const Text('STUDY')), body: const Center(child: Text('DECK IS EMPTY')));
    final card = widget.cards[_currentIndex];

    return Scaffold(
      appBar: AppBar(title: Text("STUDY: ${widget.subCategory} [${_currentIndex + 1}/${widget.cards.length}]")),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children:[
          LinearProgressIndicator(value: (_currentIndex + 1) / widget.cards.length, backgroundColor: paperBg, color: inkBlack, minHeight: 4),
          Expanded(
            child: GestureDetector(
              onTap: () { if (!_isFlipped) setState(() => _isFlipped = true); },
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(border: Border.all(color: inkBlack, width: 4), color: paperBg, boxShadow: const[BoxShadow(color: Colors.black26, offset: Offset(8, 8))]),
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children:[
                        BrutalistMarkdown(data: card.front, pStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Courier', height: 1.4)),
                        if (_isFlipped) ...[
                          const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Divider(thickness: 3)),
                          BrutalistMarkdown(data: card.back, pStyle: const TextStyle(fontSize: 18, fontFamily: 'Courier', height: 1.4)),
                        ] else ...[
                          const SizedBox(height: 48),
                          const Icon(Icons.touch_app, size: 48, color: Colors.black38),
                          const Text('TAP TO FLIP', style: TextStyle(color: Colors.black38, fontWeight: FontWeight.bold)),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isFlipped)
            Container(
              padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16 + MediaQuery.of(context).padding.bottom),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: inkBlack, width: 3)), color: paperBg),
              child: Row(
                children:[
                  Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: rustRed), onPressed: () => _handleScore(false), child: const Text('FORGOT'))),
                  const SizedBox(width: 16),
                  Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: brassAccent), onPressed: () => _handleScore(true), child: const Text('HARD'))),
                  const SizedBox(width: 16),
                  Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: steamGreen), onPressed: () => _handleScore(true), child: const Text('EASY'))),
                ],
              ),
            )
        ],
      ),
    );
  }
}

// ==========================================
// RESULT SCREEN
// ==========================================
class ResultScreen extends StatelessWidget {
  final StudySession session;
  const ResultScreen({super.key, required this.session});
  @override
  Widget build(BuildContext context) {
    double perc = session.cardsReviewed > 0 ? (session.correctRecalls / session.cardsReviewed) * 100 : 0;
    return Scaffold(
      appBar: AppBar(title: const Text('SESSION_REPORT'), automaticallyImplyLeading: false),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children:[
              Text('RECALL RATE: ${perc.toStringAsFixed(1)}%', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: perc >= 80 ? steamGreen : (perc >= 50 ? brassAccent : rustRed))),
              const Divider(height: 48),
              Text('CARDS REVIEWED: ${session.cardsReviewed}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text('CORRECT HITS: ${session.correctRecalls}', style: const TextStyle(fontSize: 20)),
              Text('TIME: ${session.durationSeconds}s', style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 48),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                icon: const Icon(Icons.home), label: const Text('RETURN TO TERMINAL'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// GLOBAL ANALYSIS 
// ==========================================
class AnalysisBaseScreen extends StatelessWidget {
  const AnalysisBaseScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final sessions = appState.sessions;
    if (sessions.isEmpty) return Scaffold(appBar: AppBar(title: const Text('GLOBAL_ANALYSIS')), body: const Center(child: Text('NO DATA', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))));

    Map<String, List<StudySession>> sessionsByCategory = {};
    for (var s in sessions) sessionsByCategory.putIfAbsent(s.category, () =>[]).add(s);

    List<BarChartGroupData> barGroups =[]; List<String> categoryLabels =[]; List<Map<String, dynamic>> categoryStats =[]; int xIndex = 0;
    sessionsByCategory.forEach((cat, list) {
      int totalRev = list.fold(0, (sum, s) => sum + s.cardsReviewed);
      int totalCor = list.fold(0, (sum, s) => sum + s.correctRecalls);
      double accuracy = totalRev > 0 ? (totalCor / totalRev) * 100 : 0;
      barGroups.add(BarChartGroupData(x: xIndex++, barRods:[BarChartRodData(toY: accuracy, color: inkBlack, width: 24, borderRadius: BorderRadius.zero)]));
      categoryLabels.add(cat); categoryStats.add({'cat': cat, 'acc': accuracy});
    });

    return Scaffold(
      appBar: AppBar(title: const Text('GLOBAL_ANALYSIS')),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16 + MediaQuery.of(context).padding.bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children:[
          const Text('RECALL_ACCURACY_GRAPH [%]', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 24),
          Container(
            height: 250, padding: const EdgeInsets.all(16), decoration: BoxDecoration(border: Border.all(color: inkBlack, width: 2)),
            child: BarChart(BarChartData(
              maxY: 100,
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, meta) => Padding(padding: const EdgeInsets.only(top: 8), child: Text(categoryLabels[val.toInt()], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))))),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (val, meta) => Text('${val.toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (val) => FlLine(color: Colors.black26, strokeWidth: 1, dashArray:[4, 4])), borderData: FlBorderData(show: false), barGroups: barGroups,
            )),
          ),
          const SizedBox(height: 32), const Text('CATEGORY_BREAKDOWN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 16),
          ...categoryStats.map((stat) => Card(child: Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(stat['cat'].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[const Text('RECALL RATE:'), Text('${(stat['acc'] as double).toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold))])
          ]))))
        ]),
      ),
    );
  }
}

// ==========================================
// ORGANIZE SCREEN (Drag & Drop Reordering)
// ==========================================
class OrganizeScreen extends StatelessWidget {
  const OrganizeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final categories = appState.getCategories();

    return Scaffold(
      appBar: AppBar(title: const Text('SYS_ORGANIZATION')),
      body: categories.isEmpty
          ? const Center(child: Text('EMPTY_DATABASE', style: TextStyle(fontWeight: FontWeight.bold)))
          : ReorderableListView.builder(
              itemCount: categories.length,
              onReorder: (oldIdx, newIdx) => appState.reorderCategory(oldIdx, newIdx),
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
              itemBuilder: (context, index) {
                final cat = categories[index];
                return Container(
                  key: ValueKey(cat),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(border: Border.all(color: inkBlack, width: 2), color: paperBg),
                  child: ExpansionTile(
                    leading: const Icon(Icons.drag_indicator, color: Colors.black),
                    title: Row(children:[
                      Text(cat.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _renameCatDialog(context, cat)),
                    ]),
                    trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.black), onPressed: () => appState.deleteCategory(cat)),
                    children: appState.getSubCategories(cat).map((subCat) {
                      return Container(
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: inkBlack, width: 2)), color: brassAccent.withOpacity(0.1)),
                        child: ExpansionTile(
                          title: Row(children:[
                            Column(children:[
                              InkWell(child: const Icon(Icons.keyboard_arrow_up), onTap: () => appState.moveSubCategoryUp(cat, subCat)),
                              InkWell(child: const Icon(Icons.keyboard_arrow_down), onTap: () => appState.moveSubCategoryDown(cat, subCat)),
                            ]),
                            const SizedBox(width: 8),
                            Text('> ${subCat.toUpperCase()}'),
                            const Spacer(),
                            IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _renameSubCatDialog(context, cat, subCat)),
                          ]),
                          trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.black), onPressed: () => appState.deleteSubCategory(cat, subCat)),
                          children: appState.getCardsBySubCategory(cat, subCat).map((c) => ListTile(
                            title: BrutalistMarkdown(data: c.front, pStyle: const TextStyle(fontFamily: 'Courier', overflow: TextOverflow.ellipsis)),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children:[
                              IconButton(icon: const Icon(Icons.drive_file_move_outline, size: 20, color: Colors.black), onPressed: () => _moveCardDialog(context, c)),
                              IconButton(icon: const Icon(Icons.delete_forever, size: 20, color: Colors.black), onPressed: () => appState.deleteCard(c.id)),
                            ]),
                          )).toList(),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
    );
  }

  void _renameCatDialog(BuildContext context, String oldName) {
    final ctrl = TextEditingController(text: oldName);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('RENAME_DIR'), content: TextField(controller: ctrl),
      actions:[
        OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
        FilledButton(onPressed: () { if(ctrl.text.trim().isNotEmpty) context.read<AppState>().renameCategory(oldName, ctrl.text.trim()); Navigator.pop(ctx); }, child: const Text('CONFIRM')),
      ]
    ));
  }
  void _renameSubCatDialog(BuildContext context, String cat, String oldSub) {
    final ctrl = TextEditingController(text: oldSub);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('RENAME_SUB_DIR'), content: TextField(controller: ctrl),
      actions:[
        OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
        FilledButton(onPressed: () { if(ctrl.text.trim().isNotEmpty) context.read<AppState>().renameSubCategory(cat, oldSub, ctrl.text.trim()); Navigator.pop(ctx); }, child: const Text('CONFIRM')),
      ]
    ));
  }
  void _moveCardDialog(BuildContext context, Flashcard c) {
    final catCtrl = TextEditingController(text: c.category); final subCtrl = TextEditingController(text: c.subCategory);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('MOVE_FILE'),
      content: Column(mainAxisSize: MainAxisSize.min, children:[TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'DEST_DIR')), const SizedBox(height: 16), TextField(controller: subCtrl, decoration: const InputDecoration(labelText: 'DEST_SUB_DIR'))]),
      actions:[
        OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
        FilledButton(onPressed: () { if(catCtrl.text.trim().isNotEmpty && subCtrl.text.trim().isNotEmpty) context.read<AppState>().moveCard(c.id, catCtrl.text.trim(), subCtrl.text.trim()); Navigator.pop(ctx); }, child: const Text('EXECUTE')),
      ]
    ));
  }
}
