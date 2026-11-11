// =====================================================
// RedLoop Pro - Full App - main.dart
// Server: https://redloop.safolota.com/api.php
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
// LOGIN - Password Eye + Remember + Fingerprint
// =====================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _showPassword = false;
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
// REGISTER - Password Eye + Confirm Eye
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
  bool _showPassword = false;
  bool _showConfirm = false;
  bool _loading = false;

  final List<String> bloods = ["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"];
  final List<String> districts = ["Dhaka", "Chattogram", "Khulna", "Rajshahi", "Sylhet", "Barishal", "Rangpur", "Mymensingh"];

  Future<void> _register() async {
    if (_nameCtrl.text.isEmpty || _phoneCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("সব ঘর পূরণ করুন")));
      return;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password মিলছে না!")));
      return;
    }
    setState(() => _loading = true);
    final res = await ApiService.call("register", {
      "name": _nameCtrl.text.trim(),
      "phone": _phoneCtrl.text.trim(),
      "password": _passCtrl.text.trim(),
      "blood_group": _blood,
      "district": _district,
      "address": _addressCtrl.text.trim(),
    });
    setState(() => _loading = false);
    if (res['success'] == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Register সফল! এখন Login করুন")));
      Navigator.pop(context);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? "Register Failed")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Full Name", prefixIcon: Icon(Icons.person))),
            const SizedBox(height: 12),
            TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone Number", prefixIcon: Icon(Icons.phone))),
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              obscureText: !_showConfirm,
              decoration: InputDecoration(
                labelText: "Confirm Password",
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_showConfirm ? Icons.visibility_off : Icons.visibility, color: Colors.red),
                  onPressed: () => setState(() => _showConfirm = !_showConfirm),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _blood,
              items: bloods.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _blood = v!),
              decoration: const InputDecoration(labelText: "Blood Group"),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _district,
              items: districts.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _district = v!),
              decoration: const InputDecoration(labelText: "District"),
            ),
            const SizedBox(height: 12),
            TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: "Address", prefixIcon: Icon(Icons.location_on))),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _register,
                child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text("Register", style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// FORGOT PASSWORD - Eye
// =====================================================
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phoneCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  bool _showNew = false;
  bool _loading = false;

  Future<void> _reset() async {
    setState(() => _loading = true);
    final res = await ApiService.call("forgot_password", {
      "phone": _phoneCtrl.text.trim(),
      "new_password": _newPassCtrl.text.trim(),
    });
    setState(() => _loading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? "Done")));
    if (res['success'] == true) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Forgot Password")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone Number")),
            const SizedBox(height: 12),
            TextField(
              controller: _newPassCtrl,
              obscureText: !_showNew,
              decoration: InputDecoration(
                labelText: "New Password",
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_showNew ? Icons.visibility_off : Icons.visibility, color: Colors.red),
                  onPressed: () => setState(() => _showNew = !_showNew),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _reset, child: const Text("Reset Password"))),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// HOME - Donor List + Bell + Filter
// =====================================================
class HomeScreen extends StatefulWidget {
  final String phone;
  const HomeScreen({super.key, required this.phone});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List donors = [];
  int unread = 0;
  String search = "";
  String filterBlood = "All";
  bool loading = true;
  final List<String> bloods = ["All", "A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"];

  @override
  void initState() {
    super.initState();
    _loadDonors();
    _loadUnread();
  }

  Future<void> _loadDonors() async {
    setState(() => loading = true);
    final res = await ApiService.get("get_donors", {"phone": widget.phone});
    if (res['success'] == true) {
      setState(() {
        donors = res['donors'] ?? [];
        loading = false;
      });
    } else {
      setState(() => loading = false);
    }
  }

  Future<void> _loadUnread() async {
    final res = await ApiService.get("get_unread_count", {"phone": widget.phone});
    if (res['success'] == true) {
      setState(() => unread = int.tryParse(res['count'].toString()) ?? 0);
    }
  }

