//
//  File.swift
//  
//
//  Created by Adhiraj Singh on 5/17/20.
//

import Foundation

public enum BinarySearchResult {
	case behind
	case forward
	case equal
}

public extension Collection {
	
    func binarySearch(where predicate: (Element) -> BinarySearchResult) -> Index {
        var low = startIndex
        var high = endIndex
		
		// take care of base cases
		if count == 0 {
			return low
		}
		if predicate(self[low]) != .forward {
			return low
		}
		switch predicate(self[index(high, offsetBy: -1)]) {
		case .forward:
			return high
		case .equal:
			return index(high, offsetBy: -1)
		default:
			break
		}
		
		// perform binary search
        while low != high {
            let mid = index(low, offsetBy: distance(from: low, to: high)/2)
			switch predicate(self[mid]) {
			case .behind:
				high = mid
				break
			case .forward:
				low = index(after: mid)
				break
			case .equal:
				return mid
			}
        }
		return low
    }
	func binarySearch<T: Comparable>(comparing block: ((Element) -> T), with v1: T) -> Index {
		var index = binarySearch { element in
			let v0 = block(element)
			return v1 < v0 ? .behind : (v0 == v1 ? .equal: .forward)
		}
		while indices.contains(index), block(self[index]) < v1 {
			index = self.index(index, offsetBy: -1)
		}
		return index
	}
}
