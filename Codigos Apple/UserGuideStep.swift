// UserGuideStep.swift
import Foundation

struct UserGuideStep: Identifiable {
    let id = UUID() // Agrega conformidad con Identifiable si es necesario
    let title: String
    let description: String
    let imageName: String
    let highlightID: String
}
