
import * as CP from '../../../../src/types/cockpit.types'
import { Observable } from 'rxjs/Observable'
import 'rxjs/add/operator/mergeMap'
import 'rxjs/add/operator/toPromise'
import { socketDbus } from '../../../../src/libs/cockpit.helpers'
import 'jasmine'

const cockpit: CP.Cockpit = require('cockpit')

describe('Check that we can Register with subscription-manager', function() {

    const service = cockpit.dbus('com.redhat.RHSM1', {'superuser': 'require'})
    
    it('Should create a unix socket when we register', function() {
        // Create the Register Server Proxy and Service
        const regPxy: CP.RegisterServerServiceProxy = service.proxy(CP.REGISTER_SERVER_IFC, CP.REGISTER_SERVER_OBJ)
        const regServerSvc: CP.RegisterServerService = new CP.RegisterServerService(regPxy)

        // Create a stream of the Options (this will emulate data coming from the modal dialog)
        // FIXME: Note, these are real values from the Ethel stage server, which means I dont know if these tests 
        // should be released upstream, since upstream users will not have access.  Another alternative would be
        // to point Register Server to a different 
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

        return Observable.fromPromise(regServerSvc.proxy.Start(navigator.language))
            .map(socket => {
                // Step 1. Create a RegisterServiceProxy.  This proxy is a bit weird, in that it requires unusual args 
                let socketPxy: CP.RegisterServiceProxy = socketDbus(null, socket)
                console.log('Created Register Server Proxy')
                // Step 2. Call the Register method from our Proxy, and return
                return Observable.fromPromise(socketPxy.Register(args.org, args.user, args.pw, args.opts, args.connect))
            })
            .mergeMap(p => {
                // Step 3. Since map() above returned an Observable<string>, we use mergeMap to pull out inner string
                console.log(`Response from DBus Register method: ${p}`)
                return p
            })
            .map(s => {
                // Step 4. Actually make an assertion that the Register() worked
                console.log('Making assertion')
                expect(s).toBeDefined()
            })
            .toPromise()  // Step 5.  Jest doesn't know Observables, so return a Promise
    })
})
