//
//  TestUtils.swift
//  
//
//  Created by Adhiraj Singh on 5/15/20.
//

import Foundation
import AsyncHTTPClient

/// url for attachments
let testAttachmentsUrl = URL(fileURLWithPath: "./Tests/QueenfisherTests/TestAttachments")
/// url for credentials folder
let testUrl = URL(fileURLWithPath: "./Tests/QueenfisherTests/Keys")

/// file for test service account credentials
let testCredsFileUrl = testUrl.appendingPathComponent("service_acc_creds.json")
/// file for test service account credentials
let testClientFileUrl = testUrl.appendingPathComponent("client_secret.json")
/// file for test service account credentials
let testApiKeyUrl = testUrl.appendingPathComponent("apikey.json")
/// test spreadsheet ID for spreadsheet tests
let testSpreadsheetId = "1bnv_3HHTXO9kDe4V11OwvbgZw8Ie5Rb0_kjJz8Xs8l8"

private var client: HTTPClient?

func getHttpClient () -> HTTPClient {
	if client == nil {
		client = HTTPClient(eventLoopGroupProvider: .createNew)
	}
	return client!
}
