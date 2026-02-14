import Foundation

@MainActor
struct SampleDataGenerator {

    static func generateSampleWorkouts(store: WorkoutStore) {
        let calendar = Calendar.current
        let now = Date()

        // 7 workouts over 3 weeks: Push/Pull/Legs/Push/Pull/Legs/Upper
        let schedule: [(daysAgo: Int, type: WorkoutType)] = [
            (20, .push),
            (18, .pull),
            (16, .legs),
            (13, .push),
            (11, .pull),
            (9,  .legs),
            (2,  .upper),
        ]

        for entry in schedule {
            let startDate = calendar.date(byAdding: .day, value: -entry.daysAgo, to: now)!
            let startTime = calendar.date(bySettingHour: 7, minute: 30, second: 0, of: startDate)!
            let duration: TimeInterval = Double.random(in: 3600...4800) // 60-80 min
            let endTime = startTime.addingTimeInterval(duration)

            let week = entry.daysAgo > 14 ? 0 : (entry.daysAgo > 7 ? 1 : 2)
            let template = exerciseTemplate(for: entry.type, week: week)

            let moments = buildMoments(from: template, startTime: startTime)
            let structuredLog = buildStructuredLog(from: template, type: entry.type)

            let session = WorkoutSession(
                startedAt: startTime,
                endedAt: endTime,
                moments: moments,
                structuredLog: structuredLog
            )

            store.saveSession(session)
        }
    }

    // MARK: - Workout Types

    private enum WorkoutType {
        case push, pull, legs, upper
    }

    private struct ExerciseTemplate {
        let name: String
        let sets: [(reps: Int, weight: Double)]
        let transcript: String
    }

    // MARK: - Exercise Templates

    private static func exerciseTemplate(for type: WorkoutType, week: Int) -> [ExerciseTemplate] {
        let progression = Double(week) * 5.0 // +5 lbs per week

        switch type {
        case .push:
            return [
                ExerciseTemplate(
                    name: "Barbell Bench Press",
                    sets: [
                        (reps: 8, weight: 135 + progression),
                        (reps: 8, weight: 135 + progression),
                        (reps: 6, weight: 145 + progression),
                        (reps: 6, weight: 145 + progression),
                    ],
                    transcript: "Bench press, warming up with \(Int(135 + progression)) for a set of 8"
                ),
                ExerciseTemplate(
                    name: "Overhead Press",
                    sets: [
                        (reps: 8, weight: 95 + progression),
                        (reps: 8, weight: 95 + progression),
                        (reps: 6, weight: 100 + progression),
                    ],
                    transcript: "Moving on to overhead press, \(Int(95 + progression)) pounds"
                ),
                ExerciseTemplate(
                    name: "Incline Dumbbell Press",
                    sets: [
                        (reps: 10, weight: 60 + progression),
                        (reps: 10, weight: 60 + progression),
                        (reps: 8, weight: 65 + progression),
                    ],
                    transcript: "Incline dumbbell press, \(Int(60 + progression))s for 10"
                ),
                ExerciseTemplate(
                    name: "Dips",
                    sets: [
                        (reps: 12, weight: 0),
                        (reps: 10, weight: 0),
                        (reps: 10, weight: 0),
                    ],
                    transcript: "Finishing with bodyweight dips, going for 12"
                ),
            ]

        case .pull:
            return [
                ExerciseTemplate(
                    name: "Deadlift",
                    sets: [
                        (reps: 5, weight: 185 + progression),
                        (reps: 5, weight: 205 + progression),
                        (reps: 5, weight: 225 + progression),
                        (reps: 3, weight: 235 + progression),
                    ],
                    transcript: "Deadlift day, starting with \(Int(185 + progression)) for 5"
                ),
                ExerciseTemplate(
                    name: "Pull-ups",
                    sets: [
                        (reps: 8, weight: 0),
                        (reps: 7, weight: 0),
                        (reps: 6, weight: 0),
                    ],
                    transcript: "Pull-ups, aiming for 8 reps"
                ),
                ExerciseTemplate(
                    name: "Barbell Row",
                    sets: [
                        (reps: 8, weight: 115 + progression),
                        (reps: 8, weight: 115 + progression),
                        (reps: 8, weight: 125 + progression),
                    ],
                    transcript: "Barbell rows at \(Int(115 + progression)) pounds"
                ),
                ExerciseTemplate(
                    name: "Face Pulls",
                    sets: [
                        (reps: 15, weight: 30 + progression),
                        (reps: 15, weight: 30 + progression),
                        (reps: 12, weight: 35 + progression),
                    ],
                    transcript: "Face pulls for rear delts, \(Int(30 + progression)) on the cable"
                ),
            ]

        case .legs:
            return [
                ExerciseTemplate(
                    name: "Barbell Squat",
                    sets: [
                        (reps: 8, weight: 155 + progression),
                        (reps: 8, weight: 165 + progression),
                        (reps: 6, weight: 175 + progression),
                        (reps: 6, weight: 175 + progression),
                    ],
                    transcript: "Squats, first working set at \(Int(155 + progression))"
                ),
                ExerciseTemplate(
                    name: "Romanian Deadlift",
                    sets: [
                        (reps: 10, weight: 135 + progression),
                        (reps: 10, weight: 135 + progression),
                        (reps: 8, weight: 145 + progression),
                    ],
                    transcript: "RDLs with \(Int(135 + progression)), focusing on the stretch"
                ),
                ExerciseTemplate(
                    name: "Leg Press",
                    sets: [
                        (reps: 12, weight: 270 + progression * 4),
                        (reps: 12, weight: 270 + progression * 4),
                        (reps: 10, weight: 290 + progression * 4),
                    ],
                    transcript: "Leg press, loading up \(Int(270 + progression * 4)) pounds"
                ),
                ExerciseTemplate(
                    name: "Lying Leg Curls",
                    sets: [
                        (reps: 12, weight: 70 + progression),
                        (reps: 12, weight: 70 + progression),
                        (reps: 10, weight: 80 + progression),
                    ],
                    transcript: "Leg curls at \(Int(70 + progression)), nice and controlled"
                ),
            ]

        case .upper:
            return [
                ExerciseTemplate(
                    name: "Barbell Bench Press",
                    sets: [
                        (reps: 6, weight: 145 + progression),
                        (reps: 6, weight: 155 + progression),
                        (reps: 5, weight: 160 + progression),
                        (reps: 5, weight: 160 + progression),
                    ],
                    transcript: "Upper body day, benching \(Int(145 + progression)) to start"
                ),
                ExerciseTemplate(
                    name: "Barbell Row",
                    sets: [
                        (reps: 8, weight: 125 + progression),
                        (reps: 8, weight: 135 + progression),
                        (reps: 6, weight: 135 + progression),
                    ],
                    transcript: "Rows at \(Int(125 + progression)), keeping it strict"
                ),
                ExerciseTemplate(
                    name: "Dumbbell Shoulder Press",
                    sets: [
                        (reps: 10, weight: 50 + progression),
                        (reps: 10, weight: 50 + progression),
                        (reps: 8, weight: 55 + progression),
                    ],
                    transcript: "DB shoulder press, \(Int(50 + progression))s for 10"
                ),
                ExerciseTemplate(
                    name: "Lat Pulldown",
                    sets: [
                        (reps: 10, weight: 120 + progression),
                        (reps: 10, weight: 130 + progression),
                        (reps: 8, weight: 130 + progression),
                    ],
                    transcript: "Lat pulldowns at \(Int(120 + progression)), full stretch at the top"
                ),
            ]
        }
    }

