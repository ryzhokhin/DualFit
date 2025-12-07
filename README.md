# DualFit 💪

A daily exercise challenge app for small groups of friends (2-10 people) built with **SwiftUI** and **Firebase**.

![iOS 17+](https://img.shields.io/badge/iOS-17%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![Firebase](https://img.shields.io/badge/Backend-Firebase-yellow)

## Overview

DualFit is an accountability app where you and your friends create daily fitness challenges, submit video proof of your exercises, and verify each other's progress. The app uses Firebase (Firestore + Storage + Auth) for the backend, which works with Apple's free Personal Team.

### Key Features

- 🏋️ **Create Challenges** - Set up daily exercise routines with custom exercises and rep counts
- 📹 **Video Proof** - Record and upload short videos proving you completed your exercises
- ✅ **Peer Review** - Friends approve or reject your submissions
- 📅 **Calendar View** - Track your daily progress with a visual calendar
- 🏆 **Leaderboard** - Compete with friends to see who's winning the challenge
- 🔗 **Easy Joining** - Share a simple code for friends to join your challenge

## Architecture

```
DualFit/
├── DualFitApp.swift         # App entry point with Firebase config
├── Models/                   # Firestore-backed data models
│   ├── AppUser.swift
│   ├── Challenge.swift
│   ├── ChallengeExercise.swift
│   ├── ChallengeParticipant.swift
│   └── ExerciseSubmission.swift
├── Services/                 # Firebase operations
│   ├── AuthService.swift     # Firebase Anonymous Auth
│   ├── UserService.swift     # Firestore user operations
│   ├── ChallengeService.swift # Firestore challenge operations
│   └── SubmissionService.swift # Firestore + Storage operations
├── ViewModels/               # MVVM view models
│   ├── AppViewModel.swift
│   ├── HomeViewModel.swift
│   ├── CreateChallengeViewModel.swift
│   ├── JoinChallengeViewModel.swift
│   ├── ChallengeDetailViewModel.swift
│   ├── TodayViewModel.swift
│   ├── ReviewViewModel.swift
│   ├── CalendarViewModel.swift
│   └── LeaderboardViewModel.swift
├── Views/                    # SwiftUI views
│   ├── RootView.swift
│   ├── OnboardingView.swift
│   ├── HomeView.swift
│   ├── CreateChallengeView.swift
│   ├── JoinChallengeView.swift
│   ├── ChallengeDetailView.swift
│   ├── TodayView.swift
│   ├── ReviewView.swift
│   ├── CalendarView.swift
│   └── LeaderboardView.swift
└── Utilities/
    ├── VideoCompressor.swift
    └── DateExtensions.swift
```

## Firebase Data Model

```
Firestore Collections:
├── users/{userId}                          # AppUser documents
└── challenges/{challengeId}                # Challenge documents
    ├── exercises/{exerciseId}              # ChallengeExercise subcollection
    ├── participants/{participantId}        # ChallengeParticipant subcollection
    └── submissions/{submissionId}          # ExerciseSubmission subcollection

Firebase Storage:
└── videos/{challengeId}/{userId}/{date}/{exerciseId}.mp4
```

## Setup Instructions

### Prerequisites

- Xcode 15+ 
- iOS 17+ device or simulator
- Apple Developer account (free Personal Team works!)
- Firebase account (free tier)

### Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **Add project**
3. Name it (e.g., "DualFit")
4. Disable Google Analytics (optional for this app)
5. Click **Create project**

### Step 2: Configure Firebase Services

#### Enable Authentication:
1. Go to **Build → Authentication**
2. Click **Get started**
3. Go to **Sign-in method** tab
4. Enable **Anonymous** sign-in

#### Enable Firestore:
1. Go to **Build → Firestore Database**
2. Click **Create database**
3. Select **Start in test mode** (we'll secure it later)
4. Choose a location close to your users
5. Click **Enable**

#### Enable Storage:
1. Go to **Build → Storage**
2. Click **Get started**
3. Select **Start in test mode**
4. Click **Next** and **Done**

### Step 3: Add iOS App to Firebase

1. In Firebase Console, click the **iOS+** button
2. Enter your Bundle ID (e.g., `com.yourname.DualFit`)
3. Download `GoogleService-Info.plist`
4. Click through the remaining steps (we'll add the SDK via SPM)

### Step 4: Open the Xcode Project

```bash
open DualFit.xcodeproj
```

### Step 5: Add Firebase SDK via Swift Package Manager

1. In Xcode, go to **File → Add Package Dependencies**
2. Enter: `https://github.com/firebase/firebase-ios-sdk`
3. Select version **11.0.0** or later
4. Add these packages to your target:
   - `FirebaseAuth`
   - `FirebaseFirestore`
   - `FirebaseStorage`

### Step 6: Add GoogleService-Info.plist

1. Drag the downloaded `GoogleService-Info.plist` into the `DualFit` folder in Xcode
2. Make sure "Copy items if needed" is checked
3. Ensure it's added to the DualFit target

### Step 7: Configure Signing

1. Select the project in the navigator
2. Select the **DualFit** target
3. Go to **Signing & Capabilities**
4. Select your **Personal Team**
5. Change the Bundle Identifier if needed to make it unique

### Step 8: Build and Run

1. Select a device or simulator running iOS 17+
2. Build and run (⌘R)

## Firebase Security Rules

Once you're ready for production, update your security rules:

### Firestore Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own profile
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Challenges are readable by participants
    match /challenges/{challengeId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      
      // Subcollections
      match /exercises/{exerciseId} {
        allow read: if request.auth != null;
        allow write: if request.auth != null;
      }
      
      match /participants/{participantId} {
        allow read: if request.auth != null;
        allow write: if request.auth != null;
      }
      
      match /submissions/{submissionId} {
        allow read: if request.auth != null;
        allow write: if request.auth != null;
      }
    }
  }
}
```

### Storage Rules
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /videos/{challengeId}/{userId}/{date}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
      allow delete: if request.auth != null;
    }
  }
}
```

## Usage

### Creating a Challenge

1. Tap **Create** on the home screen
2. Enter a challenge name (e.g., "November Pushup Challenge")
3. Set start and end dates
4. Add exercises with daily rep counts
5. Tap **Create Challenge**
6. Share the join code with friends!

### Joining a Challenge

1. Tap **Join** on the home screen
2. Enter the code shared by your friend
3. Tap **Find Challenge**
4. Review the challenge details
5. Tap **Join Challenge**

### Daily Workflow

1. Open a challenge
2. Go to the **Today** tab
3. For each exercise, tap **Upload** to select a video from your library
4. Wait for friends to review and approve

### Reviewing Others

1. Go to the **Review** tab
2. Tap on a pending submission
3. Watch the video
4. Tap **Approve** ✅ or **Reject** ❌

## Cost Considerations

Firebase free tier (Spark plan) includes:
- **1 GiB Firestore storage**
- **5 GB Storage**
- **50K/day Firestore reads**
- **20K/day Firestore writes**

To stay within limits:
- Videos are deleted immediately after review
- Only metadata is kept for history
- Recommended: 60-second max videos, compressed to ~5MB each

## Assumptions

- One submission per exercise per day per user
- Videos must be under 60 seconds
- Maximum 10 participants per challenge
- Maximum 10 exercises per challenge
- Using Anonymous authentication

## Troubleshooting

### "Missing GoogleService-Info.plist"
Make sure the file is added to your Xcode project and included in the target.

### "Permission denied" errors
Check that you've enabled the Firebase services and are using test mode rules.

### Video upload fails
Ensure Firebase Storage is enabled and the rules allow writes.

## Future Improvements

- [ ] In-app video recording
- [ ] Push notifications for new submissions
- [ ] Export challenge history
- [ ] Challenge templates
- [ ] Streak tracking and badges
- [ ] Deep linking for join codes
- [ ] Email/password authentication option

## License

MIT License - feel free to use this code for your own projects!

## Contributing

Pull requests are welcome! Please open an issue first to discuss proposed changes.
