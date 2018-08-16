//
//  ViewController.swift
//  Vision+CIImage
//
//  Created by Jack Wong on 2018/08/10.
//  Copyright © 2018 Jack Wong. All rights reserved.
//

import UIKit
import Vision
import Photos

final class ViewController: UIViewController {

    @IBOutlet weak var originalPhotoView: UIImageView!
    @IBOutlet weak var ciPhotoView: UIImageView!
    private let imagePicker = UIImagePickerController()
    private let blueView = UIView()
    private var pathLayer: CALayer?
    // Image parameters for reuse throughout app
    private var imageWidth: CGFloat = 0
    private var imageHeight: CGFloat = 0
    override func viewDidLoad() {
        super.viewDidLoad()
        ciPhotoView.image = nil
        imagePicker.delegate = self
    }
    
    @IBAction func getPhoto(_ sender: Any) {
        imagePicker.sourceType = .photoLibrary
        self.present(imagePicker, animated: true)
    }
    
    @IBAction func recognizePhoto(_ sender: Any) {
         setupVision()
    }
    
    private func setupVision() {
    
        guard let cgImage = originalPhotoView.image?.cgImage else { return }
        let request = VNDetectRectanglesRequest { (req, err) in
            if let err = err {
                print("failed to detect", err)
                return
            }
            print(req.results)
            req.results?.forEach({ res in
                guard let observation = res as? VNRectangleObservation else { return }
                print("bbb", observation.boundingBox, observation.boundingBox.minX, observation.boundingBox.width, observation.boundingBox.minY, observation.boundingBox.height)

                let ciImage = self.extractPerspectiveRect(observation, from: cgImage)
                let observedImage = self.convert(cmage: ciImage)
            
                DispatchQueue.main.async {
              
                    self.ciPhotoView.image = observedImage
                    guard let drawLayer = self.pathLayer,
                        let results = req.results as? [VNRectangleObservation] else {
                            return
                    }
                    self.draw(rectangles: results, onImageWithBounds: drawLayer.bounds)
                    drawLayer.setNeedsDisplay()
                    
                }
                
            })
        }
        request.maximumObservations = 8
        request.minimumConfidence = 0.1
        request.minimumAspectRatio = 0.3
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch let reqErr {
                print("request Error", reqErr)
            }

        }
    }
    func extractPerspectiveRect(_ observation: VNRectangleObservation, from cgImage: CGImage) -> CIImage {
        // get the pixel buffer into Core Image
        let ciImage = CIImage(cgImage: cgImage)
        
        // convert corners from normalized image coordinates to pixel coordinates
        let topLeft = observation.topLeft.scaled(to: ciImage.extent.size)
        let topRight = observation.topRight.scaled(to: ciImage.extent.size)
        let bottomLeft = observation.bottomLeft.scaled(to: ciImage.extent.size)
        let bottomRight = observation.bottomRight.scaled(to: ciImage.extent.size)
        print("bbbb", topLeft, topRight, bottomLeft, bottomRight)
        // pass those to the filter to extract/rectify the image
        return ciImage.applyingFilter("CIPerspectiveCorrection", parameters: [
            "inputTopLeft": CIVector(cgPoint: topLeft),
            "inputTopRight": CIVector(cgPoint: topRight),
            "inputBottomLeft": CIVector(cgPoint: bottomLeft),
            "inputBottomRight": CIVector(cgPoint: bottomRight),
            ]).applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0,
                kCIInputContrastKey: 32]).applyingFilter("CIColorInvert")
    }
    
    private func convert(cmage:CIImage) -> UIImage {
        let context:CIContext = CIContext.init(options: nil)
        let cgImage:CGImage = context.createCGImage(cmage, from: cmage.extent)!
        let image:UIImage = UIImage.init(cgImage: cgImage)
        return image
    }
    
}
extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        // Extract chosen image.
        if let originalImage: UIImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            show(image: originalImage)
        }
        dismiss(animated: true, completion: nil)
    }
}
// MARK: - HELPER METHOD
extension ViewController {
    /// - Tag: PreprocessImage
    private func scaleAndOrient(image: UIImage) -> UIImage {
        // Set a default value for limiting image size
        let maxResolution: CGFloat = 640
        guard let cgImage = image.cgImage else {
            print("UIImage has no CGImage backing it")
            return image
        }
        // Compute parameters ofr transform
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        var transform = CGAffineTransform.identity
        var bounds = CGRect(x: 0, y: 0, width: width, height: height)
        if width > maxResolution ||
            height > maxResolution {
            let ratio = width / height
            if width > height {
                bounds.size.width = maxResolution
                bounds.size.height = round(maxResolution / ratio)
            } else {
                bounds.size.width = round(maxResolution * ratio)
                bounds.size.height = maxResolution
            }
        }
        let scaleRatio = bounds.size.width / width
        let orientation = image.imageOrientation
        switch orientation {
        case .up:
            transform = .identity
        case .down:
            transform = CGAffineTransform(translationX: width, y: width).rotated(by: .pi)
        case .left:
            let boundsHeight = bounds.size.height
            bounds.size.height = bounds.size.width
            bounds.size.width = boundsHeight
            transform = CGAffineTransform(translationX: 0, y: width).rotated(by: 3.0 * .pi / 2.0)
        case .right:
            let boundsHeight = bounds.size.height
            bounds.size.height = bounds.size.width
            bounds.size.width = boundsHeight
            transform = CGAffineTransform(translationX: height, y: 0).rotated(by: .pi / 2.0)
        case .upMirrored:
            transform = CGAffineTransform(translationX: width, y: 0).scaledBy(x: -1, y: 1)
        case .downMirrored:
            transform = CGAffineTransform(translationX: 0, y: height).scaledBy(x: 1, y: -1)
        case .leftMirrored:
            let boundsHeight = bounds.size.height
            bounds.size.height = bounds.size.width
            bounds.size.width = boundsHeight
            transform = CGAffineTransform(translationX: height, y: width).scaledBy(x: -1, y: 1).rotated(by: 3.0 * .pi / 2.0)
        case .rightMirrored:
            let boundsHeight = bounds.size.height
            bounds.size.height = bounds.size.width
            bounds.size.width = boundsHeight
            transform = CGAffineTransform(scaleX: -1, y: 1).rotated(by: .pi / 2.0)
        }
        return UIGraphicsImageRenderer(size: bounds.size).image(actions: { rendererContext in
            let context = rendererContext.cgContext
            if orientation == .right || orientation == .left {
                context.scaleBy(x: -scaleRatio, y: scaleRatio)
                context.translateBy(x: -height, y: 0)
            } else {
                context.scaleBy(x: scaleRatio, y: -scaleRatio)
                context.translateBy(x: 0, y: -height)
            }
            context.concatenate(transform)
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        })
    }
    private func show(image: UIImage) {
        pathLayer?.removeFromSuperlayer()
        pathLayer = nil
        originalPhotoView.image = nil
        // Account for image orientation by transforming view
        let correctedImage = scaleAndOrient(image: image)
        originalPhotoView.image = correctedImage
        // Transform image to fit screen.
        guard let cgImage = correctedImage.cgImage else {
            print("Trying to show an image not backed by CGImage!")
            return
        }
        
        let fullImageWidth = CGFloat(cgImage.width)
        let fullImageHeight = CGFloat(cgImage.height)
        
        let imageFrame = originalPhotoView.frame
        let widthRatio = fullImageWidth / imageFrame.width
        let heightRatio = fullImageHeight / imageFrame.height
        
        // ScaleAspectFit: The image will be scaled down according to the stricter dimension.
        let scaleDownRatio = max(widthRatio, heightRatio)
        
        // Cache image dimensions to reference when drawing CALayer paths.
        imageWidth = fullImageWidth / scaleDownRatio
        imageHeight = fullImageHeight / scaleDownRatio
        
        // Prepare pathLayer to hold Vision results.
        let xLayer = (imageFrame.width - imageWidth) / 2
        let yLayer = originalPhotoView.frame.minY + (imageFrame.height - imageHeight) / 2
       
        let drawingLayer = CALayer()
        drawingLayer.bounds = CGRect(x: xLayer, y: yLayer, width: imageWidth, height: imageHeight)
        drawingLayer.anchorPoint = CGPoint.zero
        drawingLayer.position = CGPoint(x: xLayer, y: yLayer)
        drawingLayer.opacity = 0.5
        pathLayer = drawingLayer
        self.view.layer.addSublayer(pathLayer!)
    }
    
