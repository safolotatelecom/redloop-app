import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'screens/register.dart' hide baseUrl, apiKey;
import 'screens/donor_list.dart' hide baseUrl, apiKey;
import 'screens/blood_request.dart' hide baseUrl, apiKey;

void main() {
  runApp(const RedLoopApp());
}

const String baseUrl = "https://redloop.safolota.com/api.php";
const String apiKey = "redloop2026secure";
const String defaultLogo = "https://redloop.safolota.com/logo.png";

class RedLoopApp extends StatelessWidget {
  const RedLoopApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RedLoop',
      theme: ThemeData(primarySwatch: Colors.red, useMaterial3: true),
      home: const SplashScreen(),
    );
  }
}

Future<Map<String, dynamic>> apiCall(String action, Map<String, String> body) async {
  final uri = Uri.parse("$baseUrl?action=$action");
  final res = await http.post(uri, headers: {"X-API-KEY": apiKey}, body: body).timeout(const Duration(seconds: 15));
  try {
    return jsonDecode(res.body);
  } catch (_) {
    throw Exception("HTTP ${res.statusCode} - Body: ${res.body.substring(0, res.body.length > 200 ? 200 : res.body.length)}");
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  String logoUrl = defaultLogo;
  String notice = "Donate Blood, Save Life";
  String anim = "zoom";
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..forward();
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      final res = await http.get(Uri.parse("$baseUrl?action=settings"), headers: {"X-API-KEY": apiKey}).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        setState(() {
          logoUrl = data['data']['logo_url'] ?? defaultLogo;
          notice = data['data']['notice'] ?? notice;
          anim = data['data']['animation_type'] ?? "zoom";
        });
      }
    } catch (_) {}
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen(logoUrl: logoUrl, notice: notice)));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget logo = Image.network(logoUrl, width: 180, height: 180, errorBuilder: (_, __, ___) => const Icon(Icons.bloodtype, size: 120, color: Colors.red));
    if (anim == "fade") {
      logo = FadeTransition(opacity: _c, child: logo);
    } else if (anim == "rotate") {
      logo = RotationTransition(turns: _c, child: logo);
    } else {
      logo = ScaleTransition(scale: _c, child: logo);
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            logo,
            const SizedBox(height: 20),
            const Text("RedLoop", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 8),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 30), child: Text(notice, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  final String logoUrl;
  final String notice;
  const LoginScreen({super.key, required this.logoUrl, required this.notice});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phone = TextEditingController(text: "01700000000");
  final pass = TextEditingController(text: "password");
  bool loading = false;
  String msg = "";

  Future<void> doLogin() async {
    setState(() { loading = true; msg = "Connecting to server..."; });
    try {
      final r = await apiCall("
