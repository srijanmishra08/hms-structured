import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor class AuthenticationViewModel: ObservableObject {
    @Published var name = ""
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var age = 0
    @Published var bloodGroup = ""
    @Published var gender = ""
    @Published var errorMessage = ""
    @Published var authenticationState: AuthenticationState = .initial
    @Published var role: Role = .none
    @Published var isSignedUp = false
    

    private var cancellables = Set<AnyCancellable>()

    func signUpWithEmailPassword() async -> Bool {
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return false
        }

        do {
            authenticationState = .authenticating
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let patientData: [String: Any] = [
                "name": name,
                "email": email,
                "age": age,
                "bloodGroup": bloodGroup,
                "gender": gender,
                "role": "patient"
            ]
            try await Firestore.firestore().collection("patients").document(result.user.uid).setData(patientData)
            authenticationState = .signedUp
            self.isSignedUp = true
            return true
        } catch {
            errorMessage = error.localizedDescription
            authenticationState = .error
            return false
        }
    }
    
    func signInWithEmailPassword() async -> Bool {
        do {
            authenticationState = .authenticating
            try await Auth.auth().signIn(withEmail: email, password: password)
            let user = Auth.auth().currentUser
            
            // Check if user is in 'patients' collection
            let patientsRef = Firestore.firestore().collection("patients").document(user?.uid ?? "")
            let patientsDoc = try await patientsRef.getDocument()
            
            // Check if user is in 'doctors' collection
            let doctorsRef = Firestore.firestore().collection("doctors").document(user?.uid ?? "")
            let doctorsDoc = try await doctorsRef.getDocument()
            
            if patientsDoc.exists {
                // User is in 'patients' collection
                role = .patient
                authenticationState = .loggedIn
                return true
            } else if doctorsDoc.exists {
                // User is in 'doctors' collection
                role = .doctor
                authenticationState = .loggedIn
                return true
            } else {
                // User not found in either collection
                errorMessage = "User not found in patients or doctors collection"
                authenticationState = .error
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            authenticationState = .error
            return false
        }
    }

   

    var isValid: Bool {
        return !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty && age > 0 && !bloodGroup.isEmpty && !gender.isEmpty
    }
    
    var isValidLogin: Bool {
        return !email.isEmpty && !password.isEmpty
    }

}

enum AuthenticationState {
    case initial
    case authenticating
    case loggedIn
    case signedUp
    case error
}

enum Role {
    case none
    case patient
    case doctor
    case admin
}
