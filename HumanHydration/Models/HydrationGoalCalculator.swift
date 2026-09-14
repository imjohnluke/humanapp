import Foundation

/// Produces a transparent adult tracking target rather than a clinical prescription.
enum HydrationGoalCalculator {
    static let gallonML = 3_785

    /// Uses 35 mL/kg as a body-size comparison, with the product's gallon baseline as
    /// the floor. Exercise uses 0.4 L/hour and averages scheduled workouts over 7 days.
    static func dailyGoalML(weightPounds: Double, workoutsPerWeek: Int, workoutMinutes: Int) -> Int {
        let kilograms = max(weightPounds, 0) / 2.204_622_621_8
        let sizeBasedML = kilograms * 35
        return Int((max(Double(gallonML), sizeBasedML)
            + Double(workoutAdjustmentML(workoutsPerWeek: workoutsPerWeek, workoutMinutes: workoutMinutes))).rounded())
    }

    static func workoutAdjustmentML(workoutsPerWeek: Int, workoutMinutes: Int) -> Int {
        Int((400.0 * (Double(max(workoutMinutes, 0)) / 60.0)
            * (Double(min(max(workoutsPerWeek, 0), 7)) / 7.0)).rounded())
    }
}
