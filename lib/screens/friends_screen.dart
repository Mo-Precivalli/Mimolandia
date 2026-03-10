import 'package:flutter/material.dart';
import '../main.dart';
import 'friend_wishlist_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _showSearchDialog() async {
    _searchController.clear();
    _searchResults.clear();

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (contextDialog, setStateDialog) {
            Future<void> performSearch() async {
              final query = _searchController.text.trim();
              if (query.isEmpty) {
                setStateDialog(() => _searchResults = []);
                return;
              }

              setStateDialog(() => _isSearching = true);
              try {
                final currentUser = supabase.auth.currentUser;
                if (currentUser == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(contextDialog).showSnackBar(
                      const SnackBar(content: Text('Faça login para buscar amigos')),
                    );
                  }
                  return;
                }
                final currentUserId = currentUser.id;
                
                // 1. Get current friends
                final friendsResponse = await supabase
                    .from('friends')
                    .select('friend_id')
                    .eq('user_id', currentUserId);
                    
                final List<String> friendIds = (friendsResponse as List<dynamic>)
                    .map((item) => item['friend_id'] as String)
                    .toList();
                
                // Add current user to exclusion list
                friendIds.add(currentUserId);

                // 2. Search profiles excluding friends and self
                var queryBuilder = supabase
                    .from('profiles')
                    .select()
                    .ilike('nome', '%$query%');
                
                // Filter out all friend IDs and current user ID
                for (var id in friendIds) {
                  queryBuilder = queryBuilder.neq('id', id);
                }

                final results = await queryBuilder;

                setStateDialog(() {
                  _searchResults = List<Map<String, dynamic>>.from(results);
                });
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(contextDialog).showSnackBar(
                    SnackBar(content: Text('Erro na busca: $e')),
                  );
                }
              } finally {
                if (mounted) setStateDialog(() => _isSearching = false);
              }
            }

            return AlertDialog(
              title: const Text('Encontrar Amigos'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar usuários pelo nome...',
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: performSearch,
                        ),
                      ),
                      onSubmitted: (_) => performSearch(),
                    ),
                    const SizedBox(height: 16),
                    if (_isSearching)
                      const CircularProgressIndicator()
                    else if (_searchResults.isEmpty)
                      const Text('Nenhum resultado encontrado. Tente buscar algo diferente.')
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          itemBuilder: (contextBuilder, index) {
                            final user = _searchResults[index];
                            return ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.person_add)),
                              title: Text(user['nome']),
                              trailing: ElevatedButton(
                                onPressed: () {
                                  _addFriend(user['id'], contextDialog);
                                  if (contextDialog.mounted) {
                                    Navigator.of(contextDialog).pop(); // Fechar o popup
                                  }
                                },
                                child: const Text('Adicionar'),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fechar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addFriend(String friendId, BuildContext contextRoot) async {
    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('friends').insert({
        'user_id': userId,
        'friend_id': friendId,
      });

      if (contextRoot.mounted) {
        ScaffoldMessenger.of(contextRoot).showSnackBar(
          const SnackBar(content: Text('Amigo adicionado com sucesso!')),
        );
        setState(() {}); // Atualiza a lista de amigos (StreamBuilder)
      }
    } catch (e) {
      if (contextRoot.mounted) {
        ScaffoldMessenger.of(contextRoot).showSnackBar(
          SnackBar(content: Text('Erro ao adicionar amigo: $e')),
        );
      }
    }
  }

  Future<void> _removeFriend(String friendId, BuildContext contextRoot) async {
    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('friends')
          .delete()
          .eq('user_id', userId)
          .eq('friend_id', friendId);

      if (contextRoot.mounted) {
        ScaffoldMessenger.of(contextRoot).showSnackBar(
          const SnackBar(content: Text('Amigo removido')),
        );
        setState(() {});
      }
    } catch (e) {
      if (contextRoot.mounted) {
        ScaffoldMessenger.of(contextRoot).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  Widget _buildFriendsList() {
    final user = supabase.auth.currentUser;
    if (user == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 60, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            const Text(
              'Você está como Anônimo.\nPara adicionar amigos, faça login.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed('/login');
              },
              icon: const Icon(Icons.login),
              label: const Text('Fazer Login'),
            ),
          ],
        ),
      );
    }
    final userId = user.id;
    
    // Busca os amigos que O USUÁRIO adicionou
    final stream = supabase
        .from('friends')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Erro ao carregar amigos.'));
        }

        final friendsData = snapshot.data ?? [];
        if (friendsData.isEmpty) {
          return const Center(child: Text('Você ainda não adicionou nenhum amigo.'));
        }

        return ListView.builder(
          itemCount: friendsData.length,
          itemBuilder: (context, index) {
            final friendId = friendsData[index]['friend_id'];
            
            // Busca os detalhes do perfil do amigo
            return FutureBuilder(
              future: supabase.from('profiles').select().eq('id', friendId).single(),
              builder: (context, profileSnapshot) {
                if (!profileSnapshot.hasData) {
                  return const ListTile(title: Text('Carregando...'));
                }
                final profile = profileSnapshot.data as Map<String, dynamic>;
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(profile['nome']),
                  trailing: IconButton(
                    icon: const Icon(Icons.person_remove, color: Colors.red),
                    onPressed: () => _removeFriend(friendId, context),
                  ),
                  onTap: () {
                    final navigator = Navigator.of(context);
                    navigator.push(
                      MaterialPageRoute(
                        builder: (context) => FriendWishlistScreen(
                          friendId: friendId,
                          friendName: profile['nome'],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Expanded(
                child: Text('Meus Amigos:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              if (supabase.auth.currentUser != null)
                IconButton(
                  icon: const Icon(Icons.person_add),
                  onPressed: _showSearchDialog,
                  tooltip: 'Encontrar Amigos',
                ),
            ],
          ),
        ),
        Expanded(child: _buildFriendsList()),
      ],
    );
  }
}
