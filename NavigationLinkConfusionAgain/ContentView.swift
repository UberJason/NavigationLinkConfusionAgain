//
//  ContentView.swift
//  NavigationLinkConfusionAgain
//
//  Created by Jason Ji on 6/4/22.
//

import SwiftUI
import Combine

/// This project shows unintuitive behavior - and a race condition - related to NavigationLinks.
/// There are three levels of navigation stack - the root list of "Plans", a detail list of "Entries", and a sub-detail screen of "Entry Details" (empty).
/// The Entry Details screen has a button that refreshes the sectioning of the root list of Plans (but all the refreshed data remains the same).
/// 
/// Most of the time when running this project, tapping "Refresh Sections On Root" causes a pop back to the Entries list in the navigation stack.
/// Once every 5-10 times, it doesn't.
///
/// The console shows that on tap of Refresh Sections On Root, the identity of PlanDetailsView changes, likely causing the pop.
/// The popping behavior is unexpected to me, because although the [PlanSection] array is recreated, *PlanSection and Plan both have an explicit id.*
/// PlanDetailsView's identity is driven by its StateObject PlanDetailsViewModel, which is initialized with a plan - which has an explicit id.
///
/// It seems like the ForEach(sections) is creating NavigationLinks that aren't being matched to their previous identities,
/// causing the creation of a new PlanDetailsView identity. But again, PlanSection has an explicit id, so I don't know why this would be the case.

// MARK: - Data Models

struct PlanSection: Identifiable {
    let id: String
    let title: String
    let plans: [Plan]
}

struct Plan {
    let id: String
    let title: String
    var entries: [Entry]
}

struct Entry {
    let id: String
    let title: String
}

class PlanSectionCreator {
    func createSections(from allPlans: [Plan]) -> [PlanSection] {
        var sections = [PlanSection]()
        
        sections = [PlanSection(id: "1", title: "Plans", plans: allPlans)]
        
        return sections
    }
}

// MARK: - Views & Observable Objects
class AllPlansViewModel: ObservableObject {
    @Published var plans: [Plan]
    @Published var sections: [PlanSection]
    let creator = PlanSectionCreator()
    
    var cancellables = Set<AnyCancellable>()
    
    init(plans: [Plan]) {
        self.plans = plans
        self.sections = creator.createSections(from: plans)
        
        NotificationCenter.default.publisher(for: .refresh).sink { [unowned self] _ in
            self.refresh()
        }
        .store(in: &cancellables)
    }
    
    func refresh() {
        self.sections = creator.createSections(from: plans)
    }
    
}

struct AllPlansView: View {
    @StateObject var viewModel = AllPlansViewModel(plans: [
        Plan(id: "1", title: "Plan 1", entries: [
            Entry(id: "1", title: "Entry 1")
        ])
    ])
    
    var body: some View {
        let _ = Self._printChanges()
        NavigationView {
            List {
                ForEach(viewModel.sections) { section in
                    Section(header: Text(section.title)) {
                        ForEach(section.plans, id: \.id) { plan in
                            NavigationLink(destination: PlanDetailsView(plan: plan)) {
                                Text(plan.title)
                            }
                        }
                    }
                }
            }
            .navigationTitle("All Plans")
        }
    }
}

class PlanDetailsViewModel: ObservableObject {
    let plan: Plan
    
    init(plan: Plan) {
        self.plan = plan
    }
}

struct PlanDetailsView: View {
    @StateObject var viewModel: PlanDetailsViewModel
    
    init(plan: Plan) {
        self._viewModel = StateObject(wrappedValue: PlanDetailsViewModel(plan: plan))
    }
    
    var body: some View {
        let _ = Self._printChanges()
        List {
            ForEach(viewModel.plan.entries, id: \.id) { entry in
                NavigationLink {
                    EntryDetailsView(entry: entry)
                } label: {
                    Text(entry.title)
                }
            }
        }
    }
}

struct EntryDetailsView: View {
    let entry: Entry
    
    var body: some View {
        let _ = Self._printChanges()
        Button("Refresh Sections On Root") {
            NotificationCenter.default.post(name: .refresh, object: nil)
        }
    }
}

// MARK: - Utility

extension Notification.Name {
    static let refresh = Notification.Name.init(rawValue: "refresh")
}
