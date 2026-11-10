import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String baseUrl = "https://redloop.safolota.com/api.php";
const String apiKey = "redloop2026secure";

Widget starRow(int selected, Function(int) onTap) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(5, (i) => IconButton(
      icon: Icon(Icons.star, color: i < selected ? Colors.amber : Colors.grey, size: 40),
      onPressed: () => onTap(i + 1),
    )),
  );
}

String starLabel(int s) {
  if (s == 5) return "🌟 Excellent - খুব ভালো";
  if (s == 4) return "👍 Good - ভালো";
  if (s == 3) return "😐 Average - মোটামুটি";
  if (s == 2) return "👎 Poor - খারাপ";
  return "🚫 Very Bad - খুব খারাপ";
}

List<String> quickCommentsDonor = [
  "সময়মতো এসেছে, ভালো ব্যবহার",
  "খুব দ্রুত সাড়া দিয়েছে",
  "ব্যবহার খুব ভালো",
  "অনেকক্ষণ অপেক্ষা করিয়েছে",
  "ফোন ধরেনি / আসেনি",
];

List<String> quickCommentsUser = [
  "সময়মতো ছিল, ভালো ব্যবহার",
  "হাসপাতালে ব্যবস্থা ভালো ছিল",
  "যোগাযোগ ভালো ছিল",
  "অনেকক্ষণ অপেক্ষা করিয়েছে",
  "ব্যবহার ভালো ছিল না",
];

class RateDonorScreen extends StatefulWidget {
  final String myPhone;
  final String donorPhone;
  final String donorName;
  const RateDonorScreen({super.key, required this.myPhone, required this.donorPhone, this.donorName = ""});
  @override State<RateDonorScreen> createState() => _RateDonorScreenState();
}

class _RateDonorScreenState extends State<RateDonorScreen> {
  late TextEditingController myCtrl;
  late TextEditingController donorCtrl;
  final commentCtrl = TextEditingController();
  int stars = 5;
  bool loading = false;
  bool already = false;
  @override void initState() {
    super.initState();
    myCtrl = TextEditingController(text: widget.myPhone);
    donorCtrl = TextEditingController(text: widget.donorPhone);
  }
  Future<void> submit() async {
    if (myCtrl.text.trim().isEmpty || donorCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("দুইটা নম্বরই দিন")));
      return;
    }
    if (myCtrl.text.trim() == donorCtrl.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("নিজেকে রেটিং দেওয়া যাবে না")));
      return;
    }
    setState(() => loading = true);
    try {
      final res = await http.post(Uri.parse("$baseUrl?action=rate_donor"), headers: {"X-API-KEY": apiKey}, body: {"donor_phone": donorCtrl.text.trim(), "rater_phone": myCtrl.text.trim(), "stars": stars.toString(), "comment": commentCtrl.text.trim()}).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        setState(() => already = true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Thanks! Donor rating submitted"), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      } else {
        if (data['already_exists'] == true) setState(() => already = true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: data['already_exists'] == true ? Colors.orange.shade800 : Colors.red));
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Network error, try again")));
    }
    if (mounted) setState(() => loading = false);
  }
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Rate Donor ${widget.donorName}"), backgroundColor: Colors.red, foregroundColor: Colors.white),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)), child: const Text("রক্ত পাওয়ার পর ডোনারকে রেটিং দিন।\nডোনারের ব্যবহার + সময় কেমন ছিল?", style: TextStyle(fontWeight: FontWeight.bold))),
        const SizedBox(height: 20),
        const Text("⭐ Rating", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        starRow(stars, (v) => setState(() => stars = v)),
        Center(child: Text("$stars / 5 Star", style: const TextStyle(fontWeight: FontWeight.bold))),
        Center(child: Text(starLabel(stars), style: TextStyle(color: Colors.grey.shade700))),
        const SizedBox(height: 20),
        TextField(controller: donorCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Donor এর Phone", border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: myCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "আপনার Phone (User)", border: OutlineInputBorder())),
        const SizedBox(height: 20),
        const Text("💬 সংক্ষিপ্ত মন্তব্য (সর্বোচ্চ ২০০ অক্ষর)", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(controller: commentCtrl, maxLength: 200, maxLines: 3, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "যেমন: সময়মতো এসেছে, ভালো ব্যবহার...")),
        const SizedBox(height: 8),
        const Text("দ্রুত মন্তব্য:", style: TextStyle(color: Colors.grey, fontSize: 12)),
        Wrap(spacing: 8, runSpacing: 8, children: quickCommentsDonor.map((c) => ActionChip(label: Text(c, style: const TextStyle(fontSize: 12)), onPressed: () => setState(() => commentCtrl.text = c))).toList()),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: loading || already ? null : submit, style: ElevatedButton.styleFrom(backgroundColor: already ? Colors.grey : Colors.red), child: Text(loading ? "Submitting..." : already ? "Already Rated" : "Submit Rating", style: const TextStyle(color: Colors.white)))),
        if (already) const Padding(padding: EdgeInsets.only(top: 10), child: Center(child: Text("এই ডোনারকে আপনি আগেই রেটিং দিয়েছেন।", style: TextStyle(color: Colors.grey)))),
      ])),
    );
  }
}

class RateUserScreen extends StatefulWidget {
  final String donorPhone;
  final String userPhone;
  final String userName;
  const RateUserScreen({super.key, required this.donorPhone, this.userPhone = "", this.userName = ""});
  @override State<RateUserScreen> createState() => _RateUserScreenState();
}

