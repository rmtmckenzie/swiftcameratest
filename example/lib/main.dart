import 'package:flutter/material.dart';
import 'package:swiftcamera/swiftcamera.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  SwiftCameraController cameraController = SwiftCameraController();

  void onCameraValueChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();

    cameraController.addListener(onCameraValueChanged);

    (() async {
      await cameraController.startPreview();

      print("Camera preview started!");
    })();
  }

  @override
  void dispose() {
    cameraController.removeListener(onCameraValueChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
            child: AspectRatio(
          aspectRatio: 4 / 3,
          child: cameraController.value.isStreaming
              ? Container(
                  color: Colors.black,
                )
              : Texture(
                  textureId: cameraController.value.textureId,
                ),
        )),
      ),
    );
  }
}
