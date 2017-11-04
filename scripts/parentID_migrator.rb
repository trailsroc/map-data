# usage: ruby schema_migrator.rb

require "json"
require "nokogiri"

$pretty = true
$dry_run = false
$source_dir = "/Users/mike/Documents/src/Trails/maps.trailsroc.org/map-data/source/"
$dest_dir = "/Users/mike/Documents/src/Trails/maps.trailsroc.org/map-data/source-v3/"
#$gpx_filenames = ["mponds"]
$gpx_filenames = ["abe", "auburntr", "black_creek", "canal", "churchville_park", "city_parks", "corbetts", "crescenttr", "durand_eastman", "ellison", "gcanal", "gosnell", "gvalley", "highland", "hitor", "ibaymar", "ibaywest", "lehigh", "lmorin", "mponds", "nhamp", "oatka", "ontariob", "pmills", "senecapk", "senecatr", "tryon", "vht", "webstercp", "webstertr", "wrnp"]
$json_filenames = $gpx_filenames

$metadata = {:parks => {}, :trails => {}, :poiTypes => [], :bundle => {}, :idlist => [], :defaultParkPerFile => {}}
$skipped_json_filenames = []

# helper funcs ########################

$r = Random.new
def random_id()
    id = $r.bytes(4).unpack("H*")[0]
    return register_and_validate_unique_id(id)
end

def register_and_validate_unique_id(id)
    if $metadata[:idlist].include?(id)
        abort_msg("Duplicate ID detected:", id)
    end
    $metadata[:idlist].push(id)
    return id
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

def name_is_border(name)
    return ["border", "innerBorder"].include?(name.split(":")[0])
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

# Removes trailhead arrays
def parse_json(filename)
    debug_trace("Parsing JSON #{filename}.json")
    data = JSON.load(IO.read("#{$source_dir}#{filename}.json"))
    new_data = {"version": 3}

    if !data["version"] || data["version"] < 2
        abort_msg("Outdated JSON file #{filename}.json", nil)
    end

    if data["version"] >= 3
        error_msg("File #{filename}.json has already been processed.", nil)
        $skipped_json_filenames.push(filename)
        return nil
    end

    if data["points"] && !data["points"].empty?
        abort_msg("#{filename}.json should not have POI", nil)
    end

    if data["parks"]
        new_data["parks"] = data["parks"]
    end

    if data["trails"]
        new_data["trails"] = {}
        data["trails"].each do |trail_id, trail|
            trail.delete("trailheads")
            new_data["trails"][trail_id] = trail
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

    waypoints = gpx_xml.root().search("wpt")
    waypoints.each do |node|
        names = node.>("name")
        if names.count > 0 then

            poi_id = names.first.content
            # skip waypoints that don't represent POI
            if !poi_id.include?(":")
                next
            end
            
            tokens = poi_id.split(":")
            poi_type = tokens.first

            descs = node.>("desc")
            if descs.count > 0 && descs.first.content.length > 0 then
                other_attrs = JSON.load(descs.first.content) || {}
            else
                other_attrs = {}
            end

            parent_id_list = []
            if other_attrs["parkID"]
                parent_id_list.push(other_attrs["parkID"])
                other_attrs.delete("parkID")
            end
            if other_attrs["trailID"]
                parent_id_list.push(other_attrs["trailID"])
                other_attrs.delete("trailID")
            end
            other_attrs["parentIDs"] = parent_id_list

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
