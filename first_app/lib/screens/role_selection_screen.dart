import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'manager_main_screen.dart';
import 'first_time_setup_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({Key? key}) : super(key: key);

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _hasCheckedTerms = false;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final hasAcceptedTerms = prefs.getBool('terms_accepted') ?? false;
    setState(() {
      _hasCheckedTerms = hasAcceptedTerms;
    });
  }

  Future<void> _showTermsDialog() async {
    final prefs = await SharedPreferences.getInstance();
    bool? accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Terms and Conditions'),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to Mosque Ease! Please read and accept our terms and conditions to continue.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Text(
                  '1. Privacy: We respect your privacy and handle your data securely.\n\n'
                  '2. Data Usage: Your mosque data will be stored securely and used only for app functionality.\n\n'
                  '3. Responsibilities: As a manager, you are responsible for maintaining accurate records.\n\n'
                  '4. Updates: The app may receive updates to improve functionality.\n\n'
                  '5. Support: We provide support for technical issues and questions.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Decline'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Accept'),
            ),
          ],
        );
      },
    );

    if (accepted == true) {
      await prefs.setBool('terms_accepted', true);
      setState(() {
        _hasCheckedTerms = true;
      });
    }
  }

  Future<void> _selectRole(BuildContext context, String role) async {
    if (!_hasCheckedTerms) {
      await _showTermsDialog();
      if (!_hasCheckedTerms) return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
    
    // For manager role, check if setup is complete
    if (role == 'manager') {
      final mosqueName = prefs.getString('masjid_name');
      final isSetupComplete = mosqueName != null && mosqueName.isNotEmpty;
      
      if (!context.mounted) return;
      
      if (!isSetupComplete) {
        await prefs.setBool('first_launch', true);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const FirstTimeSetupScreen(),
          ),
        );
        return;
      }
    }
    
    await prefs.setBool('first_launch', false);

    if (!context.mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => role == 'manager' 
          ? const ManagerMainScreen() 
          : const HomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withOpacity(0.8),
              Theme.of(context).colorScheme.secondary,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Welcome to',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w300,
                        color: Colors.white70,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Mosque Ease',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select your role to continue',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 48),
                    _RoleCard(
                      title: 'Manager',
                      subtitle: 'Manage mosque activities and settings',
                      description: 'As a manager, you can:\n'
                          '• Configure mosque settings\n'
                          '• Manage financial records\n'
                          '• Handle user access\n'
                          '• Generate reports',
                      icon: Icons.admin_panel_settings,
                      onPressed: () => _selectRole(context, 'manager'),
                    ),
                    const SizedBox(height: 24),
                    _RoleCard(
                      title: 'Viewer',
                      subtitle: 'Access mosque information and services',
                      description: 'As a viewer, you can:\n'
                          '• View prayer times\n'
                          '• Access mosque announcements\n'
                          '• View public events\n'
                          '• Access basic information',
                      icon: Icons.person,
                      onPressed: () => _selectRole(context, 'viewer'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final VoidCallback onPressed;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.onPressed,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _isHovered = false;
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()
          ..scale(_isHovered ? 1.02 : 1.0),
        child: Card(
          elevation: _isHovered ? 8 : 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: () {
              setState(() => _isExpanded = !_isExpanded);
              widget.onPressed();
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          widget.icon,
                          size: 32,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                  if (_isExpanded) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      widget.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 