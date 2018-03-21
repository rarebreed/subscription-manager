/**
 * This module takes cockpit services, and converts them to streams
 */

import 'rxjs/add/operator/map'
import * as CP from '../types/cockpit.types'

const cockpit: CP.Cockpit = require('cockpit')

export const service = cockpit.dbus('com.redhat.RHSM1', {'superuser': 'require'})

/**
 * Creates a Register
 * @param name 
 * @param socket 
 */
export const socketDbus = (name: string | null, socket: string): CP.RegisterServiceProxy => {
    let opts: CP.DBusOptions = {superuser: 'require', bus: 'none', address: socket}
    return cockpit.dbus(name, opts) as CP.RegisterServiceProxy
}
