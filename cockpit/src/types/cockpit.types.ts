import { Observable } from 'rxjs/Observable'
import 'rxjs/add/observable/fromPromise'
import { Map as IMap } from 'immutable' 

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


abstract class BaseService<P extends DBusProxy, T> {
    proxy: DBusProxy;
    stream: Observable<T>;

    constructor(proxy: P) {
        this.proxy = proxy
        this.stream = Observable.fromPromise(this.proxy.wait())
    }
}

export
class ConfigService extends BaseService<ConfigServiceProxy, string> {
    constructor(proxy: ConfigServiceProxy) {
        super(proxy)
    }
}

export
class RegisterServerService extends BaseService<RegisterServerServiceProxy, string>  {
    constructor(proxy: RegisterServerServiceProxy) {
        super(proxy)
    }
}

export type DBusOptions = {
    bus?: 'session' | 'user' | 'system',
    host?: string,
    superuser?: 'require' | 'try',
    track?: "try"
}

export interface Cockpit {
    dbus: (service: string, opts?: DBusOptions) => DBusProxy
    gettext: any
    event_target: any                                     
}


// ====================================================================
// The com.redhat.SubscriptionManager Interfaces and Objects
// ====================================================================
// FIXME: This interface will be deprecated
export const SubManSvc = "com.redhat.SubscriptionManager"
export const SubManIfcs = {
    EntitlementStatus: "com.redhat.SubscriptionManager.EntitlementStatus"
}
export const SubManObjs = {
    EntitlementStatus: "/EntitlementStatus"
}


// The com.redhat.RHSM1 Interfaces and Objects
// TODO: Add methods for each IFType (eg RegisterServer.Start)
const RHSMPaths = ["com", "redhat", "RHSM1"];
export const RHSMSvc = "com.redhat.RHSM1"; // RHSMPaths.join("."); if this is used, type checker will complain
export type RHSMIFTypes = "Attach"
                        | "Config"
                        | "Entitlement"
                        | "Products"
                        | "Register"
                        | "RegisterServer"
                        | "Unregister";
export const RHSMInterfaces: Array<RHSMIFTypes> = 
    [ "Attach"
    , "Config"
    , "Entitlement"
    , "Products"
    , "Register"
    , "RegisterServer"
    , "Unregister"
    ]

// Contains map of service name to dbus interfaces: eg Attach -> com.redhat.RHSM1.Attach
export const RHSMIfcs = RHSMInterfaces.reduce((acc, n) => {
    acc[n] = `${RHSMSvc}.${n}`;
    return acc;
}, IMap<string, string>());

// Contains map of service name to dbus object: eg Attach -> /com/redhat/RHSM1/Attach 
export const RHSMObjs = RHSMInterfaces.reduce((acc, n) => {
    acc[n] = "/".concat(RHSMPaths.join("/").concat(`/${n}`));
    return acc;
}, IMap<string, string>());

const _getSig = (lookup: IMap<string, string>, name:RHSMIFTypes): string => lookup.get(name)

export const getRHSMIfc = (name: RHSMIFTypes): string => {
    let got =  _getSig(RHSMIfcs, name)
    return got !== undefined ? got : `${RHSMSvc}.${name}`
}

export const getRHSMObj = (name: RHSMIFTypes): string  => {
    let got = _getSig(RHSMObjs, name)
    return got !== undefined ? got : "/".concat(RHSMPaths.join("/").concat(`/${name}`))
}