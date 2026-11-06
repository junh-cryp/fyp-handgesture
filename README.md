# AI Real-Time Bahasa Isyarat Malaysia (BIM) Translator

An AI-powered mobile application designed to bridge communication between Deaf and hearing individuals through real-time Bahasa Isyarat Malaysia (BIM) gesture recognition, text translation, and speech synthesis.

**📌 Project Overview**

The AI Real-Time BIM Translator is a mobile application developed to assist communication between individuals who use Bahasa Isyarat Malaysia (BIM) and those who do not understand sign language.

The application uses computer vision techniques to detect hand landmarks and body poses, identify supported BIM hand signs, and translate recognized gestures into readable text and speech.

The project also provides interactive learning features through a BIM dictionary and a 3D avatar that demonstrates sign language gestures.

The system was developed in collaboration with the Penang Deaf Association (PDA) to gather requirements, obtain feedback, and validate the application's functionality.

### **✨ Key Features**

**1. Real-Time Sign Language Translation**
* Detects and recognizes supported BIM hand signs through the device camera.
* Converts recognized gestures into readable text.
* Displays detected hand landmarks and body pose information.
* Supports both one-hand and two-hand gestures.

**2. Speak Mode**
* Converts user-entered text into speech using Text-to-Speech (TTS).
* Allows users to communicate through generated audio.
* Supports audio sharing and exporting.

**3. Record Mode**
* Allows users to perform multiple sign language gestures continuously.
* Records recognized gestures and combines the translated words into a sentence.
* Converts the completed translation into speech.

**4. BIM Dictionary**
* Provides a collection of supported BIM signs.
* Displays corresponding sign information and visual references.
* Helps users learn and understand individual gestures.

**5. Interactive 3D Avatar**
* Provides 3D animated demonstrations of BIM hand signs.
* Helps users understand the correct movements and gestures.
* Uses character animations created with Blender.

### 🛠️ Technologies Used

**Technology & Purpose**

Flutter
* Cross-platform mobile application development

Dart
* Mobile application programming language

Python
* Backend development and gesture recognition logic

FastAPI
* Backend API communication

Supabase
* Cloud database and data storage

PostgreSQL
* Relational database management

MediaPipe
* Hand landmark detection

Google ML Kit
* Body pose detection

Blender
* 3D character modelling and animation

### **🏗️ System Architecture**

The online version follows a client-server architecture consisting of a Flutter mobile application, Python FastAPI backend, and Supabase database.

**Online System Workflow**

**Camera Input:** The Flutter application captures live camera frames.

**Landmark Detection:** MediaPipe detects hand landmarks, while Google ML Kit identifies body pose information.

**Backend Communication:** The Flutter application sends the extracted coordinates to the Python FastAPI backend.

**Gesture Recognition:** The backend processes the received coordinates using predefined rule-based gesture recognition logic.

**Database Retrieval:** Supabase is queried when gesture-related information or animation data is required.

**API Response:** The backend returns the recognition results in JSON format.

**Result Display:** Flutter processes the response and displays the translated text and relevant information.

Architecture Components

Frontend: Flutter and Dart

Backend: Python and FastAPI

Gesture Recognition: Rule-based detection using hand landmarks and body pose coordinates

Database: Supabase PostgreSQL

Computer Vision: MediaPipe and Google ML Kit


### **🗂️ Project Versions**

This project consists of two implementations:

**Offline Version**
* Uses locally stored application data and gesture recognition logic.
* Does not require the online backend and cloud database for its core functionality.
* Designed to operate independently of the online service.

**Online Version**
* Integrates a Python FastAPI backend.
* Uses Supabase for cloud database storage.
* Communicates between the Flutter frontend and backend through API requests.
* Supports centralized retrieval of gesture information and animation resources.

### **📋 Supported Sign Language Gestures**

The current implementation supports 30 selected BIM hand signs.

The recognition logic covers different gesture conditions, including:
* One-hand gestures.
* Two-hand gestures.
* Body-position-related gestures.

Gesture recognition is implemented using predefined coordinate conditions and rules rather than a trained machine learning classification model.

### 🚀 Installation and Setup
**Prerequisites**

Ensure the following tools are installed:
* Android Studio
* Flutter SDK
* Dart SDK
* Python 3.x
* Git (optional)

**1. Clone the Repository**

git clone <YOUR_REPOSITORY_URL>

Navigate into the project directory:

cd <PROJECT_DIRECTORY>

**2. Install Flutter Dependencies**

flutter pub get

**3. Backend Setup (Online Version)**

Navigate to the Python backend directory:

cd backend

Create a virtual environment:

python -m venv venv

Activate the environment.

**Windows:**

venv\Scripts\activate

Install the required Python dependencies:

pip install -r requirements.txt

Configure the required Supabase connection settings and environment variables before starting the backend.

Start the FastAPI server using the appropriate entry point for your backend:

uvicorn main:app --reload

**4. Run the Flutter Application**

Return to the Flutter project directory:

flutter run

Alternatively, open the project in Android Studio, connect an Android device or emulator, and run the application.

Note: The online version requires the backend and Supabase configuration to be set up correctly. Update the API base URL according to your development environment.

## **🗄️ Database**

The online version uses Supabase with PostgreSQL as its database system.

The database stores information related to:
* BIM gesture records.
* Gesture descriptions and instructions.
* Image references.
* 3D animation resource URLs.

The application retrieves relevant information through the backend API when required.

Security Note: Do not commit Supabase service-role keys, database passwords, API secrets, or other sensitive credentials to a public repository.

### 🧪 Testing and Validation

The application was tested through functional testing and validation sessions with representatives from the Penang Deaf Association.

Testing activities included:
* BIM gesture recognition testing.
* Gesture detection accuracy validation.
* Record Mode functionality testing.
* Text-to-Speech functionality testing.
* 3D Avatar animation validation.
* User feedback and application usability evaluation.

A total of 30 supported hand signs were tested during the validation process.

Recognition performance may be affected by environmental conditions, including lighting, background, camera angle, hand positioning, and detection distance.

## 🤝 Project Collaboration

**Industry Collaborator:** Penang Deaf Association (PDA)

The project involved requirement gathering, feedback sessions, application demonstrations, and functional validation with PDA representatives.

Their feedback helped guide the development and improvement of the application's features and usability.

### **👨‍💻 Developer**

**Tan Jun Hong 16290592**

**Bachelor of Science with Honours in Computer Science**

**INTI International College Penang**

**Coventry University**

### 📄 License

This project was developed as part of an academic Employer Project. Please contact the developer before redistributing or reusing the project materials.
