import SwiftUI
import Combine

struct SignUpView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var keyboardHeight: CGFloat = 0
    @State private var isSigningUp = false
    
    private var keyboardPublisher: AnyPublisher<CGFloat, Never> {
        Publishers.Merge(
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
                .map { notification in
                    (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
                },
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
                .map { _ in 0 }
        )
        .eraseToAnyPublisher()
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 20) {
                        Image(systemName: "book.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.blue)
                        
                        Text("Create Account")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        VStack(spacing: 15) {
                            TextField("Username", text: $username)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .submitLabel(.next)
                            
                            TextField("Email", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .disableAutocorrection(true)
                                .submitLabel(.next)
                            
                            SecureField("Password", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .submitLabel(.done)
                            
                            Button(action: signUp) {
                                if isSigningUp {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Sign Up")
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                            .disabled(isSigningUp)
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                    .frame(minHeight: geometry.size.height - keyboardHeight)
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .onReceive(keyboardPublisher) { height in
                withAnimation(.easeOut(duration: 0.16)) {
                    keyboardHeight = height
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func signUp() {
        guard !email.isEmpty, !password.isEmpty, !username.isEmpty else {
            alertMessage = "Please fill in all fields"
            showingAlert = true
            return
        }
        
        isSigningUp = true
        
        // Call the authViewModel's signUp function
        authViewModel.signUp(email: email, password: password, username: username)
        
        // Reset the form after a short delay to show the loading state
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isSigningUp = false
        }
    }
}
