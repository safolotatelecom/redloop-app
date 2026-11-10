import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// FROZEN
const String baseUrl = "https://redloop.safolota.com/api.php";
const String apiKey = "redloop2026secure";

class DonorListScreen extends StatefulWidget {
  const DonorListScreen({super.key});
  @override
  State<DonorListScreen> createState() => _DonorListScreenState();
}

class _DonorListScreenState extends State<DonorListScreen> {
  List<dynamic> donors = [];
  bool loading = true;
  String msg = "";
  String filter = "All";
  final List<String> groups = ["All", "A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"];

  @override
  void initState() {
    super.initState();
    loadDonors();
  }

  Future<void> loadDonors() async {
    setState(() {
      loading = true;
      msg = "";
    });
    try {
      final uri = Uri.parse(baseUrl + "?action=donors");
      final res = await http.get(uri, headers: {"X-API-KEY": apiKey}).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        setState(() {
          donors = data['data'] as List;
        });
      } else {
        setState(() {
          msg = data['message'].toString();
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

  List<dynamic> get filtered {
    if (filter == "All") return donors;
    return donors.where((d) => d['blood_group'].toString() == filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Find Blood Donors"), backgroundColor: Colors.red, foregroundColor: Colors.white, actions: [IconButton(onPressed: loadDonors, icon: const Icon(Icons.refresh))]),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String>(value: filter, decoration: const InputDecoration(labelText: "Filter by Blood Group", border: OutlineInputBorder()), items: groups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(), onChanged: (v) => setState(() => filter = v!)),
          ),
          if (loading) const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.red))),
          if (!loading && msg.isNotEmpty) Padding(padding: const EdgeInsets.all(12), child: Text(msg, style: const TextStyle(color: Colors.red))),
          if (!loading)
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text("No donors found"))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final d = filtered[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: Colors.red, child: Text(d['blood_group'].toString(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                            title: Text(d['name'].toString()),
                            subtitle: Text("Phone: " + d['phone'].toString() + "\nDistrict: " + (d['district'] ?? "").toString()),
                            isThreeLine: true,
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
