import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PrayerTimesScreen extends StatefulWidget {
  @override
  _PrayerTimesScreenState createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  Map<String, dynamic>? prayerTimes;
  String? currentCity;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _getPrayerTimes();
  }

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('خدمات الموقع غير مفعلة');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('تم رفض صلاحية الموقع');
      }
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<String> _getCityName(double lat, double lon) async {
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&accept-language=ar');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['address']['city'] ?? 
               data['address']['town'] ?? 
               data['address']['village'] ?? 
               'مدينة غير معروفة';
      }
    } catch (e) {
      print('Error getting city name: $e');
    }
    return 'مدينة غير معروفة';
  }

  Future<void> _getPrayerTimes() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // جلب الموقع الحالي
      Position position = await _getCurrentLocation();
      double lat = position.latitude;
      double lon = position.longitude;
      
      // جلب اسم المدينة
      String city = await _getCityName(lat, lon);
      
      // جلب أوقات الصلاة من API
      final url = Uri.parse(
          'http://api.aladhan.com/v1/timings?latitude=$lat&longitude=$lon&method=8');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          prayerTimes = data['data']['timings'];
          currentCity = city;
          isLoading = false;
        });
      } else {
        throw Exception('فشل في جلب أوقات الصلاة');
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  String _getNextPrayer() {
    if (prayerTimes == null) return '--:--';
    
    final now = DateTime.now();
    final currentTime = TimeOfDay(hour: now.hour, minute: now.minute);
    
    final prayers = [
      {'name': 'الفجر', 'time': prayerTimes!['Fajr']},
      {'name': 'الشروق', 'time': prayerTimes!['Sunrise']},
      {'name': 'الظهر', 'time': prayerTimes!['Dhuhr']},
      {'name': 'العصر', 'time': prayerTimes!['Asr']},
      {'name': 'المغرب', 'time': prayerTimes!['Maghrib']},
      {'name': 'العشاء', 'time': prayerTimes!['Isha']},
    ];
    
    for (var prayer in prayers) {
      List<String> parts = prayer['time'].split(':');
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);
      
      if (currentTime.hour < hour || 
          (currentTime.hour == hour && currentTime.minute < minute)) {
        return prayer['name']!;
      }
    }
    return 'الفجر';
  }

  String _getTimeUntilNext() {
    if (prayerTimes == null) return '--:--';
    
    final now = DateTime.now();
    final currentTime = TimeOfDay(hour: now.hour, minute: now.minute);
    
    final prayers = [
      prayerTimes!['Fajr'],
      prayerTimes!['Sunrise'],
      prayerTimes!['Dhuhr'],
      prayerTimes!['Asr'],
      prayerTimes!['Maghrib'],
      prayerTimes!['Isha'],
    ];
    
    for (String prayerTime in prayers) {
      List<String> parts = prayerTime.split(':');
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);
      
      if (currentTime.hour < hour || 
          (currentTime.hour == hour && currentTime.minute < minute)) {
        int diffMinutes = (hour * 60 + minute) - (currentTime.hour * 60 + currentTime.minute);
        int hours = diffMinutes ~/ 60;
        int minutes = diffMinutes % 60;
        return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
      }
    }
    
    // إذا لم يتم العثور على صلاة اليوم، ننتقل إلى صلاة الفجر غداً
    List<String> fajrParts = prayers[0].split(':');
    int fajrHour = int.parse(fajrParts[0]);
    int fajrMinute = int.parse(fajrParts[1]);
    int diffMinutes = (24 * 60 - (currentTime.hour * 60 + currentTime.minute)) + (fajrHour * 60 + fajrMinute);
    int hours = diffMinutes ~/ 60;
    int minutes = diffMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('أوقات الصلاة'),
        backgroundColor: Colors.green,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _getPrayerTimes,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.shade50, Colors.white],
          ),
        ),
        child: isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                    SizedBox(height: 20),
                    Text('جاري تحميل أوقات الصلاة...'),
                  ],
                ),
              )
            : errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: 50, color: Colors.red),
                        SizedBox(height: 10),
                        Text('حدث خطأ: $errorMessage'),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _getPrayerTimes,
                          child: Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _getPrayerTimes,
                    child: ListView(
                      padding: EdgeInsets.all(16),
                      children: [
                        // المدينة والتاريخ
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            children: [
                              Text(
                                currentCity ?? 'جاري التحديد...',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}',
                                style: TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 20),
                        
                        // الصلاة الحالية والتالية
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '🕌 الآن: ${_getNextPrayer()}',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                '⏰ التالي: ${_getTimeUntilNext()}',
                                style: TextStyle(
                                  fontSize: 24,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 20),
                        
                        // جدول الصلوات
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade300,
                                blurRadius: 5,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '📅 جدول اليوم',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 10),
                              _buildPrayerRow('الفجر', prayerTimes?['Fajr'] ?? '--:--'),
                              _buildPrayerRow('الشروق', prayerTimes?['Sunrise'] ?? '--:--'),
                              _buildPrayerRow('الظهر', prayerTimes?['Dhuhr'] ?? '--:--'),
                              _buildPrayerRow('العصر', prayerTimes?['Asr'] ?? '--:--'),
                              _buildPrayerRow('المغرب', prayerTimes?['Maghrib'] ?? '--:--'),
                              _buildPrayerRow('العشاء', prayerTimes?['Isha'] ?? '--:--'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildPrayerRow(String name, String time) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: TextStyle(fontSize: 16),
          ),
          Text(
            time,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}