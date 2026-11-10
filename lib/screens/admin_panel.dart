import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

const String baseUrl = "https://redloop.safolota.com/api.php";
const String apiKey = "redloop2026secure";

String toWhatsAppNumber(String phone) {
  String p = phone.replaceAll("+", "").replaceAll(" ", "").replaceAll("-", "");
  if (p.startsWith("01")) p = "880" + p.substring(1);
  return p;
}

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});
  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List users = [];
  List passReqs = [];
  List bloodReqs = [];
  Map<String, TextEditingController> tempCtrls = {};
  final waCtrl = TextEditingController();
  final logoCtrl = TextEditingController();
  final noticeCtrl = TextEditingController();
  String animType = "zoom";
  bool loading = false;

  @override
  void initState() { super.initState(); _tab = TabController(length: 4, vsync: this); loadAll(); }

  Future<Map> api(String action, [Map<String,String> body = const {}]) async {
    final res = await http.post(Uri.parse("$baseUrl?action=$action"), headers: {"X-API-KEY": apiKey}, body: body);
    return jsonDecode(res.body);
  }

  Future<void> loadAll() async {
    setState(() => loading = true);
    try {
      final u = await api("all_users");
      final p = await api("password_requests");
      final b = await http.get(Uri.parse("$baseUrl?action=blood_requests_list"), headers: {"X-API-KEY": apiKey});
      final s = await http.get(Uri.parse("$baseUrl?action=settings"), headers: {"X-API-KEY": apiKey});
      if (mounted) setState(() {
        users = u['data'] ?? []; passReqs = p['data'] ?? []; bloodReqs = jsonDecode(b.body)['data'] ?? [];
        var sd = jsonDecode(s.body)['data'] ?? {};
        waCtrl.text = sd['admin_whatsapp'] ?? ""; logoCtrl.text = sd['logo_url'] ?? ""; noticeCtrl.text = sd['notice'] ?? ""; animType = sd['animation_type'] ?? "zoom";
      });
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Future<void> approveReset(Map req) async {
    String phone = req['phone'].toString();
    String temp = tempCtrls[phone]?.text.trim() ?? "";
    if (temp.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Temp password লিখুন"))); return; }
    final data = await api("approve_reset", {"phone": phone, "temp_password": temp, "request_id": req['id'].toString()});
    if (data['success'] == true) {
      String wa = toWhatsAppNumber(phone);
      String text = Uri.encodeComponent("Hello, Your RedLoop Temporary Password is: $temp\nLogin করে নতুন Password সেট করুন।\n- RedLoop Team");
      final uri = Uri.parse("https://wa.me/$wa?text=$text");
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Approved! WhatsApp খুলেছে, Send চাপুন. ${data['email_sent']==true ? 'Email এও গেছে।' : ''}")));
      loadAll();
    }
  }

  Future<void> saveSettings() async {
    final d = await api("update_settings", {"logo_url": logoCtrl.text.trim(), "notice": noticeCtrl.text.trim(), "animation_type": animType, "admin_whatsapp": waCtrl.text.trim()});
    if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(d['message'] ?? "Saved")));
  }

  void showEditUser(Map u) {
    final name = TextEditingController(text: u['name'] ?? "");
    final phone = TextEditingController(text: u['phone'] ?? "");
    final email = TextEditingController(text: u['email'] ?? "");
    final bg = TextEditingController(text: u['blood_group'] ?? "");
    final dist = TextEditingController(text: u['district'] ?? "");
    String role = u['role'] ?? "donor";
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text("Edit User"),
      content: SingleChildScrollView(child: Column(children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: "Name")),
        TextField(controller: phone, decoration: const InputDecoration(labelText: "Phone")),
        TextField(controller: email, decoration: const InputDecoration(labelText: "Email")),
        TextField(controller: bg, decoration: const InputDecoration(labelText: "Blood Group")),
        TextField(controller: dist, decoration: const InputDecoration(labelText: "District")),
        DropdownButton<String>(value: role, isExpanded: true, items: const [DropdownMenuItem(value: "donor", child: Text("Donor")), DropdownMenuItem(value: "user", child: Text("User")), DropdownMenuItem(value: "admin", child: Text("Admin"))], onChanged: (v) { role = v!; (context as Element).markNeedsBuild(); }),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(onPressed: () async {
          final d = await api("edit_user", {"id": u['id'].toString(), "name": name.text.trim(), "phone": phone.text.trim(), "email": email.text.trim(), "blood_group": bg.text.trim(), "district": dist.text.trim(), "role": role});
          if (!mounted) return; Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(d['message'] ?? ""))); loadAll();
        }, child: const Text("Save")),
      ],
    ));
  }

  Future<void> confirmDelete(Map u) async {
    bool? ok = await showDialog(context: context, builder: (_) => AlertDialog(title: Text("Delete ${u['name']}?"), content: const Text("এই User কে ডিলিট করবেন?"), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")), ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Yes Delete", style: TextStyle(color: Colors.white)))]));
    if (ok == true) { await api("delete_user", {"id": u['id'].toString()}); loadAll(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Panel"), backgroundColor: Colors.red, foregroundColor: Colors.white, bottom: TabBar(controller: _tab, indicatorColor: Colors.white, labelColor: Colors.white, unselectedLabelColor: Colors.white70, tabs: const [Tab(text: "Users"), Tab(text: "Pass Req"), Tab(text: "Blood Req"), Tab(text: "Settings")])),
      body: loading ? const Center(child: CircularProgressIndicator(color: Colors.red)) : TabBarView(controller: _tab, children: [
        users.isEmpty ? const Center(child: Text("No users")) : ListView.builder(itemCount: users.length, itemBuilder: (_, i) {
          var u = users[i]; bool banned = (u['is_banned'] ?? 0) == 1;
          return Card(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: ListTile(
            leading: CircleAvatar(backgroundColor: banned ? Colors.grey : Colors.red, child: Text((u['name'] ?? "?").toString().substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white))),
            title: Text("${u['name']} ${banned ? '(BANNED)' : ''}", style: TextStyle(fontWeight: FontWeight.bold, color: banned ? Colors.grey : Colors.black)),
            subtitle: Text("Phone: ${u['phone']}\nBlood: ${u['blood_group']} | ${u['district']} | ${u['role']}"),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(onSelected: (v) async {
              if (v == 'edit') showEditUser(u);
              if (v == 'delete') confirmDelete(u);
              if (v == 'ban') { await api("ban_user", {"id": u['id'].toString(), "ban": banned ? "0" : "1"}); loadAll(); }
              if (v == 'copy') { await Clipboard.setData(ClipboardData(text: "Phone: ${u['phone']}")); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied"))); }
            }, itemBuilder: (_) => [const PopupMenuItem(value: 'edit', child: Text("✏️ Edit")), PopupMenuItem(value: 'ban', child: Text(banned ? "✅ Unban" : "🚫 Ban")), const PopupMenuItem(value: 'delete', child: Text("🗑️ Delete")), const PopupMenuItem(value: 'copy', child: Text("📋 Copy Info"))]),
          ));
        }),
        passReqs.isEmpty ? const Center(child: Text("No password requests")) : ListView.builder(itemCount: passReqs.length, itemBuilder: (_, i) {
          var r = passReqs[i]; String phone = r['phone'].toString(); tempCtrls.putIfAbsent(phone, () => TextEditingController());
          bool pending = r['status'] == 'pending';
          return Card(margin: const EdgeInsets.all(10), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Phone: $phone", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text("Status: ${r['status']} | ${r['created_at']}"),
            if (pending) ...[const SizedBox(height: 10), TextField(controller: tempCtrls[phone], decoration: const InputDecoration(labelText: "Temp Password (যেমন: 123456)", border: OutlineInputBorder())), const SizedBox(height: 10), SizedBox(width: double.infinity, height: 45, child: ElevatedButton.icon(onPressed: () => approveReset(r), icon: const Icon(Icons.send, color: Colors.white), label: const Text("Approve & Send WhatsApp + Email", style: TextStyle(color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green))) ]
            else Text("Temp ছিলো: ${r['temp_password']}"),
          ])));
        }),
        bloodReqs.isEmpty ? const Center(child: Text("No blood requests")) : ListView.builder(itemCount: bloodReqs.length, itemBuilder: (_, i) {
          var r = bloodReqs[i];
          return Card(margin: const EdgeInsets.all(10), child: ListTile(leading: CircleAvatar(backgroundColor: Colors.red, child: Text((r['blood_group'] ?? "?").toString(), style: const TextStyle(color: Colors.white, fontSize: 12))), title: Text("${r['patient_name']} - ${r['blood_group']} (${r['bags']} bag)"), subtitle: Text("Hospital: ${r['hospital']}\nPhone: ${r['phone']} | ${r['created_at']}"), isThreeLine: true, trailing: IconButton(icon: const Icon(Icons.call, color: Colors.green), onPressed: () async { final uri = Uri.parse("tel:${r['phone']}"); if (await canLaunchUrl(uri)) await launchUrl(uri); })));
        }),
        SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Admin WhatsApp Number (Recovery Request আসবে এখানে)", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8), TextField(controller: waCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "যেমন: 8801712345678", border: OutlineInputBorder())),
          const SizedBox(height: 16), const Text("App Notice", style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), TextField(controller: noticeCtrl, decoration: const InputDecoration(border: OutlineInputBorder())),
          const SizedBox(height: 16), const Text("Logo URL", style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), TextField(controller: logoCtrl, decoration: const InputDecoration(border: OutlineInputBorder())),
          const SizedBox(height: 16), const Text("Animation", style: TextStyle(fontWeight: FontWeight.bold)), DropdownButton<String>(value: animType, isExpanded: true, items: const [DropdownMenuItem(value: "zoom", child: Text("Zoom")), DropdownMenuItem(value: "fade", child: Text("Fade")), DropdownMenuItem(value: "rotate", child: Text("Rotate"))], onChanged: (v) => setState(() => animType = v!)),
          const SizedBox(height: 20), SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: saveSettings, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Save Settings", style: TextStyle(color: Colors.white)))),
        ])),
      ]),
      floatingActionButton: FloatingActionButton(onPressed: loadAll, backgroundColor: Colors.red, child: const Icon(Icons.refresh, color: Colors.white)),
    );
  }
}
