import Foundation
import HealthKit
import os

@Observable
@MainActor
final class HealthKitService {
    private static let logger = Logger(subsystem: "com.whussey.momentary", category: "HealthKitService")

    private let healthStore = HKHealthStore()
    #if os(watchOS)
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    #endif

    var heartRate: Double = 0
    var activeCalories: Double = 0
    var isAuthorized = false
    var workoutUUID: UUID?

    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async {
        guard isHealthKitAvailable else { return }

        let typesToWrite: Set<HKSampleType> = [
            HKQuantityType.workoutType()
        ]

        let typesToRead: Set<HKObjectType> = [
            HKQuantityType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned)
        ]

        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            isAuthorized = true
        } catch {
            Self.logger.error("HealthKit authorization failed: \(error)")
        }
    }

    #if os(watchOS)
    func startWorkout() async {
        guard isHealthKitAvailable else { return }

        if !isAuthorized {
            await requestAuthorization()
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

            self.workoutSession = session
            self.workoutBuilder = builder

            session.startActivity(with: Date())
            try await builder.beginCollection(at: Date())

            workoutUUID = session.currentActivity.uuid

            Self.logger.info("HealthKit workout started")
        } catch {
            Self.logger.error("Failed to start HealthKit workout: \(error)")
        }
    }

    func endWorkout() async {
        guard let session = workoutSession, let builder = workoutBuilder else { return }

        session.end()

        do {
            try await builder.endCollection(at: Date())
            try await builder.finishWorkout()
            Self.logger.info("HealthKit workout finished")
        } catch {
            Self.logger.error("Failed to end HealthKit workout: \(error)")
        }

        workoutSession = nil
        workoutBuilder = nil
    }
    #else
    func startWorkout() async {
        guard isHealthKitAvailable, !isAuthorized else {
            if !isAuthorized { await requestAuthorization() }
            return
        }
        // On iPhone without watch, we'll save a post-hoc workout on end
    }

    func endWorkout() async {
        // Save a post-hoc workout using HKWorkoutBuilder if needed
    }
    #endif
}
