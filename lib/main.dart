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
  final uri = Uri.parse(baseUrl + "?action=" + action);
  final res = await http.post(uri, headers: {"X-API-KEY": apiKey}, body: body).timeout(const Duration(seconds: 15));
  return jsonDecode(res.body);
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
      final res = await http.get(Uri.parse(baseUrl + "?action=settings"), headers: {"X-API-KEY": apiKey}).timeout(const Duration(seconds: 10));
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
      final res = await http.get(Uri.parse(baseUrl + "?action=ping"), headers: {"X-API-KEY": apiKey}).timeout(const Duration(seconds: 10));
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
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: loading ? null : doLogin, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: Text(loading ? "Please wait..." : "Login", style: const TextStyle(color: Colors.white)))),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: testPing, child: const Text("Test Subdomain Connection")),
            const SizedBox(height: 12),
            TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())), child: const Text("New User? Register Here", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
            const SizedBox(height: 10),
            SelectableText(msg, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            const Text("Test Account: 01700000000 / password", style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  final String logoUrl;
  final String notice;
  const HomeScreen({super.key, required this.user, required this.logoUrl, required this.notice});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("RedLoop Home"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen(logoUrl: logoUrl, notice: notice))), icon: const Icon(Icons.logout)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Image.network(logoUrl, width: 100, height: 100)),
            const SizedBox(height: 10),
            Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)), child: Text("Notice: " + notice, style: const TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(height: 20),
            Text("Welcome, " + user['name'].toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text("Phone: " + user['phone'].toString()),
            Text("Role: " + user['role'].toString()),
            const SizedBox(height: 20),
            Card(child: ListTile(leading: const Icon(Icons.bloodtype, color: Colors.red), title: const Text("Find Blood Donors"), subtitle: const Text("Filter by blood group"), trailing: const Icon(Icons.arrow_forward_ios, size: 16), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DonorListScreen())))),
            Card(child: ListTile(leading: const Icon(Icons.emergency, color: Colors.red), title: const Text("Request Blood"), subtitle: const Text("Need blood in emergency?"), trailing: const Icon(Icons.arrow_forward_ios, size: 16), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BloodRequestScreen())))),
            Card(child: ListTile(leading: const Icon(Icons.person, color: Colors.red), title: const Text("My Profile"), subtitle: Text("User ID: " + user['id'].toString()), onTap: () {})),
          ],
        ),
      ),
    );
  }
}
