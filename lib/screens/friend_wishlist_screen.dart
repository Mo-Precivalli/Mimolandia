import 'package:flutter/material.dart';
import '../main.dart';
import '../models/wishlist_item.dart';
import 'item_detail_screen.dart';
import '../providers/settings_provider.dart';
import 'package:provider/provider.dart';

class FriendWishlistScreen extends StatelessWidget {
  final String friendId;
  final String friendName;

  const FriendWishlistScreen({
    super.key,
    required this.friendId,
    required this.friendName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Lista de $friendName')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('wishlist_items')
            .stream(primaryKey: ['id'])
            .eq('user_id', friendId)
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Erro ao carregar lista.'));
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Text('$friendName ainda não tem desejos cadastrados.'),
            );
          }

          final isGrid = Provider.of<SettingsProvider>(context).isGridView;

          if (isGrid) {
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = WishlistItem.fromMap(items[index]);
                return _buildGridCard(item, context);
              },
            );
          } else {
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = WishlistItem.fromMap(items[index]);
                return _buildListTile(item, context);
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildGridCard(WishlistItem item, BuildContext context) {
    final bool isBought = item.compradorId != null;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                ItemDetailScreen(item: item, isOwner: false),
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 6,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: item.photoUrl != null
                      ? Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          child: Image.network(
                            item.photoUrl!,
                            fit: BoxFit.contain,
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                                Theme.of(context).colorScheme.surfaceContainerHighest,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Icon(
                            Icons.card_giftcard,
                            size: 50,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                ),
                Container(
                  color: Theme.of(context).colorScheme.surface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 8.0,
                  ),
                  child: Text(
                    item.titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            if (isBought)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(WishlistItem item, BuildContext context) {
    final bool isBought = item.compradorId != null;

    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.all(8),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ItemDetailScreen(item: item, isOwner: false),
            ),
          );
        },
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 60,
            height: 60,
            child: item.photoUrl != null
                ? Image.network(item.photoUrl!, fit: BoxFit.cover)
                : Container(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(Icons.card_giftcard, color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
          ),
        ),
        title: Text(item.titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: item.descricao != null ? Text(item.descricao!, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
        trailing: isBought
            ? Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 20),
              )
            : null,
      ),
    );
  }
}
