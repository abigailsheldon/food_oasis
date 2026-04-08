import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:geocoding/geocoding.dart';
import '../main.dart';

class SellerOnboardingPage extends StatefulWidget {
  const SellerOnboardingPage({super.key});

  @override
  State<SellerOnboardingPage> createState() => _SellerOnboardingPageState();
}

class _SellerOnboardingPageState extends State<SellerOnboardingPage> {
  final _formKey = GlobalKey<FormState>();

  final _businessName = TextEditingController();
  final _address = TextEditingController();
  final _description = TextEditingController();

  bool acceptingReservations = true;
  bool isLoading = false;

  final List<String> days = const [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday",
  ];

  Map<String, bool> isOpen = {};
  Map<String, TimeOfDay?> openTime = {};
  Map<String, TimeOfDay?> closeTime = {};

  @override
  void initState() {
    super.initState();

    for (final d in days) {
      isOpen[d] = true;
      openTime[d] = const TimeOfDay(hour: 9, minute: 0);
      closeTime[d] = const TimeOfDay(hour: 18, minute: 0);
    }
  }

  // Geocode address to get latitude and longitude
  Future<Map<String, double>?> _geocodeAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return {
          'latitude': locations.first.latitude,
          'longitude': locations.first.longitude,
        };
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    // Geocode the address
    final coordinates = await _geocodeAddress(_address.text.trim());

    if (coordinates == null) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not find location for this address. Please check and try again.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;

    final hoursPayload = <String, dynamic>{};

    for (final day in days) {
      final open = isOpen[day] ?? true;

      hoursPayload[day] = {
        "isOpen": open,
        "open": open
            ? "${openTime[day]!.hour}:${openTime[day]!.minute}"
            : null,
        "close": open
            ? "${closeTime[day]!.hour}:${closeTime[day]!.minute}"
            : null,
      };
    }

    final businessRef =
        FirebaseFirestore.instance.collection('businesses').doc();

    await businessRef.set({
      "name": _businessName.text.trim(),
      "address": _address.text.trim(),
      "description": _description.text.trim(),
      "hours": hoursPayload,
      "acceptingReservations": acceptingReservations,
      "ownerUid": uid,
      "createdAt": FieldValue.serverTimestamp(),
      "latitude": coordinates['latitude'],
      "longitude": coordinates['longitude'],
    });

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      "businessId": businessRef.id,
      "role": "seller",
    });

    setState(() => isLoading = false);

    if (mounted) {
      // Clear navigation stack and restart at AuthWrapper to refresh user data
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Complete Business Setup")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _businessName,
                      decoration:
                          const InputDecoration(labelText: "Business Name"),
                      validator: (v) =>
                          v!.isEmpty ? "Required field" : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _address,
                      decoration:
                          const InputDecoration(labelText: "Address"),
                      validator: (v) =>
                          v!.isEmpty ? "Required field" : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _description,
                      decoration:
                          const InputDecoration(labelText: "Description"),
                      validator: (v) =>
                          v!.isEmpty ? "Required field" : null,
                    ),
                    const SizedBox(height: 20),

                    SwitchListTile(
                      title: const Text("Accepting Reservations"),
                      value: acceptingReservations,
                      onChanged: (v) =>
                          setState(() => acceptingReservations = v),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      "Business Hours",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 10),

                    ...days.map((day) {
                      return Row(
                        children: [
                          Checkbox(
                            value: isOpen[day],
                            onChanged: (v) =>
                                setState(() => isOpen[day] = v!),
                          ),
                          SizedBox(width: 90, child: Text(day)),

                          if (isOpen[day] == true) ...[
                            TextButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: openTime[day]!,
                                );
                                if (picked != null) {
                                  setState(() => openTime[day] = picked);
                                }
                              },
                              child: const Text("Open"),
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: closeTime[day]!,
                                );
                                if (picked != null) {
                                  setState(() => closeTime[day] = picked);
                                }
                              },
                              child: const Text("Close"),
                            ),
                          ]
                        ],
                      );
                    }),

                    const SizedBox(height: 30),

                    ElevatedButton(
                      onPressed: _submit,
                      child: const Text("Finish Setup"),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}