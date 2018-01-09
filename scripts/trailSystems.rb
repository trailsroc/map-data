# usage: ruby trailSystems.rb
# MIGRATOR for version 4 -> 5

# Migration:
# - Change some parks to trailSystems
# - Change trail.parkID to parentID
# - Change hideInListView to isSearchable for everything
# - Update parent IDs in POI also

require "json"
require "nokogiri"

$data_version = 5
$pretty = true
$dry_run = false
$source_dir = "/Users/mike/Documents/src/Trails/maps.trailsroc.org/map-data/source/"
$dest_dir = "/Users/mike/Documents/src/Trails/maps.trailsroc.org/map-data/source-v5/"
#$gpx_filenames = ["mponds", "lehigh", "canal"]
$gpx_filenames = ["abe", "auburntr", "black_creek", "canal", "churchville_park", "city_parks", "corbetts", "crescenttr", "durand_eastman", "ellison", "gcanal", "gosnell", "gvalley", "highland", "hitor", "ibaymar", "ibaywest", "lehigh", "lmorin", "mponds", "nhamp", "oatka", "ontariob", "pmills", "senecapk", "senecatr", "tryon", "vht", "webstercp", "webstertr", "wrnp"]
$json_filenames = $gpx_filenames

$metadata = {:parks => {}, :trails => {}, :poiTypes => [], :bundle => {}, :idlist => []}
$skipped_json_filenames = []

$park_ids_to_make_trail_systems = {
    "park-lehigh-park" => "tsystem-lehigh",
    "park-gv-riverway-park" => "tsystem-gv-riverway",
    "park-gv-greenway-park" => "tsystem-gv-greenway",
    "park-ecanal-park-park" => "tsystem-ecanal",
    "park-auburntr-park" => "tsystem-auburntr",
    "park-crescenttr" => "tsystem-crescenttr",
    "park-senecatr" => "tsystem-senecatr",
    "park-fowt-hojack" => "tsystem-fowt-hojack",
    "park-fowt-rt104" => "tsystem-fowt-rt104"
}

$trail_ids_to_reassign = {
    "trail-lehigh-valley-main" => "tsystem-lehigh",
    "trail-lehigh-valley-north" => "tsystem-lehigh",
    "trail-lehigh-valley-unnamed-trails" => "tsystem-lehigh",
    "trail-ecanal-main" => "tsystem-ecanal",
    "trail-ecanal-closed" => "tsystem-ecanal",
    "trail-ecanal-detour" => "tsystem-ecanal",
    "trail-ecanal-access" => "tsystem-ecanal",
    "trail-ecanal-other" => "tsystem-ecanal",
    "trail-ecanal-holley-falls" => "tsystem-ecanal",
    "trail-ecanal-rose-turner" => "tsystem-ecanal",
    "trail-gv-greenway" => "tsystem-gv-greenway",
    "trail-gv-greenway-detour" => "tsystem-gv-greenway",
    "trail-gv-greenway-access" => "tsystem-gv-greenway",
    "trail-brookdale-preserve-trail" => "tsystem-gv-greenway",
    "trail-gv-riverway-south" => "tsystem-gv-riverway",
    "trail-gv-riverway-maplewood" => "tsystem-gv-riverway",
    "trail-gv-riverway-north" => "tsystem-gv-riverway",
    "trail-gv-riverway-east" => "tsystem-gv-riverway",
    "trail-gv-riverway-other" => "tsystem-gv-riverway",
    "trail-gv-riverway-access" => "tsystem-gv-riverway",
    "trail-auburntr-main" => "tsystem-auburntr",
    "trail-auburntr-shoulder" => "tsystem-auburntr",
    "trail-lvt-auburntr-ramp" => "tsystem-auburntr",
    "trail-vht-lehigh-blackdiamond" => "tsystem-auburntr",
    "trail-crescenttr-main" => "tsystem-crescenttr",
    "trail-crescenttr-blue" => "tsystem-crescenttr",
    "trail-crescenttr-green" => "tsystem-crescenttr",
    "trail-crescenttr-red" => "tsystem-crescenttr",
    "trail-crescenttr-white" => "tsystem-crescenttr",
    "trail-crescenttr-yellow" => "tsystem-crescenttr",
    "trail-senecatr-main" => "tsystem-senecatr",
    "trail-fowt-hojack-main" => "tsystem-fowt-hojack",
    "trail-fowt-rt104-path" => "tsystem-fowt-rt104"
}

