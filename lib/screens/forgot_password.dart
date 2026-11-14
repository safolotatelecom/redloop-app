import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api_helper.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController phoneCtrl = TextEditingController();

  bool loading = true;
  String? supportWhatsApp;
  String? supportEmail;
  String? loadError;

  static const Color primary = Color(0xFFDC3545);
  static const Color background = Color(0xFFF7F8FA);

  @override
  void initState() {
    super.initState();
    _loadSupportContact();
  }

  @override
  void dispose() {
    phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSupportContact() async {
    setState(() {
      loading = true;
      loadError = null;
    });

    try {
      final result = await ApiService.get(
        '/support-contact',
        authenticated: false,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final data = result['data'];
        final values = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};

        setState(() {
          supportWhatsApp =
              values['support_whatsapp']?.toString().trim();
          supportEmail = values['support_email']?.toString().trim();
          loading = false;
        });
      } else {
        setState(() {
          loadError = result['message']?.toString() ??
              'সাপোর্ট যোগাযোগের তথ্য পাওয়া যায়নি।';
          loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadError = 'সার্ভারের সঙ্গে সংযোগ করা যাচ্ছে না।';
        loading = false;
      });
    }
  }

  String _phoneDigits(String value) {
    var digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0')) {
      digits = '88$digits';
    }
    return digits;
  }

  Future<void> _openWhatsApp() async {
    final number = _phoneDigits(supportWhatsApp ?? '');
    if (number.isEmpty) {
      _showMessage('Admin এখনো WhatsApp নম্বর সেট করেননি।');
      return;
    }

    final userPhone = phoneCtrl.text.trim();
    final message = Uri.encodeComponent(
      'Hello RedLoop Support, I need help recovering my account password.'
      '${userPhone.isEmpty ? '' : ' My registered phone number is: $userPhone.'}'
      ' Please guide me through the secure password recovery process.',
    );

    final uri = Uri.parse('https://wa.me/$number?text=$message');
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      _showMessage('WhatsApp খোলা যাচ্ছে না।');
    }
  }

  Future<void> _openEmail() async {
    final email = supportEmail?.trim() ?? '';
    if (email.isEmpty) {
      _showMessage('Admin এখনো Support Email সেট করেননি।');
      return;
    }

    final userPhone = phoneCtrl.text.trim();
    final subject = Uri.encodeComponent('RedLoop Pro - Password Assistance');
    final body = Uri.encodeComponent(
      'Hello RedLoop Support,\n\n'
      'I need help recovering my RedLoop Pro account password.\n'
      '${userPhone.isEmpty ? '' : 'Registered phone number: $userPhone\n'}'
      '\nPlease guide me through the secure password recovery process.\n',
    );

    final uri = Uri.parse('mailto:$email?subject=$subject&body=$body');
    final opened = await launchUrl(uri);

    if (!opened && mounted) {
      _showMessage('ইমেইল অ্যাপ খোলা যাচ্ছে না।');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  bool get _hasWhatsApp =>
      supportWhatsApp != null && supportWhatsApp!.trim().isNotEmpty;

  bool get _hasEmail =>
      supportEmail != null && supportEmail!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('পাসওয়ার্ড পুনরুদ্ধার'),
        backgroundColor: background,
        foregroundColor: const Color(0xFF20232B),
        elevation: 0,
      ),
      body: SafeArea(
        child: loading
            ? const Center(
                child: CircularProgressIndicator(color: primary),
              )
            : RefreshIndicator(
                color: primary,
                onRefresh: _loadSupportContact,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: primary,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'পাসওয়ার্ড ভুলে গেছেন?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF20232B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'আপনার নিবন্ধিত ফোন নম্বর লিখুন। এরপর Admin-এর নির্ধারিত WhatsApp অথবা Support Email-এ যোগাযোগ করতে পারবেন।',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: Color(0xFF777D89),
                      ),
                    ),
                    const SizedBox(height: 26),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'নিবন্ধিত ফোন নম্বর (ঐচ্ছিক)',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (loadError != null) ...[
                      _InfoCard(
                        icon: Icons.error_outline,
                        message: loadError!,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _loadSupportContact,
                        icon: const Icon(Icons.refresh),
                        label: const Text('আবার চেষ্টা করুন'),
                      ),
                    ] else if (!_hasWhatsApp && !_hasEmail) ...[
                      const _InfoCard(
                        icon: Icons.support_agent,
                        message:
                            'সাপোর্ট যোগাযোগের তথ্য এখনো Admin সেট করেননি। অনুগ্রহ করে পরে আবার চেষ্টা করুন।',
                        color: primary,
                      ),
                    ] else ...[
                      if (_hasWhatsApp)
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: _openWhatsApp,
                            icon: const Icon(Icons.chat_rounded),
                            label: const Text(
                              'WhatsApp-এ যোগাযোগ করুন',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF168C55),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      if (_hasWhatsApp && _hasEmail)
                        const SizedBox(height: 12),
                      if (_hasEmail)
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: OutlinedButton.icon(
                            onPressed: _openEmail,
                            icon: const Icon(Icons.email_outlined),
                            label: const Text(
                              'Support Email-এ মেইল করুন',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primary,
                              side: const BorderSide(color: primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 22),
                    const _InfoCard(
                      icon: Icons.shield_outlined,
                      message:
                          'নিরাপত্তার জন্য WhatsApp বা Email-এ কখনো আপনার পুরোনো পাসওয়ার্ড বা OTP পাঠাবেন না। Support Team আপনাকে নিরাপদ পুনরুদ্ধার প্রক্রিয়ায় সহায়তা করবে।',
                      color: Color(0xFF3976B8),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.55,
                color: Color(0xFF454B55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
