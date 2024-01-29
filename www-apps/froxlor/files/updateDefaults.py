#!/usr/bin/env python3
import argparse
from xml.etree.ElementTree import Element, indent, parse

if __name__ == "__main__":
    parser = argparse.ArgumentParser(prog='updateDefaults')
    parser.add_argument('xml_file', help='Path to XML file')
    parser.add_argument('settinggroup', help='Data for attribute "settinggroup" to be updated / created')
    parser.add_argument('varname', help='Data for attribute "varname" to be updated / created')
    parser.add_argument('value', help='Data for attribute "value" to be set')
    args = parser.parse_args()

    defaults_path = './distribution/defaults'
    target_attribute = 'value'

    config = parse(args.xml_file)

    defaults = config.find(defaults_path)
    if defaults is None:
        raise Exception("defaults_path not found or empty")

    element = defaults.find(f"default[@settinggroup='{args.settinggroup}'][@varname='{args.varname}']")
    if element is not None:
        element.attrib[target_attribute] = args.value
    else:
        defaults.append(Element('default', {
            'settinggroup': args.settinggroup,
            'varname': args.varname,
            target_attribute: args.value
        }))

    indent(config, space="\t")
    config.write(args.xml_file, encoding="UTF-8", xml_declaration=True, short_empty_elements=False)
