/**
 * This module takes cockpit services, and converts them to streams
 */

import 'rxjs/add/operator/map'
import * as CP from '../types/cockpit.types'
import { Observable } from 'rxjs/Observable';


const cockpit: CP.Cockpit = require("cockpit");

const service = cockpit.dbus('com.redhat.RHSM1', {'superuser': 'require'});
const configSvcPxy: CP.ConfigServiceProxy = service.proxy(CP.getRHSMIfc("Config"), '/com/redhat/RHSM1/Config');
const configService = new CP.ConfigService(configSvcPxy)



