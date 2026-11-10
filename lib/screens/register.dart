import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// FROZEN
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
  final district = TextEditingController();
  String bloodGroup = "A+";
  String role = "donor";
  bool loading = false;
  String msg = "";
  final List<String> groups = ["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"];

  Future<void> doRegister() async {
    if (name.text.trim().isEmpty || phone.text.trim().isEmpty || pass.text.trim().isEmpty) {
      setState(() {
        msg = "Please fill all fields";
      });
      return;
    }
    setState(() {
      loading = true;
      msg = "Registering...";
    });
    try {
      final uri = Uri.parse(baseUrl + "?action=register");
      final res = await http.post(uri, headers: {"X-API-KEY": apiKey}, body: {"name": name.text.trim(), "phone": phone.text.trim(), "password": pass.text.trim(), "blood_group": bloodGroup, "district": district.text.trim(), "role": role}).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        setState(() {
          msg = "Registration successful! Please login.";
        });
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pop(context);
      } else {
        setState(() {
          msg = "SERVER SAYS: " + data['message'].toString();
        });
      }
    } catch (e) {
      setState(() {
        msg = "ERROR: " + e.toString();
      });
    }
    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register"), backgroundColor: Colors.red, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: phone, decoration: const InputDecoration(labelText: "Phone Number", border: OutlineInputBorder()), keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: district, decoration: const InputDecoration(labelText: "District / Area", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(value: bloodGroup, decoration: const InputDecoration(labelText: "Blood Group", border: OutlineInputBorder()), items: groups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(), onChanged: (v) => setState(() => bloodGroup = v!)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(value: role, decoration: const InputDecoration(labelText: "I want to", border: OutlineInputBorder()), items: const [DropdownMenuItem(value: "donor", child: Text("Donate Blood")), DropdownMenuItem(value: "seeker", child: Text("Find Blood"))], onChanged: (v) => setState(() => role = v!)),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: loading ? null : doRegister, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: Text(loading ? "Please wait..." : "Register", style: const TextStyle(color: Colors.white)))),
            const SizedBox(height: 12),
            SelectableText(msg, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
