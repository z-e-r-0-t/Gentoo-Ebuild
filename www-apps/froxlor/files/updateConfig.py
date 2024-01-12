#!/usr/bin/env python3
import argparse
from xml.etree.ElementTree import parse

if __name__ == "__main__":
	parser = argparse.ArgumentParser(prog='updateConfig')
	parser.add_argument('xml_file', help='Path to XML file')
	parser.add_argument('xpath', help='XPath to be used')
	parser.add_argument('attribute_name', help='Name of the attribute to be set')
	parser.add_argument('attribute_value', help='Value of the attribute to be set')
	args = parser.parse_args()

	config = parse(args.xml_file)
	config.find(args.xpath).attrib[args.attribute_name] = args.attribute_value
	config.write(args.xml_file)
