//
// AdHocCommandsModule.swift
//
// TigaseSwift
// Copyright (C) 2017 "Tigase, Inc." <office@tigase.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License,
// or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. Look for COPYING file in the top folder.
// If not, see http://www.gnu.org/licenses/.
//

import Foundation

extension XmppModuleIdentifier {
    public static var adhoc: XmppModuleIdentifier<AdHocCommandsModule> {
        return AdHocCommandsModule.IDENTIFIER;
    }
}

open class AdHocCommandsModule: XmppModule, ContextAware {
    
    public static let COMMANDS_XMLNS = "http://jabber.org/protocol/commands";
    
    public static let ID = COMMANDS_XMLNS;
    public static let IDENTIFIER = XmppModuleIdentifier<AdHocCommandsModule>();
    
    public let criteria = Criteria.empty();
    
    open var context: Context!;
    
    public let features = [String]();
    
    public init() {
    }
    
    open func process(stanza: Stanza) throws {
        throw ErrorCondition.feature_not_implemented;
    }
    
    open func execute(on to: JID?, command node: String, action: Action?, data: JabberDataElement?, completionHandler: @escaping (AdHocResult)->Void) {
        let iq = Iq();
        iq.type = .set;
        iq.to = to;
        
        let command = Element(name: "command", xmlns: AdHocCommandsModule.COMMANDS_XMLNS);
        command.setAttribute("node", value: node);
        
        if data != nil {
            command.addChild(data!.submitableElement(type: XDataType.submit));
        }
        
        iq.addChild(command);
        
        context.writer?.write(iq, callback: { response in
            guard let stanza = response, stanza.type == .result else {
                completionHandler(.failure(errorCondition: response?.errorCondition ?? .remote_server_timeout));
                return;
            }
            
            guard let command = stanza.findChild(name: "command", xmlns: AdHocCommandsModule.COMMANDS_XMLNS) else {
                completionHandler(.failure(errorCondition: .undefined_condition));
                return;
            }
            
            let form = JabberDataElement(from: command.findChild(name: "x", xmlns: "jabber:x:data"));
            let actions = command.findChild(name: "actions")?.mapChildren(transform: { Action(rawValue: $0.name) }) ?? [];
            let notes = command.mapChildren(transform: { Note.from(element: $0) });
            let status = Status(rawValue: command.getAttribute("status") ?? "") ?? Status.completed;
            completionHandler(.success(status: status, form: form, actions: actions, notes: notes));
        });
    }
    
    public enum Status: String {
        case executing
        case completed
        case canceled
    }
    
    public enum Action: String {
        case cancel
        case complete
        case execute
        case next
        case prev
    }
    
    public enum Note {
        case info(message: String)
        case warn(message: String)
        case error(message: String)
        
        static func from(element: Element) -> Note? {
            guard element.name == "note" else {
                return nil;
            }
            switch element.getAttribute("type") ?? "info" {
            case "warn":
                return .warn(message: element.value ?? "");
            case "error":
                return .error(message: element.value ?? "");
            default:
                return .info(message: element.value ?? "");
            }
        }
    }
}

public enum AdHocResult {
    case success(status: AdHocCommandsModule.Status, form: JabberDataElement?, actions: [AdHocCommandsModule.Action], notes: [AdHocCommandsModule.Note])
    case failure(errorCondition: ErrorCondition)
}
