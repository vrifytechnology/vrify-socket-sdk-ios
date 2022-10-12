//
//  ChatRoomViewController.swift
//  Basic
//
//  Created by Daniel Rees on 12/22/20.
//  Copyright © 2021 SwiftPhoenixClient. All rights reserved.
//

import UIKit
import SwiftPhoenixClient

struct Shout {
    let name: String
    let message: String
}

/*
 ChatRoom provides a "real" example of using SwiftPhoenixClient, including how
 to use the Rx extensions for it. It also utilizes logic to disconnect/reconnect
 the socket when the app enters and exits the foreground.
 
 NOTE: iOS can, at will, kill your connection if the app enters the background without
 notiftying your process that it has been killed. Thus resulting in a disconnected
 socket when the app comes back to the foreground. The best way around this is to
 listen to UIApplication.didBecomeActiveNotification events and manually check if the socket is still connected
 and attempt to reconnect and rejoin any channels.
 
 In this example, the channel is left and socket is disconnected when the app enters
 the background and then a new channel is created and joined and the socket is connected
 when the app enters the foreground.
 
 This example utilizes the PhxChat example at https://github.com/dwyl/phoenix-chat-example
 */
class ChatRoomViewController: UIViewController {

    // MARK: - Child Views
    @IBOutlet weak var messageInput: UITextField!
    @IBOutlet weak var tableView: UITableView!

    // MARK: - Attributes
    private let username: String = "ChatRoom"
    private let socket = Socket("https://phxchat.herokuapp.com/socket/websocket")
    //  private let socket = Socket(endPoint: "https://phxchat.herokuapp.com/socket/websocket", transport: { url in return StarscreamTransport(url: url) })
    private let topic: String = "room:lobby"

    private var lobbyChannel: Channel?
    private var shouts: [Shout] = []

    // Notifcation Subscriptions
    private var didbecomeActiveObservervation: NSObjectProtocol?
    private var willResignActiveObservervation: NSObjectProtocol?

    //  private let disposeBag = DisposeBag()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.dataSource = self

        // When app enters foreground, be sure that the socket is connected
        self.observeDidBecomeActive()

        Task {
            // Connect to the chat for the first time
            await self.connectToChat()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // When the Controller is removed from the view hierarchy, then stop
        // observing app lifecycle and disconnect from the chat
        self.removeAppActiveObservation()
        self.disconnectFromChat()
    }

    // MARK: - IB Actions
    @IBAction func onExitButtonPressed(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    @IBAction func onSendButtonPressed(_ sender: Any) {
        Task {
            // Create and send the payload
            let payload = ["name": username, "message": messageInput.text!]
            await self.lobbyChannel?.push("shout", payload: payload)
        }

        // Clear the text intput
        self.messageInput.text = ""
    }

    // ----------------------------------------------------------------------
    // MARK: - Background/Foreground reconnect strategy
    // ----------------------------------------------------------------------
    private func observeDidBecomeActive() {
        // Make sure there's no other observations
        self.removeAppActiveObservation()

        self.didbecomeActiveObservervation = NotificationCenter.default
            .addObserver(forName: UIApplication.didBecomeActiveNotification,
                         object: nil,
                         queue: .main) { [weak self] _ in
                Task {
                    await self?.connectToChat()
                }
            }

        // When the app resigns being active, the leave any existing channels
        // and disconnect from the websocket.
        self.willResignActiveObservervation = NotificationCenter.default
            .addObserver(forName: UIApplication.willResignActiveNotification,
                         object: nil,
                         queue: .main) { [weak self] _ in self?.disconnectFromChat() }
    }

    private func removeAppActiveObservation() {
        if let observer = self.didbecomeActiveObservervation {
            NotificationCenter.default.removeObserver(observer)
            self.didbecomeActiveObservervation = nil
        }

        if let observer = self.willResignActiveObservervation {
            NotificationCenter.default.removeObserver(observer)
            self.willResignActiveObservervation = nil
        }
    }

    private func connectToChat() async {
        // Setup the socket to receive open/close events
        socket.delegateOnOpen(to: self) { (_) in
            print("CHAT ROOM: Socket Opened")
        }

        socket.delegateOnClose(to: self) { (_) in
            print("CHAT ROOM: Socket Closed")

        }

        socket.delegateOnError(to: self) { (_, error) in
            print("CHAT ROOM: Socket Errored. \(error)")
        }

        socket.logger = { msg in print("LOG:", msg) }

        // Setup the Channel to receive and send messages
        let channel = await socket.channel(topic, params: ["status": "joining"])
        //    channel.rx
        //      .on("shout")
        //      .observeOn(MainScheduler.asyncInstance)
        //      .subscribe( onNext: { (message) in
        //        let payload = message.payload
        //        guard
        //          let name = payload["name"] as? String,
        //          let message = payload["message"] as? String else { return }
        //
        //        let shout = Shout(name: name, message: message)
        //        self.shouts.append(shout)
        //
        //        let indexPath = IndexPath(row: self.shouts.count - 1, section: 0)
        //        self.tableView.reloadData() //reloadRows(at: [indexPath], with: .automatic)
        //        self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
        //      }).disposed(by: disposeBag)

        // Now connect the socket and join the channel
        self.lobbyChannel = channel
        await self.lobbyChannel?
            .join()
            .delegateReceive("ok", to: self, callback: { (_, _) in
                print("CHANNEL: rooms:lobby joined")
            })
            .delegateReceive("error", to: self, callback: { (_, message) in
                print("CHANNEL: rooms:lobby failed to join. \(message.payload)")
            })

        self.socket.connect()
    }

    private func disconnectFromChat() {
        Task {
            if let channel = self.lobbyChannel {
                await channel.leave()
                await self.socket.remove(channel)
            }

            self.socket.disconnect()
            self.shouts = []
        }
    }
}

extension ChatRoomViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.shouts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "shout_cell")

        let shout = self.shouts[indexPath.row]

        cell.textLabel?.text = shout.message
        cell.detailTextLabel?.text = shout.name

        return cell
    }
}
