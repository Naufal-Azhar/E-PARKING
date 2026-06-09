import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/user_model.dart';
import '../../models/slot_model.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // Mendapatkan UID User yang sedang login
  String? get currentUid => _auth.currentUser?.uid;

  // Stream status login secara global
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Fungsi Register Akun Baru
  Future<String?> registerUser({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        // Set up data profile awal dan saldo dummy awal senilai Rp 100.000
        await _db.ref().child('users').child(credential.user!.uid).set({
          'name': name,
          'email': email,
          'saldo_dummy': 100000,
          'is_parking': false,
          'parked_at_slot': '',
        });
      }
      return null; // Return null artinya sukses tanpa error
    } on FirebaseAuthException catch (e) {
      return e.message ?? "Terjadi kesalahan saat registrasi.";
    } catch (e) {
      return e.toString();
    }
  }

  // Fungsi Login
  Future<String?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // Sukses
    } on FirebaseAuthException catch (e) {
      return e.message ?? "Email atau password salah.";
    } catch (e) {
      return e.toString();
    }
  }

  // Fungsi Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Menangkap data profil & saldo secara real-time
  Stream<UserModel?> streamUserData() {
    final uid = currentUid;
    if (uid == null) return Stream.value(null);
    
    return _db.ref().child('users').child(uid).onValue.map((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        return UserModel.fromMap(uid, data);
      }
      return null;
    });
  }

  // Menangkap perubahan sensor slot parkir dari ESP32 secara real-time
  Stream<List<SlotModel>> streamParkingSlots() {
    return _db.ref().child('parking_slots').onValue.map((event) {
      final List<SlotModel> slots = [];
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        data.forEach((key, value) {
          slots.add(SlotModel(
            id: key.toString(),
            isFilled: value == 1 || value == true,
          ));
        });
      }
      // Urutkan nama slot berdasarkan alfabet (cth: Slot A1, Slot A2)
      slots.sort((a, b) => a.id.compareTo(b.id));
      return slots;
    });
  }

  // --- FITUR BARU: LOGIKA TAP KARTU NFC (CHECK-IN & CHECK-OUT POTONG SALDO) ---
  Future<Map<String, dynamic>> processNfcTap(String cardUid) async {
    final uid = currentUid;
    if (uid == null) return {'success': false, 'message': 'User belum login.'};

    final userRef = _db.ref().child('users').child(uid);
    final snapshot = await userRef.get();

    if (!snapshot.exists) {
      return {'success': false, 'message': 'Data user tidak ditemukan.'};
    }

    final userData = snapshot.value as Map;
    bool isParking = userData['is_parking'] ?? false;
    int currentSaldo = userData['saldo_dummy'] ?? 0;

    // ALUR 1: JIKA BELUM PARKIR (TAP PERTAMA = MASUK / CHECK-IN)
    if (!isParking) {
      int now = DateTime.now().millisecondsSinceEpoch;
      await userRef.update({
        'is_parking': true,
        'check_in_time': now,
        'parked_at_slot': 'NFC Zone',
        'card_uid': cardUid,
      });
      return {
        'success': true, 
        'status': 'check_in', 
        'message': 'Check-In Sukses! Timer parkir dimulai.'
      };
    } 
    // ALUR 2: JIKA SUDAH PARKIR (TAP KEDUA = KELUAR / POTONG SALDO)
    else {
      int checkInTime = userData['check_in_time'] ?? DateTime.now().millisecondsSinceEpoch;
      int now = DateTime.now().millisecondsSinceEpoch;
      
      // Menghitung durasi total parkir (dalam satuan detik)
      int durationInSeconds = ((now - checkInTime) / 1000).round();
      if (durationInSeconds < 1) durationInSeconds = 1; // Minimal terhitung 1 detik

      // ATURAN TARIF DEMO PBL: Rp 1.000 per 5 detik
      int tarifPer5Detik = 1000;
      int totalBiaya = ((durationInSeconds / 5).ceil()) * tarifPer5Detik;

      if (currentSaldo < totalBiaya) {
        return {'success': false, 'message': 'Saldo tidak cukup! Biaya parkir: Rp $totalBiaya'};
      }

      // Potong saldo dummy dan kembalikan status parkir user ke normal
      int saldoBaru = currentSaldo - totalBiaya;
      await userRef.update({
        'is_parking': false,
        'saldo_dummy': saldoBaru,
        'check_in_time': null,
        'parked_at_slot': '',
      });

      return {
        'success': true,
        'status': 'check_out',
        'message': 'Check-Out Sukses!\nDurasi: $durationInSeconds detik\nBiaya: Rp $totalBiaya\nSisa Saldo: Rp $saldoBaru'
      };
    }
  }
}