import Queenfisher

GMail(using: try AuthToken.loading(fromJSONAt: "/path/to/token"))
.list()
.map {
    print ("got \($0.resultSizeEstimate) messages")
    if let messages = $0.messages {
        for m in messages { // metadata of messages
            print ("id: \(m.id)")
        }
    }
}