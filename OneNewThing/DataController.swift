/// DataController.swift
import Foundation
import CoreData

class DataController: ObservableObject {
    let container: NSPersistentContainer
    // Shared model instance to ensure we don't create multiple models
    private static let sharedModel: NSManagedObjectModel = makeModel()

    init() {
        print("📊 DataController.init() starting")
        // Use the shared model instance
        container = NSPersistentContainer(name: "NewExperiencesModel", managedObjectModel: Self.sharedModel)
        print("📊 NSPersistentContainer created")
        
        container.loadPersistentStores { _, error in
            if let error = error {
                print("📊 ERROR: Core Data failed to load: \(error.localizedDescription)")
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
            print("📊 Persistent stores loaded successfully")
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        print("📊 Starting seedDataIfNeeded()")
        seedDataIfNeeded()
        print("📊 DataController initialization complete")
    }

    /// Constructs the Core Data model entirely in code
    private static func makeModel() -> NSManagedObjectModel {
        print("📊 Creating NSManagedObjectModel")
        let model = NSManagedObjectModel()

        // ExperienceCategory entity
        let categoryEntity = NSEntityDescription()
        categoryEntity.name = "ExperienceCategory"
        categoryEntity.managedObjectClassName = String(describing: ExperienceCategory.self)
        let categoryName = NSAttributeDescription()
        categoryName.name = "name"
        categoryName.attributeType = .stringAttributeType
        categoryName.isOptional = true
        categoryEntity.properties = [categoryName]

        // Activity entity
        let activityEntity = NSEntityDescription()
        activityEntity.name = "Activity"
        activityEntity.managedObjectClassName = String(describing: Activity.self)
        let activityName = NSAttributeDescription()
        activityName.name = "name"
        activityName.attributeType = .stringAttributeType
        activityName.isOptional = true
        let notesAttr = NSAttributeDescription()
        notesAttr.name = "notes"
        notesAttr.attributeType = .stringAttributeType
        notesAttr.isOptional = true
        let isIncluded = NSAttributeDescription()
        isIncluded.name = "isIncluded"
        isIncluded.attributeType = .booleanAttributeType
        isIncluded.isOptional = false
        let isCompleted = NSAttributeDescription()
        isCompleted.name = "isCompleted"
        isCompleted.attributeType = .booleanAttributeType
        isCompleted.isOptional = false
        isCompleted.defaultValue = false
        activityEntity.properties = [activityName, notesAttr, isIncluded, isCompleted]

        // JournalEntry entity
        let journalEntity = NSEntityDescription()
        journalEntity.name = "JournalEntry"
        journalEntity.managedObjectClassName = String(describing: JournalEntry.self)
        let dateAttr = NSAttributeDescription()
        dateAttr.name = "date"
        dateAttr.attributeType = .dateAttributeType
        dateAttr.isOptional = true
        let textAttr = NSAttributeDescription()
        textAttr.name = "text"
        textAttr.attributeType = .stringAttributeType
        textAttr.isOptional = true
        let titleAttr = NSAttributeDescription()
        titleAttr.name = "title"
        titleAttr.attributeType = .stringAttributeType
        titleAttr.isOptional = true
        journalEntity.properties = [dateAttr, titleAttr, textAttr]

        // Relationships: Category.activities <-> Activity.category
        let relActivities = NSRelationshipDescription()
        relActivities.name = "activities"
        relActivities.destinationEntity = activityEntity
        relActivities.minCount = 0
        relActivities.maxCount = 0  // to-many
        relActivities.deleteRule = .cascadeDeleteRule

        let relCategory = NSRelationshipDescription()
        relCategory.name = "category"
        relCategory.destinationEntity = categoryEntity
        relCategory.minCount = 0
        relCategory.maxCount = 1  // to-one
        relCategory.deleteRule = .nullifyDeleteRule

        relActivities.inverseRelationship = relCategory
        relCategory.inverseRelationship = relActivities

        categoryEntity.properties.append(relActivities)
        activityEntity.properties.append(relCategory)

        model.entities = [categoryEntity, activityEntity, journalEntity]
        print("📊 NSManagedObjectModel creation complete")
        return model
    }

    /// Seeds all default categories and activities on first launch
    private func seedDataIfNeeded() {
        let ctx = container.viewContext
        let request: NSFetchRequest<ExperienceCategory> = ExperienceCategory.fetchRequest()
        
        do {
            let count = try ctx.count(for: request)
            print("📊 Found \(count) existing categories")
            guard count == 0 else { return }
            
            print("📊 Seeding initial data")
            // Continue with seeding...
        } catch {
            print("📊 Error checking for existing data: \(error.localizedDescription)")
            return
        }

        let defaults: [String: [String]] = [
            "🧭 Gently Adventurous / Exploration": [
                "Go wild swimming at dawn",
                "Sleep in a hammock overnight",
                "Spend 24 hours without technology. No phones, no screens.",
                "Join the local protest or march for a cause you believe in.",
                "Go geocaching",
                "Take a spontaneous day trip somewhere",
                "Take a ride on a heritage railway",
                "Try a new mode of transportation",
                "See how far you can get in one day on public transport",
                "Choose one event within 20 miles of your home that week — chosen at random"
            ],
            "👃 Sensory / Self-Care / Body Awareness": [
                "Try a sensory deprivation tank",
                "Experience a proper tea ceremony",
                "Experience a traditional hammam or sauna",
                "Attend a sound bath or gong meditation",
                "Get a type of massage you've never had before",
                "Experience aromatherapy",
                "Try tai chi"
            ],
            "🔄 Perspective-Shifting": [
                "Visit a Buddhist monastery",
                "Attend a religious service or ritual from a tradition you're unfamiliar with",
                "Have a conversation with someone from an older generation for an hour with no agenda",
                "Spend a full day intentionally doing everything slowly",
                "Try volunteering somewhere totally outside your usual world",
                "Attend a cultural festival",
                "Visit a museum or gallery you've never been to",
                "Read a book from a genre you usually avoid",
                "Attend a lecture or seminar",
                "Try fasting",
                "Spend a week in silence"
            ],
            "🎨 Creative / Expressive": [
                "Learn and perform a simple magic or card trick in front of someone",
                "Take a dance class",
                "Make and release a song using only your voice and body for sound",
                "Write and mail a letter to someone who changed your life",
                "Take an art class",
                "Write a short story or poem and share it",
                "Attend a jam night",
                "Lead a sound walk",
                "Write and release an EP in a week",
                "Release one app on the App Store",
                "Release one Max for Live device"
            ],
            "💬 Relationships & People": [
                "Go on a friend date",
                "Ask someone deep questions from the 36 Questions study",
                "Strike up a conversation with a stranger",
                "Leave a thank you note for someone in a public-facing job",
                "Write someone a compliment and send it by post or mail",
                "Interview a friend or relative about their life story",
                "Let someone else plan a day for you with no input"
            ],
            "🏋️ Physical Challenge / Nature": [
                "Learn to hula hoop (practice for half an hour a day for a week)",
                "Try walking a marathon distance (26 miles) in one day",
                "Go foraging",
                "Go wild camping on your own",
                "Go for a walk",
                "Submit your work to something"
            ]
        ]

        for (catName, acts) in defaults {
            let category = ExperienceCategory(context: ctx)
            category.name = catName
            for actName in acts {
                let activity = Activity(context: ctx)
                activity.name = actName
                activity.notes = nil
                activity.isIncluded = true
                activity.isCompleted = false
                activity.category = category
            }
        }
        
        do {
            try ctx.save()
            print("📊 Initial data seeded successfully")
        } catch {
            print("📊 Error saving seeded data: \(error.localizedDescription)")
        }
    }
}
