//
//  Sequence+Logmatic.swift
//
//  Created by Riad Krim on 31/12/2016.
//

import Foundation



// Pending https://bugs.swift.org/browse/SR-1009
// extension Array where Element == Logs
extension Sequence where Iterator.Element == Logs {

    static func mergeSafely(array1: Logs?, array2: Logs?) -> Logs? {
        guard array1 != nil && array2 != nil else {
            return array1 ?? array2
        }
        var mergeArray = array1
        mergeArray! += array2!
        return mergeArray
    }

}
