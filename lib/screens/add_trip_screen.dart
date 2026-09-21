import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/country.dart';
import '../services/country_service.dart';
import '../services/trip_service.dart';
import 'checklist_screen.dart';

class AddTripScreen extends StatefulWidget {
  const AddTripScreen({super.key});

  @override
  State<AddTripScreen> createState() => _AddTripScreenState();
}

class _AddTripScreenState extends State<AddTripScreen> {
  final CountryService _countryService = CountryService();
  final TripService _tripService = TripService();
  final TextEditingController _durationController = TextEditingController();

  List<Country> _countries = [];
  Country? _selectedCountry;
  String? _selectedPurpose;
  DateTime? _departureDate;

  bool _isLoadingCountries = true;
  bool _isCreatingTrip = false;
  String? _countryError;
  
  final List<Map<String,String>> _purposes = [
    {
      'value': 'tourism',
      'label': 'Tourism',
    },
    {
      'value': 'business',
      'label': 'Business',
    },
    {
      'value': 'study',
      'label': 'Study',
    },
  ];
  
  @override
  void initState(){
    super.initState();
    _loadCountries();
  }
  
  @override
  void dispose(){
    _durationController.dispose();
    super.dispose();
  }
  
  //Load enabled destination countries from Firestore.
Future<void> _loadCountries() async {
    try {
      final List<Country> countries = await _countryService.getEnabledCountries();
      
      if (!mounted) return;
      
      setState(() {
        _countries = countries;
        _isLoadingCountries = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _countryError = 'Unable to load destination countries.';
        _isLoadingCountries = false;
      });
    }
  }
  //Opens the date picker for the traveller's departure date.
  Future<void> _selectDepartureDate() async {
    final DateTime now = DateTime.now();
    
    final DateTime? selectedDate = await showDatePicker(
        context: context, 
        initialDate: now.add(const Duration(days: 1)),
        firstDate: now,
        lastDate: DateTime(now.year + 5),
    );
    if (selectedDate == null || !mounted) return;
    
    setState(() {
      _departureDate = selectedDate;
    });
  }
  //Validates the trip details before passing them to the DSS
  String? _validatetrip(){
    if (_selectedCountry == null){
      return 'Please select a destination country.';
    }
    if (_selectedPurpose == null){
      return 'Please select a travel purpose.';
    }
    if (_departureDate == null){
      return 'Please select a departure date.';
    }
    final int? duration = int.tryParse(_durationController.text.trim());

    if (duration == null || duration <= 0) {
      return 'Please enter a valid trip duration.';
    }
    return null;
  }
  //Creates the trip and generates its personalised checklist.
  Future<void> _generateChecklist() async {
    if (_isCreatingTrip) return;

    final String? validationMessage = _validatetrip();
    
    if (validationMessage != null){
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(validationMessage),
          ),
      );
      return;
    }
    final User? user = FirebaseAuth.instance.currentUser;
    
    if (user == null){
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No authenticated user was found.'),
          ),
      );
      return;
    }
    final int duration = int.parse(_durationController.text.trim());

    setState(() {
      _isCreatingTrip = true;
    });

    try {
      final String tripId = await _tripService.createTripWithChecklist(
          userId: user.uid,
          countryId: _selectedCountry!.id,
          purpose: _selectedPurpose!,
          durationDays: duration,
          departureDate: _departureDate!,
      );
      if (!mounted) return;

      setState(() {
        _isCreatingTrip = false;
      });

// Open the generated checklist for the newly created trip.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChecklistScreen(
            tripId: tripId,
          ),
        ),
      );
    } catch (e) {
      debugPrint ('Create trip Error: $e');

      if (!mounted) return;

      setState(() {
        _isCreatingTrip = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to generate the travel checklist.'),
          ),
      );
    }
  }
  String _formatDate(DateTime date){
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Trip'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Plan Your Trip',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your travel details to generate a personalised preparation checklist.',
              ),
              const SizedBox(height: 28),

              const Text(
                'Destination Country',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              if (_isLoadingCountries)
                const Center(
                  child: CircularProgressIndicator(),
                )
              else if (_countryError != null)
                Text(
                  _countryError!,
                  style: const TextStyle(
                    color: Colors.red,
                  ),
                )
              else
                DropdownButtonFormField<Country>(
                  initialValue: _selectedCountry,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Select destination',
                  ),
                  items: _countries.map((country) {
                    return DropdownMenuItem<Country>(
                      value: country,
                      child: Text(country.name),
                    );
                  }).toList(),
                  onChanged: (Country? country) {
                    setState(() {
                      _selectedCountry = country;
                    });
                  },
                ),

              const SizedBox(height: 20),

              const Text(
                'Travel Purpose',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                initialValue: _selectedPurpose,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Select purpose',
                ),
                items: _purposes.map((purpose) {
                  return DropdownMenuItem<String>(
                    value: purpose['value'],
                    child: Text(purpose['label']!),
                  );
                }).toList(),
                onChanged: (String? purpose) {
                  setState(() {
                    _selectedPurpose = purpose;
                  });
                },
              ),

              const SizedBox(height: 20),

              const Text(
                'Departure Date',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              InkWell(
                onTap: _selectDepartureDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(
                      Icons.calendar_today,
                    ),
                  ),
                  child: Text(
                    _departureDate == null
                        ? 'Select departure date'
                        : _formatDate(_departureDate!),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Duration of Stay',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter number of days',
                  suffixText: 'days',
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isCreatingTrip
                      ? null
                      : _generateChecklist,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    child: _isCreatingTrip
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : const Text(
                      'Generate Checklist',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}