  List get filtered {
    return donors.where((d) {
      bool okBlood = filterBlood == "All" || d['blood_group'] == filterBlood;
      bool okSearch = search.isEmpty ||
          (d['name'] ?? "").toString().toLowerCase().contains(search.toLowerCase()) ||
          (d['district'] ?? "").toString().toLowerCase().contains(search.toLowerCase());
      return okBlood && okSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🩸 RedLoop Pro"),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationScreen(phone: widget.phone)));
                  _loadUnread();
                  _loadDonors();
                },
              ),
              if (unread > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.yellow, shape: BoxShape.circle),
                    child: Text("$unread", style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HelpScreen(phone: widget.phone))),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFFD32F2F)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("🩸 RedLoop Pro", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(widget.phone, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            ListTile(leading: const Icon(Icons.person), title: const Text("My Profile"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(phone: widget.phone)))),
            ListTile(leading: const Icon(Icons.lock), title: const Text("Change Password"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChangePasswordScreen(phone: widget.phone)))),
            ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text("Logout", style: TextStyle(color: Colors.red)), onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
            }),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => search = v),
              decoration: const InputDecoration(hintText: "নাম / জেলা দিয়ে খুঁজুন...", prefixIcon: Icon(Icons.search)),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: bloods.map((b) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(b),
                  selected: filterBlood == b,
                  selectedColor: Colors.red,
                  labelStyle: TextStyle(color: filterBlood == b ? Colors.white : Colors.black),
                  onSelected: (_) => setState(() => filterBlood = b),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(child: Text("কোনো Donor পাওয়া যায়নি"))
                    : RefreshIndicator(
                        onRefresh: _loadDonors,
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            final d = filtered[i];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.red,
                                  child: Text(d['blood_group'] ?? "?", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                                title: Text(d['name'] ?? ""),
                                subtitle: Text("${d['district'] ?? ""} • ${d['address'] ?? ""}\n⭐ Rating: ${d['rating'] ?? "5.0"} (${d['total_ratings'] ?? 0})"),
                                isThreeLine: true,
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DonorDetailScreen(donor: d, myPhone: widget.phone))),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateRequestScreen(phone: widget.phone))),
        backgroundColor: const Color(0xFFD32F2F),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Blood Request", style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

// =====================================================
// DONOR DETAIL + DIRECT REQUEST
// =====================================================
class DonorDetailScreen extends StatelessWidget {
  final Map donor;
  final String myPhone;
  const DonorDetailScreen({super.key, required this.donor, required this.myPhone});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(donor['name'] ?? "Donor")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: CircleAvatar(radius: 50, backgroundColor: Colors.red, child: Text(donor['blood_group'] ?? "?", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)))),
            const SizedBox(height: 16),
            Text("নাম: ${donor['name']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Phone: ${donor['phone']}"),
            Text("Blood: ${donor['blood_group']}"),
            Text("District: ${donor['district']}"),
            Text("Address: ${donor['address']}"),
            Text("Rating: ⭐ ${donor['rating'] ?? "5.0"} (${donor['total_ratings'] ?? 0} ratings)"),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateRequestScreen(phone: myPhone, directTo: donor['phone'].toString(), directName: donor['name'].toString()))),
                child: const Text("এই Donor কে Direct Request পাঠান"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// CREATE REQUEST - General + Direct
// =====================================================
class CreateRequestScreen extends StatefulWidget {
  final String phone;
  final String? directTo;
  final String? directName;
  const CreateRequestScreen({super.key, required this.phone, this.directTo, this.directName});
  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final _hospitalCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _blood = "A+";
  String _bags = "1";
  bool _loading = false;
  final List<String> bloods = ["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"];

  Future<void> _send() async {
    if (_hospitalCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hospital এর নাম দিন")));
      return;
    }
    setState(() => _loading = true);
    final res = await ApiService.call("create_request", {
      "requester_phone": widget.phone,
      "blood_group": _blood,
      "bags": _bags,
      "hospital": _hospitalCtrl.text.trim(),
      "note": _noteCtrl.text.trim(),
      "direct_to": widget.directTo ?? "",
    });
    setState(() => _loading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? "Sent")));
    if (res['success'] == true) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.directTo != null ? "Direct Request - ${widget.directName}" : "General Blood Request")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (widget.directTo != null)
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)), child: Text("Direct Request যাবে শুধু: ${widget.directName} (${widget.directTo})", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
            if (widget.directTo == null)
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)), child: const Text("General Request যাবে সব Donor এর কাছে। ৫ মিনিট পরপর Reminder যাবে।", style: TextStyle(color: Colors.orange))),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(value: _blood, items: bloods.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _blood = v!), decoration: const InputDecoration(labelText: "Blood Group")),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(value: _bags, items: ["1", "2", "3", "4"].map((e) => DropdownMenuItem(value: e, child: Text("$e Bag"))).toList(), onChanged: (v) => setState(() => _bags = v!), decoration: const InputDecoration(labelText: "কয় ব্যাগ লাগবে?")),
            const SizedBox(height: 12),
            TextField(controller: _hospitalCtrl, decoration: const InputDecoration(labelText: "Hospital Name", prefixIcon: Icon(Icons.local_hospital))),
            const SizedBox(height: 12),
            TextField(controller: _noteCtrl, maxLines: 3, decoration: const InputDecoration(labelText: "Note (ঐচ্ছিক)")),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _send, child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text("Request পাঠান"))),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// NOTIFICATION - Received / No Thanks + Rating
