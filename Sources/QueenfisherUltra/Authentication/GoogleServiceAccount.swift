//
//  File.swift
//  
//
//  Created by Adhiraj Singh on 5/16/20.
//

import Foundation
import SwiftJWT
import Promises

/// Google Service Account to use for authentication. See https://developers.google.com/identity/protocols/oauth2/service-account
public class GoogleServiceAccount: Codable, AuthenticationFactory {
	/// The JWT Claim
	struct Claim: Claims {
		let iss: String
		let aud: URL
		let exp: Date
		let iat: Date
		let scope: GoogleScope
	}
	/// account type, ("service_account" in this class)
	public let type: String
	/// private key identifier
	public let privateKeyId: String
	/// private key data in a .pem format
	public let privateKey: String
	/// email of the service account
	public let clientEmail: String
	public let clientId: String
	public let clientX509CertUrl: URL
	/// URL to request authentication from
	public let tokenUri: URL
	
	lazy var apiKeys = { [GoogleScope:Promise<GoogleAPIKey>]() }()
	lazy var queue: DispatchQueue = { .init(label: "", attributes: []) }()
	
	func getKey (scope: GoogleScope) throws -> Promise<GoogleAPIKey> {
		/*
			Structure of JWT & Claims from https://developers.google.com/identity/protocols/oauth2/service-account#authorizingrequests
		*/
		let claim = Claim (iss: clientEmail,
						   aud: tokenUri,
						   exp: Date (timeIntervalSinceNow: 60*60), // expire access token in 60 minutes
						   iat: Date (),
						   scope: scope)
		var jwt = JWT (header: .init (typ: "JWT"), claims: claim) // generate a JWT token
		let signer = JWTSigner.rs256(privateKey: privateKey.data(using: .utf8)!) // signer using RS256, and our private key
		let signed = try jwt.sign(using: signer) // sign the token
		
		let body = ["grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", // Google requires this
					"assertion": signed]
		return try tokenUri.httpRequest(headers: [:], body: body, errorType: GoogleAuthenticationError.self)
	}
}
