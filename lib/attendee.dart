import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/firebase_service.dart';

class AttendeeDashboard extends StatefulWidget {
  final String username;

  const AttendeeDashboard({Key? key, required this.username}) : super(key: key);

  @override
  State<AttendeeDashboard> createState() => _AttendeeDashboardState();
}

enum EventStatus { upcoming, ongoing, completed }

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

  factory AttendeeEvent.fromFirestore(Map<String, dynamic> data) {
    DateTime dateTime = data['date'] is DateTime
        ? data['date']
        : (data['date'] as Timestamp).toDate();

    EventStatus status;
    switch (data['status']) {
      case 'ongoing':
        status = EventStatus.ongoing;
        break;
      case 'completed':
        status = EventStatus.completed;
        break;
      default:
        status = EventStatus.upcoming;
    }

    return AttendeeEvent(
      id: data['id'],
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      date: DateFormat('MMM dd, yyyy').format(dateTime),
      time: data['time'] ?? '',
      location: data['location'] ?? '',
      category: data['category'] ?? '',
      capacity: data['capacity'] ?? 0,
      registered: data['registeredCount'] ?? 0,
      status: status,
    );
  }
}

class _AttendeeDashboardState extends State<AttendeeDashboard> {
  String? studentId;
  Set<String> registeredEventIds = {};
  Set<String> favoriteEventIds = {};
  Map<String, bool> attendanceStatus = {}; // Track attendance per event
  String searchQuery = '';
  String selectedCategory = 'All Categories';
  EventStatus? activeFilter;

  final List<String> categories = [
    'All Categories',
    'Technical',
    'Cultural',
    'Sports',
    'Career'
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _listenToAttendanceChanges();
  }

