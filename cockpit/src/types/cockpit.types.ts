import { Observable } from 'rxjs/Observable'
import 'rxjs/add/observable/fromPromise'
import { Map as IMap } from 'immutable' 
const cockpit: Cockpit = require('cockpit')

////////////////////////////////////////////////////////////////////////////////////////////////
// _ServiceProxy interfaces
///////////////////////////////////////////////////////////////////////////////////////////////

/**
 * The DBusProxy interface describes the attributes returned from a client.proxy() in the cockpit.dbus API
 * 
 */
export interface DBusProxy {
    proxy: <T>(iface?: string, path?: string) => T
    wait: <T>(callback?: any) => Promise<T>
    close: (code?: string) => void
    options: DBusOptions
    unique_name: string | null
    onclose?: Event
    onowner?: Event
    client: string
    path: string
    iface: string
    valid: boolean
    data: {}
}

/**
 * The ConfigServiceProxy describes the methods available when 
 */
export interface ConfigServiceProxy extends DBusProxy {
    Get: (section: string, name: string) => Promise<{t: string, v: string}>
    GetAll: (section: string) => Promise<string[]>
    Set: (name: string, value: any) => Promise<void>
}

export interface RegisterServerServiceProxy extends DBusProxy {
    Start: (lang: string) => Promise<string>
    Stop: () => Promise<string>
}

/**
 * This is an interface that can be passed as the fourth argument to the Register method in 
 * RegisterServiceProxy.
 * 
 * See http://www.candlepinproject.org/docs/subscription-manager/dbus_objects.html#methods-5
 */
export interface RegisterOptions {
    force?: boolean
    name?: string
}

export interface RegisterOptionsFull extends RegisterOptions {
    consumerid?: string
    environment?: string
}

/**
 * This is an interface that can be passed as the fifth argument to the Register method in 
 * RegisterServiceProxy
 * 
 * See http://www.candlepinproject.org/docs/subscription-manager/dbus_objects.html#methods-5
 */
export interface RegisterConnectOptions {
    host?: string      // the subscription management server host
    port?: number      // the subscription management server port
    handler?: string   // the context of the subscription management server. E.g. /subscriptions
    insecure?: boolean // disable SSL/TLS host verification
    proxy_hostname?: string
    proxy_user?: string
    proxy_password?: string
}

export interface RegisterServiceProxy extends DBusProxy {
    Register: ( org: string
              , user: string
              , pw: string
              , opts: RegisterOptionsFull | {}
              , connect: RegisterConnectOptions | {}) => Promise<string>
    RegisterWithActivationKeys: ( org: string
                                , keylist: string[]
                                , opts: RegisterOptions | {}
                                , connect: RegisterConnectOptions | {}) => Promise<string>
}

////////////////////////////////////////////////////////////////////////////////////////////////
// _Service classes that extend BaseService
////////////////////////////////////////////////////////////////////////////////////////////////

abstract class BaseService<P extends DBusProxy> {
    proxy: DBusProxy
    stream: Observable<void>

    constructor(proxy: P) {
        this.proxy = proxy
        this.stream = Observable.fromPromise(this.proxy.wait())
    }
}

export
class ConfigService extends BaseService<ConfigServiceProxy> {
    constructor(proxy: ConfigServiceProxy) {
        super(proxy)
    }
}

export
class RegisterServerService extends BaseService<RegisterServerServiceProxy>  {
    proxy: RegisterServerServiceProxy

    constructor(proxy: RegisterServerServiceProxy) {
        super(proxy)
        this.proxy = proxy
    }
}

export 
class RegisterService extends BaseService<RegisterServiceProxy> {
    proxy: RegisterServiceProxy

    constructor(sockname: string) {
        let pxy = RegisterService.socketDbus(null, sockname)
        super(pxy)
    }

