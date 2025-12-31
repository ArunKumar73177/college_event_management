import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

class AttendeeDashboard extends StatefulWidget {
  const AttendeeDashboard({Key? key}) : super(key: key);

  @override
  State<AttendeeDashboard> createState() => _AttendeeDashboardState();
}

enum EventStatus { upcoming, completed }

class AttendeeEvent {
  final String id;
  final String title;
  final String description;
  final String date;
  final String time;
  final String location;
  final String category;
  final int capacity;
  final int registered;
  final EventStatus status;

  AttendeeEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.time,
    required this.location,
    required this.category,
    required this.capacity,
    required this.registered,
    required this.status,
  });
}

class _AttendeeDashboardState extends State<AttendeeDashboard> {
  // Mock event data
  final List<AttendeeEvent> mockEvents = [
    AttendeeEvent(
      id: '1',
      title: 'Tech Talk: AI Workshop',
      description: 'Learn the fundamentals of AI and machine learning',
      date: 'Jan 15, 2026',
      time: '10:00',
      location: 'Auditorium Hall A',
      category: 'Technical',
      capacity: 200,
      registered: 145,
      status: EventStatus.upcoming,
    ),
    AttendeeEvent(
      id: '2',
      title: 'Annual Sports Day',
      description: 'Participate in various sports competitions',
      date: 'Jan 20, 2026',
      time: '09:00',
      location: 'Main Sports Ground',
      category: 'Sports',
      capacity: 500,
      registered: 320,
      status: EventStatus.upcoming,
    ),
    AttendeeEvent(
      id: '3',
      title: 'Cultural Night 2026',
      description: 'Evening of music, dance, and performances',
      date: 'Feb 5, 2026',
      time: '18:00',
      location: 'Open Air Theatre',
      category: 'Cultural',
      capacity: 300,
      registered: 267,
      status: EventStatus.upcoming,
    ),
    AttendeeEvent(
      id: '4',
      title: 'Hackathon 2026',
      description: '24-hour coding marathon with prizes',
      date: 'Feb 15, 2026',
      time: '09:00',
      location: 'Innovation Hub',
      category: 'Technical',
      capacity: 100,
      registered: 89,
      status: EventStatus.upcoming,
    ),
    AttendeeEvent(
      id: '5',
      title: 'Career Fair',
      description: 'Meet recruiters from top companies',
      date: 'Mar 10, 2026',
      time: '14:00',
      location: 'Conference Hall',
      category: 'Career',
      capacity: 150,
      registered: 98,
      status: EventStatus.upcoming,
    ),
    AttendeeEvent(
      id: '6',
      title: 'Web Development Workshop',
      description: 'Learn modern web development',
      date: 'Dec 10, 2025',
      time: '10:00',
      location: 'Computer Lab 2',
      category: 'Technical',
      capacity: 50,
      registered: 50,
      status: EventStatus.completed,
    ),
    AttendeeEvent(
      id: '7',
      title: 'Winter Fest 2025',
      description: 'Annual winter celebration',
      date: 'Dec 20, 2025',
      time: '16:00',
      location: 'Central Lawn',
      category: 'Cultural',
      capacity: 250,
      registered: 198,
      status: EventStatus.completed,
    ),
    AttendeeEvent(
      id: '8',
      title: 'Alumni Meet 2025',
      description: 'Network with successful alumni',
      date: 'Nov 15, 2025',
      time: '17:00',
      location: 'Grand Hall',
      category: 'Career',
      capacity: 100,
      registered: 87,
      status: EventStatus.completed,
    ),
  ];

  final List<String> categories = [
    'All Categories',
    'Technical',
    'Cultural',
    'Sports',
    'Career'
  ];

  Set<String> registeredEventIds = {'6', '7'};
  Set<String> favoriteEventIds = {};
  String searchQuery = '';
  String selectedCategory = 'All Categories';
  EventStatus? activeFilter;
  AttendeeEvent? selectedEventForQR;

  void _handleRegister(String eventId) {
    setState(() {
      registeredEventIds.add(eventId);
    });
    _showSnackBar('Successfully registered for the event!');
  }

  void _handleUnregister(String eventId) {
    setState(() {
      registeredEventIds.remove(eventId);
    });
    _showSnackBar('Registration cancelled');
  }

  void _handleToggleFavorite(String eventId) {
    setState(() {
      if (favoriteEventIds.contains(eventId)) {
        favoriteEventIds.remove(eventId);
        _showSnackBar('Removed from favorites');
      } else {
        favoriteEventIds.add(eventId);
        _showSnackBar('Added to favorites');
      }
    });
  }

  void _handleViewQR(AttendeeEvent event) {
    setState(() {
      selectedEventForQR = event;
    });
    _showQRDialog(event);
  }

