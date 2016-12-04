require 'json'
require 'nokogiri'

def usage()
    print "Usage: ruby poi_gpx_to_json.rb input.gpx\n"
    print "Extracts POI data (waypoints) from input.gpx, prints JSON data to stdout.\n"
    print "Does not modify input.gpx.\n"
end

def process(gpx_file)
    gpx_raw = IO.read gpx_file
    gpx_xml = Nokogiri::XML::Document.parse(gpx_raw)
    gpx_raw = nil

    points = []

    waypoints = gpx_xml.root().search('wpt')
    waypoints.each do |node|
        poi = {}
        names = node.>('name')
        if names.count > 0 then
            tokens = names.first.content.split(':')
            poi["type"] = tokens[0]
            poi["name"] = tokens[1] || ''
        end
        poi["loc"] = [node["lat"].to_f, node["lon"].to_f]
        descs = node.>('desc')
        if descs.count > 0 && descs.first.content.length > 0 then
            other_attrs = JSON.load(descs.first.content) || {}
            poi = poi.merge(other_attrs)
        end
        points.push JSON.generate(poi)
    end

    print points.join(",\n")
    print "\n"
end

if ARGV.length > 0
    process ARGV[0]
else
    usage()
end
