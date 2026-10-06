class AppUser {
  final int id;
  final String username;
  final String name;
  final String email;
  final String role; // 'farmer' or 'buyer'
  final String? contact;

  const AppUser({
    required this.id,
    required this.username,
    required this.name,
    required this.email,
    required this.role,
    this.contact,
  });

  bool get isFarmer => role == 'farmer';
  bool get isBuyer => role == 'buyer';

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['user_id'] as int,
        username: j['username'] as String,
        name: j['name'] as String,
        email: j['email'] as String,
        role: j['role'] as String,
        contact: j['contact'] as String?,
      );
}
