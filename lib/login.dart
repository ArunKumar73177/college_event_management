import 'package:flutter/material.dart';
import 'dart:math';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Organizer fields
  final TextEditingController _organizerStudentIdController = TextEditingController();
  final TextEditingController _organizerPasswordController = TextEditingController();
  final TextEditingController _organizerCaptchaController = TextEditingController();
  String _organizerCaptchaCode = '';

  // Attendee fields
  final TextEditingController _attendeeStudentIdController = TextEditingController();
  final TextEditingController _attendeePasswordController = TextEditingController();
  final TextEditingController _attendeeCaptchaController = TextEditingController();
  String _attendeeCaptchaCode = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _organizerCaptchaCode = _generateCaptcha();
    _attendeeCaptchaCode = _generateCaptcha();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _organizerStudentIdController.dispose();
    _organizerPasswordController.dispose();
    _organizerCaptchaController.dispose();
    _attendeeStudentIdController.dispose();
    _attendeePasswordController.dispose();
    _attendeeCaptchaController.dispose();
    super.dispose();
  }

  String _generateCaptcha() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
    final random = Random();
    return String.fromCharCodes(
        Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
    );
  }

  void _refreshOrganizerCaptcha() {
    setState(() {
      _organizerCaptchaCode = _generateCaptcha();
      _organizerCaptchaController.clear();
    });
  }

  void _refreshAttendeeCaptcha() {
    setState(() {
      _attendeeCaptchaCode = _generateCaptcha();
      _attendeeCaptchaController.clear();
    });
  }

  void _handleOrganizerLogin() {
    if (_organizerCaptchaController.text != _organizerCaptchaCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid CAPTCHA. Please try again.')),
      );
      _refreshOrganizerCaptcha();
      return;
    }
    print('Organizer login: ${_organizerStudentIdController.text}');
    // Add your login logic here
  }

  void _handleAttendeeLogin() {
    if (_attendeeCaptchaController.text != _attendeeCaptchaCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid CAPTCHA. Please try again.')),
      );
      _refreshAttendeeCaptcha();
      return;
    }
    print('Attendee login: ${_attendeeStudentIdController.text}');
    // Add your login logic here
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.black87),
                  const SizedBox(width: 8),
                  const Text(
                    'Help & Support',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'If you forgot your login details, please contact the event manager',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Event Manager Contact',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.phone, size: 16, color: Colors.black54),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Phone',
                              style: TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '+91 9876543210',
                              style: TextStyle(color: Colors.black87),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.mail_outline, size: 16, color: Colors.black54),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Email',
                              style: TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'events.manager@scriet.edu',
                              style: TextStyle(color: Colors.black87),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: const [
                    Expanded(
                      child: Text(
                        'Office Hours: Monday - Friday, 9:00 AM - 5:00 PM',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
              Colors.grey.shade50,
              Colors.grey.shade100,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 448),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo and Header
                    Image.asset(
                      'assets/images/logo.png', // Replace with your logo path
                      width: 112,
                      height: 112,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'SCRIET Events',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'College Event Management System',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Chaudhary Charan Singh University, Meerut',
                      style: TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                    const SizedBox(height: 32),

                    // Card
                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Access your account to manage or attend events',
                                  style: TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                          ),

                          // Content
                          Container(
                            padding: const EdgeInsets.all(24),
                            color: Colors.white,
                            child: Column(
                              children: [
                                // Tabs
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border(
                                      bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                                    ),
                                  ),
                                  child: TabBar(
                                    controller: _tabController,
                                    indicator: UnderlineTabIndicator(
                                      borderSide: BorderSide(
                                        color: Colors.black87,
                                        width: 3,
                                      ),
                                      insets: EdgeInsets.symmetric(horizontal: 0),
                                    ),
                                    labelColor: Colors.black87,
                                    unselectedLabelColor: Colors.black54,
                                    labelStyle: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                    unselectedLabelStyle: const TextStyle(
                                      fontWeight: FontWeight.normal,
                                      fontSize: 15,
                                    ),
                                    tabs: const [
                                      Tab(text: 'Organizer'),
                                      Tab(text: 'Attendee'),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Tab Content
                                SizedBox(
                                  height: 380,
                                  child: TabBarView(
                                    controller: _tabController,
                                    children: [
                                      _buildLoginForm(
                                        studentIdController: _organizerStudentIdController,
                                        passwordController: _organizerPasswordController,
                                        captchaController: _organizerCaptchaController,
                                        captchaCode: _organizerCaptchaCode,
                                        onRefreshCaptcha: _refreshOrganizerCaptcha,
                                        onLogin: _handleOrganizerLogin,
                                        buttonText: 'Login as Organizer',
                                        studentIdHint: 'e.g., 2024001',
                                      ),
                                      _buildLoginForm(
                                        studentIdController: _attendeeStudentIdController,
                                        passwordController: _attendeePasswordController,
                                        captchaController: _attendeeCaptchaController,
                                        captchaCode: _attendeeCaptchaCode,
                                        onRefreshCaptcha: _refreshAttendeeCaptcha,
                                        onLogin: _handleAttendeeLogin,
                                        buttonText: 'Login as Attendee',
                                        studentIdHint: 'e.g., 2024123',
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Help Button
                                OutlinedButton.icon(
                                  onPressed: _showHelpDialog,
                                  icon: const Icon(Icons.info_outline),
                                  label: const Text('Need Help?'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.black54,
                                    side: BorderSide(color: Colors.grey.shade300),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Footer
                    const Text(
                      '© 2024 SCRIET | Meerut, Uttar Pradesh',
                      style: TextStyle(fontSize: 12, color: Colors.black45),
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

  Widget _buildLoginForm({
    required TextEditingController studentIdController,
    required TextEditingController passwordController,
    required TextEditingController captchaController,
    required String captchaCode,
    required VoidCallback onRefreshCaptcha,
    required VoidCallback onLogin,
    required String buttonText,
    required String studentIdHint,
  }) {
    return Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student ID
          const Text(
            'Student ID',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: studentIdController,
            decoration: InputDecoration(
              hintText: studentIdHint,
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Password
          const Text(
            'Password',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'Enter your password',
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // CAPTCHA
          const Text(
            'Enter CAPTCHA',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: captchaController,
                  decoration: InputDecoration(
                    hintText: 'Enter code',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  captchaCode,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 18,
                    letterSpacing: 2,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: Colors.black54,
                    decorationThickness: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onRefreshCaptcha,
                icon: const Icon(Icons.refresh),
                style: IconButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Login Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade900,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }
}