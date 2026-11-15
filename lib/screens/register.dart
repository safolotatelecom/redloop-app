import 'package:flutter/material.dart';

import '../api_helper.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loadingTerms = true;
  bool _registering = false;
  bool _termsAccepted = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String _termsVersion = '';
  String _termsContent = '';
  String _pageMessage = '';

  @override
  void initState() {
    super.initState();
    _loadTerms();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadTerms() async {
    if (mounted) {
      setState(() {
        _loadingTerms = true;
        _pageMessage = '';
      });
    }

    final result = await ApiService.get(
      '/terms',
      authenticated: false,
    );

    if (!mounted) return;

    final version = result['terms_version'];
    final content = result['terms_content'];

    if (result['success'] == true &&
        version is String &&
        version.trim().isNotEmpty &&
        content is String &&
        content.trim().isNotEmpty) {
      setState(() {
        _termsVersion = version.trim();
        _termsContent = content.trim();
        _loadingTerms = false;
      });
    } else {
      setState(() {
        _loadingTerms = false;
        _termsVersion = '';
        _termsContent = '';
        _pageMessage = (result['message'] ??
                'শর্তাবলি লোড করা যায়নি। আবার চেষ্টা করুন।')
            .toString();
      });
    }
  }

  String? _validationMessage(Map<String, dynamic> result) {
    final errors = result['errors'];

    if (errors is Map) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }
      }
    }

    return result['message']?.toString() ??
        'নিবন্ধন সম্পন্ন করা যায়নি। আবার চেষ্টা করুন।';
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_loadingTerms || _termsVersion.isEmpty || _termsContent.isEmpty) {
      _showMessage('সর্বশেষ শর্তাবলি লোড না হওয়া পর্যন্ত নিবন্ধন করা যাবে না।');
      return;
    }

    if (!_termsAccepted) {
      _showMessage('নিবন্ধন করতে শর্তাবলি গ্রহণ করুন।');
      return;
    }

    setState(() {
      _registering = true;
      _pageMessage = '';
    });

    final result = await ApiService.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
      passwordConfirmation: _confirmPasswordController.text,
      termsAccepted: true,
      termsVersion: _termsVersion,
    );

    if (!mounted) return;

    setState(() {
      _registering = false;
    });

    if (result['success'] == true) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: const Icon(
            Icons.check_circle_rounded,
            color: Colors.green,
            size: 52,
          ),
          title: const Text('নিবন্ধন সফল হয়েছে'),
          content: const Text(
            'আপনার অ্যাকাউন্ট তৈরি হয়েছে। এখন লগইন করতে পারবেন।',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ঠিক আছে'),
            ),
          ],
        ),
      );

      if (mounted) Navigator.pop(context);
    } else {
      _showMessage(_validationMessage(result) ?? 'নিবন্ধন সম্পন্ন করা যায়নি। আবার চেষ্টা করুন।');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  InputDecoration _decoration(
    String label,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE7E9EE)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD92332), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }

  Widget _buildTermsCard() {
    if (_loadingTerms) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE7E9EE)),
        ),
        child: const Row(
          children: [
            SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('সর্বশেষ শর্তাবলি লোড হচ্ছে...')),
          ],
        ),
      );
    }

    if (_termsVersion.isEmpty || _termsContent.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4F3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFD7D3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'শর্তাবলি পাওয়া যাচ্ছে না',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _pageMessage.isEmpty
                  ? 'নিবন্ধনের আগে সার্ভার থেকে শর্তাবলি পাওয়া প্রয়োজন।'
                  : _pageMessage,
              style: const TextStyle(color: Colors.black87),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _loadTerms,
                icon: const Icon(Icons.refresh),
                label: const Text('আবার চেষ্টা করুন'),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7E9EE)),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            value: _termsAccepted,
            onChanged: _registering
                ? null
                : (value) {
                    setState(() {
                      _termsAccepted = value ?? false;
                    });
                  },
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: const Color(0xFFD92332),
            title: const Text(
              'আমি Terms & Conditions পড়েছি এবং সম্মত আছি।',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            subtitle: Text(
              'সংস্করণ: $_termsVersion',
              style: const TextStyle(fontSize: 11),
            ),
          ),
          const Divider(height: 1),
          ExpansionTile(
            leading: const Icon(
              Icons.description_outlined,
              color: Color(0xFFD92332),
            ),
            title: const Text(
              'Terms & Conditions পড়ুন',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 260),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _termsContent,
                    style: const TextStyle(height: 1.55, fontSize: 13),
                  ),
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
    final canRegister = !_registering &&
        !_loadingTerms &&
        _termsVersion.isNotEmpty &&
        _termsContent.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'নতুন অ্যাকাউন্ট',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFFD92332),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
            children: [
              Center(
                child: Container(
                  height: 76,
                  width: 76,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.volunteer_activism_rounded,
                    color: Color(0xFFD92332),
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'RedLoop Pro-তে যোগ দিন',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF20232A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'রক্তদানের মাধ্যমে মানুষের পাশে দাঁড়ান।',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 26),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: _decoration('পূর্ণ নাম', Icons.person_outline),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'আপনার নাম লিখুন।'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: _decoration('ইমেইল', Icons.email_outlined),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return 'ইমেইল লিখুন।';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                      .hasMatch(email)) {
                    return 'সঠিক ইমেইল ঠিকানা লিখুন।';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: _decoration('মোবাইল নম্বর', Icons.phone_outlined),
                validator: (value) {
                  final phone = value?.trim() ?? '';
                  if (phone.isEmpty) return 'মোবাইল নম্বর লিখুন।';
                  if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(phone)) {
                    return '১০ থেকে ১৫ সংখ্যার সঠিক নম্বর লিখুন।';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: _decoration(
                  'পাসওয়ার্ড',
                  Icons.lock_outline,
                  suffixIcon: IconButton(
                    onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword,
                    ),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'পাসওয়ার্ড লিখুন।';
                  }
                  if (value.length < 8) {
                    return 'পাসওয়ার্ড কমপক্ষে ৮ অক্ষরের হতে হবে।';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: _decoration(
                  'পাসওয়ার্ড নিশ্চিত করুন',
                  Icons.lock_reset_outlined,
                  suffixIcon: IconButton(
                    onPressed: () => setState(
                      () => _obscureConfirmPassword =
                          !_obscureConfirmPassword,
                    ),
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'পাসওয়ার্ড আবার লিখুন।';
                  }
                  if (value != _passwordController.text) {
                    return 'দুটি পাসওয়ার্ড এক নয়।';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _buildTermsCard(),
              const SizedBox(height: 22),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: canRegister ? _register : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD92332),
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _registering
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'অ্যাকাউন্ট তৈরি করুন',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'নিবন্ধনের সময় সার্ভারে থাকা সর্বশেষ Terms & Conditions গ্রহণ করতে হবে।',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
