import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String baseUrl = "https://redloop.safolota.com/api.php";
const String apiKey = "redloop2026secure";

class DonorListScreen extends StatefulWidget {
  const DonorListScreen({super.key});
  @override
  State<DonorListScreen> createState() => _DonorListScreenState();
}

class _DonorListScreenState extends State<DonorListScreen> {
  List donors = [];
  bool loading = true;
  String filter = "All";
  final groups = ["All", "A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"];

  @override
  void initState() {
    super.initState();
    loadDonors();
  }

  Future<void> loadDonors() async {
    setState(() => loading = true);
    try {
      final res = await http.get(Uri.parse("$baseUrl?action=donors"), headers: {"X-API-KEY": apiKey});
      final data = jsonDecode(res.body);
      if (data['success'] == true) donors = data['data'];
    } catch (_) {}
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final shown = filter == "All" ? donors : donors.where((d) => d['blood_group'] == filter).toList();
    return Scaffold(
      appBar: AppBar(title: const Text("Donor List"), backgroundColor: Colors.red, foregroundColor: Colors.white),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            child: Row(children: groups.map((g) => Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(g), selected: filter == g, selectedColor: Colors.red.shade100, onSelected: (_) => setState(() => filter = g)))).toList()),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(color: Colors.red))
                : shown.isEmpty
                    ? const Center(child: Text("No donors found."))
                    : ListView.builder(
                        itemCount: shown.length,
                        itemBuilder: (_, i) {
                          final d = shown[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: ListTile(
                              leading: CircleAvatar(backgroundColor: Colors.red, child: Text(d['blood_group'] ?? "?", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              title: Text(d['name'] ?? "Unknown"),
                              subtitle: Text("Phone: ${d['phone'] ?? ''}"),
                              trailing: const Icon(Icons.call, color: Colors.green),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
