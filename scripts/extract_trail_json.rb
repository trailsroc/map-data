# usage: ruby extract_trail_json.rb *.gpx | pbcopy

# loop over all tracks/routes in the GPX,
# get the names of all the items,
# produce JSON for everything:
# from borders: park object with bounds
# from tracks/routes:
# zoom bounds

require 'json'
require 'nokogiri'

def parse_file(gpx_file)
    gpx_raw = IO.read gpx_file
    gpx_xml = Nokogiri::XML::Document.parse(gpx_raw)
    gpx_raw = nil

    data = {}
    parks = {}
    trails = {}

    routes_tracks = gpx_xml.root().search('rte', 'trk')
    routes_tracks.each do |node|
        names = node.>('name')
        if names.count > 0 then
            name = names.first.content
            if name_is_border(name) then
                name = get_border_name(name)
                parks[name] = get_bounds(node, parks[name])
            else
                trails[name] = get_bounds(node, trails[name])
            end
        end
    end

    data["parks"] = parks
    data["trails"] = trails

    print JSON.pretty_generate(data)
    print "\n"
end

def name_is_border(name)
    return get_border_name(name) != nil
end

def get_border_name(name)
    splitted = name.split(":")
    return splitted.count > 0 ? splitted[1] : nil
end

def get_bounds(track_or_route, existing_data)
    lats = []
    lons = []
    if existing_data then
        if existing_data["SW"] then
            lats.push(existing_data["SW"][0])
            lats.push(existing_data["NE"][0])
            lons.push(existing_data["SW"][1])
            lons.push(existing_data["NE"][1])
        end
    end

    collect_coords(track_or_route, lats, lons)

    lats.count > 0 ? {"SW" => [lats.min, lons.min], "NE" => [lats.max, lons.max]} : {}
end

def collect_coords(track_or_route, lats, lons)
    points = track_or_route.search('trkpt', 'rtept')
    points.each do |point|
        lats.push(point["lat"].to_f)
        lons.push(point["lon"].to_f)
    end
end

gpx_files = ARGV
gpx_files.each {|f| parse_file(f)}
