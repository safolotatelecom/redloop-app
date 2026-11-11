// =====================================================
// RedLoop Pro - Full App - main.dart
// Server: https://redloop.safolota.com/api.php
// Features: Login, Register, Eye Password, Fingerprint,
// Remember Me, Donor List, Notification Loop, Request,
// Received, Rating, Help Ticket, Admin
// =====================================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

const String BASE_URL = "https://redloop.safolota.com/api.php";

void main() {
  runApp(const RedLoopApp());
}

class RedLoopApp extends StatelessWidget {
  const RedLoopApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RedLoop Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        primaryColor: const Color(0xFFD32F2F),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFD32F2F),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD32F2F),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// =====================================================
// API SERVICE
// =====================================================
class ApiService {
  static Future<Map<String, dynamic>> call(String action, Map<String, String> params) async {
    try {
      final res = await http.post(
        Uri.parse("$BASE_URL?action=$action"),
        body: params,
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(res.body);
    } catch (e) {
      return {"success": false, "message": "Server Error: $e"};
    }
  }

  static Future<Map<String, dynamic>> get(String action, Map<String, String> params) async {
    try {
      String q = params.entries.map((e) => "${e.key}=${Uri.encodeComponent(e.value)}").join("&");
      final res = await http.get(Uri.parse("$BASE_URL?action=$action&$q")).timeout(const Duration(seconds: 15));
      return jsonDecode(res.body);
    } catch (e) {
      return {"success": false, "message": "Server Error: $e"};
    }
  }
}

// =====================================================
// SPLASH + AUTO LOGIN
// =====================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    await Future.delayed(const Duration(seconds: 2));
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString("phone");
    final pass = prefs.getString("password");
    final remember = prefs.getBool("remember") ?? false;
    if (!mounted) return;
    if (remember && phone != null && pass != null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(phone: phone)));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD32F2F),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text("🩸", style: TextStyle(fontSize: 80)),
            SizedBox(height: 10),
            Text("RedLoop Pro", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("রক্ত দিন, জীবন বাঁচান", style: TextStyle(color: Colors.white70, fontSize: 16)),
            SizedBox(height: 30),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// LOGIN SCREEN - Password Eye + Remember + Fingerprint
// =====================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _showPassword = false; // 👁️ Eye - Login Password
  bool _remember = true;
  bool _loading = false;
  final LocalAuthentication _auth = LocalAuthentication();

  Future<void> _login() async {
    if (_phoneCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Phone ও Password দিন")));
      return;
    }
    setState(() => _loading = true);
    final res = await ApiService.call("login", {
      "phone": _phoneCtrl.text.trim(),
      "password": _passCtrl.text.trim(),
    });
    setState(() => _loading = false);
    if (res['success'] == true) {
      final prefs = await SharedPreferences.getInstance();
      if (_remember) {
        await prefs.setString("phone", _phoneCtrl.text.trim());
        await prefs.setString("password", _passCtrl.text.trim());
        await prefs.setBool("remember", true);
      } else {
        await prefs.setBool("remember", false);
      }
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(phone: _phoneCtrl.text.trim())));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? "Login Failed")));
    }
  }

  Future<void> _fingerprintLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString("phone");
    final pass = prefs.getString("password");
    if (phone == null || pass == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("আগে একবার Password দিয়ে Login করুন")));
      return;
    }
    try {
      final ok = await _auth.authenticate(localizedReason: "RedLoop Pro তে Login করতে Fingerprint দিন");
      if (ok) {
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(phone: phone)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fingerprint Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 50),
            const Text("🩸", style: TextStyle(fontSize: 70)),
            const Text("RedLoop Pro", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFD32F2F))),
            const Text("Login করুন", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: "Phone Number", prefixIcon: Icon(Icons.phone)),
            ),
            const SizedBox(height: 14),
            // ===== PASSWORD + EYE =====
            TextField(
              controller: _passCtrl,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                labelText: "Password",
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, color: Colors.red),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Checkbox(value: _remember, onChanged: (v) => setState(() => _remember = v ?? true)),
                const Text("Remember Me"),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                  child: const Text("Forgot Password?"),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text("Login", style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _fingerprintLogin,
                icon: const Icon(Icons.fingerprint, color: Colors.red),
                label: const Text("Fingerprint দিয়ে Login"),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Account নেই? "),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  child: const Text("Register করুন"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// REGISTER SCREEN - Password Eye + Confirm Eye
// =====================================================
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String _blood = "A+";
  String _district = "Dhaka";
  bool _showPassword = false; // 👁️ Eye - Register Password
  bool _showConfirm = false; // 👁️ Eye - Confirm Password
  bool _loading = false;

  final List<String> bloods = ["A+", "A-", "
