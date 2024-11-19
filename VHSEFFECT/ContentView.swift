import SwiftUI
import AVKit
import UniformTypeIdentifiers
import CoreImage
import CoreImage.CIFilterBuiltins

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    
    var body: some View {
        VStack {
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
        }
        .padding()
    }
}


