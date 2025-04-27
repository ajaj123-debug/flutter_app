import 'package:flutter/material.dart';
import 'dart:ui';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final double opacity;

  const BottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    this.opacity = 1.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Only apply backdrop filter when opacity > 0
    Widget navBarContent = Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        // Start with solid white when opacity is 0, transition to translucent as opacity increases
        color: opacity == 0
            ? Colors.white
            : Colors.white.withAlpha((0.8 * opacity * 255).round()),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * opacity * 255).round()),
            offset: const Offset(0, -5),
            blurRadius: 10,
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey.shade600,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 11,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mosque),
            label: 'Mosque',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_rounded),
            label: 'Quran',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );

    // Apply backdrop filter only when opacity > 0
    if (opacity > 0) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10 * opacity, sigmaY: 10 * opacity),
          child: navBarContent,
        ),
      );
    } else {
      // No backdrop filter when opacity is 0 (solid white)
      return navBarContent;
    }
  }
}
