import 'package:flutter/material.dart';

class ClassroomScreen extends StatelessWidget {
  const ClassroomScreen({super.key, required this.classroomId});

  final String classroomId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Classroom $classroomId')),
      body: Center(
        child: Text('Classroom detail for id: $classroomId'),
      ),
    );
  }
}
