import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'screens/register.dart' hide baseUrl, apiKey;
import 'screens/donor_list.dart' hide baseUrl, apiKey;
import 'screens/blood_request.dart' hide baseUrl, apiKey;
import 'screens/admin_panel.dart';
import 'screens/forgot_password.dart';
import 'screens/change_password.dart';

void main() { runApp(const RedLoopApp()); }

const String baseUrl = "https://redloop.safolota.com/api.php";
const String apiKey = "redloop2026secure";
const String defaultLogo = "https://redloop.safolota.com/logo.png";

String toWhatsAppNumber(String phone) {
  String p = phone.replaceAll("+", "").replaceAll(" ", "");
  if (p.startsWith("01")) p = "880" + p.substring(1);
  return p;
}

class RedLoopApp extends StatelessWidget {
  const RedLoopApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, title: 'RedLoop', theme: ThemeData(primarySwatch: Colors.red, useMaterial3: true), home: const SplashScreen());
  }
}

Future<Map<String, dynamic>> apiCall(String action, Map<String, String> body) async {
  Exception? lastError;
  for (int attempt = 0; attempt < 3; attempt++) {
    try {
      final uri = Uri.parse("$baseUrl?action=$action");
      final res = await http.post(uri, headers: {"X-API-KEY": apiKey}, body: body).timeout(const Duration(seconds: 15));
      return jsonDecode(res.body);
    } catch (e) { lastError = e is Exception ? e : Exception(e.toString()); if (attempt < 2) await Future.delayed(Duration(seconds: attempt + 1)); }
  }
  throw lastError ?? Exception("Cannot connect to server.");
}

Future<bool> checkDns() async {
  try { final r = await InternetAddress.lookup('redloop.safolota.com').timeout(const Duration(seconds: 8)); return r.isNotEmpty; } catch (_) { return false; }
}

class SplashScreen extends StatefulWidget { const SplashScreen({super.key}); @override State<SplashScreen> createState() => _SplashScreenState(); }
class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  String logoUrl = defaultLogo; String notice = "Donate Blood, Save Life"; String anim = "zoom"; late AnimationController _c;
  @override void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..forward(); loadSettings(); }
  Future<void> loadSettings() async {
    try {
      final res = await http.get(Uri.parse("$baseUrl?action=settings"), headers: {"X-API-KEY": apiKey}).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);
      if (data['success'] == true) setState(() { logoUrl = data['data']['logo_url'] ?? defaultLogo; notice = data['data']['notice'] ?? notice; anim = data['data']['animation_type'] ?? "zoom"; });
    } catch (_) {}
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen(logoUrl: logoUrl, notice: notice)));
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    Widget logo = Image.network(logoUrl, width: 180, height: 180, errorBuilder: (_, __, ___) => const Icon(Icons.bloodtype, size: 120, color: Colors.red));
    if (anim == "fade") logo = FadeTransition(opacity: _c, child: logo);
    else if (anim == "rotate") logo = RotationTransition(turns: _c, child: logo);
    else logo = ScaleTransition(scale: _c, child: logo);
    return Scaffold(backgroundColor: Colors.white, body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [logo, const SizedBox(height: 20), const Text("RedLoop", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.red)), const SizedBox(height: 8), Padding(padding: const EdgeInsets.symmetric(horizontal: 30), child: Text(notice, textAlign: TextAlign.center)) ])));
  }
}

class LoginScreen extends StatefulWidget {
  final String logoUrl; final String notice;
  const LoginScreen({super.key, required this.logoUrl, required this.notice});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phone = TextEditingController(text: "01700000000");
  final pass = TextEditingController(text: "password");
  bool loading = false; bool showPass = false; String msg = ""; String adminWa = "8801712345678";
  bool forgotAlreadySent = false;

  @override void initState() { super.initState(); loadAdminWa(); }
  Future<void> loadAdminWa() async {
    try { final res = await http.get(Uri.parse("$baseUrl?action=settings"), headers: {"X-API-KEY": apiKey}); final d = jsonDecode(res.body); if (d['success']==true) setState(() => adminWa = d['data']['admin_whatsapp'] ?? adminWa); } catch(_){}
  }

  Future<void> doLogin() async {
    setState(() { loading = true; msg = "Connecting..."; });
    try {
      final dnsOk = await checkDns();
      if (!dnsOk) { setState(() { msg = "DNS Error: Check A Record / Airplane Mode ON-OFF"; loading = false; }); return; }
      final r = await apiCall("login", {"phone": phone.text.trim(), "password": pass.text.trim()});
      if (r['success'] == true) {
        if (r['is_temp'] == 1 || r['data']['is_temp_password'] == 1) {
          if (!mounted) return; Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChangePasswordScreen(phone: phone.text.trim())));
        } else {
          if (!mounted) return; Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(user: r['data'], logoUrl: widget.logoUrl, notice: widget.notice)));
        }
      } else
