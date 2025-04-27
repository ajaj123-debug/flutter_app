import 'package:flutter/material.dart';
import 'dart:async';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({Key? key}) : super(key: key);

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  // Placeholder for timer logic
  String _timeLeft = "20:34:44";
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Start a dummy timer for visual effect
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    // This is just a visual countdown, not a real offer timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Simple countdown logic placeholder
      // You might want to replace this with actual offer duration logic
      setState(() {
        // Update _timeLeft (This is complex, using placeholder)
        _timeLeft =
            "20:34:${(int.parse(_timeLeft.split(':')[2]) - 1).toString().padLeft(2, '0')}";
        if (_timeLeft.endsWith('00')) {
          _timeLeft = "20:33:59"; // Example rollover
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF075E54), // Dark teal background
      body: Stack(
        children: [
          // Background Image (Flipped)
          Positioned.fill(
            child: Transform.rotate(
              angle: 3.14159, // Rotate 180 degrees (pi radians)
              child: Image.asset(
                'assets/images/background_for_premium.jpg', // Corrected asset path
                fit: BoxFit.cover,
                // Remove the color overlay from here if the gradient provides enough contrast
                color: Colors.black.withOpacity(0.3),
                colorBlendMode: BlendMode.darken,
              ),
            ),
          ),
          // Black Fade Overlay (Bottom Half)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.6),
                    Colors.black.withOpacity(0.8),
                  ],
                  begin: Alignment
                      .topCenter, // Start transparent at the top (of the gradient)
                  end: Alignment
                      .bottomCenter, // End black at the bottom (of the gradient)
                  stops: const [
                    0.4,
                    0.7,
                    1.0
                  ], // Control fade: transparent until 40%, then fade to black
                ),
              ),
            ),
          ),
          // Close Button
          Positioned(
            top: 40,
            right: 15,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  const Text(
                    'Streamline Your Mosque Finances',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: Offset(1.0, 1.0),
                          blurRadius: 3.0,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Go ad-free and support future development', // Updated Subtitle
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Offer ends in ',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      Text(
                        _timeLeft,
                        style: const TextStyle(
                          color: Color(0xFF25D366), // Bright Green
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildPremiumButton(context),
                  const SizedBox(height: 16),
                  const Text(
                    'Cancel any time - no penalties or fees',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 10), // Add some space
                  const Text(
                    'Consider the cost of physical registers, that will cost you approx premium price \nFor just ₹499/year, manage everything digitally. \nUpgrade once, enjoy premium benefits there will be no go back.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        height: 1.4),
                  ),
                  const SizedBox(
                      height: 10), // Add some space before the next buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () {
                          // Add logic for terms and conditions
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Terms & Conditions coming soon...')));
                        },
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4)), // Reduce padding
                        child: const Text(
                          'Terms & Conditions',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              decoration: TextDecoration.underline),
                        ),
                      ),
                      const Text('|',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12)), // Separator
                      TextButton(
                        onPressed: () {
                          // Add logic to restore purchase
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'Restore purchase functionality coming soon...')));
                        },
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4)), // Reduce padding
                        child: const Text(
                          'Restore purchase',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              decoration: TextDecoration.underline),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumButton(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1DB954), // Slightly lighter green
                Color(
                    0xFF128C7E), // Slightly darker green (like WhatsApp dark green)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 3), // changes position of shadow
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () {
              // Add your purchase logic here
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Purchase functionality coming soon...')));
              // Example: Initiate purchase flow
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors
                  .transparent, // Make button background transparent to show gradient
              shadowColor: Colors.transparent, // Remove default button shadow
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              minimumSize: const Size(double.infinity, 60), // Make button wide
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Remove Ads for ₹499/year', // Replace with actual price/currency
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "That's only ₹1.36/day!", // Replace with calculated monthly price
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: -12, // Position the badge slightly above the button
          left: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              // Gold-like gradient for the badge
              gradient: LinearGradient(
                colors: [
                  Colors.yellow.shade600,
                  Colors.yellow.shade800,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 0,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: const Text(
              'Limited Time Only',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  shadows: [
                    Shadow(
                        color: Colors.black26,
                        offset: Offset(0, 1),
                        blurRadius: 1)
                  ]),
            ),
          ),
        ),
      ],
    );
  }
}
