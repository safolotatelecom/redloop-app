import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String baseUrl = "https://redloop.safolota.com/api.php";
const String apiKey = "redloop2026secure";

class BloodRequestScreen extends StatefulWidget {
  const BloodRequestScreen({super.key});
  @override
  State<BloodRequestScreen> createState() => _BloodRequestScreenState();
}

class _BloodRequestScreenState extends State<BloodRequestScreen> {
  final nameCtrl = TextEditingController();
  final hospitalCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final bagsCtrl = TextEditingController(text: "1");
  final districtCtrl = TextEditingController();
  String bloodGroup = "O+";
  bool loading = false;
  String msg = "";

  Future<void> sendRequest() async {
    if (nameCtrl.text.trim().isEmpty || hospitalCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
      setState(() => msg = "সব ফিল্ড পূরণ করুন");
      return;
    }
    setState(() { loading = true; msg = "Sending..."; });
    try {
      final res = await http.post(Uri.parse("$baseUrl?action=blood_request"), headers: {"X-API-KEY": apiKey}, body: {"name": nameCtrl.text.trim(), "hospital": hospitalCtrl.text.trim(), "phone": phoneCtrl.text.trim(), "blood_group": bloodGroup, "bags": bagsCtrl.text.trim(), "district": districtCtrl.text.trim()}).timeout(const Duration(seconds: 15));
      if (res.body.trim().isEmpty) {
        setState(() => msg = "SERVER ERROR: Empty response. Chrome এ api.php?action=settings খুলে দেখুন।");
        return;
      }
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        setState(() => msg = "✅ Request sent successfully!");
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Blood request submitted"), backgroundColor: Colors.green));
        if (mounted) Navigator.pop(context, true);
      } else {
        setState(() => msg = "SERVER SAYS: ${data['message']}");
      }
    } catch (e) {
      setState(() => msg = "ERROR: $e");
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Request Blood"), backgroundColor: Colors.red, foregroundColor: Colors.white),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Patient Name", border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: hospitalCtrl, decoration: const InputDecoration(labelText: "Hospital Name", border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Contact Phone", border: OutlineInputBorder())),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: bloodGroup, decoration: const InputDecoration(labelText: "Blood Group Needed", border: OutlineInputBorder()), items: ["A+","A-","B+","B-","O+","O-","AB+","AB-"].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(), onChanged: (v) => setState(() => bloodGroup = v!)),
        const SizedBox(height: 12),
        TextField(controller: bagsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "How many bags?", border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: districtCtrl, decoration: const InputDecoration(labelText: "District (Optional)", border: OutlineInputBorder())),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: loading ? null : sendRequest, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: Text(loading ? "Sending..." : "Send Request", style: const TextStyle(color: Colors.white)))),
        const SizedBox(height: 12),
        if (msg.isNotEmpty) SelectableText(msg, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
      ])),
    );
  }
}
