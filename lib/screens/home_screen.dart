import 'package:flutter/material.dart';

import '../main.dart';
import '../models/wishlist_item.dart';
import 'add_edit_item_screen.dart';
import 'friends_screen.dart';
import 'item_detail_screen.dart';
import '../providers/settings_provider.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _userName = 'Caregando...';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final response = await supabase
          .from('profiles')
          .select('nome')
          .eq('id', userId)
          .single();
      if (mounted) {
        setState(() {
          _userName = response['nome'] ?? 'Usuário';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userName = 'Usuário';
        });
      }
    }
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  Future<void> _deleteItem(String id) async {
    await supabase.from('wishlist_items').delete().eq('id', id);
    setState(() {}); // Re-render o FutureBuilder
  }

  Widget _buildMinhaLista() {
    final userId = supabase.auth.currentUser!.id;
    final stream = supabase
        .from('wishlist_items')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Erro ao carregar a lista'));
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Center(
            child: Text(
              'Você não tem nenhum desejo ainda.\nClique em + para adicionar!',
              textAlign: TextAlign.center,
            ),
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
    );
  }

  Widget _buildGridCard(WishlistItem item, BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ItemDetailScreen(item: item, isOwner: true),
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 6,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: item.photoUrl != null
                  ? Image.network(item.photoUrl!, fit: BoxFit.cover)
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.3),
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Icon(
                        Icons.card_giftcard,
                        size: 50,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
            ),
            Container(
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildPopupMenu(item),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(WishlistItem item, BuildContext context) {
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
              builder: (context) => ItemDetailScreen(item: item, isOwner: true),
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
                    child: Icon(
                      Icons.card_giftcard,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
          ),
        ),
        title: Text(
          item.titulo,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: item.descricao != null
            ? Text(
                item.descricao!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: _buildPopupMenu(item),
      ),
    );
  }

  Widget _buildPopupMenu(WishlistItem item) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      padding: EdgeInsets.zero,
      onSelected: (val) async {
        if (val == 'edit') {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddEditItemScreen(itemToEdit: item),
            ),
          );
        } else if (val == 'delete') {
          _deleteItem(item.id);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'edit', child: Text('Editar')),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Excluir', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Desejo App'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.of(
                  context,
                ).pushNamed('/settings').then((_) => _loadUserName());
              } else if (value == 'logout') {
                _signOut();
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem<String>(
                  enabled: false, // apenas visualização
                  child: Text(
                    'Olá, $_userName',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.tune, size: 20),
                      SizedBox(width: 8),
                      Text('Configurações'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Sair', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: _selectedIndex == 0 ? _buildMinhaLista() : const FriendsScreen(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list), label: 'Minha Lista'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Amigos'),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AddEditItemScreen(),
                  ),
                );
                if (result == true) setState(() {});
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
