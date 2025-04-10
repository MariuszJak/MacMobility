//
//  QRCodeScanner.swift
//  MagicTrackpad
//
//  Created by Mariusz Jakowienko on 08/11/2023.
//

import Foundation
import SwiftUI
import os
import AVFoundation

struct QRCodeScannerView: View {
    var completion: (String) -> Void
    
    var body: some View {
        // Create a QR code scanner view
        QRCodeScanner(completion: completion)
    }
}

struct QRCodeScanner: UIViewControllerRepresentable {
    var completion: (String) -> Void
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<QRCodeScanner>) -> UIViewController {
        // Create a QR code scanner
        let scannerViewController = QRCodeScannerViewController(completion: completion)
        return scannerViewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: UIViewControllerRepresentableContext<QRCodeScanner>) {
        // Update the view controller
    }
}

class QRCodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    let spinner = UIActivityIndicatorView(style: .medium)
    let captureSession = AVCaptureSession()
    lazy var videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    var completion: (String) -> Void
    
    public init(completion: @escaping (String) -> Void) {
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Force vertical orientation (portrait)
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        UIViewController.attemptRotationToDeviceOrientation()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Force horizontal orientation (landscapeRight as an example)
        UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
        UIViewController.attemptRotationToDeviceOrientation()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        view.addSubview(spinner)
        
        // Center it in the view
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        spinner.startAnimating()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            guard let captureDevice = AVCaptureDevice.default(for: AVMediaType.video) else { return }
            guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
            self.captureSession.addInput(input)
            
            let captureMetadataOutput = AVCaptureMetadataOutput()
            self.captureSession.addOutput(captureMetadataOutput)
            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
            
            self.videoPreviewLayer.frame = self.view.layer.bounds
            self.view.layer.addSublayer(self.videoPreviewLayer)
            DispatchQueue.global(qos: .background).async {
                self.captureSession.startRunning()
            }
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if metadataObjects.count == 0 {
            return
        }
        
        guard let metadataObj = metadataObjects[0] as? AVMetadataMachineReadableCodeObject else {
            return
        }
        
        if metadataObj.type == AVMetadataObject.ObjectType.qr,
           let urlString = metadataObj.stringValue {
            completion(urlString)
            captureSession.stopRunning()
        }
    }
}