    static socketDbus = (name: string | null, socket: string): RegisterServiceProxy => {
        let opts: DBusOptions = {superuser: 'require', bus: 'none', address: socket}
        return cockpit.dbus(name, opts) as RegisterServiceProxy
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////
// cockpit API typescript definitions
////////////////////////////////////////////////////////////////////////////////////////////////

export type DBusOptions = {
    bus?: 'session' | 'user' | 'system' | 'none',
    host?: string,
    superuser?: 'require' | 'try',
    track?: 'try',
    address?: string
}

export interface Cockpit {
    dbus: (service: string | null, opts?: DBusOptions) => DBusProxy
    gettext: any
    event_target: any                                     
}

////////////////////////////////////////////////////////////////////////////////////////////////
// Subscription Manager DBus Object definitions
////////////////////////////////////////////////////////////////////////////////////////////////

// ====================================================================
// The com.redhat.SubscriptionManager Interfaces and Objects
// ====================================================================
// FIXME: This interface will be deprecated
export const SubManSvc = 'com.redhat.SubscriptionManager'
export const SubManIfcs = {
    EntitlementStatus: 'com.redhat.SubscriptionManager.EntitlementStatus'
}
export const SubManObjs = {
    EntitlementStatus: '/EntitlementStatus'
}

// The com.redhat.RHSM1 Interfaces and Objects
// TODO: Add methods for each IFType (eg RegisterServer.Start)
const RHSMPaths = ['com', 'redhat', 'RHSM1']
export const RHSMSvc = 'com.redhat.RHSM1' // RHSMPaths.join("."); if this is used, type checker will complain
export type RHSMIFTypes = 'Attach'
                        | 'Config'
                        | 'Entitlement'
                        | 'Products'
                        | 'Register'
                        | 'RegisterServer'
                        | 'Unregister'
export const RHSMInterfaces: Array<RHSMIFTypes> = 
    [ 'Attach'
    , 'Config'
    , 'Entitlement'
    , 'Products'
    , 'Register'
    , 'RegisterServer'
    , 'Unregister'
    ]

// Contains map of service name to dbus interfaces: eg Attach -> com.redhat.RHSM1.Attach
export const RHSMIfcs = RHSMInterfaces.reduce((acc, n) => {
    acc[n] = `${RHSMSvc}.${n}`
    return acc
}, IMap<string, string>())

// Contains map of service name to dbus object: eg Attach -> /com/redhat/RHSM1/Attach 
export const RHSMObjs = RHSMInterfaces.reduce((acc, n) => {
    acc[n] = '/'.concat(RHSMPaths.join('/').concat(`/${n}`))
    return acc
}, IMap<string, string>())

const _getSig = (lookup: IMap<string, string>, name: RHSMIFTypes): string => lookup.get(name)

export const getRHSMIfc = (name: RHSMIFTypes): string => {
    let got =  _getSig(RHSMIfcs, name)
    return got !== undefined ? got : `${RHSMSvc}.${name}`
}

export const getRHSMObj = (name: RHSMIFTypes): string  => {
    let got = _getSig(RHSMObjs, name)
    return got !== undefined ? got : '/'.concat(RHSMPaths.join('/').concat(`/${name}`))
}

export const REGISTER_SERVER_IFC = getRHSMIfc('RegisterServer')
export const REGISTER_IFC = getRHSMIfc('Register')
export const CONFIG_IFC = getRHSMIfc('Config')
export const ATTACH_IFC = getRHSMIfc('Attach')
export const PRODUCTS_IFC = getRHSMIfc('Products')
export const UNREGISTER_IFC = getRHSMIfc('Unregister')

export const REGISTER_SERVER_OBJ = getRHSMObj('RegisterServer')
export const REGISTER_OBJ = getRHSMObj('Register')
export const CONFIG_OBJ = getRHSMObj('Config')
export const ATTACH_OBJ = getRHSMObj('Attach')
export const PRODUCTS_OBJ = getRHSMObj('Products')
export const UNREGISTER_OBJ = getRHSMObj('Unregister')
