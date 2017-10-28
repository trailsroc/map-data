# usage: ruby schema_migrator.rb

require "json"
require "nokogiri"

$pretty = true
$dry_run = false
$source_dir = "/Users/mike/Documents/src/Trails/maps.trailsroc.org/map-data/source/"
$dest_dir = "/Users/mike/Documents/src/Trails/maps.trailsroc.org/map-data/source-v2/"
#$gpx_filenames = ["mponds"]
$gpx_filenames = ["abe", "auburntr", "black_creek", "canal", "churchville_park", "city_parks", "corbetts", "crescenttr", "durand_eastman", "ellison", "gcanal", "gosnell", "gvalley", "highland", "hitor", "ibaymar", "ibaywest", "lehigh", "lmorin", "mponds", "nhamp", "oatka", "ontariob", "pmills", "senecapk", "senecatr", "tryon", "vht", "webstercp", "webstertr", "wrnp"]
$json_filenames = $gpx_filenames

$metadata = {:parks => {}, :trails => {}, :poiTypes => [], :bundle => {}, :idlist => [], :defaultParkPerFile => {}}
$skipped_json_filenames = []

$v1_gpx_with_poi_waypoints = ["auburntr", "vht", "canal", "city_parks", "corbetts"]
$poi_to_add_to_gpx = {}

# helper funcs ########################

$r = Random.new
def random_id()
    id = $r.bytes(4).unpack("H*")[0]
    return register_and_validate_unique_id(id)
end

# call only once
def standardize_park_id_and_validate(park_id)
    new_id = standardize_park_id(park_id)
    return register_and_validate_unique_id(new_id)
end

# call only once
def standardize_trail_id_and_validate(trail_id)
    new_id = standardize_trail_id(trail_id)
    return register_and_validate_unique_id(new_id)
end

def register_and_validate_unique_id(id)
    if $metadata[:idlist].include?(id)
        abort_msg("Duplicate ID detected:", id)
    end
    $metadata[:idlist].push(id)
    return id
end

# idempotent.
def standardize_park_id(park_id)
    fix_id_punct(require_prefix(park_id, "park-"))
end

# idempotent.
def standardize_trail_id(trail_id)
    fix_id_punct(require_prefix(trail_id, "trail-"))
end

# idempotent.
def standardize_poi_type(type)
    if type == "boat_launch"
        type = "boatLaunch"
    end
    type = fix_id_punct(require_prefix(type, "point-"))
    if !$metadata[:poiTypes].include?(type)
        $metadata[:poiTypes].push(type)
    end
    return type
end

# idempotent.
def require_prefix(value, prefix)
    if !value
        return value
    end
    if !value.start_with?(prefix)
        value = prefix + value
    end
    return value
end

# idempotent.
def fix_id_punct(value)
    if !value
        return value
    end
    value = value.gsub(/_/, "-")
end

def standardize_poi_name(raw_name, poi_type)
    name = raw_name

    if poi_type == "point-intersection" && !name.start_with?("Intersection")
        name = "Intersection " + name
    end
    if poi_type == "point-shelter" && !name.end_with?("Shelter")
        name = name + " Shelter"
    end
    if poi_type == "point-lodge" && !name.end_with?("Lodge")
        name = name + " Lodge"
    end
    if !name
        type_name_map = {
            "point-admin" => "Administrative Building",
            "point-boatLaunch" => "Boat Launch",
            "point-campsite" => "Campsite",
            "point-parking" => "Parking",
            "point-poi" => "Point of Interest",
            "point-restroom" => "Restroom",
            "point-scenic" => "Scenic Point",
            "point-sports" => "Sports Field"
        }
        if type_name_map.has_key?(poi_type)
            name = type_name_map[poi_type]
        end
    end

    return name
end

def name_is_border(name)
    return get_border_name(name) != nil
end

def is_inner_border(name)
    name.split(":")[0] == "innerBorder"
end

def get_border_name(name)
    splitted = name.split(":")
    return splitted.count > 0 ? splitted[1] : nil
