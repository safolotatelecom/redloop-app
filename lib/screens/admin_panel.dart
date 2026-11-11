import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String baseUrl = "https://redloop.safolota.com/api.php";
const String apiKey = "redloop2026secure";

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});
  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  int tab = 0;
  List users = [];
  List passReqs = [];
  List bloodReqs = [];
  List donorRatings = [];
  List userRatings = [];
  bool loading = true;
  final tempCtrl = TextEditingController();
  final noticeCtrl = TextEditingController();
  final waCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  Future<List> fetchAction(String action) async {
    try {
      final res = await http.get(Uri.parse("$baseUrl?action=$action"), headers: {"X-API-KEY": apiKey}).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      return data['data'] ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<void> loadAll() async {
    setState(() => loading = true);
    final u = await fetchAction("all_users");
    final p = await fetchAction("password_requests");
    final b = await fetchAction("blood_requests");
    Map<String, dynamic> ratingData = {"donor_ratings": [], "user_ratings": []};
    try {
      final r = await http.get(Uri.parse("$baseUrl?action=admin_all_ratings"), headers: {"X-API-KEY": apiKey}).timeout(const Duration(seconds: 15));
      ratingData = jsonDecode(r.body);
    } catch (_) {}
    try {
      final s = await http.get(Uri.parse("$baseUrl?action=settings"), headers: {"X-API-KEY": apiKey});
      final sd = jsonDecode(s.body);
      if (sd['success'] == true) {
        noticeCtrl.text = sd['data']['notice'] ?? "";
        waCtrl.text = sd['data']['admin_whatsapp'] ?? "";
      }
    } catch (_) {}
    setState(() {
      users = u;
      passReqs = p;
      bloodReqs = b;
      donorRatings = ratingData['donor_ratings'] ?? [];
      userRatings = ratingData['user_ratings'] ?? [];
      loading = false;
    });
  }

  Future<void> approvePass(String phone) async {
    if (tempCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Temp Password লিখুন")));
      return;
    }
    final res = await http.post(Uri.parse("$baseUrl?action=approve_password"), headers: {"X-API-KEY": apiKey}, body: {"phone": phone, "temp_password": tempCtrl.text.trim()});
    final data = jsonDecode(res.body);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'])));
    tempCtrl.clear();
    loadAll();
  }

  Future<void> deleteRating(String type, int id) async {
    bool confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Rating?"),
        content: const Text("এই রেটিং + মন্তব্য মুছে যাবে।"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Delete", style: TextStyle(color: Colors.white))),
        ],
      ),
    ) ?? false;
    if (!confirm) return;
    await http.post(Uri.parse("$baseUrl?action=delete_rating"), headers: {"X-API-KEY": apiKey}, body: {"type": type, "id": id.toString()});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rating deleted")));
    loadAll();
  }

  // ===== ADMIN USER CONTROL =====
  Future<void> editUser(Map u) async {
    final nameCtrl = TextEditingController(text: u['name'] ?? "");
    final districtCtrl = TextEditingController(text: u['district'] ?? "");
    String blood = (u['blood_group'] ?? "O+").toString();
    String role = (u['role'] ?? "user").toString();
    bool? saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text("Edit User - ${u['name']}"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name", border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: districtCtrl, decoration: const InputDecoration(labelText: "District", border: OutlineInputBorder())),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: ["A+","A-","B+","B-","O+","O-","AB+","AB-"].contains(blood) ? blood : "O+",
                  decoration: const InputDecoration(labelText: "Blood Group", border: OutlineInputBorder()),
                  items: ["A+","A-","B+","B-","O+","O-","AB+","AB-"].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (v) => setD(() => blood = v!),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: ["user","donor","admin"].contains(role) ? role : "user",
                  decoration: const InputDecoration(labelText: "Role", border: OutlineInputBorder()),
                  items: ["user","donor","admin"].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setD(() => role = v!),
                ),
                const SizedBox(height: 8),
                Text("Phone: ${u['phone']} (Phone বদলানো যাবে না)", style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Save", style: TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final res = await http.post(Uri.parse("$baseUrl?action=update_user"), headers: {"X-API-KEY": apiKey}, body: {"id": u['id'].toString(), "name": nameCtrl.text.trim(), "district": districtCtrl.text.trim(), "blood_group": blood, "role": role});
    final data = jsonDecode(res.body);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'])));
    loadAll();
  }

  Future<void> deleteUser(Map u) async {
    bool confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete User?"),
        content: Text("${u['name']} (${u['phone']}) কে পুরো ডিলিট করবেন? এই কাজ ফেরানো যাবে না।"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Delete", style: TextStyle(color: Colors.white))),
        ],
      ),
    ) ?? false;
    if (!confirm) return;
    final res = await http.post(Uri.parse("$baseUrl?action=delete_user"), headers: {"X-API-KEY": apiKey}, body: {"id": u['id'].toString()});
    final data = jsonDecode(res.body);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'])));
    loadAll();
  }

  Future<void> toggleBan(Map u) async {
    bool isBanned = (u['status'] ?? "active") == "banned";
    bool confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isBanned ? "Unban User?" : "Ban User?"),
        content: Text(isBanned ? "${u['name']} কে আবার চালু করবেন?" : "${u['name']} কে Ban করবেন? Ban করলে সে Login করতে পারবে না, Donor List এও দেখাবে না।"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: isBanned ? Colors.green : Colors.red), child: Text(isBanned ? "Unban" : "Ban", style: const TextStyle(color: Colors.white))),
        ],
      ),
    ) ?? false;
    if (!confirm) return;
    String action = isBanned ? "unban_user" : "ban_user";
    final res = await http.post(Uri.parse("$baseUrl?action=$action"), headers: {"X-API-KEY": apiKey}, body: {"id": u['id'].toString()});
    final data = jsonDecode(res.body);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'])));
    loadAll();
  }

  Widget tabButton(String label, int index, IconData icon) {
    bool sel = tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: sel ? Colors.red : Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
          child: Column(
            children: [
              Icon(icon, color: sel ? Colors.white : Colors.black, size: 20),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(color: sel ? Colors.white : Colors.black, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget ratingCard(Map r, String type) {
    int stars = (r['stars'] as num).toInt();
    bool isBad = stars <= 2;
    String title = type == "donor" ? "Donor: ${r['donor_name'] ?? ''} (${r['donor_phone']})" : "User: ${r['user_name'] ?? ''} (${r['user_phone']})";
    String sub = type == "donor" ? "Rated by User: ${r['rater_name'] ?? ''} (${r['rater_phone']})" : "Rated by Donor: ${r['donor_name'] ?? ''} (${r['donor_phone']})";
    return Card(
      color: isBad ? Colors.red.shade50 : Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: isBad ? Colors.red : Colors.amber, child: Text("$stars⭐", style: const TextStyle(fontSize: 11, color: Colors.white))),
        title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sub, style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 4),
            Text(r['comment']?.toString().isEmpty == true ? "No comment" : "💬 ${r['comment']}", style: TextStyle(fontSize: 12, color: isBad ? Colors.red : Colors.black87)),
            Text(r['created_at'].toString().substring(0, 16), style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => deleteRating(type, (r['id'] as num).toInt())),
      ),
    );
  }

  Widget userCard(Map u) {
    bool isBanned = (u['status'] ?? "active") == "banned";
    bool isAdmin = (u['role'] ?? "") == "admin";
    return Card(
      color: isBanned ? Colors.red.shade50 : Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            ListTile(
              leading: CircleAvatar(backgroundColor: isBanned ? Colors.grey : Colors.red, child: Text((u['blood_group'] ?? "?").toString(), style: const TextStyle(color: Colors.white, fontSize: 11))),
              title: Row(
                children: [
                  Expanded(child: Text(u['name'] ?? "", style: TextStyle(fontWeight: FontWeight.bold, decoration: isBanned ? TextDecoration.lineThrough : null))),
                  if (isBanned) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)), child: const Text("BANNED", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                  if (isAdmin && !isBanned) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(10)), child: const Text("ADMIN", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                ],
              ),
              subtitle: Text("Phone: ${u['phone']} | District: ${u['district']} | Role: ${u['role']} | Status: ${u['status'] ?? 'active'}"),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(onPressed: () => editUser(u), icon: const Icon(Icons.edit, size: 18, color: Colors.blue), label: const Text("Edit", style: TextStyle(color: Colors.blue))),
                TextButton.icon(onPressed: () => toggleBan(u), icon: Icon(isBanned ? Icons.check_circle : Icons.block, size: 18, color: isBanned ? Colors.green : Colors.orange), label: Text(isBanned ? "Unban" : "Ban", style: TextStyle(color: isBanned ? Colors.green : Colors.orange))),
                TextButton.icon(onPressed: () => deleteUser(u), icon: const Icon(Icons.delete, size: 18, color: Colors.red), label: const Text("Delete", style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Panel"), backgroundColor: Colors.red, foregroundColor: Colors.white, actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: loadAll)]),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                tabButton("Users", 0, Icons.people),
                const SizedBox(width: 6),
                tabButton("Password", 1, Icons.lock),
                const SizedBox(width: 6),
                tabButton("Blood Req", 2, Icons.bloodtype),
                const SizedBox(width: 6),
                tabButton("Ratings", 3, Icons.star),
                const SizedBox(width: 6),
                tabButton("Settings", 4, Icons.settings),
              ],
            ),
          ),
          Expanded(child: loading ? const Center(child: CircularProgressIndicator(color: Colors.red)) : buildTabContent()),
        ],
      ),
    );
  }

  Widget buildTabContent() {
    if (tab == 0) {
      if (users.isEmpty) return const Center(child: Text("No users"));
      return ListView.builder(itemCount: users.length, itemBuilder: (_, i) => userCard(users[i]));
    }
    if (tab == 1) {
      if (passReqs.isEmpty) return const Center(child: Text("No pending password requests"));
      return Column(
        children: [
          Padding(padding: const EdgeInsets.all(10), child: TextField(controller: tempCtrl, decoration: const InputDecoration(labelText: "Temp Password (যেমন: 1234)", border: OutlineInputBorder()))),
          Expanded(child: ListView.builder(itemCount: passReqs.length, itemBuilder: (_, i) {
            var p = passReqs[i];
            return Card(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), child: ListTile(title: Text("Phone: ${p['phone']}"), subtitle: Text("Requested: ${p['created_at']}"), trailing: ElevatedButton(onPressed: () => approvePass(p['phone'].toString()), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("Approve", style: TextStyle(color: Colors.white)))));
          })),
        ],
      );
    }
    if (tab == 2) {
      if (bloodReqs.isEmpty) return const Center(child: Text("No blood requests"));
      return ListView.builder(itemCount: bloodReqs.length, itemBuilder: (_, i) {
        var b = bloodReqs[i];
        return Card(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), child: ListTile(leading: CircleAvatar(backgroundColor: Colors.red, child: Text((b['blood_group'] ?? "?").toString(), style: const TextStyle(color: Colors.white, fontSize: 11))), title: Text("${b['name']} - ${b['blood_group']}"), subtitle: Text("Hospital: ${b['hospital']} | Phone: ${b['phone']} | ${b['district']}"), trailing: Text(b['status'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold))));
      });
    }
    if (tab == 3) {
      return SingleChildScrollView(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)), child: Text("Total: ${donorRatings.length} Donor Ratings | ${userRatings.length} User Ratings", style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
        const SizedBox(height: 14),
        const Text("⭐ Donor Ratings (User → Donor)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
        const Text("ইউজাররা ডোনারদের কী রেটিং দিয়েছে", style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        if (donorRatings.isEmpty) const Text("এখনো কোনো Donor Rating নেই", style: TextStyle(color: Colors.grey)),
        ...donorRatings.map((r) => ratingCard(r, "donor")).toList(),
        const SizedBox(height: 20),
        const Text("⭐ User Ratings (Donor → User)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
        const Text("ডোনাররা ইউজারদের কী রেটিং দিয়েছে", style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        if (userRatings.isEmpty) const Text("এখনো কোনো User Rating নেই", style: TextStyle(color: Colors.grey)),
        ...userRatings.map((r) => ratingCard(r, "user")).toList(),
        const SizedBox(height: 20),
        const Text("Note: ১-২ ⭐ রেটিং লাল দেখাবে। খারাপ মন্তব্য হলে Delete করতে পারবেন।", style: TextStyle(color: Colors.grey, fontSize: 12)),
      ]));
    }
    return Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Notice", style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      TextField(controller: noticeCtrl, maxLines: 2, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Donate Blood, Save Life")),
      const SizedBox(height: 16),
      const Text("Admin WhatsApp", style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      TextField(controller: waCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "88017XXXXXXXX")),
      const SizedBox(height: 20),
      const Text("Settings change করতে cPanel থেকে settings টেবিলে বদলাতে হবে। এই version এ শুধু দেখা যাবে।", style: TextStyle(color: Colors.grey, fontSize: 12)),
    ]));
  }
}
