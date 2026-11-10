import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'donor_list.dart' hide baseUrl, apiKey;
import 'blood_request.dart' hide baseUrl, apiKey;
import 'admin_panel.dart';

const String baseUrl = "https://redloop.safolota.com/api.php";
const String apiKey = "redloop2026secure";
const String defaultLogo = "https://redloop.safolota.com/logo.png";

class ChangePasswordScreen extends StatefulWidget {
  final String phone;
  const ChangePasswordScreen({super.key, required this.phone});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final newPass = TextEditingController();
  final confirmPass = TextEditingController();
  bool show1 = false;
  bool show2 = false;
  String msg = "";
  bool loading = false;

  Future<void> change() async {
    if (newPass.text.trim().isEmpty || confirmPass.text.trim().isEmpty) {
      setState(() => msg = "সব ঘর পূরণ করুন");
      return;
    }
    if (newPass.text != confirmPass.text) {
      setState(() => msg = "Password does not match");
      return;
    }
    if (newPass.text.length < 4) {
      setState(() => msg = "Password must be at least 4 characters");
      return;
    }
    setState(() {
      loading = true;
      msg = "";
    });
    try {
      final res = await http.post(
        Uri.parse("$baseUrl?action=change_password"),
        headers: {"X-API-KEY": apiKey},
        body: {"phone": widget.phone, "new_password": newPass.text.trim()},
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Password changed! Please login with new password"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => SimpleLoginBackScreen(phone: widget.phone),
          ),
          (route) => false,
        );
      } else {
        setState(() => msg = data['message']);
      }
    } catch (e) {
      setState(() => msg = "Network error, try again");
    }
    if (mounted) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Set New Password"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange),
              ),
              child: const Text(
                "⚠️ আপনি Temp Password দিয়ে Login করেছেন। এখনই নতুন Password সেট করুন।",
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: newPass,
              obscureText: !show1,
              decoration: InputDecoration(
                labelText: "New Password",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(show1 ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => show1 = !show1),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPass,
              obscureText: !show2,
              decoration: InputDecoration(
                labelText: "Confirm New Password",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(show2 ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => show2 = !show2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: loading ? null : change,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(
                  loading ? "Changing..." : "Change Password",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(msg, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

class SimpleLoginBackScreen extends StatefulWidget {
  final String phone;
  const SimpleLoginBackScreen({super.key, this.phone = ""});
  @override
  State<SimpleLoginBackScreen> createState() => _SimpleLoginBackScreenState();
}

class _SimpleLoginBackScreenState extends State<SimpleLoginBackScreen> {
  late TextEditingController phone;
  final pass = TextEditingController();
  bool showPass = false;
  String msg = "";
  bool loading = false;

  @override
  void initState() {
    super.initState();
    phone = TextEditingController(text: widget.phone);
  }

  Future<void> doLogin() async {
    if (phone.text.trim().isEmpty || pass.text.trim().isEmpty) {
      setState(() => msg = "Phone + Password লিখুন");
      return;
    }
    setState(() {
      loading = true;
      msg = "Logging in...";
    });
    try {
      final res = await http.post(
        Uri.parse("$baseUrl?action=login"),
        headers: {"X-API-KEY": apiKey},
        body: {"phone": phone.text.trim(), "password": pass.text.trim()},
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Welcome, ${data['data']['name']}")),
        );
        // FIX: অ্যাপ বন্ধ করতে হবে না - সরাসরি Home এ যাবে
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => AfterChangeHomeScreen(user: data['data']),
          ),
          (route) => false,
        );
      } else {
        setState(() => msg = data['message']);
      }
    } catch (e) {
      setState(() => msg = "Network error: $e");
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("RedLoop Login"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Image.network(
              defaultLogo,
              width: 120,
              height: 120,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.bloodtype, size: 100, color: Colors.red),
            ),
            const SizedBox(height: 10),
            const Text(
              "Password Changed Successfully! ✅\nNow login with your NEW password",
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Phone Number",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pass,
              obscureText: !showPass,
              decoration: InputDecoration(
                labelText: "New Password",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(showPass ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => showPass = !showPass),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: loading ? null : doLogin,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(
                  loading ? "Please wait..." : "Login with New Password",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(msg,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// Password Change এর পরের Home - main.dart এর Home এর মতোই, কিন্তু Import Cycle ছাড়া
class AfterChangeHomeScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  const AfterChangeHomeScreen({super.key, required this.user});
  @override
  Widget build(BuildContext context) {
    bool isAdmin = (user['role'] ?? "") == "admin";
    return Scaffold(
      appBar: AppBar(
        title: const Text("RedLoop Home"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => SimpleLoginBackScreen(phone: ""),
                ),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Image.network(defaultLogo, width: 100, height: 100,
                  errorBuilder: (_, __, ___) => const Icon(Icons.bloodtype, size: 80, color: Colors.red)),
            ),
            const SizedBox(height: 20),
            Text("Welcome, ${user['name']}",
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text("Phone: ${user['phone']}"),
            Text("Role: ${user['role']}"),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.bloodtype, color: Colors.red),
                title: const Text("Find Blood Donors"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DonorListScreen())),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.emergency, color: Colors.red),
                title: const Text("Request Blood"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const BloodRequestScreen())),
              ),
            ),
            if (isAdmin)
              Card(
                color: Colors.red.shade50,
                child: ListTile(
                  leading: const Icon(Icons.admin_panel_settings, color: Colors.red),
                  title: const Text("Admin Panel",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AdminPanelScreen())),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
