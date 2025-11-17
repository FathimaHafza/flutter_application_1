import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const WeatherDashboard(),
    );
  }
}

class WeatherDashboard extends StatefulWidget {
  const WeatherDashboard({super.key});

  @override
  State<WeatherDashboard> createState() => _WeatherDashboardState();
}

class _WeatherDashboardState extends State<WeatherDashboard> {
  final TextEditingController _indexController = TextEditingController(text: '224235D');
  
  double? _latitude;
  double? _longitude;
  String? _requestUrl;
  String? _lastUpdate;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isCached = false;
  
  // Weather data
  double? _temperature;
  double? _windSpeed;
  int? _weatherCode;

  @override
  void initState() {
    super.initState();
    _calculateCoordinates();
    _loadCachedData();
  }

  void _calculateCoordinates() {
    final index = _indexController.text.trim();
    if (index.length >= 4) {
      final firstTwo = int.tryParse(index.substring(0, 2)) ?? 0;
      final nextTwo = int.tryParse(index.substring(2, 4)) ?? 0;
      
      setState(() {
        _latitude = 5 + (firstTwo / 10.0);
        _longitude = 79 + (nextTwo / 10.0);
        _requestUrl = 'https://api.open-meteo.com/v1/forecast?latitude=${_latitude!.toStringAsFixed(1)}&longitude=${_longitude!.toStringAsFixed(1)}&current_weather=true';
      });
    }
  }

  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('weather_data');
    if (cachedData != null) {
      final data = json.decode(cachedData);
      setState(() {
        _temperature = data['temperature']?.toDouble();
        _windSpeed = data['windspeed']?.toDouble();
        _weatherCode = data['weathercode'];
        _lastUpdate = data['last_update'];
        _isCached = true;
      });
    }
  }

  Future<void> _saveWeatherData(Map<String, dynamic> weatherData) async {
    final prefs = await SharedPreferences.getInstance();
    final dataToSave = {
      'temperature': weatherData['temperature'],
      'windspeed': weatherData['windspeed'],
      'weathercode': weatherData['weathercode'],
      'last_update': DateTime.now().toString(),
    };
    await prefs.setString('weather_data', json.encode(dataToSave));
  }

  Future<void> _fetchWeather() async {
    if (_requestUrl == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isCached = false;
    });

    try {
      final response = await http.get(Uri.parse(_requestUrl!));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final currentWeather = data['current_weather'];
        
        setState(() {
          _temperature = currentWeather['temperature']?.toDouble();
          _windSpeed = currentWeather['windspeed']?.toDouble();
          _weatherCode = currentWeather['weathercode'];
          _lastUpdate = DateTime.now().toString();
          _isLoading = false;
        });
        
        await _saveWeatherData(currentWeather);
      } else {
        throw Exception('Failed to load weather data');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error. Showing cached data if available.';
        _isLoading = false;
      });
      await _loadCachedData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Weather Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Index Input Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Student Index',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _indexController,
                      decoration: InputDecoration(
                        hintText: 'Enter your student index',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.person),
                      ),
                      onChanged: (_) => _calculateCoordinates(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Coordinates Card
            if (_latitude != null && _longitude != null)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Computed Coordinates',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.red),
                          const SizedBox(width: 8),
                          Text('Latitude: ${_latitude!.toStringAsFixed(2)}°', style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text('Longitude: ${_longitude!.toStringAsFixed(2)}°', style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            
            // Fetch Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _fetchWeather,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  elevation: 4,
                ),
                child: _isLoading 
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('Fetching...', style: TextStyle(fontSize: 16)),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_download),
                          SizedBox(width: 8),
                          Text('Fetch Weather', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Error Message
            if (_errorMessage != null)
              Card(
                elevation: 4,
                color: Colors.red[50],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Weather Data Card
            if (_temperature != null)
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [Colors.blue[400]!, Colors.blue[600]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.wb_sunny, color: Colors.white, size: 28),
                            const SizedBox(width: 8),
                            const Text(
                              'Weather Data',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const Spacer(),
                            if (_isCached)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  '(cached)',
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Temperature
                        Row(
                          children: [
                            const Icon(Icons.thermostat, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'Temperature: ${_temperature!.toStringAsFixed(1)}°C',
                              style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        // Wind Speed
                        Row(
                          children: [
                            const Icon(Icons.air, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'Wind Speed: ${_windSpeed!.toStringAsFixed(1)} km/h',
                              style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        // Weather Code
                        Row(
                          children: [
                            const Icon(Icons.code, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'Weather Code: $_weatherCode',
                              style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        
                        if (_lastUpdate != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.access_time, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Last Updated: ${DateTime.parse(_lastUpdate!).toString().substring(0, 19)}',
                                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Request URL Card
            if (_requestUrl != null)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.link, color: Colors.grey),
                          SizedBox(width: 8),
                          Text(
                            'Request URL',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          _requestUrl!,
                          style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}