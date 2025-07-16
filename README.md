# PlantCare 🌿

A comprehensive iOS app for managing your plant collection with intelligent care reminders, AI-powered plant identification, and organized space management.

## Features

### 🏠 Space Management
- **Indoor Rooms**: Organize plants by rooms with window tracking
- **Outdoor Zones**: Manage outdoor plants with aspect, sun exposure, and wind conditions
- **Flexible Organization**: Move plants between spaces with drag-and-drop simplicity

### 🌱 Plant Management
- **Detailed Plant Profiles**: Track common name, Latin name, visual descriptions, light requirements, and humidity preferences
- **Visual Descriptions**: Add memorable descriptions to help identify plants at a glance
- **Smart Duplication**: Duplicate plants with automatic numbering (#1, #2, etc.)
- **Bulk Import**: Import multiple plants from clipboard data

### 📅 Care Routines
- **Guided Care Sessions**: Step-by-step care routines organized by location
- **Customizable Care Steps**: Watering, misting, fertilizing, dusting, pruning, and rotation schedules
- **Smart Filtering**: Hide care steps not due for configurable days (default: 5 days)
- **Photo Documentation**: Take photos during care sessions with visual indicators
- **Reversible Actions**: Mark/unmark care steps within a session without affecting schedules

### 🤖 AI Features
- **Plant Identification**: Identify plants from photos using AI
- **Care Recommendations**: Get personalized care instructions based on your plant and home layout
- **Intelligent Placement**: AI suggests optimal locations based on plant needs and available spaces
- **Plant Q&A**: Ask questions about your plants and get expert advice

### 📊 Organization & Tracking
- **Multiple Sort Options**: 
  - Alphabetical (A-Z, Z-A)
  - By space/location
  - By watering urgency
- **Care History**: Track when care tasks were completed
- **Early Warning System**: Configurable warnings for early care completion
- **Photo Timeline**: Document plant growth with timestamped photos

### 💾 Backup & Sync
- **iCloud Backup**: Automatic backup to iCloud (when available)
- **Local Backup**: Falls back to local storage when iCloud is unavailable
- **Complete Data Export**: Backup includes all plants, rooms, zones, photos, and settings

### ⚙️ Customization
- **Notification Settings**: Daily reminders for plant care
- **Care Routine Settings**: 
  - Early completion warnings (1-7 days)
  - Hide future care steps (3-14 days)
- **Custom Room Order**: Arrange rooms for optimal care routine flow
- **OpenAI Integration**: Add your API key for AI features

## Requirements

- iOS 16.0+
- Xcode 14.0+
- Swift 5.7+
- OpenAI API key (for AI features)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/PlantCare.git
```

2. Open the project in Xcode:
```bash
cd PlantCare
open PlantCare.xcodeproj
```

3. Configure signing:
   - Select the project in Xcode
   - Go to "Signing & Capabilities"
   - Select your development team

4. Enable iCloud (optional):
   - Add iCloud capability
   - Enable "iCloud Documents"

5. Build and run on your device or simulator

## Configuration

### OpenAI API Key
To use AI features:
1. Go to Settings in the app
2. Enter your OpenAI API key
3. The key is stored securely on your device

### iCloud Backup
For automatic iCloud backup:
1. Ensure iCloud is enabled in Xcode capabilities
2. Sign in to iCloud on your device
3. The app will automatically use iCloud when available

## Usage

### Getting Started
1. **Add Rooms**: Create indoor rooms with windows (direction matters for plant placement)
2. **Add Zones**: Create outdoor zones with aspect, sun period, and wind exposure
3. **Add Plants**: Manually, via AI, or import from clipboard
4. **Set Care Schedules**: Configure watering and other care frequencies
5. **Run Care Routines**: Follow guided sessions to care for all your plants

### Care Routine Tips
- Plants are organized by location for efficient care
- Take photos to document plant health
- Use the AI assistant for plant-specific questions
- Mark care steps as complete - they won't save until session ends

### AI Plant Addition
1. Tap "Add Plant" → "Add via AI"
2. Enter plant name or take a photo
3. Select indoor/outdoor preference
4. Get AI recommendations for placement and care
5. Customize and save

## Data Format

### Import Format
Plants can be imported via clipboard in this format:
```
Plant Name 1, Location 1
Plant Name 2, Location 2
```

## Privacy

- All data is stored locally on your device
- iCloud sync (if enabled) uses your personal iCloud account
- OpenAI API calls are made directly from your device
- No analytics or tracking

## Troubleshooting

### Backup Issues
- Check iCloud is enabled in Settings
- Ensure sufficient iCloud storage
- App falls back to local storage automatically

### AI Features Not Working
- Verify OpenAI API key is entered correctly
- Check internet connection
- Ensure API key has sufficient credits

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Built with SwiftUI
- AI features powered by OpenAI
- Icons from SF Symbols

## Support

For issues, questions, or suggestions, please open an issue on GitHub.