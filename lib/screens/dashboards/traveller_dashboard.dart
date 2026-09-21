import 'package:flutter/material.dart';

import '../add_trip_screen.dart';
import '../my_trips_screen.dart';

class TravellerDashboard extends StatelessWidget {
  const TravellerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Traveller Dashboard'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TravelGuard MY',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Prepare for your international trip with personalised travel requirements.',
              ),
              const SizedBox(height: 32),

              // Opens the trip form used to generate a personalised checklist.
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddTripScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    child: Text('Add New Trip'),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Opens previously created trips belonging to the traveller.
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MyTripsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.luggage_outlined),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    child: Text('My Trips'),
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