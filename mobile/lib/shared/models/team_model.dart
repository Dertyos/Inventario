class TeamModel {
  final String id;
  final String name;
  final String currency;
  final String timezone;
  final String? userRole;
  final DateTime createdAt;

  const TeamModel({
    required this.id,
    required this.name,
    this.currency = 'COP',
    this.timezone = 'America/Bogota',
    this.userRole,
    required this.createdAt,
  });

  factory TeamModel.fromJson(Map<String, dynamic> json) => TeamModel(
        id: json['id'] as String,
        name: json['name'] as String,
        currency: json['currency'] as String? ?? 'COP',
        timezone: json['timezone'] as String? ?? 'America/Bogota',
        userRole: json['userRole'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
