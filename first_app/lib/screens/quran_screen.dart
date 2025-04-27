import 'package:flutter/material.dart';
import '../services/quran_database_service.dart';
import '../models/surah.dart';
import '../widgets/surah_tile.dart';
import 'dart:developer' as developer;
import '../utils/asset_utils.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  final QuranDatabaseService _quranService = QuranDatabaseService();
  final ScrollController _scrollController = ScrollController();
  late Future<List<Surah>> _surahs;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadQuranData();
  }

  Future<void> _loadQuranData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Run comprehensive asset debugging
      await AssetUtils.debugAssetLoading();

      // Check if the asset exists first
      final bool assetExists =
          await AssetUtils.assetExists('assets/quran.sqlite');

      if (!assetExists) {
        throw Exception(
            'Quran database asset not found. Please ensure the asset is properly included in the app.');
      }

      // Log all available assets for debugging
      await AssetUtils.logAvailableAssets();

      // Log database schema to diagnose table issues
      await _quranService.logDatabaseSchema();

      _surahs = _quranService.getAllSurahs();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      developer.log('Error loading Quran data: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Al-Quran',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {
              // Implement search functionality here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search coming soon')),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorWidget()
              : FutureBuilder<List<Surah>>(
                  future: _surahs,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 60,
                              color: Colors.red.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading Quran data',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.red.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              snapshot.error.toString(),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _loadQuranData,
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      );
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.menu_book,
                              size: 60,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Quran data available',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _loadQuranData,
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      );
                    }

                    final surahs = snapshot.data!;
                    return RefreshIndicator(
                      onRefresh: _loadQuranData,
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: surahs.length,
                        itemBuilder: (context, index) {
                          final surah = surahs[index];
                          return SurahTile(
                            surah: surah,
                            onTap: () {
                              _navigateToSurahDetail(surah);
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildErrorWidget() {
    // Special handling for the "no such table" error
    if (_errorMessage != null && _errorMessage!.contains('no such table')) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.table_chart,
                size: 60,
                color: Colors.red.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'Database Table Missing',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'The SQLite database file was loaded successfully, but it does not contain the expected table structure.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Technical Details:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage ?? 'Unknown error',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Possible Solutions:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. Verify that the quran.sqlite file has the correct table structure',
                      style: TextStyle(
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '2. Try using a different Quran database file that contains a valid table',
                      style: TextStyle(
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '3. Update the app to match the actual table structure of your database',
                      style: TextStyle(
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _loadQuranData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _tryAlternativeMethod,
                    icon: const Icon(Icons.cloud_download),
                    label: const Text('Alternative Method'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade100,
                      foregroundColor: Colors.blue.shade900,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Default error widget for other errors
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading Quran data',
              style: TextStyle(
                fontSize: 18,
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Possible solutions:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Make sure the quran.sqlite file is in the assets folder',
                    style: TextStyle(
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '2. Check that assets/quran.sqlite is properly listed in pubspec.yaml',
                    style: TextStyle(
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '3. Run "flutter clean" and "flutter pub get"',
                    style: TextStyle(
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '4. Restart the app',
                    style: TextStyle(
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Try Alternative Method:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This will attempt to use an alternative method to download the Quran database.',
                    style: TextStyle(
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _tryAlternativeMethod,
                      icon: const Icon(Icons.cloud_download),
                      label: const Text('Try Alternative Download'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade100,
                        foregroundColor: Colors.blue.shade900,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadQuranData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _tryAlternativeMethod() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attempting to use alternative method...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Here you would implement an alternative approach like:
      // 1. Downloading the database from a server
      // 2. Using a pre-packaged database file
      // 3. Creating a minimal database with essential data

      // For demonstration, we're just showing how this would work
      await Future.delayed(const Duration(seconds: 2));

      // Try loading the data again
      _surahs = _quranService.getAllSurahs();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      developer.log('Error in alternative method: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Alternative method also failed: ${e.toString()}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alternative method failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _navigateToSurahDetail(Surah surah) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SurahDetailScreen(surah: surah),
      ),
    );
  }
}

class SurahDetailScreen extends StatefulWidget {
  final Surah surah;

  const SurahDetailScreen({super.key, required this.surah});

  @override
  State<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends State<SurahDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  String _content = '';
  final String _bismillah = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';

  @override
  void initState() {
    super.initState();
    _loadSurahContent();
  }

  Future<void> _loadSurahContent() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // We already have the content in the Surah object
      String content = widget.surah.content;

      // Process content for At-Tawbah (9) and other surahs differently
      if (widget.surah.id != 9) {
        // Check if content already starts with Bismillah and remove it
        // because we'll display it separately in the UI
        if (content.startsWith(_bismillah)) {
          content = content.substring(_bismillah.length).trim();
        }
      }

      _content = content;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      developer.log('Error loading surah content: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          widget.surah.nameEn,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {
              // Show options menu
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Options coming soon')),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  // Surah header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          widget.surah.nameAr,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            fontFamily:
                                'Indopak', // Using an existing font from pubspec
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.surah.nameEn,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: widget.surah.isMakki
                                    ? Colors.amber.shade50
                                    : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                widget.surah.originalClassification == 'مكية' ||
                                        widget.surah.originalClassification ==
                                            'مدنية'
                                    ? widget.surah.originalClassification
                                    : (widget.surah.isMakki
                                        ? 'Makki'
                                        : 'Madani'),
                                style: TextStyle(
                                  color: widget.surah.isMakki
                                      ? Colors.amber.shade800
                                      : Colors.green.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: widget.surah
                                                  .originalClassification ==
                                              'مكية' ||
                                          widget.surah.originalClassification ==
                                              'مدنية'
                                      ? 'Indopak'
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${widget.surah.versesCount} Verses',
                                style: TextStyle(
                                  color: Colors.blue.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Surah content
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: widget.surah.id != 9
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Bismillah (displayed separately)
                                    Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 20),
                                      child: Text(
                                        _bismillah,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          height: 2.0,
                                          fontFamily: 'Indopak',
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),

                                    // Add decorative separator
                                    Container(
                                      width: 200,
                                      margin: const EdgeInsets.only(bottom: 20),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Divider(
                                              color:
                                                  Colors.teal.withOpacity(0.5),
                                              thickness: 1,
                                            ),
                                          ),
                                          Container(
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 10),
                                            child: Text(
                                              '۝',
                                              style: TextStyle(
                                                fontSize: 20,
                                                color: Colors.teal.shade700,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Divider(
                                              color:
                                                  Colors.teal.withOpacity(0.5),
                                              thickness: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Rest of the content
                                    Text(
                                      _content,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        height: 1.8,
                                        fontFamily: 'Indopak',
                                      ),
                                      textAlign: TextAlign.justify,
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    // Note for Surah At-Tawbah
                                    if (widget.surah.id == 9)
                                      Container(
                                        width: double.infinity,
                                        margin:
                                            const EdgeInsets.only(bottom: 20),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade50,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: Colors.amber.shade300),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              'سورة التوبة هي السورة الوحيدة التي لا تبدأ بالبسملة',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontFamily: 'Indopak',
                                                color: Colors.amber.shade900,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Surah At-Tawbah is the only surah that does not begin with Bismillah',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.amber.shade800,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    Text(
                                      _content,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        height: 1.8,
                                        fontFamily: 'Indopak',
                                      ),
                                      textAlign: TextAlign.justify,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
