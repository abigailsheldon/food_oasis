import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'business_detail_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'cart_page.dart';
import 'favorites_page.dart';
import 'app_bottom_nav.dart';


class NavigatePage extends StatefulWidget {
  const NavigatePage({super.key});

  @override
  State<NavigatePage> createState() => _NavigatePageState();
}

class _NavigatePageState extends State<NavigatePage> {
  late GoogleMapController _mapController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Default center: Atlanta, GA
  static const LatLng _atlantaCenter = LatLng(33.7490, -84.3880);

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _allBusinesses = [];

  Set<Marker> _markers = {};
  Map<String, dynamic>? _selectedBusiness;

  @override
  void initState() {
    super.initState();
    _loadBusinessMarkers();
  }

  Future<void> _loadBusinessMarkers() async {
    final snapshot = await _firestore.collection('businesses').get();

    final Set<Marker> markers = {};
    final List<Map<String, dynamic>> businesses = [];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      data['businessId'] = doc.id;

      // Store all businesses for search
      businesses.add(data);

      // Check if business has coordinates
      final lat = data['latitude'] as double?;
      final lng = data['longitude'] as double?;

      if (lat != null && lng != null) {
        markers.add(
          Marker(
            markerId: MarkerId(doc.id),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(
              title: data['name'] ?? 'Unknown Business',
              snippet: 'Tap for details',
              onTap: () {
                _showBusinessDetails(data);
              },
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
            onTap: () {
              setState(() {
                _selectedBusiness = data;
              });
            },
          ),
        );
      }
    }

    setState(() {
      _markers = markers;
      _allBusinesses = businesses;
    });
  }


  void _showBusinessDetails(Map<String, dynamic> business) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BusinessDetailPage(seller: business),
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  List<Map<String, dynamic>> get _filteredBusinesses {
    if (_searchQuery.isEmpty) return [];
    return _allBusinesses.where((b) {
      final name = (b['name'] ?? '').toString().toLowerCase();
      final address = (b['address'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) ||
          address.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _goToBusiness(Map<String, dynamic> business) {
    final lat = business['latitude'] as double?;
    final lng = business['longitude'] as double?;

    if (lat != null && lng != null) {
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15),
      );
      setState(() {
        _selectedBusiness = business;
        _searchQuery = '';
        _searchController.clear();
      });
    }
  }

  Future<void> _openInGoogleMaps(Map<String, dynamic> business) async {
    final lat = business['latitude'];
    final lng = business['longitude'];
    final name = Uri.encodeComponent(business['name'] ?? 'Destination');

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No coordinates available for navigation')),
      );
      return;
    }

    // Try Google Maps app first, then fall back to browser
    final googleMapsUrl = Uri.parse(
      'google.navigation:q=$lat,$lng&mode=d',
    );
    final webUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=$name',
    );

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl);
    } else if (await canLaunchUrl(webUrl)) {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigate'),
        backgroundColor: Colors.green.shade50,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FavoritesPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CartPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBusinessMarkers,
            tooltip: 'Refresh markers',
          ),
        ],
      ),
      body: Stack(
        children: [


          // Google Map
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: _atlantaCenter,
              zoom: 12.0,
            ),
            markers: _markers,
            myLocationEnabled: false, // Set to true if you add location permission
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            mapToolbarEnabled: true,
          ),

          // Search bar
          Positioned(
            top: 10,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search markets & vendors...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                
                // Search results dropdown
                if (_filteredBusinesses.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredBusinesses.length,
                      itemBuilder: (context, index) {
                        final business = _filteredBusinesses[index];
                        final hasCoords = business['latitude'] != null;
                        
                        return ListTile(
                          leading: Icon(
                            Icons.storefront,
                            color: hasCoords ? Colors.green : Colors.grey,
                          ),
                          title: Text(
                            business['name'] ?? 'Unknown',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            business['address'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          trailing: hasCoords
                              ? const Icon(Icons.arrow_forward_ios, size: 16)
                              : const Text('No map', style: TextStyle(fontSize: 10)),
                          onTap: hasCoords ? () => _goToBusiness(business) : null,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          // Bottom card showing selected business
          if (_selectedBusiness != null)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _selectedBusiness!['name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _selectedBusiness = null;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedBusiness!['address'] ?? 'No address',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _showBusinessDetails(_selectedBusiness!);
                              },
                              icon: const Icon(Icons.info_outline, size: 18),
                              label: const Text('Details'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _openInGoogleMaps(_selectedBusiness!);
                              },
                              icon: const Icon(Icons.directions, size: 18),
                              label: const Text('Navigate'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Show message if no markers
          if (_markers.isEmpty)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_off,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No businesses on map yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Businesses need latitude and longitude to appear here',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      //bottomNavigationBar: const AppBottomNavBar(currentIndex: -1),
    );
  }
}