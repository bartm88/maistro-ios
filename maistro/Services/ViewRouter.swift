//
//  ViewRouter.swift
//  maistro
//

import SwiftUI

class ViewRouter: ObservableObject {
    @Published var currentView: AppView = .landing
    @Published var viewStack: [AppView] = []

    func navigate(to view: AppView) {
        viewStack.append(currentView)
        currentView = view
    }

    func goBack() {
        if let previousView = viewStack.popLast() {
            currentView = previousView
        }
    }

    func goToRoot() {
        viewStack.removeAll()
        currentView = .landing
    }

    func goToCards() {
        viewStack.removeAll()
        currentView = .cards
    }
}
