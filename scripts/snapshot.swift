#!/usr/bin/env swift
// Debug builds only: asks a running kDownloader to render its windows as PNG
// files, or to trigger a menu item by its title.
// Usage: scripts/snapshot.swift <output-directory>
//        scripts/snapshot.swift --menu <item title>
//        scripts/snapshot.swift --session <command>   (type:<text>, analyze, cancel, retry, …)
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())
let (name, object): (String, String)
switch arguments.count {
case 1: (name, object) = ("com.kozian.kDownloader.debug.snapshot", arguments[0])
case 2 where arguments[0] == "--menu": (name, object) = ("com.kozian.kDownloader.debug.menu", arguments[1])
case 2 where arguments[0] == "--session": (name, object) = ("com.kozian.kDownloader.debug.session", arguments[1])
default:
    print("usage: snapshot.swift <output-directory> | --menu <item title> | --session <command>")
    exit(2)
}
DistributedNotificationCenter.default().postNotificationName(
    Notification.Name(name), object: object, userInfo: nil, deliverImmediately: true
)
