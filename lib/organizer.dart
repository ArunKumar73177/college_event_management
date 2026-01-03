import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/firebase_service.dart';

enum EventStatus { upcoming, ongoing, completed }

class Event {
  final String id;
  final String title;
  final DateTime date;
  final TimeOfDay time;
  final String location;
  final String description;
  final String category;
  final int maxAttendees;
  int attendees;
  final EventStatus status;

  Event({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.location,
    required this.description,
    required this.category,
    required this.maxAttendees,
    required this.attendees,
    required this.status,
  });

  factory Event.fromFirestore(Map<String, dynamic> data) {
    DateTime date = data['date'] is DateTime
        ? data['date']
        : (data['date'] as Timestamp).toDate();

    List<String> timeParts = data['time'].toString().split(':');
    TimeOfDay time = TimeOfDay(
      hour: int.parse(timeParts[0]),
      minute: int.parse(timeParts[1]),
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
      date: date,
      time: time,
      location: data['location'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      maxAttendees: data['capacity'] ?? 0,
      attendees: data['registeredCount'] ?? 0,
      status: status,
    );
  }
}

enum DashboardView { list, create, edit, details }

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
        date: event.date,
        time: '${event.time.hour}:${event.time.minute}',
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
          'date': updatedEvent.date,
          'time': '${updatedEvent.time.hour}:${updatedEvent.time.minute}',
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
            const Text('Back', style: TextStyle(color: Colors.black)),
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
                // Stats Cards (Real-time)
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

                // Search Bar
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

                // Filter Tabs
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
    final attendancePercentage = (event.attendees / event.maxAttendees * 100).round();

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
                  Text(
                    '${DateFormat('MMM dd, yyyy').format(event.date)} at ${event.time.format(context)}',
                    style: const TextStyle(color: Colors.grey),
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
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
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
    _selectedDate = widget.event?.date ?? DateTime.now();
    _selectedTime = widget.event?.time ?? TimeOfDay.now();
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
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  setState(() {
                    _selectedDate = date;
                  });
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  DateFormat('MMM dd, yyyy').format(_selectedDate),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _selectedTime,
                );
                if (time != null) {
                  setState(() {
                    _selectedTime = time;
                  });
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Time',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.access_time),
                ),
                child: Text(
                  _selectedTime.format(context),
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
        date: _selectedDate,
        time: _selectedTime,
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

  const EventDetailsWidget({
    Key? key,
    required this.event,
    required this.onEdit,
    required this.onDelete,
    required this.onSendAlert,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final attendancePercentage = (event.attendees / event.maxAttendees * 100).round();

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
              DateFormat('MMM dd, yyyy').format(event.date)),
          _buildDetailRow(Icons.access_time, event.time.format(context)),
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
                    builder: (context) => AlertDialog(
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