//
//  SKBatcher.swift
//
//  Created by Scott J. Kleper on 12/21/16.
//

import Foundation
import SwiftyJSON

public class SKBatcher {
    
    let apiCall: (([Int], ((JSON?) -> Void)) -> Void)
    
    public var allIds = [Int]() {
        didSet {
            cache = [Int: AnyObject]()
        }
    }

    var cache = [Int: AnyObject]()
    var completionHandlers: [Int: [((AnyObject) -> Void)?]] = [:]
    
    public init(apiCall: (([Int], ((JSON?) -> Void)) -> Void)) {
        self.apiCall = apiCall
    }

    func idIsPending(id: Int) -> Bool {
        return cache[id] is Bool
    }
    
    func cachedValueForId(id: Int) -> AnyObject? {
        guard !(cache[id] is Bool) else { return nil }
        
        if let value = cache[id] {
            return value
        }
        return nil
    }

    public func fetch(id: Int, completion: (AnyObject) -> Void) {
        if let cachedValue = cachedValueForId(id) {
            completion(cachedValue)
            return
        }

        if completionHandlers[id] == nil {
            completionHandlers[id] = []
        }
        completionHandlers[id]!.append(completion)

        if idIsPending(id) {
            return
        }

        // Batch up the next 10, but omit any that are already pending
        var batch = [Int]()
        batch.append(id)
        cache[id] = true
        if let loc = allIds.indexOf(id) {
            allIds[loc..<min(loc+10, allIds.count)].forEach({ (id) in
                if !idIsPending(id) {
                    batch.append(id)
                    cache[id] = true
                }
            })
        }

        apiCall(batch) { (json) in
            if let results = json?.dictionary {
                results.keys.forEach{ id in
                    if let excerpt = results[id] {
                        self.cache[Int(id)!] = excerpt.object
                        if let handlers = self.completionHandlers[Int(id)!] {
                            handlers.forEach({ (handler) in
                                handler?(excerpt.object)
                            })
                        }
                        self.completionHandlers[Int(id)!] = []
                    }
                }
            }
        }
    }
    
}
