import 'package:flutter/material.dart';

import '../api_helper.dart';

const Color _red = Color(0xFFDC2638);
const Color _dark = Color(0xFF20232B);
const Color _muted = Color(0xFF777D89);
const Color _background = Color(0xFFF7F7FA);

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  int _tab = 0;
  bool _loading = true;
  bool _saving = false;
  bool _isSuperAdmin = false;
  String? _loadError;

  Map<String, dynamic> _dashboard = {};
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _bloodRequests = [];
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _passwordRequests = [];
  List<Map<String, dynamic>> _ratings = [];
  List<Map<String, dynamic>> _notices = [];
  List<Map<String, dynamic>> _admins = [];
  final TextEditingController _userSearch = TextEditingController();
  final TextEditingController _bloodSearch = TextEditingController();
  final TextEditingController _whatsApp = TextEditingController();
  final TextEditingController _supportEmail = TextEditingController();
  final TextEditingController _termsVersion = TextEditingController();
  final TextEditingController _termsContent = TextEditingController();
  String _userStatus = '';
  String _userRole = '';
  String _bloodGroup = '';
  String _bloodStatus = '';

  static const List<String> _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _userSearch.dispose();
    _bloodSearch.dispose();
    _whatsApp.dispose();
    _supportEmail.dispose();
    _termsVersion.dispose();
    _termsContent.dispose();
    super.dispose();
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (value is Map && value['data'] is List) {
      return (value['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  String _text(dynamic value, [String fallback = '—']) {
    if (value == null || value.toString().trim().isEmpty) return fallback;
    return value.toString();
  }

  int _int(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  void _message(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? Colors.red.shade700 : _dark,
        ),
      );
  }

  String _error(Map<String, dynamic> result) {
    final errors = result['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
    }
    return _text(result['message'], 'অনুরোধটি সম্পন্ন হয়নি।');
  }

  Future<Map<String, dynamic>> _get(String path, {Map<String, String>? query}) {
    return ApiService.get(path, query: query);
  }

  Future<void> _loadAll() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

    try {
      final current = await _get('/user');
      if (current['success'] != true) {
        throw Exception(_error(current));
      }
      final currentUser = _map(current['user']);
      _isSuperAdmin = currentUser['role']?.toString() == 'super_admin';

      final jobs = await Future.wait([
        _get('/admin/dashboard'),
        _get('/admin/users'),
        _get('/admin/blood-requests'),
        _get('/admin/help-tickets'),
        _get('/admin/password-assistance-requests'),
        _get('/admin/ratings'),
        _get('/admin/notices'),
        if (_isSuperAdmin) _get('/admin/settings'),
        if (_isSuperAdmin) _get('/admin/administrators'),
      ]);

      final dashboard = jobs[0];
      final users = jobs[1];
      final blood = jobs[2];
      final tickets = jobs[3];
      final passwords = jobs[4];
      final ratings = jobs[5];
      final notices = jobs[6];

      if (!mounted) return;
      setState(() {
        _dashboard = _map(dashboard['statistics']);
        _users = _rows(users['users']);
        _bloodRequests = _rows(blood['blood_requests']);
        _tickets = _rows(tickets['data']);
        _passwordRequests = _rows(passwords['data']);
        _ratings = _rows(ratings['ratings']);
        _notices = _rows(notices['notices']);
        if (_isSuperAdmin) {
          final settings = jobs[7];
          final settingRows = _rows(settings['data']);
          final values = <String, String>{};
          for (final item in settingRows) {
            values[_text(item['setting_key'], '')] =
                _text(item['setting_value'], '');
          }
          _whatsApp.text = values['support_whatsapp'] ?? '';
          _supportEmail.text = values['support_email'] ?? '';
          _termsVersion.text = values['terms_version'] ?? '';
          _termsContent.text = values['terms_content'] ?? '';
          _admins = _rows(jobs[8]['data']);
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadUsers() async {
    final query = <String, String>{};
    if (_userSearch.text.trim().isNotEmpty) query['search'] = _userSearch.text.trim();
    if (_userStatus.isNotEmpty) query['status'] = _userStatus;
    if (_userRole.isNotEmpty) query['role'] = _userRole;
    final result = await _get('/admin/users', query: query);
    if (result['success'] == true && mounted) {
      setState(() => _users = _rows(result['users']));
    } else {
      _message(_error(result), error: true);
    }
  }

  Future<void> _loadBloodRequests() async {
    final query = <String, String>{};
    if (_bloodSearch.text.trim().isNotEmpty) query['search'] = _bloodSearch.text.trim();
    if (_bloodGroup.isNotEmpty) query['blood_group'] = _bloodGroup;
    if (_bloodStatus.isNotEmpty) query['status'] = _bloodStatus;
    final result = await _get('/admin/blood-requests', query: query);
    if (result['success'] == true && mounted) {
      setState(() => _bloodRequests = _rows(result['blood_requests']));
    } else {
      _message(_error(result), error: true);
    }
  }

  Future<void> _saveSetting(String key, String value) async {
    if (mounted) setState(() => _saving = true);
    try {
      final result = await ApiService.put(
        '/admin/settings/$key',
        body: {'setting_value': value},
      );
      if (result['success'] == true) {
        _message('সেটিংস সংরক্ষণ হয়েছে।');
      } else {
        _message(_error(result), error: true);
      }
    } catch (e) {
      _message('সংরক্ষণ করা যায়নি: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editUser(Map<String, dynamic> user) async {
    final name = TextEditingController(text: _text(user['name'], ''));
    final email = TextEditingController(text: _text(user['email'], ''));
    final phone = TextEditingController(text: _text(user['phone'], ''));
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ব্যবহারকারীর তথ্য সম্পাদনা'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'নাম')),
              const SizedBox(height: 10),
              TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'ইমেইল')),
              const SizedBox(height: 10),
              TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'ফোন')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('সংরক্ষণ')),
        ],
      ),
    );
    if (saved != true) {
      name.dispose(); email.dispose(); phone.dispose();
      return;
    }
    final result = await ApiService.put(
      '/admin/users/${user['id']}',
      body: {'name': name.text.trim(), 'email': email.text.trim(), 'phone': phone.text.trim()},
    );
    name.dispose(); email.dispose(); phone.dispose();
    if (result['success'] == true) {
      _message('ব্যবহারকারীর তথ্য আপডেট হয়েছে।');
      await _loadUsers();
    } else {
      _message(_error(result), error: true);
    }
  }

  Future<void> _toggleBan(Map<String, dynamic> user) async {
    final banned = user['account_status']?.toString() == 'banned';
    final ok = await _confirm(
      banned ? 'অ্যাকাউন্ট চালু করবেন?' : 'অ্যাকাউন্ট Ban করবেন?',
      '${_text(user['name'])} — ${banned ? 'আবার লগইন করতে পারবে।' : 'লগইন করতে পারবে না।'}',
      confirmText: banned ? 'Unban' : 'Ban',
      danger: !banned,
    );
    if (!ok) return;
    final result = await ApiService.patch(
      '/admin/users/${user['id']}/${banned ? 'unban' : 'ban'}',
    );
    if (result['success'] == true) {
      _message(_text(result['message'], 'সম্পন্ন হয়েছে।'));
      await _loadUsers();
    } else {
      _message(_error(result), error: true);
    }
  }

  Future<bool> _confirm(String title, String message, {String confirmText = 'নিশ্চিত করুন', bool danger = false}) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
              FilledButton(
                style: danger ? FilledButton.styleFrom(backgroundColor: _red) : null,
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(confirmText),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showBloodDetails(Map<String, dynamic> item) async {
    final result = await _get('/admin/blood-requests/${item['id']}');
    if (result['success'] != true) {
      _message(_error(result), error: true);
      return;
    }
    final request = _map(result['blood_request']);
    final requester = _map(request['requester']);
    final responses = _rows(request['responses']);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('রক্তের অনুরোধ · ${_text(request['blood_group'])}'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detail('হাসপাতাল', request['hospital_name']),
                _detail('জেলা', request['district']),
                _detail('এলাকা', request['area']),
                _detail('স্ট্যাটাস', request['status']),
                _detail('রোগী', request['patient_name']),
                _detail('প্রয়োজনীয় রক্ত', request['units']),
                _detail('অনুরোধকারী', requester['name']),
                _detail('ফোন', requester['phone']),
                const Divider(),
                Text('Donor Responses (${responses.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (responses.isEmpty) const Text('এখনো কোনো Donor Response নেই।'),
                ...responses.map((r) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(_text(r['donor_name'], 'Donor')),
                  subtitle: Text('Status: ${_text(r['status'])}'),
                )),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বন্ধ করুন'))],
      ),
    );
  }

  Future<void> _editSupportRequest(Map<String, dynamic> item, {required bool password}) async {
    final reply = TextEditingController(text: _text(item['admin_reply'], ''));
    final statusOptions = password
        ? ['pending', 'in_progress', 'approved', 'rejected', 'completed']
        : ['open', 'in_progress', 'solved', 'closed'];
    String status = _text(item['status'], statusOptions.first);
    final assigned = TextEditingController(text: _text(item['assigned_admin_id'], ''));
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(password ? 'Password Assistance' : 'Help Ticket'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: reply, maxLines: 4, decoration: const InputDecoration(labelText: 'Admin Reply')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: statusOptions.contains(status) ? status : statusOptions.first,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setDialog(() => status = v ?? status),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: assigned,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Assigned Admin ID (ঐচ্ছিক)'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('আপডেট')),
          ],
        ),
      ),
    );
    if (saved != true) {
      reply.dispose(); assigned.dispose();
      return;
    }
    final body = <String, dynamic>{
      'admin_reply': reply.text.trim(),
      'status': status,
    };
    if (assigned.text.trim().isNotEmpty) {
      body['assigned_admin_id'] = int.tryParse(assigned.text.trim());
    }
    final path = password
        ? '/admin/password-assistance-requests/${item['id']}'
        : '/admin/help-tickets/${item['id']}';
    final result = await ApiService.put(path, body: body);
    reply.dispose(); assigned.dispose();
    if (result['success'] == true) {
      _message(_text(result['message'], 'আপডেট হয়েছে।'));
      await _loadAll();
    } else {
      _message(_error(result), error: true);
    }
  }

  Future<void> _deleteRating(Map<String, dynamic> rating) async {
    final ok = await _confirm('রেটিং মুছবেন?', 'এই রেটিং ও মন্তব্য মুছে যাবে।', confirmText: 'Delete', danger: true);
    if (!ok) return;
    final result = await ApiService.delete('/admin/ratings/${rating['id']}');
    if (result['success'] == true) {
      _message('রেটিং মুছে ফেলা হয়েছে।');
      await _loadAll();
    } else {
      _message(_error(result), error: true);
    }
  }

  Future<void> _editNotice([Map<String, dynamic>? notice]) async {
    final title = TextEditingController(text: _text(notice?['title'], ''));
    final message = TextEditingController(text: _text(notice?['message'], ''));
    bool active = notice?['is_active'] != false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(notice == null ? 'নতুন Notice' : 'Notice সম্পাদনা'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: title, decoration: const InputDecoration(labelText: 'শিরোনাম')),
                  const SizedBox(height: 12),
                  TextField(controller: message, maxLines: 5, decoration: const InputDecoration(labelText: 'বিস্তারিত')),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('প্রকাশিত'),
                    value: active,
                    onChanged: (v) => setDialog(() => active = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('সংরক্ষণ')),
          ],
        ),
      ),
    );
    if (saved != true) {
      title.dispose(); message.dispose();
      return;
    }
    final body = {'title': title.text.trim(), 'message': message.text.trim(), 'is_active': active};
    final result = notice == null
        ? await ApiService.post('/admin/notices', body: body)
        : await ApiService.put('/admin/notices/${notice['id']}', body: body);
    title.dispose(); message.dispose();
    if (result['success'] == true) {
      _message(_text(result['message'], 'Notice সংরক্ষণ হয়েছে।'));
      await _loadAll();
    } else {
      _message(_error(result), error: true);
    }
  }

  Future<void> _deleteNotice(Map<String, dynamic> notice) async {
    final ok = await _confirm('Notice মুছবেন?', _text(notice['title']), confirmText: 'Delete', danger: true);
    if (!ok) return;
    final result = await ApiService.delete('/admin/notices/${notice['id']}');
    if (result['success'] == true) {
      _message(_text(result['message'], 'Notice মুছে ফেলা হয়েছে।'));
      await _loadAll();
    } else {
      _message(_error(result), error: true);
    }
  }

  Future<void> _showAdminForm([Map<String, dynamic>? admin]) async {
    final name = TextEditingController(text: _text(admin?['name'], ''));
    final email = TextEditingController(text: _text(admin?['email'], ''));
    final phone = TextEditingController(text: _text(admin?['phone'], ''));
    final password = TextEditingController();
    final confirm = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(admin == null ? 'নতুন Admin তৈরি' : 'Admin সম্পাদনা'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'নাম')),
                const SizedBox(height: 10),
                TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'ইমেইল')),
                const SizedBox(height: 10),
                TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'ফোন')),
                const SizedBox(height: 10),
                TextField(controller: password, obscureText: true, decoration: InputDecoration(labelText: admin == null ? 'Password (কমপক্ষে ১২ অক্ষর)' : 'নতুন Password (ঐচ্ছিক)')),
                const SizedBox(height: 10),
                TextField(controller: confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm Password')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('সংরক্ষণ')),
        ],
      ),
    );
    if (saved != true) {
      name.dispose(); email.dispose(); phone.dispose(); password.dispose(); confirm.dispose();
      return;
    }
    final body = <String, dynamic>{
      'name': name.text.trim(),
      'email': email.text.trim(),
      'phone': phone.text.trim(),
    };
    if (password.text.isNotEmpty) {
      body['password'] = password.text;
      body['password_confirmation'] = confirm.text;
    } else if (admin == null) {
      _message('নতুন Admin-এর জন্য Password প্রয়োজন।', error: true);
      name.dispose(); email.dispose(); phone.dispose(); password.dispose(); confirm.dispose();
      return;
    }
    final result = admin == null
        ? await ApiService.post('/admin/administrators', body: body)
        : await ApiService.put('/admin/administrators/${admin['id']}', body: body);
    name.dispose(); email.dispose(); phone.dispose(); password.dispose(); confirm.dispose();
    if (result['success'] == true) {
      _message(_text(result['message'], 'Admin তথ্য সংরক্ষণ হয়েছে।'));
      await _loadAll();
    } else {
      _message(_error(result), error: true);
    }
  }

  Future<void> _deactivateAdmin(Map<String, dynamic> admin) async {
    final ok = await _confirm('Admin নিষ্ক্রিয় করবেন?', '${_text(admin['name'])}-এর অ্যাকাউন্ট নিষ্ক্রিয় হবে।', confirmText: 'নিষ্ক্রিয় করুন', danger: true);
    if (!ok) return;
    final result = await ApiService.delete('/admin/administrators/${admin['id']}');
    if (result['success'] == true) {
      _message(_text(result['message'], 'Admin নিষ্ক্রিয় হয়েছে।'));
      await _loadAll();
    } else {
      _message(_error(result), error: true);
    }
  }

  Widget _detail(String label, dynamic value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 118, child: Text(label, style: const TextStyle(color: _muted, fontSize: 13))),
            Expanded(child: Text(_text(value), style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );

  Widget _empty(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 10),
              Text(text, style: const TextStyle(color: _muted)),
            ],
          ),
        ),
      );

  Widget _sectionTitle(String title, String subtitle) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _dark)),
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: _muted)),
          ],
        ),
      );

  Widget _statCard(String title, dynamic value, IconData icon, Color color) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEDEEF2))),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_text(value, '0'), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: _dark)),
                  Text(title, style: const TextStyle(fontSize: 11, color: _muted)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _dashboardTab() {
    final users = _map(_dashboard['users']);
    final donors = _map(_dashboard['donors']);
    final blood = _map(_dashboard['blood_requests']);
    final tickets = _map(_dashboard['help_tickets']);
    final passwords = _map(_dashboard['password_assistance']);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _sectionTitle('Dashboard', 'RedLoop Pro-এর বর্তমান সারসংক্ষেপ'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.85,
            children: [
              _statCard('মোট ব্যবহারকারী', users['total'], Icons.people_alt_outlined, Colors.blue),
              _statCard('সক্রিয় ব্যবহারকারী', users['active'], Icons.verified_user_outlined, Colors.green),
              _statCard('Ban করা', users['banned'], Icons.block, _red),
              _statCard('মোট Donor', donors['total'], Icons.volunteer_activism, Colors.teal),
              _statCard('Available Donor', donors['available'], Icons.bloodtype, _red),
              _statCard('মোট Blood Request', blood['total'], Icons.bloodtype_outlined, Colors.deepOrange),
              _statCard('Open Request', blood['open'], Icons.pending_actions, Colors.orange),
              _statCard('Open Help Ticket', tickets['open'], Icons.support_agent, Colors.indigo),
              _statCard('Pending Password Help', passwords['pending'], Icons.lock_reset, Colors.purple),
            ],
          ),
        ),
      ],
    );
  }

  Widget _usersTab() {
    return Column(
      children: [
        _sectionTitle('ব্যবহারকারী ব্যবস্থাপনা', 'তথ্য সম্পাদনা এবং Ban / Unban'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TextField(
            controller: _userSearch,
            onSubmitted: (_) => _loadUsers(),
            decoration: InputDecoration(
              hintText: 'নাম, ইমেইল বা ফোন দিয়ে খুঁজুন',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(onPressed: _loadUsers, icon: const Icon(Icons.arrow_forward)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _userStatus,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('সব Status')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'banned', child: Text('Banned')),
                  ],
                  onChanged: (v) { _userStatus = v ?? ''; _loadUsers(); },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _userRole,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('সব Role')),
                    DropdownMenuItem(value: 'user', child: Text('User')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (v) { _userRole = v ?? ''; _loadUsers(); },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _users.isEmpty
              ? _empty('কোনো ব্যবহারকারী পাওয়া যায়নি।')
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (_, i) {
                    final user = _users[i];
                    final banned = user['account_status'] == 'banned';
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: banned ? Colors.grey : _red,
                                child: Text(_text(user['name'], '?').characters.first.toUpperCase(), style: const TextStyle(color: Colors.white)),
                              ),
                              title: Text(_text(user['name']), style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${_text(user['phone'])}\n${_text(user['email'])}\n${_text(user['role'])} · ${_text(user['account_status'])}'),
                              isThreeLine: true,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(onPressed: () => _editUser(user), icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit')),
                                TextButton.icon(
                                  onPressed: () => _toggleBan(user),
                                  icon: Icon(banned ? Icons.check_circle_outline : Icons.block, size: 18, color: banned ? Colors.green : _red),
                                  label: Text(banned ? 'Unban' : 'Ban', style: TextStyle(color: banned ? Colors.green : _red)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _bloodTab() {
    return Column(
      children: [
        _sectionTitle('রক্তের অনুরোধ', 'অনুরোধের বিস্তারিত ও Donor Responses দেখুন'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TextField(
            controller: _bloodSearch,
            onSubmitted: (_) => _loadBloodRequests(),
            decoration: InputDecoration(
              hintText: 'Hospital, District বা Area',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(onPressed: _loadBloodRequests, icon: const Icon(Icons.search)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _bloodGroup,
                  decoration: const InputDecoration(labelText: 'Blood Group'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('সব গ্রুপ')),
                    ..._bloodGroups.map((g) => DropdownMenuItem(value: g, child: Text(g))),
                  ],
                  onChanged: (v) { _bloodGroup = v ?? ''; _loadBloodRequests(); },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(labelText: 'Status filter'),
                  onSubmitted: (v) { _bloodStatus = v.trim(); _loadBloodRequests(); },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _bloodRequests.isEmpty
              ? _empty('কোনো Blood Request পাওয়া যায়নি।')
              : ListView.builder(
                  itemCount: _bloodRequests.length,
                  itemBuilder: (_, i) {
                    final item = _bloodRequests[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      child: ListTile(
                        onTap: () => _showBloodDetails(item),
                        leading: CircleAvatar(backgroundColor: _red, child: Text(_text(item['blood_group'], '?'), style: const TextStyle(color: Colors.white, fontSize: 12))),
                        title: Text(_text(item['hospital_name']), style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${_text(item['district'])} · ${_text(item['area'])}\n${_text(item['status'])} · ${_text(item['requester'] is Map ? item['requester']['name'] : null)}'),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _supportList({required bool password}) {
    final items = password ? _passwordRequests : _tickets;
    return Column(
      children: [
        _sectionTitle(
          password ? 'Password Assistance' : 'Help Tickets',
          password ? 'ব্যবহারকারীর পাসওয়ার্ড সহায়তার অনুরোধ' : 'ব্যবহারকারীর সহায়তা ও Admin Reply',
        ),
        Expanded(
          child: items.isEmpty
              ? _empty(password ? 'কোনো Password Assistance নেই।' : 'কোনো Help Ticket নেই।')
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
                    final user = _map(item['user']);
                    final status = _text(item['status']);
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      child: ListTile(
                        onTap: () => _editSupportRequest(item, password: password),
                        leading: CircleAvatar(
                          backgroundColor: status == 'pending' || status == 'open' ? Colors.orange : Colors.blue,
                          child: Icon(password ? Icons.lock_reset : Icons.support_agent, color: Colors.white),
                        ),
                        title: Text(_text(item['subject'], password ? 'Password assistance' : 'Help Ticket'), maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${_text(user['name'])} · ${_text(user['phone'])}\nStatus: $status'),
                        isThreeLine: true,
                        trailing: const Icon(Icons.edit_outlined),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _ratingsTab() {
    if (_ratings.isEmpty) return _empty('এখনো কোনো Rating নেই।');
    return ListView(
      children: [
        _sectionTitle('Ratings', 'শুধু প্রয়োজন হলে অনুপযুক্ত Rating মুছুন'),
        ..._ratings.map((rating) {
          final reviewer = _map(rating['reviewer']);
          final reviewee = _map(rating['reviewee']);
          final stars = _int(rating['stars']);
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: stars <= 2 ? _red : Colors.amber,
                child: Text('$stars★', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              title: Text('${_text(reviewer['name'])} → ${_text(reviewee['name'])}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${_text(rating['comment'], 'কোনো মন্তব্য নেই')}\n${_text(rating['created_at'])}'),
              isThreeLine: true,
              trailing: IconButton(
                tooltip: 'Delete rating',
                onPressed: () => _deleteRating(rating),
                icon: const Icon(Icons.delete_outline, color: _red),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _noticesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Expanded(child: Text('Notice Management', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _dark))),
              FilledButton.icon(onPressed: () => _editNotice(), icon: const Icon(Icons.add), label: const Text('নতুন')),
            ],
          ),
        ),
        Expanded(
          child: _notices.isEmpty
              ? _empty('এখনো কোনো Notice তৈরি হয়নি।')
              : ListView.builder(
                  itemCount: _notices.length,
                  itemBuilder: (_, i) {
                    final notice = _notices[i];
                    final active = notice['is_active'] == true || notice['is_active'] == 1;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      child: ListTile(
                        onTap: () => _editNotice(notice),
                        title: Text(_text(notice['title']), style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${_text(notice['message'])}\n${active ? 'প্রকাশিত' : 'প্রকাশিত নয়'}'),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') _editNotice(notice);
                            if (v == 'delete') _deleteNotice(notice);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _settingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Support Settings', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _dark)),
        const SizedBox(height: 6),
        const Text('Forgot Password স্ক্রিনে এই যোগাযোগের তথ্য দেখানো হবে।', style: TextStyle(color: _muted)),
        const SizedBox(height: 18),
        TextField(
          controller: _whatsApp,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Support WhatsApp Number', prefixIcon: Icon(Icons.chat_outlined), hintText: '8801XXXXXXXXX'),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton(
            onPressed: _saving ? null : () => _saveSetting('support_whatsapp', _whatsApp.text.trim()),
            child: const Text('WhatsApp সংরক্ষণ'),
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _supportEmail,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Support Email', prefixIcon: Icon(Icons.email_outlined), hintText: 'support@example.com'),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _saving ? null : () => _saveSetting('support_email', _supportEmail.text.trim()),
            child: const Text('Email সংরক্ষণ'),
          ),
        ),
        const Divider(height: 32),
        const Text('Terms & Conditions', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _dark)),
        const SizedBox(height: 6),
        const Text(
          'অ্যাপের Terms স্ক্রিনে এই Version ও Content দেখানো হবে। পরিবর্তনের অনুমতি শুধু Super Admin-এর আছে।',
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _termsVersion,
          decoration: const InputDecoration(
            labelText: 'Terms Version',
            hintText: 'যেমন: 1.0',
            prefixIcon: Icon(Icons.verified_outlined),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton(
            onPressed: _saving ? null : () {
              final version = _termsVersion.text.trim();
              if (version.isEmpty) {
                _message('Terms Version লিখুন।', error: true);
                return;
              }
              _saveSetting('terms_version', version);
            },
            child: const Text('Version সংরক্ষণ'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _termsContent,
          minLines: 8,
          maxLines: 16,
          maxLength: 50000,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            labelText: 'Terms & Conditions Content',
            alignLabelWithHint: true,
            hintText: 'এখানে সম্পূর্ণ Terms & Conditions লিখুন',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _saving ? null : () {
              final content = _termsContent.text.trim();
              if (content.isEmpty) {
                _message('Terms & Conditions Content লিখুন।', error: true);
                return;
              }
              _saveSetting('terms_content', content);
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Terms Content সংরক্ষণ'),
          ),
        ),
        const SizedBox(height: 20),
        const Divider(),
        const Text('Settings পরিবর্তনের অনুমতি শুধু Super Admin-এর আছে।', style: TextStyle(color: _muted, fontSize: 12)),
      ],
    );
  }

  Widget _adminsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Expanded(child: Text('Admin Management', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _dark))),
              FilledButton.icon(onPressed: () => _showAdminForm(), icon: const Icon(Icons.person_add_alt_1), label: const Text('নতুন Admin')),
            ],
          ),
        ),
        Expanded(
          child: _admins.isEmpty
              ? _empty('কোনো Admin পাওয়া যায়নি।')
              : ListView.builder(
                  itemCount: _admins.length,
                  itemBuilder: (_, i) {
                    final admin = _admins[i];
                    final active = admin['account_status'] == 'active';
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      child: ListTile(
                        title: Text(_text(admin['name']), style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${_text(admin['email'])}\n${_text(admin['phone'])} · ${_text(admin['account_status'])}'),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') _showAdminForm(admin);
                            if (v == 'deactivate') _deactivateAdmin(admin);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            if (active) const PopupMenuItem(value: 'deactivate', child: Text('Deactivate')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  List<({String title, IconData icon})> get _tabs => [
        (title: 'Dashboard', icon: Icons.dashboard_outlined),
        (title: 'Users', icon: Icons.people_outline),
        (title: 'Blood', icon: Icons.bloodtype_outlined),
        (title: 'Tickets', icon: Icons.support_agent),
        (title: 'Password', icon: Icons.lock_reset),
        (title: 'Ratings', icon: Icons.star_outline),
        (title: 'Notices', icon: Icons.campaign_outlined),
        if (_isSuperAdmin) (title: 'Settings', icon: Icons.settings_outlined),
        if (_isSuperAdmin) (title: 'Admins', icon: Icons.admin_panel_settings_outlined),
      ];

  Widget _tabContent() {
    switch (_tabs[_tab].title) {
      case 'Dashboard': return _dashboardTab();
      case 'Users': return _usersTab();
      case 'Blood': return _bloodTab();
      case 'Tickets': return _supportList(password: false);
      case 'Password': return _supportList(password: true);
      case 'Ratings': return _ratingsTab();
      case 'Notices': return _noticesTab();
      case 'Settings': return _settingsTab();
      case 'Admins': return _adminsTab();
      default: return _dashboardTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    if (_tab >= tabs.length) _tab = 0;
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: Text(_isSuperAdmin ? 'Super Admin Panel' : 'Admin Panel', style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: _red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _loadAll, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 48, color: _red),
                        const SizedBox(height: 12),
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton.icon(onPressed: _loadAll, icon: const Icon(Icons.refresh), label: const Text('আবার চেষ্টা করুন')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Container(
                      color: Colors.white,
                      height: 62,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        scrollDirection: Axis.horizontal,
                        itemCount: tabs.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 7),
                        itemBuilder: (_, i) {
                          final selected = i == _tab;
                          return ChoiceChip(
                            selected: selected,
                            onSelected: (_) => setState(() => _tab = i),
                            avatar: Icon(tabs[i].icon, size: 17, color: selected ? Colors.white : _muted),
                            label: Text(tabs[i].title),
                            selectedColor: _red,
                            labelStyle: TextStyle(color: selected ? Colors.white : _dark, fontWeight: FontWeight.w600),
                            backgroundColor: _background,
                            side: BorderSide.none,
                            showCheckmark: false,
                          );
                        },
                      ),
                    ),
                    Expanded(child: _tabContent()),
                  ],
                ),
    );
  }
}