end

def error_msg(msg, o)
    $stderr.puts msg
    if o
        $stderr.puts o
    end
    $stderr.puts "\n"
end

def abort_msg(msg, o)
    error_msg(msg, o)
    Kernel.exit(1)
end

def debug_trace(msg)
    if $dry_run
        puts msg
    end
end

# JSON #################################

def parse_json(filename)
    $poi_to_add_to_gpx[filename] = {}

    debug_trace("Parsing JSON #{filename}.json")
    data = JSON.load(IO.read("#{$source_dir}#{filename}.json"))
    new_data = {"version": 2}

    if data["version"] && data["version"] >= 2
        error_msg("File #{filename}.json has already been processed.", nil)
        $skipped_json_filenames.push(filename)
        return nil
    end

    if data["parks"]
        new_data["parks"] = {}
        data["parks"].each do |old_park_id, park|
            park_id = standardize_park_id_and_validate(old_park_id)
            new_data["parks"][park_id] = park
        end
    end

    if new_data["parks"].count == 1
        default_park_id = new_data["parks"].keys.first
        $metadata[:defaultParkPerFile][filename] = default_park_id
    else
        default_park_id = nil
    end

    if data["trails"]
        proto_trail = data["trails"]["_prototype"] || {}
        new_data["trails"] = {}
        data["trails"].each do |old_trail_id, trail|
            if old_trail_id == "_prototype"
                next
            end

            trail_id = standardize_trail_id_and_validate(old_trail_id)
            trail = proto_trail.merge(trail)
            park_id = standardize_park_id(trail["parkId"])
            if park_id
                trail["parkID"] = park_id
            end
            trail.delete("parkId")

            new_data["trails"][trail_id] = trail
        end
    end


    if data["points"]
        new_data["points"] = {}
        data["points"].each do |point|
            poi_type = standardize_poi_type(point["type"])
            poi_id = "#{poi_type}:#{filename}:#{random_id()}"
            point["type"] = poi_type
            point["name"] = standardize_poi_name(point["name"], poi_type)

            park_id = standardize_park_id(point["parkId"]) || default_park_id
            if park_id
                point["parkID"] = park_id
            end
            point.delete("parkId")

            trail_id = standardize_trail_id(point["trailId"])
            if trail_id
                point["trailID"] = trail_id
            end
            point.delete("trailId")

            if !point["name"]
                error_msg("Warning: POI without name.", point)
            end

            if !point["parkID"] && !point["trailID"]
                abort_msg("POI without park ID or trail ID.", point)
            end

            if !$v1_gpx_with_poi_waypoints.include?(filename)
                $poi_to_add_to_gpx[filename][poi_id] = point
            end
        end
    end

    return new_data
end

# GPX ##################################

