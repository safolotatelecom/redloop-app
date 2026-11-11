import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

// =====================================================
// RedLoop Pro - STEP 2 - GitHub + cPanel - SERVER BASED
// =====================================================
// GitHub = শুধু কোড জমা রাখা
// cPanel = আসল Server - সব Data এখান থেকে আসবে
// অ্যাপে কোনো Data Hardcode নেই, সব api.php থেকে আসবে
// =====================================================
const String API_BASE = "https://redloop.safolota.com/api.php";
// cPanel Database: safolota_redlooppro
// cPanel API File: public_html/api.php

Future<Map<String, dynamic>> apiCall(String action, Map<String, dynamic> body) async {
  try {
    final res = await http.post(
      Uri.parse("$API_BASE?action=$action"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 20));
    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return {"success": false, "message": "Server Error - cPanel Check করুন"};
  } catch (e) {
    return {"success": false, "message": "Network Error - cPanel Server পাওয়া যাচ্ছে না"};
  }
}

void main() => runApp(const RedLoopProApp());

class RedLoopProApp extends StatelessWidget {
  const RedLoopProApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RedLoop Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.red, useMaterial3: true),
      home: const SplashScreen(),
    );
  }
}

// =====================================================
// SPLASH - Remember Login - Token cPanel থেকে Check হবে
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
    _check();
  }

  Future<void> _check() async {
    await Future.delayed(const Duration(seconds: 1));
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('phone') ?? '';
    final token = prefs.getString('token') ?? '';
    final remember = prefs.getBool('remember') ?? false;
    if (!mounted) return;
    if (remember && phone.isNotEmpty && token.isNotEmpty) {
      // cPanel থেকে Token Check
      final r = await apiCall('auto_login', {"phone": phone, "token": token});
      if (r['success'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen(user: Map<String, dynamic>.from(r['data']))),
        );
        return;
      }
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.red,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bloodtype, size: 90, color: Colors.white),
            SizedBox(height: 12),
            Text("RedLoop Pro", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            Text("Donate Blood, Save Life", style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// LOGIN - cPanel থেকে Login হবে
// =====================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  bool _remember = true;
  bool _loading = false;
  String _terms = "";

  @override
  void initState() {
    super.initState();
    _loadTerms();
  }

  // Terms cPanel থেকে আসবে - অ্যাপে লেখা থাকবে না
  Future<void> _loadTerms() async {
    final r = await apiCall('get_settings', {});
    if (r['success'] == true && mounted) {
      setState(() => _terms = (r['data']['terms_conditions'] ?? '').toString());
    }
  }

  void _msg(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _login() async {
    if (_phone.text.trim().isEmpty || _pass.text.isEmpty) {
      _msg("Phone + Password দিন");
      return;
    }
    setState(() => _loading = true);
    // cPanel api.php -> login -> users Table Check
    final r = await apiCall('login', {"phone": _phone.text.trim(), "password": _pass.text});
    setState(() => _loading = false);
    if (r['success'] != true) {
      _msg(r['message'].toString());
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('phone', _phone.text.trim());
    await prefs.setString('token', (r['data']['auth_token'] ?? '').toString());
    await prefs.setBool('remember', _remember);
    await prefs.setBool('has_logged_in_once', true);
    if (!mounted) return;
    if (r['data']['is_temp_password'] == 1) {
      _msg("Temp Password দিয়ে Login করেছেন। এখন Password বদলে নিন।");
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(user: Map<String, dynamic>.from(r['data']))),
    );
  }

  Future<void> _fingerprintLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final hasOnce = prefs.getBool('has_logged_in_once') ?? false;
    if (!hasOnce) {
      _msg("প্রথমবার Phone + Password দিয়ে Login করুন");
      return;
    }
    final auth = LocalAuthentication();
    try {
      final can = await auth.canCheckBiometrics;
      if (!can) {
        _msg("এই ফোনে Fingerprint নেই");
        return;
      }
      final ok = await auth.authenticate(localizedReason: 'RedLoop Pro তে Login করতে Fingerprint দিন');
      if (!ok) return;
      final phone = prefs.getString('phone') ?? '';
      final token = prefs.getString('token') ?? '';
      if (phone.isEmpty || token.isEmpty) {
        _msg("প্রথমবার Phone + Password দিয়ে Login করুন");
        return;
      }
      // Fingerprint মিললেও cPanel থেকে Token Check হবে
      final r = await apiCall('auto_login', {"phone": phone, "token": token});
      if (r['success'] == true && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen(user: Map<String, dynamic>.from(r['data']))),
        );
      } else {
        _msg("Session শেষ, আবার Login করুন");
      }
    } catch (e) {
      _msg("Fingerprint Error");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.bloodtype, size: 80, color: Colors.red),
              const Center(child: Text("RedLoop Pro", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold))),
              const Center(child: Text("Donate Blood, Save Life")),
              const SizedBox(height: 25),
              TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone Number", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone))),
              const SizedBox(height: 12),
              TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock))),
              Row(
                children: [
                  Checkbox(value: _remember, onChanged: (v) => setState(() => _remember = v ?? true)),
                  const Text("Remember Me"),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotScreen())),
                    child: const Text("Forgot Password?"),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: _loading ? null : _login,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(_loading ? "Loading..." : "LOGIN"),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _fingerprintLogin,
                icon: const Icon(Icons.fingerprint, size: 28),
                label: const Text("Fingerprint দিয়ে Login"),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterScreen(terms: _terms))),
                child: const Text("New User? Register Here"),
              ),
              TextButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Terms & Conditions"),
                    content: SingleChildScrollView(child: Text(_terms.isEmpty ? "Terms এখনো সেট করা হয়নি - cPanel থেকে Super Admin সেট করবে" : _terms)),
                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
                  ),
                ),
                child: const Text("Terms & Conditions দেখুন - cPanel থেকে আসবে"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// REGISTER - cPanel users Table এ যাবে
// =====================================================
class RegisterScreen extends StatefulWidget {
  final String terms;
  const RegisterScreen({super.key, required this.terms});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  final _dist = TextEditingController();
  String _bg = 'O+';
  bool _termsOk = false;
  final _bgs = ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'];

  void _msg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _reg() async {
    if (!_termsOk) {
      _msg("আগে Terms & Conditions মেনে নিন");
      return;
    }
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty || _pass.text.isEmpty) {
      _msg("সব তথ্য দিন");
      return;
    }
    // cPanel এ Register হবে
    final r = await apiCall('register', {
      "name": _name.text.trim(),
      "phone": _phone.text.trim(),
      "password": _pass.text,
      "blood_group": _bg,
      "district": _dist.text.trim(),
      "terms_accepted": 1,
    });
    _msg(r['message'].toString());
    if (r['success'] == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register - RedLoop Pro"), backgroundColor: Colors.red, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone Number", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            DropdownButtonFormField(
              value: _bg,
              items: _bgs.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _bg = v!),
              decoration: const InputDecoration(labelText: "Blood Group", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(controller: _dist, decoration: const InputDecoration(labelText: "District", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(value: _termsOk, onChanged: (v) => setState(() => _termsOk = v ?? false)),
                const Expanded(child: Text("আমি Terms & Conditions পড়েছি এবং মেনে নিয়েছি")),
              ],
            ),
            TextButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Terms & Conditions"),
                  content: SingleChildScrollView(child: Text(widget.terms.isEmpty ? "Terms এখনো সেট করা হয়নি" : widget.terms)),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
                ),
              ),
              child: const Text("Terms দেখুন"),
            ),
            ElevatedButton(
              onPressed: _reg,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text("REGISTER - cPanel এ Save হবে"),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// FORGOT PASSWORD - cPanel password_requests Table এ যাবে
// =====================================================
class ForgotScreen extends StatefulWidget {
  const ForgotScreen({super.key});
  @override
  State<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends State<ForgotScreen> {
  final _phone = TextEditingController();
  void _msg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Forgot Password"), backgroundColor: Colors.red, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Phone নম্বর দিন। Admin Approve করলে Temp Password পাবেন।"),
            const SizedBox(height: 12),
            TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                final r = await apiCall('forgot_request', {"phone": _phone.text.trim()});
                _msg(r['message'].toString());
                if (r['success'] == true && mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text("REQUEST পাঠান - cPanel এ যাবে"),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// HOME - সব Data cPanel থেকে আসবে
// =====================================================
class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const HomeScreen({super.key, required this.user});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List donors = [];
  List myReqs = [];
  List notifs = [];
  int unread = 0;
  String notice = "Donate Blood, Save Life";
  bool isSuper = false;
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    isSuper = widget.user['role'] == 'super_admin';
    isAdmin = widget.user['role'] == 'admin' || isSuper;
    _loadAll();
  }

  // সব Data cPanel থেকে Load হবে - get_donors, get_notifications, get_my_requests, get_settings
  Future<void> _loadAll() async {
    final d = await apiCall('get_donors', {});
    final n = await apiCall('get_notifications', {"phone": widget.user['phone']});
    final r = await apiCall('get_my_requests', {"phone": widget.user['phone']});
    final s = await apiCall('get_settings', {});
    if (!mounted) return;
    setState(() {
      if (d['success'] == true) donors = (d['data'] as List?) ?? [];
      if (n['success'] == true) {
        notifs = (n['data']['list'] as List?) ?? [];
        unread = (n['data']['unread'] ?? 0) as int;
      }
      if (r['success'] == true) myReqs = (r['data'] as List?) ?? [];
      if (s['success'] == true) notice = (s['data']['notice'] ?? notice).toString();
    });
  }

  void _msg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _openNotifs() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Notifications - cPanel থেকে এসেছে"),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: notifs.isEmpty
              ? const Center(child: Text("কোনো Notification নেই"))
              : ListView.builder(
                  itemCount: notifs.length,
                  itemBuilder: (_, i) {
                    final x = notifs[i];
                    return ListTile(
                      title: Text((x['title'] ?? '').toString(), style: TextStyle(fontWeight: x['is_read'] == 0 ? FontWeight.bold : FontWeight.normal)),
                      subtitle: Text((x['body'] ?? '').toString()),
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
    await apiCall('mark_notifications_read', {"phone": widget.user['phone']});
    _loadAll();
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Logout?"),
        content: const Text("আপনি কি Logout করতে চান?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes")),
        ],
      ),
    );
    if (ok != true) return;
    await apiCall('logout', {"phone": widget.user['phone']});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
  }

  Future<void> _respond(Map r, String st) async {
    final res = await apiCall('respond_request', {
      "request_id": r['id'],
      "donor_phone": widget.user['phone'],
      "donor_name": widget.user['name'],
      "status": st,
    });
    _msg(res['message'].toString());
    _loadAll();
  }

  Future<void> _askReceived(Map r) async {
    final pick = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm করুন"),
        content: const Text("রক্ত কি পেয়েছেন? Yes করলে আর বদলানো যাবে না।"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, 'received'), child: const Text("Received")),
          TextButton(onPressed: () => Navigator.pop(context, 'no_thanks'), child: const Text("No, Thanks")),
        ],
      ),
    );
    if (pick == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("আপনি কি নিশ্চিত?"),
        content: Text(pick == 'received' ? "Received Confirm করছেন?" : "No, Thanks Confirm করছেন?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes")),
        ],
      ),
    );
    if (ok != true) return;
    final res = await apiCall('mark_received', {"request_id": r['id'], "type": pick});
    _msg(res['message'].toString());
    _loadAll();
  }

  Future<void> _editLastDonation() async {
    final c = TextEditingController(text: (widget.user['last_donation_date'] ?? '').toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Last Donation Date"),
        content: TextField(controller: c, decoration: const InputDecoration(hintText: "YYYY-MM-DD", border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Save - cPanel এ যাবে")),
        ],
      ),
    );
    if (ok != true) return;
    final res = await apiCall('update_last_donation', {"phone": widget.user['phone'], "date": c.text.trim(), "by_phone": widget.user['phone']});
    _msg(res['message'].toString());
    _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("RedLoop Pro"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          Stack(
            children: [
              IconButton(icon: const Icon(Icons.notifications), onPressed: _openNotifs),
              if (unread > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.yellow,
                    child: Text("$unread", style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                child: Text("👋 ${widget.user['name']} • ${widget.user['blood_group']} • ${widget.user['role']}\n$notice\nServer: cPanel - Live", style: const TextStyle(fontSize: 15)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _homeBtn("🩸 Blood Request", Colors.red, () => Navigator.push(context, MaterialPageRoute(builder: (_) => RequestScreen(user: widget.user))).then((_) => _loadAll()))),
                  const SizedBox(width: 10),
                  Expanded(child: _homeBtn("🎫 Help Ticket", Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => TicketScreen(user: widget.user))))),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _homeBtn("⭐ My Ratings", Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => RatingScreen(user: widget.user))))),
                  const SizedBox(width: 10),
                  Expanded(child: _homeBtn("📅 Last Donation", Colors.blue, _editLastDonation)),
                ],
              ),
              if (isAdmin) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _homeBtn("🛠 Admin Panel", Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminScreen(user: widget.user))))),
                    if (isSuper) ...[
                      const SizedBox(width: 10),
                      Expanded(child: _homeBtn("⚙ Settings / Terms", Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(user: widget.user))))),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 18),
              const Text("My Requests - cPanel থেকে", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (myReqs.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("কোনো Request নেই")),
              ...myReqs.map((r) => _reqCard(Map<String, dynamic>.from(r))).toList(),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [const Text("Donor List - cPanel থেকে", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text("${donors.length} জন", style: const TextStyle(color: Colors.grey))],
              ),
              const SizedBox(height: 6),
              if (donors.isEmpty) const Text("কোনো Donor নেই"),
              ...donors.map((d) => _donorCard(Map<String, dynamic>.from(d))).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _homeBtn(String t, Color c, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(12)),
        child: Center(child: Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      ),
    );
  }

  Widget _donorCard(Map<String, dynamic> d) {
    final avail = (d['available'] ?? 'Available').toString();
    final rating = double.tryParse('${d['avg_rating'] ?? 0}') ?? 0;
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: Colors.red, child: Text((d['blood_group'] ?? 'O+').toString(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
        title: Text("${d['name']} • ${d['district']}"),
        subtitle: Text("⭐ ${rating.toStringAsFixed(1)} (${d['rating_count'] ?? 0} Rating) • Last: ${d['last_donation_date'] ?? 'কখনো না'} • $avail"),
        trailing: ElevatedButton(
          onPressed: avail == 'Not Available' ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => RequestScreen(user: widget.user, targetName: (d['name'] ?? '').toString()))),
          child: const Text("Request"),
        ),
      ),
    );
  }

  Widget _reqCard(Map<String, dynamic> r) {
    final isMy = r['requester_phone'] == widget.user['phone'];
    final resp = (r['responses'] as List?) ?? [];
    final need = ((r['bags'] ?? 1) as int) * 2;
    return Card(
      color: Colors.yellow.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Patient: ${r['patient_name']} • ${r['blood_group']} • ${r['bags']} ব্যাগ", style: const TextStyle(fontWeight: FontWeight.bold)),
            Text("Hospital: ${r['hospital']} • ${r['address']}"),
            Text("Status: ${r['status']} • Response: ${resp.length} / $need"),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (!isMy && r['status'] == 'pending') ...[
                  ElevatedButton(onPressed: () => _respond(r, 'accepted'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), child: const Text("Accept")),
                  ElevatedButton(onPressed: () => _respond(r, 'rejected'), style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, foregroundColor: Colors.white), child: const Text("Reject")),
                ],
                if (isMy && r['status'] == 'pending')
                  ElevatedButton(onPressed: () => _askReceived(r), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white), child: const Text("Received / No, Thanks")),
                if (isMy && r['status'] == 'received')
                  ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RatingScreen(user: widget.user, request: r))), child: const Text("Rating দিন")),
                ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(user: widget.user, request: r))), child: const Text("Message")),
              ],
            ),
            if (resp.isNotEmpty) ...resp.map((x) => Text("• ${x['donor_name']} - ${x['status']}")).toList(),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// BLOOD REQUEST - cPanel blood_requests Table এ যাবে
