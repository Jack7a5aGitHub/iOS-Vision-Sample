//
//  ViewController.swift
//  Vision+CIImage
//
//  Created by Jack Wong on 2018/08/10.
//  Copyright © 2018 Jack Wong. All rights reserved.
//

import UIKit
import Vision

final class ViewController: UIViewController {

    @IBOutlet weak var originalPhotoView: UIImageView!
    @IBOutlet weak var ciPhotoView: UIImageView!
    var image = #imageLiteral(resourceName: "IMG_7224")
    // Layer into which to draw bounding box paths.
    var pathLayer: CALayer?
    // Image parameters for reuse throughout app
    var imageWidth: CGFloat = 0
    var imageHeight: CGFloat = 0
   // var request = [VNRequest]
    override func viewDidLoad() {
        super.viewDidLoad()
        ciPhotoView.image = nil
        setupImage()
        setupVision()
    }
    
    private func setupImage() {

        originalPhotoView.image = image
        pathLayer?.removeFromSuperlayer()
        pathLayer = nil
        let fullImageWidth = CGFloat((image.cgImage?.width)!)
        let fullImageHeight = CGFloat((image.cgImage?.height)!)
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
    
    private func setupVision() {
        //let request = VNDetectRectanglesRequest(completionHandler: self.handleDetectedRectangle)
        let request = VNDetectRectanglesRequest { (req, err) in
            if let err = err {
                print("failed to detect", err)
                return
            }
            print(req.results)
            req.results?.forEach({ res in
                guard let observation = res as? VNRectangleObservation else { return }
                print("bbb", observation.boundingBox)

               let ciImage = self.extractPerspectiveRect(observation, from: self.image.cgImage!)
                let observedImage = self.convert(cmage: ciImage)
                DispatchQueue.main.async {
                    self.ciPhotoView.image = observedImage
                }
            })
        }
//        request.maximumObservations = 8
//        request.minimumConfidence = 0.6
//        request.minimumAspectRatio = 0.3
        
        guard let cgImage = image.cgImage else { return }
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
        
        // pass those to the filter to extract/rectify the image
        return ciImage.applyingFilter("CIPerspectiveCorrection", parameters: [
            "inputTopLeft": CIVector(cgPoint: topLeft),
            "inputTopRight": CIVector(cgPoint: topRight),
            "inputBottomLeft": CIVector(cgPoint: bottomLeft),
            "inputBottomRight": CIVector(cgPoint: bottomRight),
            ])
    }
    
    private func convert(cmage:CIImage) -> UIImage {
        let context:CIContext = CIContext.init(options: nil)
        let cgImage:CGImage = context.createCGImage(cmage, from: cmage.extent)!
        let image:UIImage = UIImage.init(cgImage: cgImage)
        return image
    }
    private func handleDetectedRectangle(request: VNRequest?, error: Error?) {
        if let nsError = error as NSError? {
            print("failed to detect", nsError)
            return
        }
        // Since handlers are executing on a background thread, explicitly send draw calls to the main thread.
        DispatchQueue.main.async {
            guard let drawLayer = self.pathLayer,
                let results = request?.results as? [VNRectangleObservation] else {
                    return
            }
            self.draw(rectangles: results, onImageWithBounds: drawLayer.bounds)
            drawLayer.setNeedsDisplay()
        }
    }
    
    // MARK: - Path-Drawing
    
    fileprivate func boundingBox(forRegionOfInterest: CGRect, withinImageBounds bounds: CGRect) -> CGRect {
        
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
    
    fileprivate func shapeLayer(color: UIColor, frame: CGRect) -> CAShapeLayer {
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
    
    // Rectangles are BLUE.
    fileprivate func draw(rectangles: [VNRectangleObservation], onImageWithBounds bounds: CGRect) {
        CATransaction.begin()
        for observation in rectangles {
            let rectBox = boundingBox(forRegionOfInterest: observation.boundingBox, withinImageBounds: bounds)
            let rectLayer = shapeLayer(color: .blue, frame: rectBox)
            
            // Add to pathLayer on top of image.
            pathLayer?.addSublayer(rectLayer)
        }
        CATransaction.commit()
    }
}
extension CGPoint {
    func scaled(to size: CGSize) -> CGPoint {
        return CGPoint(x: self.x * size.width,
                       y: self.y * size.height)
    }
}
