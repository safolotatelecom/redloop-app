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
  final phone = TextEditingController();
  String msg = "";
  bool loading = false;

  String toWa(String p) {
    String x = p.replaceAll("+", "").replaceAll(" ", "");
    if (x.startsWith("01")) x = "880" + x.substring(1);
    return x;
  }

  Future<void> sendRequest() async {
    setState(() { loading = true; msg = ""; });
    final res = await http.post(Uri.parse("$baseUrl?action=forgot_password"),
      headers: {"X-API-KEY": apiKey}, body: {"phone": phone.text.trim()});
    final data = jsonDecode(res.body);
    if (data['success'] == true) {
      String adminNum = toWa(data['admin_whatsapp'] ?? "8801712345678");
      String text = Uri.encodeComponent("Hello RedLoop Admin, I forgot my password. My phone: ${phone.text.trim()}. Please send me a temporary password.");
      final uri = Uri.parse("https://wa.me/$adminNum?text=$text");
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
      setState(() => msg = "Request sent! Admin will send temp password on WhatsApp.");
    } else {
      setState(() => msg = data['message']);
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Forgot Password"), backgroundColor: Colors.red, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const Text("Enter your registered phone number. Admin will send you a temporary password on WhatsApp.", textAlign: TextAlign.center),
          const SizedBox(height: 20),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone Number", border: OutlineInputBorder())),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: loading ? null : sendRequest, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: Text(loading ? "Sending..." : "Send Request on WhatsApp", style: const TextStyle(color: Colors.white)))),
          const SizedBox(height: 15),
          Text(msg, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
