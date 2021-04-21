//
//  ContentView.swift
//  Resting Heart Rate App WatchKit Extension
//
//  Created by Jonathan Aanesen on 21/04/2021.
//

import HealthKit
import SwiftUI

struct ContentView: View {
    private var healthStore = HKHealthStore()
    let heartRateQuantity = HKUnit(from: "count/min")
    
    @State private var restingHeartRates: Array<Double> = []
    @State private var lastRestingHeartRate: Double = 0.0
    
    var body: some View {
        VStack {
            Text("AVG. RESTING BPM")
                .font(.footnote)
                .fontWeight(.bold)
                .foregroundColor(Color.red)
            Spacer()
            HStack {
                Text(restingHeartRates != [] && restingHeartRates.count >= 7 ? "\(Int(restingHeartRates.average))" : "--")
                    .foregroundColor(Color.white)
                    .font(.system(size: 60))
                Image(systemName: "heart.fill")
                    .font(.title)
                    .foregroundColor(Color.red)
            }
            
            Spacer()
            
            Text("Last 7 days:")
                .font(.footnote)
                .foregroundColor(Color.white)
            
            Spacer()
            
            HStack(spacing: 3) {
                ForEach(restingHeartRates, id: \.self) { num in
                    Text("\(Int(num))")
                        .fontWeight(.regular)
                        .font(.system(size: 13))
                }
            }
            .padding(.horizontal, 3)
            .frame(height: 30, alignment: .center)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.gray, lineWidth: 0.3)
            )
        }
        .onAppear(perform: start)
    }
    
    // MARK: - Start
    
    private func start() {
        guard HKHealthStore.isHealthDataAvailable() else {
            fatalError("*** HealthKit not available ***")
        }
        
        guard let restingHeartRate = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            fatalError("*** Unable to create resting heart rate type ***")
        }
        
        let types: Set<HKSampleType> = [restingHeartRate]
        
        HKHealthStore().requestAuthorization(toShare: nil, read: types) { authorized, error in
            guard authorized else {
                let baseMessage = "HealthKit Authorization Failed"
                
                if let error = error {
                    print("\(baseMessage). Reason: \(error.localizedDescription)")
                } else {
                    print(baseMessage)
                }
                return
            }
            print("HealthKit Successfully Authorized.")
            startHeartRateQuery()
        }
    }
        
    // MARK: - Resting Heart Rate query
    
    private func startHeartRateQuery() {
        let calendar = NSCalendar.current
        
        var anchorComponents = calendar.dateComponents([.day, .month, .year, .weekday], from: NSDate() as Date)
        
        anchorComponents.day! -= 6
        
        guard let anchorDate = Calendar.current.date(from: anchorComponents) else {
            fatalError("*** unable to create a valid date from the given components ***")
        }
        
        let interval = NSDateComponents()
        interval.day = 1
        
        let endDate = Date()
        
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: endDate) else {
            fatalError("*** Unable to calculate the start date ***")
        }
        
        guard let quantityType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.restingHeartRate) else {
            fatalError("*** Unable to create a resting heart rate type ***")
        }
        
        // Create the query
        let query = HKStatisticsCollectionQuery(quantityType: quantityType,
                                                quantitySamplePredicate: nil,
                                                options: .discreteAverage,
                                                anchorDate: anchorDate,
                                                intervalComponents: interval as DateComponents)
        
        // Set the results handlers
        query.initialResultsHandler = {
            _, results, error in
            guard let statsCollection = results else {
                fatalError("*** An error occurred while calculating the statistics: \(error?.localizedDescription ?? "") ***")
            }
            print("Initial resting heart rates updated")
            var values: Array<Double> = []
            // Add the average resting heart rate to array
            statsCollection.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                
                if let quantity = statistics.averageQuantity() {
                    let value = quantity.doubleValue(for: HKUnit(from: "count/min"))
                    values.append(value)
                }
            }
            restingHeartRates = values
        }
        
        query.statisticsUpdateHandler = {
            _, _, results, error in guard let statsCollection = results else {
                fatalError("*** An error occurred while calculating the statistics: \(error?.localizedDescription ?? "") ***")
            }
        
        print("Resting Heart Rates updated")
        var values: Array<Double> = []
        // Add the average resting heart rate to array
        statsCollection.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
            
            if let quantity = statistics.averageQuantity() {
                let value = quantity.doubleValue(for: HKUnit(from: "count/min"))
                values.append(value)
            }
        }
        restingHeartRates = values
        }
        
        healthStore.execute(query)
    }
}

    // MARK: - Extensions

extension Array where Element: BinaryFloatingPoint {
    /// The average value of all the items in the array
    var average: Double {
        if isEmpty {
            return 0.0
        } else {
            let sum = reduce(0, +)
            return Double(sum) / Double(count)
        }
    }
}

