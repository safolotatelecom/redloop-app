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
  final name = TextEditingController();
  final phone = TextEditingController();
  final hospital = TextEditingController();
  String bloodGroup = "A+";
  String msg = "";
  bool loading = false;
  final groups = ["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"];

  Future<void> sendRequest() async {
    if (name.text.isEmpty || phone.text.isEmpty || hospital.text.isEmpty) {
      setState(() => msg = "Please fill in all fields.");
      return;
    }
    setState(() { loading = true; msg = ""; });
    try {
      final res = await http.post(
        Uri.parse("$baseUrl?action=blood_request"),
        headers: {"X-API-KEY": apiKey},
        body: {"name": name.text.trim(), "phone": phone.text.trim(), "hospital": hospital.text.trim(), "blood_group": bloodGroup},
      );
      final data = jsonDecode(res.body);
      setState(() => msg = data['success'] == true ? "Request Sent Successfully! Donors will see your request." : (data['message'] ?? "Request Failed. Please try again."));
    } catch (_) {
      setState(() => msg = "Cannot connect to server. Please check your internet connection.");
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Blood Request"), backgroundColor: Colors.red, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: "Patient Name", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: phone, decoration: const InputDecoration(labelText: "Contact Phone", border: OutlineInputBorder()), keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            TextField(controller: hospital, decoration: const InputDecoration(labelText: "Hospital / Location", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(value: bloodGroup, decoration: const InputDecoration(labelText: "Required Blood Group", border: OutlineInputBorder()), items: groups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(), onChanged: (v) => setState(() => bloodGroup = v!)),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: loading ? null : sendRequest, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: Text(loading ? "Please wait..." : "Send Request", style: const TextStyle(color: Colors.white)))),
            const SizedBox(height: 10),
            Text(msg, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
