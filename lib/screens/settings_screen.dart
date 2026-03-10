import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../providers/theme_provider.dart';
import '../providers/settings_provider.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isEditingName = false;
  File? _imageFile;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadCurrentName();
  }

  Future<void> _loadCurrentName() async {
    final userId = supabase.auth.currentUser!.id;
    try {
      final response = await supabase.from('profiles').select().eq('id', userId).single();
      if (mounted) {
        setState(() {
          _nameController.text = response['nome'] ?? '';
          _avatarUrl = response['avatar_url'];
        });
      }
    } catch (e) {
      // Falha silenciosa ou log
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
      _uploadImage();
    }
  }

  Future<void> _uploadImage() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final destinationPath = '$userId/$fileName';

      await supabase.storage.from('wishlist-images').upload(
        destinationPath,
        _imageFile!,
      );

      final publicUrl = supabase.storage.from('wishlist-images').getPublicUrl(destinationPath);
      
      await supabase.from('profiles').update({'avatar_url': publicUrl}).eq('id', userId);

      setState(() {
        _avatarUrl = publicUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto atualizada com sucesso!')));
      }
    } catch (e) {
      debugPrint('Erro ao carregar imagem: $e'); // Caso não exista a coluna avatar_url
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro: Não foi possível salvar a imagem no perfil.')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      
      // Atualiza na tabela profiles
      await supabase.from('profiles').update({'nome': newName}).eq('id', userId);
      
      // Opcional: atualiza metadata no auth (para manter sincronizado se precisar no futuro)
      await supabase.auth.updateUser(
        UserAttributes(data: {'nome': newName}),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nome atualizado com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar nome: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Perfil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!) as ImageProvider
                          : (_avatarUrl != null ? NetworkImage(_avatarUrl!) : null),
                      child: _imageFile == null && _avatarUrl == null
                          ? const Icon(Icons.person, size: 50, color: Colors.grey)
                          : null,
                    ),
                    if (_isLoading)
                      const Positioned.fill(
                        child: CircularProgressIndicator(),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    enabled: _isEditingName,
                    decoration: const InputDecoration(
                      labelText: 'Seu Nome de Exibição',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(_isEditingName ? Icons.check : Icons.edit, color: _isEditingName ? Colors.green : null),
                  onPressed: () {
                    if (_isEditingName) {
                      _updateName();
                      setState(() => _isEditingName = false);
                    } else {
                      setState(() => _isEditingName = true);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const Text('Aparência', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SwitchListTile(
              title: const Text('Modo Escuro (Dark Mode)'),
              value: themeProvider.isDarkMode,
              onChanged: (value) {
                themeProvider.toggleTheme(value);
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text('Cor do Tema:', style: TextStyle(fontSize: 16)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  Colors.blue,
                  Colors.deepPurple,
                  Colors.pink,
                  Colors.teal,
                  Colors.orange,
                  Colors.red,
                  Colors.green,
                ].map((color) {
                  final isSelected = themeProvider.seedColor.toARGB32() == color.toARGB32();
                  return GestureDetector(
                    onTap: () => themeProvider.setSeedColor(color),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: themeProvider.isDarkMode ? Colors.white : Colors.black, width: 3) : null,
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                        ],
                      ),
                      child: isSelected ? Icon(Icons.check, color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white) : null,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Consumer<SettingsProvider>(
              builder: (context, settingsProvider, child) {
                return SwitchListTile(
                  title: const Text('Visualizar Itens em Grade'),
                  subtitle: const Text('Desative para visualização em lista'),
                  value: settingsProvider.isGridView,
                  onChanged: (value) {
                    settingsProvider.toggleViewMode();
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
