/**
 * 
 */
import * as CP from '../../../../src/types/cockpit.types'
import 'rxjs/add/operator/mergeMap'
import 'rxjs/add/operator/toPromise'
import 'rxjs/add/operator/map'
import 'rxjs/add/observable/fromPromise'
import 'jasmine'

const cockpit: CP.Cockpit = require('cockpit')

export const registerStart = () => {
    const service = cockpit.dbus('com.redhat.RHSM1', {'superuser': 'require'})
    // Create the Register Server Proxy and Service
    const regPxy: CP.RegisterServerServiceProxy = service.proxy(CP.REGISTER_SERVER_IFC, CP.REGISTER_SERVER_OBJ)
    const regServerSvc: CP.RegisterServerService = new CP.RegisterServerService(regPxy)

    // Create a stream of the Options (this will emulate data coming from the modal dialog)
    // FIXME: Note, these are real values from the Ethel stage server, which means I dont know if these tests 
    // should be released upstream, since upstream users will not have access.  Another alternative would be
    // to point Register Server to a different candlepin instance
    let args = {
        user: '',
        org: '',
        pw: '',
        opts: {
            host: 'subscription.rhsm.stage.redhat.com',
            port: 443
        },
        connect: {

        }
    }

    // Step 1. The stream contains an Observable which in turn was created from this.proxy.wait().  When we call
    // mergeMap, the argument is an Observable<void> (because calling proxy.wait() returns a Promise<void>).  This
    // means that when the proxy's wait() is done, it is ready to be used.  So we can call the proxy.Start()
    return regServerSvc.start(args)
        .map(p => {
            // Step 2. Since map() above returned an Observable<string>, we use mergeMap to pull out inner string
            console.log(`Response from DBus Register method: ${p}`)
            return p
        })
        .map(s => {
            // Step 3. Actually make an assertion that the Register() worked
            console.log('Making assertion')
            expect(s).toBeDefined()
        })
        .toPromise()  // Step 4.  Jest doesn't know Observables, so return a Promise
}