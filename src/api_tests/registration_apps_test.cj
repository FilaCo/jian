package jian.api_tests

import jian.*

// The parent deliberately mounts its child before the other file registers commands.
let registeredUsers = JianApp(help: "Registered users")
let registeredApp = JianApp(name: "demo").add(registeredUsers, name: "users")
