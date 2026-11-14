import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import 'api_helper.dart';
import 'donor_profile_screen.dart';
import 'donor_opportunities_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RedLoopApp());
}

const red = Color(0xFFDC2638);
const dark = Color(0xFF20232B);
const muted = Color(0xFF777D89);
const background = Color(0xFFF7F7FA);

class RedLoopApp extends StatelessWidget {
  const RedLoopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RedLoop Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: red,
          primary: red,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: dark,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE9E9EF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: red, width: 1.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: red,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

String errorMessage(Map<String, dynamic> result) {
  final errors = result['errors'];
  if (errors is Map && errors.isNotEmpty) {
    final first = errors.values.first;
    if (first is List && first.isNotEmpty) {
      return first.first.toString();
    }
  }
  return result['message']?.toString() ?? 'অনুরোধটি সম্পন্ন হয়নি।';
}

Map<String, dynamic> userFrom(Map<String, dynamic> result) {
  final value = result['user'];
  if (value is Map) return Map<String, dynamic>.from(value);
  return result;
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await Future.delayed(const Duration(milliseconds: 700));
    final token = await ApiService.getToken();
    if (!mounted) return;

    if (token == null || token.isEmpty) {
      _openLogin();
      return;
    }

    final result = await ApiService.getCurrentUser();
    if (!mounted) return;

    if (result['success'] == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(user: userFrom(result)),
        ),
      );
    } else {
      await ApiService.clearToken();
      _openLogin();
    }
  }

  void _openLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: red,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const BrandMark(size: 100, light: true),
            const SizedBox(height: 20),
            const Text(
              'RedLoop Pro',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'রক্ত দিন, জীবন বাঁচান',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final identifier = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;
  bool remember = true;
  bool loading = false;

  @override
  void dispose() {
    identifier.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (identifier.text.trim().isEmpty || password.text.isEmpty) {
      showMessage(context, 'ফোন নম্বর/ইমেইল এবং পাসওয়ার্ড দিন।');
      return;
    }

    setState(() => loading = true);
    final result = await ApiService.login(
      identifier: identifier.text.trim(),
      password: password.text,
      rememberMe: remember,
      deviceName: 'RedLoop Pro Mobile',
      platform: 'android',
    );

    if (!mounted) return;
    setState(() => loading = false);

    if (result['success'] == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(user: userFrom(result)),
        ),
      );
    } else {
      showMessage(context, errorMessage(result));
    }
  }

  Future<void> fingerprintLogin() async {
    final token = await ApiService.getToken();
    if (token == null || token.isEmpty) {
      showMessage(context, 'আগে পাসওয়ার্ড দিয়ে একবার Login করুন।');
      return;
    }

    try {
      final auth = LocalAuthentication();
      final available =
          await auth.canCheckBiometrics || await auth.isDeviceSupported();

      if (!available) {
        showMessage(context, 'এই ডিভাইসে বায়োমেট্রিক সুবিধা নেই।');
        return;
      }

      final authenticated = await auth.authenticate(
        localizedReason: 'RedLoop Pro-তে প্রবেশ করতে পরিচয় নিশ্চিত করুন',
      );

      if (!authenticated || !mounted) return;

      setState(() => loading = true);
      final result = await ApiService.getCurrentUser();
      if (!mounted) return;
      setState(() => loading = false);

      if (result['success'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(user: userFrom(result)),
          ),
        );
      } else {
        await ApiService.clearToken();
        showMessage(context, 'সেশন শেষ হয়েছে। আবার Login করুন।');
      }
    } catch (_) {
      if (mounted) showMessage(context, 'বায়োমেট্রিক যাচাই করা যায়নি।');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BrandHeader(),
                const SizedBox(height: 38),
                const Text(
                  'স্বাগতম!',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    color: dark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'আপনার RedLoop অ্যাকাউন্টে প্রবেশ করুন',
                  style: TextStyle(color: muted),
                ),
                const SizedBox(height: 26),
                TextField(
                  controller: identifier,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'ফোন নম্বর অথবা ইমেইল',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: password,
                  obscureText: obscure,
                  onSubmitted: (_) => loading ? null : login(),
                  decoration: InputDecoration(
                    labelText: 'পাসওয়ার্ড',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => obscure = !obscure),
                      icon: Icon(
                        obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Checkbox(
                      value: remember,
                      activeColor: red,
                      onChanged: (value) {
                        setState(() => remember = value ?? true);
                      },
                    ),
                    const Text('Remember Me'),
                    const Spacer(),
                    IconButton(
                      onPressed: fingerprintLogin,
                      icon: const Icon(Icons.fingerprint, color: red),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: loading ? null : login,
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Login করুন'),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('নতুন ব্যবহারকারী? '),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'অ্যাকাউন্ট তৈরি করুন',
                        style: TextStyle(
                          color: red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();

  bool acceptedTerms = false;
  bool loading = false;
  bool obscure = true;
  String termsVersion = '1.0';
  String termsText = 'শর্তাবলি লোড করা হচ্ছে...';

  @override
  void initState() {
    super.initState();
    loadTerms();
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> loadTerms() async {
    final result = await ApiService.get('/terms', authenticated: false);
    if (!mounted) return;

    if (result['success'] == true) {
      termsVersion = result['terms_version']?.toString() ?? '1.0';
      termsText = result['terms']?.toString() ??
          result['content']?.toString() ??
          'RedLoop Pro ব্যবহারের শর্তাবলি প্রযোজ্য।';
    } else {
      termsText = 'শর্তাবলি এখন লোড করা যাচ্ছে না।';
    }
    setState(() {});
  }

  Future<void> showTerms() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ব্যবহারের শর্তাবলি'),
        content: SingleChildScrollView(child: Text(termsText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('বন্ধ করুন'),
          ),
        ],
      ),
    );
  }

  Future<void> register() async {
    if (name.text.trim().isEmpty ||
        email.text.trim().isEmpty ||
        phone.text.trim().isEmpty ||
        password.text.isEmpty ||
        confirmPassword.text.isEmpty) {
      showMessage(context, 'সব তথ্য পূরণ করুন।');
      return;
    }

    if (password.text != confirmPassword.text) {
      showMessage(context, 'দুটি পাসওয়ার্ড মিলছে না।');
      return;
    }

    if (!acceptedTerms) {
      showMessage(context, 'শর্তাবলি গ্রহণ করতে হবে।');
      return;
    }

    setState(() => loading = true);
    final result = await ApiService.register(
      name: name.text.trim(),
      email: email.text.trim(),
      phone: phone.text.trim(),
      password: password.text,
      passwordConfirmation: confirmPassword.text,
      termsAccepted: true,
      termsVersion: termsVersion,
    );

    if (!mounted) return;
    setState(() => loading = false);

    if (result['success'] == true) {
      final token = await ApiService.getToken();
      if (!mounted) return;

      if (token != null && token.isNotEmpty) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(user: userFrom(result)),
          ),
          (_) => false,
        );
      } else {
        showMessage(context, 'রেজিস্ট্রেশন সফল। এখন Login করুন।');
        Navigator.pop(context);
      }
    } else {
      showMessage(context, errorMessage(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('নতুন অ্যাকাউন্ট')),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const Text(
            'RedLoop Pro-তে যোগ দিন',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: dark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'একটি অ্যাকাউন্ট দিয়ে রক্ত চাইতে ও রক্ত দিতে পারবেন।',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'আপনার নাম',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 13),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'ইমেইল',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 13),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'মোবাইল নম্বর',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 13),
          TextField(
            controller: password,
            obscureText: obscure,
            decoration: InputDecoration(
              labelText: 'পাসওয়ার্ড',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => setState(() => obscure = !obscure),
                icon: Icon(
                  obscure ? Icons.visibility : Icons.visibility_off,
                ),
              ),
            ),
          ),
          const SizedBox(height: 13),
          TextField(
            controller: confirmPassword,
            obscureText: obscure,
            decoration: const InputDecoration(
              labelText: 'পাসওয়ার্ড নিশ্চিত করুন',
              prefixIcon: Icon(Icons.lock_reset),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: acceptedTerms,
                activeColor: red,
                onChanged: (value) {
                  setState(() => acceptedTerms = value ?? false);
                },
              ),
              const Expanded(
                child: Text('আমি ব্যবহারের শর্তাবলি গ্রহণ করছি।'),
              ),
              TextButton(onPressed: showTerms, child: const Text('পড়ুন')),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: loading ? null : register,
            child: loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('অ্যাকাউন্ট তৈরি করুন'),
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(user: widget.user),
      const MyRequestsPage(),
      const NotificationsPage(),
      ProfilePage(user: widget.user),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: selectedIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
        },
        backgroundColor: Colors.white,
        indicatorColor: red.withOpacity(0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: red),
            label: 'হোম',
          ),
          NavigationDestination(
            icon: Icon(Icons.bloodtype_outlined),
            selectedIcon: Icon(Icons.bloodtype, color: red),
            label: 'অনুরোধ',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications, color: red),
            label: 'নোটিফিকেশন',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: red),
            label: 'প্রোফাইল',
          ),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  final Map<String, dynamic> user;

  const DashboardPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final name = user['name']?.toString() ?? 'ব্যবহারকারী';

    return RefreshIndicator(
      color: red,
      onRefresh: () async {
        await ApiService.getCurrentUser();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Row(
            children: [
              const BrandMark(size: 46),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RedLoop Pro',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: dark,
                      ),
                    ),
                    Text(
                      'রক্ত দিন, জীবন বাঁচান',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.notifications_none, size: 27),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE52F43), Color(0xFFB9182B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: red.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'স্বাগতম, $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  'আপনার একটি ছোট উদ্যোগ\nবাঁচাতে পারে একটি জীবন।',
                  style: TextStyle(
                    color: Colors.white,
                    height: 1.6,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: red,
                    minimumSize: const Size(190, 48),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateRequestPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('রক্তের অনুরোধ করুন'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 27),
          const Text(
            'আপনি কী করতে চান?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: dark,
            ),
          ),
          const SizedBox(height: 15),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 13,
            crossAxisSpacing: 13,
            childAspectRatio: 1.22,
            children: [
              ActionTile(
                icon: Icons.bloodtype,
                title: 'রক্তের অনুরোধ',
                subtitle: 'জরুরি রক্ত প্রয়োজন',
                color: red,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateRequestPage(),
                  ),
                ),
              ),
              ActionTile(
                icon: Icons.volunteer_activism_rounded,
                title: 'রক্ত দিতে চাই',
                subtitle: 'আপনার গ্রুপের অনুরোধ দেখুন',
                color: const Color(0xFFD92344),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DonorOpportunitiesScreen(),
                  ),
                ),
              ),
              ActionTile(
                icon: Icons.person_pin_circle_outlined,
                title: 'ডোনার প্রোফাইল',
                subtitle: 'রক্তদানের তথ্য সেট করুন',
                color: const Color(0xFF168C78),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DonorProfileScreen(),
                  ),
                ),
              ),
              ActionTile(
                icon: Icons.list_alt,
                title: 'আমার অনুরোধ',
                subtitle: 'অনুরোধের অবস্থা',
                color: const Color(0xFF5366C9),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MyRequestsPage(),
                  ),
                ),
              ),
              ActionTile(
                icon: Icons.notifications_active_outlined,
                title: 'নোটিফিকেশন',
                subtitle: 'নতুন আপডেট',
                color: const Color(0xFF9B62B6),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsPage(),
                  ),
                ),
              ),
              ActionTile(
                icon: Icons.support_agent,
                title: 'সহায়তা',
                subtitle: 'সমস্যা জানাতে',
                color: const Color(0xFF5366C9),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpPage()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              children: [
                Icon(Icons.favorite, color: red, size: 28),
                SizedBox(width: 13),
                Expanded(
                  child: Text(
                    'রক্তদান করুন, মানুষের পাশে দাঁড়ান। আপনার সহযোগিতাই হতে পারে কারও নতুন জীবন।',
                    style: TextStyle(
                      color: dark,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CreateRequestPage extends StatefulWidget {
  const CreateRequestPage({super.key});

  @override
  State<CreateRequestPage> createState() => _CreateRequestPageState();
}

class _CreateRequestPageState extends State<CreateRequestPage> {
  final hospital = TextEditingController();
  final district = TextEditingController();
  final area = TextEditingController();
  final condition = TextEditingController();

  String bloodGroup = 'O+';
  int bags = 1;
  DateTime neededAt = DateTime.now().add(const Duration(hours: 2));
  bool loading = false;

  @override
  void dispose() {
    hospital.dispose();
    district.dispose();
    area.dispose();
    condition.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (hospital.text.trim().isEmpty ||
        district.text.trim().isEmpty ||
        area.text.trim().isEmpty) {
      showMessage(context, 'হাসপাতাল, জেলা ও এলাকা পূরণ করুন।');
      return;
    }

    setState(() => loading = true);
    final result = await ApiService.post(
      '/blood-requests',
      body: {
        'blood_group': bloodGroup,
        'bags': bags,
        'hospital_name': hospital.text.trim(),
        'district': district.text.trim(),
        'area': area.text.trim(),
        'needed_at': neededAt.toIso8601String(),
        'patient_condition': condition.text.trim(),
      },
    );

    if (!mounted) return;
    setState(() => loading = false);

    if (result['success'] == true) {
      showMessage(context, 'রক্তের অনুরোধ জমা হয়েছে।');
      Navigator.pop(context, true);
    } else {
      showMessage(context, errorMessage(result));
    }
  }

  Future<void> chooseDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: neededAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(neededAt),
    );
    if (time == null) return;

    setState(() {
      neededAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('রক্তের অনুরোধ')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'রক্তের প্রয়োজনীয় তথ্য দিন',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: dark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'সঠিক তথ্য দিলে উপযুক্ত ডোনার খুঁজে পাওয়া সহজ হবে।',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 22),
          const FieldLabel('রক্তের গ্রুপ'),
          DropdownButtonFormField<String>(
            value: bloodGroup,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.bloodtype, color: red),
            ),
            items: const [
              'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
            ].map((group) {
              return DropdownMenuItem(value: group, child: Text(group));
            }).toList(),
            onChanged: (value) {
              if (value != null) setState(() => bloodGroup = value);
            },
          ),
          const SizedBox(height: 16),
          const FieldLabel('কত ব্যাগ রক্ত প্রয়োজন?'),
          DropdownButtonFormField<int>(
            value: bags,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.water_drop_outlined),
            ),
            items: List.generate(10, (index) => index + 1).map((value) {
              return DropdownMenuItem(
                value: value,
                child: Text('$value ব্যাগ'),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) setState(() => bags = value);
            },
          ),
          const SizedBox(height: 16),
          const FieldLabel('হাসপাতাল / চিকিৎসাকেন্দ্র'),
          TextField(
            controller: hospital,
            decoration: const InputDecoration(
              hintText: 'হাসপাতালের নাম',
              prefixIcon: Icon(Icons.local_hospital_outlined),
            ),
          ),
          const SizedBox(height: 16),
          const FieldLabel('জেলা'),
          TextField(
            controller: district,
            decoration: const InputDecoration(
              hintText: 'জেলার নাম',
              prefixIcon: Icon(Icons.location_city),
            ),
          ),
          const SizedBox(height: 16),
          const FieldLabel('এলাকা'),
          TextField(
            controller: area,
            decoration: const InputDecoration(
              hintText: 'এলাকা / থানা',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 16),
          const FieldLabel('রক্ত কখন প্রয়োজন?'),
          OutlinedButton.icon(
            onPressed: chooseDateTime,
            icon: const Icon(Icons.calendar_month, color: red),
            label: Text(
              '${neededAt.day}/${neededAt.month}/${neededAt.year} '
              '${TimeOfDay.fromDateTime(neededAt).format(context)}',
              style: const TextStyle(color: dark),
            ),
          ),
          const SizedBox(height: 16),
          const FieldLabel('রোগীর অবস্থা (ঐচ্ছিক)'),
          TextField(
            controller: condition,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'রোগীর অবস্থা সংক্ষেপে লিখুন',
            ),
          ),
          const SizedBox(height: 25),
          ElevatedButton(
            onPressed: loading ? null : submit,
            child: loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('রক্তের অনুরোধ জমা দিন'),
          ),
        ],
      ),
    );
  }
}