  Future<void> _loadUserData() async {
    final user = await FirebaseService.getCurrentUser();
    if (user != null) {
      setState(() {
        studentId = user['studentId'];
      });
    } else {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  // NEW: Listen to real-time attendance changes
  void _listenToAttendanceChanges() async {
    final user = await FirebaseService.getCurrentUser();
    if (user == null) return;

    final studentId = user['studentId'];

    FirebaseFirestore.instance
        .collectionGroup('registrations')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified ||
            change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            final wasAttended = attendanceStatus[change.doc.reference.parent.parent!.id] ?? false;
            final isNowAttended = data['attended'] == true;

            // Show popup when attendance is newly marked
            if (!wasAttended && isNowAttended) {
              _showAttendanceConfirmation(change.doc.reference.parent.parent!.id);
            }

            setState(() {
              attendanceStatus[change.doc.reference.parent.parent!.id] = isNowAttended;
            });
          }
        }
      }
    });
  }

  // NEW: Show attendance confirmation popup
  void _showAttendanceConfirmation(String eventId) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 32),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Attendance Registered!', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified, color: Colors.green, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your attendance has been successfully marked for this event!',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'You can now view your updated attendance record in your dashboard.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Great!'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRegister(String eventId) async {
    if (studentId == null) return;

    try {
      await FirebaseService.registerForEvent(eventId, studentId!);
      _showSnackBar('Successfully registered for the event!');
    } catch (e) {
      _showSnackBar(e.toString());
    }
  }

  Future<void> _handleUnregister(String eventId) async {
    if (studentId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unregister'),
        content: const Text('Are you sure you want to cancel your registration?'),
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
            child: const Text('Unregister'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseService.unregisterFromEvent(eventId, studentId!);
        _showSnackBar('Registration cancelled');
      } catch (e) {
        _showSnackBar(e.toString());
      }
    }
  }

  Future<void> _handleToggleFavorite(String eventId) async {
    if (studentId == null) return;

    try {
      if (favoriteEventIds.contains(eventId)) {
        await FirebaseService.removeFromFavorites(studentId!, eventId);
        _showSnackBar('Removed from favorites');
      } else {
        await FirebaseService.addToFavorites(studentId!, eventId);
        _showSnackBar('Added to favorites');
      }
    } catch (e) {
      _showSnackBar(e.toString());
    }
  }

  void _handleViewQR(AttendeeEvent event) {
    if (studentId == null) return;
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
    final qrData = FirebaseService.generateQRData(event.id, studentId!);

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
                  child: QrImageView(data: qrData, version: QrVersions.auto, size: 200),
                ),
                const SizedBox(height: 16),
                Text(event.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('${event.date} at ${event.time}', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                const Text('Valid for 5 minutes', style: TextStyle(color: Colors.red, fontSize: 12)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                  child: Text('Student ID: $studentId', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                ),
              ],
            ),
          ),
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
    final isFavorite = favoriteEventIds.contains(event.id);

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : null),
              title: Text(isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
              onTap: () {
                Navigator.pop(context);
                _handleToggleFavorite(event.id);
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
          ],
        ),
      ),
    );
  }

  void _showAlertsDialog() {
    if (studentId == null) return;

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
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: FirebaseService.getAlertsStream(studentId!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_off, size: 48, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No notifications', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      );
                    }

                    final alerts = snapshot.data!;

                    Future.delayed(Duration.zero, () {
                      FirebaseService.markAllAlertsAsRead(studentId!);
                    });

                    return ListView.separated(
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
                          title: Text(alert['eventTitle'] ?? 'Notification'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(alert['message'] ?? ''),
                              const SizedBox(height: 4),
                              Text(
                                _formatTimestamp(alert['timestamp']),
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        );
                      },
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

  // UPDATED: Show only favorite events that exist
  void _showFavoritesDialog(List<AttendeeEvent> allEvents) {
    // Filter to only show events that are both favorited AND exist in the event list
    final favoriteEvents = allEvents.where((e) => favoriteEventIds.contains(e.id)).toList();

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
                          _handleToggleFavorite(event.id);
                          Navigator.pop(context);
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

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return 'Just now';

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

  List<AttendeeEvent> _filterEvents(List<AttendeeEvent> events) {
    var filtered = events;

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

  // UPDATED: Calculate attended count properly
  Future<int> _getAttendedCount() async {
    if (studentId == null) return 0;

    int count = 0;
    for (var eventId in registeredEventIds) {
      if (attendanceStatus[eventId] == true) {
        count++;
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    if (studentId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirebaseService.getActiveEventsStream(),
        builder: (context, eventsSnapshot) {
          if (eventsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (eventsSnapshot.hasError) {
            return Center(child: Text('Error: ${eventsSnapshot.error}'));
          }

          final events = eventsSnapshot.data?.map((data) => AttendeeEvent.fromFirestore(data)).toList() ?? [];

          return StreamBuilder<List<String>>(
            stream: FirebaseService.getStudentRegistrationsStream(studentId!),
            builder: (context, regSnapshot) {
              if (regSnapshot.hasData) {
                registeredEventIds = regSnapshot.data!.toSet();
              }

              return StreamBuilder<List<String>>(
                stream: FirebaseService.getFavoritesStream(studentId!),
                builder: (context, favSnapshot) {
                  if (favSnapshot.hasData) {
                    favoriteEventIds = favSnapshot.data!.toSet();
                  }

                  final filteredEvents = _filterEvents(events);
                  final registeredCount = registeredEventIds.length;
                  final upcomingRegisteredCount = events.where((e) => e.status == EventStatus.upcoming && registeredEventIds.contains(e.id)).length;

                  return CustomScrollView(
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
                                        StreamBuilder<int>(
                                          stream: FirebaseService.getUnreadAlertsCountStream(studentId!),
                                          builder: (context, alertSnapshot) {
                                            final unreadCount = alertSnapshot.data ?? 0;

                                            return Stack(
                                              children: [
                                                IconButton(
                                                  onPressed: _showAlertsDialog,
                                                  icon: const Icon(Icons.notifications),
                                                  color: Colors.black,
                                                ),
                                                if (unreadCount > 0)
                                                  Positioned(
                                                    right: 8,
                                                    top: 8,
                                                    child: Container(
                                                      padding: const EdgeInsets.all(4),
                                                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                                      child: Text(
                                                        unreadCount.toString(),
                                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                        textAlign: TextAlign.center,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            );
                                          },
                                        ),
                                        IconButton(
                                          onPressed: _handleLogout,
                                          icon: const Icon(Icons.logout),
                                          color: Colors.red,
                                          tooltip: 'Logout',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                // UPDATED: Stats with real-time attendance count
                                FutureBuilder<int>(
                                  future: _getAttendedCount(),
                                  builder: (context, attendedSnapshot) {
                                    final attendedCount = attendedSnapshot.data ?? 0;

                                    return Row(
                                      children: [
                                        Expanded(child: _buildStatCard('Registered', registeredCount.toString(), Icons.calendar_today, Colors.blue)),
                                        const SizedBox(width: 12),
                                        Expanded(child: _buildStatCard('Upcoming', upcomingRegisteredCount.toString(), Icons.trending_up, Colors.green)),
                                        const SizedBox(width: 12),
                                        Expanded(child: _buildStatCard('Attended', attendedCount.toString(), Icons.check_circle, Colors.purple)),
                                      ],
                                    );
                                  },
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
                                  onTap: () => _showFavoritesDialog(events),
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
                  );
                },
              );
            },
          );
        },
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
              children: [
                Expanded(
                  child: Text(event.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 2),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _handleToggleFavorite(event.id),
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : Colors.grey,
                  ),
                  tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
                ),
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
            Row(
              children: [
                Expanded(
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
                if (isRegistered && event.status == EventStatus.upcoming) ...[
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _handleViewQR(event),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(12),
                    ),
                    child: const Icon(Icons.qr_code, size: 20),
                  ),
                ],
                const SizedBox(width: 8),
                IconButton(onPressed: () => _showEventOptions(event), icon: const Icon(Icons.more_vert, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}