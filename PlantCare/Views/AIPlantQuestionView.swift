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
    @State private var selectedTimelinePhotoID: UUID?
    @State private var showingPhotoPreview = false
    @State private var conversationMessages: [ConversationMessage] = []
    @State private var pendingResponse: AIPlantQuestionResponse?
    
    @FocusState private var isQuestionFocused: Bool
    
    var plantPhotos: [PlantPhoto] {
        dataStore.photos(for: plant.id).prefix(5).map { $0 }
    }
    
    var selectedTimelinePhotoData: Data? {
        guard let photoID = selectedTimelinePhotoID,
              let photo = plantPhotos.first(where: { $0.id == photoID }),
              let url = photo.imageURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return data
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Plant info header
                PlantInfoCard(plant: plant, room: dataStore.roomForPlant(plant))
                    .padding()
                
                // Chat messages
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            // Initial prompt if no messages
                            if conversationMessages.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "bubble.left.and.bubble.right")
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary)
                                    
                                    Text("Ask me anything about \(plant.name)")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    
                                    Text("You can ask about care, health, placement, or any concerns. Include a photo for visual analysis.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                            }
                            
                            // Show conversation history
                            ForEach(conversationMessages, id: \.timestamp) { message in
                                ConversationBubble(message: message)
                                    .id(message.timestamp)
                            }
                            
                            // Show pending response if available
                            if let response = pendingResponse {
                                VStack(alignment: .leading, spacing: 16) {
                                    ConversationBubble(message: ConversationMessage(
                                        role: "assistant",
                                        content: response.answer,
                                        timestamp: Date()
                                    ))
                                    
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
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            
                            // Loading indicator
                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("AI is thinking...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }
                        }
                        .padding()
                    }
                    .onChange(of: conversationMessages.count) { _, _ in
                        withAnimation {
                            proxy.scrollTo(conversationMessages.last?.timestamp, anchor: .bottom)
                        }
                    }
                }
                
                // Message input area
                VStack(spacing: 0) {
                    Divider()
                    
                    // Photo selection area (only show for first message)
                    if conversationMessages.isEmpty {
                        VStack(spacing: 8) {
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
                                
                                if selectedPhotoData != nil || selectedTimelinePhotoID != nil {
                                    Button("Remove") {
                                        selectedPhoto = nil
                                        selectedPhotoData = nil
                                        selectedTimelinePhotoID = nil
                                    }
                                    .font(.caption)
                                    .foregroundColor(.red)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                            
                            // Show recent photos from timeline
                            if !plantPhotos.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(plantPhotos) { photo in
                                            TimelinePhotoThumbnail(
                                                photo: photo,
                                                isSelected: selectedTimelinePhotoID == photo.id
                                            )
                                            .onTapGesture {
                                                selectTimelinePhoto(photo)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            
                            if let photoData = selectedPhotoData, let uiImage = UIImage(data: photoData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 100)
                                    .cornerRadius(8)
                                    .padding(.horizontal)
                                    .onTapGesture {
                                        showingPhotoPreview = true
                                    }
                            }
                        }
                    }
                    
                    HStack(alignment: .bottom, spacing: 8) {
                        TextField("Type your message...", text: $question, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(1...4)
                            .focused($isQuestionFocused)
                            .disabled(conversationMessages.count >= 10)
                        
                        Button(action: askQuestion) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(question.isEmpty || conversationMessages.count >= 10 ? Color(.systemGray5) : Color.blue)
                                .clipShape(Circle())
                        }
                        .disabled(question.isEmpty || isLoading || conversationMessages.count >= 10)
                    }
                    .padding()
                    
                    if conversationMessages.count >= 10 {
                        Text("Maximum conversation limit reached (5 exchanges)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)
                    }
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("Ask AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                if !conversationMessages.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("New Conversation") {
                            resetForNewQuestion()
                        }
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingReview) {
                if let response = pendingResponse, let changes = response.suggestedChanges {
                    PlantChangeReviewView(
                        plant: plant,
                        suggestedChanges: changes,
                        onApprove: { updatedPlant in
                            dataStore.updatePlant(updatedPlant)
                            // Apply the response after approval
                            if let response = pendingResponse {
                                conversationMessages.append(ConversationMessage(
                                    role: "assistant",
                                    content: response.answer,
                                    timestamp: Date()
                                ))
                                pendingResponse = nil
                            }
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
        
        // Add user message to conversation
        let userMessage = ConversationMessage(
            role: "user",
            content: question,
            timestamp: Date()
        )
        conversationMessages.append(userMessage)
        
        // Clear the question field
        let currentQuestion = question
        question = ""
        
        Task {
            do {
                let apiKey = dataStore.settings.openAIAPIKey
                guard !apiKey.isEmpty else {
                    throw APIError.openAIError("OpenAI API key not configured")
                }
                
                let photoData = selectedPhotoData ?? selectedTimelinePhotoData
                
                let response = try await OpenAIService.shared.askPlantQuestion(
                    question: currentQuestion,
                    plant: plant,
                    rooms: dataStore.rooms,
                    zones: dataStore.zones,
                    photoData: photoData,
                    previousMessages: conversationMessages.dropLast(), // Don't include the message we just added
                    apiKey: apiKey
                )
                
                await MainActor.run {
                    self.pendingResponse = response
                    self.isLoading = false
                    
                    // If no changes suggested, add response to conversation
                    if response.suggestedChanges == nil {
                        conversationMessages.append(ConversationMessage(
                            role: "assistant",
                            content: response.answer,
                            timestamp: Date()
                        ))
                        pendingResponse = nil
                    }
                    
                    // Clear photo selection after first use
                    if conversationMessages.count == 2 {
                        selectedPhoto = nil
                        selectedPhotoData = nil
                        selectedTimelinePhotoID = nil
                    }
                }
            } catch {
                await MainActor.run {
                    // Remove the user message if there was an error
                    conversationMessages.removeLast()
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
        conversationMessages = []
        pendingResponse = nil
        selectedPhoto = nil
        selectedPhotoData = nil
        selectedTimelinePhotoID = nil
        isQuestionFocused = true
    }
    
    func selectTimelinePhoto(_ photo: PlantPhoto) {
        selectedTimelinePhotoID = photo.id
        selectedPhoto = nil
        
        // Load the photo data
        if let url = photo.imageURL,
           let imageData = try? Data(contentsOf: url) {
            selectedPhotoData = imageData
        }
    }
}

struct TimelinePhotoThumbnail: View {
    let photo: PlantPhoto
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            if let url = photo.imageURL,
               let uiImage = UIImage(contentsOfFile: url.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipped()
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            
            Text(photo.dateTaken, format: .dateTime.month().day())
                .font(.caption2)
                .foregroundColor(.secondary)
        }
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

struct ConversationBubble: View {
    let message: ConversationMessage
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == "assistant" {
                Image(systemName: "sparkles.square.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 32, height: 32)
            } else {
                Spacer()
                    .frame(width: 32)
            }
            
            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(message.role == "user" ? Color.blue : Color(.systemGray6))
                    .foregroundColor(message.role == "user" ? .white : .primary)
                    .cornerRadius(18)
                    .frame(maxWidth: 280, alignment: message.role == "user" ? .trailing : .leading)
                
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading)
            
            if message.role == "user" {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .frame(width: 32, height: 32)
            } else {
                Spacer()
                    .frame(width: 32)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
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