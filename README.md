# lockedin

A new Flutter project with Jay and Jeevan

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


# LockedIn 🔒

LockedIn is a cross-platform mobile productivity-tracking application built using **Flutter** and **Supabase**. Functioning as a *"Strava for studying,"* LockedIn shifts the focus from toxic "time spent at a desk" to actual **tasks executed**, helping university students build healthy, accountable, and consistent deep-work habits.

---

## 🎯 Targeted Level of Achievement
**Apollo 11**

---

## 💡 Milestone 1 (Ideation)

### 1. Problem Motivation  
Coping with a university's academic rigor is challenging; the process of studying can easily become demoralizing. Students frequently struggle with the sheer volume of content covered per module in a semester, and consolidating knowledge across 5–6 modules is no easy task. 

Current productivity and study-tracking applications fundamentally misunderstand student psychology. They reward "time spent sitting at a desk" via stopwatches, which often leads to fake productivity and toxic comparisons of study hours among peers. 

**LockedIn** shifts the focus from *time spent* to *tasks executed*. We want to create a tracking system that, on top of tracking time spent studying, holds students accountable for how they spent that time. Instead of just telling students how long they spent at the library, we provide immediate feedback on what they accomplished in that timeframe. By gamifying the completion of specific assignment milestones rather than raw hours, we promote healthier study habits, discourage last-minute cramming, and provide a meaningful, supportive social feed for university students.

### 2. Proposed Core Features & User Stories

#### Core System Features
* **Authentication Sandbox Protocol:** Secure user registration and login functionality.
* **Task Management & Tagging:** Checklists of micro-tasks categorized by university modules.
* **Study Session Timer:** An elegant built-in timer to track focused study durations alongside active tasks.
* **Social Accountability Feed:** A feed displaying the completed milestones of connected friends to encourage genuine accountability.
* **Visual Consistency Calendar:** A calendar interface displaying past study sessions to maintain visual study streaks.

#### User Stories
1. **As students who struggle with procrastination**, we want to break our assignments down into a checklist of micro-tasks so that we can track our assignments and feel a sense of progression for each step completed.
2. **As friends in a study group**, we want to see our peers' completed milestones on a social feed so that we can stay motivated without the anxiety of comparing total hours studied.
3. **As students trying to build better habits**, we want to view our past study sessions on a calendar so that we can maintain a visual streak and stay consistent over the semester.
4. **As a user of this app**, I want to be able to create a to-do list and utilize tags to separate my tasks according to subjects/modules, allowing for easier tracking of progress.
5. **As a user who studies in multiple places**, I want the app to tag my location during a focused session so that I can view analytics on which environments yield my highest productivity.

### 3. System Design & Architecture

LockedIn utilizes a modern Serverless/BaaS architecture to ensure a seamless cross-platform experience and rapid feature delivery:

* **Frontend:** **Flutter / Dart** for a single-codebase compile targeting both iOS and Android with visual consistency.
* **Backend-as-a-Service (BaaS):** **Supabase**, leveraging its native authentication management engine to securely handle session tokens.
* **Database:** **PostgreSQL (via Supabase)** to handle complex relational links between user records, profile attributes, micro-tasks, and social metadata.

#### Technical Architecture Pipeline
