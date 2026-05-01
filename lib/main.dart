import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'prayertime_screen.dart';

Future<Position> getCurrentLocation() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return Future.error('Location services are disabled.');
  }
  
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return Future.error('Location permissions are denied');
    }
  }
  
  return await Geolocator.getCurrentPosition();
}

void main() {
  runApp(PrayerTimesApp());
}

class PrayerTimesApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prayer Times',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
      ),
      home: PrayerTimesScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}