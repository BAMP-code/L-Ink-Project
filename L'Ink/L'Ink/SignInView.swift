import SwiftUI
import Combine

struct SignInView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var keyboardHeight: CGFloat = 0
    @State private var isSigningIn = false
    
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
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .background(Color(uiColor: .systemBackground))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                            )
                        
                        Text("Sign In")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        VStack(spacing: 15) {
                            TextField("Email", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .disableAutocorrection(true)
                                .submitLabel(.next)
                            
                            SecureField("Password", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .submitLabel(.done)
                            
                            Button(action: signIn) {
                                if isSigningIn {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Sign In")
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                            .disabled(isSigningIn)
                            
                            NavigationLink(destination: SignUpView()) {
                                Text("Don't have an account? Create Account")
                                    .foregroundColor(.blue)
                            }
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
    
    private func signIn() {
        guard !email.isEmpty, !password.isEmpty else {
            alertMessage = "Please fill in all fields"
            showingAlert = true
            return
        }
        
        isSigningIn = true
        
        // Call the authViewModel's signIn function
        authViewModel.signIn(email: email, password: password)
        
        // Reset the form after a short delay to show the loading state
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isSigningIn = false
        }
    }
} 