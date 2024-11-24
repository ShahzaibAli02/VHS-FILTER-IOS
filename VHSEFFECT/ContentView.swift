import SwiftUI
import AVKit
import UniformTypeIdentifiers
import CoreImage
import CoreImage.CIFilterBuiltins

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    
    var body: some View {
        VStack {
            if viewModel.saved {
                       Text("Saved successfully!")
                           .padding()
                           .background(Color.green)
                           .cornerRadius(8)
                           .foregroundColor(.white)
                           .transition(.opacity) // Smooth fade in/out
                   }
            HStack {
                Spacer()
                Button(action: {
                    viewModel.pickVideo()
                }) {
                    HStack {
                        Image(systemName: "video.fill")
                        Text("Pick Video")
                    }
                }
                .sheet(isPresented: $viewModel.showVideoPicker) {
                    VideoPicker(viewModel: viewModel)
                }
                Spacer()
                
                Button(action: {
                    viewModel.pickImage()
                }) {
                    HStack {
                        Image(systemName: "photo.fill")
                        Text("Pick Image")
                    }
                }
                .sheet(isPresented: $viewModel.showImagePicker) {
                    ImagePicker(viewModel: viewModel)
                }
                Spacer()
            }
            
            if let player = viewModel.player {
                VideoPlayer(player: player)
                    .frame(height: 300)
                    .onAppear {
                        player.play()
                    }
            } else if let image = viewModel.selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 300)
            }
            
            
            if viewModel.selectedImage != nil || viewModel.videoURL != nil{
                Button(action: {
                    
                    if viewModel.selectedImage != nil {
                        viewModel.saveImage()
                    }
                    else {
                        viewModel.saveVideo()
                    }
                   
                }) {
                    HStack (alignment: .center){
                        Image(systemName: "square.and.arrow.down")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                        Text("Save")
                    }
                }
            }
           
        }
        .sheet(isPresented: $viewModel.showLoading) {
            ZStack {
                // Transparent background
                Color.black.opacity(0.5).edgesIgnoringSafeArea(.all)
                
                // Centered circular progress view
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(2) // You can adjust the size here
                    .padding(40)    // Optional: padding for better spacing
            }
        }
        .padding()
    }
}


