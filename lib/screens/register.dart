import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String baseUrl = "https://redloop.safolota.com/api.php";
const String apiKey = "redloop2026secure";

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final pass = TextEditingController();
  String bloodGroup = "A+";
  bool loading = false;
  String msg = "";
  final groups = ["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"];

  Future<void> doRegister() async {
    if (name.text.isEmpty || phone.text.isEmpty || pass.text.isEmpty) {
      setState(() => msg = "Sob field puron korun");
      return;
    }
    setState(() { loading = true; msg = ""; });
    try {
      final res = await http.post(
        Uri.parse("$baseUrl?action=register"),
        headers: {"X-API-KEY": apiKey},
        body: {"name": name.text.trim(), "phone": phone.text.trim(), "password": pass.text.trim(), "blood_group": bloodGroup},
      );
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        setState(() => msg = "Register Success! Ekhon Login korun");
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pop(context);
      } else {
        setState(() => msg = data['message'] ?? "Register Failed");
      }
    } catch (e) {
      setState(() => msg = "Server Error: $e");
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register - RedLoop"), backgroundColor: Colors.red, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: phone, decoration: const InputDecoration(labelText: "Phone", border: OutlineInputBorder()), keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(value: bloodGroup, decoration: const InputDecoration(labelText: "Blood Group", border: OutlineInputBorder()), items: groups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(), onChanged: (v) => setState(() => bloodGroup = v!)),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: loading ? null : doRegister, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: Text(loading ? "Wait..." : "Register", style: const TextStyle(color: Colors.white)))),
            const SizedBox(height: 10),
            Text(msg, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
