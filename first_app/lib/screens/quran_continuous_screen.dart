import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'dart:math';
import '../services/quran_database_service.dart';
import '../models/surah.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuranContinuousScreen extends StatefulWidget {
  const QuranContinuousScreen({super.key});

  @override
  State<QuranContinuousScreen> createState() => _QuranContinuousScreenState();
}

class _QuranContinuousScreenState extends State<QuranContinuousScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final QuranDatabaseService _quranService = QuranDatabaseService();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  String? _errorMessage;
  final List<Surah> _surahs = [];
  final String _bismillah = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';

  // Pagination variables
  static const int _pageSize = 10; // Load 10 surahs at a time
  int _currentPage = 0;
  bool _hasMoreSurahs = true;
  bool _isLoadingMore = false;

  // Current visible surah for app bar title
  String _currentVisibleSurah = "Al-Quran";
  int? _currentVisibleSurahId;

  // Cache the last saved position
  double? _lastScrollPosition;

  // Add a flag to disable auto-updates temporarily
  bool _disableAutoUpdates = false;

  // Constants for SharedPreferences keys
  static const String _scrollPositionKey = 'quran_scroll_position';
  static const String _lastSurahIdKey = 'quran_last_surah_id';
  static const String _lastSurahNameKey = 'quran_last_surah_name';

  // Timer for periodic saving of scroll position
  DateTime _lastSaveTime = DateTime.now();

  // Flag to show if we're restoring a position
  bool _isRestoringPosition = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Register for lifecycle events
    WidgetsBinding.instance.addObserver(this);

    // First load the Quran data
    _loadQuranData().then((_) {
      // Then restore the scroll position after ensuring data is loaded
      _restoreScrollPosition();
    });

    // Add scroll listener for pagination and updating app bar
    _scrollController.addListener(_scrollListener);

    // Add memory management
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkMemoryUsage();

      // Set up a periodic sync to ensure surah name stays accurate
      // This helps catch any missed updates during fast scrolling
      _setupPeriodicSync();
    });
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // Save the final position when the screen is disposed
    _saveScrollPositionNow();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Save position when app goes to background
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _saveScrollPositionNow();
      developer.log('App lifecycle changed to $state. Saved reading position.');
    }
  }

  void _scrollListener() {
    // For infinite scroll pagination
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      if (!_isLoadingMore && _hasMoreSurahs) {
        _loadMoreSurahs();
      }
    }

    // Use a direct approach to update the visible surah
    _directUpdateVisibleSurah();

    // Save scroll position periodically
    _saveScrollPosition();
  }

  Future<void> _saveScrollPosition() async {
    // Only save position every 2 seconds to avoid excessive writes
    final now = DateTime.now();
    if (now.difference(_lastSaveTime).inSeconds >= 2) {
      _lastSaveTime = now;
      await _saveScrollPositionNow();
    }
  }

  Future<void> _saveScrollPositionNow() async {
    if (!_scrollController.hasClients) return;

    final prefs = await SharedPreferences.getInstance();

    // Save current scroll position
    await prefs.setDouble(
        _scrollPositionKey, _scrollController.position.pixels);

    // Save current surah ID and name
    if (_currentVisibleSurahId != null) {
      await prefs.setInt(_lastSurahIdKey, _currentVisibleSurahId!);
      await prefs.setString(_lastSurahNameKey, _currentVisibleSurah);

      // Log for debugging
      developer.log('Saved position: ${_scrollController.position.pixels}, '
          'Surah: $_currentVisibleSurah (ID: $_currentVisibleSurahId)');
    }

    _lastScrollPosition = _scrollController.position.pixels;
  }

  Future<void> _restoreScrollPosition() async {
    if (!mounted) return;

    // Wait for the scroll controller to be attached
    if (!_scrollController.hasClients) {
      // If scroll controller isn't attached yet, wait a bit and try again
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        _restoreScrollPosition();
      }
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // Restore scroll position
      final savedPosition = prefs.getDouble(_scrollPositionKey);

      // Restore surah information - we won't use this directly since it might be inaccurate
      final savedSurahId = prefs.getInt(_lastSurahIdKey);

      if (savedPosition != null && savedPosition > 0) {
        // Show restoring indicator
        setState(() {
          _isRestoringPosition = true;
        });

        // Make sure we have enough content loaded before scrolling
        await _ensureContentLoadedForPosition(savedPosition);

        // Jump to the saved position with a small delay to ensure rendering is complete
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _scrollController.hasClients) {
            // Make sure we don't scroll beyond the available content
            final maxScroll = _scrollController.position.maxScrollExtent;
            final targetPosition =
                savedPosition > maxScroll ? maxScroll : savedPosition;

            _scrollController.jumpTo(targetPosition);
            developer.log(
                'Restored scroll position: $targetPosition (original: $savedPosition)');

            // Let the scrolling settle, then update the surah info
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                // Update visible surah directly based on new position
                _directUpdateVisibleSurah();
                setState(() {
                  _isRestoringPosition = false;
                });
              }
            });
          } else {
            setState(() {
              _isRestoringPosition = false;
            });
          }
        });
      }
    } catch (e) {
      developer.log('Error restoring scroll position: $e');
      if (mounted) {
        setState(() {
          _isRestoringPosition = false;
        });
      }
    }
  }

  // Remove the snackbar method since we're not using it anymore

  // Make sure we have enough content loaded for the target position
  Future<void> _ensureContentLoadedForPosition(double targetPosition) async {
    // If we're near the max scroll position and there's more content to load
    while (_scrollController.hasClients &&
        _hasMoreSurahs &&
        !_isLoadingMore &&
        targetPosition > _scrollController.position.maxScrollExtent - 500) {
      // Load more content so we can scroll to the right position
      await _loadMoreSurahs();

      // Small delay to allow the UI to update
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  void _checkMemoryUsage() {
    // In a production app, you might use a plugin to measure memory usage
    // If memory usage is high, you could clear some caches or reduce the loaded data

    // Schedule the next memory check
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _checkMemoryUsage();
      }
    });
  }

  void _directUpdateVisibleSurah() {
    // If auto-updates are disabled, exit immediately
    if (_disableAutoUpdates || _surahs.isEmpty) return;

    // Get current scroll position
    final double scrollPosition = _scrollController.position.pixels;

    // Fixed multiplier based on character count to pixel height
    const double charHeightMultiplier = 0.9;
    const double baseHeight = 200; // Header + spacing
    const double bismillahHeight = 70;

    // Track cumulative height
    double cumulativeHeight = 0;
    int visibleSurahIndex = 0;

    // Find which surah contains the current scroll position
    for (int i = 0; i < _surahs.length; i++) {
      final surah = _surahs[i];

      // Calculate this surah's height
      double surahHeight = baseHeight;

      // Add bismillah height if needed
      if (surah.id != 9 && surah.id != 1) {
        surahHeight += bismillahHeight;
      }

      // Add text content height
      surahHeight += surah.content.length * charHeightMultiplier;

      // If scroll position is within this surah's height range, this is our visible surah
      if (scrollPosition >= cumulativeHeight &&
          scrollPosition < (cumulativeHeight + surahHeight)) {
        visibleSurahIndex = i;
        break;
      }

      // Otherwise add to cumulative height and continue
      cumulativeHeight += surahHeight;
    }

    // If we didn't find a match (could happen at very end of scroll), use last surah
    if (visibleSurahIndex >= _surahs.length) {
      visibleSurahIndex = _surahs.length - 1;
    }

    // Use scroll percentage as fallback for long scrolls
    if (visibleSurahIndex == 0 && scrollPosition > 1000) {
      final double maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll > 0) {
        double scrollPercentage = scrollPosition / maxScroll;
        int approximateIndex = (scrollPercentage * _surahs.length).floor();

        // Ensure index is within valid range
        if (approximateIndex > 0 && approximateIndex < _surahs.length) {
          visibleSurahIndex = approximateIndex;
        }
      }
    }

    // Update the UI if the visible surah has changed
    final Surah visibleSurah = _surahs[visibleSurahIndex];
    if (_currentVisibleSurahId != visibleSurah.id) {
      setState(() {
        _currentVisibleSurah = visibleSurah.nameEn;
        _currentVisibleSurahId = visibleSurah.id;

        // Log the update for debugging
        developer.log(
            'Auto-updated to surah: ${visibleSurah.nameEn} (ID: ${visibleSurah.id}) '
            'at position $scrollPosition out of total ${_scrollController.position.maxScrollExtent}');
      });
    }
  }

  Future<void> _loadQuranData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Reset pagination variables
      _currentPage = 0;
      _hasMoreSurahs = true;
      _surahs.clear();

      await _loadMoreSurahs();
    } catch (e) {
      developer.log('Error loading Quran data: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadMoreSurahs() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // Calculate start and end indices for pagination
      final startIndex = _currentPage * _pageSize + 1; // 1-based index
      final endIndex = startIndex + _pageSize - 1;

      // Load surahs for current page
      final surahs = await _quranService.getSurahsByRange(startIndex, endIndex);

      setState(() {
        if (surahs.isEmpty) {
          _hasMoreSurahs = false;
        } else {
          _surahs.addAll(surahs);
          _currentPage++;

          // Update current visible surah if it's the first load
          if (_surahs.isNotEmpty && _currentVisibleSurahId == null) {
            _currentVisibleSurah = _surahs[0].nameEn;
            _currentVisibleSurahId = _surahs[0].id;
          }
        }

        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      developer.log('Error loading more surahs: $e');
      setState(() {
        _isLoadingMore = false;
        if (_surahs.isEmpty) {
          _isLoading = false;
          _errorMessage = e.toString();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF3E7146),
        elevation: 0,
        title: GestureDetector(
          onTap: () => _showCurrentPositionInfo(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Al-Quran',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!_isLoading && _surahs.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Show a lock icon when auto-update is disabled
                    if (_disableAutoUpdates)
                      GestureDetector(
                        // Allow unlocking by tapping the lock icon
                        onTap: () {
                          setState(() {
                            _disableAutoUpdates = false;
                            developer.log('Manually unlocked surah selection');
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.only(right: 4.0),
                          child: Icon(
                            Icons.lock,
                            size: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    Text(
                      _currentVisibleSurah,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: _disableAutoUpdates
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.hexagon_outlined, color: Colors.white),
            onPressed: () => _showOptionsMenu(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content
          _isLoading && _surahs.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? _buildErrorWidget()
                  : _buildQuranContent(),

          // Overlay for position restoration
          if (_isRestoringPosition)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.teal.shade700),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Restoring your last position...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      persistentFooterButtons: [
        Container(
          width: MediaQuery.of(context).size.width,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 8,
            children: [
              _buildFooterButton(context, Icons.headphones, 'Listen', 0),
              _buildFooterButton(context, Icons.article_outlined, 'Tafseer', 1),
              _buildFooterButton(context, Icons.sync_alt, 'Display', 2),
              _buildFooterButton(context, Icons.search, 'Search', 3),
              _buildFooterButton(context, Icons.redo, 'Jump to', 4),
              _buildFooterButton(context, Icons.menu, 'Scroll', 5),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuranContent() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView.separated(
        controller: _scrollController,
        itemCount: _surahs.length + (_hasMoreSurahs ? 1 : 0),
        // Clear separator between items
        separatorBuilder: (context, index) => Divider(
          height: 30,
          color: Colors.teal.withOpacity(0.1),
          thickness: 1,
        ),
        itemBuilder: (context, index) {
          // Show loading indicator at the end
          if (index == _surahs.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(
                  color: Colors.teal,
                ),
              ),
            );
          }

          final surah = _surahs[index];

          // Add an onTap action to force update the title if needed
          return GestureDetector(
            onTap: () {
              // Force update title when tapping a surah and disable auto-updates for a period
              setState(() {
                _currentVisibleSurah = surah.nameEn;
                _currentVisibleSurahId = surah.id;

                // Disable auto-updates temporarily
                _disableAutoUpdates = true;

                // Log the manual override
                developer.log(
                    'Manual selection of surah: ${surah.nameEn} (ID: ${surah.id})');
              });

              // Re-enable auto-updates after 10 seconds
              Future.delayed(const Duration(seconds: 10), () {
                if (mounted) {
                  setState(() {
                    _disableAutoUpdates = false;
                    developer
                        .log('Re-enabled auto updates after manual selection');
                  });
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Surah header - more prominent for visibility
                  Container(
                    margin: const EdgeInsets.only(top: 5, bottom: 15),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.teal.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Surah number
                        Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.teal.shade300),
                          ),
                          child: Center(
                            child: Text(
                              '${surah.id}',
                              style: TextStyle(
                                color: Colors.teal.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),

                        // Surah name
                        Column(
                          children: [
                            Text(
                              surah.nameEn,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              textDirection: TextDirection.ltr,
                            ),
                            Text(
                              'Juz ${_getJuzForSurah(surah.id)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                              textDirection: TextDirection.ltr,
                            ),
                          ],
                        ),

                        // Arabic name
                        Text(
                          surah.nameAr,
                          style: const TextStyle(
                            fontSize: 22,
                            fontFamily: 'Indopak',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bismillah for all surahs except At-Tawbah (9)
                  if (surah.id != 9 && surah.id != 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 15, top: 5),
                      child: Text(
                        _bismillah,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Indopak',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Surah content
                  Text(
                    // Remove Bismillah if it's already at the beginning of content
                    surah.content.startsWith(_bismillah) && surah.id != 1
                        ? surah.content.substring(_bismillah.length).trim()
                        : surah.content,
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
          );
        },
      ),
    );
  }

  String _getJuzForSurah(int surahId) {
    // A simplified mapping of surahs to juz
    // In a real app, you'd have a more complete mapping
    final juzMapping = {
      1: 1,
      2: 1,
      3: 3,
      4: 4,
      5: 6,
      6: 7,
      7: 8,
      8: 9,
      9: 10,
      10: 11,
      11: 12,
      12: 12,
      13: 13,
      14: 13,
      15: 14,
      16: 14,
      17: 15,
      18: 15,
      19: 16,
      20: 16,
      21: 17,
      22: 17,
      23: 18,
      24: 18,
      25: 18,
      26: 19,
      27: 19,
      28: 20,
      29: 20,
      30: 21,
      31: 21,
      32: 21,
      33: 21,
      34: 22,
      35: 22,
      36: 22,
      37: 23,
      38: 23,
      39: 23,
      40: 24,
      41: 24,
      42: 25,
      43: 25,
      44: 25,
      45: 25,
      46: 26,
      47: 26,
      48: 26,
      49: 26,
      50: 26,
      51: 27,
      52: 27,
      53: 27,
      54: 27,
      55: 27,
      56: 27,
      57: 27,
      58: 28,
      59: 28,
      60: 28,
      61: 28,
      62: 28,
      63: 28,
      64: 28,
      65: 28,
      66: 28,
      67: 29,
      68: 29,
      69: 29,
      70: 29,
      71: 29,
      72: 29,
      73: 29,
      74: 29,
      75: 29,
      76: 29,
      77: 29,
      78: 30,
      79: 30,
      80: 30,
      81: 30,
      82: 30,
      83: 30,
      84: 30,
      85: 30,
      86: 30,
      87: 30,
      88: 30,
      89: 30,
      90: 30,
      91: 30,
      92: 30,
      93: 30,
      94: 30,
      95: 30,
      96: 30,
      97: 30,
      98: 30,
      99: 30,
      100: 30,
      101: 30,
      102: 30,
      103: 30,
      104: 30,
      105: 30,
      106: 30,
      107: 30,
      108: 30,
      109: 30,
      110: 30,
      111: 30,
      112: 30,
      113: 30,
      114: 30
    };

    return juzMapping[surahId]?.toString() ?? '1';
  }

  Widget _buildErrorWidget() {
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
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadQuranData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3E7146),
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

  // Helper method to log surah positions for debugging
  void _logSurahPositions() {
    developer.log('-------- Surah Position Debug Info --------');
    developer.log('Total surahs loaded: ${_surahs.length}');
    developer
        .log('Current scroll position: ${_scrollController.position.pixels}');
    developer.log(
        'Viewport height: ${_scrollController.position.viewportDimension}');
    developer.log(
        'Max scroll extent: ${_scrollController.position.maxScrollExtent}');
    developer.log(
        'Current visible surah: $_currentVisibleSurah (ID: $_currentVisibleSurahId)');

    // Calculate and log estimated positions
    double cumulativeHeight = 0;
    for (int i = 0; i < min(_surahs.length, 10); i++) {
      // Log first 10 surahs
      final contentLength = _surahs[i].content.length;
      final estimatedHeight = 200 + (contentLength * 0.5);
      cumulativeHeight += estimatedHeight;
      developer.log(
          'Surah ${_surahs[i].id} (${_surahs[i].nameEn}): estimated start at ${cumulativeHeight - estimatedHeight}px, end at ${cumulativeHeight}px');
    }
    developer.log('------------------------------------------');
  }

  void _showCurrentPositionInfo(BuildContext context) {
    // Debug log positions
    _logSurahPositions();

    if (_currentVisibleSurahId == null || _surahs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No position information available yet'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Find the current surah
    final currentSurah = _surahs.firstWhere(
      (s) => s.id == _currentVisibleSurahId,
      orElse: () => _surahs.first,
    );

    // Calculate progress
    const int totalSurahs = 114; // Total in the Quran
    final double progress = currentSurah.id / totalSurahs;
    final int progressPercent = (progress * 100).round();

    // Get juz number
    final String juzNumber = _getJuzForSurah(currentSurah.id);

    // Show a modal with the position info
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            const Text(
              'Current Reading Position',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Surah info
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${currentSurah.id}',
                      style: TextStyle(
                        color: Colors.teal.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentSurah.nameEn,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Juz $juzNumber',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  currentSurah.nameAr,
                  style: const TextStyle(
                    fontSize: 20,
                    fontFamily: 'Indopak',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal.shade300),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$progressPercent% of Quran',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.bookmark_add),
                  label: const Text('Bookmark'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade100,
                    foregroundColor: Colors.teal.shade800,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Bookmark feature coming soon'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade100,
                    foregroundColor: Colors.blue.shade800,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Share feature coming soon'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Options',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Options list
            _buildOptionItem(
              context,
              Icons.text_fields,
              'Text Size',
              'Adjust the font size of the Quran text',
              () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Text size adjustment coming soon'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),

            _buildOptionItem(
              context,
              Icons.palette,
              'Theme',
              'Change app theme and colors',
              () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Theme settings coming soon'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),

            _buildOptionItem(
              context,
              Icons.language,
              'Translation',
              'Show/hide translation',
              () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Translation options coming soon'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),

            _buildOptionItem(
              context,
              Icons.format_list_numbered,
              'Verse Numbers',
              'Show/hide verse numbers',
              () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Verse number options coming soon'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(
        icon,
        color: Colors.teal,
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12),
      ),
      onTap: onTap,
    );
  }

  Widget _buildFooterButton(
    BuildContext context,
    IconData icon,
    String label,
    int index,
  ) {
    return InkWell(
      onTap: () => _handleBottomNavTap(context, index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 24,
            color: Colors.black87,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  void _handleBottomNavTap(BuildContext context, int index) {
    final String feature;
    switch (index) {
      case 0:
        feature = 'Audio recitation';
        break;
      case 1:
        feature = 'Tafseer view';
        break;
      case 2:
        feature = 'Display options';
        break;
      case 3:
        feature = 'Search functionality';
        break;
      case 4:
        feature = 'Jump to specific surah/ayah';
        break;
      case 5:
        feature = 'Scroll options';
        break;
      default:
        feature = 'This feature';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature will be implemented soon'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Add this new method
  void _setupPeriodicSync() {
    // Periodically check and update the current visible surah
    // This ensures the header stays in sync, even during rapid scrolling
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        // Only perform update if auto-updates are enabled
        if (!_disableAutoUpdates) {
          _directUpdateVisibleSurah();
        }
        _setupPeriodicSync();
      }
    });
  }

  // Simpler helper method to check if an item is visible in the viewport
  bool _isVisibleInViewport(BuildContext context, int index) {
    if (!_scrollController.hasClients) return false;

    // Get current scroll position
    final double scrollPosition = _scrollController.position.pixels;
    // Get viewport height
    final double viewportHeight = _scrollController.position.viewportDimension;

    // Estimate item position
    double estimatedItemPosition = 0;
    for (int i = 0; i < index; i++) {
      if (i >= _surahs.length) break;

      // Calculate approximate height for each previous surah
      final surah = _surahs[i];
      final contentLength = surah.content.length;

      // Base header height
      double itemHeight = 150;

      // Add bismillah height if applicable
      if (surah.id != 9 && surah.id != 1) {
        itemHeight += 50;
      }

      // Add content height based on text length
      itemHeight += contentLength * 0.7;

      estimatedItemPosition += itemHeight;
    }

    // Check if item is in visible area (with some buffer for better detection)
    bool isVisible = estimatedItemPosition >= scrollPosition - 200 &&
        estimatedItemPosition <= scrollPosition + (viewportHeight * 0.3);

    return isVisible;
  }
}

// Optimized surah widget that memoizes expensive computations
class _SurahWidget extends StatelessWidget {
  final Surah surah;
  final String bismillah;
  final String juzNumber;

  // Cache the processed content to avoid recomputing it
  late final String _processedContent;

  _SurahWidget({
    Key? key,
    required this.surah,
    required this.bismillah,
    required this.juzNumber,
  }) : super(key: key) {
    // Pre-process content only once during initialization
    _processedContent = _preprocessContent();
  }

  // Process the content once to avoid doing it during build
  String _preprocessContent() {
    if (surah.content.startsWith(bismillah) && surah.id != 1) {
      return surah.content.substring(bismillah.length).trim();
    }
    return surah.content;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Surah header optimized with const widgets where possible
          _buildSurahHeader(),

          // Bismillah - only show for appropriate surahs
          if (surah.id != 9 && surah.id != 1) const SizedBox(height: 10),

          if (surah.id != 9 && surah.id != 1)
            Text(
              bismillah,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Indopak',
              ),
              textAlign: TextAlign.center,
            ),

          const SizedBox(height: 10),

          // Use efficient text rendering for the main content
          _buildSurahContent(),
        ],
      ),
    );
  }

  // Extract header to a separate method
  Widget _buildSurahHeader() {
    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Surah number in circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${surah.id}',
                style: TextStyle(
                  color: Colors.teal.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Center - Surah name with RTL support
          Column(
            children: [
              Text(
                surah.nameEn,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textDirection: TextDirection.ltr,
              ),
              Text(
                'Juz $juzNumber',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textDirection: TextDirection.ltr,
              ),
            ],
          ),

          // Arabic name
          Text(
            surah.nameAr,
            style: const TextStyle(
              fontSize: 20,
              fontFamily: 'Indopak',
            ),
          ),
        ],
      ),
    );
  }

  // Extract content to a separate method
  Widget _buildSurahContent() {
    // Use a more efficient text rendering approach with optimized text performance
    return ExcludeSemantics(
      child: RichText(
        text: TextSpan(
          text: _processedContent,
          style: const TextStyle(
            fontSize: 20,
            height: 1.8,
            fontFamily: 'Indopak',
            color: Colors.black,
          ),
        ),
        textAlign: TextAlign.justify, // Prevent text scaling which can be expensive
        softWrap: true,
        overflow: TextOverflow.clip,
        textDirection: TextDirection.rtl, textScaler: TextScaler.linear(1.0),
      ),
    );
  }
}

// Extract bottom navigation bar to a separate widget
class _QuranBottomNavBar extends StatelessWidget {
  const _QuranBottomNavBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Optimized for persistentFooterButtons
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavBarItem(context, Icons.headphones, 'Listen', 0),
          _buildNavBarItem(context, Icons.article_outlined, 'Tafseer', 1),
          _buildNavBarItem(context, Icons.sync_alt, 'Display', 2),
          _buildNavBarItem(context, Icons.search, 'Search', 3),
          _buildNavBarItem(context, Icons.redo, 'Jump to', 4),
          _buildNavBarItem(context, Icons.menu, 'Scroll', 5),
        ],
      ),
    );
  }

  Widget _buildNavBarItem(
      BuildContext context, IconData icon, String label, int index) {
    return InkWell(
      onTap: () => _handleBottomNavTap(context, index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 24,
            color: Colors.black87,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  void _handleBottomNavTap(BuildContext context, int index) {
    final String feature;
    switch (index) {
      case 0:
        feature = 'Audio recitation';
        break;
      case 1:
        feature = 'Tafseer view';
        break;
      case 2:
        feature = 'Display options';
        break;
      case 3:
        feature = 'Search functionality';
        break;
      case 4:
        feature = 'Jump to specific surah/ayah';
        break;
      case 5:
        feature = 'Scroll options';
        break;
      default:
        feature = 'This feature';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature will be implemented soon'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
