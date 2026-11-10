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

  @override
  State<DonorListScreen> createState() => _DonorListScreenState();
}

class _DonorListScreenState extends State<DonorListScreen> {
  List donors = [];
  List filtered = [];
  Map<String, dynamic> ratings = {};
  String filter = "All";
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadDonors();
  }

  Future<void> loadDonors() async {
    setState(() {
      loading = true;
    });
    try {
      final res = await http.get(
        Uri.parse("$baseUrl?action=donors"),
        headers: {"X-API-KEY": apiKey},
      );
      final data = jsonDecode(res.body);

      final rRes = await http.get(
        Uri.parse("$baseUrl?action=donor_ratings"),
        headers: {"X-API-KEY": apiKey},
      );
      final rData = jsonDecode(rRes.body);

      setState(() {
        donors = data['data'] ?? [];
        ratings = Map<String, dynamic>.from(rData['data'] ?? {});
        donors.sort((a, b) {
          double ra = 0;
          double rb = 0;
          if (ratings[a['phone']] != null) {
            ra = (ratings[a['phone']]['avg'] as num).toDouble();
          }
          if (ratings[b['phone']] != null) {
            rb = (ratings[b['phone']]['avg'] as num).toDouble();
          }
          return rb.compareTo(ra);
        });
        filtered = donors;
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void applyFilter(String g) {
    setState(() {
      filter = g;
      if (g == "All") {
        filtered = donors;
      } else {
        filtered = donors.where((d) => d['blood_group'] == g).toList();
      }
    });
  }

  Future<void> callDonor(String phone) async {
    final u = Uri.parse("tel:$phone");
    if (await canLaunchUrl(u)) {
      await launchUrl(u);
    }
  }

  Future<void> whatsappDonor(Map d) async {
    String p = d['phone'].toString().replaceAll("+", "");
    if (p.startsWith("01")) {
      p = "880" + p.substring(1);
    }
    final text = "Hello, I need ${d['blood_group']} blood. Are you available? - RedLoop";
    final u = Uri.parse("https://wa.me/$p?text=${Uri.encodeComponent(text)}");
    if (await canLaunchUrl(u)) {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    }
  }

  void showReviews(Map d) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Reviews - ${d['name']}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  RatingDetailView(
                    phone: d['phone'].toString(),
                    isDonor: true,
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Close"),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> rateDonor(Map d) async {
    final ok = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RateDonorScreen(
          myPhone: widget.myPhone,
          donorPhone: d['phone'].toString(),
          donorName: d['name'].toString(),
        ),
      ),
    );
    if (ok == true) {
      loadDonors();
    }
  }

  Widget buildDonorCard(Map d) {
    var rate = ratings[d['phone']];
    double avg = 0;
    int total = 0;
    if (rate != null) {
      avg = (rate['avg'] as num).toDouble();
      total = (rate['total'] as num).toInt();
    }
    String ratingText = "⭐ No rating yet";
    if (total > 0) {
      ratingText = "⭐ ${avg.toStringAsFixed(1)}  ($total rating)";
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.red,
                child: Text(
                  d['blood_group'] ?? "?",
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              title: Text(d['name'] ?? ""),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("District: ${d['district']} | Phone: ${d['phone']}"),
                  const SizedBox(height: 4),
                  Text(
                    ratingText,
                    style: TextStyle(
                      color: total == 0 ? Colors.grey : Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.call, color: Colors.green),
                    onPressed: () => callDonor(d['phone'].toString()),
                  ),
                  IconButton(
                    icon: const Icon(Icons.message, color: Colors.blue),
                    onPressed: () => whatsappDonor(d),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => showReviews(d),
                  icon: const Icon(Icons.comment, size: 18, color: Colors.grey),
                  label: const Text(
                    "Reviews",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => rateDonor(d),
                  icon: const Icon(Icons.star, color: Colors.amber, size: 18),
                  label: const Text(
                    "Rate Donor",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<String> groups = ["All", "A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Blood Donors"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadDonors,
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(10),
            child: Row(
              children: groups.map((g) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(g),
                    selected: filter == g,
                    selectedColor: Colors.red,
                    labelStyle: TextStyle(
                      color: filter == g ? Colors.white : Colors.black,
                    ),
                    onSelected: (_) => applyFilter(g),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.red),
                  )
                : filtered.isEmpty
                    ? const Center(child: Text("No donors found"))
                    : RefreshIndicator(
                        onRefresh: loadDonors,
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            return buildDonorCard(filtered[i]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
