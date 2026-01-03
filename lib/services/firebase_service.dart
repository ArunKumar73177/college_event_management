import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== AUTHENTICATION ====================

  /// Login with Student ID (NO Firebase Auth Email)
  static Future<Map<String, dynamic>> loginWithStudentId(
      String studentId,
      String password
      ) async {
    try {
      final doc = await _firestore
          .collection('students')
          .doc(studentId)
          .get();

      if (!doc.exists) {
        throw 'Student ID not found';
      }

      final data = doc.data()!;

      if (data['password'] != password) {
        throw 'Wrong password';
      }

      // Save session locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('studentId', studentId);
      await prefs.setString('name', data['name']);
      await prefs.setString('role', data['role']);

      return {
        'studentId': studentId,
        'name': data['name'],
        'role': data['role'], // 'organizer' or 'attendee'
      };
    } catch (e) {
      throw e.toString();
    }
  }

  /// Get current logged-in user from local storage
  static Future<Map<String, String>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final studentId = prefs.getString('studentId');

    if (studentId == null) return null;

    return {
      'studentId': studentId,
      'name': prefs.getString('name') ?? '',
      'role': prefs.getString('role') ?? '',
    };
  }

  /// Logout
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ==================== EVENTS CRUD ====================

  /// Create new event (Organizer only)
  static Future<String> createEvent({
    required String title,
    required String description,
    required DateTime date,
    required String time,
    required String location,
    required String category,
    required int capacity,
  }) async {
    try {
      final docRef = await _firestore.collection('events').add({
        'title': title,
        'description': description,
        'date': Timestamp.fromDate(date),
        'time': time,
        'location': location,
        'category': category,
        'capacity': capacity,
        'registeredCount': 0,
        'status': 'upcoming', // upcoming, ongoing, completed
        'createdAt': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      throw 'Failed to create event: ${e.toString()}';
    }
  }

  /// Update event
  static Future<void> updateEvent(
      String eventId,
      Map<String, dynamic> updates,
      ) async {
    try {
      // Convert DateTime to Timestamp if present
      if (updates.containsKey('date') && updates['date'] is DateTime) {
        updates['date'] = Timestamp.fromDate(updates['date']);
      }

      await _firestore.collection('events').doc(eventId).update(updates);
    } catch (e) {
      throw 'Failed to update event: ${e.toString()}';
    }
  }

  /// Delete event
  static Future<void> deleteEvent(String eventId) async {
    try {
      // Delete all registrations first
      final registrations = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('registrations')
          .get();

      for (var doc in registrations.docs) {
        await doc.reference.delete();
      }

      // Delete the event
      await _firestore.collection('events').doc(eventId).delete();
    } catch (e) {
      throw 'Failed to delete event: ${e.toString()}';
    }
  }

  /// Get all events (real-time stream)
  static Stream<List<Map<String, dynamic>>> getAllEventsStream() {
    return _firestore
        .collection('events')
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;

        // Convert Timestamp to DateTime
        if (data['date'] is Timestamp) {
          data['date'] = (data['date'] as Timestamp).toDate();
        }

        return data;
      }).toList();
    });
  }

  /// Get active events for attendees
  static Stream<List<Map<String, dynamic>>> getActiveEventsStream() {
    return _firestore
        .collection('events')
        .where('status', whereIn: ['upcoming', 'ongoing'])
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;

        if (data['date'] is Timestamp) {
          data['date'] = (data['date'] as Timestamp).toDate();
        }

        return data;
      }).toList();
    });
  }

  // ==================== REGISTRATION SYSTEM ====================

  /// Register for an event
  static Future<void> registerForEvent(
      String eventId,
      String studentId,
      ) async {
    try {
      // Check if already registered
      final existingReg = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('registrations')
          .doc(studentId)
          .get();

      if (existingReg.exists) {
        throw 'Already registered for this event';
      }

      // Check capacity
      final eventDoc = await _firestore
          .collection('events')
          .doc(eventId)
          .get();

      final eventData = eventDoc.data()!;
      if (eventData['registeredCount'] >= eventData['capacity']) {
        throw 'Event is full';
      }

      // Add registration
      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('registrations')
          .doc(studentId)
          .set({
        'timestamp': FieldValue.serverTimestamp(),
        'studentId': studentId,
      });

      // Increment registered count
      await _firestore
          .collection('events')
          .doc(eventId)
          .update({
        'registeredCount': FieldValue.increment(1),
      });
    } catch (e) {
      throw e.toString();
    }
  }

  /// Unregister from event
  static Future<void> unregisterFromEvent(
      String eventId,
      String studentId,
      ) async {
    try {
      // Remove registration
      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('registrations')
          .doc(studentId)
          .delete();

      // Decrement registered count
      await _firestore
          .collection('events')
          .doc(eventId)
          .update({
        'registeredCount': FieldValue.increment(-1),
      });
    } catch (e) {
      throw 'Failed to unregister: ${e.toString()}';
    }
  }

  /// Check if student is registered for event
  static Future<bool> isRegistered(String eventId, String studentId) async {
    try {
      final doc = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('registrations')
          .doc(studentId)
          .get();

      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Get all registrations for a student
  static Future<List<String>> getStudentRegistrations(String studentId) async {
    try {
      final events = await _firestore.collection('events').get();
      List<String> registeredEventIds = [];

      for (var event in events.docs) {
        final reg = await event.reference
            .collection('registrations')
            .doc(studentId)
            .get();

        if (reg.exists) {
          registeredEventIds.add(event.id);
        }
      }

      return registeredEventIds;
    } catch (e) {
      return [];
    }
  }

  // ==================== ALERTS SYSTEM ====================

  /// Send alert to specific student(s)
  static Future<void> sendAlert({
    required String eventId,
    required String eventTitle,
    required String message,
    required List<String> studentIds,
  }) async {
    try {
      final batch = _firestore.batch();

      for (var studentId in studentIds) {
        final alertRef = _firestore.collection('alerts').doc();
        batch.set(alertRef, {
          'studentId': studentId,
          'eventId': eventId,
          'eventTitle': eventTitle,
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      await batch.commit();
    } catch (e) {
      throw 'Failed to send alerts: ${e.toString()}';
    }
  }

  /// Broadcast alert to all registered students for an event
  static Future<void> broadcastAlertToEvent(
      String eventId,
      String eventTitle,
      String message,
      ) async {
    try {
      // Get all registered students
      final registrations = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('registrations')
          .get();

      final studentIds = registrations.docs
          .map((doc) => doc.data()['studentId'] as String)
          .toList();

      if (studentIds.isNotEmpty) {
        await sendAlert(
          eventId: eventId,
          eventTitle: eventTitle,
          message: message,
          studentIds: studentIds,
        );
      }
    } catch (e) {
      throw 'Failed to broadcast alert: ${e.toString()}';
    }
  }

  /// Get alerts for a student (real-time)
  static Stream<List<Map<String, dynamic>>> getAlertsStream(String studentId) {
    return _firestore
        .collection('alerts')
        .where('studentId', isEqualTo: studentId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;

        if (data['timestamp'] is Timestamp) {
          data['timestamp'] = (data['timestamp'] as Timestamp).toDate();
        }

        return data;
      }).toList();
    });
  }

  /// Get unread alerts count
  static Stream<int> getUnreadAlertsCountStream(String studentId) {
    return _firestore
        .collection('alerts')
        .where('studentId', isEqualTo: studentId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mark alert as read
  static Future<void> markAlertAsRead(String alertId) async {
    try {
      await _firestore
          .collection('alerts')
          .doc(alertId)
          .update({'isRead': true});
    } catch (e) {
      throw 'Failed to mark alert as read: ${e.toString()}';
    }
  }

  /// Mark all alerts as read for a student
  static Future<void> markAllAlertsAsRead(String studentId) async {
    try {
      final alerts = await _firestore
          .collection('alerts')
          .where('studentId', isEqualTo: studentId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();

      for (var doc in alerts.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      throw 'Failed to mark alerts as read: ${e.toString()}';
    }
  }

  // ==================== QR CODE ====================

  /// Generate QR data for event registration
  static String generateQRData(String eventId, String studentId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$eventId|$studentId|$timestamp';
  }

  /// Verify QR code and mark attendance
  static Future<Map<String, dynamic>> verifyQRAndMarkAttendance(
      String qrData,
      ) async {
    try {
      final parts = qrData.split('|');
      if (parts.length != 3) {
        throw 'Invalid QR code format';
      }

      final eventId = parts[0];
      final studentId = parts[1];
      final timestamp = int.parse(parts[2]);

      // Verify timestamp (QR valid for 5 minutes)
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - timestamp > 300000) {
        throw 'QR code expired';
      }

      // Verify registration
      final isReg = await isRegistered(eventId, studentId);
      if (!isReg) {
        throw 'Student not registered for this event';
      }

      // Mark attendance
      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('registrations')
          .doc(studentId)
          .update({
        'attended': true,
        'attendanceTime': FieldValue.serverTimestamp(),
      });

      // Get event and student details
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      final studentDoc = await _firestore.collection('students').doc(studentId).get();

      return {
        'success': true,
        'eventTitle': eventDoc.data()?['title'] ?? 'Unknown Event',
        'studentName': studentDoc.data()?['name'] ?? 'Unknown Student',
      };
    } catch (e) {
      throw e.toString();
    }
  }

  // ==================== FAVORITES ====================

  /// Add event to favorites
  static Future<void> addToFavorites(String studentId, String eventId) async {
    try {
      await _firestore
          .collection('students')
          .doc(studentId)
          .collection('favorites')
          .doc(eventId)
          .set({'timestamp': FieldValue.serverTimestamp()});
    } catch (e) {
      throw 'Failed to add to favorites: ${e.toString()}';
    }
  }

  /// Remove from favorites
  static Future<void> removeFromFavorites(String studentId, String eventId) async {
    try {
      await _firestore
          .collection('students')
          .doc(studentId)
          .collection('favorites')
          .doc(eventId)
          .delete();
    } catch (e) {
      throw 'Failed to remove from favorites: ${e.toString()}';
    }
  }

  /// Get favorites for student
  static Future<List<String>> getFavorites(String studentId) async {
    try {
      final snapshot = await _firestore
          .collection('students')
          .doc(studentId)
          .collection('favorites')
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      return [];
    }
  }

  // ==================== STATISTICS ====================

  /// Get organizer statistics
  static Future<Map<String, int>> getOrganizerStats() async {
    try {
      final events = await _firestore.collection('events').get();

      int total = events.docs.length;
      int upcoming = 0;
      int totalAttendees = 0;

      for (var doc in events.docs) {
        final data = doc.data();
        if (data['status'] == 'upcoming') upcoming++;
        totalAttendees += (data['registeredCount'] as int?) ?? 0;
      }

      return {
        'total': total,
        'upcoming': upcoming,
        'totalAttendees': totalAttendees,
      };
    } catch (e) {
      return {'total': 0, 'upcoming': 0, 'totalAttendees': 0};
    }
  }

  /// Get attendee statistics
  static Future<Map<String, int>> getAttendeeStats(String studentId) async {
    try {
      final registrations = await getStudentRegistrations(studentId);

      int registered = registrations.length;
      int upcoming = 0;
      int attended = 0;

      for (var eventId in registrations) {
        final eventDoc = await _firestore.collection('events').doc(eventId).get();
        final eventData = eventDoc.data();

        if (eventData?['status'] == 'upcoming') upcoming++;

        final regDoc = await _firestore
            .collection('events')
            .doc(eventId)
            .collection('registrations')
            .doc(studentId)
            .get();

        if (regDoc.data()?['attended'] == true) attended++;
      }

      return {
        'registered': registered,
        'upcoming': upcoming,
        'attended': attended,
      };
    } catch (e) {
      return {'registered': 0, 'upcoming': 0, 'attended': 0};
    }
  }
}