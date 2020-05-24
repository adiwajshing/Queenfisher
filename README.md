# Queenfisher - Cross-Platform Google APIs for Swift

## What is done:
- [x] Authenticating using OAuth & using refresh tokens to continually fetch new access tokens
- [x] Authenticating using a service account
- [x] G-Mail -- reading, modifying & sending mails
- [x] Spreadsheets -- reading, modifying & sending mails
- [x] Synchronize a database on Google Sheets

## Installing

1. Queenfisher is written in Swift 5, so you need either **XCode 11** or **Swift 5.0** installed on your system.
2. Add Queenfisher to your swift package by adding it as a dependency: 
``` swift
	...
	dependencies: [
		// Dependencies declare other packages that this package depends on.
		.package(url: "https://github.com/adiwajshing/Queenfisher.git", from: "0.1.0")
	],
	targets: [
		.target(name: "MyTarger", dependencies: ["Queenfisher", ...])
	]
	...
```
3. Finally, import **Queenfisher** in your code using:
``` swift
	import Queenfisher
```

## Authenticating with Google

1. Before you can use these APIs, you need to have a project setup on Google Cloud Platform, you can create one [here](https://console.developers.google.com/projectcreate). 
2. Once you have a project setup, you must enable the APIs you want to use. **Queenfisher** currently wraps around the GMail & Sheets API, so you can enable either or both.
3. To authenticate using [O-Auth](https://developers.google.com/identity/protocols/oauth2/web-server)
	- Create & download your client secret, learn how to do that [here](https://developers.google.com/identity/protocols/oauth2/web-server#creatingcred).
	- Store the downloaded JSON somewhere nice & safe.
	- Now you can load the JSON & generate an access token:
	``` swift
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
	let pathToAcc = URL(fileURLWithPath: "Path/to/service_account.json")
	let serviceAcc: GoogleServiceAccount = try .loading(fromJSONAt: pathToAcc)
	
	let factory = serviceAcc.factory (forScope: .sheets) // get authentication for sheets
	```

## Accessing GMail
