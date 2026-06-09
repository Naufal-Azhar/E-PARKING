import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart'; // Impor pustaka sensor NFC HP
import '../../core/services/firebase_service.dart';
import '../../models/user_model.dart';
import '../../models/slot_model.dart';
import '../auth/login_view.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final FirebaseService _firebaseService = FirebaseService();

  void _signOut() async {
    await _firebaseService.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Parkir Mall', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _signOut,
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Seksi Informasi Saldo dan Profil User secara Realtime
              StreamBuilder<UserModel?>(
                stream: _firebaseService.streamUserData(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data == null) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text("Gagal sinkronisasi data profil."),
                      ),
                    );
                  }
                  
                  final user = snapshot.data!;
                  return Card(
                    color: Colors.blueAccent,
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Halo, ${user.name}',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                user.isParking ? 'Parkir di: ${user.parkedAtSlot}' : 'Status: Mencari Parkir',
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                              Text(
                                'Rp ${user.saldoDummy}',
                                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Peta Slot Parkir (Live)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              
              // Denah Grid Slot Bioskop untuk Kendaraan (Koneksi ESP32)
              StreamBuilder<List<SlotModel>>(
                stream: _firebaseService.streamParkingSlots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text("Menghubungkan ke sensor alat kelompok..."),
                      ),
                    );
                  }
                  
                  final slots = snapshot.data!;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: slots.length,
                    itemBuilder: (context, index) {
                      final slot = slots[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: slot.isFilled ? Colors.red[400] : Colors.green[400],
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                slot.id,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                slot.isFilled ? "TERISI" : "KOSONG",
                                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
      // --- FITUR BARU: TOMBOL PEMBACA SCAN KARTU NFC DI HP ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // 1. Periksa ketersediaan perangkat keras NFC di HP Android
          bool isAvailable = await NfcManager.instance.isAvailable();
          
          if (!isAvailable) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error: Fitur NFC HP tidak aktif atau tidak didukung!'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          // 2. Beri umpan balik visual bahwa sistem stand-by mendengarkan kartu
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('NFC Aktif! Tempelkan kartu KTM/Siswa ke belakang HP...'),
              duration: Duration(seconds: 10),
            ),
          );

          // 3. Membuka sesi jabat tangan sensor NFC HP
          NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
            try {
              final nfcData = tag.data;
              // Mendeteksi berbagai jenis protokol chip NFC kartu pintar
              final Map? identifier = nfcData['isodep'] ?? nfcData['mifareclassic'] ?? nfcData['nfca'];
              
              if (identifier != null && identifier.containsKey('identifier')) {
                final List<int> uidBytes = List<int>.from(identifier['identifier']);
                // Mengubah urutan bit biner kartu menjadi kode teks String HEX unik
                String cardUid = uidBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase();

                // 4. Melempar ID unik kartu ke database cloud Firebase
                final result = await _firebaseService.processNfcTap(cardUid);

                if (mounted) {
                  // Hapus snackbar stand-by sebelumnya
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  // Tampilkan notifikasi status Check-In/Check-Out berhasil
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message']),
                      backgroundColor: result['success'] ? Colors.green : Colors.red,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Gagal membaca kartu: $e'), backgroundColor: Colors.red),
                );
              }
            } finally {
              // 5. Tutup kembali sesi komunikasi antena agar baterai HP hemat
              NfcManager.instance.stopSession();
            }
          });
        },
        label: const Text('Scan Kartu NFC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.nfc, color: Colors.white),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }
}