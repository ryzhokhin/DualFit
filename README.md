# DualFit 💪

A daily exercise challenge app for small groups of friends (2-10 people) built with **SwiftUI** and **CloudKit**.

![iOS 17+](https://img.shields.io/badge/iOS-17%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![CloudKit](https://img.shields.io/badge/Backend-CloudKit-green)

## Overview

DualFit is an accountability app where you and your friends create daily fitness challenges, submit video proof of your exercises, and verify each other's progress. The app is designed to be cheap to operate using only Apple's free CloudKit tier, and automatically deletes videos after they're reviewed to minimize storage costs.

### Key Features

- 🏋️ **Create Challenges** - Set up daily exercise routines with custom exercises and rep counts
- 📹 **Video Proof** - Record and upload short videos proving you completed your exercises
- ✅ **Peer Review** - Friends approve or reject your submissions
- 📅 **Calendar View** - Track your daily progress with a visual calendar
- 🏆 **Leaderboard** - Compete with friends to see who's winning the challenge
- 🔗 **Easy Joining** - Share a simple code for friends to join your challenge

## Screenshots

(Add screenshots here after building the app)

## Architecture

```
DualFit/
├── DualFitApp.swift         # App entry point
├── Models/                   # CloudKit-backed data models
│   ├── AppUser.swift
│   ├── Challenge.swift
│   ├── ChallengeExercise.swift
│   ├── ChallengeParticipant.swift
│   └── ExerciseSubmission.swift
├── Services/                 # CloudKit operations
│   ├── CloudKitManager.swift
│   ├── UserService.swift
│   ├── ChallengeService.swift
│   └── SubmissionService.swift
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

## Setup Instructions

### Prerequisites

- Xcode 15+ 
- iOS 17+ device or simulator
- Apple Developer account (free tier works)
- iCloud account (for testing)

### Step 1: Create Xcode Project

1. Open Xcode
2. Create a new project: **File → New → Project**
3. Select **iOS → App**
4. Configure:
   - Product Name: `DualFit`
   - Team: Your Apple Developer team
   - Organization Identifier: Your identifier (e.g., `com.yourname`)
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **None** (we'll use CloudKit)
5. Choose a location and create the project

### Step 2: Add Source Files

1. Delete the default `ContentView.swift` file
2. Copy all the Swift files from this repository into your Xcode project:
   - Drag the `Models`, `Services`, `ViewModels`, `Views`, and `Utilities` folders into your project
   - Replace `DualFitApp.swift` with the one from this repo
3. Copy the `Assets.xcassets` folder contents
4. Copy `Info.plist` and `DualFit.entitlements`

### Step 3: Configure CloudKit

1. Select your project in the navigator
2. Select the **DualFit** target
3. Go to **Signing & Capabilities**
4. Click **+ Capability** and add:
   - **iCloud**
5. In the iCloud capability:
   - Check **CloudKit**
   - Under Containers, click the **+** button
   - Create a container named: `iCloud.com.yourteam.DualFit` (use your actual bundle ID)

### Step 4: Set Up CloudKit Schema

1. Open the [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard/)
2. Select your container
3. Go to **Schema** → **Record Types**
4. Create these record types (or they'll be auto-created on first save):

#### AppUser
| Field | Type |
|-------|------|
| icloudUserRecordID | String |
| displayName | String |
| avatarEmoji | String |
| createdAt | Date/Time |

#### Challenge
| Field | Type |
|-------|------|
| name | String |
| description | String |
| createdByUserRef | Reference → AppUser |
| startDate | Date/Time |
| endDate | Date/Time |
| maxParticipants | Int(64) |
| createdAt | Date/Time |

#### ChallengeExercise
| Field | Type |
|-------|------|
| challengeRef | Reference → Challenge |
| name | String |
| dailyRequiredReps | Int(64) |
| order | Int(64) |

#### ChallengeParticipant
| Field | Type |
|-------|------|
| challengeRef | Reference → Challenge |
| userRef | Reference → AppUser |
| joinedAt | Date/Time |

#### ExerciseSubmission
| Field | Type |
|-------|------|
| challengeRef | Reference → Challenge |
| exerciseRef | Reference → ChallengeExercise |
| userRef | Reference → AppUser |
| date | Date/Time |
| videoAsset | Asset |
| status | String |
| reviewerRef | Reference → AppUser |
| reviewedAt | Date/Time |
| videoDeleted | Int(64) |
| pointsAwarded | Int(64) |
| createdAt | Date/Time |
| updatedAt | Date/Time |

5. Add indexes for queryable fields:
   - AppUser: `icloudUserRecordID` (Queryable)
   - Challenge: all reference fields (Queryable)
   - ChallengeExercise: `challengeRef` (Queryable)
   - ChallengeParticipant: `challengeRef`, `userRef` (Queryable)
   - ExerciseSubmission: `challengeRef`, `userRef`, `exerciseRef`, `status`, `date` (Queryable, Sortable)

### Step 5: Configure Info.plist

Ensure your `Info.plist` contains these privacy descriptions:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>DualFit needs access to your photo library to select exercise videos for proof of completion.</string>
<key>NSCameraUsageDescription</key>
<string>DualFit needs camera access to record exercise videos for proof of completion.</string>
<key>NSMicrophoneUsageDescription</key>
<string>DualFit needs microphone access to record audio with your exercise videos.</string>
```

### Step 6: Build and Run

1. Select a device or simulator running iOS 17+
2. Make sure you're signed into iCloud on the device/simulator
3. Build and run (⌘R)

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

This app is designed to run on CloudKit's free tier:
- **10 GB asset storage**
- **100 MB database storage**
- **2 GB data transfer/day**

To stay within limits:
- Videos are deleted immediately after review
- Only metadata is kept for history
- Recommended: 60-second max videos, compressed to ~5MB each

## Assumptions

- One submission per exercise per day per user
- Videos must be under 60 seconds
- Maximum 10 participants per challenge
- Maximum 10 exercises per challenge
- Using iCloud authentication (no email/password)

## Future Improvements

- [ ] In-app video recording
- [ ] Push notifications for new submissions
- [ ] Export challenge history
- [ ] Challenge templates
- [ ] Streak tracking and badges
- [ ] Deep linking for join codes

## License

MIT License - feel free to use this code for your own projects!

## Contributing

Pull requests are welcome! Please open an issue first to discuss proposed changes.

