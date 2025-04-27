import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logging/logging.dart' as logging;
import '../services/google_sheets_service.dart';
import '../models/transaction_model.dart';
import '../models/deduction_model.dart';
import '../models/summary_model.dart';
import '../services/ad_service.dart';
import '../utils/logger.dart' as app_logger;

// Initialize logger
final _logger = logging.Logger('MosqueScreen');

class MosqueScreen extends StatefulWidget {
  final Function(double)? updateNavBarOpacity;

  const MosqueScreen({super.key, this.updateNavBarOpacity});

  @override
  State<MosqueScreen> createState() => _MosqueScreenState();
}

class _MosqueScreenState extends State<MosqueScreen> {
  bool _isCodeSet = false;
  String? _mosqueCode;
  String? _mosqueName;
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = true;
  bool _isInitializing = false;
  double _navBarOpacity = 0.0;
  final ScrollController _scrollController = ScrollController();
  final GoogleSheetsService _sheetsService = GoogleSheetsService();
  bool _isMosqueNameStored = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    if (!mounted) return;

    setState(() {
      _isInitializing = true;
    });

    try {
      await _loadMosqueCode();
      await _checkMosqueNameStorage();

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isInitializing = false;
      });
    } catch (e) {
      _logger.severe('Error initializing app: $e');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isInitializing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error initializing app: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _checkMosqueNameStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final storedMosqueName = prefs.getString('mosque_name_permanent');
    setState(() {
      _isMosqueNameStored =
          storedMosqueName != null && storedMosqueName.isNotEmpty;
    });
  }

  Future<void> _loadMosqueCode() async {
    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString('mosque_code');
      final savedName = prefs.getString('mosque_name');

      if (code != null && savedName != null) {
        setState(() {
          _mosqueCode = code;
          _mosqueName = savedName;
          _isCodeSet = true;
        });
      }
    } catch (e) {
      _logger.severe('Error loading mosque code: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    // Dispose of any loaded ads when the widget is removed
    AdService().disposeRewardedAd();
    super.dispose();
  }

  void _scrollListener() {
    // Calculate opacity based on scroll position
    // Start becoming opaque after scrolling 20 pixels
    // Fully opaque by 120 pixels
    const double fadeStart = 20.0;
    const double fadeEnd = 120.0;

    double newOpacity = 0.0;

    if (_scrollController.offset <= fadeStart) {
      newOpacity = 0.0;
    } else if (_scrollController.offset < fadeEnd) {
      // Calculate a value between 0.0 and 1.0
      newOpacity =
          (_scrollController.offset - fadeStart) / (fadeEnd - fadeStart);
    } else {
      newOpacity = 1.0;
    }

    setState(() {
      _navBarOpacity = newOpacity;
    });

    // Call the callback if it exists
    if (widget.updateNavBarOpacity != null) {
      widget.updateNavBarOpacity!(newOpacity);
    }
  }

  Future<void> _saveMosqueCode(String code) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Clean and validate the mosque code
      final cleanedCode = code.trim().replaceAll(RegExp(r'[^a-zA-Z0-9\-]'), '');

      if (cleanedCode.isEmpty) {
        throw Exception('Please enter a valid mosque code');
      }

      // Initialize sheets service only when needed
      await _sheetsService.initializeSheetsApi();
      _sheetsService.setSpreadsheetId(cleanedCode);
      final mosqueName = await _sheetsService.getMosqueName();

      if (mosqueName != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('mosque_code', cleanedCode);
        await prefs.setString('mosque_name', mosqueName);

        if (mounted) {
          setState(() {
            _mosqueCode = cleanedCode;
            _mosqueName = mosqueName;
            _isCodeSet = true;
            _isMosqueNameStored = true;
          });
        }
      }
    } catch (e) {
      _logger.severe('Error saving mosque code: $e');
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.grey.shade50,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        color: Colors.orange,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Connection Error",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Content
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    e.toString().replaceAll('Exception: ', ''),
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Action button
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "OK",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Reset the mosque code (for changing mosques)
  Future<void> _resetMosqueCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mosque_code');
    await prefs.remove('mosque_name');
    await _sheetsService.clearStoredMosqueName();

    setState(() {
      _mosqueCode = null;
      _mosqueName = null;
      _isCodeSet = false;
      _isMosqueNameStored = false;
    });
  }

  // Check and show ad for specific feature, returns true if navigation should proceed
  Future<bool> _checkAndShowFeatureAd(String featureKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today =
          DateTime.now().toString().substring(0, 10); // YYYY-MM-DD format
      final lastAdWatchDate = prefs.getString('last_ad_watch_date_$featureKey');

      // If ad already watched today for this specific feature, proceed without showing ad
      if (lastAdWatchDate == today) {
        app_logger.Logger.info(
            'User already watched ad today for $featureKey, proceeding with navigation');
        return true;
      }

      // Check if an ad is available
      final adService = AdService();

      if (adService.isRewardedAdReady()) {
        // Show a dialog informing the user about the compulsory ad
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Colors.grey.shade50,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.video_library,
                          color: Colors.blue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "Feature Access",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Content
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Watch a short ad to access the ${_getFeatureName(featureKey)} feature. You\'ll only need to watch one ad per day for this feature.',
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Action button
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "OK",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        final bool rewardEarned = await adService.showRewardedAd(context);

        if (rewardEarned) {
          app_logger.Logger.info(
              'User earned reward for $featureKey, saving watch date and proceeding');
          // Save the date when ad was watched for this specific feature
          await prefs.setString('last_ad_watch_date_$featureKey', today);
          return true;
        } else {
          app_logger.Logger.info(
              'User did not earn reward for $featureKey, cancelling navigation');
          if (!mounted) return false;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please watch the ad completely to continue'),
              backgroundColor: Colors.orange,
            ),
          );
          return false;
        }
      } else {
        // If no ad is available but user hasn't watched one today for this feature,
        // load an ad for next time but let them proceed this time
        app_logger.Logger.info(
            'No ad available for $featureKey, proceeding with navigation');
        adService.loadRewardedAd();
        return true;
      }
    } catch (e) {
      app_logger.Logger.error(
          'Error checking and showing ad for $featureKey', e);
      return true; // Let them proceed on error
    }
  }

  // Helper method to get user-friendly feature names
  String _getFeatureName(String featureKey) {
    switch (featureKey) {
      case 'summary':
        return 'Summary';
      case 'transactions':
        return 'Transactions';
      case 'deductions':
        return 'Expenses & Deductions';
      case 'payer_transactions':
        return 'View My Transactions';
      default:
        return 'Selected';
    }
  }

  // Navigate to summary screen
  void _navigateToSummary() async {
    if (await _checkAndShowFeatureAd('summary')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SummaryScreen(),
        ),
      );
    }
  }

  // Navigate to transactions screen
  void _navigateToTransactions() async {
    if (await _checkAndShowFeatureAd('transactions')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const TransactionsScreen(),
        ),
      );
    }
  }

  // Navigate to deductions screen
  void _navigateToDeductions() async {
    if (await _checkAndShowFeatureAd('deductions')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const DeductionsScreen(),
        ),
      );
    }
  }

  // Navigate to payer transactions screen
  void _navigateToPayerTransactions() async {
    if (await _checkAndShowFeatureAd('payer_transactions')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PayerTransactionsScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the height of the status bar for proper spacing
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      extendBodyBehindAppBar: true,
      body: _isInitializing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Initializing app...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            )
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    // Main content
                    SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      controller: _scrollController,
                      child: Column(
                        children: [
                          SizedBox(height: statusBarHeight),
                          _isCodeSet
                              ? _buildMosqueOverview()
                              : _buildConnectToMosque(),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                    // Removed the translucent top bar
                  ],
                ),
    );
  }

  // UI for when mosque code is not set
  Widget _buildConnectToMosque() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Mosque illustration
          Container(
            height: 200,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 30),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SvgPicture.asset(
                'assets/images/mosque.svg',
                fit: BoxFit.contain,
                placeholderBuilder: (BuildContext context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          ),

          const Text(
            "Enter the mosque code provided by your mosque manager to view fund details, transactions, and more.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.black87,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 30),

          // Mosque code input field
          TextField(
            controller: _codeController,
            decoration: InputDecoration(
              labelText: "Mosque Code",
              hintText: "Enter your mosque's unique code",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              prefixIcon: const Icon(Icons.mosque),
            ),
          ),

          const SizedBox(height: 20),

          // Connect button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                if (_codeController.text.isNotEmpty) {
                  _saveMosqueCode(_codeController.text);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                "Connect",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Help text
          const Text(
            "Don't have the code? Ask your mosque committee.",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 20),

          // Information button
          TextButton.icon(
            onPressed: () {
              _showHelpDialog();
            },
            icon: const Icon(Icons.help_outline, color: Colors.teal),
            label: const Text(
              "What is a Mosque Code?",
              style: TextStyle(color: Colors.teal),
            ),
          ),
        ],
      ),
    );
  }

  // UI for when mosque code is set
  Widget _buildMosqueOverview() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mosque connection info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.teal.shade600,
                  Colors.teal.shade800,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.mosque,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Connected to:",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () {
                        _showResetConfirmDialog();
                      },
                      icon: const Icon(Icons.edit, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _mosqueName ?? "Loading...",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Code: $_mosqueCode",
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Section title
          const Text(
            "Explore",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          // Overview card
          _buildActionCard(
            title: "View Summary",
            description: "See overview of mosque funds and activities",
            icon: Icons.dashboard,
            onTap: _navigateToSummary,
          ),

          _buildActionCard(
            title: "View Transactions",
            description: "Browse all financial transactions",
            icon: Icons.receipt_long,
            onTap: _navigateToTransactions,
          ),

          _buildActionCard(
            title: "Expenses & Deductions",
            description: "View donations or record of expenses",
            icon: Icons.account_balance_wallet,
            onTap: _navigateToDeductions,
          ),

          _buildActionCard(
            title: "View My Transactions",
            description: "View transaction history by payer",
            icon: Icons.people,
            onTap: _navigateToPayerTransactions,
          ),

          // Events section
          const SizedBox(height: 30),
          const Text(
            "Upcoming Events",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 15),

          _buildEventCard(
            title: "Friday Jama'at",
            date: "Friday, 12:30 PM",
            description: "Speaker: Mosque's Imam",
          ),

          _buildEventCard(
            title: "Eid Prayer",
            date: "7:30 AM",
            description: "Followed by community breakfast",
          ),
        ],
      ),
    );
  }

  // Action card widget
  Widget _buildActionCard({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.teal,
                size: 24,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.teal,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // Event card widget
  Widget _buildEventCard({
    required String title,
    required String date,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  date,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.teal,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // Help dialog
  void _showHelpDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: Colors.teal,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "What is a Mosque Code?",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Content
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
                child: const Text(
                  "A Mosque Code is a unique identifier provided by your mosque management. "
                  "It allows this app to securely access and display information specific to your mosque, "
                  "such as financial data, events, and other community information.\n\n"
                  "To get your mosque's code, please contact your mosque administrator or committee member.",
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Action button
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Got it",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Reset confirmation dialog
  void _showResetConfirmDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Change Mosque",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Content
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
                child: const Text(
                  "Are you sure you want to disconnect from the current mosque? "
                  "You'll need to enter a new mosque code to reconnect.",
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Action buttons
              Row(
                children: [
                  // Cancel button
                  Expanded(
                    child: SizedBox(
                      height: 45,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.teal,
                          side: const BorderSide(color: Colors.teal),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Disconnect button
                  Expanded(
                    child: SizedBox(
                      height: 45,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _resetMosqueCode();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Disconnect",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final GoogleSheetsService _sheetsService = GoogleSheetsService();
  bool _isLoading = true;
  Summary? _summary;
  DateTime? _lastUpdated;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load last update time
      final lastUpdatedStr = prefs.getString('summary_last_updated');
      if (lastUpdatedStr != null) {
        _lastUpdated = DateTime.parse(lastUpdatedStr);
      }

      // Load summary from storage
      final summaryJson = prefs.getString('summary');
      if (summaryJson != null) {
        setState(() {
          _summary = Summary.fromMap(json.decode(summaryJson));
          _isLoading = false;
        });
      }

      // Only try to fetch new data if we have internet
      if (await _checkInternetConnection()) {
        if (_summary == null ||
            _lastUpdated == null ||
            DateTime.now().difference(_lastUpdated!) >
                const Duration(hours: 1)) {
          await _fetchAndStoreData();
        }
      } else if (mounted) {
        setState(() {
          _isOffline = true;
          _isLoading = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are offline. Showing last saved data.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      _logger.severe('Error loading from storage: $e');
      setState(() {
        _isLoading = false;
        _isOffline = true;
      });
    }
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<void> _fetchAndStoreData() async {
    try {
      // Check internet connection first
      if (!await _checkInternetConnection()) {
        if (mounted) {
          setState(() {
            _isOffline = true;
            _isLoading = false;
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No internet connection. Cannot refresh data.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isLoading = true;
          _isOffline = false;
        });
      }

      // Initialize the sheets service
      await _sheetsService.initializeSheetsApi();

      // Load mosque code from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final mosqueCode = prefs.getString('mosque_code');

      if (mosqueCode == null) {
        throw Exception('No mosque code found');
      }

      _sheetsService.setSpreadsheetId(mosqueCode);

      // Fetch summary data
      final summaryData = await _sheetsService.getSummary();

      // Convert to Summary object
      if (summaryData.isNotEmpty && summaryData[0].length >= 7 && mounted) {
        try {
          final summaryRow = summaryData[0];
          final newSummary = Summary(
            totalIncome: _parseDouble(summaryRow[0]),
            totalSavings: _parseDouble(summaryRow[1]),
            currentMonthSavings: _parseDouble(summaryRow[2]),
            currentMonthIncome: _parseDouble(summaryRow[3]),
            totalDeductions: _parseDouble(summaryRow[4]),
            currentMonthDeductions: _parseDouble(summaryRow[5]),
            previousMonthSavings: _parseDouble(summaryRow[6]),
          );

          await prefs.setString('summary', json.encode(newSummary.toMap()));
          await prefs.setString(
              'summary_last_updated', DateTime.now().toIso8601String());

          setState(() {
            _summary = newSummary;
            _lastUpdated = DateTime.now();
            _isLoading = false;
            _isOffline = false;
          });
        } catch (e) {
          _logger.severe('Error creating Summary object in SummaryScreen: $e');
          // Create default Summary object on error
          final defaultSummary = Summary(
            totalIncome: 0.0,
            totalSavings: 0.0,
            currentMonthSavings: 0.0,
            currentMonthIncome: 0.0,
            totalDeductions: 0.0,
            currentMonthDeductions: 0.0,
            previousMonthSavings: 0.0,
          );

          await prefs.setString('summary', json.encode(defaultSummary.toMap()));
          await prefs.setString(
              'summary_last_updated', DateTime.now().toIso8601String());

          setState(() {
            _summary = defaultSummary;
            _lastUpdated = DateTime.now();
            _isLoading = false;
            _isOffline = false;
          });
        }
      } else if (mounted) {
        // Create default Summary object with zero values if no summary data
        _logger.warning(
            'No summary data found in SummaryScreen. Creating default summary.');

        final defaultSummary = Summary(
          totalIncome: 0.0,
          totalSavings: 0.0,
          currentMonthSavings: 0.0,
          currentMonthIncome: 0.0,
          totalDeductions: 0.0,
          currentMonthDeductions: 0.0,
          previousMonthSavings: 0.0,
        );

        await prefs.setString('summary', json.encode(defaultSummary.toMap()));
        await prefs.setString(
            'summary_last_updated', DateTime.now().toIso8601String());

        setState(() {
          _summary = defaultSummary;
          _lastUpdated = DateTime.now();
          _isLoading = false;
          _isOffline = false;
        });
      }
    } catch (e) {
      _logger.severe('Error fetching data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOffline = true;
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper method to safely parse doubles from various data types
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsedValue = double.tryParse(value);
      if (parsedValue != null) return parsedValue;
    }
    return 0.0;
  }

  Widget _buildMetricCard({
    required String title,
    required double value,
    required Color color,
    required IconData icon,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '₹${value.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Summary'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_lastUpdated != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Last updated: ${_lastUpdated!.hour}:${_lastUpdated!.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (_isOffline)
                      const Text(
                        'Offline',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchAndStoreData,
              child: _summary == null
                  ? const Center(
                      child: Text('No summary data found'),
                    )
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Section
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.teal.withOpacity(0.1),
                                  Colors.teal.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.teal.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.account_balance,
                                        color: Colors.teal,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    const Text(
                                      'Financial Overview',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'As of ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Income Section
                          _buildSectionHeader(
                            title: 'Income',
                            subtitle: 'Total and current month income',
                            icon: Icons.arrow_upward,
                            color: Colors.green,
                          ),
                          const SizedBox(height: 16),
                          _buildMetricCard(
                            title: 'Total Income',
                            value: _summary!.totalIncome,
                            color: Colors.green,
                            icon: Icons.arrow_upward,
                            subtitle: 'All Time',
                          ),
                          const SizedBox(height: 12),
                          _buildMetricCard(
                            title: 'Current Month Income',
                            value: _summary!.currentMonthIncome,
                            color: Colors.green,
                            icon: Icons.arrow_upward,
                            subtitle: 'This Month',
                          ),
                          const SizedBox(height: 24),

                          // Savings Section
                          _buildSectionHeader(
                            title: 'Savings',
                            subtitle: 'Total and monthly savings',
                            icon: Icons.account_balance,
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 16),
                          _buildMetricCard(
                            title: 'Total Savings',
                            value: _summary!.totalSavings,
                            color: Colors.blue,
                            icon: Icons.account_balance,
                            subtitle: 'All Time',
                          ),
                          const SizedBox(height: 12),
                          _buildMetricCard(
                            title: 'Current Month Savings',
                            value: _summary!.currentMonthSavings,
                            color: Colors.blue,
                            icon: Icons.account_balance,
                            subtitle: 'This Month',
                          ),
                          const SizedBox(height: 12),
                          _buildMetricCard(
                            title: 'Previous Month Savings',
                            value: _summary!.previousMonthSavings,
                            color: Colors.blue,
                            icon: Icons.account_balance,
                            subtitle: 'Last Month',
                          ),
                          const SizedBox(height: 24),

                          // Deductions Section
                          _buildSectionHeader(
                            title: 'Deductions',
                            subtitle: 'Total and current month deductions',
                            icon: Icons.arrow_downward,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          _buildMetricCard(
                            title: 'Total Deductions',
                            value: _summary!.totalDeductions,
                            color: Colors.red,
                            icon: Icons.arrow_downward,
                            subtitle: 'All Time',
                          ),
                          const SizedBox(height: 12),
                          _buildMetricCard(
                            title: 'Current Month Deductions',
                            value: _summary!.currentMonthDeductions,
                            color: Colors.red,
                            icon: Icons.arrow_downward,
                            subtitle: 'This Month',
                          ),
                          const SizedBox(height: 25),
                        ],
                      ),
                    ),
            ),
    );
  }
}

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final GoogleSheetsService _sheetsService = GoogleSheetsService();
  bool _isLoading = true;
  List<Transaction> _transactions = [];
  String? _mosqueName;
  DateTime? _lastUpdated;
  bool _isOffline = false;
  Summary? _summary;

  @override
  void initState() {
    super.initState();
    _loadFromStorage();

    // Preload an ad for next time
    AdService().loadRewardedAd();
  }

  @override
  void dispose() {
    // When this screen is closed, preload a new ad for next time
    AdService().loadRewardedAd();
    super.dispose();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load mosque name
      _mosqueName = prefs.getString('mosque_name');

      // Load last update time
      final lastUpdatedStr = prefs.getString('transactions_last_updated');
      if (lastUpdatedStr != null) {
        _lastUpdated = DateTime.parse(lastUpdatedStr);
      }

      // Load summary from storage
      final summaryJson = prefs.getString('summary');
      if (summaryJson != null && mounted) {
        setState(() {
          _summary = Summary.fromMap(json.decode(summaryJson));
        });
      }

      // Load transactions from storage
      final transactionsJson = prefs.getString('transactions');
      if (transactionsJson != null && mounted) {
        final List<dynamic> transactionsList = json.decode(transactionsJson);
        setState(() {
          _transactions = transactionsList
              .map((item) => Transaction.fromMap(item))
              .toList();
          _isLoading = false;
        });
      }

      // Only try to fetch new data if we have internet
      if (await _checkInternetConnection()) {
        if (_transactions.isEmpty ||
            _lastUpdated == null ||
            DateTime.now().difference(_lastUpdated!) >
                const Duration(hours: 1)) {
          await _fetchAndStoreData();
        }
      } else if (mounted) {
        setState(() {
          _isOffline = true;
          _isLoading = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are offline. Showing last saved data.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      _logger.severe('Error loading from storage: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOffline = true;
        });
      }
    }
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<void> _fetchAndStoreData() async {
    try {
      // Check internet connection first
      if (!await _checkInternetConnection()) {
        if (mounted) {
          setState(() {
            _isOffline = true;
            _isLoading = false;
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No internet connection. Cannot refresh data.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isLoading = true;
          _isOffline = false;
        });
      }

      // Initialize the sheets service
      await _sheetsService.initializeSheetsApi();

      // Load mosque code from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final mosqueCode = prefs.getString('mosque_code');

      if (mosqueCode == null) {
        throw Exception('No mosque code found');
      }

      _sheetsService.setSpreadsheetId(mosqueCode);

      // Fetch both transactions and summary data
      final [transactionsData, summaryData] = await Future.wait([
        _sheetsService.getTransactions(),
        _sheetsService.getSummary(),
      ]);

      // Convert to Transaction objects
      final newTransactions = transactionsData
          .where((row) => row.length >= 3) // Ensure row has at least 3 columns
          .map((row) => Transaction.fromList(row))
          .toList();

      // Convert to Summary object
      if (summaryData.isNotEmpty && summaryData[0].length >= 7 && mounted) {
        try {
          final summaryRow = summaryData[0];
          final newSummary = Summary(
            totalIncome: _parseDouble(summaryRow[0]),
            totalSavings: _parseDouble(summaryRow[1]),
            currentMonthSavings: _parseDouble(summaryRow[2]),
            currentMonthIncome: _parseDouble(summaryRow[3]),
            totalDeductions: _parseDouble(summaryRow[4]),
            currentMonthDeductions: _parseDouble(summaryRow[5]),
            previousMonthSavings: _parseDouble(summaryRow[6]),
          );

          await prefs.setString('summary', json.encode(newSummary.toMap()));
          setState(() {
            _summary = newSummary;
          });
        } catch (e) {
          _logger.severe(
              'Error creating Summary object in TransactionsScreen: $e');
          // Create default Summary object on error
          final defaultSummary = Summary(
            totalIncome: 0.0,
            totalSavings: 0.0,
            currentMonthSavings: 0.0,
            currentMonthIncome: 0.0,
            totalDeductions: 0.0,
            currentMonthDeductions: 0.0,
            previousMonthSavings: 0.0,
          );

          await prefs.setString('summary', json.encode(defaultSummary.toMap()));
          setState(() {
            _summary = defaultSummary;
          });
        }
      } else if (mounted) {
        // Create default Summary object with zero values if no summary data
        _logger.warning(
            'No summary data found in TransactionsScreen. Creating default summary.');

        final defaultSummary = Summary(
          totalIncome: 0.0,
          totalSavings: 0.0,
          currentMonthSavings: 0.0,
          currentMonthIncome: 0.0,
          totalDeductions: 0.0,
          currentMonthDeductions: 0.0,
          previousMonthSavings: 0.0,
        );

        await prefs.setString('summary', json.encode(defaultSummary.toMap()));
        setState(() {
          _summary = defaultSummary;
        });
      }

      // Store transactions in SharedPreferences
      final transactionsJson = json.encode(
        newTransactions.map((t) => t.toMap()).toList(),
      );
      await prefs.setString('transactions', transactionsJson);
      await prefs.setString(
          'transactions_last_updated', DateTime.now().toIso8601String());

      if (mounted) {
        setState(() {
          _transactions = newTransactions;
          _lastUpdated = DateTime.now();
          _isLoading = false;
          _isOffline = false;
        });
      }
    } catch (e) {
      _logger.severe('Error fetching data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOffline = true;
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper method to safely parse doubles from various data types
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsedValue = double.tryParse(value);
      if (parsedValue != null) return parsedValue;
    }
    return 0.0;
  }

  Widget _buildTransactionCard(Transaction transaction) {
    final amount = transaction.amount;
    final isIncome = amount > 0;
    final color = isIncome ? Colors.green : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Icon(
              isIncome ? Icons.arrow_upward : Icons.arrow_downward,
              color: color,
              size: 24,
            ),
          ),
        ),
        title: Text(
          transaction.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        trailing: Text(
          '₹${amount.abs().toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Transactions'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_lastUpdated != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Last updated: ${_lastUpdated!.hour}:${_lastUpdated!.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (_isOffline)
                      const Text(
                        'Offline',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No transactions found',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pull down to refresh',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchAndStoreData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Section
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.green.withOpacity(0.1),
                                Colors.green.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.receipt_long,
                                      color: Colors.green,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Text(
                                    'Transactions History',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Showing ${_transactions.length} transactions',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 25),
                        // Total Summary Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.green.withOpacity(0.1),
                                Colors.green.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Total Income',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '₹${_summary?.totalIncome.toStringAsFixed(0) ?? '0'}',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Current Month',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '₹${_summary?.currentMonthIncome.toStringAsFixed(0) ?? '0'}',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ..._transactions
                            .map((transaction) =>
                                _buildTransactionCard(transaction))
                            .toList(),
                        const SizedBox(height: 25),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class PayerTransactionsScreen extends StatefulWidget {
  const PayerTransactionsScreen({super.key});

  @override
  State<PayerTransactionsScreen> createState() =>
      _PayerTransactionsScreenState();
}

class _PayerTransactionsScreenState extends State<PayerTransactionsScreen> {
  final GoogleSheetsService _sheetsService = GoogleSheetsService();
  bool _isLoading = false; // Changed from true to false
  bool _isDataFetching = false; // New flag to track background data fetching
  List<String> _payers = [];
  String? _selectedPayer;
  List<Map<String, dynamic>> _transactions = [];
  double _totalAmount = 0.0;
  DateTime? _lastUpdated;
  bool _isOffline = false;
  bool _isFirstLoad = true;
  final List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Only load data from storage initially, don't fetch from server
      await _loadFromStorage();

      // If we have a selected payer and transactions, show them immediately
      if (_selectedPayer != null && _transactions.isNotEmpty) {
        setState(() {
          _isLoading = false;
        });
      } else {
        // Only show loading indicator if we don't have stored data
        setState(() {
          _isLoading = true;
        });

        // Check internet connection - only needed if we have no cached data
        if (!await _checkInternetConnection()) {
          if (mounted) {
            setState(() {
              _isOffline = true;
              _isLoading = false;
            });
            if (_transactions.isEmpty) {
              // Only show offline message if we don't have any data to display
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('You are offline. No saved data available.'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
          return;
        }

        // Only fetch payers list if we need to show the selection dialog
        await _fetchPayersList();

        // Check if user has already selected their name
        if (_selectedPayer != null && _selectedPayer!.isNotEmpty) {
          // Only fetch transactions if we don't have any stored
          await _loadPayerTransactions(_selectedPayer!);
        } else if (_isFirstLoad && mounted) {
          _isFirstLoad = false;
          // If no payer selected yet, show user selection dialog
          _showUserSelectionDialog();
        }

        setState(() {
          _isDataFetching = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      _logger.severe('Error loading payer data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isDataFetching = false;
          _isOffline = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // New method to only fetch the payers list, without transactions
  Future<void> _fetchPayersList() async {
    try {
      setState(() {
        _isDataFetching = true;
      });

      // Initialize sheets service
      await _sheetsService.initializeSheetsApi();

      // Load mosque code from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final mosqueCode = prefs.getString('mosque_code');

      if (mosqueCode == null) {
        throw Exception('No mosque code found');
      }

      _sheetsService.setSpreadsheetId(mosqueCode);

      // Fetch payer data from all years
      final payerData = await _sheetsService.getAllYearsPayerData();

      // Extract unique payers from payer data
      final payers = payerData
          .where((row) =>
              row.length >= 2 &&
              row[1].toString().trim().isNotEmpty &&
              row[1].toString().trim() != 'Category')
          .map((row) =>
              row[1].toString().trim()) // Payer name is in second column
          .toSet()
          .toList()
        ..sort();

      if (mounted) {
        setState(() {
          _payers = payers;
          _isOffline = false;
          _isDataFetching = false;
        });
      }
    } catch (e) {
      _logger.severe('Error fetching payers list: $e');
      if (mounted) {
        setState(() {
          _isDataFetching = false;
        });
      }
      rethrow;
    }
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load last update time
      final lastUpdatedStr = prefs.getString('payer_transactions_last_updated');
      if (lastUpdatedStr != null) {
        _lastUpdated = DateTime.parse(lastUpdatedStr);
      }

      // Load selected payer
      _selectedPayer = prefs.getString('selected_payer');

      // Load transactions
      final transactionsJson = prefs.getString('payer_transactions');
      if (transactionsJson != null) {
        final List<dynamic> transactionsList = json.decode(transactionsJson);
        if (mounted) {
          setState(() {
            _transactions = transactionsList.cast<Map<String, dynamic>>();

            // Recalculate total amount properly handling different number types
            _totalAmount = _transactions.fold(0.0, (sum, transaction) {
              // Handle all possible number types properly
              var amount = transaction['amount'];
              double numericAmount = 0.0;

              if (amount is int) {
                numericAmount = amount.toDouble();
              } else if (amount is double) {
                numericAmount = amount;
              } else if (amount is String) {
                numericAmount = double.tryParse(amount) ?? 0.0;
              } else if (amount is num) {
                numericAmount = amount.toDouble();
              }

              return sum + numericAmount;
            });

            _logger.info(
                'Loaded ${_transactions.length} transactions from storage with total: $_totalAmount');
          });
        }
      }
    } catch (e) {
      _logger.severe('Error loading from storage: $e');
    }
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save last update time
      await prefs.setString(
          'payer_transactions_last_updated', DateTime.now().toIso8601String());

      // Save selected payer (ensure it's not null)
      if (_selectedPayer != null) {
        await prefs.setString('selected_payer', _selectedPayer!);
      }

      // Save transactions - ensure numbers are properly serialized
      final processedTransactions = _transactions.map((transaction) {
        // Create a new map to avoid modifying the original
        final Map<String, dynamic> processedTransaction = {...transaction};

        // Ensure amount is a numeric value before saving
        var amount = transaction['amount'];
        if (amount is String) {
          processedTransaction['amount'] = double.tryParse(amount) ?? 0.0;
        } else if (amount is int) {
          processedTransaction['amount'] = amount.toDouble();
        }

        return processedTransaction;
      }).toList();

      final transactionsJson = json.encode(processedTransactions);
      await prefs.setString('payer_transactions', transactionsJson);

      _logger.info(
          'Saved ${_transactions.length} transactions to storage with total: $_totalAmount');
    } catch (e) {
      _logger.severe('Error saving to storage: $e');
    }
  }

  void _showOfflineAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Offline Mode'),
        content: const Text(
          'You are currently offline. Please check your internet connection and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showUserSelectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Select Your Name'),
        content: const Text(
          'Please select your name from the list to view your transactions.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showUserSelectionList();
            },
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }

  void _showUserSelectionList() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Your Name'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _payers.length,
            itemBuilder: (context, index) {
              final payer = _payers[index];
              return ListTile(
                title: Text(payer),
                onTap: () async {
                  // Save selected payer to SharedPreferences
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('selected_payer', payer);

                  // Close dialog and load transactions
                  Navigator.pop(context);
                  _loadPayerTransactions(payer);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _loadPayerTransactions(String payer) async {
    _logger.info('Loading transactions for payer: $payer');
    try {
      setState(() {
        _isDataFetching = true;
        _isOffline = false;
      });

      final DateTime now = DateTime.now();
      final int currentYear = now.year;

      // Use the new optimized method to get all transactions with a single request
      final transactions = await _sheetsService.getPayerTransactions(payer);

      if (transactions.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No transaction data found for this payer.'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // Calculate total amount with proper number type handling
      double totalAmount = transactions.fold(0.0, (sum, item) {
        // Get the amount value
        var amount = item['amount'];
        double numericAmount = 0.0;

        // Handle all possible number types
        if (amount is int) {
          numericAmount = amount.toDouble();
        } else if (amount is double) {
          numericAmount = amount;
        } else if (amount is String) {
          numericAmount = double.tryParse(amount) ?? 0.0;
        } else if (amount is num) {
          numericAmount = amount.toDouble();
        }

        return sum + numericAmount;
      });

      _logger.info(
          'Calculated total amount: $totalAmount from ${transactions.length} transactions');

      if (mounted) {
        setState(() {
          _transactions = transactions;
          _totalAmount = totalAmount;
          _selectedPayer = payer;
          _lastUpdated = DateTime.now();
          _isDataFetching = false;
          _isOffline = false;
        });
      }

      // Save to storage
      await _saveToStorage();
    } catch (e) {
      _logger.severe('Error loading payer transactions: $e');
      if (mounted) {
        setState(() {
          _isDataFetching = false;
          _isOffline = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading transactions: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final month = transaction['monthName'] as String;

    // Handle amount with proper type checking
    double amount = 0.0;
    var rawAmount = transaction['amount'];

    if (rawAmount is int) {
      amount = rawAmount.toDouble();
    } else if (rawAmount is double) {
      amount = rawAmount;
    } else if (rawAmount is String) {
      amount = double.tryParse(rawAmount) ?? 0.0;
    } else if (rawAmount is num) {
      amount = rawAmount.toDouble();
    }

    final year = transaction['year'] as int;
    final isIncome = amount > 0;
    final color = isIncome ? Colors.green : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Icon(
              isIncome ? Icons.arrow_upward : Icons.arrow_downward,
              color: color,
              size: 24,
            ),
          ),
        ),
        title: Text(
          month,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Year: $year',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        trailing: Text(
          '₹${amount.abs().toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('My Transactions'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isDataFetching)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                  ),
                ),
              ),
            ),
          if (_lastUpdated != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Last updated: ${_lastUpdated!.hour}:${_lastUpdated!.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (_isOffline)
                      const Text(
                        'Offline',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedPayer == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No user selected',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () async {
                          // Fetch payers list only when the button is pressed
                          try {
                            await _fetchPayersList();
                            _showUserSelectionList();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Error fetching payers: ${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: const Text('Select Your Name'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    // Only fetch data when user explicitly pulls to refresh
                    if (await _checkInternetConnection()) {
                      setState(() {
                        _isDataFetching = true;
                      });
                      await _loadPayerTransactions(_selectedPayer!);
                    } else {
                      _showOfflineAlert();
                    }
                  },
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            // User info card
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.teal.withOpacity(0.1),
                                    Colors.teal.withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.teal.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.teal.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.person,
                                          color: Colors.teal,
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
                                              'Your Transactions',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _selectedPayer!,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Total amount card
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          'Total Amount (All Years)',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '₹${_totalAmount.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.teal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_selectedPayer != null)
                        Expanded(
                          child: _transactions.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.receipt_long,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No transactions found',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Pull down to refresh',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : SingleChildScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  child: Column(
                                    children: _transactions
                                        .map((transaction) =>
                                            _buildTransactionCard(transaction))
                                        .toList(),
                                  ),
                                ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class DeductionsScreen extends StatefulWidget {
  const DeductionsScreen({super.key});

  @override
  State<DeductionsScreen> createState() => _DeductionsScreenState();
}

class _DeductionsScreenState extends State<DeductionsScreen> {
  final GoogleSheetsService _sheetsService = GoogleSheetsService();
  bool _isLoading = true;
  List<Deduction> _deductions = [];
  String? _mosqueName;
  DateTime? _lastUpdated;
  bool _isOffline = false;
  Summary? _summary;

  @override
  void initState() {
    super.initState();
    _loadFromStorage();

    // Preload an ad for next time
    AdService().loadRewardedAd();
  }

  @override
  void dispose() {
    // When this screen is closed, preload a new ad for next time
    AdService().loadRewardedAd();
    super.dispose();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load mosque name
      _mosqueName = prefs.getString('mosque_name');

      // Load last update time
      final lastUpdatedStr = prefs.getString('deductions_last_updated');
      if (lastUpdatedStr != null) {
        _lastUpdated = DateTime.parse(lastUpdatedStr);
      }

      // Load summary from storage
      final summaryJson = prefs.getString('summary');
      if (summaryJson != null && mounted) {
        setState(() {
          _summary = Summary.fromMap(json.decode(summaryJson));
        });
      }

      // Load deductions from storage
      final deductionsJson = prefs.getString('deductions');
      if (deductionsJson != null && mounted) {
        final List<dynamic> deductionsList = json.decode(deductionsJson);
        setState(() {
          _deductions =
              deductionsList.map((item) => Deduction.fromMap(item)).toList();
          _isLoading = false;
        });
      }

      // Only try to fetch new data if we have internet
      if (await _checkInternetConnection()) {
        if (_deductions.isEmpty ||
            _lastUpdated == null ||
            DateTime.now().difference(_lastUpdated!) >
                const Duration(hours: 1)) {
          await _fetchAndStoreData();
        }
      } else if (mounted) {
        setState(() {
          _isOffline = true;
          _isLoading = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are offline. Showing last saved data.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      _logger.severe('Error loading from storage: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOffline = true;
        });
      }
    }
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<void> _fetchAndStoreData() async {
    try {
      // Check internet connection first
      if (!await _checkInternetConnection()) {
        if (mounted) {
          setState(() {
            _isOffline = true;
            _isLoading = false;
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No internet connection. Cannot refresh data.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isLoading = true;
          _isOffline = false;
        });
      }

      // Initialize the sheets service
      await _sheetsService.initializeSheetsApi();

      // Load mosque code from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final mosqueCode = prefs.getString('mosque_code');

      if (mosqueCode == null) {
        throw Exception('No mosque code found');
      }

      _sheetsService.setSpreadsheetId(mosqueCode);

      // Fetch both deductions and summary data
      final [deductionsData, summaryData] = await Future.wait([
        _sheetsService.getDeductions(),
        _sheetsService.getSummary(),
      ]);

      // Convert to Deduction objects
      final newDeductions =
          deductionsData.map((row) => Deduction.fromList(row)).toList();

      // Convert to Summary object
      if (summaryData.isNotEmpty && summaryData[0].length >= 7 && mounted) {
        try {
          final summaryRow = summaryData[0];
          final newSummary = Summary(
            totalIncome: _parseDouble(summaryRow[0]),
            totalSavings: _parseDouble(summaryRow[1]),
            currentMonthSavings: _parseDouble(summaryRow[2]),
            currentMonthIncome: _parseDouble(summaryRow[3]),
            totalDeductions: _parseDouble(summaryRow[4]),
            currentMonthDeductions: _parseDouble(summaryRow[5]),
            previousMonthSavings: _parseDouble(summaryRow[6]),
          );

          await prefs.setString('summary', json.encode(newSummary.toMap()));
          setState(() {
            _summary = newSummary;
          });
        } catch (e) {
          _logger
              .severe('Error creating Summary object in DeductionsScreen: $e');
          // Create default Summary object on error
          final defaultSummary = Summary(
            totalIncome: 0.0,
            totalSavings: 0.0,
            currentMonthSavings: 0.0,
            currentMonthIncome: 0.0,
            totalDeductions: 0.0,
            currentMonthDeductions: 0.0,
            previousMonthSavings: 0.0,
          );

          await prefs.setString('summary', json.encode(defaultSummary.toMap()));
          setState(() {
            _summary = defaultSummary;
          });
        }
      } else if (mounted) {
        // Create default Summary object with zero values if no summary data
        _logger.warning(
            'No summary data found in DeductionsScreen. Creating default summary.');

        final defaultSummary = Summary(
          totalIncome: 0.0,
          totalSavings: 0.0,
          currentMonthSavings: 0.0,
          currentMonthIncome: 0.0,
          totalDeductions: 0.0,
          currentMonthDeductions: 0.0,
          previousMonthSavings: 0.0,
        );

        await prefs.setString('summary', json.encode(defaultSummary.toMap()));
        setState(() {
          _summary = defaultSummary;
        });
      }

      // Store deductions in SharedPreferences
      final deductionsJson = json.encode(
        newDeductions.map((d) => d.toMap()).toList(),
      );
      await prefs.setString('deductions', deductionsJson);
      await prefs.setString(
          'deductions_last_updated', DateTime.now().toIso8601String());

      if (mounted) {
        setState(() {
          _deductions = newDeductions;
          _lastUpdated = DateTime.now();
          _isLoading = false;
          _isOffline = false;
        });
      }
    } catch (e) {
      _logger.severe('Error fetching data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOffline = true;
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper method to safely parse doubles from various data types
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsedValue = double.tryParse(value);
      if (parsedValue != null) return parsedValue;
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Deductions'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_lastUpdated != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Last updated: ${_lastUpdated!.hour}:${_lastUpdated!.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (_isOffline)
                      const Text(
                        'Offline',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _deductions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.money_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No deductions found',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pull down to refresh',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchAndStoreData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Section
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.red.withOpacity(0.1),
                                Colors.red.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.money_off,
                                      color: Colors.red,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Text(
                                    'Deductions History',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Showing ${_deductions.length} deductions',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 25),
                        // Total Summary Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.red.withOpacity(0.1),
                                Colors.red.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Total Deductions',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '₹${_summary?.totalDeductions.toStringAsFixed(0) ?? '0'}',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Current Month',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '₹${_summary?.currentMonthDeductions.toStringAsFixed(0) ?? '0'}',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ..._deductions
                            .map((deduction) => _buildDeductionCard(deduction))
                            .toList(),
                        const SizedBox(
                            height: 25), // Bottom margin for navigation
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildDeductionCard(Deduction deduction) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.red.withOpacity(0.1),
            Colors.red.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.red.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Icon(Icons.arrow_downward, color: Colors.red, size: 24),
          ),
        ),
        title: Text(
          deduction.category,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${deduction.date.day}/${deduction.date.month}/${deduction.date.year}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Deduction',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${deduction.amount.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${deduction.date.hour.toString().padLeft(2, '0')}:${deduction.date.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
