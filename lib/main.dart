import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:parental_control/parent/notification.dart';
import 'child/cnt.dart';
import 'parent/login.dart';
import 'child/login.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  //NotificationService().initialize();
  runApp(SmartSafeApp());
}

class SmartSafeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartSafe',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: OnboardingScreen(),
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                'Remote monitoring your children from online',
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
                  foregroundColor: Colors.white, backgroundColor: Colors.blue,
                  minimumSize: Size(double.infinity, 50), 
                  textStyle: TextStyle(fontSize: 16),
                ),
              ),
              SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ChildLoginScreen()),
                    
                  );
                },
                child: Text('Get Started as Children'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue, minimumSize: Size(double.infinity, 50), 
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
