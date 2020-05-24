# Queenfisher - Cross-Platform Google APIs for Swift

## What's Done:
- [x] Authenticating using OAuth & using refresh tokens to continually fetch new access tokens
- [x] Authenticating using a service account
- [x] **GMail** -- reading, modifying, fetching, sending & replying to emails
- [x] **Spreadsheets** -- reading, modifying & writing to sheets 
- [x] Synchronize & maintain a database on Sheets

## Installing

1. Queenfisher is written in Swift 5, so you need either **XCode 11** or **Swift 5.0** installed on your system.
2. Add Queenfisher to your swift package: 
``` swift
	...
	dependencies: [
		// Dependencies declare other packages that this package depends on.
		.package(url: "https://github.com/adiwajshing/Queenfisher.git", from: "0.1.0")
	],
	targets: [
		.target(name: "MyTarget", dependencies: ["Queenfisher", ...])
	]
	...
```
3. Finally, import **Queenfisher** in your code using:
``` swift
	import Queenfisher
```

## Authenticating with Google

1. Before you can use these APIs, you need to have a project setup on Google Cloud Platform, you can create one [here](https://console.developers.google.com/projectcreate). 
2. Once you have a project setup, you must enable the APIs you want to use. **Queenfisher** currently wraps around the [GMail](https://developers.google.com/gmail/api/v1/reference) & [Sheets]() API, so you can enable either or both.
3. To authenticate using [O-Auth](https://developers.google.com/identity/protocols/oauth2/web-server)
	- Create & download your client secret, learn how to do that [here](https://developers.google.com/identity/protocols/oauth2/web-server#creatingcred).
	- Store the downloaded JSON somewhere nice & safe.
	- Now you can load the JSON & generate an access token:
	``` swift
	import Queenfisher
	import Promises
	
	let pathToSecret = URL(fileURLWithPath: "Path/to/client_secret.json")
	let pathToToken = URL(fileURLWithPath: "Path/to/my_token.json") // place to save the generated token
	
	let client: GoogleOAuthClient = try .loading(from: pathToSecret)
	// generate the authentication url where you can sign in & get your access token
	let authUrl = client.authUrl(for: .mailAll + .sheets) // authenticate for full access to mail & spreadsheets
	print ("sign in here & paste the code from the link below: \(authUrl)") // open the url in a browser
	/*
		Once you sign off on the permissions, google will redirect you to the url you specified in the client secret
		If you don't have a server listening, you can just extract the code & paste it here, and you will get your access & refresh tokens
		The code will be in the url query like: http://localhost:8080?code=abcdefg&scope=blahblah
		Paste `abcdefg` below
	*/
	let code = readLine(strippingNewline: true)!
	let accessToken = try await(client.fetchToken(fromCode: code)) // will exchange code for access & refresh tokens
	print("got access token: \($0)")
	
	/* You can now use this access token for sheets or gmail */
	
	try JSONEncoder().encode(accessToken).write(to: pathToToken) // save the token as a JSON
	```
	- To continually ensure you have an active token, you can [create a factory](https://developers.google.com/identity/protocols/oauth2/web-server#offline). New tokens are fetched using the refresh token whenever one expires. Do note, that refresh tokens never expire, they stop working whenever the user revokes access to your GCP project.
	``` swift
	// get your client secret
	let client: GoogleOAuthClient = try .loading(from: pathToSecret)
	// create an authentication factory using the access token & secret
	let authFactory = try client.factory(usingAccessToken: .loading(fromJSONAt: pathToToken))
	/*
	Use authFactory as your access mediator when accessing APIs. 
	This will ensure you always have an active access token
	*/
	```
4. To authenticate using a [Service Account](https://developers.google.com/identity/protocols/oauth2/service-account):
	- Create a service account or use one you already have, learn about creating one [here](https://developers.google.com/identity/protocols/oauth2/service-account#creatinganaccount).
	- Download the credentials of said service account.
	``` swift
	import Queenfisher
	
	let pathToAcc = URL(fileURLWithPath: "Path/to/service_account.json")
	let serviceAcc: GoogleServiceAccount = try .loading(fromJSONAt: pathToAcc)
	
	let authFactory = serviceAcc.factory (forScope: .sheets) // get authentication for sheets
	/*
	Use authFactory as your access mediator when accessing APIs. 
	This will ensure you always have an active access token
	*/
	```
	
## Accessing GMail

- Create an instance
	``` swift
	import Queenfisher
	import Promises
	
	// create an authentication factory using the access token & secret
	// make sure your token has access to GMail
	// do note, service accounts cannot access GMail unless with GSuite accounts
	let client: GoogleOAuthClient = try .loading(from: pathToSecret)
	let authFactory = try client.factory(usingAccessToken: .loading(fromJSONAt: pathToToken))
	
	let gmail: GMail = .init(using: authFactory)
	
	let profile = try await(gmail.profile())
	print ("Oh hello: \(profile.emailAddress)") // print email address
	```
- [Listing emails](https://developers.google.com/gmail/api/v1/reference/users/messages/list)
	``` swift
	gmail.list() // lists all messages in inbox, sent & drafts ordered by timestamp
	.then (on: .global()) { // handle promise on global dispatch queue
		print ("got \($0.resultSizeEstimate) messages")
		if let messages = $0.messages {
			for m in messages { // metadata of messages
				print ("id: \(m.id)")
			}
		}
	}
	```
	You can refine your search by specifying query parameters mentioned [here](https://support.google.com/mail/answer/7190?hl=en). For example:
	``` swift
	gmail.list(q: "is:unread") // lists all unread messages
	gmail.list(q: "subject:permission") // subject contains the word `permission`
	gmail.list(q: "from:xyz@yahoo.com") // all emails from this email address
	```
- [Reading emails](https://developers.google.com/gmail/api/v1/reference/users/messages/get)
	``` swift
	gmail.list() // lists all messages in inbox, sent & drafts ordered by timestamp
	.then (on: .global()) { gmail.get(id: $0.messages![0].id, format: .full) } // get the first email received
	.then (on: .global()) { 
		print ("email from: \($0.from!)") 
		print ("email subject: \($0.subject!)") 
		print ("email snippet: \($0.snippet!)") 
	}
	```
	Dive deeper into the [GMail.Message](Sources/Queenfisher/GMail/GMail.Message.swift) class to get the attachements & the entire text of the email.
- [Sending emails](https://developers.google.com/gmail/api/v1/reference/users/messages/send)
	``` swift
	let attachFile = URL(fileURLWithPath: "Path/to/fave_image.jpeg")
	
	let mail: GMail.Message = .init(to: [ .namedEmail("Myself & I", profile.emailAddress) ],
									subject: "Hello",
									text: "My name <b>Jeff</b>.",
									attachments: [ try! .attachment(fileAt: attachFile) ])
	
	gmail.send (message: mail)
	.then (on: .global()) { print ("yay sent mail with ID: \($0.id)") }
	.catch (on: .global()) { print ("error in sending: \($0)") }
	```
	The `text` in emails must be some html text.
- [Replying to emails](https://developers.google.com/gmail/api/v1/reference/users/messages/send)
	``` swift
	let profile = try await(gmail.profile()) // get profile
	gmail.list()
	.then (on: .global()) { gmail.get(id: $0.messages![0].id, format: .full) } // get the first email received
	.then (on: .global()) { message -> Promise<GMail.Message> in
		let isMailFromMe = $0.from!.email == profile.emailAddress // determine if the email was sent by me
		let reply: GMail.Message = GMail.Message(replyingTo: message, 
												fromMe: isMailFromMe, 
												text: "Wow this is a reply")!
		return gmail.send (message: reply)
	}
	.then (on: .global()) { print ("yay sent reply with ID: \($0.id)") }
	```
- Fetching Emails
	``` swift
	// fetch unread emails every 60 seconds
	// note: once a mail is forwarded to this handler, it will not be forwarded again in the future
	gmail.fetch(over: .seconds(60), q: "is:unread") { result in
		switch result {
		case .success(let messages):
			print ("got \(messages.count) new messages")
			break
		case .failure(let error):
			print("Oh no, got an error: \(error)")
			break
		}
	}
	```
- Misc Tasks
	* [Marking emails as read](https://developers.google.com/gmail/api/v1/reference/users/messages/modify)
	``` swift
		gmail.markRead (id: idOfTheMessage)
		.then (on: .global()) { print ("yay read mail with ID: \($0.id)") }
	```
	* [Trashing emails](https://developers.google.com/gmail/api/v1/reference/users/messages/trash)
	``` swift
		gmail.trash (id: idOfTheMessage)
		.then (on: .global()) { print ("yay trashed mail with ID: \($0.id)") }
	```
	* [Modifying labels on emails](https://developers.google.com/gmail/api/v1/reference/users/messages/modify)
	``` swift
		gmail.modify (id: idOfTheMessage, adddingLabelIds: ["UNREAD"]) // effectively mark an email as unread
		.then (on: .global()) { print ("yay modified mail with ID: \($0.id)") }
	```

## Sheets

Haven't documented it yet :/
