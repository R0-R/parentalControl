import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main_screen.dart';

class ParentSignInScreen extends StatefulWidget {
  @override
  _ParentSignInScreenState createState() => _ParentSignInScreenState();
}

class _ParentSignInScreenState extends State<ParentSignInScreen> {
  final TextEditingController userNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  void signUp() async {
    if (_formKey.currentState!.validate()) {
      if (passwordController.text != confirmPasswordController.text) {
        setState(() {
          _confirmPasswordError = 'Passwords do not match';
        });
        return;
      }

      try {
        // Create user with Firebase Authentication
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text,
          password: passwordController.text,
        );

        // Store user data in Firestore
        await FirebaseFirestore.instance.collection('parents').doc(userCredential.user?.uid).set({
          'username': userNameController.text,
          'email': emailController.text, 
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Account created for ${userCredential.user?.email}')),
        );

        // Navigate to the dashboard screen after successful sign-up
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ParentMainScreen()),
        );
      } on FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign up: ${e.message}')),
        );
      }
    }
  }

  void _validateEmail(String value) {
    setState(() {
      if (value.isEmpty) {
        _emailError = 'Please enter your email (abc@gmail.com)';
      } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
        _emailError = 'Please enter a valid email (abc@gmail.com)';
      } else {
        _emailError = null;
      }
    });
  }

  void _validatePassword(String value) {
    setState(() {
      if (value.isEmpty) {
        _passwordError = 'Please enter your password';
      } else if (!RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*[!@#\$&*~.,%^]).{8,}$').hasMatch(value)) {
        _passwordError = 'Password must contain at least:\n'
                        '• One uppercase letter\n'
                        '• One lowercase letter\n'
                        '• One symbol\n'
                        '• At least 8 characters';
      } else {
        _passwordError = null; // No errors
      }
    });
  }


  void _validateConfirmPassword(String value) {
    setState(() {
      if (value != passwordController.text) {
        _confirmPasswordError = 'Passwords do not match';
      } else {
        _confirmPasswordError = null;
      }
    });
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Parent Sign Up'),
      backgroundColor: Colors.blue,
    ),
    backgroundColor: Colors.white,
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create an Account',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Text(
              'Sign up to monitor your child remotely',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40),
            TextFormField(
              controller: userNameController,
              decoration: InputDecoration(
                labelText: 'UserName',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your username';
                }
                return null;
              },
            ),
            SizedBox(height: 20),
            TextFormField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
                errorText: _emailError,
              ),
              keyboardType: TextInputType.emailAddress,
              onChanged: _validateEmail,
            ),
            SizedBox(height: 20),
            TextFormField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
                errorText: _passwordError,
              ),
              obscureText: true,
              onChanged: _validatePassword,
            ),
            SizedBox(height: 20),
            TextFormField(
              controller: confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
                errorText: _confirmPasswordError,
              ),
              obscureText: true,
              onChanged: _validateConfirmPassword,
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: signUp,
              child: Text('Sign Up'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white, backgroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(vertical: 15),
                textStyle: TextStyle(fontSize: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
            SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Return to login screen or previous screen
              },
              child: Text('Already have an account? Sign In'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue, textStyle: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}