// =====================================================
class NotificationScreen extends StatefulWidget {
  final String phone;
  const NotificationScreen({super.key, required this.phone});
  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List notis = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiService.get("get_notifications", {"phone": widget.phone});
    if (res['success'] == true) setState(() { notis = res['notifications'] ?? []; loading = false; });
    else setState(() => loading = false);
  }

  Future<void> _markRead(String id) async {
    await ApiService.call("mark_read", {"id": id, "phone": widget.phone});
  }

  Future<void> _response(String notiId, String requestId, String action) async {
    final res = await ApiService.call("respond_request", {
      "phone": widget.phone,
      "notification_id": notiId,
      "request_id": requestId,
      "action": action,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? "Done")));
    _load();
  }

  Future<void> _receivedAction(String requestId, String action) async {
    if (action == "received") {
      int? rating = await showDialog<int>(
        context: context,
        builder: (ctx) {
          int r = 5;
          return AlertDialog(
            title: const Text("Rating দিন"),
            content: StatefulBuilder(builder: (c, setS) {
              return Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => IconButton(icon: Icon(Icons.star, color: i < r ? Colors.amber : Colors.grey), onPressed: () => setS(() => r = i + 1))));
            }),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx, r), child: const Text("Submit"))],
          );
        },
      );
      if (rating != null) {
        await ApiService.call("mark_received", {"request_id": requestId, "phone": widget.phone, "rating": rating.toString()});
      }
    } else {
      await ApiService.call("mark_received", {"request_id": requestId, "phone": widget.phone, "rating": "0"});
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : notis.isEmpty
              ? const Center(child: Text("কোনো Notification নেই"))
              : ListView.builder(
                  itemCount: notis.length,
                  itemBuilder: (ctx, i) {
                    final n = notis[i];
                    final type = n['type']?.toString() ?? "general";
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: type == "request" ? Colors.red : Colors.blue, child: Icon(type == "request" ? Icons.bloodtype : Icons.notifications, color: Colors.white)),
                        title: Text(n['title'] ?? ""),
                        subtitle: Text("${n['body'] ?? ""}\n${n['created_at'] ?? ""}"),
                        isThreeLine: true,
                        onTap: () => _markRead(n['id'].toString()),
                        trailing: type == "request"
                            ? Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => _response(n['id'].toString(), n['related_id'].toString(), "accept")),
                                IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => _response(n['id'].toString(), n['related_id'].toString(), "decline")),
                              ])
                            : type == "response"
                                ? Row(mainAxisSize: MainAxisSize.min, children: [
                                    TextButton(onPressed: () => _receivedAction(n['related_id'].toString(), "received"), child: const Text("Received")),
                                    TextButton(onPressed: () => _receivedAction(n['related_id'].toString(), "no_thanks"), child: const Text("No Thanks")),
                                  ])
                                : null,
                      ),
                    );
                  },
                ),
    );
  }
}

