import 'package:flutter/material.dart';
import '../screens/mosque_screen.dart';
import '../screens/settings_screen.dart';

class FeatureGrid extends StatelessWidget {
  const FeatureGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      child: GridView.count(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 15,
        crossAxisSpacing: 15,
        childAspectRatio: 1.2,
        children: [
          _buildFeatureCard(
            context,
            'Prayer Timings',
            Icons.access_time_rounded,
            Colors.orange,
            () {
              // Navigate to Prayer Timings screen
              Navigator.pushNamed(context, '/prayer_timings');
            },
          ),
          _buildFeatureCard(
            context,
            'Al-Quran',
            Icons.menu_book_rounded,
            Colors.green,
            () {
              // Navigate to Quran Continuous screen
              Navigator.pushNamed(context, '/quran_continuous');
            },
          ),
          _buildFeatureCard(
            context,
            'Qibla Direction',
            Icons.explore,
            Colors.purple,
            () {
              // Navigate to Qibla screen when implemented
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Qibla Direction coming soon')),
              );
            },
          ),
          _buildFeatureCard(
            context,
            'Hadith Collection',
            Icons.library_books,
            Colors.indigo,
            () {
              // Navigate to Hadith screen when implemented
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Hadith Collection coming soon')),
              );
            },
          ),
          _buildFeatureCard(
            context,
            'Duas',
            Icons.favorite,
            Colors.pink,
            () {
              // Navigate to Duas screen when implemented
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Duas coming soon')),
              );
            },
          ),
          _buildFeatureCard(
            context,
            'Your Mosque',
            Icons.mosque,
            Colors.teal,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MosqueScreen(),
                ),
              );
            },
          ),
          _buildFeatureCard(
            context,
            'Settings',
            Icons.settings,
            Colors.blue,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 30,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
