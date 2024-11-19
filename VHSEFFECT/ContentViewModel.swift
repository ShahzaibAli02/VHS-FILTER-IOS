//
//  ContentViewModel.swift
//  VHSEFFECT
//
//  Created by Shahzaib Ali on 19/11/2024.
//

import SwiftUI
import AVKit
import UniformTypeIdentifiers
import CoreImage
import CoreImage.CIFilterBuiltins

class ContentViewModel: ObservableObject {
    @Published var showVideoPicker = false
    @Published var showImagePicker = false
    @Published var videoURL: URL?
    @Published var player: AVPlayer?
    @Published var selectedImage: UIImage?

    func pickVideo() {
        showVideoPicker = true
    }

    func pickImage() {
        showImagePicker = true
    }

    func pickedVideo(_ url: URL) {
        videoURL = url
        player = createPlayer(with: url)
        selectedImage = nil // Clear the selected image when a video is picked
    }
    
    func pickedImage(_ image: UIImage) {
        
        if  let ciImage = CIImage(image: image) {
            let ciImageOutput =  applyVHSFilter(source:ciImage,shouldCrop: false)
            let context = CIContext(options: nil)
            guard let cgImage = context.createCGImage(ciImageOutput, from: ciImageOutput.extent) else {
                return
            }
    
            selectedImage = UIImage(cgImage: cgImage)
            player = nil // Clear the player when an image is picked
        }
      
    }
    func applyVHSFilter(source : CIImage, shouldCrop : Bool = true) -> CIImage {
        // Crop to 4:3 aspect ratio
        let cropHeight = source.extent.width * 3 / 4
        let cropY = max((source.extent.height - cropHeight) / 2, 0) // Ensure cropY is not negative
        let cropRect = CGRect(x: 0, y: cropY, width: source.extent.width, height: min(cropHeight, source.extent.height - cropY))

        let croppedImage = source.cropped(to: cropRect)
        
      
        // Resize to 360x270 resolution
        let resizedImage = (shouldCrop ? croppedImage : source ).transformed(by: CGAffineTransform(scaleX: 360 / cropRect.width, y: 270 / cropRect.height))
           
        print("Source Size: \(source.extent.size)")
        print("Cropped Size: \(croppedImage.extent.size)")
        print("Resized Size: \(resizedImage.extent.size)")
      
        // Lower color saturation
        let colorAdjusted = resizedImage.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.5
        ])
        
        // Apply color matrix to reduce green
        let colorMatrix = colorAdjusted.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0.93, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 1, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ])
        
        // Apply directional sharpening
        let sharpened = colorMatrix.applyingFilter("CIConvolution3X3", parameters: [
            "inputWeights": CIVector(values: [
                0, -0.5, 0,
                -0.5, 2.9, -0.5,
                0, -0.5, 0
            ], count: 9),
            "inputBias": 0
        ])
        
        // Add text overlays
        return  self.addTextOverlay(to: sharpened)
    }

    private func createPlayer(with url: URL) -> AVPlayer? {
        print("createPlayer")
        let asset = AVAsset(url: url)
        
        let composition = AVMutableVideoComposition(asset: asset) { [self] request in
            let source = request.sourceImage
            
    
            
            // Finish the request with the processed image
            request.finish(with: applyVHSFilter(source: source), context: nil)
        }
        
        // Set the render size and frame duration
        composition.renderSize = CGSize(width: 360, height: 270)
        composition.frameDuration = CMTime(value: 1, timescale: 30) // 30 fps
        
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.videoComposition = composition
        
        return AVPlayer(playerItem: playerItem)
    }

    private func addTextOverlay(to image: CIImage) -> CIImage {
        let renderSize = CGSize(width: image.extent.width, height: image.extent.height)
        
        // Create a graphics context
        UIGraphicsBeginImageContext(renderSize)
        
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return image
        }
        
        // Draw the video frame
        UIImage(ciImage: image).draw(in: CGRect(origin: .zero, size: renderSize))
        
        // Create and configure text layers
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 15),
            .foregroundColor: UIColor(white: 1, alpha: 0.7)
        ]
        
//        let playingText = NSAttributedString(string: "Playing", attributes: textAttributes)
//        playingText.draw(at: CGPoint(x: 10, y: 10)) // Positioning the text

        // Add date/time text
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateTimeString = dateFormatter.string(from: Date())
        let dateTimeAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor(white: 1, alpha: 0.7)
        ]
        
        let dateTimeText = NSAttributedString(string: dateTimeString, attributes: dateTimeAttributes)
        dateTimeText.draw(at: CGPoint(x: 10, y: renderSize.height - 30)) // Positioning the date/time text

        // Retrieve the composited image
        let compositedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        // Return the CIImage from the composited UIImage
        return CIImage(image: compositedImage!) ?? image
    }
}
