import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xポスト テキスト化＆フォルダ保存',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

// 画面切り替え（タブバー）用の管理スクリーン
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const SavedListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.download),
            label: '取得',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder),
            label: '保存リスト',
          ),
        ],
      ),
    );
  }
}

// 全カテゴリ定義
final List<String> kCategories = [
  '自己啓発',
  '健康',
  '防災ライフハック',
  'レシピ',
  'AIカスタム',
  '暗号資産',
  '暮らし',
  '法律',
  '法則',
  '読書・映画',
  'その他',
];

// キーワード辞書
final Map<String, List<String>> kCategoryKeywords = {
  'AIカスタム': ['ChatGPT', 'GPT', 'プロンプト', 'Claude', 'Gemini', 'LLM', '生成AI', 'Midjourney', 'AI', 'カスタム指示', 'アプリ'],
  '自己啓発': ['習慣', '思考', '目標', '成長', '成功', 'メンタル', '努力', 'モチベーション', '人生', 'マインド', 'リソース', '判断'],
  '健康': ['健康', '筋トレ', 'ダイエット', '睡眠', '食事', '運動', '予防', 'カロリー', '疲労', '体重'],
  '防災ライフハック': ['防災', '地震', '避難', '備蓄', '台風', '非常食', 'ライフハック', '応急', '対策', '災害'],
  'レシピ': ['レシピ', '作り方', '材料', '料理', '美味', '時短', 'クッキング', 'パスタ', '簡単', '味付け', '調理'],
  '暗号資産': ['暗号資産', '仮想通貨', 'ビットコイン', 'BTC', 'ETH', 'Web3', 'ブロックチェーン', 'NFT', 'リップル', 'xrp', '規制'],
  '暮らし': ['暮らし', '掃除', '収納', '節約', 'インテリア', '家事', '便利グッズ', '生活', '断捨離'],
  '法律': ['法律', '弁護士', '権利', '契約', '違法', '著作権', '訴訟', '労働法', '規約', '損害賠償', '改正', '投票'],
  '法則': ['法則', '倍音', '血液脳関門', 'pi', '螺旋', '黄金比'],
  '読書・映画': ['読書', '映画', '本', '小説', '著者', 'シネマ', '作品', 'レビュー', 'ネタバレ', '推薦図書'],
};

// ホーム画面（URL入力・テキスト取得）
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  String? _authorName;
  String? _tweetText;
  String? _selectedCategory;

  String _categorizeText(String text) {
    Map<String, int> scores = {};

    kCategoryKeywords.forEach((category, keywords) {
      int score = 0;
      for (var keyword in keywords) {
        if (text.toLowerCase().contains(keyword.toLowerCase())) {
          score++;
        }
      }
      if (score > 0) {
        scores[category] = score;
      }
    });

    if (scores.isEmpty) {
      return 'その他';
    }

    var sortedEntries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries.first.key;
  }

  Future<void> _fetchTweetText(String url) async {
    if (url.isEmpty) return;

    setState(() {
      _isLoading = true;
      _authorName = null;
      _tweetText = null;
      _selectedCategory = null;
    });

    try {
      final oembedUrl = Uri.parse(
        'https://publish.twitter.com/oembed?url=${Uri.encodeComponent(url)}&omit_script=true',
      );

      final response = await http.get(oembedUrl);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String rawHtml = data['html'] ?? '';
        final document = html_parser.parse(rawHtml);
        final pElement = document.querySelector('p');
        final cleanText = pElement?.text ?? document.body?.text ?? '';

        setState(() {
          _authorName = data['author_name'];
          _tweetText = cleanText;
          _selectedCategory = _categorizeText(cleanText);
        });
      } else {
        _showSnackBar('ポストの取得に失敗しました');
      }
    } catch (e) {
      _showSnackBar('エラーが発生しました: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // アプリ内に保存する処理
  Future<void> _saveItem() async {
    if (_tweetText == null || _selectedCategory == null) return;

    final prefs = await SharedPreferences.getInstance();
    final String? existingDataStr = prefs.getString('saved_posts');
    List<dynamic> existingList = [];

    if (existingDataStr != null) {
      existingList = jsonDecode(existingDataStr);
    }

    final newItem = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'category': _selectedCategory,
      'author': _authorName ?? '不明',
      'text': _tweetText,
      'createdAt': DateTime.now().toIso8601String(),
    };

    existingList.insert(0, newItem); // 新しいものを先頭に追加
    await prefs.setString('saved_posts', jsonEncode(existingList));

    _showSnackBar('【$_selectedCategory】フォルダに保存しました！');
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('クリップボードにコピーしました！');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Xポスト テキスト化')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'XのポストURLを貼り付け',
                border: OutlineInputBorder(),
                hintText: 'https://x.com/...',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _fetchTweetText(_urlController.text),
              icon: const Icon(Icons.download),
              label: const Text('本文を取得する'),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_tweetText != null) ...[
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _authorName ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownButton<String>(
                            value: _selectedCategory,
                            items: kCategories.map((String category) {
                              return DropdownMenuItem<String>(
                                value: category,
                                child: Text(
                                  category,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedCategory = newValue;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_tweetText!, style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _copyToClipboard(_tweetText!),
                            icon: const Icon(Icons.copy),
                            label: const Text('コピー'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _saveItem,
                            icon: const Icon(Icons.bookmark_add),
                            label: const Text('アプリに保存'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// 保存済みリスト＆フォルダ閲覧画面
class SavedListScreen extends StatefulWidget {
  const SavedListScreen({super.key});

  @override
  State<SavedListScreen> createState() => _SavedListScreenState();
}

class _SavedListScreenState extends State<SavedListScreen> {
  List<Map<String, dynamic>> _savedPosts = [];
  String _filterCategory = 'すべて';

  @override
  void initState() {
    super.initState();
    _loadSavedPosts();
  }

  Future<void> _loadSavedPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? dataStr = prefs.getString('saved_posts');
    if (dataStr != null) {
      final List<dynamic> decoded = jsonDecode(dataStr);
      setState(() {
        _savedPosts = decoded.cast<Map<String, dynamic>>();
      });
    }
  }

  Future<void> _deletePost(String id) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedPosts.removeWhere((item) => item['id'] == id);
    });
    await prefs.setString('saved_posts', jsonEncode(_savedPosts));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('削除しました')),
      );
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('クリップボードにコピーしました！')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // フォルダ選択用フィルタの選択肢
    final filterOptions = ['すべて', ...kCategories];

    // 表示データの絞り込み
    final filteredList = _filterCategory == 'すべて'
        ? _savedPosts
        : _savedPosts.where((item) => item['category'] == _filterCategory).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('保存済みフォルダ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSavedPosts,
          )
        ],
      ),
      body: Column(
        children: [
          // 横スクロール式のジャンルフィルタータブ
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: filterOptions.map((category) {
                final isSelected = _filterCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _filterCategory = category;
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          // リスト表示
          Expanded(
            child: filteredList.isEmpty
                ? const Center(child: Text('保存されたデータはありません'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Chip(
                                    label: Text(
                                      item['category'] ?? 'その他',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () => _deletePost(item['id']),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['text'] ?? '',
                                style: const TextStyle(fontSize: 15),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '投稿者: ${item['author']}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _copyToClipboard(item['text']),
                                    icon: const Icon(Icons.copy, size: 16),
                                    label: const Text('コピー'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}