class _RateUserScreenState extends State<RateUserScreen> {
  late TextEditingController donorCtrl;
  late TextEditingController userCtrl;
  final commentCtrl = TextEditingController();
  int stars = 5;
  bool loading = false;
  bool already = false;
  @override void initState() {
    super.initState();
    donorCtrl = TextEditingController(text: widget.donorPhone);
    userCtrl = TextEditingController(text: widget.userPhone);
  }
  Future<void> submit() async {
    if (donorCtrl.text.trim().isEmpty || userCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("দুইটা নম্বরই দিন")));
      return;
    }
    if (donorCtrl.text.trim() == userCtrl.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("নিজেকে রেটিং দেওয়া যাবে না")));
      return;
    }
    setState(() => loading = true);
    try {
      final res = await http.post(Uri.parse("$baseUrl?action=rate_user"), headers: {"X-API-KEY": apiKey}, body: {"user_phone": userCtrl.text.trim(), "donor_phone": donorCtrl.text.trim(), "stars": stars.toString(), "comment": commentCtrl.text.trim()}).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        setState(() => already = true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Thanks! User rating submitted"), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      } else {
        if (data['already_exists'] == true) setState(() => already = true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: data['already_exists'] == true ? Colors.orange.shade800 : Colors.red));
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Network error, try again")));
    }
    if (mounted) setState(() => loading = false);
  }
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Rate User ${widget.userName}"), backgroundColor: Colors.red, foregroundColor: Colors.white),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)), child: const Text("ডোনার হিসেবে ইউজারকে রেটিং দিচ্ছেন।\nরক্ত দেওয়ার পর ইউজারের ব্যবহার কেমন ছিল?", style: TextStyle(fontWeight: FontWeight.bold))),
        const SizedBox(height: 20),
        const Text("⭐ Rating", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        starRow(stars, (v) => setState(() => stars = v)),
        Center(child: Text("$stars / 5 Star", style: const TextStyle(fontWeight: FontWeight.bold))),
        Center(child: Text(starLabel(stars), style: TextStyle(color: Colors.grey.shade700))),
        const SizedBox(height: 20),
        TextField(controller: userCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "User এর Phone (যাকে রক্ত দিয়েছেন)", border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: donorCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "আপনার Phone (Donor)", border: OutlineInputBorder())),
        const SizedBox(height: 20),
        const Text("💬 সংক্ষিপ্ত মন্তব্য (সর্বোচ্চ ২০০ অক্ষর)", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(controller: commentCtrl, maxLength: 200, maxLines: 3, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "যেমন: সময়মতো ছিল, ভালো ব্যবহার...")),
        const SizedBox(height: 8),
        const Text("দ্রুত মন্তব্য:", style: TextStyle(color: Colors.grey, fontSize: 12)),
        Wrap(spacing: 8, runSpacing: 8, children: quickCommentsUser.map((c) => ActionChip(label: Text(c, style: const TextStyle(fontSize: 12)), onPressed: () => setState(() => commentCtrl.text = c))).toList()),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: loading || already ? null : submit, style: ElevatedButton.styleFrom(backgroundColor: already ? Colors.grey : Colors.red), child: Text(loading ? "Submitting..." : already ? "Already Rated" : "Submit Rating", style: const TextStyle(color: Colors.white)))),
        if (already) const Padding(padding: EdgeInsets.only(top: 10), child: Center(child: Text("এই ইউজারকে আপনি আগেই রেটিং দিয়েছেন।", style: TextStyle(color: Colors.grey)))),
      ])),
    );
  }
}

class RatingDetailView extends StatefulWidget {
  final String phone;
  final bool isDonor;
  const RatingDetailView({super.key, required this.phone, this.isDonor = true});
  @override State<RatingDetailView> createState() => _RatingDetailViewState();
}

class _RatingDetailViewState extends State<RatingDetailView> {
  List ratings = [];
  bool loading = true;
  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    try {
      final action = widget.isDonor ? "donor_rating_detail" : "user_rating_detail";
      final key = widget.isDonor ? "donor_phone" : "user_phone";
      final res = await http.post(Uri.parse("$baseUrl?action=$action"), headers: {"X-API-KEY": apiKey}, body: {key: widget.phone});
      final data = jsonDecode(res.body);
      setState(() { ratings = data['data'] ?? []; loading = false; });
    } catch (_) { if (mounted) setState(() => loading = false); }
  }
  @override Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: Colors.red));
    if (ratings.isEmpty) return const Text("⭐ No rating yet", style: TextStyle(color: Colors.grey));
    double avg = ratings.map((e) => (e['stars'] as num).toDouble()).reduce((a, b) => a + b) / ratings.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("⭐ ${avg.toStringAsFixed(1)}  (${ratings.length} rating)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800, fontSize: 16)),
      const SizedBox(height: 10),
      ...ratings.map((r) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
        leading: CircleAvatar(backgroundColor: Colors.red, child: Text("${r['stars']}⭐", style: const TextStyle(fontSize: 11, color: Colors.white))),
        title: Text("${widget.isDonor ? (r['rater_name'] ?? 'User') : (r['donor_name'] ?? 'Donor')} (${widget.isDonor ? r['rater_phone'] : r['donor_phone']})"),
        subtitle: Text(r['comment']?.toString().isEmpty == true ? "No comment" : r['comment'].toString()),
        trailing: Text(r['created_at'].toString().substring(0, 10), style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ))).toList(),
    ]);
  }
}
