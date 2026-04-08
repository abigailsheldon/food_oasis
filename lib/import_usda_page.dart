import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ImportUSDAPage extends StatefulWidget {
  const ImportUSDAPage({super.key});

  @override
  State<ImportUSDAPage> createState() => _ImportUSDAPageState();
}

class _ImportUSDAPageState extends State<ImportUSDAPage> {
  final _apiKeyController = TextEditingController();
  final _stateController = TextEditingController(text: 'ga');
  
  bool isRunning = false;
  List<String> logs = [];
  int imported = 0;
  int skipped = 0;
  int failed = 0;

  // Which directories to import
  bool importFarmersMarket = true;
  bool importFoodHub = true;
  bool importOnFarmMarket = true;

  final Map<String, String> endpoints = {
    'Farmers Market': 'https://www.usdalocalfoodportal.com/api/farmersmarket/',
    'Food Hub': 'https://www.usdalocalfoodportal.com/api/foodhub/',
    'On-Farm Market': 'https://www.usdalocalfoodportal.com/api/onfarmmarket/',
  };

  Future<void> _importData() async {
    if (_apiKeyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your API key')),
      );
      return;
    }

    setState(() {
      isRunning = true;
      logs = [];
      imported = 0;
      skipped = 0;
      failed = 0;
    });

    final apiKey = _apiKeyController.text.trim();
    final state = _stateController.text.trim().toLowerCase();

    // Determine which directories to fetch
    List<String> directoriesToFetch = [];
    if (importFarmersMarket) directoriesToFetch.add('Farmers Market');
    if (importFoodHub) directoriesToFetch.add('Food Hub');
    if (importOnFarmMarket) directoriesToFetch.add('On-Farm Market');

    for (final directory in directoriesToFetch) {
      await _fetchAndImportDirectory(directory, apiKey, state);
    }

    _addLog('');
    _addLog('===== COMPLETE =====');
    _addLog('Imported: $imported');
    _addLog('Skipped: $skipped');
    _addLog('Failed: $failed');

    setState(() => isRunning = false);
  }

  Future<void> _fetchAndImportDirectory(String directory, String apiKey, String state) async {
    _addLog('');
    _addLog('📂 Fetching $directory...');

    final url = '${endpoints[directory]}?apikey=$apiKey&state=$state';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'FoodOasis/1.0',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _addLog('Found ${data.length} listings in $directory');

        for (final item in data) {
          await _importBusiness(item, directory);
        }
      } else {
        _addLog('❌ Error fetching $directory: ${response.statusCode}');
        _addLog('Response: ${response.body}');
        failed++;
      }
    } catch (e) {
      _addLog('❌ Error: $e');
      failed++;
    }
  }

  Future<void> _importBusiness(Map<String, dynamic> item, String directory) async {
    final name = item['listing_name'] ?? item['listing_desc'] ?? 'Unknown';
    
    // Build address from available fields
    final street = item['location_street'] ?? '';
    final city = item['location_city'] ?? '';
    final state = item['location_state'] ?? '';
    final zip = item['location_zipcode'] ?? '';
    final address = '$street, $city, $state $zip'.trim();

    // Get coordinates if available
    final lat = _parseDouble(item['location_y']);
    final lng = _parseDouble(item['location_x']);

    // Check if business already exists (by name and state)
    final existing = await FirebaseFirestore.instance
        .collection('businesses')
        .where('name', isEqualTo: name)
        .where('source', isEqualTo: 'USDA')
        .get();

    if (existing.docs.isNotEmpty) {
      _addLog('⏭️ $name - already exists, skipping');
      skipped++;
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('businesses').add({
        'name': name,
        'address': address,
        'description': item['listing_desc'] ?? 'Local food vendor from USDA directory',
        'latitude': lat,
        'longitude': lng,
        'website': item['media_website'] ?? '',
        'phone': item['contact_phone'] ?? '',
        'email': item['contact_email'] ?? '',
        'directory': directory,
        'source': 'USDA',
        'acceptingReservations': false,
        'hours': _parseHours(item),
        'createdAt': FieldValue.serverTimestamp(),
        'ownerUid': null, // No owner - imported data
      });

      _addLog('✅ $name');
      imported++;
    } catch (e) {
      _addLog('❌ $name - error: $e');
      failed++;
    }
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Map<String, dynamic> _parseHours(Map<String, dynamic> item) {
    // Try to parse schedule fields if available
    final schedule = item['brief_desc'] ?? '';
    
    // Return default hours structure
    return {
      'Monday': {'isOpen': true, 'open': '9:0', 'close': '17:0'},
      'Tuesday': {'isOpen': true, 'open': '9:0', 'close': '17:0'},
      'Wednesday': {'isOpen': true, 'open': '9:0', 'close': '17:0'},
      'Thursday': {'isOpen': true, 'open': '9:0', 'close': '17:0'},
      'Friday': {'isOpen': true, 'open': '9:0', 'close': '17:0'},
      'Saturday': {'isOpen': true, 'open': '9:0', 'close': '17:0'},
      'Sunday': {'isOpen': false, 'open': null, 'close': null},
      'notes': schedule,
    };
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
        title: const Text('Import USDA Data'),
        backgroundColor: Colors.blue.shade50,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Import Food Vendors from USDA',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'This will fetch farmers markets, food hubs, and on-farm markets from the USDA Local Food Directory.',
            ),
            const SizedBox(height: 20),

            // API Key input
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'USDA API Key',
                border: OutlineInputBorder(),
                hintText: 'Enter your API key',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),

            // State input
            TextField(
              controller: _stateController,
              decoration: const InputDecoration(
                labelText: 'State (abbreviation)',
                border: OutlineInputBorder(),
                hintText: 'e.g., ga, ny, ca',
              ),
              maxLength: 2,
            ),
            const SizedBox(height: 12),

            // Directory checkboxes
            const Text('Directories to import:', style: TextStyle(fontWeight: FontWeight.bold)),
            CheckboxListTile(
              title: const Text('Farmers Markets'),
              value: importFarmersMarket,
              onChanged: (v) => setState(() => importFarmersMarket = v ?? true),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
            CheckboxListTile(
              title: const Text('Food Hubs'),
              value: importFoodHub,
              onChanged: (v) => setState(() => importFoodHub = v ?? true),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
            CheckboxListTile(
              title: const Text('On-Farm Markets'),
              value: importOnFarmMarket,
              onChanged: (v) => setState(() => importOnFarmMarket = v ?? true),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),

            const SizedBox(height: 16),

            // Import button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isRunning ? null : _importData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
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
                          Text('Importing...'),
                        ],
                      )
                    : const Text('Import Data'),
              ),
            ),

            const SizedBox(height: 20),

            // Logs
            if (logs.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Log:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    'Imported: $imported | Skipped: $skipped | Failed: $failed',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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

  @override
  void dispose() {
    _apiKeyController.dispose();
    _stateController.dispose();
    super.dispose();
  }
}