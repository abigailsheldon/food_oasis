/* File to add lat/long values to pre-existing businesses in Firestore*/
// Used for debugging & troubleshooting Firestore integration

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';

class GeocodeBusinessesPage extends StatefulWidget {
  const GeocodeBusinessesPage({super.key});

  @override
  State<GeocodeBusinessesPage> createState() => _GeocodeBusinessesPageState();
}

class _GeocodeBusinessesPageState extends State<GeocodeBusinessesPage> {
  bool isRunning = false;
  List<String> logs = [];
  int updated = 0;
  int skipped = 0;
  int failed = 0;

  Future<void> _geocodeAllBusinesses() async {
    setState(() {
      isRunning = true;
      logs = [];
      updated = 0;
      skipped = 0;
      failed = 0;
    });

    final snapshot = await FirebaseFirestore.instance.collection('businesses').get();

    _addLog('Found ${snapshot.docs.length} businesses');

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final name = data['name'] ?? 'Unknown';
      final address = data['address'] as String?;

      // Skip if already has coordinates
      if (data['latitude'] != null && data['longitude'] != null) {
        _addLog('⏭️ $name - already has coordinates, skipping');
        skipped++;
        continue;
      }

      // Skip if no address
      if (address == null || address.isEmpty) {
        _addLog('⚠️ $name - no address, skipping');
        failed++;
        continue;
      }

      // Geocode the address
      try {
        _addLog('$name - geocoding "$address"...');
        
        List<Location> locations = await locationFromAddress(address);
        
        if (locations.isNotEmpty) {
          final lat = locations.first.latitude;
          final lng = locations.first.longitude;

          await doc.reference.update({
            'latitude': lat,
            'longitude': lng,
          });

          _addLog('$name - updated ($lat, $lng)');
          updated++;
        } else {
          _addLog('$name - no results found');
          failed++;
        }
      } catch (e) {
        _addLog('$name - error: $e');
        failed++;
      }

      // Small delay to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 500));
    }

    _addLog('');
    _addLog('===== DONE =====');
    _addLog('Updated: $updated');
    _addLog('Skipped: $skipped');
    _addLog('Failed: $failed');

    setState(() => isRunning = false);
  }

  void _addLog(String message) {
    setState(() {
      logs.add(message);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geocode Businesses'),
        backgroundColor: Colors.orange.shade50,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Coordinates to Existing Businesses',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'This will find all businesses without latitude/longitude and geocode their addresses.',
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isRunning ? null : _geocodeAllBusinesses,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: isRunning
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Running...'),
                        ],
                      )
                    : const Text('Run Geocoding'),
              ),
            ),

            const SizedBox(height: 20),

            if (logs.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Log:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Updated: $updated | Skipped: $skipped | Failed: $failed',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      return Text(
                        logs[index],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
