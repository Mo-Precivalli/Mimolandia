import 'package:flutter/material.dart';

import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../models/wishlist_item.dart';
import '../main.dart'; // import supabase instance
import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddEditItemScreen extends StatefulWidget {
  final WishlistItem? itemToEdit;

  const AddEditItemScreen({super.key, this.itemToEdit});

  @override
  State<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends State<AddEditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _linkController = TextEditingController();
  
  bool _isLoading = false;
  Uint8List? _imageBytes;
  String? _existingPhotoUrl;
  String? _metadataPhotoUrl; // URL buscada via link

  @override
  void initState() {
    super.initState();
    if (widget.itemToEdit != null) {
      _tituloController.text = widget.itemToEdit!.titulo;
      _descricaoController.text = widget.itemToEdit!.descricao ?? '';
      _linkController.text = widget.itemToEdit!.link ?? '';
      _existingPhotoUrl = widget.itemToEdit!.photoUrl;
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
      });
    }
  }

  Future<String?> _uploadImage(String userId) async {
    if (_imageBytes == null) return null;

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final destinationPath = '$userId/$fileName'; // Organiza por pasta de usuário

    await supabase.storage.from('wishlist-images').uploadBinary(
          destinationPath,
          _imageBytes!,
        );

    final publicUrl = supabase.storage.from('wishlist-images').getPublicUrl(destinationPath);
    return publicUrl;
  }

  Future<void> _fetchMetadata() async {
    final link = _linkController.text.trim();
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insira um link primeiro')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Tentar busca direta (Funciona bem em Apps Mobile)
      Metadata? data;
      try {
        data = await MetadataFetch.extract(link);
      } catch (e) {
        debugPrint('Busca direta falhou, tentando via proxy: $e');
      }

      // 2. Fallback via Proxy de CORS (Essencial para Flutter Web)
      if (data == null || data.image == null) {
        final proxyUrl = 'https://api.allorigins.win/get?url=${Uri.encodeComponent(link)}';
        final response = await http.get(Uri.parse(proxyUrl));
        
        if (response.statusCode == 200) {
          final jsonData = jsonDecode(response.body);
          final htmlContent = jsonData['contents'] as String;
          
          // O metadata_fetch pode processar a string HTML diretamente
          data = await MetadataFetch.extract(link); // Re-extracting for simplicity if proxy just returns content
          // Or more accurately if we have the content:
          final doc = MetadataFetch.responseToDocument(http.Response(htmlContent, 200));
          if (doc != null) {
              // Usually MetadataFetch.extract handles the logic, 
              // but if we are parsing a manually fetched doc:
              data = MetadataParser.parse(doc); 
          }
        }
      }

      if (data != null) {
        setState(() {
          if (data?.image != null) {
            _metadataPhotoUrl = data!.image;
            _imageBytes = null; // Prioriza a do link
          }
          // Sugerir título se estiver vazio
          if (_tituloController.text.trim().isEmpty && data?.title != null) {
            _tituloController.text = data!.title!;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Informações recuperadas com sucesso!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível extrair dados deste link automaticamente.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao buscar link: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser!.id;
      
      String? photoUrl = _existingPhotoUrl;
      if (_imageBytes != null) {
        photoUrl = await _uploadImage(userId);
      } else if (_metadataPhotoUrl != null) {
        photoUrl = _metadataPhotoUrl;
      }

      final itemData = {
        'user_id': userId,
        'titulo': _tituloController.text.trim(),
        'descricao': _descricaoController.text.trim().isEmpty ? null : _descricaoController.text.trim(),
        'link': _linkController.text.trim().isEmpty ? null : _linkController.text.trim(),
        'photo_url': photoUrl,
      };

      if (widget.itemToEdit == null) {
        // Criar novo
        await supabase.from('wishlist_items').insert(itemData);
      } else {
        // Atualizar
        await supabase.from('wishlist_items').update(itemData).eq('id', widget.itemToEdit!.id);
      }

      if (mounted) {
        Navigator.of(context).pop(true); // Retorna true para atualizar a lista
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar item: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.itemToEdit == null ? 'Adicionar Desejo' : 'Editar Desejo'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: _imageBytes != null
                            ? Image.memory(_imageBytes!, fit: BoxFit.contain)
                            : (_metadataPhotoUrl != null
                                ? Image.network(_metadataPhotoUrl!, fit: BoxFit.contain)
                                : (_existingPhotoUrl != null
                                    ? Image.network(_existingPhotoUrl!, fit: BoxFit.contain)
                                    : const Icon(Icons.add_a_photo, size: 50, color: Colors.grey))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _tituloController,
                      decoration: const InputDecoration(labelText: 'O que você quer ganhar?'),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Campo obrigatório' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descricaoController,
                      decoration: const InputDecoration(labelText: 'Detalhes (tamanho, cor, modelo)'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _linkController,
                      decoration: InputDecoration(
                        labelText: 'Link de onde comprar',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.auto_fix_high),
                          tooltip: 'Buscar foto pelo link',
                          onPressed: _fetchMetadata,
                        ),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _saveItem,
                      child: Text(widget.itemToEdit == null ? 'Salvar Novo Desejo' : 'Salvar Alterações'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
