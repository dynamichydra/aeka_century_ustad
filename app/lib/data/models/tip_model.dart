class TipModel {
  final String id;
  final String title;
  final String body;

  const TipModel({
    required this.id,
    required this.title,
    required this.body,
  });

  factory TipModel.fromJson(Map<String, dynamic> json) {
    return TipModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
    );
  }
}
