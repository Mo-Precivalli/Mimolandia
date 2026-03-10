import 'package:flutter/material.dart';

import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/wishlist_item.dart';
import '../main.dart'; // import supabase instance

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
  File? _imageFile;
  String? _existingPhotoUrl;

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
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(String userId) async {
    if (_imageFile == null) return null;

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final destinationPath = '$userId/$fileName'; // Organiza por pasta de usuário

    await supabase.storage.from('wishlist-images').upload(
          destinationPath,
          _imageFile!,
        );

    final publicUrl = supabase.storage.from('wishlist-images').getPublicUrl(destinationPath);
    return publicUrl;
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser!.id;
      
      String? photoUrl = _existingPhotoUrl;
      if (_imageFile != null) {
        photoUrl = await _uploadImage(userId);
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
                        child: _imageFile != null
                            ? Image.file(_imageFile!, fit: BoxFit.cover)
                            : (_existingPhotoUrl != null
                                ? Image.network(_existingPhotoUrl!, fit: BoxFit.cover)
                                : const Icon(Icons.add_a_photo, size: 50, color: Colors.grey)),
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
                      decoration: const InputDecoration(labelText: 'Link de onde comprar'),
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
