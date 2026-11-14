
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
  bool _responding = false;
  String? _error;
  String _message = '';
  List<Map<String, dynamic>> _requests = [];

  static const Color _primary = Color(0xFFD92344);
  static const Color _background = Color(0xFFF7F8FC);

  @override
  void initState() {
    super.initState();
    _loadOpportunities();
  }

  Future<void> _loadOpportunities() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response =
          await ApiService.get('/donor-opportunities');

      if (!mounted) return;

      if (response['success'] != true) {
        throw Exception(
          response['message'] ?? 'তথ্য লোড করা যায়নি।',
        );
      }

      final dynamic data = response['requests'];

      setState(() {
        _requests = data is List
            ? data
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : [];

        _message = response['message']?.toString() ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _respond(
    Map<String, dynamic> request,
    String responseType,
  ) async {
    if (_responding) return;

    final int? requestId =
        int.tryParse(request['id']?.toString() ?? '');

    if (requestId == null) return;

    final bool accepted = responseType == 'accepted';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          accepted ? 'রক্তদানে সম্মতি' : 'অনুরোধ প্রত্যাখ্যান',
        ),
        content: Text(
          accepted
              ? 'আপনি কি এই রোগীকে রক্ত দিতে সম্মত? সম্মতি দেওয়ার পর প্রয়োজনীয় যোগাযোগের তথ্য পাওয়া যাবে।'
              : 'আপনি কি এই রক্তদানের অনুরোধটি প্রত্যাখ্যান করতে চান?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('না'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  accepted ? _primary : Colors.grey.shade700,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('নিশ্চিত করুন'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _responding = true);

    try {
      final result = await ApiService.post(
        '/blood-requests/$requestId/respond',
        body: {'response': responseType},
      );

      if (!mounted) return;

      if (result['success'] != true) {
        throw Exception(
          result['message'] ?? 'আপনার উত্তর জমা দেওয়া যায়নি।',
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accepted
                ? 'আপনার রক্তদানের সম্মতি জমা হয়েছে।'
                : 'অনুরোধটি প্রত্যাখ্যান করা হয়েছে।',
          ),
          backgroundColor: accepted
              ? Colors.green.shade700
              : Colors.blueGrey,
        ),
      );

      await _loadOpportunities();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _responding = false);
      }
    }
  }

  String _formatDate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return 'সময় নির্ধারিত নয়';
    }

    try {
      final date = DateTime.parse(value.toString()).toLocal();
      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final period = date.hour >= 12 ? 'PM' : 'AM';

      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year} • $hour:'
          '${date.minute.toString().padLeft(2, '0')} $period';
    } catch (_) {
      return value.toString();
    }
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.volunteer_activism_rounded,
                size: 48,
                color: _primary,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'এখন কোনো রক্তের অনুরোধ নেই',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              _message.isNotEmpty
                  ? _message
                  : 'আপনার রক্তের গ্রুপের সঙ্গে মিলে যাওয়া নতুন অনুরোধ এলে এখানে দেখতে পাবেন।',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: _loadOpportunities,
              icon: const Icon(Icons.refresh),
              label: const Text('আবার দেখুন'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> request) {
    final String bloodGroup =
        request['blood_group']?.toString() ?? '--';

    final String hospital =
        request['hospital_name']?.toString() ?? 'হাসপাতালের নাম নেই';

    final String district =
        request['district']?.toString() ?? '';

    final String area =
        request['area']?.toString() ?? '';

    final String condition =
        request['patient_condition']?.toString() ?? '';

    final String location = [area, district]
        .where((item) => item.trim().isNotEmpty)
        .join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      bloodGroup,
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
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
                        'রক্ত প্রয়োজন',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hospital,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1E8),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    '${request['bags'] ?? 1} ব্যাগ',
                    style: const TextStyle(
                      color: Color(0xFFB65A20),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 17),
            Divider(color: Colors.grey.shade200),
            const SizedBox(height: 8),
            _infoRow(
              Icons.location_on_outlined,
              location.isEmpty ? 'ঠিকানা উল্লেখ নেই' : location,
            ),
            const SizedBox(height: 10),
            _infoRow(
              Icons.calendar_month_outlined,
              _formatDate(request['needed_at']),
            ),
            if (condition.isNotEmpty) ...[
              const SizedBox(height: 10),
              _infoRow(Icons.info_outline, condition),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _responding
                        ? null
                        : () => _respond(request, 'rejected'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('এড়িয়ে যান'),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _responding
                        ? null
                        : () => _respond(request, 'accepted'),
                    icon: const Icon(
                      Icons.favorite_rounded,
                      size: 18,
                    ),
                    label: const Text('রক্ত দিতে চাই'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _primary),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'রক্তের অনুরোধ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 19,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadOpportunities,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'রিফ্রেশ',
          ),
          const SizedBox(width: 5),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: _primary),
              )
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(25),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            color: _primary,
                            size: 48,
                          ),
                          const SizedBox(height: 15),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: _loadOpportunities,
                            icon: const Icon(Icons.refresh),
                            label: const Text('আবার চেষ্টা করুন'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _requests.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                        color: _primary,
                        onRefresh: _loadOpportunities,
                        child: ListView(
                          padding: const EdgeInsets.all(17),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFD92344),
                                    Color(0xFFAB1735),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(17),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.volunteer_activism_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  const SizedBox(width: 13),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'আপনার রক্তে বাঁচতে পারে জীবন',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_requests.length}টি মিল পাওয়া অনুরোধ',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            ..._requests.map(_requestCard),
                          ],
                        ),
                      ),
      ),
    );
  }
}
