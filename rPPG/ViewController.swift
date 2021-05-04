//
//  ViewController.swift
//  rPPG
//
//  Created by Krisztián Vörös on 2021. 04. 29..
//

import AVFoundation
import UIKit
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, HeartRateDetectionModelDelegate {
    
    var measurements: Array<Int32> = [];
    let model = HeartRateDetectionModel();
    private var captureSession = AVCaptureSession()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var cameraInput: AVCaptureDeviceInput? = nil
    @IBOutlet weak var bpmValue: UILabel!
    private var cameraPos: AVCaptureDevice.Position = .front
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.startRecording()
    }
    
    @IBAction func cameraTypeChanged(_ sender: Any) {
        if let segmentController = sender as? UISegmentedControl {
            switch segmentController.selectedSegmentIndex {
            case 0:
                self.cameraPos = .front
                restartRecording()
            default:
                self.cameraPos = .back
                restartRecording()
            }
        }
    }
    
    @IBOutlet weak var imageView: UIImageView!
    
    
    @IBAction func startButtonPressed(_ sender: Any) {
        self.captureSession.startRunning()
    }
    
    @IBAction func stopButtonPressed(_ sender: Any) {
        if (self.measurements.count > 0) {
            self.restartRecording()
        }
        self.captureSession.stopRunning()
    }
    
    func restartRecording() {
        bpmValue.text = "-"
        self.measurements = []
        self.captureSession.stopRunning()
        self.captureSession.removeInput(cameraInput!)
        self.captureSession.removeOutput(videoDataOutput)
        self.startRecording()
        self.captureSession.startRunning()
    }
    
    func startRecording() {
        self.addCameraInput()
        self.getFrames()
        self.initializeDetection()
    }

    func initializeDetection() {
        model.initialize(self.captureSession);
        model.delegate = self;
    }
    
    private func addCameraInput() {
        guard let device = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera],
            mediaType: .video,
                position: self.cameraPos).devices.first else {
                fatalError("No back camera device found!")
        }
        device.activeVideoMinFrameDuration = CMTimeMake(value:1, timescale:30);
        device.activeVideoMaxFrameDuration = CMTimeMake(value:1, timescale:30);
        self.cameraInput = try! AVCaptureDeviceInput(device: device)
        self.captureSession.addInput(self.cameraInput!)
    }
 
    
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection) {
        guard let  imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags.readOnly)
        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Little.rawValue
        bitmapInfo |= CGImageAlphaInfo.premultipliedFirst.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
        let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
        guard let quartzImage = context?.makeImage() else { return }
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags.readOnly)
        let image = UIImage(cgImage: quartzImage)
        model.captureOutput(output, didOutputSampleBuffer: sampleBuffer, from: connection)
        
        
        DispatchQueue.main.async {
            self.process(image)
            self.imageView.image = image
        }
    }
    
    private func getFrames() {
        videoDataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_32BGRA)] as [String : Any]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.frame.processing.queue"))
        self.captureSession.addOutput(videoDataOutput)
        guard let connection = self.videoDataOutput.connection(with: AVMediaType.video),
            connection.isVideoOrientationSupported else { return }
        connection.videoOrientation = .portrait
    }
    
    func process(_ image: UIImage) {
       imageView.image = image
       guard let ciImage = CIImage(image: image) else {
           return
       }
       let request = VNDetectFaceRectanglesRequest { [unowned self] request, error in
           if let error = error {
            print(error)
           }
           else {
               self.handleFaces(with: request)
           }
       }
       let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
       do {
           try handler.perform([request])
       }
       catch {
       }
   }
    
    func handleFaces(with request: VNRequest) {
        imageView.layer.sublayers?.forEach { layer in
            layer.removeFromSuperlayer()
        }
        guard let observations = request.results as? [VNFaceObservation] else {
            return
        }
        observations.forEach { observation in
            let boundingBox = observation.boundingBox
            let size = CGSize(
                width: boundingBox.width * imageView.bounds.width * imageView.contentScaleFactor,
                                height: boundingBox.height * imageView.bounds.height * imageView.contentScaleFactor)
            let origin = CGPoint(x: boundingBox.minX * imageView.bounds.width,
                                y: (1 - observation.boundingBox.minY) * imageView.bounds.height - size.height)

            let layer = CAShapeLayer()
            layer.frame = CGRect(origin: origin, size: size)
            layer.borderColor = UIColor.red.cgColor
            layer.borderWidth = 2
            
            imageView.layer.addSublayer(layer)
        }
    }
    
    
    func heartRateUpdate(_ bpm: Int32, atTime seconds: Int32) {
        measurements.insert(bpm, at: measurements.endIndex)
        let sum = measurements.reduce(0, +)
        let avg = Int(sum)/measurements.count
        bpmValue.text = String(avg)
    }
    
    func stopDetection() {
        self.captureSession.stopRunning()
    }
    
}

