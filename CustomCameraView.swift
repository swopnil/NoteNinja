import SwiftUI
import AVFoundation

struct CustomCameraView: View {
    
    let cameraService = CameraSevice()
    @Binding var capturedImage: UIImage?
    
    @Environment(\.presentationMode) private var presentationMode
    
    @State private var isCapturing = false
    private let speechSynthesizer = AVSpeechSynthesizer()
    @State private var spokenText: String = ""
    
    init(capturedImage: Binding<UIImage?>) {
        self._capturedImage = capturedImage
        
        let initialMessage = "Double tap to click picture"
        let speechUtterance = AVSpeechUtterance(string: initialMessage)
        speechUtterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speechUtterance.volume = 1.0
        speechUtterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        
        // Speak the initial message and update spokenText
        speechSynthesizer.speak(speechUtterance)
        self._spokenText = State(initialValue: initialMessage)
    }
    
    var body: some View {
        ZStack {
            CameraView(cameraService: cameraService) { result in
                switch result {
                case .success(let photo):
                    if let data = photo.fileDataRepresentation() {
                        capturedImage = UIImage(data: data)
                        presentationMode.wrappedValue.dismiss()
                        
                        // Send the image to the Python API
                        if let image = capturedImage {
                            sendImageToAPI(image)
                        }
                    } else {
                        print("Error: no image data found")
                    }
                case .failure(let err):
                    print(err.localizedDescription)
                }
            }
            
            VStack {
                Spacer()
                
                // Display the spoken text
                Text(spokenText)
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(6))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .padding()
                
                Spacer()
                
                Button(action: {
                    cameraService.capturePhoto()
                }, label: {
                    Image(systemName: "circle")
                        .font(.system(size: 72))
                        .foregroundColor(.white)
                })
                .padding(.bottom)
            }
        }
        .onTapGesture(count: 2) {
            // Double tap detected
            if !isCapturing {
                isCapturing = true
                cameraService.capturePhoto()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    isCapturing = false
                }
            }
        }
    }
    
    
    func sendImageToAPI(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 1.0) else {
            print("Error converting image to data")
            return
        }
        
        let url = URL(string: "http://10.130.17.143:4555/upload")!
        var request = URLRequest(url: url)
        let boundary = UUID().uuidString
        
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let httpBody = NSMutableData()
        
        httpBody.append("--\(boundary)\r\n".data(using: .utf8)!)
        httpBody.append("Content-Disposition: form-data; name=\"file\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        httpBody.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        httpBody.append(imageData)
        httpBody.append("\r\n".data(using: .utf8)!)
        httpBody.append("--\(boundary)--".data(using: .utf8)!)

        request.httpBody = httpBody as Data
        
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("Error sending image to API: \(error)")
                return
            }
            
            if let data = data {
                do {
                    // Parse the JSON response
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        // Get the "folder" value from the JSON response
                        if let folder = json["folder"] as? String {
                            // Extract the last part of the folder path
                            let components = folder.components(separatedBy: "/")
                            if let lastComponent = components.last {
                                // Split the last component by space and get the last part
                                let folderNameComponents = lastComponent.components(separatedBy: " ")
                                if let lastNumber = folderNameComponents.last {
                                    // Display and pronounce the last number
                                    DispatchQueue.main.async {
                                        self.spokenText = lastNumber
                                    }
                                    Text(lastNumber)
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.black.opacity(0.5))
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                        .padding()
                                    // Speak the last number
                                    
                                    let speechUtterance = AVSpeechUtterance(string: lastNumber)
                                    speechUtterance.rate = AVSpeechUtteranceDefaultSpeechRate
                                    speechUtterance.volume = 1.0
                                    speechUtterance.voice = AVSpeechSynthesisVoice(language: "en-US")
                                    speechSynthesizer.speak(speechUtterance)
                                }
                            }
                        }
                    }
                } catch {
                    print("Error parsing JSON: \(error)")
                }
            }
        }.resume()
    }

}
