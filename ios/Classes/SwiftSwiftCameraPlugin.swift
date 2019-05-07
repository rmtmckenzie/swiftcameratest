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

  unowned let registrar: FlutterPluginRegistrar

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
  }

  var cameraHandler: CameraHandler?
  var textureId: Int64?

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
      switch call.method {
      case "startPreview":
        
        DispatchQueue.global(qos: .userInteractive).async {
          do{
            self.cameraHandler = try CameraHandler(())
            unowned let textureRegistry = self.registrar.textures()
            let textureId = textureRegistry.register(self.cameraHandler!)
            self.textureId = textureId
            
            self.cameraHandler!.frameReady = { () in
              textureRegistry.textureFrameAvailable(textureId)
            }
            
            self.cameraHandler!.start()
            
            DispatchQueue.main.async {
              result(["textureId": textureId, "width": self.cameraHandler!.previewDimensions.width, "height": self.cameraHandler!.previewDimensions.height])
            }
          } catch let error as CameraInitializeError {
            switch error {
            case .addingPreviewInputFailed:
              result(FlutterError(code: "INIT_ERROR", message: "Adding preview input failed"))
              break
            case .addingPreviewConnectionFailed:
              result(FlutterError(code: "INIT_ERROR", message: "Adding preview connection failed"))
              break
            case .addingPreviewOutputFailed:
              result(FlutterError(code: "INIT_ERROR", message: "Adding preview output failed"))
              break
            case .cantOpenCamera(error: let nserr):
              result(FlutterError(code: "INIT_ERROR", message: "Opening camera failed: \(nserr)"))
              break
            }
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(code: "UNKNOWN_ERROR", message: "Unknown error: \(error)."))
            }
          }
        }
        break
      case "stopPreview":
        cameraHandler?.stop()
        cameraHandler?.frameReady = nil
        cameraHandler = nil
        result(nil)
        break;
      default:
        result(FlutterMethodNotImplemented)
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
  let queue = DispatchQueue(label: "cameraqueue", qos: .userInteractive)

  var buffer: CVImageBuffer?
  var frameReady: (() -> ())?

  private init(session: AVCaptureSession, input: AVCaptureDeviceInput, previewOutput: AVCaptureVideoDataOutput, previewConnection: AVCaptureConnection, previewDimensions: CMVideoDimensions) {
    self.session = session
    self.input = input
    self.previewOutput = previewOutput
    self.previewConnection = previewConnection
    self.previewDimensions = previewDimensions

    super.init()

    previewOutput.setSampleBufferDelegate(
      self,
      queue: queue
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
    session.inputs.forEach { (input) in
      session.removeInput(input)
    }
    
    session.outputs.forEach { (output) in
      session.removeOutput(output)
    }

    previewOutput.setSampleBufferDelegate(nil, queue: nil)
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
    print("Frame received.")
    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      //TODO: print error?
      print("Error getting image buffer from CMSamplebuffer.")
      return
    }
    buffer = imageBuffer
    frameReady?()
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
