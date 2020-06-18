#!/usr/bin/env python3

# manager-file.py: generate .manager files and TpCMParamSpec arrays from the
# same data (should be suitable for all connection managers that don't have
# plugins)
#
# The upstream copy of this program is in the telepathy-glib repository -
# please make any changes there.
#
# Copyright (c) Collabora Ltd. <http://www.collabora.co.uk/>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

import re
import sys
import runpy

_NOT_C_STR = re.compile(r'[^A-Za-z0-9_-]')

def c_string(x):
    # whitelist-based brute force and ignorance - escape nearly all punctuation
    return '"' + _NOT_C_STR.sub(lambda c: r'\x%02x' % ord(c), x) + '"'

def desktop_string(x):
    return x.replace(' ', r'\s').replace('\n', r'\n').replace('\r', r'\r').replace('\t', r'\t')

supported = list('sbuiqn')

fdefaultencoders = {
        's': desktop_string,
        'b': (lambda b: b and '1' or '0'),
        'u': (lambda n: '{}'.format(n)),
        'i': (lambda n: '{}'.format(n)),
        'q': (lambda n: '{}'.format(n)),
        'n': (lambda n: '{}'.format(n)),
        }
for x in supported: assert x in fdefaultencoders

gtypes = {
        's': 'G_TYPE_STRING',
        'b': 'G_TYPE_BOOLEAN',
        'u': 'G_TYPE_UINT',
        'i': 'G_TYPE_INT',
        'q': 'G_TYPE_UINT',
        'n': 'G_TYPE_INT',
}
for x in supported: assert x in gtypes

gdefaultencoders = {
        's': c_string,
        'b': (lambda b: b and 'GINT_TO_POINTER (TRUE)' or 'GINT_TO_POINTER (FALSE)'),
        'u': (lambda n: 'GUINT_TO_POINTER ({})'.format(n)),
        'i': (lambda n: 'GINT_TO_POINTER ({})'.format(n)),
        'q': (lambda n: 'GUINT_TO_POINTER ({})'.format(n)),
        'n': (lambda n: 'GINT_TO_POINTER ({})'.format(n)),
        }
for x in supported: assert x in gdefaultencoders

gdefaultdefaults = {
        's': 'NULL',
        'b': 'GINT_TO_POINTER (FALSE)',
        'u': 'GUINT_TO_POINTER (0)',
        'i': 'GINT_TO_POINTER (0)',
        'q': 'GUINT_TO_POINTER (0)',
        'n': 'GINT_TO_POINTER (0)',
        }
for x in supported: assert x in gdefaultdefaults

gflags = {
        'has-default': 'TP_CONN_MGR_PARAM_FLAG_HAS_DEFAULT',
        'register': 'TP_CONN_MGR_PARAM_FLAG_REGISTER',
        'required': 'TP_CONN_MGR_PARAM_FLAG_REQUIRED',
        'secret': 'TP_CONN_MGR_PARAM_FLAG_SECRET',
        'dbus-property': 'TP_CONN_MGR_PARAM_FLAG_DBUS_PROPERTY',
}

def write_manager(f, manager, protos):
    # pointless backwards compat section
    print('[ConnectionManager]', file=f)
    print('BusName=org.freedesktop.Telepathy.ConnectionManager.' + manager, file=f)
    print('ObjectPath=/org/freedesktop/Telepathy/ConnectionManager/' + manager, file=f)

    # protocols
    for proto, params in iter(protos.items()):
        print('', file=f)
        print('[Protocol {}]'.format(proto), file=f)

        defaults = {}

        for param, info in iter(params.items()):
            dtype = info['dtype']
            flags = info.get('flags', '').split()
            struct_field = info.get('struct_field', param.replace('-', '_'))
            filter = info.get('filter', 'NULL')
            filter_data = info.get('filter_data', 'NULL')
            setter_data = 'NULL'

            if 'default' in info:
                default = fdefaultencoders[dtype](info['default'])
                defaults[param] = default

            if flags:
                flags = ' ' + ' '.join(flags)
            else:
                flags = ''

            print('param-{}={}{}'.format(param, desktop_string(dtype), flags), file=f)

        for param, default in iter(defaults.items()):
            print('default-{}={}'.format(param, default), file=f)

def write_c_params(f, manager, proto, struct, params):
    print("static const TpCMParamSpec {}_{}_params[] = {{".format(manager, proto), file=f)

    for param, info in iter(params.items()):
        dtype = info['dtype']
        flags = info.get('flags', '').split()
        struct_field = info.get('struct_field', param.replace('-', '_'))
        filter = info.get('filter', 'NULL')
        filter_data = info.get('filter_data', 'NULL')
        setter_data = 'NULL'

        if 'default' in info:
            default = gdefaultencoders[dtype](info['default'])
        else:
            default = gdefaultdefaults[dtype]

        if flags:
            flags = ' | '.join([gflags[flag] for flag in flags])
        else:
            flags = '0'

        if struct is None or struct_field is None:
            struct_offset = '0'
        else:
            struct_offset = 'G_STRUCT_OFFSET ({}, {})'.format(struct, struct_field)

        print('''  {{ {}, {}, {},
    {},
    {}, /* default */
    {}, /* struct offset */
    {}, /* filter */
    {}, /* filter data */
    {} /* setter data */ }},'''.format(c_string(param), c_string(dtype),
                    gtypes[dtype], flags, default, struct_offset, filter,
                    filter_data, setter_data), file=f)

    print("  { NULL }", file=f)
    print("};", file=f)

if __name__ == '__main__':
    environment = runpy.run_path(sys.argv[1])

    with open('{}/{}.manager'.format(sys.argv[2], environment['MANAGER']), 'w') as f:
        write_manager(f, environment['MANAGER'], environment['PARAMS'])

    with open('{}/param-spec-struct.h'.format(sys.argv[2]), 'w') as f:
        for protocol in environment['PARAMS']:
            write_c_params(f, environment['MANAGER'], protocol,
                    environment['STRUCTS'][protocol],
                    environment['PARAMS'][protocol])