    // Rectangles are RED.
    private func draw(rectangles: [VNRectangleObservation], onImageWithBounds bounds: CGRect) {
        CATransaction.begin()
        for observation in rectangles {
            let rectBox = boundingBox(forRegionOfInterest: observation.boundingBox, withinImageBounds: bounds)
            let rectLayer = shapeLayer(color: .red, frame: rectBox)
            
            // Add to pathLayer on top of image.
            pathLayer?.addSublayer(rectLayer)
        }
        CATransaction.commit()
    }
    private func boundingBox(forRegionOfInterest: CGRect, withinImageBounds bounds: CGRect) -> CGRect {
        
        let imageWidth = bounds.width
        let imageHeight = bounds.height
        
        // Begin with input rect.
        var rect = forRegionOfInterest
        
        // Reposition origin.
        rect.origin.x *= imageWidth
        rect.origin.x += bounds.origin.x
        rect.origin.y = (1 - rect.origin.y) * imageHeight + bounds.origin.y
        
        // Rescale normalized coordinates.
        rect.size.width *= imageWidth
        rect.size.height *= imageHeight
        
        return rect
    }
    private func shapeLayer(color: UIColor, frame: CGRect) -> CAShapeLayer {
        // Create a new layer.
        let layer = CAShapeLayer()
        
        // Configure layer's appearance.
        layer.fillColor = nil // No fill to show boxed object
        layer.shadowOpacity = 0
        layer.shadowRadius = 0
        layer.borderWidth = 2
        
        // Vary the line color according to input.
        layer.borderColor = color.cgColor
        
        // Locate the layer.
        layer.anchorPoint = .zero
        layer.frame = frame
        layer.masksToBounds = true
        
        // Transform the layer to have same coordinate system as the imageView underneath it.
        layer.transform = CATransform3DMakeScale(1, -1, 1)
        
        return layer
    }
}
extension CGPoint {
    func scaled(to size: CGSize) -> CGPoint {
        return CGPoint(x: self.x * size.width,
                       y: self.y * size.height)
    }
}
