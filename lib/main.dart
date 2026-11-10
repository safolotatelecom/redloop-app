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
      } else { setState(() => msg = "SERVER SAYS: ${r['message']}"); }
    } catch (e) { setState(() => msg = "REAL ERROR: $e"); }
    setState(() => loading = false);
  }

  Future<void> forgotOneClick() async {
    if (phone.text.trim().isEmpty) { setState(() => msg = "আগে ফোন নম্বর লিখুন"); return; }
    final r = await apiCall("forgot_password", {"phone": phone.text.trim()});
    if (r['success'] == true) {
      String wa = r['admin_whatsapp'] ?? adminWa;
      String text = Uri.encodeComponent("Hello RedLoop Admin, I forgot my password. My phone: ${phone.text.trim()}. Please send me a temporary password.");
      final uri = Uri.parse("https://wa.me/${toWhatsAppNumber(wa)}?text=$text");
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
      setState(() => msg = "Request sent! Admin এর WhatsApp এ গেছে। Temp Password পেলে Login করুন।");
    } else { setState(() => msg = r['message']); }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("RedLoop Login"), backgroundColor: Colors.red, foregroundColor: Colors.white),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
        Image.network(widget.logoUrl, width: 120, height: 120, errorBuilder: (_, __, ___) => const Icon(Icons.bloodtype, size: 100, color: Colors.red)),
        const SizedBox(height: 10), Text(widget.notice, textAlign: TextAlign.center), const SizedBox(height: 20),
        TextField(controller: phone, decoration: const InputDecoration(labelText: "Phone Number", border: OutlineInputBorder(), hintText: "017XXXXXXXX"), keyboardType: TextInputType.phone),
        const SizedBox(height: 12),
        TextField(controller: pass, obscureText: !showPass, decoration: InputDecoration(labelText: "Password", border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(showPass ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => showPass = !showPass)))),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerRight, child: TextButton(onPressed: forgotOneClick, child: const Text("Forgot Password? (1 Click WhatsApp)", style: TextStyle(color: Colors.red)))),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: loading ? null : doLogin, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: Text(loading ? "Please wait..." : "Login", style: const TextStyle(color: Colors.white)))),
        const SizedBox(height: 10),
        TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())), child: const Text("Forgot Password - Full Page", style: TextStyle(color: Colors.grey))),
        TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())), child: const Text("New User? Register Here", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        const SizedBox(height: 10), SelectableText(msg, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
        const SizedBox(height: 10), const Text("Test Account: 01700000000 / password", style: TextStyle(color: Colors.grey)),
      ])),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final Map<String, dynamic> user; final String logoUrl; final String notice;
  const HomeScreen({super.key, required this.user, required this.logoUrl, required this.notice});
  @override Widget build(BuildContext context) {
    bool isAdmin = (user['role'] ?? "") == "admin";
    return Scaffold(
      appBar: AppBar(title: const Text("RedLoop Home"), backgroundColor: Colors.red, foregroundColor: Colors.white, actions: [IconButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen(logoUrl: logoUrl, notice: notice))), icon: const Icon(Icons.logout))]),
      body: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Image.network(logoUrl, width: 100, height: 100)), const SizedBox(height: 10),
        Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)), child: Text("Notice: $notice", style: const TextStyle(fontWeight: FontWeight.bold))),
        const SizedBox(height: 20), Text("Welcome, ${user['name']}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), Text("Phone: ${user['phone']}"), Text("Role: ${user['role']}"), const SizedBox(height: 20),
        Card(child: ListTile(leading: const Icon(Icons.bloodtype, color: Colors.red), title: const Text("Find Blood Donors"), subtitle: const Text("Filter by blood group"), trailing: const Icon(Icons.arrow_forward_ios, size: 16), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DonorListScreen())))),
        Card(child: ListTile(leading: const Icon(Icons.emergency, color: Colors.red), title: const Text("Request Blood"), subtitle: const Text("Need blood in emergency?"), trailing: const Icon(Icons.arrow_forward_ios, size: 16), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BloodRequestScreen())))),
        Card(child: ListTile(leading: const Icon(Icons.person, color: Colors.red), title: const Text("My Profile"), subtitle: Text("User ID: ${user['id']}"), onTap: () {})),
        if (isAdmin) Card(color: Colors.red.shade50, child: ListTile(leading: const Icon(Icons.admin_panel_settings, color: Colors.red), title: const Text("Admin Panel", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)), subtitle: const Text("Users, Password Requests, Blood Requests, Settings"), trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen())))),
      ])),
    );
  }
}
