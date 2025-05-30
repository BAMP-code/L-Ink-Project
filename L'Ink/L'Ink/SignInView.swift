import SwiftUI

struct SignInView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showingSignUp = false
    @State private var isPasswordVisible = false
    @State private var showingForgotPasswordAlert = false
    @State private var showingResetConfirmation = false
    @State private var resetPasswordMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Logo
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .padding(.top, 50)
            
            Text("Welcome to L'Ink")
                .font(.title)
                .fontWeight(.bold)
            
            // Sign In Form
            VStack(spacing: 15) {
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                
                ZStack(alignment: .trailing) {
                    if isPasswordVisible {
                        TextField("Password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textContentType(.password)
                    } else {
                        SecureField("Password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textContentType(.password)
                    }
                    
                    Button(action: { isPasswordVisible.toggle() }) {
                        Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.gray)
                    }
                    .padding(.trailing, 8)
                }
                
                // Forgot Password Button
                Button(action: {
                    showingForgotPasswordAlert = true
                }) {
                    Text("Forgot Password?")
                        .foregroundColor(.blue)
                        .font(.footnote)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal)
            }
            .padding(.horizontal)
            
            // Sign In Button
            Button(action: {
                authViewModel.signIn(email: email, password: password)
            }) {
                Text("Sign In")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            
            // Sign Up Link
            Button(action: { showingSignUp = true }) {
                Text("Don't have an account? Sign Up")
                    .foregroundColor(.blue)
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingSignUp) {
            SignUpView()
        }
        .alert("Reset Password", isPresented: $showingForgotPasswordAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset") {
                if !email.isEmpty {
                    authViewModel.resetPassword(email: email) { success, message in
                        resetPasswordMessage = success ? 
                            "Password reset email has been sent to \(email)" :
                            message ?? "An error occurred"
                        showingResetConfirmation = true
                    }
                } else {
                    resetPasswordMessage = "Please enter your email address first"
                    showingResetConfirmation = true
                }
            }
        } message: {
            Text("Would you like to reset your password? A reset link will be sent to your email address.")
        }
        .alert("Password Reset", isPresented: $showingResetConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(resetPasswordMessage)
        }
    }
}

struct SignInView_Previews: PreviewProvider {
    static var previews: some View {
        SignInView()
            .environmentObject(AuthViewModel())
    }
} 