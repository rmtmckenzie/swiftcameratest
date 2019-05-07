import Flutter
import UIKit
import AVFoundation

extension FlutterError {
  convenience init(code: String, message: String?) {
    self.init(code: code, message: message, details: nil)
  }
}

public class SwiftSwiftCameraPlugin: NSObject, FlutterPlugin {

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "swiftcamera", binaryMessenger: registrar.messenger())
    let instance = SwiftSwiftCameraPlugin(registrar: registrar)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  let registrar: FlutterPluginRegistrar

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
  }

  var cameraHandler: CameraHandler?
  var textureId: Int64?

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    do{
      switch call.method {
      case "startPreview":
        cameraHandler = try CameraHandler(())
        textureId = registrar.textures().register(cameraHandler!)

        cameraHandler!.start()
        result(["textureId": textureId!, "width": cameraHandler!.previewDimensions.width, "height": cameraHandler!.previewDimensions.height])
        break
      case "stopPreview":
        cameraHandler?.stop()
        result()
        break;
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch CameraInitializeError.addingPreviewInputFailed {
      result(FlutterError(code: "INIT_ERROR", message: "Adding preview input failed"))
    } catch CameraInitializeError.addingPreviewConnectionFailed{
      result(FlutterError(code: "INIT_ERROR", message: "Adding preview connection failed"))
    } catch CameraInitializeError.addingPreviewOutputFailed {
      result(FlutterError(code: "INIT_ERROR", message: "Adding preview output failed"))
    } catch CameraInitializeError.cantOpenCamera(error: let error) {
      result(FlutterError(code: "INIT_ERROR", message: "Opening camera failed: \(error)"))
    } catch {
      result(FlutterError(code: "UNKNOWN_ERROR", message: "Unknown error: \(error)."))
    }
  }
}

enum CameraInitializeError: Error {
  case addingPreviewInputFailed
  case addingPreviewOutputFailed
  case addingPreviewConnectionFailed
  case cantOpenCamera(error: NSError)
}

class CameraHandler: NSObject {

  let session: AVCaptureSession
  let input: AVCaptureDeviceInput
  let previewOutput: AVCaptureVideoDataOutput
  let previewConnection: AVCaptureConnection
  let previewDimensions: CMVideoDimensions

  var buffer: CVImageBuffer?

  private init(session: AVCaptureSession, input: AVCaptureDeviceInput, previewOutput: AVCaptureVideoDataOutput, previewConnection: AVCaptureConnection, previewDimensions: CMVideoDimensions) {
    self.session = session
    self.input = input
    self.previewOutput = previewOutput
    self.previewConnection = previewConnection

    super.init()

    previewOutput.setSampleBufferDelegate(
      self,
      queue: DispatchQueue.main
    )
  }

  convenience init(_:Void) throws {
    let session = AVCaptureSession()

    let captureDevice: AVCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)!
    if(captureDevice.isFocusModeSupported(.continuousAutoFocus)) {
      try! captureDevice.lockForConfiguration()
      captureDevice.focusMode = .continuousAutoFocus
      captureDevice.unlockForConfiguration()
    }

    let input: AVCaptureDeviceInput
    do {
      input = try AVCaptureDeviceInput(device: captureDevice)
    } catch let e as NSError {
      throw CameraInitializeError.cantOpenCamera(error: e)
    }

    let previewOutput = AVCaptureVideoDataOutput()
    previewOutput.alwaysDiscardsLateVideoFrames = true
    previewOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String: NSNumber(value: kCVPixelFormatType_32BGRA)]

    guard session.canAddInput(input) else {
      throw CameraInitializeError.addingPreviewInputFailed
    }
    session.addInputWithNoConnections(input)

    guard session.canAddOutput(previewOutput) else {
      session.removeInput(input)
      throw CameraInitializeError.addingPreviewOutputFailed
    }
    session.addOutputWithNoConnections(previewOutput)

    let previewConnection = AVCaptureConnection(inputPorts: input.ports, output: previewOutput)
    previewConnection.videoOrientation = AVCaptureVideoOrientation.portrait
    guard session.canAddConnection(previewConnection) else {
      session.removeInput(input)
      session.removeOutput(previewOutput)
      throw CameraInitializeError.addingPreviewConnectionFailed
    }
    session.addConnection(previewConnection)

    if(session.canSetSessionPreset(AVCaptureSession.Preset.hd4K3840x2160)){
      print("Setting session preset to hd4k3840x2160")
      session.sessionPreset = AVCaptureSession.Preset.hd4K3840x2160
    }else if(session.canSetSessionPreset(AVCaptureSession.Preset.photo)){
      print("Setting session preset to photo")
      session.sessionPreset = AVCaptureSession.Preset.photo
    }else if(session.canSetSessionPreset(AVCaptureSession.Preset.high)){
      print("Setting session preset to high")
      session.sessionPreset = AVCaptureSession.Preset.high
    } else {
      print("Not setting session preset I guess")
    }

    let formatDescription = captureDevice.activeFormat.formatDescription
    let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)

    self.init(session: session, input: input, previewOutput: previewOutput, previewConnection: previewConnection, previewDimensions: dimensions)
  }

  deinit {
    session.removeInput(input)
    previewOutput.setSampleBufferDelegate(nil, queue: nil)
    session.removeOutput(previewOutput)
    session.removeConnection(previewConnection)
  }

  public func start() {
    session.startRunning()
  }

  public func stop() {
    session.stopRunning()
  }

}

extension CameraHandler: AVCaptureVideoDataOutputSampleBufferDelegate {

  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      //TODO: print error?
      print("Error getting image buffer from CMSamplebuffer.")
      return
    }
    buffer = imageBuffer
  }

  func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    print("Frame dropped!")
  }

}

extension CameraHandler: FlutterTexture {

  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    return buffer != nil ? Unmanaged<CVPixelBuffer>.passRetained(buffer!) : nil
  }

}
