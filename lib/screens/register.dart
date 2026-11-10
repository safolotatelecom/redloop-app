import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

// FROZEN
const String baseUrl = "https://redloop.safolota.com/api.php";
const String subDomainHost = "redloop.safolota.com";
const String fallbackIp = "144.79.219.130";
const String apiKey = "redloop2026secure";

Future<String> resolveIp() async {
  try {
    final client = HttpClient();
    final req = await client.getUrl(Uri.parse("https://dns.google/resolve?name=" + subDomainHost + "&type=A"));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    client.close();
    final data = jsonDecode(body);
    final ans = data['Answer'] as List;
    for (var a in ans) {
      if (a['type'] == 1) return a['data'].toString();
    }
  } catch (_) {}
  return fallbackIp;
}

String decodeChunked(String s) {
  String out = "";
  int i = 0;
  while (i < s.length) {
    int end = s.indexOf("\r\n", i);
    if (end == -1) break;
    int len = int.tryParse(s.substring(i, end).trim(), radix: 16) ?? 0;
    if (len == 0) break;
    int start = end + 2;
    if (start + len > s.length) break;
    out += s.substring(start, start + len);
    i = start + len + 2;
  }
  return out;
}

Future<String> httpsRequest(String method, String action, Map<String, String> body) async {
  final ip = await resolveIp();
  String encoded = body.entries.map((e) => Uri.encodeComponent(e.key) + "=" + Uri.encodeComponent(e.value)).join("&");
  final sock = await Socket.connect(ip, 443, timeout: const Duration(seconds: 10));
  final sec = await SecureSocket.secure(sock, host: subDomainHost, onBadCertificate: (c) => true);
  String req;
  if (method == "POST") {
    req = "POST /api.php?action=" + action + " HTTP/1.1\r\nHost: " + subDomainHost + "\r\nX-API-KEY: " + apiKey + "\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: " + encoded.length.toString() + "\r\nConnection: close\r\n\r\n" + encoded;
  } else {
    req = "GET /api.php?action=" + action + " HTTP/1.1\r\nHost: " + subDomainHost + "\r\nX-API-KEY: " + apiKey + "\r\nConnection: close\r\n\r\n";
  }
  sec.write(req);
  await sec.flush();
  List<int> bytes = [];
  await for (var chunk in sec) {
    bytes.addAll(chunk);
  }
  try { await sec.close(); } catch (_) {}
  String resp = utf8.decode(bytes, allowMalformed: true);
  int idx = resp.indexOf("\r\n\r\n");
  String b = idx >= 0 ? resp.substring(idx + 4) : resp;
  if (resp.toLowerCase().contains("transfer-encoding: chunked")) b = decodeChunked(b);
  return b;
}

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
      final b = await httpsRequest("POST", "register", {"name": name.text.trim(), "phone": phone.text.trim(), "password": pass.text.trim(), "blood_group": bloodGroup, "district": district.text.trim(), "role": role});
      final data = jsonDecode(b);
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