class MyRequestsPage extends StatefulWidget {
  const MyRequestsPage({super.key});

  @override
  State<MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends State<MyRequestsPage> {
  bool loading = true;
  List<dynamic> requests = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final result = await ApiService.get('/blood-requests');
    if (!mounted) return;

    final raw =
        result['requests'] ?? result['data'] ?? result['blood_requests'];

    if (result['success'] == true) {
      if (raw is List) {
        requests = raw;
      } else if (raw is Map && raw['data'] is List) {
        requests = raw['data'];
      } else {
        requests = [];
      }
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('আমার রক্তের অনুরোধ'),
        actions: [
          IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: red))
          : requests.isEmpty
              ? EmptyState(
                  icon: Icons.bloodtype_outlined,
                  title: 'এখনো কোনো অনুরোধ নেই',
                  subtitle: 'প্রয়োজনে নতুন রক্তের অনুরোধ তৈরি করুন।',
                  buttonText: 'নতুন অনুরোধ',
                  onPressed: () async {
                    final created = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateRequestPage(),
                      ),
                    );
                    if (created == true) load();
                  },
                )
              : RefreshIndicator(
                  color: red,
                  onRefresh: load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      return RequestCard(
                        item: Map<String, dynamic>.from(
                          requests[index] as Map,
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: red,
        foregroundColor: Colors.white,
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateRequestPage(),
            ),
          );
          if (created == true) load();
        },
        icon: const Icon(Icons.add),
        label: const Text('অনুরোধ'),
      ),
    );
  }
}

class RequestCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const RequestCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final group = item['blood_group']?.toString() ?? '--';
    final status = item['status']?.toString() ?? 'open';
    final place = item['hospital_name']?.toString() ?? 'হাসপাতাল';
    final district = item['district']?.toString() ?? '';
    final area = item['area']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: red.withOpacity(0.09),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                group,
                style: const TextStyle(
                  color: red,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: dark,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$district, $area',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 5),
                Text(
                  '${item['bags'] ?? 1} ব্যাগ • $status',
                  style: const TextStyle(
                    color: red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool loading = true;
  bool markingAll = false;
  int unreadCount = 0;
  List<dynamic> notifications = [];
  final Set<String> updatingIds = {};
  final Set<String> openingIds = {};

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) setState(() => loading = true);

    final result = await ApiService.get('/notifications');
    if (!mounted) return;

    if (result['success'] == true) {
      final raw = result['notifications'] ?? result['data'];

      if (raw is List) {
        notifications = raw;
      } else if (raw is Map && raw['data'] is List) {
        notifications = raw['data'];
      } else {
        notifications = [];
      }

      unreadCount = int.tryParse(
            result['unread_count']?.toString() ?? '',
          ) ??
          notifications.where((item) {
            return item is Map && item['read_at'] == null;
          }).length;
    } else if (notifications.isEmpty) {
      showMessage(context, errorMessage(result));
    }

    setState(() => loading = false);
  }

  String formatDateTime(dynamic value) {
    if (value == null) return '';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return '';

    final local = date.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}  $hour:$minute $period';
  }

  String? _getActionRequestId(Map<String, dynamic> item) {
    if (item['type']?.toString() != 'blood_request') {
      return null;
    }

    final rawData = item['data'];
    if (rawData is! Map) return null;

    final data = Map<String, dynamic>.from(rawData);
    final value = data['blood_request_id'] ??
        data['bloodRequestId'];

    final requestId = value?.toString().trim();

    if (requestId == null || requestId.isEmpty) {
      return null;
    }

    return requestId;
  }

  Future<void> openNotification(Map<String, dynamic> item) async {
    final requestId = _getActionRequestId(item);

    // যেসব নোটিফিকেশনে কোনো Action নেই, সেগুলোতে কিছুই খুলবে না।
    if (requestId == null) return;

    final notificationId = item['id']?.toString() ?? '';

    if (notificationId.isNotEmpty &&
        item['read_at'] == null &&
        !openingIds.contains(notificationId)) {
      setState(() => openingIds.add(notificationId));

      final result = await ApiService.patch(
        '/notifications/$notificationId/read',
      );

      if (!mounted) return;

      setState(() {
        openingIds.remove(notificationId);
      });

      if (result['success'] == true) {
        item['read_at'] = DateTime.now().toIso8601String();

        if (unreadCount > 0) {
          unreadCount--;
        }

        setState(() {});
      } else {
        showMessage(
          context,
          'নোটিফিকেশন Read করা যায়নি। অনুরোধটি খোলা হচ্ছে।',
        );
      }
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DonorOpportunitiesScreen(
          requestId: requestId,
        ),
      ),
    );
  }

  Future<void> markRead(String id) async {
    if (id.isEmpty || updatingIds.contains(id)) return;

    setState(() => updatingIds.add(id));

    final result = await ApiService.patch('/notifications/$id/read');

    if (!mounted) return;
    setState(() => updatingIds.remove(id));

    if (result['success'] == true) {
      await load();
    } else {
      showMessage(context, errorMessage(result));
    }
  }

  Future<void> markAllRead() async {
    if (unreadCount == 0 || markingAll) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('সব নোটিফিকেশন পড়া হয়েছে?'),
        content: const Text(
          'সব অপঠিত নোটিফিকেশন পড়া হিসেবে চিহ্নিত করতে চান?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('না'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('হ্যাঁ, সব পড়ুন'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => markingAll = true);

    final result = await ApiService.patch('/notifications/read-all');

    if (!mounted) return;
    setState(() => markingAll = false);

    if (result['success'] == true) {
      await load();
      if (mounted) {
        showMessage(context, 'সব নোটিফিকেশন পড়া হয়েছে।');
      }
    } else {
      showMessage(context, errorMessage(result));
    }
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE52F43), Color(0xFFB9182B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: red.withOpacity(0.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'আপডেট ও নোটিফিকেশন',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  unreadCount == 0
                      ? 'আপনি সব নোটিফিকেশন পড়ে ফেলেছেন'
                      : '$unreadCountটি অপঠিত নোটিফিকেশন',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                  color: red,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    final isRead = item['read_at'] != null;
    final isUpdating = updatingIds.contains(id);
    final isOpening = openingIds.contains(id);
    final title = item['title']?.toString() ?? 'নোটিফিকেশন';
    final body = item['body']?.toString() ?? '';
    final date = formatDateTime(item['created_at']);
    final hasAction = _getActionRequestId(item) != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : const Color(0xFFFFF5F6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isRead ? const Color(0xFFEDEDF1) : const Color(0xFFF4C9CF),
        ),
        boxShadow: [
          BoxShadow(
            color: dark.withOpacity(0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: hasAction && !isOpening
              ? () => openNotification(item)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isRead
                        ? const Color(0xFFF0F1F4)
                        : red.withOpacity(0.11),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.bloodtype_rounded,
                    color: isRead ? muted : red,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                color: dark,
                                fontSize: 14,
                                fontWeight:
                                    isRead ? FontWeight.w600 : FontWeight.w900,
                                height: 1.35,
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              margin: const EdgeInsets.only(left: 7, top: 5),
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: red,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          body,
                          style: const TextStyle(
                            color: muted,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                      if (hasAction) ...[
                        const SizedBox(height: 7),
                        const Row(
                          children: [
                            Icon(
                              Icons.touch_app_outlined,
                              color: red,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'অনুরোধ দেখতে ট্যাপ করুন',
                              style: TextStyle(
                                color: red,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: muted,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              date.isEmpty ? 'সময় উল্লেখ নেই' : date,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          if (isRead)
                            const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.done_all_rounded,
                                  size: 15,
                                  color: Color(0xFF168C78),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'পড়া হয়েছে',
                                  style: TextStyle(
                                    color: Color(0xFF168C78),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          else
                            TextButton(
                              onPressed: id.isEmpty || isUpdating || isOpening
                                  ? null
                                  : () => markRead(id),
                              style: TextButton.styleFrom(
                                foregroundColor: red,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: isUpdating || isOpening
                                  ? const SizedBox(
                                      width: 15,
                                      height: 15,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: red,
                                      ),
                                    )
                                  : const Text(
                                      'পড়ে ফেলুন',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'নোটিফিকেশন',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: markingAll ? null : markAllRead,
              icon: markingAll
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: red,
                      ),
                    )
                  : const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('সব পড়ুন'),
            ),
          IconButton(
            tooltip: 'রিফ্রেশ',
            onPressed: loading ? null : load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: red),
            )
          : RefreshIndicator(
              color: red,
              onRefresh: load,
              child: notifications.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 35),
                        EmptyState(
                          icon: Icons.notifications_none_rounded,
                          title: 'কোনো নোটিফিকেশন নেই',
                          subtitle: 'নতুন আপডেট এলে এখানে দেখা যাবে।',
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: notifications.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) return _buildHeader();

                        final value = notifications[index - 1];
                        if (value is! Map) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildNotificationCard(
                            Map<String, dynamic>.from(value),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  final Map<String, dynamic> user;

  const ProfilePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final name = user['name']?.toString() ?? 'ব্যবহারকারী';
    final phone = user['phone']?.toString() ?? '';
    final email = user['email']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('আমার প্রোফাইল')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 15),
          const Center(child: BrandMark(size: 82)),
          const SizedBox(height: 15),
          Center(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: dark,
              ),
            ),
          ),
          const SizedBox(height: 5),
          const Center(
            child: Text(
              'RedLoop Pro Member',
              style: TextStyle(color: muted),
            ),
          ),
          const SizedBox(height: 28),
          ProfileInfo(icon: Icons.phone, label: 'মোবাইল', value: phone),
          ProfileInfo(icon: Icons.email, label: 'ইমেইল', value: email),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DonorProfileScreen(),
                ),
              );
            },
            icon: const Icon(Icons.bloodtype, color: red),
            label: const Text('ডোনার প্রোফাইল ও লোকেশন'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpPage()),
              );
            },
            icon: const Icon(Icons.support_agent),
            label: const Text('সহায়তা কেন্দ্র'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: dark),
            onPressed: () async {
              final result = await ApiService.logout();
              if (!context.mounted) return;

              if (result['success'] == true) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LoginScreen(),
                  ),
                  (_) => false,
                );
              } else {
                showMessage(context, errorMessage(result));
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  final subject = TextEditingController();
  final message = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    subject.dispose();
    message.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (subject.text.trim().isEmpty || message.text.trim().isEmpty) {
      showMessage(context, 'বিষয় ও বিস্তারিত লিখুন।');
      return;
    }

    setState(() => loading = true);
    final result = await ApiService.post(
      '/help-tickets',
      body: {
        'subject': subject.text.trim(),
        'message': message.text.trim(),
      },
    );

    if (!mounted) return;
    setState(() => loading = false);

    if (result['success'] == true) {
      showMessage(context, 'আপনার সহায়তা অনুরোধ জমা হয়েছে।');
      Navigator.pop(context);
    } else {
      showMessage(context, errorMessage(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('সহায়তা কেন্দ্র')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'কীভাবে সাহায্য করতে পারি?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: dark,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: subject,
            decoration: const InputDecoration(
              labelText: 'সমস্যার বিষয়',
              prefixIcon: Icon(Icons.subject),
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: message,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'বিস্তারিত লিখুন',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: loading ? null : submit,
            child: loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('অনুরোধ জমা দিন'),
          ),
        ],
      ),
    );
  }
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        BrandMark(size: 88),
        SizedBox(height: 15),
        Text(
          'RedLoop Pro',
          style: TextStyle(
            fontSize: 29,
            fontWeight: FontWeight.w900,
            color: red,
          ),
        ),
        SizedBox(height: 5),
        Text('রক্ত দিন, জীবন বাঁচান', style: TextStyle(color: muted)),
      ],
    );
  }
}

class BrandMark extends StatelessWidget {
  final double size;
  final bool light;

  const BrandMark({
    super.key,
    required this.size,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: light ? Colors.white : red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(
        Icons.bloodtype_rounded,
        color: red,
        size: size * 0.72,
      ),
    );
  }
}

class ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const ActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: dark,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  final String text;

  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: dark,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class ProfileInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const ProfileInfo({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: red),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty ? 'তথ্য নেই' : value,
                  style: const TextStyle(
                    color: dark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonText;
  final VoidCallback? onPressed;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonText,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58, color: red.withOpacity(0.55)),
            const SizedBox(height: 15),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: dark,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, height: 1.5),
            ),
            if (buttonText != null && onPressed != null) ...[
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: onPressed,
                child: Text(buttonText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

    
  }
}
