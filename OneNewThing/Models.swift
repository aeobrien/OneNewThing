/// Models.swift
import Foundation
import CoreData

@objc(ExperienceCategory)
public class ExperienceCategory: NSManagedObject, Identifiable {
    @NSManaged public var name: String?
    @NSManaged public var activities: Set<Activity>?
}

extension ExperienceCategory {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ExperienceCategory> {
        NSFetchRequest<ExperienceCategory>(entityName: "ExperienceCategory")
    }
    var activitiesArray: [Activity] {
        (activities ?? []).sorted { ($0.name ?? "") < ($1.name ?? "") }
    }
}

@objc(Activity)
public class Activity: NSManagedObject, Identifiable {
    @NSManaged public var name: String?
    @NSManaged public var notes: String?
    @NSManaged public var isIncluded: Bool
    @NSManaged public var isCompleted: Bool
    @NSManaged public var category: ExperienceCategory?
}

extension Activity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Activity> {
        NSFetchRequest<Activity>(entityName: "Activity")
    }
}

@objc(JournalEntry)
public class JournalEntry: NSManagedObject, Identifiable {
    @NSManaged public var date: Date?
    @NSManaged public var text: String?
    @NSManaged public var title: String?
}

extension JournalEntry {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<JournalEntry> {
        NSFetchRequest<JournalEntry>(entityName: "JournalEntry")
    }
}
