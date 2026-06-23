import '../../data/models/event_model.dart';

/// Shared client-side event filters (feed + map).
class EventListFilters {
  const EventListFilters({
    this.category = 'all',
    this.date = 'week',
    this.sort = 'nearest',
    this.price = 'all',
    this.format = 'all',
  });

  final String category;
  final String date;
  final String sort;
  final String price;
  final String format;

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'date': date,
      'sort': sort,
      'price': price,
      'format': format,
    };
  }

  factory EventListFilters.fromMap(Map<String, dynamic> map) {
    return EventListFilters(
      category: map['category'] as String? ?? 'all',
      date: map['date'] as String? ?? 'week',
      sort: map['sort'] as String? ?? 'nearest',
      price: map['price'] as String? ?? 'all',
      format: map['format'] as String? ?? 'all',
    );
  }

  List<EventModel> apply(
    List<EventModel> events, {
    String query = '',
    double? sortLatitude,
    double? sortLongitude,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final now = DateTime.now();

    bool matchesDate(EventModel event) {
      if (date == 'all') return true;

      final start = event.dateTime.toLocal();
      final end = event.actualEndDateTime.toLocal();

      if (date == 'today') {
        final todayStart = DateTime(now.year, now.month, now.day);
        final todayEnd = todayStart.add(const Duration(days: 1));
        return end.isAfter(todayStart) && start.isBefore(todayEnd);
      }
      if (date == 'week') {
        final windowEnd = now.add(const Duration(days: 7));
        return end.isAfter(now) && start.isBefore(windowEnd);
      }
      if (date == 'month') {
        final windowEnd = DateTime(now.year, now.month + 1, now.day);
        return end.isAfter(now) && start.isBefore(windowEnd);
      }
      return true;
    }

    bool matchesCategory(EventModel event) {
      if (category == 'all') return true;
      return event.category.toLowerCase() == category.toLowerCase();
    }

    bool matchesPrice(EventModel event) {
      if (price == 'all') return true;
      if (price == 'free') return event.price == 0;
      if (price == 'paid') return event.price > 0;
      return true;
    }

    bool matchesFormat(EventModel event) {
      if (format == 'all') return true;
      if (format == 'online') return event.isOnline;
      if (format == 'offline') return !event.isOnline;
      return true;
    }

    var out = events.where((event) {
      final matchesQuery = normalizedQuery.isEmpty ||
          event.title.toLowerCase().contains(normalizedQuery) ||
          event.description.toLowerCase().contains(normalizedQuery) ||
          event.location.toLowerCase().contains(normalizedQuery) ||
          event.category.toLowerCase().contains(normalizedQuery);

      return matchesQuery &&
          matchesDate(event) &&
          matchesCategory(event) &&
          matchesPrice(event) &&
          matchesFormat(event);
    }).toList();

    if (sort == 'popular') {
      out.sort((a, b) => b.participantsCount.compareTo(a.participantsCount));
    } else if (sort == 'rating') {
      out.sort((a, b) => b.averageRating.compareTo(a.averageRating));
    } else if (sortLatitude != null && sortLongitude != null) {
      double dist(EventModel e) {
        final dLat = (e.latitude - sortLatitude).abs();
        final dLon = (e.longitude - sortLongitude).abs();
        return dLat + dLon;
      }

      out.sort((a, b) => dist(a).compareTo(dist(b)));
    } else {
      out.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    }

    return out;
  }
}
