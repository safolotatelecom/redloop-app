import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

const String baseUrl = "https://redloop.safolota.com/api.php";
const String apiKey = "redloop2026secure";

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final phoneCtrl = TextEditingController();
  bool loading = false;
  bool alreadySent = false;
  String msg = "";

  Future<void> sendRequest() async {
    if (phoneCtrl.text.trim().isEmpty) { setState(() => msg = "আগে ফোন নম্বর লিখুন"); return; }
    if (alreadySent) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Already request submitted. Please wait for Admin approval."), backgroundColor: Colors.orange)); return; }
    setState(() { loading = true; msg = "Sending..."; });
    try {
      final res = await http.post(Uri.parse("$baseUrl?action=forgot_password"), headers: {"X-API-KEY": apiKey}, body: {"phone": phoneCtrl.text.trim()}).timeout(const Duration(seconds: 15));
      if (res.body.trim().isEmpty) { setState(() => msg = "SERVER ERROR: Empty response."); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Network error, try again"))); return; }
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        setState(() { alreadySent = true; msg = "Request sent! Admin এর WhatsApp এ গেছে।"; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request sent successfully"), backgroundColor: Colors.green));
        String wa = data['admin_whatsapp'] ?? "8801712345678";
        String p = wa.replaceAll("+", "").replaceAll(" ", "");
        if (p.startsWith("01")) p = "880" + p.substring(1);
        String text = Uri.encodeComponent("Hello RedLoop Admin, I forgot my password. My phone: ${phoneCtrl.text.trim()}. Please send me a temporary password.");
        final uri = Uri.parse("https://wa.me/$p?text=$text");
        if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (data['already_exists'] == true) { setState(() { alreadySent = true; msg = data['message']; }); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: Colors.orange.shade800)); }
        else { setState(() => msg = data['message']); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']))); }
      }
    } catch (e) { setState(() => msg = "Network error: $e"); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Network error, try again"))); }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Forgot Password"), backgroundColor: Colors.red, foregroundColor: Colors.white),
      body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
        const Text("Enter your registered phone number. Admin will send you a temporary password on WhatsApp.", textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
        const SizedBox(height: 20),
        TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone Number", border: OutlineInputBorder())),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: loading ? null : sendRequest, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: Text(loading ? "Sending..." : "Send Request on WhatsApp", style: const TextStyle(color: Colors.white)))),
        const SizedBox(height: 12),
        if (msg.isNotEmpty) Text(msg, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
      ])),
    );
  }
}
