import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/wishlist_item.dart';
import '../main.dart'; // supabase

class ItemDetailScreen extends StatefulWidget {
  final WishlistItem item;
  final bool isOwner; // Se for o dono, não mostra se alguém comprou

  const ItemDetailScreen({
    super.key,
    required this.item,
    required this.isOwner,
  });

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late WishlistItem _item;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  Future<void> _openLink(String urlStr) async {
    final Uri url = Uri.parse(urlStr);
    if (!await launchUrl(url)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível abrir o link: $urlStr')),
        );
      }
    }
  }

  Future<void> _toggleComprado() async {
    setState(() => _isLoading = true);
    try {
      final currentUserId = supabase.auth.currentUser!.id;
      final bool isCurrentlyBoughtByMe = _item.compradorId == currentUserId;
      
      final String? newCompradorId = isCurrentlyBoughtByMe ? null : currentUserId;

      await supabase
          .from('wishlist_items')
          .update({'comprador_id': newCompradorId})
          .eq('id', _item.id);

      // Atualiza o estado local para refletir a mudança
      setState(() {
        _item = WishlistItem(
          id: _item.id,
          userId: _item.userId,
          titulo: _item.titulo,
          descricao: _item.descricao,
          link: _item.link,
          photoUrl: _item.photoUrl,
          compradorId: newCompradorId,
          createdAt: _item.createdAt,
        );
      });
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar status: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isBought = _item.compradorId != null;
    final String currentUserId = supabase.auth.currentUser!.id;
    final bool isBoughtByMe = _item.compradorId == currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: Text(_item.titulo),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_item.photoUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(_item.photoUrl!, height: 300, fit: BoxFit.cover),
              )
            else
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.card_giftcard, size: 80, color: Colors.grey),
              ),
            
            const SizedBox(height: 24),
            
            Text(
              _item.titulo,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            
            const SizedBox(height: 16),
            
            if (_item.descricao != null && _item.descricao!.isNotEmpty) ...[
              const Text('Detalhes:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_item.descricao!, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
            ],

            if (_item.link != null && _item.link!.isNotEmpty) ...[
              ElevatedButton.icon(
                onPressed: () => _openLink(_item.link!),
                icon: const Icon(Icons.shopping_cart),
                label: const Text('Visitar loja / Comprar'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Se for a tela do amigo (não for dono), mostra checkbox/aviso de compra
            if (!widget.isOwner) ...[
              const Divider(thickness: 2),
              const SizedBox(height: 16),
              
              if (isBought && !isBoughtByMe)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock, color: Colors.orange),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Outro amigo já marcou que vai dar este presente!',
                          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                )
              else
                CheckboxListTile(
                  title: const Text('Marcar como comprado', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Isso avisa os outros amigos, mas o dono da lista NÃO vai saber!'),
                  value: isBoughtByMe,
                  onChanged: _isLoading ? null : (val) => _toggleComprado(),
                  activeColor: Colors.green,
                  secondary: _isLoading 
                      ? const CircularProgressIndicator()
                      : Icon(isBoughtByMe ? Icons.check_circle : Icons.radio_button_unchecked, 
                             color: isBoughtByMe ? Colors.green : Colors.grey),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
