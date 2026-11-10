import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
const String baseUrl = "https://redloop.safolota.com/api.php";
const String apiKey = "redloop2026secure";

class ChangePasswordScreen extends StatefulWidget {
  final String phone;
  const ChangePasswordScreen({super.key, required this.phone});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final newPass = TextEditingController();
  final confirmPass = TextEditingController();
  bool show1 = false; bool show2 = false;
  String msg = "";
  Future<void> change() async {
    if (newPass.text != confirmPass.text) { setState(() => msg = "Password does not match"); return; }
    if (newPass.text.length < 4) { setState(() => msg = "Password must be at least 4 characters"); return; }
    final res = await http.post(Uri.parse("$baseUrl?action=change_password"),
      headers: {"X-API-KEY": apiKey}, body: {"phone": widget.phone, "new_password": newPass.text.trim()});
    final data = jsonDecode(res.body);
    if (data['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password changed! Login again")));
      Navigator.pop(context);
    } else { setState(() => msg = data['message']); }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Set New Password"), backgroundColor: Colors.red, foregroundColor: Colors.white, automaticallyImplyLeading: false),
      body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange)), child: const Text("⚠️ আপনি Temp Password দিয়ে Login করেছেন। এখনই নতুন Password সেট করুন।", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
        const SizedBox(height: 20),
        TextField(controller: newPass, obscureText: !show1, decoration: InputDecoration(labelText: "New Password", border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(show1 ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => show1 = !show1)))),
        const SizedBox(height: 12),
        TextField(controller: confirmPass, obscureText: !show2, decoration: InputDecoration(labelText: "Confirm New Password", border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(show2 ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => show2 = !show2)))),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: change, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Change Password", style: TextStyle(color: Colors.white)))),
        const SizedBox(height: 12), Text(msg, style: const TextStyle(color: Colors.red)),
      ])),
    );
  }
}
