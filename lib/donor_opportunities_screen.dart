
import 'package:flutter/material.dart';

import 'api_helper.dart';

class DonorOpportunitiesScreen extends StatefulWidget {
  const DonorOpportunitiesScreen({super.key});

  @override
  State<DonorOpportunitiesScreen> createState() =>
      _DonorOpportunitiesScreenState();
}

class _DonorOpportunitiesScreenState
    extends State<DonorOpportunitiesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _requests = [];
  final Set<String> _processing = {};

  static const Color _primary = Color(0xFFDC3545);
  static const Color _background = Color(0xFFF7F8FA);

  @override
  void initState() {
    super.initState();
    _loadOpportunities();
  }

  Future<void> _loadOpportunities() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final result = await ApiService.get('/donor-opportunities');

      if (!mounted) return;

      if (result['success'] == true) {
        final data = result['requests'];

        setState(() {
          _requests = data is List
              ? data
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
              : [];
          _loading = false;
        });
      } else {
        setState(() {
          _error = result['message']?.toString() ??
              'অনুরোধগুলো লোড করা যায়নি।';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'সার্ভারের সঙ্গে সংযোগ করা যাচ্ছে না।';
        _loading = false;
      });
    }
  }

  Future<void> _respond(
    Map<String, dynamic> request,
    String response,
  ) async {
    final id = request['id']?.toString();

    if (id == null || id.isEmpty || _processing.contains(id)) {
      return;
    }

    final isAccept = response == 'accepted';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(isAccept ? 'অনুরোধ গ্রহণ করবেন?' : 'প্রত্যাখ্যান করবেন?'),
        content: Text(
          isAccept
              ? 'আপনি এই রক্তের অনুরোধটি গ্রহণ করতে যাচ্ছেন।'
              : 'আপনি কি নিশ্চিতভাবে এই অনুরোধটি প্রত্যাখ্যান করতে চান?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('না'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isAccept ? const Color(0xFF168C78) : _primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(isAccept ? 'হ্যাঁ, গ্রহণ করুন' : 'প্রত্যাখ্যান'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _processing.add(id));

    try {
      final result = await ApiService.post(
        '/blood-requests/$id/respond',
        body: {'response': response},
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAccept
                  ? 'অনুরোধটি গ্রহণ করা হয়েছে।'
                  : 'অনুরোধটি প্রত্যাখ্যান করা হয়েছে।',
            ),
            backgroundColor: const Color(0xFF168C78),
          ),
        );

        await _loadOpportunities();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message']?.toString() ?? 'কাজটি সম্পন্ন করা যায়নি।',
            ),
            backgroundColor: _primary,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('সার্ভারের সঙ্গে যোগাযোগ করা যায়নি।'),
          backgroundColor: _primary,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processing.remove(id));
      }
    }
  }

  String _value(Map<String, dynamic> data, List<String> keys,
      {String fallback = 'উল্লেখ নেই'}) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return fallback;
  }

  String _formatDate(String value) {
    if (value == 'উল্লেখ নেই') return value;

    try {
      final date = DateTime.parse(value).toLocal();
      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';

      return '${date.day}/${date.month}/${date.year} • $hour:$minute $period';
    } catch (_) {
      return value;
    }
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: Colors.blueGrey.shade500),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF263238),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> request) {
    final id = request['id']?.toString() ?? '';
    final busy = _processing.contains(id);

    final bloodGroup = _value(
      request,
      ['blood_group', 'bloodGroup'],
      fallback: 'N/A',
    );

    final units = _value(
      request,
      ['units', 'bags', 'blood_units'],
      fallback: '১',
    );

    final district = _value(request, ['district']);
    final area = _value(request, ['area', 'address']);
    final hospital = _value(
      request,
      ['hospital_name', 'hospital'],
    );

    final neededAt = _formatDate(
      _value(
        request,
        ['needed_at', 'required_at', 'date'],
      ),
    );

    final condition = _value(
      request,
      ['patient_condition', 'condition'],
    );

    final urgency = _value(
      request,
      ['urgency', 'priority'],
      fallback: 'সাধারণ',
    );

    final notes = _value(
      request,
      ['notes', 'description'],
      fallback: '',
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9ECEF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEEF0),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: Text(
                      bloodGroup,
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'রক্তের প্রয়োজন',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$units ব্যাগ রক্ত প্রয়োজন',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    urgency,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFB76E00),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 5),
            child: Column(
              children: [
                _infoRow(
                  Icons.local_hospital_outlined,
                  'হাসপাতাল',
                  hospital,
                ),
                _infoRow(
                  Icons.location_on_outlined,
                  'জেলা ও এলাকা',
                  '$district, $area',
                ),
                _infoRow(
                  Icons.calendar_month_outlined,
                  'রক্ত প্রয়োজন',
                  neededAt,
                ),
                _infoRow(
                  Icons.health_and_safety_outlined,
                  'রোগীর অবস্থা',
                  condition,
                ),
                if (notes.isNotEmpty)
                  _infoRow(
                    Icons.notes_outlined,
                    'অতিরিক্ত তথ্য',
                    notes,
                  ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 2, 16, 14),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F6F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 17,
                  color: Color(0xFF168C78),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'অনুরোধ গ্রহণ করার পর প্রয়োজনীয় যোগাযোগের তথ্য পাওয়া যাবে।',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF42645D),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => _respond(request, 'rejected'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primary,
                      side: const BorderSide(color: _primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: const Text('প্রত্যাখ্যান'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: busy
                        ? null
                        : () => _respond(request, 'accepted'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF168C78),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'রক্ত দিতে আগ্রহী',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 100,
              width: 100,
              decoration: const BoxDecoration(
                color: Color(0xFFFFEEF0),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.volunteer_activism_outlined,
                size: 48,
                color: _primary,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'এখন কোনো রক্তের অনুরোধ নেই',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'আপনার রক্তের গ্রুপের নতুন অনুরোধ এলে এখানে দেখতে পাবেন।',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _loadOpportunities,
              icon: const Icon(Icons.refresh),
              label: const Text('আবার চেষ্টা করুন'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF263238),
        elevation: 0,
        title: const Text(
          'রক্তদানের সুযোগ',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadOpportunities,
            icon: const Icon(Icons.refresh),
            tooltip: 'রিফ্রেশ',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: _primary,
        onRefresh: _loadOpportunities,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: _primary),
              )
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.55,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(25),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.cloud_off_outlined,
                                  size: 48,
                                  color: _primary,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 15),
                                ElevatedButton(
                                  onPressed: _loadOpportunities,
                                  child: const Text('আবার চেষ্টা করুন'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : _requests.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.65,
                            child: _emptyState(),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _requests.length,
                        itemBuilder: (context, index) {
                          return _requestCard(_requests[index]);
                        },
                      ),
      ),
    );
  }
}