$trail_ids_with_style_trailSystem = [
    "trail-lehigh-valley-main",
    "trail-lehigh-valley-north",
    "trail-ecanal-main",
    "trail-gv-greenway",
    "trail-gv-greenway-detour",
    "trail-gv-riverway-south",
    "trail-gv-riverway-maplewood",
    "trail-gv-riverway-north",
    "trail-gv-riverway-east",
    "trail-auburntr-main",
    "trail-auburntr-shoulder",
    "trail-vht-lehigh-blackdiamond",
    "trail-crescenttr-main",
    "trail-senecatr-main",
    "trail-fowt-hojack-main",
    "trail-fowt-rt104-path"
]

$trail_ids_with_blazes = [
    "trail-crescenttr-main",
    "trail-crescenttr-blue",
    "trail-crescenttr-green",
    "trail-crescenttr-red",
    "trail-crescenttr-white",
    "trail-crescenttr-yellow",
    "trail-senecatr-main"
]

# helper funcs ########################

def nil_or_blank(str)
    str == nil || str.strip().empty?
end

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

    if !data["version"] || data["version"] < ($data_version - 1)
        abort_msg("Outdated JSON file #{filename}.json", nil)
    end

    if data["version"] >= $data_version
        error_msg("File #{filename}.json has already been processed.", nil)
        $skipped_json_filenames.push(filename)
        return nil
    end

    new_data = {"version": $data_version}

    new_data["trailSystems"] = {}

    if data["parks"]
        new_data["parks"] = {}
        data["parks"].each do |park_id, park|
            if park.has_key?("hideInListView")
                park["isSearchable"] = !park["hideInListView"]
            end
            park.delete("hideInListView")
            park.delete("visibilityConstraint")
            if $park_ids_to_make_trail_systems.has_key?(park_id)
                park["isSearchable"] = true
                system_id = $park_ids_to_make_trail_systems[park_id]
                new_data["trailSystems"][system_id] = park
            else
                new_data["parks"][park_id] = park
            end
        end
    end

    if data["trails"]
        new_data["trails"] = {}
        data["trails"].each do |trail_id, trail|
            if trail.has_key?("hideInListView")
                abort_msg("Trail #{trail_id} has hideInListView defined.", trail)
                #trail["isSearchable"] = !trail["hideInListView"]
            end
            trail.delete("hideInListView")
            trail.delete("visibilityConstraint")
            if $trail_ids_to_reassign.has_key?(trail_id)
                parent_id = $trail_ids_to_reassign[trail_id]
                if !$trail_ids_with_blazes.include?(trail_id)
                    trail["blazes"] = "none"
                end
            else
                parent_id = trail["parkID"]
                if $park_ids_to_make_trail_systems.has_key?(parent_id)
                    parent_id = $park_ids_to_make_trail_systems[parent_id]
                end
            end
            if $trail_ids_with_style_trailSystem.include?(trail_id)
                trail["style"] = "trailSystem"
            end
            if trail.has_key?("isPrimary")
                # respect manual assignment
                trail["isPrimary"] = trail["isPrimary"]
            elsif $trail_ids_with_style_trailSystem.include?(trail_id)
                # trailSystem visibility implies isPrimary
                trail["isPrimary"] = !nil_or_blank(trail["name"])
            end
            trail.delete("parkID")
            trail["parentID"] = parent_id
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
            
            descs = node.>("desc")
            if descs.count > 0 && descs.first.content.length > 0 then
                other_attrs = JSON.load(descs.first.content) || {}
            else
                other_attrs = {}
            end

            if other_attrs.has_key?("hideInListView")
                abort_msg("hideInListView detected on a POI #{poi_id}", other_attrs)
            end

            if other_attrs.has_key?("parentIDs")
                # Update parent from old park ID to new trail system ID
                parent_ids = other_attrs["parentIDs"].map do |id|
                    $park_ids_to_make_trail_systems[id] || id
                end
                # POI -> trail -> trailSystem: ensure the trailSystem parent is assigned
                new_ids = []
                parent_ids.each do |id|
                    system_id = $trail_ids_to_reassign[id]
                    if !parent_ids.include?(system_id) && $trail_ids_to_reassign.has_key?(id)
                        new_ids.push(system_id)
                    end
                end
                parent_ids = parent_ids + new_ids
                other_attrs["parentIDs"] = parent_ids
            end

            desc_json = JSON.generate(other_attrs)
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
