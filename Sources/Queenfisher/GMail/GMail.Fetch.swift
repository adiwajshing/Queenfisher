//
//  GMail.Fetch.swift
//  
//
//  Created by Adhiraj Singh on 5/22/20.
//

import Foundation
import NIO

public extension GMail {
	
	/**
	Periodically fetch new emails
	- Parameter interval: how often to fetch
	- Parameter q: search parameters for which emails to fetch
	- Parameter lastMailFetched: Date after which to get emails
	- Parameter onUnreadMessages: Callback for when new messages are fetched
	*/
	func fetch (over interval: DispatchTimeInterval = .seconds(60),
				q: String = "is:unread",
				lastMailFetched: Date? = nil,
				onUnreadMessages: @escaping (Result<[Message], Error>) -> Void) {
		serialQueue.sync {
			if fetchTimer != nil {
				fetchTimer.cancel()
			}
			lastFetchDate = lastMailFetched ?? Date(timeIntervalSince1970: 0)
			fetchQuery = q
			
			fetchTimer = DispatchSource.makeTimerSource(queue: serialQueue) // make sure its a serial queue
			fetchTimer.schedule(deadline: .now(), repeating: interval, leeway: .seconds(1))
			fetchTimer.setEventHandler { [weak self] in
				self?.actuallyFetch(onUnreadMessages)
			}
			fetchTimer.resume()
		}
	}
	private func actuallyFetch (_ onUnreadMessages: @escaping (Result<[Message], Error>) -> Void) {
		if isFetching {
			return
		}
		
		isFetching = true
		var query = fetchQuery
		if lastFetchDate.timeIntervalSince1970 > 0.0 {
			if !query.isEmpty {
				query += " "
			}
			// only fetch emails received after the last fetch
			let lastFetchEpoch = Int(lastFetchDate.timeIntervalSince1970)
			query += "after:\(lastFetchEpoch)"
		}
		
		listAll(q: query)
		.map { m -> [GMail.Messages.MessageMeta] in
			self.lastFetchDate = Date()
			return m.messages ?? []
		}
		.flatMapThrowing {
			EventLoopFuture.whenAllSucceed($0.map { self.get(id: $0.id, format: .full) },
										   on: self.client.eventLoopGroup.next())
		}
		.whenComplete {
			onUnreadMessages ($0)
			self.isFetching = false
		}
	}
	
	
	func stopFetch () {
		serialQueue.sync {
			fetchTimer?.cancel()
			fetchTimer = nil
		}
	}
}
