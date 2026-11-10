import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'screens/register.dart' hide baseUrl, apiKey;
import 'screens/donor_list.dart' hide baseUrl, apiKey;
import 'screens/blood_request.dart' hide baseUrl, apiKey;

void main() {
  runApp(const RedLoopApp());
}

const String baseUrl = "https://redloop.safolota.com/api.php";
const String subDomainHost = "redloop.safolota.com";
const String fallbackIp = "144.79.219.130";
const String apiKey = "redloop2026secure";
const String defaultLogo = "https://redloop.safolota.com/logo.png";

Future<String> resolveIp() async {
  try {
    final res = await http.get(Uri.parse("https://dns.google/resolve?name=" + subDomainHost + "&type=A")).timeout(const Duration(seconds: 5));
    final data = jsonDecode(res.body);
    final ans = data['Answer'] as List;
    for (var a in ans) {
      if (a['type'] == 1) return a['data'].toString();
    }
  } catch (_) {}
  return fallbackIp;
}

Future<http.Client> createClient() async {
  final ip = await resolveIp();
  final ioClient = HttpClient();
  ioClient.connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) {
    Future<Socket> getSocket() async {
      final sock = await Socket.connect(ip, 443);
      final secure = await SecureSocket.secure(sock, host: subDomainHost, onBadCertificate: (cert) => true);
      return secure;
    }
    return ConnectionTask.fromSocket(getSocket(), onSocket: (s) async {});
  };
  return IOClient(ioClient);
}

Map<String, String> apiHeaders() {
  return {"X-API-KEY": apiKey, "Host": subDomainHost};
}

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
  final client = await createClient();
  try {
    final uri = Uri.parse(baseUrl + "?action=" + action);
    final res = await client.post(uri, headers: apiHeaders(), body: body).timeout(const Duration(seconds: 15));
    return jsonDecode(res.body);
  } finally {
    client.close();
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
      final client = await createClient();
      final res = await client.get(Uri.parse(baseUrl + "?action=settings"), headers: apiHeaders()).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);
      client.close();
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
    setState(() {
      loading = true;
      msg = "Connecting to server...";
    });
    try {
      final r = await apiCall("login", {"phone": phone.text.trim(), "password": pass.text.trim()});
      if (r['success'] == true) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(user: r['data'], logoUrl: widget.logoUrl, notice: widget.notice)));
      } else {
        setState(() {
          msg = "SERVER SAYS: " + r['message'].toString();
        });
      }
    } catch (e) {
      setState(() {
        msg = "REAL ERROR: " + e.toString();
      });
    }
    setState(() {
      loading = false;
    });
  }

  Future<void> testPing() async {
    setState(() {
      msg = "Testing redloop.safolota.com...";
    });
    try {
      final client = await createClient();
      final res = await client.get(Uri.parse(baseUrl + "?action=ping"), headers: apiHeaders()).timeout(const Duration(seconds: 10));
      client.close();
      setState(() {
        msg = "PING OK - Status: " + res.statusCode.toString() + " - Body: " + res.body;
      });
    } catch (e) {
      setState(() {
        msg = "PING FAILED: " + e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("RedLoop Login"), backgroundColor: Colors.red, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Image.network(widget.logoUrl, width: 120, height: 120, errorBuilder: (_, __, ___) => const Icon(Icons.bloodtype, size: 100, color: Colors.red)),
            const SizedBox(height: 10),
            Text(widget.notice, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextField(controller: phone, decoration: const InputDecoration(labelText: "Phone Number", border: OutlineInputBorder()), keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder())),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(on
