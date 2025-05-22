//
//  TouchControlTutorialView.swift
//  MacMobility
//
//  Created by Mariusz Jakowienko on 22/05/2025.
//

import SwiftUI

struct TouchControlTutorialView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var currentPage = 0
    var closeAction: () -> Void

    let pages: [TutorialPage] = [
        TutorialPage(
            title: "Welcome to Touch Display",
            description: "This is a virtual macOS display, accessible on your MobiliyControl app. You can control display using a mouse or touch gestures.",
            icon: "rectangle.and.hand.point.up.left.fill"
        ),
        TutorialPage(
            title: "Single Tap",
            description: "Tap anywhere on the screen to perform a single click. This works just like a left-click with your mouse.",
            icon: "hand.tap"
        ),
        TutorialPage(
            title: "Double Tap",
            description: "Double tap quickly on a screen area to perform a double click. Use it to open files, folders, or apps.",
            icon: "hand.tap.fill"
        ),
        TutorialPage(
            title: "Long Press & Drag",
            description: "Touch and hold for about a second to begin dragging the selected item. Perfect for moving windows or icons.",
            icon: "hand.point.up.left.fill"
        ),
        TutorialPage(
            title: "Scroll with Drag",
            description: "To scroll, touch the screen once and drag with your finger. Smoothly navigate content in windows or apps.",
            icon: "hand.draw.fill"
        )
    ]

    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    TutorialPageView(page: pages[index])
                        .tag(index)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .animation(.easeInOut, value: currentPage)

            Button(action: {
                if currentPage < pages.count - 1 {
                    currentPage += 1
                } else {
                    KeychainManager().save(key: .seenTouchTutorial, value: true)
                    closeAction()
                }
            }) {
                Text(currentPage == pages.count - 1 ? "Done" : "Next")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .cornerRadius(12)
                    .padding(.horizontal)
            }
            .padding(.bottom, 20)
        }
        .frame(width: 500, height: 370)
    }
}


struct TutorialPage {
    let title: String
    let description: String
    let icon: String
}

struct TutorialPageView: View {
    let page: TutorialPage

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: page.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)
                .padding(.top, 10)

            Text(page.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(page.description)
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
    }
}
