import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

const String baseUrl = "https://redloop.safolota.com/api.php";
const String apiKey = "redloop2026secure";

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final phone = TextEditingController();
  String msg = ""; bool loading = false; bool alreadySent = false;

  String toWa(String p) {
    String x = p.replaceAll("+", "").replaceAll(" ", "");
    if (x.startsWith("01")) x = "880" + x.substring(1);
    return x;
  }

  void showToast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: Colors.orange.shade800, duration: const Duration(seconds: 3)));
  }

  Future<void> sendRequest() async {
    if (phone.text.trim().isEmpty) { showToast("আগে ফোন নম্বর লিখুন"); return; }
    if (alreadySent) { showToast("Already request submitted. Please wait for Admin approval."); return; }
    setState(() { loading = true; msg = ""; });
    try {
      final res = await http.post(Uri.parse("$baseUrl?action=forgot_password"), headers: {"X-API-KEY": apiKey}, body: {"phone": phone.text.trim()}).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        setState(() => alreadySent = true);
        String adminNum = toWa(data['admin_whatsapp'] ?? "8801712345678");
        String text = Uri.encodeComponent("Hello RedLoop Admin, I forgot my password. My phone: ${phone.text.trim()}. Please send me a temporary password.");
        final uri = Uri.parse("https://wa.me/$adminNum?text=$text");
        if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
        setState(() => msg = "Request sent! Admin will send temp password on WhatsApp.");
        showToast("Request sent successfully");
      } else {
        // Duplicate হলে এখানে আসবে
        if (data['already_exists'] == true) {
          setState(() => alreadySent = true);
          showToast("Already request submitted. Please wait for Admin approval.");
          setState(() => msg = data['message']);
        } else {
          setState(() => msg = data['message']);
          showToast(data['message']);
        }
      }
    } catch (e) {
      showToast("Network error, try again");
    }
    if (mounted) setState(() => loading = false);
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Forgot Password"), backgroundColor: Colors.red, foregroundColor: Colors.white),
      body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
        const Text("Enter your registered phone number. Admin will send you a temporary password on WhatsApp.", textAlign: TextAlign.center),
        const SizedBox(height: 20),
        TextField(controller: phone, keyboardType: TextInputType.phone, onChanged: (_) { if (alreadySent) setState(() => alreadySent = false); }, decoration: const InputDecoration(labelText: "Phone Number", border: OutlineInputBorder())),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: loading ? null : sendRequest, style: ElevatedButton.styleFrom(backgroundColor: alreadySent ? Colors.grey : Colors.red), child: Text(loading ? "Sending..." : alreadySent ? "Already Request Submitted" : "Send Request on WhatsApp", style: const TextStyle(color: Colors.white)))),
        const SizedBox(height: 15), Text(msg, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
        if (alreadySent) const Text("ভুল করে আবার চাপলেও নতুন Request যাবে না। Admin Approve করলে Temp Password পাবেন।", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
      ])),
    );
  }
}
