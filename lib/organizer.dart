import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'services/firebase_service.dart';

enum EventStatus { upcoming, ongoing, completed }

class Event {
  final String id;
  final String title;
  final DateTime startDate;
  final TimeOfDay startTime;
  final DateTime endDate;
  final TimeOfDay endTime;
  final String location;
  final String description;
  final String category;
  final int maxAttendees;
  int attendees;
  final EventStatus status;

  Event({
    required this.id,
    required this.title,
    required this.startDate,
    required this.startTime,
    required this.endDate,
    required this.endTime,
    required this.location,
    required this.description,
    required this.category,
    required this.maxAttendees,
    required this.attendees,
    required this.status,
  });

  factory Event.fromFirestore(Map<String, dynamic> data) {
    DateTime startDate = data['startDate'] is DateTime
        ? data['startDate']
        : (data['startDate'] as Timestamp).toDate();

    DateTime endDate = data['endDate'] is DateTime
        ? data['endDate']
        : (data['endDate'] as Timestamp).toDate();

    List<String> startTimeParts = data['startTime'].toString().split(':');
    TimeOfDay startTime = TimeOfDay(
      hour: int.parse(startTimeParts[0]),
      minute: int.parse(startTimeParts[1]),
    );

    List<String> endTimeParts = data['endTime'].toString().split(':');
    TimeOfDay endTime = TimeOfDay(
      hour: int.parse(endTimeParts[0]),
      minute: int.parse(endTimeParts[1]),
    );

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

    return Event(
      id: data['id'],
      title: data['title'] ?? '',
      startDate: startDate,
      startTime: startTime,
      endDate: endDate,
      endTime: endTime,
      location: data['location'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      maxAttendees: data['capacity'] ?? 0,
      attendees: data['registeredCount'] ?? 0,
      status: status,
    );
  }
}

enum DashboardView { list, create, edit, details, attendees, scanner }

class OrganizerDashboard extends StatefulWidget {
  const OrganizerDashboard({Key? key}) : super(key: key);

  @override
  State<OrganizerDashboard> createState() => _OrganizerDashboardState();
}

class _OrganizerDashboardState extends State<OrganizerDashboard> {
  String organizerName = "Loading...";
  String? studentId;
  bool isLoading = true;

