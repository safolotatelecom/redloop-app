import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'rating_system.dart';

const String baseUrl = "https://redloop.safolota.com/api.php";
const String apiKey = "redloop2026secure";

class DonorListScreen extends StatefulWidget {
  final String myPhone;
  const DonorListScreen({super.key, this.myPhone = ""});
  @override State<DonorListScreen> createState() => _DonorListScreenState();
}

class _DonorListScreenState extends State<DonorListScreen> {
  List donors = [];
  List filtered = [];
  Map<String, dynamic> ratings = {};
  String filter = "All";
  bool loading = true;
  @override void initState() { super.initState(); loadDonors(); }
  Future<void> loadDonors() async {
    setState(() => loading = true);
    try {
      final res = await http.get(Uri.parse("$baseUrl?action=donors"), headers: {"X-API-KEY": apiKey});
      final data = jsonDecode(res.body);
      final rRes = await http.get(Uri.parse("$baseUrl?action=donor_ratings"), headers: {"X-API-KEY": apiKey});
      final rData = jsonDecode(rRes.body);
      setState(() {
        donors = data['data'] ?? [];
        ratings = Map<String, dynamic>.from(rData['data'] ?? {});
        donors.sort((a, b) {
          double ra = ratings[a['phone']] != null ? (ratings[a['phone']]['avg'] as num).toDouble() : 0;
          double rb = ratings[b['phone']] != null ? (ratings[b['phone']]['avg'] as num).toDouble() : 0;
          return rb.compareTo(ra);
        });
        filtered = donors;
        loading = false;
      });
    } catch (_) { if (mounted) setState(() => loading = false); }
  }
  void applyFilter(String g) { setState(() { filter = g; filtered = g == "All" ? donors : donors.where((d) => d['blood_group'] == g).toList(); }); }
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Blood Donors"), backgroundColor: Colors.red, foregroundColor: Colors.white, actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: loadDonors)]),
      body: Column(children: [
        SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(10), child: Row(children: ["All","A+","A-","B+","B-","O+","O-","AB+","AB-"].map((g) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(g), selected: filter == g, selectedColor: Colors.red, labelStyle: TextStyle(color: filter == g ? Colors.white : Colors.black), onSelected: (_) => applyFilter(g)))).toList())),
        Expanded(child: loading ? const Center(child: CircularProgressIndicator(color: Colors.red)) : filtered.isEmpty ? const Center(child: Text("No donors found")) : RefreshIndicator(onRefresh: loadDonors, child: ListView.builder(itemCount: filtered.length, itemBuilder: (_, i) {
          var d = filtered[i];
          var rate = ratings[d['phone']];
          double avg = rate != null ? (rate['avg'] as num).toDouble() : 0;
          int total = rate != null ? (rate['total'] as num).toInt() : 0;
          return Card(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: Padding(padding: const EdgeInsets.all(8), child: Column(children: [
            ListTile(
              leading: CircleAvatar(backgroundColor: Colors.red, child: Text(d['blood_group'] ?? "?", style: const TextStyle(color: Colors.white, fontSize: 12))),
              title: Text(d['name'] ?? ""),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("District: ${d['district']} | Phone: ${d['phone']}"),
                const SizedBox(height: 4),
                Text(total == 0 ? "⭐ No rating yet" : "⭐ ${avg.toStringAsFixed(1)}  ($total rating)", style: TextStyle(color: total == 0 ? Colors.grey : Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
              ]),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.call, color: Colors.green), onPressed: () async { final u = Uri.parse("tel:${d['phone']}"); if (await canLaunchUrl(u)) await launchUrl(u); }),
                IconButton(icon: const Icon(Icons.message, color: Colors.blue), onPressed: () async { String p = d['phone'].toString().replaceAll("+", ""); if (p.startsWith("01")) p = "880" + p.substring(1); final u = Uri.parse("https://wa.me/$p?text=${Uri.encodeComponent("Hello, I need ${d['blood_group']} blood. Are you available? - RedLoop")}"); if (await canLaunchUrl(u)) await launchUrl(u, mode: LaunchMode.externalApplication); }),
              ]),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              TextButton.icon(onPressed: () { showDialog(context: context, builder: (_) => Dialog(child: Padding(padding: const EdgeInsets.all(16), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [Text("Reviews - ${d['name']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 10), RatingDetailView(phone: d['phone'].toString(), isDonor: true), const SizedBox(height: 10), TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))]))))); }, icon: const Icon(Icons.comment, size: 18, color: Colors.grey), label: const Text("Reviews", style: TextStyle(color: Colors.grey))),
              TextButton.icon(onPressed: () async { final ok = await Navigator.push(context, MaterialPageRoute(builder: (_) => RateDonorScreen(myPhone: widget.myPhone, donorPhone: d['phone'].toString(), donorName: d['name'].toString()))); if (ok == true) loadDonors(); }, icon: const Icon(Icons.star, color: Colors.amber, size: 18), label: const Text("Rate Donor", style: TextStyle(color: Colors.red))),
            ]),
          ]))));
        }))),
      ]),
    );
  }
}
