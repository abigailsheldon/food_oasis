import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A bottom sheet widget for selecting pickup date and time
/// based on a business's operating hours.
class PickupTimeSelector extends StatefulWidget {
  final String businessId;
  final Function(DateTime selectedDateTime) onTimeSelected;

  const PickupTimeSelector({
    super.key,
    required this.businessId,
    required this.onTimeSelected,
  });

  @override
  State<PickupTimeSelector> createState() => _PickupTimeSelectorState();

  /// Show the pickup time selector as a bottom sheet
  static Future<DateTime?> show({
    required BuildContext context,
    required String businessId,
  }) async {
    DateTime? selectedTime;
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PickupTimeSelector(
        businessId: businessId,
        onTimeSelected: (time) {
          selectedTime = time;
          Navigator.pop(context);
        },
      ),
    );
    
    return selectedTime;
  }
}

class _PickupTimeSelectorState extends State<PickupTimeSelector> {
  Map<String, dynamic>? businessHours;
  String? businessName;
  bool isLoading = true;
  bool hasHours = false; // Track if business has hours set
  
  // Selected date (today or tomorrow, etc.)
  DateTime selectedDate = DateTime.now();
  TimeOfDay? selectedTime;
  
  // Available dates (next 7 days)
  List<DateTime> availableDates = [];
  
  // Time slots for selected date
  List<TimeOfDay> availableTimeSlots = [];

  @override
  void initState() {
    super.initState();
    _generateAvailableDates();
    _loadBusinessHours();
  }

  void _generateAvailableDates() {
    final now = DateTime.now();
    availableDates = List.generate(7, (i) => DateTime(
      now.year,
      now.month,
      now.day + i,
    ));
  }

  Future<void> _loadBusinessHours() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final hours = data['hours'] as Map<String, dynamic>?;
        
        setState(() {
          businessHours = hours;
          businessName = data['name'] ?? 'Business';
          hasHours = hours != null && hours.isNotEmpty;
          isLoading = false;
        });
        
        _generateTimeSlotsForDate(selectedDate);
      } else {
        // Business doesn't exist - use defaults
        setState(() {
          hasHours = false;
          businessName = 'Business';
          isLoading = false;
        });
        _generateTimeSlotsForDate(selectedDate);
      }
    } catch (e) {
      debugPrint('Error loading business hours: $e');
      setState(() {
        hasHours = false;
        isLoading = false;
      });
      _generateTimeSlotsForDate(selectedDate);
    }
  }

  String _getDayName(DateTime date) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
  }

  void _generateTimeSlotsForDate(DateTime date) {
    TimeOfDay openTime;
    TimeOfDay closeTime;
    
    if (hasHours && businessHours != null) {
      // Use business hours
      final dayName = _getDayName(date);
      final dayHours = businessHours![dayName] as Map<String, dynamic>?;

      if (dayHours == null || dayHours['isOpen'] == false) {
        setState(() => availableTimeSlots = []);
        return;
      }

      openTime = _parseTime(dayHours['open']) ?? const TimeOfDay(hour: 8, minute: 0);
      closeTime = _parseTime(dayHours['close']) ?? const TimeOfDay(hour: 18, minute: 0);
    } else {
      // DEFAULT: 8 AM - 6 PM for all days if no hours set
      openTime = const TimeOfDay(hour: 8, minute: 0);
      closeTime = const TimeOfDay(hour: 18, minute: 0);
    }

    final slots = <TimeOfDay>[];
    final now = DateTime.now();
    final isToday = date.year == now.year && 
                    date.month == now.month && 
                    date.day == now.day;

    // Generate 30-minute slots
    int currentMinutes = openTime.hour * 60 + openTime.minute;
    final endMinutes = closeTime.hour * 60 + closeTime.minute;

    while (currentMinutes < endMinutes - 15) {
      final slotTime = TimeOfDay(
        hour: currentMinutes ~/ 60,
        minute: currentMinutes % 60,
      );
      
      // If today, only show future times (at least 30 min from now)
      if (isToday) {
        final slotDateTime = DateTime(
          date.year, date.month, date.day,
          slotTime.hour, slotTime.minute,
        );
        if (slotDateTime.isAfter(now.add(const Duration(minutes: 30)))) {
          slots.add(slotTime);
        }
      } else {
        slots.add(slotTime);
      }
      
      currentMinutes += 30;
    }

    setState(() {
      availableTimeSlots = slots;
      selectedTime = null;
    });
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'Today';
    if (dateOnly == tomorrow) return 'Tomorrow';
    
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  bool _isDateOpen(DateTime date) {
    // If no hours set, assume all days are open
    if (!hasHours || businessHours == null) return true;
    
    final dayName = _getDayName(date);
    final dayHours = businessHours![dayName] as Map<String, dynamic>?;
    return dayHours != null && dayHours['isOpen'] == true;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.schedule, color: Colors.green.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Pickup Time',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (businessName != null)
                        Text(
                          businessName!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            )
          else ...[
            // Date selector
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Select Date',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      if (!hasHours) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Flexible hours',
                            style: TextStyle(fontSize: 10, color: Colors.blue.shade700),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 70,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: availableDates.length,
                      itemBuilder: (context, index) {
                        final date = availableDates[index];
                        final isSelected = selectedDate.year == date.year &&
                            selectedDate.month == date.month &&
                            selectedDate.day == date.day;
                        final isOpen = _isDateOpen(date);

                        return GestureDetector(
                          onTap: isOpen ? () {
                            setState(() => selectedDate = date);
                            _generateTimeSlotsForDate(date);
                          } : null,
                          child: Container(
                            width: 70,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.green
                                  : isOpen
                                      ? Colors.green.shade50
                                      : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.green
                                    : isOpen
                                        ? Colors.green.shade200
                                        : Colors.grey.shade300,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _getDayName(date).substring(0, 3),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected
                                        ? Colors.white
                                        : isOpen
                                            ? Colors.green.shade700
                                            : Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : isOpen
                                            ? Colors.black
                                            : Colors.grey,
                                  ),
                                ),
                                if (!isOpen)
                                  Text(
                                    'Closed',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Time slots
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Time',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (availableTimeSlots.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy, color: Colors.grey.shade500),
                          const SizedBox(width: 8),
                          Text(
                            'No available times for this date',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: availableTimeSlots.map((time) {
                            final isSelected = selectedTime == time;
                            return GestureDetector(
                              onTap: () => setState(() => selectedTime = time),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.green
                                      : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.green
                                        : Colors.green.shade200,
                                  ),
                                ),
                                child: Text(
                                  _formatTime(time),
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.green.shade700,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Confirm button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: selectedTime != null
                      ? () {
                          final pickupDateTime = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            selectedTime!.hour,
                            selectedTime!.minute,
                          );
                          widget.onTimeSelected(pickupDateTime);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    selectedTime != null
                        ? 'Confirm: ${_formatDate(selectedDate)} at ${_formatTime(selectedTime!)}'
                        : 'Select a Time',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            // Bottom padding for safe area
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ],
      ),
    );
  }
}