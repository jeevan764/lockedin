# lockedin

A new Flutter project with Jay and Jeevan

# How to use our application LockedIn!
Welcome to LockedIn! Our application is designed to shift the paradigm from simply tracking time spent to tracking actual tasks executed. Here is a quick guide to getting started with your new academic companion.

# Step 1: Getting Started
Create an Account: Open the app and sign up by entering a valid email address, a unique username, and a secure password.

Log In: If you already have an account, simply log in with your credentials to be directed to your homepage.

# Step 2: Organize Your Workspace
Navigate to Workspace: This is your central command dashboard to manage academic commitments.

Create Module Tags: Categorize your work by setting up color-coded tags for your specific university modules or subjects (e.g., CS1010, MA1521).

Add Tasks: Break your assignments down and add them as micro-tasks under their respective module tags.

Check Them Off: Tap the checkboxes to tick off assignments as you complete them and watch them disappear from your active list.

# Step 3: Get "Locked In" (Record a Session)
When you are ready to study, navigate to the Record Activity page. You can track your session via two methods:

Live Timer: Press start on the built-in stopwatch to clock your focus session in real-time. You can pause and resume the timer when your focus wavers.

Manual Entry: Forgot to start the timer? Use the manual entry form to log past study sessions after the fact.

Log Details: For both methods, you will be required to input the duration you studied, the specific task you completed, and your study location.

# Step 4: Socialize Your Focus
View the Activity Feed: Your homepage acts as a chronological timeline displaying the study sessions and task accomplishments of your peers.

Add Friends: Tap the button on the top right of the Activity Feed page to search for your study buddies by their usernames and follow them.

Engage: Provide mutual accountability by utilizing the interactive like buttons and comment feature on your friends' activity cards.

# Step 5: Track Your Progress
Navigate to your Profile Page to view your personalized statistics and academic growth:

Calendar Heatmap: Review a monthly calendar grid that visually colorizes the specific days you successfully logged tasks.

Day Streak: Check your current consistency via the fire icon, which tracks how many consecutive calendar days you have actively logged focus achievements.

Social Stats: View your current Follower and Following counts, which control the streams on your social timeline.


# LockedIn 🔒

LockedIn is a cross-platform mobile productivity-tracking application built using Flutter and Supabase. Functioning as a "Strava for studying," LockedIn shifts the focus from toxic "time spent at a desk" to actual tasks executed, helping university students build healthy, accountable, and consistent deep-work habits.

# 🎯 Targeted Level of Achievement
Apollo 11

# 🚀 Milestone 2 (Prototyping) - Core Features Implemented
During the Prototyping phase, we successfully transitioned our core UI/UX concepts into a fully functional, database-backed application.

# 1. Workspace & Task Management
Dynamic Module Tagging: Users can create custom university module tags (e.g., CS2030, BT1101), which the system automatically assigns unique, consistent colors using hashcode generation.

Granular Task Checklists: Students can break down monolithic assignments into micro-tasks and check them off in real-time, instantly syncing with the backend.

# 2. Activity Recording Engine
Dual-Mode Tracking: Users can lock into a session using the Live Stopwatch Timer for real-time focus, or utilize the Manual Entry fallback for retrospective logging.

Contextual Data: Every session captures the specific task, the associated module tag, the duration, and the physical location of the user.

# 3. Social Accountability Feed
Chronological Peer Timeline: A fully functional social feed that automatically aggregates and formats the completed milestones of followed friends.

Interactive Engagement: Users can "Like" and "Comment" on peers' study sessions.

Follower System: A built-in user search engine allows students to find peers, follow them, and curate a customized network of study companions.

Smart UI Rendering: The feed utilizes dynamic time-ago formatting (e.g., "2 hrs ago") and automatically extracts and colorizes module tags from database strings.

# 4. Profile & Analytics Dashboard
Interactive Calendar Heatmap: A visual grid powered by table_calendar that queries the user's historical study data to plot active study days.

Gamification Metrics: The app calculates and updates a Daily Streak counter and an aggregate Total XP score based on the duration of completed tasks.

Data Mutability (CRUD): Users can seamlessly edit past session logs (adjusting duration, tags, or names) or delete them entirely, with strict PostgreSQL Row Level Security (RLS) policies ensuring data privacy.

# 💡 The Problem & Our Motivation
Coping with a university's academic rigor is challenging; the process of studying can easily become demoralizing. Students frequently struggle with the sheer volume of content covered per module in a semester, and consolidating knowledge across 5–6 modules simultaneously is a monumental task.

Current productivity and study-tracking applications fundamentally misunderstand student psychology. They reward "time spent sitting at a desk" via generic stopwatches, which often leads to fake productivity and toxic comparisons of study hours among peers.

LockedIn shifts the paradigm. We engineered a tracking system that holds students strictly accountable for how they spent their time. Instead of just telling a student they spent three hours in the library, LockedIn provides immediate feedback on what they accomplished in that timeframe. By gamifying task execution rather than raw hours, we promote healthier study habits, actively discourage last-minute cramming, and foster a meaningful, supportive social environment.

# 🏗️ System Design & Architecture
LockedIn utilizes a modern Serverless/BaaS architecture to ensure a seamless cross-platform experience and rapid feature delivery:

Frontend (Flutter / Dart): A single-codebase compiling to both iOS and Android. We utilize ValueNotifier for efficient state management, ensuring background tabs (like the Social Feed) instantly refresh without requiring manual user intervention or heavy API polling.

Backend-as-a-Service (Supabase): Leverages Supabase's native authentication management engine to securely handle session tokens and user identity.

Database (PostgreSQL): Handles the complex relational links between user records, social metadata (followers/likes/comments), and task instances. We utilize strict Row Level Security (RLS) policies to ensure users can only modify their own data.

# 🗺️ Roadmap (Milestone 3 Extensions)
With our core MVP completed, we are targeting the following extension features for Milestone 3:

Level & Badge Progression: Expanding the XP engine to calculate user tiers and unlock visual badges for their profile avatar.

Spatial Analytics: Translating the logged "Location" data into readable bar charts or heatmaps to show users their most productive campus environments.

Background Timer Persistence: Ensuring the Live Timer can persist perfectly even if the application is temporarily minimized or closed in the background.