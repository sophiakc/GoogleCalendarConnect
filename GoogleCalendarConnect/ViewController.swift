//
//  ViewController.swift
//  GoogleCalendarConnect
//
//  Created by Sophia KC on 06/12/2016.
//  Copyright © 2016 Sophia KC. All rights reserved.
//

import UIKit
import GoogleAPIClient
import GTMOAuth2
import AppAuth

class ViewController: UIViewController {
    
    // Variables
    private let kKeychainItemName = "Google Calendar API"
    private let kClientID = "157920455123-i6alke6riu30fkdqqnscit30p8s78rfp.apps.googleusercontent.com"
    private let kRedirectURI = URL(string: "com.googleusercontent.apps.157920455123-i6alke6riu30fkdqqnscit30p8s78rfp:/oauthredirect")
    
    // If modifying these scopes, delete your previously saved credentials by
    // resetting the iOS simulator or uninstall the app.
//    private let scopes = [kGTLAuthScopeCalendarReadonly] // read-only access to Calendars
    private let scopes = [kGTLAuthScopeCalendar] // read/write access to Calendars
    
    private let service = GTLServiceCalendar()
    let output = UITextView()
    
    
    // AppAuth configuration
    let authorizationEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")
    let tokenEndpoint = URL(string: "https://www.googleapis.com/oauth2/v4/token")
    
    var authState: OIDAuthState!
    
    
    // When the view loads, create necessary subviews
    // and initialize the Google Calendar API service
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        // Perform/ initiate the auth request
        let configuration = OIDServiceConfiguration(authorizationEndpoint: authorizationEndpoint!, tokenEndpoint: tokenEndpoint!)
        
        let request = OIDAuthorizationRequest(
            configuration: configuration,
            clientId: kClientID,
            clientSecret: nil,
            scopes: [OIDScopeProfile],
            redirectURL: kRedirectURI!,
            responseType: OIDResponseTypeCode,
            additionalParameters: nil)
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        appDelegate.currentAuthorizationFlow = OIDAuthState.authState(byPresenting: request, presenting: self, callback: {
            (authState: OIDAuthState?, error: Error?) in
            // some code here
            if (authState != nil) {
                print("Got authorization tokens")
                self.authState = authState
            } else {
                print(error?.localizedDescription)
            }
        })
        
       // Handling the Redirect
        func application(_ app: UIApplication, open url: URL, options: [String: Any]) -> Bool {
            // Sends the URL to the current authorization flow (if any) which will
            // process it if it relates to an authorization response.
            appDelegate.currentAuthorizationFlow = nil
            if appDelegate.currentAuthorizationFlow.resumeAuthorizationFlow(with: url) {
                appDelegate.currentAuthorizationFlow = nil
                return true
            }
            // Your additional URL handling (if any) goes here.
            return false
        }
        
        // Making API Calls without worrying about token freshness
//        authState.performAction(freshTokens: { (accessToken: String, idToken: String, error: Error) in
//            if Error != nil {
//                print("Error fetching fresh tokens: \(error.localizedDescription)")
//                return
//            }
//            
//            // perform your API request using the tokens
//
//        } as! OIDAuthStateAction)

        
        
        output.frame = view.bounds
        output.isEditable = false
        output.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0)
        output.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        
        view.addSubview(output);
        
        if let auth = GTMOAuth2ViewControllerTouch.authForGoogleFromKeychain(
            forName: kKeychainItemName,
            clientID: kClientID,
            clientSecret: nil) {
            service.authorizer = auth
        }
        
    }
    
    // When the view appears, ensure that the Google Calendar API service is authorized
    // and perform API calls
    override func viewDidAppear(_ animated: Bool) {
//        if let authorizer = service.authorizer,
//            let canAuth = authorizer.canAuthorize , canAuth {
//            fetchEvents()
//        } else {
//            present(
//                createAuthController(),
//                animated: true,
//                completion: nil
//            )
//        }
    }
    
    // Construct a query and get a list of upcoming events from the user calendar
    func fetchEvents() {
        let query = GTLQueryCalendar.queryForEventsList(withCalendarId: "primary")
        query?.maxResults = 10
        query?.timeMin = GTLDateTime(date: NSDate() as Date!, timeZone: NSTimeZone.local)
        query?.singleEvents = true
        query?.orderBy = kGTLCalendarOrderByStartTime
        service.executeQuery(
            query!,
            delegate: self,
            didFinish: Selector(("displayResultWithTicket:finishedWithObject:error:"))
        )
    }
    
    // Display the start dates and event summaries in the UITextView
    func displayResultWithTicket(
        ticket: GTLServiceTicket,
        finishedWithObject response : GTLCalendarEvents,
        error : NSError?) {
        
        if let error = error {
            showAlert(title: "Error", message: error.localizedDescription)
            return
        }
        
        var eventString = ""
        
        if let events = response.items() , !events.isEmpty {
            for event in events as! [GTLCalendarEvent] {
                let start : GTLDateTime! = event.start.dateTime ?? event.start.date
                let startString = DateFormatter.localizedString(
                    from: start.date,
                    dateStyle: .short,
                    timeStyle: .short
                )
                eventString += "\(startString) - \(event.summary)\n"
            }
        } else {
            eventString = "No upcoming events found."
        }
        
        output.text = eventString
    }
    
    
//    // Creates the auth controller for authorizing access to Google Calendar API
//    private func createAuthController() -> GTMOAuth2ViewControllerTouch {
//        let scopeString = scopes.joined(separator: " ")
//        return GTMOAuth2ViewControllerTouch(
//            scope: scopeString,
//            clientID: kClientID,
//            clientSecret: nil,
//            keychainItemName: kKeychainItemName,
//            delegate: self,
//            finishedSelector: Selector(("viewController:finishedWithAuth:error:"))
//        )
//    }
    
    // Handle completion of the authorization process, and update the Google Calendar API
    // with the new credentials.
    func viewController(vc : UIViewController,
                        finishedWithAuth authResult : GTMOAuth2Authentication, error : NSError?) {
        
        if let error = error {
            service.authorizer = nil
            showAlert(title: "Authentication Error", message: error.localizedDescription)
            return
        }
        
        service.authorizer = authResult
        dismiss(animated: true, completion: nil)
    }
    
    // Helper for showing an alert
    func showAlert(title : String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: UIAlertControllerStyle.alert
        )
        let ok = UIAlertAction(
            title: "OK",
            style: UIAlertActionStyle.default,
            handler: nil
        )
        alert.addAction(ok)
        present(alert, animated: true, completion: nil)
    }
    
       
}

