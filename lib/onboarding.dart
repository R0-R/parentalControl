import 'package:flutter/material.dart';
import 'parent/login.dart';  // Import parent login screen
import 'child/login.dart'; // Import child login screen if you have it
import 'package:parental_control/child/login.dart';
import 'package:parental_control/parent/login.dart';

class OnboardingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/logo.png',
                height: 150,
              ),
              SizedBox(height: 50),
              Text(
                'Welcome to SmartSafe',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              Text(
                'Remote monitoring your children online',
                style: TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ParentLoginScreen()),
                  );
                },
                child: Text('Get Started as Parent'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.blue,
                  minimumSize: Size(double.infinity, 50), // full-width button
                  textStyle: TextStyle(fontSize: 16),
                ),
              ),
              SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ChildLoginScreen()), // Use ChildLoginScreen if implemented
                  );
                },
                child: Text('Get Started as Child'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  minimumSize: Size(double.infinity, 50), // full-width button
                  textStyle: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