  void _showQRDialog(AttendeeEvent event) {
    final registrationId = 'REG-${event.id}-${DateTime.now().millisecondsSinceEpoch}';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Event QR Code',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: QrImageView(
                  data: registrationId,
                  version: QrVersions.auto,
                  size: 200,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                event.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${event.date} at ${event.time}',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Registration ID: $registrationId',
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  List<AttendeeEvent> get filteredEvents {
    var filtered = mockEvents;

    if (activeFilter != null) {
      filtered = filtered.where((e) => e.status == activeFilter).toList();
    }

    if (selectedCategory != 'All Categories') {
      filtered = filtered.where((e) => e.category == selectedCategory).toList();
    }

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered
          .where((e) =>
      e.title.toLowerCase().contains(query) ||
          e.description.toLowerCase().contains(query) ||
          e.location.toLowerCase().contains(query))
          .toList();
    }

    return filtered;
  }

  int get registeredCount => registeredEventIds.length;
  int get upcomingRegisteredCount => mockEvents
      .where((e) => e.status == EventStatus.upcoming && registeredEventIds.contains(e.id))
      .length;
  int get completedAttendedCount => mockEvents
      .where((e) => e.status == EventStatus.completed && registeredEventIds.contains(e.id))
      .length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            backgroundColor: Colors.white,
            pinned: true,
            expandedHeight: 220,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Event Dashboard',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Discover & Register',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            _showSnackBar('Alerts feature');
                          },
                          icon: const Icon(Icons.notifications, size: 18),
                          label: const Text('Alerts'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Stats Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Registered',
                            registeredCount.toString(),
                            Icons.calendar_today,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Upcoming',
                            upcomingRegisteredCount.toString(),
                            Icons.trending_up,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Attended',
                            completedAttendedCount.toString(),
                            Icons.check_circle,
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search events...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Filter Buttons
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All', null),
                        const SizedBox(width: 8),
                        _buildFilterChip('Upcoming', EventStatus.upcoming),
                        const SizedBox(width: 8),
                        _buildFilterChip('Completed', EventStatus.completed),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButton<String>(
                      value: selectedCategory,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: categories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedCategory = newValue!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Favorites count
                  if (activeFilter == null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.favorite, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text('Favorites', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(favoriteEventIds.length.toString()),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Event List
                  filteredEvents.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredEvents.length,
                    itemBuilder: (context, index) {
                      return _buildEventCard(filteredEvents[index]);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, EventStatus? status) {
    final isActive = activeFilter == status;
    return FilterChip(
      label: Text(label),
      selected: isActive,
      onSelected: (selected) {
        setState(() {
          activeFilter = selected ? status : null;
        });
      },
      backgroundColor: Colors.white,
      selectedColor: Colors.black,
      labelStyle: TextStyle(
        color: isActive ? Colors.white : Colors.black,
      ),
    );
  }

  Widget _buildEventCard(AttendeeEvent event) {
    final isRegistered = registeredEventIds.contains(event.id);
    final isFavorite = favoriteEventIds.contains(event.id);
    final registrationPercentage = (event.registered / event.capacity * 100).round();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: event.status == EventStatus.upcoming
                        ? Colors.black
                        : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    event.status == EventStatus.upcoming ? 'Upcoming' : 'Completed',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(event.description, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text('${event.date} at ${event.time}',
                    style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(event.location, style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.people, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  '${event.registered} / ${event.capacity} attendees',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Registration', style: TextStyle(fontSize: 12)),
                    Text('$registrationPercentage%',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: registrationPercentage / 100,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isRegistered
                        ? (event.status == EventStatus.upcoming
                        ? () => _handleUnregister(event.id)
                        : null)
                        : (event.status == EventStatus.upcoming &&
                        event.registered < event.capacity
                        ? () => _handleRegister(event.id)
                        : null),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isRegistered ? Colors.green : Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isRegistered ? Icons.check_circle : Icons.person_add,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(isRegistered ? 'Registered' : 'Register'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _handleToggleFavorite(event.id),
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : Colors.grey,
                  ),
                ),
                if (isRegistered)
                  IconButton(
                    onPressed: () => _handleViewQR(event),
                    icon: const Icon(Icons.qr_code, color: Colors.grey),
                  ),
                IconButton(
                  onPressed: () => _showEventOptions(event),
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: const [
            Icon(Icons.calendar_today, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No events found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _showEventOptions(AttendeeEvent event) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Add to Calendar'),
              onTap: () {
                Navigator.pop(context);
                _showSnackBar('Event added to calendar');
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share Event'),
              onTap: () {
                Navigator.pop(context);
                _showSnackBar('Event link copied to clipboard');
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('View Details'),
              onTap: () {
                Navigator.pop(context);
                _showSnackBar('View event details');
              },
            ),
          ],
        ),
      ),
    );
  }
}