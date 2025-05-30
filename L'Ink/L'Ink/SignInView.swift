import SwiftUI

struct SignInView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showingSignUp = false
    @State private var isPasswordVisible = false
    
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
            }
        }

struct SignInView_Previews: PreviewProvider {
    static var previews: some View {
        SignInView()
            .environmentObject(AuthViewModel())
    }
} 