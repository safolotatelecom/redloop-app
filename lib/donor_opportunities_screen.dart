
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'api_helper.dart';
import 'screens/chat_screen.dart';

class DonorOpportunitiesScreen extends StatefulWidget {
  final String? requestId;

  const DonorOpportunitiesScreen({
    super.key,
    this.requestId,
  });

  @override
  State<DonorOpportunitiesScreen> createState() =>
      _DonorOpportunitiesScreenState();
}

class _DonorOpportunitiesScreenState
    extends State<DonorOpportunitiesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _allRequests = [];
  final Set<String> _processing = {};

  bool _targetNotFound = false;
  bool _showAllOpportunities = false;

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
        _targetNotFound = false;
      });
    }

    try {
      final result = await ApiService.get('/donor-opportunities');

      if (!mounted) return;

      if (result['success'] == true) {
        final data = result['requests'];

        final allRequests = data is List
            ? data
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : <Map<String, dynamic>>[];

        final targetId = widget.requestId?.trim();

        final filteredRequests = targetId == null || targetId.isEmpty
            ? allRequests
            : allRequests
                .where((item) => item['id']?.toString() == targetId)
                .toList();

        setState(() {
          _allRequests = allRequests;
          _requests = _showAllOpportunities
              ? allRequests
              : filteredRequests;
          _targetNotFound = targetId != null &&
              targetId.isNotEmpty &&
              filteredRequests.isEmpty &&
              !_showAllOpportunities;
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

  void _showAllRequests() {
    setState(() {
      _showAllOpportunities = true;
      _targetNotFound = false;
      _requests = _allRequests;
    });
  }

  Future<void> _showAcceptedDetails(
    Map<String, dynamic> details, {
    required String requestId,
    required String donorId,
  }) async {
    final name = _value(details, ['requester_name']);
    final phone = _value(details, ['requester_phone', 'phone']);
    final hospital = _value(details, ['hospital_name']);
    final district = _value(details, ['district']);
    final area = _value(details, ['area']);

    final neededAt = _formatDate(
      _value(details, ['needed_at']),
    );

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Color(0xFF168C78),
              size: 26,
            ),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'অনুরোধ গ্রহণ সফল',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'এখন অনুরোধকারীর যোগাযোগের তথ্য দেখতে পারবেন।',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 18),
              _infoRow(Icons.person_outline, 'অনুরোধকারীর নাম', name),
              _infoRow(Icons.phone_outlined, 'মোবাইল নম্বর', phone),
              _infoRow(
                Icons.local_hospital_outlined,
                'হাসপাতাল',
                hospital,
              ),
              _infoRow(Icons.location_on_outlined, 'জেলা', district),
              _infoRow(Icons.place_outlined, 'এলাকা', area),
              _infoRow(
                Icons.calendar_month_outlined,
                'রক্ত প্রয়োজন',
                neededAt,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('পরে'),
          ),
          if (donorId.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DonorLiveLocationPage(requestId: requestId),
                  ),
                );
              },
              icon: const Icon(Icons.location_on_outlined),
              label: const Text('Live Location'),
            ),
          if (donorId.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      requestId: requestId,
                      donorId: donorId,
                      otherName: name,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('চ্যাট শুরু করুন'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF168C78),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
        ],
      ),
    );
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
        title: Text(
          isAccept ? 'অনুরোধ গ্রহণ করবেন?' : 'প্রত্যাখ্যান করবেন?',
        ),
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
              backgroundColor:
                  isAccept ? const Color(0xFF168C78) : _primary,
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
        if (isAccept) {
          final details = result['accepted_details'];

          if (details is Map) {
            final userResult = await ApiService.getCurrentUser();
            final user = userResult['user'];
            final donorId = user is Map ? user['id']?.toString() : null;

            if (donorId != null && donorId.isNotEmpty) {
              await _showAcceptedDetails(
                Map<String, dynamic>.from(details),
                requestId: id,
                donorId: donorId,
              );
            } else {
              await _showAcceptedDetails(
                Map<String, dynamic>.from(details),
                requestId: id,
                donorId: '',
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'অনুরোধ গ্রহণ হয়েছে, কিন্তু যোগাযোগের তথ্য পাওয়া যায়নি।',
                ),
                backgroundColor: _primary,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('অনুরোধটি প্রত্যাখ্যান করা হয়েছে।'),
              backgroundColor: _primary,
            ),
          );
        }

        if (!mounted) return;
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

  String _value(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = 'উল্লেখ নেই',
  }) {
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

  Widget _infoRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: Colors.blueGrey.shade500,
          ),
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
                SelectableText(
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
    final hospital = _value(request, ['hospital_name', 'hospital']);

    final neededAt = _formatDate(
      _value(request, ['needed_at', 'required_at', 'date']),
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
            color: Colors.black.withOpacity(0.035),
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
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
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

  Widget _targetNotFoundState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.find_in_page_outlined,
              size: 62,
              color: _primary,
            ),
            const SizedBox(height: 18),
            const Text(
              'এই রক্তের অনুরোধটি আর উপলভ্য নেই',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              'অনুরোধটি ইতিমধ্যে পূরণ, বন্ধ অথবা আপনার জন্য আর প্রযোজ্য নয়।',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _showAllRequests,
              icon: const Icon(Icons.volunteer_activism_outlined),
              label: const Text('অন্য রক্তদানের সুযোগ দেখুন'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
              ),
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
        title: Text(
          widget.requestId != null && !_showAllOpportunities
              ? 'নির্দিষ্ট রক্তের অনুরোধ'
              : 'রক্তদানের সুযোগ',
          style: const TextStyle(
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
            ? ListView(
                physics: AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 500,
                    child: Center(
                      child: CircularProgressIndicator(color: _primary),
                    ),
                  ),
                ],
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
                : _targetNotFound
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.65,
                            child: _targetNotFoundState(),
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


class DonorLiveLocationPage extends StatefulWidget {
  final String requestId;

  const DonorLiveLocationPage({
    super.key,
    required this.requestId,
  });

  @override
  State<DonorLiveLocationPage> createState() =>
      _DonorLiveLocationPageState();
}

class _DonorLiveLocationPageState extends State<DonorLiveLocationPage> {
  static const Color _green = Color(0xFF168C78);
  Timer? _timer;
  bool _starting = false;
  bool _sharing = false;
  bool _stopping = false;
  String _status = 'লোকেশন শেয়ার শুরু করতে নিচের বাটনে চাপ দিন।';
  DateTime? _lastUpdated;

  String get _endpoint =>
      '/blood-requests/${widget.requestId}/live-location';

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _setStatus('ফোনের Location/GPS চালু করুন।');
      await Geolocator.openLocationSettings();
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      _setStatus('লোকেশন অনুমতি দেওয়া হয়নি।');
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      _setStatus('Settings থেকে RedLoop Pro-কে Location permission দিন।');
      await Geolocator.openAppSettings();
      return false;
    }

    return true;
  }

  void _setStatus(String value) {
    if (mounted) setState(() => _status = value);
  }

  Future<void> _sendCurrentLocation({bool showErrors = true}) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      final result = await ApiService.put(
        _endpoint,
        body: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy_meters': position.accuracy,
          'duration_minutes': 120,
        },
      );

      if (!mounted) return;

      if (result['success'] == true ||
          result['message']?.toString().toLowerCase().contains('success') == true) {
        setState(() {
          _lastUpdated = DateTime.now();
          _status = 'আপনার Live Location অনুরোধকারীর সঙ্গে শেয়ার হচ্ছে।';
          _sharing = true;
        });
      } else {
        final message = result['message']?.toString() ??
            'লোকেশন আপডেট করা যায়নি।';
        if (showErrors) _setStatus(message);
        if (result['status'] == 403) {
          _timer?.cancel();
          setState(() => _sharing = false);
        }
      }
    } catch (_) {
      if (showErrors) _setStatus('লোকেশন পাঠানো যায়নি। ইন্টারনেট ও GPS পরীক্ষা করুন।');
    }
  }

  Future<void> _startSharing() async {
    if (_starting || _sharing) return;
    setState(() => _starting = true);

    try {
      final allowed = await _ensureLocationPermission();
      if (!allowed || !mounted) return;

      await _sendCurrentLocation();
      if (!mounted || !_sharing) return;

      _timer?.cancel();
      _timer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _sendCurrentLocation(showErrors: false),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _stopSharing() async {
    if (_stopping) return;
    setState(() => _stopping = true);
    _timer?.cancel();

    try {
      final result = await ApiService.delete(_endpoint);
      if (!mounted) return;
      if (result['success'] == true || result['message'] != null) {
        setState(() {
          _sharing = false;
          _status = 'Live Location শেয়ার বন্ধ করা হয়েছে।';
        });
      } else {
        setState(() {
          _status = result['message']?.toString() ??
              'লোকেশন শেয়ার বন্ধ করা যায়নি।';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _status = 'সার্ভারের সঙ্গে যোগাযোগ করা যায়নি।');
      }
    } finally {
      if (mounted) setState(() => _stopping = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Donor Live Location'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF263238),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Icon(
              _sharing ? Icons.location_on : Icons.location_searching,
              size: 76,
              color: _sharing ? _green : Colors.blueGrey,
            ),
            const SizedBox(height: 20),
            Text(
              _sharing ? 'Live Location চালু আছে' : 'Live Location শেয়ার',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            if (_lastUpdated != null) ...[
              const SizedBox(height: 10),
              Text(
                'সর্বশেষ আপডেট: ${_lastUpdated!.toLocal().toString().substring(0, 19)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _starting || _sharing ? null : _startSharing,
              icon: _starting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.my_location),
              label: Text(_starting ? 'শুরু হচ্ছে...' : 'লোকেশন শেয়ার শুরু করুন'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: !_sharing || _stopping ? null : _stopSharing,
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text(_stopping ? 'বন্ধ হচ্ছে...' : 'লোকেশন শেয়ার বন্ধ করুন'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC3545),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const Spacer(),
            const Text(
              'এই স্ক্রিন খোলা থাকা অবস্থায় প্রতি ১৫ সেকেন্ডে লোকেশন আপডেট হবে। অ্যাপ বন্ধ বা স্ক্রিন থেকে বের হলে স্বয়ংক্রিয় আপডেট বন্ধ হবে। শেয়ার সর্বোচ্চ ১২০ মিনিট কার্যকর থাকবে।',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
