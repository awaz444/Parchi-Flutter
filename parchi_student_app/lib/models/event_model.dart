class EventModel {
  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final String externalUrl;
  final DateTime? eventDate;
  final String? venue;
  final bool isActive;
  final int displayOrder;

  EventModel({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    required this.externalUrl,
    this.eventDate,
    this.venue,
    this.isActive = true,
    this.displayOrder = 0,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      imageUrl: json['imageUrl'],
      externalUrl: json['externalUrl'] ?? '',
      eventDate: json['eventDate'] != null
          ? DateTime.tryParse(json['eventDate'].toString())
          : null,
      venue: json['venue'],
      isActive: json['isActive'] ?? true,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
    );
  }
}
