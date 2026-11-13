
import 'package:flutter/material.dart';

import 'api_helper.dart';
import 'services/location_service.dart';

const Color _red = Color(0xFFDC2638);
const Color _dark = Color(0xFF20232B);
const Color _muted = Color(0xFF777D89);

class DonorProfileScreen extends StatefulWidget {
  const DonorProfileScreen({super.key});

  @override
  State<DonorProfileScreen> createState() => _DonorProfileScreenState();
}

class _DonorProfileScreenState extends State<DonorProfileScreen> {
  final _districtController = TextEditingController();
  final _areaController = TextEditingController();

  final LocationService _locationService = LocationService();

  String _bloodGroup = 'O+';
  bool _available = false;
  bool _loading = true;
  bool _saving = false;
  bool _gettingLocation = false;

  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _districtController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Map<String, dynamic>? _extractProfile(Map<String, dynamic> result) {
    for (final key in ['profile', 'donor_profile', 'data']) {
      final value = result[key];

      if (value is Map<String, dynamic>) {
        if (value.containsKey('blood_group')) {
          return value;
        }

        for (final nestedKey in ['profile', 'donor_profile']) {
          final nested = value[nestedKey];

          if (nested is Map<String, dynamic>) {
            return nested;
          }
        }
      }
    }

    return null;
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);

    final result = await ApiService.get('/donor-profile');

    if (!mounted) return;

    if (result['success'] == true) {
      final profile = _extractProfile(result);

      if (profile != null) {
        final group = profile['blood_group']?.toString();

        if (group != null &&
            ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                .contains(group)) {
          _bloodGroup = group;
        }

        _districtController.text =
            profile['district']?.toString() ?? '';

        _areaController.text =
            profile['area']?.toString() ?? '';

        _available = profile['is_available'] == true ||
            profile['is_available'] == 1;

        _latitude = double.tryParse(
          profile['latitude']?.toString() ?? '',
        );

        _longitude = double.tryParse(
          profile['longitude']?.toString() ?? '',
        );
      }
    } else {
      _message(
        result['message']?.toString() ??
            'ডোনার প্রোফাইল লোড করা যায়নি।',
      );
    }

    setState(() => _loading = false);
  }

  Future<void> _getLocation() async {
    setState(() => _gettingLocation = true);

    try {
      final coordinates =
          await _locationService.getCoordinates();

      if (!mounted) return;

      setState(() {
        _latitude = coordinates['latitude'];
        _longitude = coordinates['longitude'];
      });

      _message('আপনার বর্তমান লোকেশন পাওয়া গেছে।');
    } catch (e) {
      _message(
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => _gettingLocation = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_districtController.text.trim().isEmpty ||
        _areaController.text.trim().isEmpty) {
      _message('জেলা ও এলাকার নাম লিখুন।');
      return;
    }

    setState(() => _saving = true);

    final result = await ApiService.put(
      '/donor-profile',
      body: {
        'blood_group': _bloodGroup,
        'district': _districtController.text.trim(),
        'area': _areaController.text.trim(),
        'is_available': _available,
        if (_latitude != null && _longitude != null) ...{
          'latitude': _latitude,
          'longitude': _longitude,
        },
      },
    );

    if (!mounted) return;

    setState(() => _saving = false);

    if (result['success'] == true) {
      _message('ডোনার প্রোফাইল সফলভাবে সংরক্ষিত হয়েছে।');
    } else {
      _message(
        result['message']?.toString() ??
            'প্রোফাইল সংরক্ষণ করা যায়নি।',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ডোনার প্রোফাইল',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadProfile,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _red),
            )
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(21),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFE52F43),
                          Color(0xFFB9182B),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.volunteer_activism,
                          color: Colors.white,
                          size: 35,
                        ),
                        SizedBox(height: 13),
                        Text(
                          'আপনার রক্ত, কারও জীবন',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 7),
                        Text(
                          'সঠিক তথ্য দিয়ে ডোনার প্রোফাইল সম্পূর্ণ করুন।',
                          style: TextStyle(
                            color: Colors.white70,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  const _SectionTitle('রক্তের তথ্য'),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _bloodGroup,
                    decoration: const InputDecoration(
                      labelText: 'রক্তের গ্রুপ',
                      prefixIcon: Icon(
                        Icons.bloodtype,
                        color: _red,
                      ),
                    ),
                    items: const [
                      'A+', 'A-', 'B+', 'B-',
                      'AB+', 'AB-', 'O+', 'O-',
                    ].map((group) {
                      return DropdownMenuItem(
                        value: group,
                        child: Text(group),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _bloodGroup = value);
                      }
                    },
                  ),
                  const SizedBox(height: 25),
                  const _SectionTitle('আপনার ঠিকানা'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _districtController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'জেলা',
                      prefixIcon: Icon(Icons.location_city),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _areaController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'এলাকা / থানা',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle('GPS লোকেশন'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: const Color(0xFFE9E9EF),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.my_location,
                              color: _red,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'বর্তমান অবস্থান',
                                style: TextStyle(
                                  color: _dark,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Icon(
                              _latitude != null
                                  ? Icons.check_circle
                                  : Icons.location_searching,
                              color: _latitude != null
                                  ? Colors.green
                                  : _muted,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _latitude != null && _longitude != null
                              ? 'লোকেশন সংরক্ষণের জন্য প্রস্তুত'
                              : 'এখনো GPS লোকেশন নেওয়া হয়নি।',
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed:
                              _gettingLocation ? null : _getLocation,
                          icon: _gettingLocation
                              ? const SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.my_location,
                                  color: _red,
                                ),
                          label: Text(
                            _gettingLocation
                                ? 'লোকেশন নেওয়া হচ্ছে...'
                                : 'বর্তমান লোকেশন নিন',
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'GPS লোকেশন ডোনার ম্যাচিংয়ে দূরত্ব নির্ণয়ে সাহায্য করবে।',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle('রক্তদানের প্রস্তুতি'),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    tileColor: Colors.white,
                    activeThumbColor: _red,
                    value: _available,
                    onChanged: (value) {
                      setState(() => _available = value);
                    },
                    title: const Text(
                      'আমি রক্ত দিতে আগ্রহী',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _dark,
                      ),
                    ),
                    subtitle: Text(
                      _available
                          ? 'আপনি ডোনার ম্যাচিংয়ে অন্তর্ভুক্ত থাকবেন।'
                          : 'আপনি আপাতত ডোনার ম্যাচিংয়ে থাকবেন না।',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  ElevatedButton(
                    onPressed: _saving ? null : _saveProfile,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('প্রোফাইল সংরক্ষণ করুন'),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w900,
        color: _dark,
      ),
    );
  }
}
