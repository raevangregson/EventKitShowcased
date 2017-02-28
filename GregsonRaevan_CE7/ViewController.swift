//
//  ViewController.swift
//  GregsonRaevan_CE7
//
//  Created by Raevan Gregson on 12/10/16.
//  Copyright © 2016 Raevan Gregson. All rights reserved.
//

import UIKit
import EventKit
import EventKitUI

class ViewController: UIViewController, EKCalendarChooserDelegate, EKEventEditViewDelegate {
    
    //outlets for my UIButtons
    @IBOutlet weak var createButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var calendarChooserButton: UIButton!
    
    
    //eventstore database
    let eventStore = EKEventStore()
    //var to hold my calendar identifier for the currently selected calendar
    var calIdentifier = ""
    //var that to differentiate between default event identifiers or events identifiers created for my user created calendar
    var eventIdentifiers = [String]()
    var defIdentifiers = [String]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        //check what the current authorization status is
        let status = EKEventStore.authorizationStatus(for: .event)
        
        if status == .notDetermined{
            //then request access
            eventStore.requestAccess(to: .event, completion: { (granted, error) in
                if let error = error{
                    print("Request Failed with error: \(error)")
                    return
                }
                if granted{
                    print("Grant Access")
                } else {
                    //disable some UI
                    print("denied access")
                }
            })
        }
        //make sure the calendar chooser isn't enabled until the user creates a calendar
        calendarChooserButton.isEnabled = false
    }
    
    @IBAction func createCalander(_ sender: UIButton) {
        //check status
        let status = EKEventStore.authorizationStatus(for: .event)
        //once again check what the authorization status is,if denied the exit the statements and don't proceed
        if status == .denied{
            return
        }
            // if authorized then create a new event calendar and make sure to save the calendar identifier so it can be referenced
        else if status == .authorized{
            let calendar = EKCalendar(for: .event, eventStore: self.eventStore)
            calendar.title = "User Event Calendar"
            calendar.cgColor = UIColor.purple.cgColor
            calIdentifier = calendar.calendarIdentifier
            calendarChooserButton.isEnabled = true
            //save to a local source A.K.A on the phone itself
            for source in self.eventStore.sources{
                if source.sourceType == EKSourceType.local{
                    //found local source can save to local device
                    calendar.source = source
                    break;
                }
            }
            //save it to the database
            do{
                try self.eventStore.saveCalendar(calendar, commit: true)
            } catch{
                print(error)
            }
        }
        //make sure to enable the correct buttons after creating a calendar so the user can only create one at a time
        createButton.isEnabled = false
        deleteButton.isEnabled = true
    }
    
    //action that gets call when the delete button UI is pushed
    @IBAction func deleteUserCalander(_ sender: UIButton) {
        //to figure out which calendar to delete I use the calendar identifier I used to save it, if I used the calendar chooser to change calendars at this point my calendar identifier should still be updated with the accurateley selected calendar. I also remember to disable the calendar chooser after my calendar is deleted
        let calender = eventStore.calendar(withIdentifier: calIdentifier)
        if ((calender) != nil) {
            if let _ = try? eventStore.removeCalendar(calender!, commit: true){
                self.calendarChooserButton.isEnabled = false
                calIdentifier = ""
            }
        }
        //also I rememeber to enable the correct delete or create button upon deletion of my calendar, in this case we want the create button enabled and the delete disabled
        deleteButton.isEnabled = false
        createButton.isEnabled = true
    }
    
    //the action that is called when the create event UI is pushed
    @IBAction func createEvent(_ sender: UIButton) {
        let eventVC = EKEventEditViewController()
        //when creating an event, I make sure to save the calendaritemidentifier to an array, depending on what my calendar identifier is I save it to an array reserve for default calendar event identifiers or an array reserved for my user calendar events
        eventVC.eventStore = eventStore
        eventVC.editViewDelegate = self
        let ident  = eventVC.event?.calendarItemIdentifier
        if calIdentifier == eventStore.defaultCalendarForNewEvents.calendarIdentifier{
            defIdentifiers.append(ident!)
        }else{
            eventIdentifiers.append(ident!)
        }
        
        
        present(eventVC, animated: true, completion: nil)
        //this is where I set what calendar is selected when the user brings up the add event controller so it populates with whatever they have chosen with the calendar chooser, defaults to the default cal if they haven't created one, or defaults to there custom calendar if they've created one but haven't used the calendar chooser yet to switch between calendars
        if calIdentifier == eventStore.defaultCalendarForNewEvents.calendarIdentifier || calIdentifier == ""{
            eventVC.event?.calendar = eventStore.defaultCalendarForNewEvents
            calIdentifier = eventStore.defaultCalendarForNewEvents.calendarIdentifier
        }
        else{
            eventVC.event?.calendar = eventStore.calendar(withIdentifier: calIdentifier)!
        }
    }
    
    //MARK: - EKEventEditViewDelegate
    //this function is just used when the user hits done and is done with the add event view controller
    func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
        dismiss(animated: true, completion: nil)
    }
    
    //this event is called when the user pushed that calendarchooser UI button
    @IBAction func calanderChooser(_ sender: UIButton) {
        let chooser = EKCalendarChooser(selectionStyle: .single, displayStyle: .allCalendars, entityType: .event, eventStore: eventStore)
        //sets up some UI in this case makes the done button active, and assigns the delegate
        chooser.showsDoneButton = true
        chooser.delegate = self
        
        let nav = UINavigationController(rootViewController: chooser)
        
        
        present(nav, animated: true, completion:nil)
    }
    
    //MARK: - EKCalendarChooserDelegate
    //when the user hits done
    func calendarChooserDidFinish(_ calendarChooser: EKCalendarChooser) {
        print("Done")
        dismiss(animated: true, completion: nil)
    }
    
    //this is the function I use to save the selection the user makes when they do use the calendar chooser, if they make one at all. I make sure to save to the calendar identifier var I have setup
    func calendarChooserSelectionDidChange(_ calendarChooser: EKCalendarChooser) {
        let choice = calendarChooser.selectedCalendars
        let cal = choice.first
        calIdentifier = (cal?.calendarIdentifier)!
    }
    
    //this function is used to delete all events for the particular calendar they are on
    @IBAction func deleteEvents(_ sender: UIButton) {
        //First I differentiate if the user wants to delete events to default cal or their own created cal by checking what the calendar identifier is, then in both I loop through there reserved event ident arrays and remove each value both from the calendar and the array, I remove from the calendar using the same calendar item identifier I saved with.
        if calIdentifier == eventStore.defaultCalendarForNewEvents.calendarIdentifier{
            for value in defIdentifiers{
                do{
                    try eventStore.remove(eventStore.calendarItem(withIdentifier: value) as! EKEvent, span: EKSpan.thisEvent, commit: true)
                    let index = defIdentifiers.index(of: value)
                    defIdentifiers.remove(at: index!)
                }catch{
                    print(error)
                }
            }
            
        }
        else{
            for value in eventIdentifiers{
                do{
                    try eventStore.remove(eventStore.calendarItem(withIdentifier: value) as! EKEvent, span: EKSpan.thisEvent, commit: true)
                    let index = eventIdentifiers.index(of: value)
                    eventIdentifiers.remove(at: index!)
                }catch{
                    print(error)
                }
            }
        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

