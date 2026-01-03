import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'services/firebase_service.dart';

class AttendeeDashboard extends StatefulWidget {
  final String username;

  const AttendeeDashboard({Key? key, required this.username}) : super(key: key);

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

class EventAlert {
  final String id;
  final String eventTitle;
  final String message;
  final DateTime timestamp;
  bool isRead;

  EventAlert({
    required this.id,
    required this.eventTitle,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });
}

class _AttendeeDashboardState extends State<AttendeeDashboard> {
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
  ];

  List<EventAlert> alerts = [
    EventAlert(
      id: '1',
      eventTitle: 'Tech Talk: AI Workshop',
      message: 'Event starts in 2 days! Don\'t forget to attend.',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      isRead: false,
    ),
    EventAlert(
      id: '2',
      eventTitle: 'Cultural Night 2026',
      message: 'New performers added to the lineup!',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      isRead: false,
    ),
    EventAlert(
      id: '3',
      eventTitle: 'System Notification',
      message: 'Your profile has been updated successfully.',
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      isRead: true,
    ),
  ];

  final List<String> categories = [
    'All Categories',
    'Technical',
    'Cultural',
    'Sports',
    'Career'
  ];

  Set<String> registeredEventIds = {};
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

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseService.logout();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        }
      } catch (e) {
        _showSnackBar('Logout failed: ${e.toString()}');
      }
    }
  }

  void _showQRDialog(AttendeeEvent event) {
    final registrationId = 'REG-${event.id}-${DateTime.now().millisecondsSinceEpoch}';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Event QR Code', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
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
                  child: QrImageView(data: registrationId, version: QrVersions.auto, size: 200),
                ),
                const SizedBox(height: 16),
                Text(event.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('${event.date} at ${event.time}', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                  child: Text('Registration ID: $registrationId', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAlertsDialog() {
    setState(() {
      for (var alert in alerts) {
        alert.isRead = true;
      }
    });

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Notifications', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: alerts.isEmpty
                    ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_off, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No notifications', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
                    : ListView.separated(
                  shrinkWrap: true,
                  itemCount: alerts.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final alert = alerts[index];
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.notifications, color: Colors.grey, size: 20),
                      ),
                      title: Text(alert.eventTitle),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(alert.message),
                          const SizedBox(height: 4),
                          Text(_formatTimestamp(alert.timestamp), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFavoritesDialog() {
    final favoriteEvents = mockEvents.where((e) => favoriteEventIds.contains(e.id)).toList();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Favorite Events', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: favoriteEvents.isEmpty
                    ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite_border, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No favorite events', style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 8),
                      Text('Add events to favorites to see them here', style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
                    ],
                  ),
                )
                    : ListView.separated(
                  shrinkWrap: true,
                  itemCount: favoriteEvents.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final event = favoriteEvents[index];
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.favorite, color: Colors.red, size: 20),
                      ),
                      title: Text(event.title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('${event.date} at ${event.time}'),
                          const SizedBox(height: 2),
                          Text(event.location, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            favoriteEventIds.remove(event.id);
                          });
                          Navigator.pop(context);
                          _showSnackBar('Removed from favorites');
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
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
      filtered = filtered.where((e) =>
      e.title.toLowerCase().contains(query) ||
          e.description.toLowerCase().contains(query) ||
          e.location.toLowerCase().contains(query)).toList();
    }

    return filtered;
  }

  int get registeredCount => registeredEventIds.length;
  int get upcomingRegisteredCount => mockEvents.where((e) => e.status == EventStatus.upcoming && registeredEventIds.contains(e.id)).length;
  int get completedAttendedCount => mockEvents.where((e) => e.status == EventStatus.completed && registeredEventIds.contains(e.id)).length;
  int get unreadAlertsCount => alerts.where((a) => !a.isRead).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.white,
            pinned: true,
            expandedHeight: 240,
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Welcome, ${widget.username}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                              const Text('Discover & Register Events', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            Stack(
                              children: [
                                IconButton(onPressed: _showAlertsDialog, icon: const Icon(Icons.notifications), color: Colors.black),
                                if (unreadAlertsCount > 0)
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                      child: Text(unreadAlertsCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                    ),
                                  ),
                              ],
                            ),
                            IconButton(onPressed: _handleLogout, icon: const Icon(Icons.logout), color: Colors.red, tooltip: 'Logout'),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('Registered', registeredCount.toString(), Icons.calendar_today, Colors.blue)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard('Upcoming', upcomingRegisteredCount.toString(), Icons.trending_up, Colors.green)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard('Attended', completedAttendedCount.toString(), Icons.check_circle, Colors.purple)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search events...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                    child: DropdownButton<String>(
                      value: selectedCategory,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: categories.map((String category) {
                        return DropdownMenuItem<String>(value: category, child: Text(category));
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedCategory = newValue!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (activeFilter == null)
                    InkWell(
                      onTap: _showFavoritesDialog,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade100)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.favorite, color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Text('Favorites', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                                  child: Text(favoriteEventIds.length.toString()),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
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
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
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
      labelStyle: TextStyle(color: isActive ? Colors.white : Colors.black),
    );
  }

  Widget _buildEventCard(AttendeeEvent event) {
    final isRegistered = registeredEventIds.contains(event.id);
    final registrationPercentage = (event.registered / event.capacity * 100).round();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(event.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 2),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: event.status == EventStatus.upcoming ? Colors.black : Colors.grey, borderRadius: BorderRadius.circular(12)),
                  child: Text(event.status == EventStatus.upcoming ? 'Upcoming' : 'Completed', style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(event.description, style: const TextStyle(color: Colors.grey), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(child: Text('${event.date} at ${event.time}', style: const TextStyle(color: Colors.grey, fontSize: 14), overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(child: Text(event.location, style: const TextStyle(color: Colors.grey, fontSize: 14), overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.people, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text('${event.registered} / ${event.capacity}', style: const TextStyle(color: Colors.grey, fontSize: 14)),
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
                    Text('$registrationPercentage%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: registrationPercentage / 100, backgroundColor: Colors.grey[200], valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue)),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.5,
                  child: ElevatedButton(
                    onPressed: isRegistered
                        ? (event.status == EventStatus.upcoming ? () => _handleUnregister(event.id) : null)
                        : (event.status == EventStatus.upcoming && event.registered < event.capacity ? () => _handleRegister(event.id) : null),
                    style: ElevatedButton.styleFrom(backgroundColor: isRegistered ? Colors.green : Colors.black, foregroundColor: Colors.white),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isRegistered ? Icons.check_circle : Icons.person_add, size: 18),
                        const SizedBox(width: 8),
                        Text(isRegistered ? 'Registered' : 'Register'),
                      ],
                    ),
                  ),
                ),
                IconButton(onPressed: () => _showEventOptions(event), icon: const Icon(Icons.more_vert, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(Icons.calendar_today, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No events found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Try adjusting your search or filters', style: TextStyle(color: Colors.grey)),
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