def parse_gpx(filename)
    if $skipped_json_filenames.include?(filename)
        error_msg("Skipping #{filename}.gpx because corresponding JSON file was skipped.", nil)
        return nil
    end

    gpx_raw = IO.read "#{$source_dir}#{filename}.gpx"
    gpx_xml = Nokogiri::XML::Document.parse(gpx_raw)
    gpx_raw = nil

    default_park_id = $metadata[:defaultParkPerFile][filename]

    routes_tracks = gpx_xml.root().search("rte", "trk")
    routes_tracks.each do |node|
        names = node.>("name")
        if names.count > 0 then
            name = names.first.content
            if name_is_border(name)
                park_id = standardize_park_id(get_border_name(name))
                if !$metadata[:idlist].include?(park_id)
                    abort_msg("Park not found for #{name}.")
                end
                if is_inner_border(name)
                    new_name = "innerBorder:#{park_id}"
                else
                    new_name = "border:#{park_id}"
                end
            else
                trail_id_list = name.split(",").map do |old_trail_id|
                    trail_id = standardize_trail_id(old_trail_id)
                    if !$metadata[:idlist].include?(trail_id)
                        abort_msg("Trail not found in track #{name}.")
                    end
                    trail_id
                end
                trail_id_list = trail_id_list.join(",")
                new_name = "seg:#{trail_id_list}:#{random_id()}"
            end
            #debug_trace("ROUTE #{name} -> #{new_name}")
            if new_name
                names.first.content = new_name
            end
        end
    end

    waypoints = gpx_xml.root().search("wpt")
    waypoints.each do |node|
        names = node.>("name")
        if names.count > 0 then
            name = names.first.content
            tokens = name.split(":")
            raw_type = tokens.first

            # skip waypoints that don't represent POI
            if !["admin", "boat_launch", "campsite", "intersection", "lodge", "parking", "poi", "restroom", "scenic", "shelter", "sports"].include?(raw_type)
                next
            end

            descs = node.>("desc")
            if descs.count > 0 && descs.first.content.length > 0 then
                other_attrs = JSON.load(descs.first.content) || {}
            else
                other_attrs = {}
            end

            poi_type = standardize_poi_type(raw_type)
            poi_id = "#{poi_type}:#{filename}:#{random_id()}"

            poi_name = other_attrs["name"] || standardize_poi_name(tokens.count > 1 ? tokens[1] : nil, poi_type)
            park_id = standardize_park_id(other_attrs["parkId"]) || default_park_id
            other_attrs.delete("parkId")

            trail_id = standardize_trail_id(other_attrs["trailId"])
            other_attrs.delete("trailId")

            if !poi_name
                error_msg("#{filename}.gpx: Warning: POI without name.", node)
            end

            if !park_id && !trail_id
                abort_msg("#{filename}.gpx: POI without park ID or trail ID.", node)
            end

            names.first.content = poi_id

            other_attrs["name"] = poi_name
            if park_id
                other_attrs["parkID"] = park_id
            end
            if trail_id
                other_attrs["trailID"] = trail_id
            end

            desc_json = JSON.pretty_generate(other_attrs)
            if descs.count > 0
                descs.first.content = desc_json
            else
                desc_node = Nokogiri::XML::Node.new("desc", gpx_xml)
                desc_node.content = desc_json
                names.first.add_next_sibling(desc_node)
            end
        end
    end

    $poi_to_add_to_gpx[filename].each do |poi_id, point|
        node = Nokogiri::XML::Node.new("wpt", gpx_xml)
        node["lat"] = point["loc"][0]
        node["lon"] = point["loc"][1]
        point.delete("loc")

        name_node = Nokogiri::XML::Node.new("name", gpx_xml)
        name_node.content = poi_id
        desc_node = Nokogiri::XML::Node.new("desc", gpx_xml)
        desc_node.content = JSON.pretty_generate(point)

        node.add_child(name_node)
        node.add_child(desc_node)
        gpx_xml.root().add_child(node)
    end

    return gpx_xml
end

# do it ################################

if !$dry_run
    if !Dir.exist?($dest_dir)
        abort_msg('Output directory missing.', $dest_dir)
    end
    if !(Dir.empty?($dest_dir) || ['.', '..', '.DS_Store'] == Dir.entries($dest_dir))
        abort_msg('Output directory not empty.', $dest_dir)
    end
end

$json_filenames.each do |filename|
    json_data = parse_json(filename)
    if !json_data
        next
    end

    if $dry_run
        print "#{filename}.json:\n"
        print JSON.pretty_generate(json_data)
        next
    end

    if $pretty
        IO.write("#{$dest_dir}#{filename}.json", JSON.pretty_generate(json_data))
    else
        IO.write("#{$dest_dir}#{filename}.json", JSON.generate(json_data))
    end
end

$gpx_filenames.each do |filename|
    gpx_doc = parse_gpx(filename)
    if !gpx_doc
        next
    end

    if !$dry_run
        IO.write("#{$dest_dir}#{filename}.gpx", gpx_doc)
    end
end

if $dry_run
    print "\n\nMetadata:\n"
    print JSON.pretty_generate($metadata)
end
