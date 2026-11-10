import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// FROZEN - DO NOT CHANGE
const String baseUrl = "https://redloop.safolota.com/api.php";
const String apiKey = "redloop2026secure";

class BloodRequestScreen extends StatefulWidget {
  const BloodRequestScreen({super.key});
  @override
  State<BloodRequestScreen> createState() => _BloodRequestScreenState();
}

class _BloodRequestScreenState extends State<BloodRequestScreen> {
  final patientName = TextEditingController();
  final hospital = TextEditingController();
  final phone = TextEditingController();
  final bags = TextEditingController(text: "1");
  String bloodGroup = "A+";
  bool loading = false;
  String msg = "";

  final List<String> groups = ["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"];

  Future<void> sendRequest() async {
    if (patientName.text.trim().isEmpty || hospital.text.trim().isEmpty || phone.text.trim().isEmpty) {
      setState(() {
        msg = "Please fill all fields";
      });
      return;
    }
    setState(() {
      loading = true;
      msg = "Sending request...";
    });
    try {
      final uri = Uri.parse(baseUrl + "?action=blood_request");
      final res = await http.post(uri, headers: {"X-API-KEY": apiKey}, body: {
        "patient_name": patientName.text.trim(),
        "hospital": hospital.text.trim(),
        "phone": phone.text.trim(),
        "blood_group": bloodGroup,
        "bags": bags.text.trim(),
      }).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        setState(() {
          msg = "Request sent successfully!";
        });
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
      appBar: AppBar(title: const Text("Request Blood"), backgroundColor: Colors.red, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: patientName, decoration: const InputDecoration(labelText: "Patient Name", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: hospital, decoration: const InputDecoration(labelText: "Hospital Name", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: phone, decoration: const InputDecoration(labelText: "Contact Phone", border: OutlineInputBorder()), keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(value: bloodGroup, decoration: const InputDecoration(labelText: "Blood Group Needed", border: OutlineInputBorder()), items: groups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(), onChanged: (v) => setState(() => bloodGroup = v!)),
            const SizedBox(height: 12),
            TextField(controller: bags, decoration: const InputDecoration(labelText: "How many bags?", border: OutlineInputBorder()), keyboardType: TextInputType.number),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: loading ? null : sendRequest, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: Text(loading ? "Please wait..." : "Send Request", style: const TextStyle(color: Colors.white)))),
            const SizedBox(height: 12),
            SelectableText(msg, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