    // MARK: - Builders

    private static func buildMoments(from templates: [ExerciseTemplate], startTime: Date) -> [Moment] {
        var moments: [Moment] = []
        for (i, template) in templates.enumerated() {
            let offset = TimeInterval(i) * 900 + Double.random(in: 0...120) // ~15 min apart
            let moment = Moment(
                timestamp: startTime.addingTimeInterval(offset),
                transcript: template.transcript,
                source: .phone,
                confidence: Double.random(in: 0.85...0.98)
            )
            moments.append(moment)
        }
        return moments
    }

    private static func buildStructuredLog(from templates: [ExerciseTemplate], type: WorkoutType) -> StructuredLog {
        let exercises = templates.map { template in
            ExerciseGroup(
                exerciseName: template.name,
                sets: template.sets.enumerated().map { i, set in
                    ExerciseSet(
                        setNumber: i + 1,
                        reps: set.reps,
                        weight: set.weight > 0 ? set.weight : nil,
                        weightUnit: .lbs
                    )
                }
            )
        }

        let typeName: String
        switch type {
        case .push: typeName = "Push"
        case .pull: typeName = "Pull"
        case .legs: typeName = "Legs"
        case .upper: typeName = "Upper Body"
        }

        let totalSets = exercises.reduce(0) { $0 + $1.sets.count }
        let totalVolume = exercises.reduce(0.0) { total, group in
            total + group.sets.reduce(0.0) { $0 + (Double($1.reps ?? 0) * ($1.weight ?? 0)) }
        }

        return StructuredLog(
            exercises: exercises,
            summary: "\(typeName) workout — \(exercises.count) exercises, \(totalSets) sets, \(Int(totalVolume)) lbs total volume",
            highlights: buildHighlights(from: templates, type: type)
        )
    }

    private static func buildHighlights(from templates: [ExerciseTemplate], type: WorkoutType) -> [String] {
        var highlights: [String] = []
        if let heaviest = templates.max(by: {
            ($0.sets.map(\.weight).max() ?? 0) < ($1.sets.map(\.weight).max() ?? 0)
        }) {
            let maxWeight = Int(heaviest.sets.map(\.weight).max() ?? 0)
            if maxWeight > 0 {
                highlights.append("Top set: \(heaviest.name) at \(maxWeight) lbs")
            }
        }
        highlights.append("All sets completed with good form")
        return highlights
    }
}
