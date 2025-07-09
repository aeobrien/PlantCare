import SwiftUI
import PhotosUI

struct AIPlantQuestionView: View {
    let plant: Plant
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    @State private var question = ""
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var aiResponse: AIPlantQuestionResponse?
    @State private var showingReview = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var showingPhotoPreview = false
    
    @FocusState private var isQuestionFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        PlantInfoCard(plant: plant, room: dataStore.roomForPlant(plant))
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ask about \(plant.name)")
                                .font(.headline)
                            
                            TextEditor(text: $question)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .focused($isQuestionFocused)
                            
                            // Photo picker section
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                        HStack {
                                            Image(systemName: "camera")
                                            Text("Add Photo")
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedPhotoData != nil {
                                        Button("Remove Photo") {
                                            selectedPhoto = nil
                                            selectedPhotoData = nil
                                        }
                                        .font(.caption)
                                        .foregroundColor(.red)
                                    }
                                }
                                
                                if let photoData = selectedPhotoData, let uiImage = UIImage(data: photoData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxHeight: 200)
                                        .cornerRadius(8)
                                        .onTapGesture {
                                            showingPhotoPreview = true
                                        }
                                }
                            }
                            
                            Text("Examples: Is this plant getting enough light? Should I adjust the watering schedule? Is the room humidity appropriate? You can include a photo to help with visual analysis.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let response = aiResponse {
                            VStack(alignment: .leading, spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "bubble.left.fill")
                                            .foregroundColor(.blue)
                                        Text("AI Response")
                                            .font(.headline)
                                    }
                                    
                                    Text(response.answer)
                                        .font(.body)
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                }
                                
                                if response.suggestedChanges != nil {
                                    Button(action: {
                                        showingReview = true
                                    }) {
                                        HStack {
                                            Image(systemName: "wand.and.stars")
                                            Text("Review Suggested Changes")
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
                
                if !isLoading && aiResponse == nil {
                    VStack {
                        Divider()
                        
                        Button(action: askQuestion) {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("Ask AI")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(question.isEmpty ? Color(.systemGray5) : Color.blue)
                            .foregroundColor(question.isEmpty ? Color(.systemGray) : .white)
                            .cornerRadius(8)
                        }
                        .disabled(question.isEmpty || isLoading)
                        .padding()
                    }
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle("Ask AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                if aiResponse != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("New Question") {
                            resetForNewQuestion()
                        }
                    }
                }
            }
            .overlay {
                if isLoading {
                    LoadingView()
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingReview) {
                if let response = aiResponse, let changes = response.suggestedChanges {
                    PlantChangeReviewView(
                        plant: plant,
                        suggestedChanges: changes,
                        onApprove: { updatedPlant in
                            dataStore.updatePlant(updatedPlant)
                            dismiss()
                        }
                    )
                }
            }
            .onAppear {
                isQuestionFocused = true
            }
            .onChange(of: selectedPhoto) { _, newPhoto in
                Task {
                    if let newPhoto = newPhoto {
                        do {
                            if let data = try await newPhoto.loadTransferable(type: Data.self) {
                                selectedPhotoData = data
                            }
                        } catch {
                            print("Error loading photo: \(error)")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingPhotoPreview) {
                if let photoData = selectedPhotoData, let uiImage = UIImage(data: photoData) {
                    PhotoPreviewView(image: uiImage)
                }
            }
        }
    }
    
    func askQuestion() {
        isLoading = true
        isQuestionFocused = false
        
        Task {
            do {
                let apiKey = dataStore.settings.openAIAPIKey
                guard !apiKey.isEmpty else {
                    throw APIError.openAIError("OpenAI API key not configured")
                }
                
                let response = try await OpenAIService.shared.askPlantQuestion(
                    question: question,
                    plant: plant,
                    rooms: dataStore.rooms,
                    photoData: selectedPhotoData,
                    apiKey: apiKey
                )
                
                await MainActor.run {
                    self.aiResponse = response
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    func resetForNewQuestion() {
        question = ""
        aiResponse = nil
        selectedPhoto = nil
        selectedPhotoData = nil
        isQuestionFocused = true
    }
}

struct PlantInfoCard: View {
    let plant: Plant
    let room: Room?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plant.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    if let room = room {
                        Text("Currently in \(room.name)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "leaf.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            }
            
            HStack(spacing: 16) {
                Label(plant.lightType.rawValue, systemImage: plant.lightIcon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let humidity = plant.humidityPreference {
                    Label(humidity.rawValue + " humidity", systemImage: "humidity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Asking AI...")
                    .font(.headline)
            }
            .padding(32)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 10)
        }
    }
}

struct PhotoPreviewView: View {
    let image: UIImage
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZoomableImageView(image: image)
                .navigationTitle("Photo Preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        scrollView.addSubview(imageView)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
        
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        let parent: ZoomableImageView
        
        init(_ parent: ZoomableImageView) {
            self.parent = parent
        }
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return scrollView.subviews.first
        }
    }
}

extension Plant {
    var lightIcon: String {
        switch lightType {
        case .direct:
            return "sun.max.fill"
        case .indirect:
            return "sun.max"
        case .low:
            return "moon"
        }
    }
}

#Preview {
    AIPlantQuestionView(plant: DataStore.shared.plants.first!)
        .environmentObject(DataStore.shared)
}