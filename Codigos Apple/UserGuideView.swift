import SwiftUI



extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

struct UserGuideView: View {
    @Binding var currentGuideStep: Int
    @Binding var highlightID: String?
    let guideSteps: [UserGuideStep]
    @Binding var showingUserGuide: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showingUserGuide = false
                        UserDefaults.standard.set(true, forKey: "hasSeenUserGuide")
                        highlightID = nil
                    }
                }
            
            if let step = guideSteps[safe: currentGuideStep] {
                VStack(spacing: 20) {
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation {
                                showingUserGuide = false
                                UserDefaults.standard.set(true, forKey: "hasSeenUserGuide")
                                highlightID = nil
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white)
                                .imageScale(.large)
                                .padding(.top, 10)
                                .padding(.trailing, 10)
                        }
                    }
                    
                    Text("Guía de Usuario")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.bottom, 10)
                    
                    if let image = UIImage(named: step.imageName) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 300, maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    Text(step.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                    
                    Text(step.description)
                        .font(.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Spacer()
                    
                    HStack {
                        if currentGuideStep > 0 {
                            Button(action: {
                                withAnimation {
                                    currentGuideStep -= 1
                                    if let newStep = guideSteps[safe: currentGuideStep] {
                                        highlightID = newStep.highlightID
                                    }
                                }
                            }) {
                                Image(systemName: "arrow.left.circle.fill")
                                    .foregroundColor(.white)
                                    .imageScale(.large)
                            }
                        }
                        Button(action: {
                            withAnimation {
                                if currentGuideStep < guideSteps.count - 1 {
                                    currentGuideStep += 1
                                    if let newStep = guideSteps[safe: currentGuideStep] {
                                        highlightID = newStep.highlightID
                                    }
                                } else {
                                    showingUserGuide = false
                                    UserDefaults.standard.set(true, forKey: "hasSeenUserGuide")
                                    highlightID = nil
                                }
                            }
                        }) {
                            Text(currentGuideStep < guideSteps.count - 1 ? NSLocalizedString("Siguiente", comment: "") : NSLocalizedString("Finalizar", comment: ""))
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.bottom, 20)
                }
                .padding()
                .background(VisualEffectView(effect: UIBlurEffect(style: .systemMaterial)))
            } else {
                Color.clear
                    .onAppear {
                        withAnimation {
                            currentGuideStep = 0
                            highlightID = guideSteps[safe: currentGuideStep]?.highlightID
                        }
                    }
            }
        }
    }
}
