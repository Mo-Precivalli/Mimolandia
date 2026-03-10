import 'package:flutter/material.dart';
import '../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    // Aguarda um pequeno tempo para mostrar a tela de carregamento
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Verifica se há um usuário autenticado na sessão atual do Supabase
    final session = supabase.auth.currentSession;
    if (session != null) {
      // Já está logado, vai pra Home
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      // Não está logado, vai pro Login
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.deepPurple,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.card_giftcard, size: 80, color: Colors.white),
            SizedBox(height: 24),
            Text(
              'Desejo',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
