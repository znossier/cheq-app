//
//  AddPeopleView.swift
//  Cheq
//
//  Add people screen with fast name input
//

import SwiftUI

struct AddPeopleView: View {
    @State var receipt: Receipt
    @State private var newPersonName = ""
    @State private var navigateToAssign = false
    @FocusState private var isNameFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Who's splitting this bill?")
                .font(.headline)
                .padding(.top)
            
            // Name input
            TextField("Enter name", text: $newPersonName)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color.appSurface)
                .cornerRadius(8)
                .focused($isNameFieldFocused)
                .submitLabel(.done)
                .onSubmit {
                    addPerson()
                }
                .padding(.horizontal)
            
            // People list
            if !receipt.people.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(receipt.people) { person in
                            HStack {
                                Text(person.name)
                                    .font(.body)
                                Spacer()
                                    Button(action: {
                                        removePerson(person)
                                    }) {
                                        Image(systemName: "trash.fill")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(.red)
                                    }
                            }
                            .padding()
                            .background(Color.appSurface)
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            Spacer()
            
            // Continue button
            if receipt.people.count >= 2 {
                Button(action: {
                    navigateToAssign = true
                }) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.appButtonTextOnMint)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appPrimary)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom)
                .frame(minHeight: Constants.minimumTapTargetSize)
            }
        }
        .navigationTitle("Add People")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isNameFieldFocused = true
        }
        .navigationDestination(isPresented: $navigateToAssign) {
            AssignItemsView(receipt: receipt)
        }
    }
    
    private func addPerson() {
        let trimmedName = newPersonName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        let person = Person(name: trimmedName)
        receipt.people.append(person)
        newPersonName = ""
        isNameFieldFocused = true
    }
    
    private func removePerson(_ person: Person) {
        receipt.people.removeAll { $0.id == person.id }
    }
}

