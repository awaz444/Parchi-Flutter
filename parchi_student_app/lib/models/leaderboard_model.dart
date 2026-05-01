class LeaderboardItem {
  final int rank;
  final String name;
  final String university;
  final int redemptions;
  final String? userId; // Optional: ID if available
  final String? parchiId; // Optional: Parchi ID if available
  final String? profilePicture; // Optional: profile picture URL

  LeaderboardItem({
    required this.rank,
    required this.name,
    required this.university,
    required this.redemptions,
    this.userId,
    this.parchiId,
    this.profilePicture,
  });

  factory LeaderboardItem.fromJson(Map<String, dynamic> json) {
    return LeaderboardItem(
      rank: json['rank'] ?? 0,
      name: json['name'] ?? '',
      university: json['university'] ?? '',
      redemptions: json['redemptions'] ?? 0,
      userId: json['userId']?.toString() ?? json['user_id']?.toString(),
      parchiId: json['parchiId']?.toString() ?? json['parchi_id']?.toString(),
      profilePicture: json['profilePicture']?.toString() ?? json['profile_picture']?.toString(),
    );
  }
}

class LeaderboardPagination {
  final int page;
  final int limit;
  final int total;
  final int pages;
  final bool hasNext;
  final bool hasPrev;

  LeaderboardPagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
    required this.hasNext,
    required this.hasPrev,
  });

  factory LeaderboardPagination.fromJson(Map<String, dynamic> json) {
    return LeaderboardPagination(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 10,
      total: json['total'] ?? 0,
      pages: json['pages'] ?? 0,
      hasNext: json['hasNext'] ?? false,
      hasPrev: json['hasPrev'] ?? false,
    );
  }
}

class LeaderboardResponse {
  final List<LeaderboardItem> items;
  final LeaderboardPagination pagination;

  LeaderboardResponse({
    required this.items,
    required this.pagination,
  });

  factory LeaderboardResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final itemsList = data['items'] as List<dynamic>;
    
    return LeaderboardResponse(
      items: itemsList
          .map((item) => LeaderboardItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      pagination: LeaderboardPagination.fromJson(
        data['pagination'] as Map<String, dynamic>,
      ),
    );
  }
}