  DashboardView currentView = DashboardView.list;
  Event? selectedEvent;
  String searchQuery = '';
  EventStatus? activeFilter;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await FirebaseService.getCurrentUser();
      if (user != null) {
        setState(() {
          organizerName = user['name'] ?? 'Organizer';
          studentId = user['studentId'];
          isLoading = false;
        });
      } else {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } catch (e) {
      setState(() {
        organizerName = 'Organizer';
        isLoading = false;
      });
    }
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
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseService.logout();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } catch (e) {
        _showSnackBar('Logout failed: ${e.toString()}');
      }
    }
  }

  Future<void> _createEvent(Event event) async {
    try {
      await FirebaseService.createEvent(
        title: event.title,
        description: event.description,
        startDate: event.startDate,
        startTime: '${event.startTime.hour}:${event.startTime.minute}',
        endDate: event.endDate,
        endTime: '${event.endTime.hour}:${event.endTime.minute}',
        location: event.location,
        category: event.category,
        capacity: event.maxAttendees,
      );
      setState(() {
        currentView = DashboardView.list;
      });
      _showSnackBar('Event created successfully!');
    } catch (e) {
      _showSnackBar('Failed to create event: $e');
    }
  }

  Future<void> _updateEvent(Event updatedEvent) async {
    try {
      await FirebaseService.updateEvent(
        updatedEvent.id,
        {
          'title': updatedEvent.title,
          'description': updatedEvent.description,
          'startDate': updatedEvent.startDate,
          'startTime': '${updatedEvent.startTime.hour}:${updatedEvent.startTime.minute}',
          'endDate': updatedEvent.endDate,
          'endTime': '${updatedEvent.endTime.hour}:${updatedEvent.endTime.minute}',
          'location': updatedEvent.location,
          'category': updatedEvent.category,
          'capacity': updatedEvent.maxAttendees,
          'status': updatedEvent.status.name,
        },
      );
      setState(() {
        currentView = DashboardView.list;
        selectedEvent = null;
      });
      _showSnackBar('Event updated successfully!');
    } catch (e) {
      _showSnackBar('Failed to update event: $e');
    }
  }

  Future<void> _deleteEvent(String id) async {
    try {
      await FirebaseService.deleteEvent(id);
      setState(() {
        currentView = DashboardView.list;
        selectedEvent = null;
      });
      _showSnackBar('Event deleted successfully!');
    } catch (e) {
      _showSnackBar('Failed to delete event: $e');
    }
  }

  Future<void> _sendAlertToAttendees(Event event) async {
    final messageController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Alert'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Send notification to all registered attendees for "${event.title}"?'),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
                hintText: 'Enter alert message...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (confirmed == true && messageController.text.isNotEmpty) {
      try {
        await FirebaseService.broadcastAlertToEvent(
          event.id,
          event.title,
          messageController.text,
        );
        _showSnackBar('Alert sent to all registered attendees!');
      } catch (e) {
        _showSnackBar('Failed to send alert: $e');
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  List<Event> _filterEvents(List<Event> events) {
    var filtered = events;

    if (activeFilter != null) {
      filtered = filtered.where((e) => e.status == activeFilter).toList();
    }

    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((e) =>
      e.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          e.location.toLowerCase().contains(searchQuery.toLowerCase()) ||
          e.category.toLowerCase().contains(searchQuery.toLowerCase())
      ).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: currentView != DashboardView.list
            ? Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () {
                setState(() {
                  currentView = DashboardView.list;
                  selectedEvent = null;
                });
              },
            ),
            Text(
                currentView == DashboardView.scanner ? 'Scan QR Code' :
                currentView == DashboardView.attendees ? 'Attendees' : 'Back',
                style: const TextStyle(color: Colors.black)
            ),
          ],
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome, $organizerName',
                style: const TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const Text('Organize & Manage Events',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
        actions: currentView == DashboardView.list
            ? [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.black),
            onPressed: () {
              setState(() {
                currentView = DashboardView.scanner;
              });
            },
            tooltip: 'Scan QR',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 8),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  currentView = DashboardView.create;
                });
              },
            ),
          ),
        ]
            : null,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (currentView) {
      case DashboardView.list:
        return _buildListView();
      case DashboardView.create:
        return EventFormWidget(onSubmit: _createEvent);
      case DashboardView.edit:
        return EventFormWidget(
          event: selectedEvent,
          onSubmit: _updateEvent,
        );
      case DashboardView.details:
        return EventDetailsWidget(
          event: selectedEvent!,
          onEdit: () {
            setState(() {
              currentView = DashboardView.edit;
            });
          },
          onDelete: () => _deleteEvent(selectedEvent!.id),
          onSendAlert: () => _sendAlertToAttendees(selectedEvent!),
          onViewAttendees: () {
            setState(() {
              currentView = DashboardView.attendees;
            });
          },
        );
      case DashboardView.attendees:
        return AttendeesListView(event: selectedEvent!);
      case DashboardView.scanner:
        return QRScannerView(
          onScanned: (result) {
            setState(() {
              currentView = DashboardView.list;
            });
          },
        );
    }
  }

  Widget _buildListView() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseService.getAllEventsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState();
        }

        final events = snapshot.data!.map((data) => Event.fromFirestore(data)).toList();
        final filteredEvents = _filterEvents(events);

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                StreamBuilder<Map<String, int>>(
                  stream: FirebaseService.getOrganizerStatsStream(),
                  builder: (context, statsSnapshot) {
                    final stats = statsSnapshot.data ?? {'total': 0, 'upcoming': 0, 'totalAttendees': 0};

                    return Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total',
                            stats['total'].toString(),
                            Icons.calendar_today,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Upcoming',
                            stats['upcoming'].toString(),
                            Icons.trending_up,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Attendees',
                            stats['totalAttendees'].toString(),
                            Icons.people,
                            Colors.purple,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

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

                Row(
                  children: [
                    _buildFilterChip('All', null),
                    const SizedBox(width: 8),
                    _buildFilterChip('Upcoming', EventStatus.upcoming),
                    const SizedBox(width: 8),
                    _buildFilterChip('Completed', EventStatus.completed),
                  ],
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
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
      selectedColor: Colors.blue[100],
    );
  }

  Widget _buildEventCard(Event event) {
    final attendancePercentage = event.maxAttendees > 0
        ? (event.attendees / event.maxAttendees * 100).round()
        : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            selectedEvent = event;
            currentView = DashboardView.details;
          });
        },
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
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {
                      _showEventOptions(event);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Chip(
                label: Text(event.status.name.toUpperCase()),
                backgroundColor: event.status == EventStatus.upcoming
                    ? Colors.blue[100]
                    : Colors.grey[300],
                labelStyle: TextStyle(
                  color: event.status == EventStatus.upcoming
                      ? Colors.blue
                      : Colors.grey[700],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Start: ${DateFormat('MMM dd, yyyy').format(event.startDate)} at ${event.startTime.format(context)}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.event, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'End: ${DateFormat('MMM dd, yyyy').format(event.endDate)} at ${event.endTime.format(context)}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(event.location, style: const TextStyle(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.people, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    '${event.attendees} / ${event.maxAttendees} attendees',
                    style: const TextStyle(color: Colors.grey),
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
                      Text('$attendancePercentage%',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: attendancePercentage / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const SizedBox(height: 48),
            const Text(
              'No events found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  currentView = DashboardView.create;
                });
              },
              child: const Text('Create First Event'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEventOptions(Event event) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('View Attendees'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  selectedEvent = event;
                  currentView = DashboardView.attendees;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  selectedEvent = event;
                  currentView = DashboardView.edit;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Send Alert'),
              onTap: () {
                Navigator.pop(context);
                _sendAlertToAttendees(event);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteEvent(event.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// QR Scanner View
class QRScannerView extends StatefulWidget {
  final Function(String) onScanned;

  const QRScannerView({Key? key, required this.onScanned}) : super(key: key);

  @override
  State<QRScannerView> createState() => _QRScannerViewState();
}

class _QRScannerViewState extends State<QRScannerView> {
  bool isProcessing = false;
  bool showManualInput = false;
  final TextEditingController _manualController = TextEditingController();

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _handleQRCode(String code) async {
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
    });

    try {
      final result = await FirebaseService.verifyQRAndMarkAttendance(code);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 32),
                SizedBox(width: 12),
                Text('Success!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Student: ${result['studentName']}'),
                Text('ID: ${result['studentId']}'),
                const SizedBox(height: 8),
                Text('Event: ${result['eventTitle']}'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '✓ Attendance marked successfully',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onScanned(code);
                },
                child: const Text('Done'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    isProcessing = false;
                  });
                },
                child: const Text('Scan Next'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red, size: 32),
                SizedBox(width: 12),
                Text('Error'),
              ],
            ),
            content: Text(e.toString()),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    isProcessing = false;
                  });
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _verifyManual() async {
    if (_manualController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter QR code')),
      );
      return;
    }

    await _handleQRCode(_manualController.text);
    _manualController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (!showManualInput)
            MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    _handleQRCode(barcode.rawValue!);
                    break;
                  }
                }
              },
            )
          else
            _buildManualInputView(),

          if (!showManualInput) _buildScanningOverlay(),

          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                icon: Icon(showManualInput ? Icons.qr_code_scanner : Icons.keyboard),
                label: Text(showManualInput ? 'Use Camera' : 'Enter Manually'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                onPressed: () {
                  setState(() {
                    showManualInput = !showManualInput;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningOverlay() {
    return Column(
      children: [
        Expanded(
          flex: 1,
          child: Container(color: Colors.black.withOpacity(0.5)),
        ),
        Expanded(
          flex: 2,
          child: Row(
            children: [
              Expanded(child: Container(color: Colors.black.withOpacity(0.5))),
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.green, width: 4),
                              left: BorderSide(color: Colors.green, width: 4),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.green, width: 4),
                              right: BorderSide(color: Colors.green, width: 4),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.green, width: 4),
                              left: BorderSide(color: Colors.green, width: 4),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.green, width: 4),
                              right: BorderSide(color: Colors.green, width: 4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(child: Container(color: Colors.black.withOpacity(0.5))),
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Position QR code within frame',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'QR codes are valid for 5 minutes only',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualInputView() {
    return Container(
      color: Colors.grey[50],
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.qr_code,
                  size: 100,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Verify Attendee',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter the QR code from attendee\'s device',
                style: TextStyle(color: Colors.grey, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _manualController,
                        enabled: !isProcessing,
                        decoration: const InputDecoration(
                          labelText: 'QR Code',
                          hintText: 'Paste or type QR code here',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.qr_code),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isProcessing ? null : _verifyManual,
                          icon: isProcessing
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                              : const Icon(Icons.verified_user),
                          label: Text(isProcessing ? 'Verifying...' : 'Verify Attendance'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Attendees List View
class AttendeesListView extends StatelessWidget {
  final Event event;

  const AttendeesListView({Key? key, required this.event}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseService.getEventAttendeesStream(event.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final attendees = snapshot.data ?? [];

        if (attendees.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No attendees yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
              ],
            ),
          );
        }

        final attendedCount = attendees.where((a) => a['attended'] == true).length;

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          'Registered',
                          attendees.length.toString(),
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoCard(
                          'Attended',
                          attendedCount.toString(),
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoCard(
                          'Pending',
                          (attendees.length - attendedCount).toString(),
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: attendees.length,
                itemBuilder: (context, index) {
                  final attendee = attendees[index];
                  final isAttended = attendee['attended'] == true;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isAttended ? Colors.green : Colors.grey,
                        child: Text(
                          attendee['name'].toString().substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        attendee['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('ID: ${attendee['studentId']}'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isAttended ? Colors.green.shade100 : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isAttended ? 'Attended' : 'Pending',
                          style: TextStyle(
                            color: isAttended ? Colors.green.shade900 : Colors.orange.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Event Form Widget
class EventFormWidget extends StatefulWidget {
  final Event? event;
  final Function(Event) onSubmit;

  const EventFormWidget({Key? key, this.event, required this.onSubmit})
      : super(key: key);

  @override
  State<EventFormWidget> createState() => _EventFormWidgetState();
}

class _EventFormWidgetState extends State<EventFormWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _descriptionController;
  late TextEditingController _categoryController;
  late TextEditingController _maxAttendeesController;
  late DateTime _selectedStartDate;
  late TimeOfDay _selectedStartTime;
  late DateTime _selectedEndDate;
  late TimeOfDay _selectedEndTime;
  late EventStatus _selectedStatus;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event?.title ?? '');
    _locationController = TextEditingController(text: widget.event?.location ?? '');
    _descriptionController = TextEditingController(text: widget.event?.description ?? '');
    _categoryController = TextEditingController(text: widget.event?.category ?? '');
    _maxAttendeesController = TextEditingController(
        text: widget.event?.maxAttendees.toString() ?? '');
    _selectedStartDate = widget.event?.startDate ?? DateTime.now();
    _selectedStartTime = widget.event?.startTime ?? TimeOfDay.now();
    _selectedEndDate = widget.event?.endDate ?? DateTime.now().add(const Duration(hours: 2));
    _selectedEndTime = widget.event?.endTime ?? TimeOfDay(hour: TimeOfDay.now().hour + 2, minute: TimeOfDay.now().minute);
    _selectedStatus = widget.event?.status ?? EventStatus.upcoming;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Event Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
              value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
              value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _maxAttendeesController,
              decoration: const InputDecoration(
                labelText: 'Max Attendees',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) =>
              value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedStartDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  setState(() {
                    _selectedStartDate = date;
                  });
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Start Date',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  DateFormat('MMM dd, yyyy').format(_selectedStartDate),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _selectedStartTime,
                );
                if (time != null) {
                  setState(() {
                    _selectedStartTime = time;
                  });
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Start Time',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.access_time),
                ),
                child: Text(
                  _selectedStartTime.format(context),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedEndDate.isBefore(_selectedStartDate)
                      ? _selectedStartDate
                      : _selectedEndDate,
                  firstDate: _selectedStartDate,
                  lastDate: DateTime(2030),
                );

                if (picked != null) {
                  setState(() {
                    _selectedEndDate = picked;
                  });
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'End Date',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  DateFormat('MMM dd, yyyy').format(_selectedEndDate),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _selectedEndTime,
                );
                if (time != null) {
                  setState(() {
                    _selectedEndTime = time;
                  });
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'End Time',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.access_time),
                ),
                child: Text(
                  _selectedEndTime.format(context),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitForm,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: Text(widget.event == null ? 'Create Event' : 'Update Event'),
            ),
          ],
        ),
      ),
    );
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      final event = Event(
        id: widget.event?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        startDate: _selectedStartDate,
        startTime: _selectedStartTime,
        endDate: _selectedEndDate,
        endTime: _selectedEndTime,
        location: _locationController.text,
        description: _descriptionController.text,
        category: _categoryController.text,
        maxAttendees: int.parse(_maxAttendeesController.text),
        attendees: widget.event?.attendees ?? 0,
        status: _selectedStatus,
      );
      widget.onSubmit(event);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _maxAttendeesController.dispose();
    super.dispose();
  }
}

// Event Details Widget
class EventDetailsWidget extends StatelessWidget {
  final Event event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSendAlert;
  final VoidCallback onViewAttendees;

  const EventDetailsWidget({
    Key? key,
    required this.event,
    required this.onEdit,
    required this.onDelete,
    required this.onSendAlert,
    required this.onViewAttendees,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final attendancePercentage = event.maxAttendees > 0
        ? (event.attendees / event.maxAttendees * 100).round()
        : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Chip(
            label: Text(event.status.name.toUpperCase()),
            backgroundColor: event.status == EventStatus.upcoming
                ? Colors.blue[100]
                : Colors.grey[300],
          ),
          const SizedBox(height: 24),
          _buildDetailRow(Icons.calendar_today,
              'Start: ${DateFormat('MMM dd, yyyy').format(event.startDate)}'),
          _buildDetailRow(Icons.access_time, 'Start Time: ${event.startTime.format(context)}'),
          _buildDetailRow(Icons.event,
              'End: ${DateFormat('MMM dd, yyyy').format(event.endDate)}'),
          _buildDetailRow(Icons.schedule, 'End Time: ${event.endTime.format(context)}'),
          _buildDetailRow(Icons.location_on, event.location),
          _buildDetailRow(Icons.category, event.category),
          _buildDetailRow(
              Icons.people, '${event.attendees} / ${event.maxAttendees}'),
          const SizedBox(height: 24),
          const Text('Description',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(event.description),
          const SizedBox(height: 24),
          Text('Registration: $attendancePercentage%',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: attendancePercentage / 100,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: const Icon(Icons.people),
            label: const Text('View Attendees'),
            onPressed: onViewAttendees,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 0),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.notifications),
                  label: const Text('Send Alert'),
                  onPressed: onSendAlert,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: onEdit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: const Icon(Icons.edit),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) =>
                        AlertDialog(
                          title: const Text('Delete Event'),
                          content: const Text(
                              'Are you sure you want to delete this event?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                onDelete();
                              },
                              child: const Text('Delete',
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.red,
                ),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}