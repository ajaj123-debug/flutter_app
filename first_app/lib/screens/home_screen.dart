import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import '../widgets/feature_grid.dart';
import '../widgets/bottom_nav_bar.dart';
import 'mosque_screen.dart';
import 'settings_screen.dart';
import 'prayer_timings_screen.dart';
import '../services/google_sheets_service.dart';
import '../utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _opacity = 0.0;
  double _navBarOpacity = 0.0;
  final ScrollController _scrollController = ScrollController();
  int _currentIndex = 0;
  String? _mosqueName;
  bool _isLoadingMosqueName = true;
  final GoogleSheetsService _sheetsService = GoogleSheetsService();

  // Flag to track if images are preloaded
  bool _imagesPreloaded = false;

  // Prayer times variables
  bool _isLoadingPrayerTimes = true;
  Map<String, dynamic>? _prayerTimes;
  String _selectedCity = 'Ambala';
  String _selectedCountry = 'India';
  String _nextPrayer = '';
  String _nextPrayerTime = '';
  Duration _timeUntilNextPrayer = Duration.zero;
  String _hijriDate = '';

  // Location search variables
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> _searchResults = [];
  bool _isSearching = false;
  bool _isLoadingResults = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadMosqueName();
    _loadSelectedLocation();

    // First try to load from local storage
    _loadPrayerTimesFromLocal().then((loaded) {
      // Then fetch from API to get the latest data
      _fetchPrayerTimes();
    });

    // Make status bar transparent
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ));

    // Setup timer to update countdown
    _startCountdownTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Preload images here instead of initState
    if (!_imagesPreloaded) {
      _preloadImages();
      _imagesPreloaded = true;
    }
  }

  void _startCountdownTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _updateNextPrayer();
        _startCountdownTimer();
      }
    });
  }

  Future<void> _fetchPrayerTimes() async {
    Logger.debug('Fetching prayer times for $_selectedCity, $_selectedCountry');

    setState(() {
      if (_prayerTimes == null) {
        _isLoadingPrayerTimes = true;
      }
    });

    try {
      // Use selected city and country
      final url =
          'https://api.aladhan.com/v1/timingsByCity?city=$_selectedCity&country=$_selectedCountry&method=1';
      Logger.debug('API URL: $url');

      final response = await http.get(Uri.parse(url));
      Logger.debug('API response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Print the entire response for debugging
        Logger.debug('API raw response: ${response.body}');

        final data = jsonDecode(response.body);

        // Check if the response has the expected structure
        if (data['data'] != null && data['data']['timings'] != null) {
          Logger.debug('Successfully parsed prayer times from API response');

          setState(() {
            _prayerTimes = data['data']['timings'];

            // Handling potentially missing fields more safely
            try {
              final hijriDateData = data['data']['date']['hijri'];
              _hijriDate =
                  '${hijriDateData['day']} ${hijriDateData['month']['en']} ${hijriDateData['year']}';
            } catch (e) {
              Logger.warning('Error parsing Hijri date: $e');
              _hijriDate = DateFormat('dd MMMM yyyy').format(DateTime.now());
            }

            _isLoadingPrayerTimes = false;
            _updateNextPrayer();
          });

          // Save the fetched data to local storage
          _savePrayerTimesToLocal();
          Logger.debug('Saved prayer times to local storage');
        } else {
          Logger.error('Unexpected API response format: ${response.body}');
          throw Exception('Unexpected API response format');
        }
      } else {
        Logger.error(
            'API returned error status code: ${response.statusCode}, body: ${response.body}');
        _handlePrayerTimesError(
            'API returned status code: ${response.statusCode}');
      }
    } catch (e) {
      Logger.error('Error fetching prayer times: $e');
      _handlePrayerTimesError(e.toString());
    }
  }

  void _updateNextPrayer() {
    if (_prayerTimes == null) return;

    final now = DateTime.now();
    final prayers = {
      'Fajr': _convertToDateTime(_prayerTimes!['Fajr']),
      'Dhuhr': _convertToDateTime(_prayerTimes!['Dhuhr']),
      'Asr': _convertToDateTime(_prayerTimes!['Asr']),
      'Maghrib': _convertToDateTime(_prayerTimes!['Maghrib']),
      'Isha': _convertToDateTime(_prayerTimes!['Isha']),
    };

    String nextPrayer = '';
    DateTime? nextTime;

    prayers.forEach((name, time) {
      if (time.isAfter(now) && (nextTime == null || time.isBefore(nextTime!))) {
        nextPrayer = name;
        nextTime = time;
      }
    });

    // If no next prayer today, first prayer tomorrow is Fajr
    if (nextPrayer.isEmpty) {
      nextPrayer = 'Fajr';
      nextTime = prayers['Fajr']!.add(const Duration(days: 1));
    }

    // Format time for display (12-hour format)
    final formattedTime = DateFormat('hh:mm a').format(nextTime!).toUpperCase();

    // Calculate time until next prayer
    final timeUntil = nextTime!.difference(now);

    setState(() {
      _nextPrayer = nextPrayer;
      _nextPrayerTime = formattedTime;
      _timeUntilNextPrayer = timeUntil;
    });
  }

  DateTime _convertToDateTime(String timeStr) {
    final now = DateTime.now();
    final timeParts = timeStr.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  String _formatPrayerTime(String? timeStr) {
    if (timeStr == null) return '--:--';
    return timeStr;
  }

  String _formatTimeRemaining() {
    if (_timeUntilNextPrayer.isNegative) return '00:00:00';

    final hours = _timeUntilNextPrayer.inHours.toString().padLeft(2, '0');
    final minutes =
        (_timeUntilNextPrayer.inMinutes % 60).toString().padLeft(2, '0');
    final seconds =
        (_timeUntilNextPrayer.inSeconds % 60).toString().padLeft(2, '0');

    return '$hours:$minutes:$seconds';
  }

  Future<void> _loadMosqueName() async {
    if (!mounted) return;

    setState(() {
      _isLoadingMosqueName = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString('mosque_code');

      // First check if we have a saved mosque name
      final savedName = prefs.getString('mosque_name');
      final lastFetchTime = prefs.getInt('mosque_name_last_fetch') ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      // Check if we have a valid saved name and it was fetched within the last 7 days
      final shouldRefresh = savedName == null ||
          savedName == 'Not Connected' ||
          (currentTime - lastFetchTime) > (7 * 24 * 60 * 60 * 1000);

      if (savedCode == null) {
        setState(() {
          _mosqueName = 'Not Connected';
          _isLoadingMosqueName = false;
        });
        return;
      }

      // If we have a valid saved name and don't need to refresh, use it
      if (savedName != null && !shouldRefresh) {
        setState(() {
          _mosqueName = savedName;
          _isLoadingMosqueName = false;
        });
        return;
      }

      // Otherwise fetch from Google Sheets
      try {
        await _sheetsService.initializeSheetsApi();
        await _sheetsService.setSpreadsheetId(savedCode);
        final mosqueName = await _sheetsService.getMosqueName();

        if (mosqueName != null) {
          // Save the new name and update the fetch timestamp
          await prefs.setString('mosque_name', mosqueName);
          await prefs.setInt('mosque_name_last_fetch', currentTime);

          if (mounted) {
            setState(() {
              _mosqueName = mosqueName;
              _isLoadingMosqueName = false;
            });
          }
        } else {
          // If fetch fails but we have a saved name, use that
          if (savedName != null) {
            setState(() {
              _mosqueName = savedName;
              _isLoadingMosqueName = false;
            });
          } else {
            setState(() {
              _mosqueName = 'Not Connected';
              _isLoadingMosqueName = false;
            });
          }
        }
      } catch (e) {
        Logger.error('Error fetching from Google Sheets: $e');
        // If sheets fetch fails but we have a saved name, use that
        if (savedName != null) {
          setState(() {
            _mosqueName = savedName;
            _isLoadingMosqueName = false;
          });
        } else {
          setState(() {
            _mosqueName = 'Not Connected';
            _isLoadingMosqueName = false;
          });
        }
      }
    } catch (e) {
      Logger.error('Error in _loadMosqueName: $e');
      if (mounted) {
        setState(() {
          _mosqueName = 'Not Connected';
          _isLoadingMosqueName = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    const double fadeStart = 10.0;
    const double fadeEnd = 100.0;

    if (_scrollController.offset <= fadeStart) {
      setState(() {
        _opacity = 0.0;
        _navBarOpacity = 0.0;
      });
    } else if (_scrollController.offset < fadeEnd) {
      final newOpacity =
          (_scrollController.offset - fadeStart) / (fadeEnd - fadeStart);
      setState(() {
        _opacity = newOpacity;
        _navBarOpacity =
            newOpacity * 0.9; // Slightly less opaque for bottom nav
      });
    } else {
      setState(() {
        _opacity = 1.0;
        _navBarOpacity = 0.9; // Slightly less opaque for bottom nav
      });
    }
  }

  void _onNavTap(int index) {
    // If Quran tab is selected (index 2), navigate to the continuous screen
    if (index == 2) {
      Navigator.pushNamed(context, '/quran_continuous');
      return;
    }

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    // Get the current day number to rotate background images daily
    final int currentDay = DateTime.now().day;
    final String prayerBgImage = _getPrayerBackgroundImage(currentDay);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      extendBodyBehindAppBar: true,
      appBar: _currentIndex == 1 || _currentIndex == 2 || _currentIndex == 3
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(56.0),
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color:
                          Colors.white.withValues(alpha: _opacity > 0.1 ? 0.7 : 0.0),
                      boxShadow: _opacity > 0.1
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: _opacity * 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey
                              .withOpacity(_opacity > 0.1 ? 0.2 : 0.0),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Menu button or back button
                            IconButton(
                              icon: const Icon(Icons.menu, size: 20),
                              padding: const EdgeInsets.all(8.0),
                              constraints: const BoxConstraints(
                                  minWidth: 36, minHeight: 36),
                              color: Colors.black87,
                              onPressed: () {
                                // Open drawer or menu
                              },
                            ),

                            // Location text
                            GestureDetector(
                              onTap: _showLocationBottomSheet,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _opacity > 0.1
                                      ? Colors.teal.withOpacity(0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _opacity > 0.1
                                        ? Colors.teal.withOpacity(0.2)
                                        : Colors.transparent,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: Colors.teal.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$_selectedCity, $_selectedCountry',
                                      style: TextStyle(
                                        color: Colors.teal.shade800,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 16,
                                      color: Colors.teal.shade600,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Notification icon
                            IconButton(
                              icon: const Icon(Icons.notifications_outlined,
                                  size: 20),
                              padding: const EdgeInsets.all(8.0),
                              constraints: const BoxConstraints(
                                  minWidth: 36, minHeight: 36),
                              color: Colors.black87,
                              onPressed: () {
                                // Show notifications
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
      body: Stack(
        children: [
          // Content based on selected tab
          _currentIndex == 1
              ? MosqueScreen(updateNavBarOpacity: (opacity) {
                  setState(() {
                    _navBarOpacity = opacity;
                  });
                })
              : _currentIndex == 3
                  ? SettingsScreen(updateNavBarOpacity: (opacity) {
                      setState(() {
                        _navBarOpacity = opacity;
                      });
                    })
                  : Positioned.fill(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          await _loadMosqueName();
                          await _fetchPrayerTimes();
                        },
                        displacement: 80 + MediaQuery.of(context).padding.top,
                        edgeOffset: 16,
                        color: Colors.teal,
                        backgroundColor: Colors.white,
                        child: NotificationListener<
                            OverscrollIndicatorNotification>(
                          onNotification:
                              (OverscrollIndicatorNotification overscroll) {
                            overscroll
                                .disallowIndicator(); // Disable the glow effect
                            return true;
                          },
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(
                                top: 8), // Add small top padding
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Add space before the Prayer Hero Section
                                SizedBox(
                                    height: statusBarHeight +
                                        56), // Adjusted to match app bar height

                                // Prayer Times Hero Section
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.only(
                                      top: 24,
                                      left: 16,
                                      right: 16,
                                      bottom: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      image: DecorationImage(
                                        image: ResizeImage(
                                          AssetImage(prayerBgImage),
                                          width: 800,
                                          height: 800,
                                        ),
                                        fit: BoxFit.cover,
                                        colorFilter: ColorFilter.mode(
                                          Colors.black
                                              .withAlpha(26), // 0.1 * 255 = 26
                                          BlendMode.darken,
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.1),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(height: 0),
                                        // Location and date
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            GestureDetector(
                                              onTap: _showLocationBottomSheet,
                                              child: Row(
                                                children: [
                                                  Text(
                                                    '$_selectedCity, $_selectedCountry',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  const Icon(
                                                    Icons.keyboard_arrow_down,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _isLoadingPrayerTimes
                                              ? 'Loading...'
                                              : _hijriDate,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 12),

                                        // Next prayer info
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(
                                                sigmaX: 10, sigmaY: 10),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 16),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.white
                                                        .withValues(alpha: 0.15),
                                                    Colors.white
                                                        .withValues(alpha: 0.05),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.2),
                                                    blurRadius: 15,
                                                    offset: const Offset(0, 5),
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                children: [
                                                  const Text(
                                                    'Next',
                                                    style: TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _isLoadingPrayerTimes
                                                        ? 'Loading...'
                                                        : _nextPrayer,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 32,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _isLoadingPrayerTimes
                                                        ? '--:--'
                                                        : _nextPrayerTime,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 28,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    _isLoadingPrayerTimes
                                                        ? 'Loading...'
                                                        : 'Starts in ${_formatTimeRemaining()}',
                                                    style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),

                                        // View All Prayers button
                                        const SizedBox(height: 12),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(30),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(
                                                sigmaX: 8, sigmaY: 8),
                                            child: GestureDetector(
                                              onTap: () {
                                                Navigator.pushNamed(
                                                  context,
                                                  '/prayer_timings',
                                                );
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 6),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Colors.white
                                                          .withValues(alpha: 0.2),
                                                      Colors.white
                                                          .withValues(alpha: 0.1),
                                                    ],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(30),
                                                ),
                                                child: const Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .calendar_month_outlined,
                                                      color: Colors.white,
                                                      size: 16,
                                                    ),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      'View All Prayers',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Action buttons - horizontal scrollable
                                        const SizedBox(height: 8),
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          physics:
                                              const BouncingScrollPhysics(),
                                          child: Row(
                                            children: [
                                              _buildActionButton(
                                                icon: Icons.explore,
                                                label: 'Qibla 82°',
                                                onTap: () {},
                                              ),
                                              const SizedBox(width: 8),
                                              _buildActionButton(
                                                icon: Icons.event_note,
                                                label: 'Log Prayer',
                                                onTap: () {},
                                              ),
                                              const SizedBox(width: 8),
                                              _buildActionButton(
                                                icon: Icons.share,
                                                label: 'Share Prayer Times',
                                                onTap: () {},
                                              ),
                                              const SizedBox(width: 8),
                                              _buildActionButton(
                                                icon: Icons.notification_add,
                                                label: 'Prayer Notifications',
                                                onTap: () {},
                                              ),
                                              const SizedBox(width: 8),
                                              _buildActionButton(
                                                icon: Icons.calculate,
                                                label: 'Prayer Calculator',
                                                onTap: () {},
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Current and next prayer mini-cards
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: _buildPrayerTimeMiniCards(),
                                ),

                                // Mosque Connection Section
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.shade200,
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.shade50,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.mosque,
                                            color: Colors.teal.shade600,
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Connected Mosque',
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _isLoadingMosqueName
                                                    ? 'Loading...'
                                                    : (_mosqueName ??
                                                        'Not Connected'),
                                                style: const TextStyle(
                                                  color: Colors.black87,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () {
                                            // Navigate to mosque screen to change mosque
                                            setState(() {
                                              _currentIndex = 1;
                                            });
                                          },
                                          icon: const Icon(
                                            Icons.edit,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Explore Section
                                const SizedBox(height: 12),
                                const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 0),
                                  child: Text(
                                    'EXPLORE',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // Features Grid
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: FeatureGrid(),
                                ),

                                const SizedBox(
                                    height: 80), // Space for bottom nav
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

          // Bottom navigation bar with blur effect
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.white.withValues(alpha: _navBarOpacity),
                  child: BottomNavBar(
                    currentIndex: _currentIndex,
                    onTap: _onNavTap,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.2),
                  Colors.white.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrayerTimeMiniCards() {
    if (_isLoadingPrayerTimes && _prayerTimes == null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
              ),
              const SizedBox(height: 12),
              Text(
                'Loading prayer times...',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Format the prayer times for display
    Map<String, String> formattedTimes = {};
    if (_prayerTimes != null) {
      _prayerTimes!.forEach((prayer, time) {
        if (time is String) {
          try {
            final dateTime = DateFormat('HH:mm').parse(time);
            formattedTimes[prayer] =
                DateFormat('hh:mm a').format(dateTime).toUpperCase();
          } catch (e) {
            formattedTimes[prayer] = time;
          }
        }
      });
    }

    // Get the current time and prayer
    final now = DateTime.now();

    // Calculate remaining times
    final currentPrayerEndingIn = _formatTimeRemaining();

    // Determine which prayers to show in the upcoming section
    List<Map<String, dynamic>> upcomingPrayers =
        _getUpcomingPrayers(formattedTimes);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with prayer times and view all button
          Padding(
            padding:
                const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 18,
                      color: Colors.teal.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Prayer Timings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to detailed prayer times screen
                    Navigator.pushNamed(
                      context,
                      '/prayer_timings',
                    );
                  },
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'View All',
                    style: TextStyle(
                      color: Colors.teal.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Divider(color: Colors.grey.shade200, height: 1),

          // Current and Next Prayer Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Current Prayer
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.mosque_outlined,
                              size: 14,
                              color: Colors.teal.shade800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'NOW',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: _nextPrayer == 'Fajr' && now.hour > 12
                                  ? 'Isha'
                                  : _nextPrayer == 'Dhuhr'
                                      ? 'Fajr'
                                      : _nextPrayer == 'Asr'
                                          ? 'Dhuhr'
                                          : _nextPrayer == 'Maghrib'
                                              ? 'Asr'
                                              : _nextPrayer == 'Isha'
                                                  ? 'Maghrib'
                                                  : 'Before Fajr',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            TextSpan(
                              text: ' • ',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: _nextPrayer == 'Fajr' && now.hour > 12
                                  ? formattedTimes['Isha'] ?? '--:--'
                                  : _nextPrayer == 'Dhuhr'
                                      ? formattedTimes['Fajr'] ?? '--:--'
                                      : _nextPrayer == 'Asr'
                                          ? formattedTimes['Dhuhr'] ?? '--:--'
                                          : _nextPrayer == 'Maghrib'
                                              ? formattedTimes['Asr'] ?? '--:--'
                                              : _nextPrayer == 'Isha'
                                                  ? formattedTimes['Maghrib'] ??
                                                      '--:--'
                                                  : '--:--',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.blueGrey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ending in $currentPrayerEndingIn',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Vertical Divider
                Container(
                  height: 60,
                  width: 1,
                  color: Colors.grey.shade200,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),

                // Next Prayer
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.arrow_forward,
                              size: 14,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'NEXT',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: _nextPrayer,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            TextSpan(
                              text: ' • ',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: _nextPrayerTime,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.blueGrey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Starting in ${_formatTimeRemaining()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Divider(color: Colors.grey.shade200, height: 1),

          // Upcoming Prayers in a horizontal scrollable row
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UPCOMING',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      // Dynamic prayers based on current time
                      ...upcomingPrayers
                          .map((prayer) => _buildPrayerChip(
                                prayer['name'],
                                prayer['time'],
                                prayer['day'],
                                prayer['icon'],
                                prayer['color'],
                              ))
                          .toList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerChip(String name, String time, String day, IconData icon,
      MaterialColor color) {
    return Container(
      margin: const EdgeInsets.only(right: 10, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color.shade700,
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: color.shade800,
                      ),
                    ),
                    TextSpan(
                      text: ' • ',
                      style: TextStyle(
                        fontSize: 13,
                        color: color.shade300,
                      ),
                    ),
                    TextSpan(
                      text: time,
                      style: TextStyle(
                        fontSize: 13,
                        color: color.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                day,
                style: TextStyle(
                  fontSize: 11,
                  color: color.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to get the upcoming prayers in correct order
  List<Map<String, dynamic>> _getUpcomingPrayers(
      Map<String, String> formattedTimes) {
    final prayers = [
      'Fajr',
      'Sunrise',
      'Dhuhr',
      'Asr',
      'Maghrib',
      'Isha',
      'Qiyam',
    ];

    final prayerIcons = {
      'Fajr': Icons.wb_twilight,
      'Sunrise': Icons.wb_sunny_outlined,
      'Dhuhr': Icons.wb_sunny,
      'Asr': Icons.wb_sunny_outlined,
      'Maghrib': Icons.nights_stay_outlined,
      'Isha': Icons.nightlight_round,
      'Qiyam': Icons.nightlight_round,
    };

    final prayerColors = {
      'Fajr': Colors.amber,
      'Sunrise': Colors.orange,
      'Dhuhr': Colors.blue,
      'Asr': Colors.amber,
      'Maghrib': Colors.deepOrange,
      'Isha': Colors.indigo,
      'Qiyam': Colors.purple,
    };

    // Find the index of the next prayer
    int nextPrayerIndex = prayers.indexOf(_nextPrayer);
    if (nextPrayerIndex == -1) nextPrayerIndex = 0;

    // We want to show prayers after the next prayer
    List<Map<String, dynamic>> upcomingPrayers = [];

    // Start with the prayer after "next"
    int startIndex = (nextPrayerIndex + 1) % prayers.length;

    // Add today's remaining prayers
    for (int i = startIndex; i < prayers.length; i++) {
      String prayerName = prayers[i];
      // Skip Qiyam in the first loop as it's for later tonight
      if (i == prayers.length - 1) continue;

      upcomingPrayers.add({
        'name': prayerName,
        'time': formattedTimes[prayerName] ?? '--:--',
        'day': 'Today',
        'icon': prayerIcons[prayerName]!,
        'color': prayerColors[prayerName]!,
      });
    }

    // Add "Later Tonight" for Qiyam
    upcomingPrayers.add({
      'name': 'Qiyam',
      'time': '12:20 am',
      'day': 'Later Tonight',
      'icon': Icons.nightlight_round,
      'color': Colors.indigo,
    });

    // Add tomorrow's prayers up to the next prayer
    for (int i = 0; i <= nextPrayerIndex; i++) {
      String prayerName = prayers[i];
      upcomingPrayers.add({
        'name': prayerName,
        'time': formattedTimes[prayerName] ?? '--:--',
        'day': 'Tomorrow',
        'icon': prayerIcons[prayerName]!,
        'color': prayerColors[prayerName]!,
      });
    }

    return upcomingPrayers;
  }

  // Add a new method to save prayer times to local storage
  Future<void> _savePrayerTimesToLocal() async {
    if (_prayerTimes == null) {
      Logger.debug('Not saving prayer times to local storage as data is null');
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save prayer times, city and date information
      final prayerTimesJson = jsonEncode(_prayerTimes);
      await prefs.setString('prayer_times', prayerTimesJson);
      await prefs.setString('prayer_times_date', DateTime.now().toString());
      await prefs.setString('prayer_times_city', _selectedCity);
      await prefs.setString('prayer_times_country', _selectedCountry);
      await prefs.setString('hijri_date', _hijriDate);

      Logger.debug(
          'Successfully saved prayer times to local storage: $prayerTimesJson');
    } catch (e) {
      Logger.error('Error saving prayer times', e);
    }
  }

  // Add a method to load prayer times from local storage
  Future<bool> _loadPrayerTimesFromLocal() async {
    Logger.debug('Attempting to load prayer times from local storage');
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPrayerTimes = prefs.getString('prayer_times');

      if (savedPrayerTimes != null) {
        final savedCity = prefs.getString('prayer_times_city');
        final savedCountry = prefs.getString('prayer_times_country');
        final savedHijriDate = prefs.getString('hijri_date') ?? '';

        Logger.debug(
            'Found saved prayer times for $savedCity, $savedCountry: $savedPrayerTimes');

        setState(() {
          _prayerTimes = jsonDecode(savedPrayerTimes);
          _hijriDate = savedHijriDate;
          _isLoadingPrayerTimes = false;
          _updateNextPrayer();
        });

        return true;
      } else {
        Logger.debug('No saved prayer times found in local storage');
        return false;
      }
    } catch (e) {
      Logger.error('Error loading prayer times from local storage', e);
      return false;
    }
  }

  // Add method to load selected location from shared preferences
  Future<void> _loadSelectedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCity = prefs.getString('selected_city');
      final savedCountry = prefs.getString('selected_country');

      if (savedCity != null && savedCountry != null) {
        setState(() {
          _selectedCity = savedCity;
          _selectedCountry = savedCountry;
        });
      }
    } catch (e) {
      Logger.error('Error loading location', e);
    }
  }

  // Add method to save selected location to shared preferences
  Future<void> _saveSelectedLocation(String city, String country) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_city', city);
      await prefs.setString('selected_country', country);
    } catch (e) {
      Logger.error('Error saving location', e);
    }
  }

  // Method to search for locations
  Future<void> _searchLocation(String query, String country) async {
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    Logger.debug('Searching for location: "$query" in country: "$country"');
    setState(() {
      _isSearching = true;
      _isLoadingResults = true;
    });

    try {
      // First try to find in predefined list (for faster results)
      final List<Map<String, String>> results = [];

      // International cities data
      final cities = _getCitiesList();

      Logger.debug('Searching through ${cities.length} predefined cities');
      for (var city in cities) {
        // Filter by both query and country
        if (city['city']!.toLowerCase().contains(query.toLowerCase()) &&
            (country == 'All Countries' || city['country'] == country)) {
          results.add({
            'city': city['city']!,
            'country': city['country']!,
          });
        }
      }

      Logger.debug('Found ${results.length} matches in predefined cities');

      // If no results in predefined list, let the user create a custom entry
      if (results.isEmpty) {
        // Add the user's search as a custom city
        results.add({
          'city': query,
          'country': country,
          'custom': 'true', // Mark as custom
        });
        Logger.debug('Added custom city entry: "$query" in $country');
      }

      setState(() {
        _searchResults = results;
        _isLoadingResults = false;
      });
    } catch (e) {
      Logger.error('Error searching locations', e);
      setState(() {
        _isLoadingResults = false;
        // Still add the user's search as a custom city even if there's an error
        _searchResults = [
          {
            'city': query,
            'country': country,
            'custom': 'true', // Mark as custom
          }
        ];
      });
    }
  }

  // Get a list of cities from various countries
  List<Map<String, String>> _getCitiesList() {
    return [
      // India
      {'city': 'New Delhi', 'country': 'India'},
      {'city': 'Mumbai', 'country': 'India'},
      {'city': 'Kolkata', 'country': 'India'},
      {'city': 'Chennai', 'country': 'India'},
      {'city': 'Bangalore', 'country': 'India'},
      {'city': 'Hyderabad', 'country': 'India'},
      {'city': 'Ahmedabad', 'country': 'India'},
      {'city': 'Pune', 'country': 'India'},
      {'city': 'Jaipur', 'country': 'India'},
      {'city': 'Lucknow', 'country': 'India'},
      {'city': 'Patna', 'country': 'India'},
      {'city': 'Chapra', 'country': 'India'},
      {'city': 'Ambala', 'country': 'India'},
      {'city': 'Mullana', 'country': 'India'},

      // Saudi Arabia
      {'city': 'Riyadh', 'country': 'Saudi Arabia'},
      {'city': 'Jeddah', 'country': 'Saudi Arabia'},
      {'city': 'Mecca', 'country': 'Saudi Arabia'},
      {'city': 'Medina', 'country': 'Saudi Arabia'},
      {'city': 'Dammam', 'country': 'Saudi Arabia'},

      // United Arab Emirates
      {'city': 'Dubai', 'country': 'UAE'},
      {'city': 'Abu Dhabi', 'country': 'UAE'},
      {'city': 'Sharjah', 'country': 'UAE'},
      {'city': 'Ajman', 'country': 'UAE'},

      // Pakistan
      {'city': 'Karachi', 'country': 'Pakistan'},
      {'city': 'Lahore', 'country': 'Pakistan'},
      {'city': 'Islamabad', 'country': 'Pakistan'},
      {'city': 'Faisalabad', 'country': 'Pakistan'},

      // Bangladesh
      {'city': 'Dhaka', 'country': 'Bangladesh'},
      {'city': 'Chittagong', 'country': 'Bangladesh'},
      {'city': 'Khulna', 'country': 'Bangladesh'},

      // Malaysia
      {'city': 'Kuala Lumpur', 'country': 'Malaysia'},
      {'city': 'Penang', 'country': 'Malaysia'},
      {'city': 'Johor Bahru', 'country': 'Malaysia'},

      // Indonesia
      {'city': 'Jakarta', 'country': 'Indonesia'},
      {'city': 'Surabaya', 'country': 'Indonesia'},
      {'city': 'Bandung', 'country': 'Indonesia'},

      // Turkey
      {'city': 'Istanbul', 'country': 'Turkey'},
      {'city': 'Ankara', 'country': 'Turkey'},
      {'city': 'Izmir', 'country': 'Turkey'},

      // Egypt
      {'city': 'Cairo', 'country': 'Egypt'},
      {'city': 'Alexandria', 'country': 'Egypt'},
      {'city': 'Giza', 'country': 'Egypt'},

      // US
      {'city': 'New York', 'country': 'USA'},
      {'city': 'Los Angeles', 'country': 'USA'},
      {'city': 'Chicago', 'country': 'USA'},
      {'city': 'Houston', 'country': 'USA'},

      // UK
      {'city': 'London', 'country': 'UK'},
      {'city': 'Manchester', 'country': 'UK'},
      {'city': 'Birmingham', 'country': 'UK'},

      // Canada
      {'city': 'Toronto', 'country': 'Canada'},
      {'city': 'Vancouver', 'country': 'Canada'},
      {'city': 'Montreal', 'country': 'Canada'},
    ];
  }

  // Get a list of countries for the dropdown
  List<String> _getCountryList() {
    return [
      'All Countries',
      'India',
      'Saudi Arabia',
      'UAE',
      'Pakistan',
      'Bangladesh',
      'Malaysia',
      'Indonesia',
      'Turkey',
      'Egypt',
      'USA',
      'UK',
      'Canada',
    ];
  }

  // Update method to select location and fetch prayer times
  Future<void> _selectLocation(String city, String country,
      {bool isCustom = false}) async {
    Logger.info('Selected location: $city, $country');
    setState(() {
      _selectedCity = city;
      _selectedCountry = country;
      _isLoadingPrayerTimes = true;
    });

    // Save the selected location
    await _saveSelectedLocation(city, country);
    Logger.info('Saved location to preferences: $city, $country');

    // Close the bottom sheet
    Navigator.of(context).pop();

    // Fetch prayer times for the new location
    await _fetchPrayerTimes();
  }

  // Method to show location selection bottom sheet
  void _showLocationBottomSheet() {
    // Country selection state
    String selectedSearchCountry = _selectedCountry;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(25),
                      topRight: Radius.circular(25),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Search Location',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Country selection dropdown
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedSearchCountry,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down),
                            elevation: 16,
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontSize: 16,
                            ),
                            onChanged: (String? value) {
                              if (value != null) {
                                setModalState(() {
                                  selectedSearchCountry = value;
                                  Logger.info(
                                      'Changed search country to $value');
                                });
                              }
                            },
                            items: _getCountryList()
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ),
                      ),

                      // City search field
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search for city...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setModalState(() {
                                        _searchController.clear();
                                        _searchResults = [];
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onChanged: (value) {
                            setModalState(() {
                              _searchLocation(value, selectedSearchCountry);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Current location button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.my_location),
                    label: const Text("Use current location"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: BorderSide(color: Colors.blue.shade300),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () async {
                      // This would be implemented with actual geolocation in a production app
                      setModalState(() {
                        _searchController.text = "Detecting...";
                      });

                      await Future.delayed(const Duration(seconds: 1));

                      setModalState(() {
                        _searchController.text = "New Delhi";
                        selectedSearchCountry = "India";
                        _searchLocation("New Delhi", "India");
                      });
                    },
                  ),
                ),

                Divider(color: Colors.grey.shade200),

                // Search results
                Expanded(
                  child: _isLoadingResults
                      ? const Center(child: CircularProgressIndicator())
                      : _searchResults.isEmpty &&
                              _searchController.text.isNotEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.location_off,
                                    size: 60,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No locations found',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _searchResults.length,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemBuilder: (context, index) {
                                final result = _searchResults[index];
                                final isCustom = result['custom'] == 'true';

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 16,
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: isCustom
                                        ? Colors.orange.shade50
                                        : Colors.teal.shade50,
                                    child: Icon(
                                      isCustom
                                          ? Icons.add_location_alt
                                          : Icons.location_city,
                                      color: isCustom
                                          ? Colors.orange.shade700
                                          : Colors.teal.shade700,
                                    ),
                                  ),
                                  title: Text(
                                    result['city']!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(isCustom
                                      ? 'Add custom location'
                                      : result['country']!),
                                  trailing: _selectedCity == result['city'] &&
                                          _selectedCountry == result['country']
                                      ? const Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                        )
                                      : null,
                                  onTap: () {
                                    _selectLocation(
                                      result['city']!,
                                      result['country']!,
                                      isCustom: isCustom,
                                    );
                                  },
                                );
                              },
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Preload images to fix rotation issues
  Future<void> _preloadImages() async {
    for (int i = 1; i <= 4; i++) {
      final String assetPath = 'assets/images/prayerbg_img_$i.webp';
      await precacheImage(AssetImage(assetPath), context);
    }
  }

  // Helper method to get the prayer background image based on day of month
  String _getPrayerBackgroundImage(int day) {
    // Use modulo to cycle through the 4 images
    int imageIndex = (day % 4) + 1;
    return 'assets/images/prayerbg_img_$imageIndex.webp';
  }

  void _handlePrayerTimesError(String errorMessage) {
    Logger.error('Handling prayer times error: $errorMessage');

    setState(() {
      _isLoadingPrayerTimes = false;
    });

    // Try to load from cache first
    _loadPrayerTimesFromLocal().then((loaded) {
      if (!loaded) {
        Logger.info('No cached prayer times available');
      }
    });

    // Show error snackbar
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Unable to fetch prayer times for $_selectedCity. Showing cached data if available.'),
      backgroundColor: Colors.red.shade700,
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'Try Again',
        textColor: Colors.white,
        onPressed: () {
          Logger.info('Retrying prayer times fetch from snackbar action');
          _fetchPrayerTimes();
        },
      ),
    ));
  }
}