// =====================================================
class RequestScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String? targetName;
  const RequestScreen({super.key, required this.user, this.targetName});
  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  final _patient = TextEditingController();
  final _hosp = TextEditingController();
  final _addr = TextEditingController();
  final _dist = TextEditingController();
  final _msg = TextEditingController();
  String _bg = 'O+';
  int _bags = 1;

  void _show(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Blood Request"), backgroundColor: Colors.red, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.targetName != null) Text("To Donor: ${widget.targetName}", style: const TextStyle(fontWeight: FontWeight.bold)),
            TextField(controller: _patient, decoration: const InputDecoration(labelText: "Patient Name", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _hosp, decoration: const InputDecoration(labelText: "Hospital Name", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _addr, decoration: const InputDecoration(labelText: "Address", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _dist, decoration: const InputDecoration(labelText: "District", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            DropdownButtonFormField(
              value: _bg,
              items: ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _bg = v!),
              decoration: const InputDecoration(labelText: "Blood Group", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text("Bags: "),
                IconButton(onPressed: () => setState(() => _bags = (_bags > 1 ? _bags - 1 : 1)), icon: const Icon(Icons.remove)),
                Text("$_bags"),
                IconButton(onPressed: () => setState(() => _bags++), icon: const Icon(Icons.add)),
              ],
            ),
            TextField(controller: _msg, decoration: const InputDecoration(labelText: "Message (ঐচ্ছিক)", border: OutlineInputBorder())),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () async {
                if (_patient.text.trim().isEmpty || _hosp.text.trim().isEmpty) {
                  _show("Patient + Hospital দিন");
                  return;
                }
                final r = await apiCall('send_request', {
                  "requester_phone": widget.user['phone'],
                  "requester_name": widget.user['name'],
                  "patient_name": _patient.text.trim(),
                  "hospital": _hosp.text.trim(),
                  "address": _addr.text.trim(),
                  "district": _dist.text.trim(),
                  "blood_group": _bg,
                  "bags": _bags,
                  "message": _msg.text.trim(),
                  "target_donor_phone": "",
                });
                _show(r['message'].toString());
                if (r['success'] == true && mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text("REQUEST পাঠান - cPanel এ যাবে"),
            ),
            const SizedBox(height: 8),
            const Text("General Request হলে cPanel থেকে Blood Group ম্যাচ করা কাছের ১০ জন Donor এর কাছে Notification যাবে।", style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// CHAT - cPanel messages Table থেকে আসবে
// =====================================================
class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final Map<String, dynamic> request;
  const ChatScreen({super.key, required this.user, required this.request});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _c = TextEditingController();
  List msgs = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await apiCall('get_messages', {"request_id": widget.request['id']});
    if (mounted && r['success'] == true) setState(() => msgs = (r['data'] as List?) ?? []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Message - ${widget.request['patient_name']}"), backgroundColor: Colors.red, foregroundColor: Colors.white),
      body: Column(
        children: [
          Expanded(
            child: msgs.isEmpty
                ? const Center(child: Text("কোনো Message নেই - cPanel এ নেই"))
                : ListView.builder(
                    itemCount: msgs.length,
                    itemBuilder: (_, i) {
                      final m = msgs[i];
                      final mine = m['sender_phone'] == widget.user['phone'];
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.all(6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: mine ? Colors.red.shade100 : Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
                          child: Text((m['message'] ?? '').toString()),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _c, decoration: const InputDecoration(hintText: "Message লিখুন...", border: OutlineInputBorder()))),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.red),
                  onPressed: () async {
                    if (_c.text.trim().isEmpty) return;
                    String other = "";
                    final resp = (widget.request['responses'] as List?) ?? [];
                    if (widget.request['requester_phone'] == widget.user['phone']) {
                      if (resp.isNotEmpty) other = (resp[0]['donor_phone'] ?? '').toString();
                    } else {
                      other = (widget.request['requester_phone'] ?? '').toString();
                    }
                    final r = await apiCall('send_message', {
                      "request_id": widget.request['id'],
                      "sender_phone": widget.user['phone'],
                      "receiver_phone": other,
                      "message": _c.text.trim(),
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r['message'].toString())));
                    if (r['success'] == true) {
                      _c.clear();
                      _load();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// RATING - cPanel donor_ratings / user_ratings Table
// =====================================================
class RatingScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final Map<String, dynamic>? request;
  const RatingScreen({super.key, required this.user, this.request});
  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  List donorRatings = [];
  List userRatings = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await apiCall('get_ratings', {"phone": widget.user['phone']});
    if (mounted && r['success'] == true) {
      setState(() {
        donorRatings = (r['data']['donor_ratings'] as List?) ?? [];
        userRatings = (r['data']['user_ratings'] as List?) ?? [];
      });
    }
  }

  void _msg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  String _otherPhone() {
    if (widget.request == null) return "";
    final resp = (widget.request!['responses'] as List?) ?? [];
    if (widget.request!['requester_phone'] == widget.user['phone']) {
      if (resp.isNotEmpty) return (resp[0]['donor_phone'] ?? '').toString();
      return "";
    }
    return (widget.request!['requester_phone'] ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Ratings - cPanel থেকে"), backgroundColor: Colors.red, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.request != null) ...[
              const Text("এই Request এর জন্য Rating দিন (Received হলেই Rating হবে)", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _rateBox("Donor কে Rating দিন", true),
              const SizedBox(height: 10),
              _rateBox("User কে Rating দিন", false),
              const SizedBox(height: 14),
            ],
            const Text("Donor Ratings (আমাকে দেওয়া)", style: TextStyle(fontWeight: FontWeight.bold)),
            ...donorRatings.map((x) => ListTile(title: Text("⭐ ${x['stars']} - ${x['comment']}"), subtitle: Text("${x['created_at']}"))).toList(),
            const SizedBox(height: 10),
            const Text("User Ratings", style: TextStyle(fontWeight: FontWeight.bold)),
            ...userRatings.map((x) => ListTile(title: Text("⭐ ${x['stars']} - ${x['comment']}"), subtitle: Text("${x['created_at']}"))).toList(),
            if (donorRatings.isEmpty && userRatings.isEmpty) const Text("কোনো Rating নেই"),
          ],
        ),
      ),
    );
  }

  Widget _rateBox(String title, bool isDonor) {
    final c = TextEditingController();
    int stars = 5;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            Row(
              children: List.generate(5, (i) => IconButton(icon: Icon(Icons.star, color: i < stars ? Colors.amber : Colors.grey), onPressed: () => setState(() => stars = i + 1))),
            ),
            TextField(controller: c, decoration: const InputDecoration(hintText: "মন্তব্য (২০০ অক্ষর)", border: OutlineInputBorder())),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                final other = _otherPhone();
                if (other.isEmpty) {
                  _msg("Donor / User পাওয়া যায়নি");
                  return;
                }
                final r = isDonor
                    ? await apiCall('rate_donor', {"donor_phone": other, "rater_phone": widget.user['phone'], "request_id": widget.request!['id'], "stars": stars, "comment": c.text.trim()})
                    : await apiCall('rate_user', {"user_phone": other, "donor_phone": widget.user['phone'], "request_id": widget.request!['id'], "stars": stars, "comment": c.text.trim()});
                _msg(r['message'].toString());
                _load();
              },
              child: const Text("Rating পাঠান - cPanel এ যাবে"),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// HELP TICKET - cPanel help_tickets Table
// =====================================================
class TicketScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const TicketScreen({super.key, required this.user});
  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  List tickets = [];
  final _sub = TextEditingController();
  final _det = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await apiCall('get_tickets', {"phone": widget.user['phone']});
    if (mounted && r['success'] == true) setState(() => tickets = (r['data'] as List?) ?? []);
  }

  void _msg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.user['role'] == 'admin' || widget.user['role'] == 'super_admin';
    return Scaffold(
      appBar: AppBar(title: const Text("Help Ticket - cPanel থেকে"), backgroundColor: Colors.red, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _sub, decoration: const InputDecoration(labelText: "Subject", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _det, maxLines: 3, decoration: const InputDecoration(labelText: "Details", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                final r = await apiCall('create_ticket', {"phone": widget.user['phone'], "name": widget.user['name'], "subject": _sub.text.trim(), "details": _det.text.trim()});
                _msg(r['message'].toString());
                if (r['success'] == true) {
                  _sub.clear();
                  _det.clear();
                  _load();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text("TICKET খুলুন - cPanel এ যাবে"),
            ),
            const SizedBox(height: 16),
            const Text("My Tickets", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ...tickets.map((t) => Card(
                  child: ListTile(
                    title: Text("${t['subject']} - ${t['status']}"),
                    subtitle: Text("${t['details']}\n${t['status'] == 'solved' ? 'Solved by: ${t['solved_by_name']}' : ''}"),
                    trailing: isAdmin && t['status'] != 'solved'
                        ? TextButton(
                            onPressed: () async {
                              final r = await apiCall('solve_ticket', {"ticket_id": t['id'], "by_phone": widget.user['phone'], "by_name": widget.user['name']});
                              _msg(r['message'].toString());
                              _load();
                            },
                            child: const Text("Solve"),
                          )
                        : null,
                  ),
                )).toList(),
            if (tickets.isEmpty) const Text("কোনো Ticket নেই"),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// ADMIN PANEL - cPanel থেকে Users / Password Requests আসবে
// =====================================================
class AdminScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminScreen({super.key, required this.user});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List users = [];
  List passReqs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await apiCall('admin_get_users', {"by_phone": widget.user['phone']});
    final p = await apiCall('admin_get_password_requests', {"by_phone": widget.user['phone']});
    if (mounted) {
      setState(() {
        if (u['success'] == true) users = (u['data'] as List?) ?? [];
        if (p['success'] == true) passReqs = (p['data'] as List?) ?? [];
      });
    }
  }

  void _msg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Panel - RedLoop Pro - cPanel"), backgroundColor: Colors.purple, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Password Requests - cPanel থেকে", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ...passReqs.map((x) => Card(
                  child: ListTile(
                    title: Text("Phone: ${x['phone']}"),
                    trailing: ElevatedButton(
                      onPressed: () async {
                        final c = TextEditingController(text: "123456");
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("Temp Password দিন"),
                            content: TextField(controller: c),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Approve")),
                            ],
                          ),
                        );
                        if (ok == true) {
                          final r = await apiCall('admin_approve_password', {"by_phone": widget.user['phone'], "id": x['id'], "temp_password": c.text.trim()});
                          _msg(r['message'].toString());
                          _load();
                        }
                      },
                      child: const Text("Approve"),
                    ),
                  ),
                )).toList(),
            if (passReqs.isEmpty) const Text("কোনো Password Request নেই"),
            const SizedBox(height: 16),
            const Text("All Users - cPanel থেকে", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ...users.map((u) => Card(
                  child: ListTile(
                    title: Text("${u['name']} - ${u['phone']}"),
                    subtitle: Text("${u['role']} • ${u['status']} • ${u['blood_group']} • Last: ${u['last_donation_date'] ?? '-'}"),
                    trailing: PopupMenuButton(
                      onSelected: (v) async {
                        if (v == 'ban') {
                          final r = await apiCall('admin_ban_user', {"by_phone": widget.user['phone'], "phone": u['phone'], "status": u['status'] == 'banned' ? 'active' : 'banned'});
                          _msg(r['message'].toString());
                          _load();
                        }
                        if (v == 'delete') {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("Delete?"),
                              content: Text("আপনি কি ${u['name']} কে Delete করতে চান?"),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes")),
                              ],
                            ),
                          );
                          if (ok == true) {
                            final r = await apiCall('admin_delete_user', {"by_phone": widget.user['phone'], "phone": u['phone']});
                            _msg(r['message'].toString());
                            _load();
                          }
                        }
                      },
                      itemBuilder: (_) => [const PopupMenuItem(value: 'ban', child: Text("Ban / Unban")), const PopupMenuItem(value: 'delete', child: Text("Delete"))],
                    ),
                  ),
                )).toList(),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// SETTINGS - শুধু Super Admin - cPanel settings Table
// =====================================================
class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const SettingsScreen({super.key, required this.user});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _notice = TextEditingController();
  final _wa = TextEditingController();
  final _terms = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await apiCall('get_settings', {});
    if (mounted && r['success'] == true) {
      setState(() {
        _notice.text = (r['data']['notice'] ?? '').toString();
        _wa.text = (r['data']['admin_whatsapp'] ?? '').toString();
        _terms.text = (r['data']['terms_conditions'] ?? '').toString();
      });
    }
  }

  void _msg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings - Super Admin Only - cPanel"), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _notice, decoration: const InputDecoration(labelText: "Notice - cPanel এ Save হবে", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _wa, decoration: const InputDecoration(labelText: "Admin WhatsApp", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _terms, maxLines: 10, decoration: const InputDecoration(labelText: "Terms & Conditions - cPanel এ Save হবে", border: OutlineInputBorder())),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () async {
                final r = await apiCall('update_settings', {"by_phone": widget.user['phone'], "notice": _notice.text.trim(), "admin_whatsapp": _wa.text.trim(), "terms_conditions": _terms.text});
                _msg(r['message'].toString());
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              child: const Text("SAVE SETTINGS - cPanel"),
            ),
          ],
        ),
      ),
    );
  }
}
