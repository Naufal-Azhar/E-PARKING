import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/services/firebase_service.dart' as local_service;
import 'views/auth/login_view.dart';
import 'views/dashboard/dashboard_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Menggunakan konfigurasi Web App Firebase yang baru saja kamu buat
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyAjs5xWgxPdoasnJu_5XGw0WJSMIPPelho",
      authDomain: "e-parking-debc9.firebaseapp.com",
      databaseURL: "https://e-parking-debc9-default-rtdb.asia-southeast1.firebasedatabase.app",
      projectId: "e-parking-debc9",
      storageBucket: "e-parking-debc9.firebasestorage.app",
      messagingSenderId: "933955772550",
      appId: "1:933955772550:web:0c4187dd3afebd37c43107",
      measurementId: "G-9V6M3FLYBP"
    ),
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-Parking Mall',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: local_service.FirebaseService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        // Jika user sudah login, langsung arahkan ke Dashboard
        if (snapshot.hasData && snapshot.data != null) {
          return const DashboardView();
        }
        
        // Jika belum login, tampilkan halaman Login utama
        return const LoginView();
      },
    );
  }
}