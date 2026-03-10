class WishlistItem {
  final String id;
  final String userId;
  final String titulo;
  final String? descricao;
  final String? link;
  final String? photoUrl;
  final String? compradorId;
  final DateTime createdAt;

  WishlistItem({
    required this.id,
    required this.userId,
    required this.titulo,
    this.descricao,
    this.link,
    this.photoUrl,
    this.compradorId,
    required this.createdAt,
  });

  factory WishlistItem.fromMap(Map<String, dynamic> map) {
    return WishlistItem(
      id: map['id'],
      userId: map['user_id'],
      titulo: map['titulo'],
      descricao: map['descricao'],
      link: map['link'],
      photoUrl: map['photo_url'],
      compradorId: map['comprador_id'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'titulo': titulo,
      'descricao': descricao,
      'link': link,
      'photo_url': photoUrl,
      'comprador_id': compradorId,
    };
  }
}
