import SwiftUI
import CoreData

struct ActivitiesView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Activity.name, ascending: true)],
        predicate: NSPredicate(format: "isIncluded == YES"),
        animation: .default
    )
    private var activities: FetchedResults<Activity>

    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingAdd = false
    @State private var selectedActivity: Activity?

    var body: some View {
        NavigationStack {
            List {
                ForEach(activities, id: \.objectID) { act in
                    HStack {
                        Text(act.name ?? "")
                            .strikethrough(act.isCompleted, color: .red)
                            .foregroundColor(act.isCompleted ? .gray : .primary)
                        Spacer()
                    }
                    .contentShape(Rectangle())           // make whole row tappable
                    .onTapGesture {
                        selectedActivity = act          // show detail sheet
                    }
                }
            }
            .navigationTitle("My Activities")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink("Edit Catalog", destination: CatalogView())
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            // Add-New sheet, wrapped in a NavigationStack so Save/Cancel toolbar appears:
            .sheet(isPresented: $showingAdd) {
                NavigationStack {
                    AddNewActivityView()
                        .environment(\.managedObjectContext, viewContext)
                }
            }
            // Detail sheet for notes
            .sheet(item: $selectedActivity) { act in
                ActivityDetailView(activity: act)
            }
        }
    }
}
