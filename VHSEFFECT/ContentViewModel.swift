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

class ContentViewModel: NSObject, ObservableObject ,UIDocumentPickerDelegate{
    @Published var showVideoPicker = false
    @Published var saved = false
    @Published var showImagePicker = false
    @Published var videoURL: URL?
    @Published var player: AVPlayer?
    @Published var showLoading: Bool =  false
    @Published var selectedImage: UIImage?

    private var compostion : AVMutableVideoComposition? = nil
    func pickVideo() {
        showVideoPicker = true
    }

    func pickImage() {
        showImagePicker = true
    }

    func pickedVideo(_ url: URL) {
        videoURL = url
        player = nil
        compostion = applyVHSVideoEffect(with: url)
        player = createPlayer(with: url , composition: compostion)
        selectedImage = nil // Clear the selected image when a video is picked
    }
    
    func pickedImage(_ image: UIImage) {
        videoURL = nil
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
    func savedSuccessfully(){
        self.saved = true

           DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
               self.saved = false
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

    
    private func applyVHSVideoEffect(with url: URL) -> AVMutableVideoComposition {
        print("createPlayer")
        let asset = AVAsset(url: url)
        
        let composition = AVMutableVideoComposition(asset: asset) { [self] request in
            let source = request.sourceImage
            request.finish(with: applyVHSFilter(source: source), context: nil)
        }
        
//        // Set the render size and frame duration
//        composition.renderSize = CGSize(width: 360, height: 270)
//        composition.frameDuration = CMTime(value: 1, timescale: 30) // 30 fps
        
//        let playerItem = AVPlayerItem(asset: asset)
//        playerItem.videoComposition = composition
        return composition
    }
    private func createPlayer(with url: URL, composition: AVMutableVideoComposition? = nil) -> AVPlayer? {
        let asset = AVAsset(url: url)
        
        
        composition.mLet{ composition in
            
            composition.renderSize = CGSize(width: 360, height: 270)
            composition.frameDuration = CMTime(value: 1, timescale: 30) // 30 fps
           
        }
        
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.videoComposition = composition
        
        return AVPlayer(playerItem: playerItem)
    }
    
     func saveVideo(){
        if let videoURL = videoURL , let composition = compostion{
            showLoading = true
            Task {
                // Attempt to save modified video asynchronously
                guard let url = await self.saveModifiedVideo(with: videoURL, composition: composition) else {
                    // If URL is nil, hide the loading indicator and return
                    showLoading = false
                    return
                }
                
                // Hide the loading indicator after the operation is completed
                showLoading = false
                print("URL -> ", url)
                
                // Ensure UI update happens on the main thread
                await MainActor.run {
                    self.saveFile(with: url)
                }
            }
          
        }
        
    }
    private func saveModifiedVideo(with url: URL, composition: AVMutableVideoComposition) async -> URL?  {
        let asset = AVAsset(url: url)
        let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)
        
        // Set the export session's output URL and file type
        let fileManager = FileManager.default
        let outputURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        
        exportSession?.outputURL = outputURL
        exportSession?.outputFileType = .mp4
        
        // Apply the video composition
        exportSession?.videoComposition = composition
        return await withCheckedContinuation { (continuation: CheckedContinuation<URL?, Never>) in
            exportSession?.exportAsynchronously {
                switch exportSession?.status {
                case .completed:
                    continuation.resume(returning: outputURL)
                case .failed , .cancelled:
                    continuation.resume(returning: nil)
                default:
                    break
                }
            }
        }
       
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
             guard let selectedURL = urls.first else {
                 print("No destination URL selected")
                 return
             }
             savedSuccessfully()
             print("File saved successfully to: \(selectedURL.path)")
             // You can add any additional logic here, such as updating UI or model
         }
    
    func saveImage(){
        
        if let selectedImage = selectedImage{
            guard let url = saveImageAndGetURL(with: selectedImage) else { return  }
            saveFile(with: url)
        }

    }
    
    func saveImageAndGetURL(with image: UIImage) -> URL? {
        
        // Get the temporary directory URL
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
        let fileName = UUID().uuidString + ".png"
        let temporaryFileURL = temporaryDirectoryURL.appendingPathComponent(fileName)
        
        // Convert the UIImage to PNG or JPEG data
        if let imageData = image.pngData() { // Or image.jpegData(compressionQuality: 1.0) for JPEG
            do {
                // Write the image data to the file system
                try imageData.write(to: temporaryFileURL)
                return temporaryFileURL
            } catch {
                print("Error saving file: \(error)")
            }
        }
        return nil
    }
    func saveFile(with sourceURL:URL) {
           

        print("NAME -> ",sourceURL.lastPathComponent)
            // Create a temporary directory to store the file
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
        let temporaryFileURL = temporaryDirectoryURL.appendingPathComponent("SS"+sourceURL.lastPathComponent)

            do {
                // If a file already exists at the temporary location, remove it
                if FileManager.default.fileExists(atPath: temporaryFileURL.path) {
                    try FileManager.default.removeItem(at: temporaryFileURL)
                }

                // Copy the processed audio to the temporary location
                try FileManager.default.copyItem(at: sourceURL, to: temporaryFileURL)

                // Create a document picker to allow the user to choose where to save the file
                let documentPicker = UIDocumentPickerViewController(forExporting: [sourceURL], asCopy: true)
                documentPicker.delegate = self
                documentPicker.shouldShowFileExtensions = true

                // Present the document picker
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootViewController = window.rootViewController {
                    rootViewController.present(documentPicker, animated: true, completion: nil)
                }
            } catch {
                print("Error preparing file for saving: \(error.localizedDescription)")
            }
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
extension Optional {
    func mLet(_ block: (Wrapped) -> Void) {
        if let value = self {
            block(value)
        }
    }
}
