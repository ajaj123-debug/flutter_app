import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

class PrayerTimingsScreen extends StatefulWidget {
  const PrayerTimingsScreen({super.key});

  @override
  State<PrayerTimingsScreen> createState() => _PrayerTimingsScreenState();
}

class _PrayerTimingsScreenState extends State<PrayerTimingsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _prayerTimes;
  Map<String, dynamic>? _weeklyPrayerTimes;
  String _selectedCity = '';
  String _selectedCountry = '';
  String _hijriDate = '';
  int _selectedDayIndex = 0;
  List<DateTime> _weekDays = [];
  Map<String, String> _prayerNames = {
    'Fajr': 'Dawn',
    'Sunrise': 'Sunrise',
    'Dhuhr': 'Noon',
    'Asr': 'Afternoon',
    'Maghrib': 'Sunset',
    'Isha': 'Night',
  };

  @override
  void initState() {
    super.initState();
    _initializeWeekDays();
    _loadSelectedLocation();
    _loadPrayerTimesFromLocal().then((loaded) {
      if (!loaded || _selectedDayIndex > 0) {
        _fetchPrayerTimesForWeek();
      }
    });

    // Make status bar transparent
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ));
  }

  void _initializeWeekDays() {
    final now = DateTime.now();
    _weekDays = List.generate(
        7, (index) => DateTime(now.year, now.month, now.day + index));
  }

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
      } else {
        setState(() {
          _selectedCity = 'Ambala';
          _selectedCountry = 'India';
        });
      }
    } catch (e) {
      Logger.error('Error loading location', e);
      setState(() {
        _selectedCity = 'Ambala';
        _selectedCountry = 'India';
      });
    }
  }

  Future<bool> _loadPrayerTimesFromLocal() async {
    Logger.debug('Attempting to load prayer times from local storage');
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPrayerTimes = prefs.getString('prayer_times');

      if (savedPrayerTimes != null) {
        final savedHijriDate = prefs.getString('hijri_date') ?? '';

        Logger.debug(
            'Found saved prayer times for $_selectedCity, $_selectedCountry');

        setState(() {
          _prayerTimes = jsonDecode(savedPrayerTimes);
          _hijriDate = savedHijriDate;
          _isLoading = false;
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

  Future<void> _fetchPrayerTimesForWeek() async {
    Logger.debug('Fetching prayer times for week');
    setState(() {
      _isLoading = true;
    });

    try {
      // Initialize weekly prayer times if null
      if (_weeklyPrayerTimes == null) {
        _weeklyPrayerTimes = {};
      }

      for (int i = 0; i < _weekDays.length; i++) {
        final date = _weekDays[i];
        final dateStr = DateFormat('dd-MM-yyyy').format(date);

        // Check if we already have data for this date
        if (_weeklyPrayerTimes!.containsKey(dateStr)) {
          continue;
        }

        // Use selected city and country with the date
        final url =
            'https://api.aladhan.com/v1/timingsByCity/${date.day}-${date.month}-${date.year}?city=$_selectedCity&country=$_selectedCountry&method=1';
        Logger.debug('API URL for $dateStr: $url');

        final response = await http.get(Uri.parse(url));
        Logger.debug('API response status code: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          // Check if the response has the expected structure
          if (data['data'] != null && data['data']['timings'] != null) {
            // Add to weekly prayer times
            _weeklyPrayerTimes![dateStr] = data['data']['timings'];

            // Update hijri date for the current day
            if (i == _selectedDayIndex) {
              try {
                final hijriDateData = data['data']['date']['hijri'];
                _hijriDate =
                    '${hijriDateData['day']} ${hijriDateData['month']['en']} ${hijriDateData['year']}';
              } catch (e) {
                Logger.warning('Error parsing Hijri date: $e');
                _hijriDate = DateFormat('dd MMMM yyyy').format(date);
              }
            }
          }
        } else {
          Logger.error(
              'API returned error status code: ${response.statusCode}, body: ${response.body}');
        }
      }

      // Update the current day's prayer times
      final currentDateStr =
          DateFormat('dd-MM-yyyy').format(_weekDays[_selectedDayIndex]);
      if (_weeklyPrayerTimes!.containsKey(currentDateStr)) {
        setState(() {
          _prayerTimes = _weeklyPrayerTimes![currentDateStr];
          _isLoading = false;
        });
      } else {
        // If API fails, try to use today's cached data
        if (_selectedDayIndex == 0) {
          await _loadPrayerTimesFromLocal();
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      Logger.error('Error fetching weekly prayer times: $e');
      setState(() {
        _isLoading = false;
      });

      // Show error snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Unable to fetch prayer times. Please try again later.'),
          backgroundColor: Colors.red.shade700,
        ));
      }
    }
  }

  void _selectDate(int index) {
    setState(() {
      _selectedDayIndex = index;
      final selectedDateStr = DateFormat('dd-MM-yyyy').format(_weekDays[index]);

      if (_weeklyPrayerTimes != null &&
          _weeklyPrayerTimes!.containsKey(selectedDateStr)) {
        _prayerTimes = _weeklyPrayerTimes![selectedDateStr];
      } else {
        _prayerTimes = null;
        _isLoading = true;
        // Fetch if not available
        _fetchPrayerTimesForWeek();
      }
    });
  }

  // Helper to format prayer time
  String _formatPrayerTime(String timeStr) {
    try {
      final dateTime = DateFormat('HH:mm').parse(timeStr);
      return DateFormat('hh:mm a').format(dateTime).toUpperCase();
    } catch (e) {
      return timeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56.0),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: Colors.white.withOpacity(0.7),
              elevation: 0,
              title: Text(
                'Prayer Timings',
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.grey.shade800),
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.calendar_month, color: Colors.grey.shade800),
                  onPressed: () {
                    // TODO: Calendar view
                  },
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: Colors.grey.shade800),
                  onPressed: _fetchPrayerTimesForWeek,
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPrayerTimesForWeek,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 70,
                    bottom: 16,
                    left: 16,
                    right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location and date info
                    Container(
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
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: Colors.teal.shade600,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$_selectedCity, $_selectedCountry',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: Colors.teal.shade600,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _hijriDate.isEmpty
                                    ? DateFormat('dd MMMM yyyy')
                                        .format(_weekDays[_selectedDayIndex])
                                    : _hijriDate,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Week days selector
                    const SizedBox(height: 16),
                    Container(
                      height: 90,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: 7,
                        itemBuilder: (context, index) {
                          final date = _weekDays[index];
                          final isSelected = index == _selectedDayIndex;
                          final isToday = index == 0;

                          return GestureDetector(
                            onTap: () => _selectDate(index),
                            child: Container(
                              width: 70,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.teal.shade500
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.shade200,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    DateFormat('EEE')
                                        .format(date)
                                        .toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.white.withOpacity(0.3)
                                          : isToday
                                              ? Colors.teal.shade50
                                              : null,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      DateFormat('d').format(date),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? Colors.white
                                            : isToday
                                                ? Colors.teal.shade700
                                                : Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                  if (isToday && !isSelected)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: Colors.teal.shade400,
                                        shape: BoxShape.circle,
                                      ),
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
              ),
            ),

            // Prayer times list
            _isLoading || _prayerTimes == null
                ? SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        // Display only the main six prayer times
                        final prayers = [
                          'Fajr',
                          'Sunrise',
                          'Dhuhr',
                          'Asr',
                          'Maghrib',
                          'Isha'
                        ];
                        if (index >= prayers.length) return null;

                        final prayerName = prayers[index];
                        final prayerTime = _prayerTimes![prayerName];

                        return _buildPrayerTimeCard(
                          prayerName,
                          prayerTime,
                          index,
                        );
                      },
                      childCount: 6,
                    ),
                  ),

            // Bottom padding
            SliverToBoxAdapter(
              child: SizedBox(height: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerTimeCard(String prayerName, String prayerTime, int index) {
    // Define colors for each prayer
    final colors = [
      Colors.amber, // Fajr
      Colors.orange, // Sunrise
      Colors.blue, // Dhuhr
      Colors.amber, // Asr
      Colors.deepOrange, // Maghrib
      Colors.indigo, // Isha
    ];

    // Define icons for each prayer
    final icons = [
      Icons.wb_twilight, // Fajr
      Icons.wb_sunny_outlined, // Sunrise
      Icons.wb_sunny, // Dhuhr
      Icons.wb_sunny_outlined, // Asr
      Icons.nights_stay_outlined, // Maghrib
      Icons.nightlight_round, // Isha
    ];

    // Check if this prayer is the next one for today
    bool isNextPrayer = false;
    if (_selectedDayIndex == 0) {
      final now = DateTime.now();
      final prayerDateTime = _convertToDateTime(prayerTime);

      // Check if the prayer time is still upcoming today
      isNextPrayer = prayerDateTime.isAfter(now);

      // If we're checking and this is the first upcoming prayer, mark it
      if (isNextPrayer) {
        for (int i = 0; i < index; i++) {
          final priorPrayerName =
              ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'][i];
          final priorPrayerTime = _prayerTimes![priorPrayerName];
          final priorPrayerDateTime = _convertToDateTime(priorPrayerTime);

          if (priorPrayerDateTime.isAfter(now)) {
            isNextPrayer = false;
            break;
          }
        }
      }
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        border: isNextPrayer
            ? Border.all(color: colors[index].shade300, width: 2)
            : null,
      ),
      child: Stack(
        children: [
          if (isNextPrayer)
            Positioned(
              right: 16,
              top: 16,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colors[index].shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_forward,
                      size: 12,
                      color: colors[index].shade700,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'NEXT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colors[index].shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors[index].shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icons[index],
                        color: colors[index].shade600,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prayerName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _prayerNames[prayerName] ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  _formatPrayerTime(prayerTime),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors[index].shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DateTime _convertToDateTime(String timeStr) {
    final now = DateTime.now();
    final timeParts = timeStr.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    return DateTime(
        _weekDays[_selectedDayIndex].year,
        _weekDays[_selectedDayIndex].month,
        _weekDays[_selectedDayIndex].day,
        hour,
        minute);
  }
}
