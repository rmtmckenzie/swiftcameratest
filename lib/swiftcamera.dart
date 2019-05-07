import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class SwiftCameraValue {
  final bool isStreaming;
  final int textureId;
  final Size previewSize;

  const SwiftCameraValue({this.isStreaming, this.textureId, this.previewSize});

  const SwiftCameraValue.uninitialized() : this(isStreaming: false);

  SwiftCameraValue copyWith({bool isStreaming, int textureId, Size previewSize}) {
    return SwiftCameraValue(
      isStreaming: isStreaming ?? this.isStreaming,
      textureId: textureId ?? this.textureId,
      previewSize: previewSize ?? this.previewSize,
    );
  }

  @override
  String toString() {
    return '$runtimeType(isStreaming: $isStreaming, textureId: $textureId, previewSize: $previewSize)';
  }
}

class SwiftCameraController extends ValueNotifier<SwiftCameraValue> {
  static const MethodChannel _channel = const MethodChannel('swiftcamera');

  SwiftCameraController() : super(SwiftCameraValue.uninitialized());

  Future<void> startPreview() async {
    if (value.isStreaming) {
      throw "Preview has already been started.";
    }

    final Map<String, dynamic> reply = await _channel.invokeMapMethod<String, dynamic>('startPreview');

    final textureId = reply['textureId'];
    final width = reply['width'];
    final height = reply['height'];

    print("Started with texture $textureId, width $width, height $height");

    value = value.copyWith(
      isStreaming: true,
      textureId: textureId,
      previewSize: Size(width.toDouble(), height.toDouble()),
    );
  }

  Future<void> stopPreview() async {
    if (!value.isStreaming) {
      throw "Preview has not been started.";
    }

    await _channel.invokeMethod('stopPreview');
  }
}