// =====================================================
// PROFILE
// =====================================================
class ProfileScreen extends StatefulWidget {
  final String phone;
  const ProfileScreen({super.key, required this.phone});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map user = {};
  bool loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final res = await ApiService.get("get_profile", {"phone": widget.phone});
    if (res['success'] == true) setState(() { user = res['user'] ?? {}; loading = false; });
    else setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      body: loading ? const Center(child: CircularProgressIndicator()) : Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: CircleAvatar(radius: 45, backgroundColor: Colors.red, child: Text(user['blood_group'] ?? "?", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)))),
          const SizedBox(height: 16),
          Text("নাম: ${user['name'] ?? ""}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text("Phone: ${user['phone'] ?? ""}"),
          Text("Blood: ${user['blood_group'] ?? ""}"),
          Text("District: ${user['district'] ?? ""}"),
          Text("Address: ${user['address'] ?? ""}"),
          const SizedBox(height: 10),
          Text("⭐ Rating: ${user['rating'] ?? "5.0"} (${user['total_ratings'] ?? 0} ratings)", style: const TextStyle(fontSize: 16, color: Colors.orange)),
          Text("✅ মোট Donation: ${user['total_donations'] ?? 0}"),
        ]),
      ),
    );
  }
}

// =====================================================
// CHANGE PASSWORD - 3x Eye
// =====================================================
class ChangePasswordScreen extends StatefulWidget {
  final String phone;
  const ChangePasswordScreen({super.key, required this.phone});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showOld = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _loading = false;

  Future<void> _change() async {
    if (_newCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("New Password মিলছে না!")));
      return;
    }
    setState(() => _loading = true);
    final res = await ApiService.call("change_password", {
      "phone": widget.phone,
      "old_password": _oldCtrl.text.trim(),
      "new_password": _newCtrl.text.trim(),
    });
    setState(() => _loading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? "Done")));
    if (res['success'] == true) Navigator.pop(context);
  }

  Widget _passField(TextEditingController ctrl, String label, bool show, VoidCallback toggle) {
    return TextField(
      controller: ctrl,
      obscureText: !show,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(show ? Icons.visibility_off : Icons.visibility, color: Colors.red),
          onPressed: toggle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Change Password")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          _passField(_oldCtrl, "Old Password", _showOld, () => setState(() => _showOld = !_showOld)),
          const SizedBox(height: 12),
          _passField(_newCtrl, "New Password", _showNew, () => setState(() => _showNew = !_showNew)),
          const SizedBox(height: 12),
          _passField(_confirmCtrl, "Confirm New Password", _showConfirm, () => setState(() => _showConfirm = !_showConfirm)),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _change, child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text("Change Password"))),
        ]),
      ),
    );
  }
}

// =====================================================
// HELP - Ticket + Solved By
// =====================================================
class HelpScreen extends StatefulWidget {
  final String phone;
  const HelpScreen({super.key, required this.phone});
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _msgCtrl = TextEditingController();
  List tickets = [];
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final res = await ApiService.get("get_tickets", {"phone": widget.phone});
    if (res['success'] == true) setState(() => tickets = res['tickets'] ?? []);
  }

  Future<void> _send() async {
    if (_msgCtrl.text.isEmpty) return;
    final res = await ApiService.call("create_ticket", {"phone": widget.phone, "message": _msgCtrl.text.trim()});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? "Sent")));
    _msgCtrl.clear();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Help & Support")),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: TextField(controller: _msgCtrl, decoration: const InputDecoration(hintText: "সমস্যা লিখুন..."))),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _send, child: const Text("Send")),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: tickets.length,
            itemBuilder: (ctx, i) {
              final t = tickets[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(t['message'] ?? ""),
                  subtitle: Text("Status: ${t['status']} ${t['status'] == 'solved' ? '• Solved by: ${t['solved_by'] ?? ''} - ${t['admin_reply'] ?? ''}' : ''}"),
                  leading: Icon(t['status'] == 'solved' ? Icons.check_circle : Icons.pending, color: t['status'] == 'solved' ? Colors.green : Colors.orange),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
