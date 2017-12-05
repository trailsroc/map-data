# usage: ruby make_geojson.rb | pbcopy

require 'json'
require 'nokogiri'

# initialize ################################

$data_version = 4
$pretty = true
$dry_run = false
$source_dir = '/Users/mike/Documents/src/Trails/maps.trailsroc.org/map-data/source/'
$dest_dir = '/Users/mike/Documents/src/Trails/maps.trailsroc.org/geojson/'
#$gpx_filenames = ['mponds']
$gpx_filenames = ['abe', 'auburntr', 'black_creek', 'canal', 'churchville_park', 'city_parks', 'corbetts', 'crescenttr', 'durand_eastman', 'ellison', 'gcanal', 'gosnell', 'gvalley', 'highland', 'hitor', 'ibaymar', 'ibaywest', 'lehigh', 'lmorin', 'mponds', 'nhamp', 'oatka', 'ontariob', 'pmills', 'senecapk', 'senecatr', 'tryon', 'vht', 'webstercp', 'webstertr', 'wrnp']
$json_filenames = $gpx_filenames

$metadata = {:parks => {}, :trails => {}, :poiTypes => [], :bundle => {}, :idlist => []}

# ls ../source/*.gpx | cut -d '/' -f 3 | cut -d '.' -f 1 | pbcopy
# ls ../source/*.json | cut -d '/' -f 3 | cut -d '.' -f 1 | pbcopy

# process funcs ################################

def nil_or_blank(str)
    str == nil || str.strip().empty?
end

$r = Random.new
def random_id()
    id = $r.bytes(4).unpack("H*")[0]
    return register_and_validate_unique_id(id, "random_id")
end

def register_and_validate_unique_id(id, ctx)
    if $metadata[:idlist].include?(id)
        abort_msg("Duplicate ID detected (#{ctx}):", id)
    end
    $metadata[:idlist].push(id)
    return id
end

def validate_id_exists(id, ctx)
    if !$metadata[:idlist].include?(id)
        abort_msg("ID does not exist (#{ctx}):", id)
    end
end

def trail_metadata_for(trail_id_or_plural)
    return trail_id_or_plural.split(",").map do |id|
        trail = $metadata[:trails][id]
        if !trail
            abort_msg("Trail #{id} not found.", nil)
        end
        trail
    end
end

def color_for(name)
    return name
#    return $metadata['bundle']['appConfig']['colors'][name]['hex']
end

def surface_of(trail_id)
    surface_map = {
        'trail-lehigh-valley-main' => 'gravel',
        'trail-lvt-auburntr-ramp' => 'gravel',
        'trail-ecanal-main' => 'paved',
        'trail-pmills-roads' => 'road'
    }
    return surface_map[trail_id.split(",")[0]] || "singletrack"
end

def create_feature(trailsroc_type, trailsroc_id, ctx)
    register_and_validate_unique_id(trailsroc_id, ctx)
    # if $metadata[:idlist].include?(trailsroc_id)
    #     abort_msg("Duplicate feature ID detected (#{ctx})", trailsroc_id)
    # end
    # $metadata[:idlist].push(trailsroc_id)

    feature = {}
    feature['properties'] = {}
    feature['geometry'] = {}
    feature['type'] = 'Feature'
    feature_property(feature, 'type', trailsroc_type)
    feature_property(feature, 'id', trailsroc_id)
    return feature
end

# returns [lng, lat]
def center_of(sw_lat_lng, ne_lat_lng)
    if !sw_lat_lng
        error_msg('No SW data for center_of', [sw_lat_lng, ne_lat_lng])
        return nil
    end
    if !ne_lat_lng
        error_msg('No NE data for center_of', [sw_lat_lng, ne_lat_lng])
        return nil
    end
    avg_lng = 0.5 * (sw_lat_lng[1] + ne_lat_lng[1])
    avg_lat = 0.5 * (sw_lat_lng[0] + ne_lat_lng[0])
    [avg_lng, avg_lat]
end

def center_of_list(coordinates)
    if coordinates.empty?
        return [0,0]
    end 
    sums = coordinates.reduce([0,0]) { |sum,c| [sum[0]+c[0], sum[1]+c[1]] }
    return [sums[0].to_f / coordinates.count, sums[1].to_f / coordinates.count]
end

# side effects.
def feature_property(feature, short_key, value)
    feature['properties']['trailsroc-' + short_key] = value
end

# side effects.
def optional_property(feature, short_key, source, dflt: nil)
    if source.has_key?(short_key) && source[short_key] != nil
        feature_property(feature, short_key, source[short_key])
    elsif dflt != nil
        feature_property(feature, short_key, dflt)
    end
end

def create_point_geometry(lng_lat)
    geometry = {}
    geometry['coordinates'] = lng_lat
    geometry['type'] = 'Point'
    geometry
end

def debug_trace(msg)
    if $dry_run
        error_msg(msg, nil)
        # $stdout.puts msg
        # if o
        #     $stdout.puts o
        # end
        # $stdout.puts "\n"
    end
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

################### GPX

def parse_gpx(filename)

    debug_trace('Parsing GPX ' + filename)

    # TODO handle Inner Borders. Only three of them: corbett's, mponds, pmills.

    gpx_features = []

    gpx_raw = IO.read filename
    gpx_xml = Nokogiri::XML::Document.parse(gpx_raw)
    gpx_raw = nil

    # parkID => array
    unprocessed_borders = {}
    unprocessed_inner_borders = {}

    routes_tracks = gpx_xml.root().search('rte', 'trk')

    routes_tracks.each do |node|
        names = node.>('name')
        if names.count > 0 then
            name = names.first.content
            typ = track_type(name)
            case track_type(name)
            when "border"
                park_id = park_id_from_border_id(name)
                validate_id_exists(park_id, "border")
                if !unprocessed_borders[park_id]
                    unprocessed_borders[park_id] = []
                end
                unprocessed_borders[park_id].push(node)
            when "innerBorder"
                park_id = park_id_from_border_id(name)
                validate_id_exists(park_id, "innerBorder")
                if !unprocessed_inner_borders[park_id]
                    unprocessed_inner_borders[park_id] = []
                end
                unprocessed_inner_borders[park_id].push(node)
            when "seg"
                segment_id = name
                #register_and_validate_unique_id(segment_id, "segment")

                trail_ids = trail_ids_from_segment_id(name)
                trails = trail_metadata_for(trail_ids)
                coordinates = collect_coords(node)
                feature = create_feature('trailSegment', segment_id, "segment")
                feature['geometry']['type'] = 'LineString'
                feature['geometry']['coordinates'] = coordinates
                feature_property(feature, 'trailIDs', trail_ids)

                if trails.count == 1
                    trailName = trails[0]['name']
                    shortName = trails[0]['shortName']
                    shortName = nil_or_blank(shortName) ? trailName : shortName
                    if !nil_or_blank(trailName)
                        feature_property(feature, 'name', trailName)
                    end
                    if !nil_or_blank(shortName)
                        feature_property(feature, 'shortName', shortName)
                    end
                end

                feature_property(feature, 'surface', surface_of(trail_ids))
                feature_property(feature, 'color', color_for(trails[0]['color']))
                if trails.count > 1
                    feature_property(feature, 'color2', color_for(trails[1]['color']))
                end
                if trails.count > 2
                    feature_property(feature, 'color3', color_for(trails[2]['color']))
                end
                gpx_features.push(feature)
            else
                abort_msg("GPX track with invalid ID.", node)
            end
        else
            error_msg('Route or track with no name', node)
        end
    end

    # NB: inner borders will get duplicated if there's > 1 main border
    unprocessed_borders.each do |park_id, nodes|
        nodes.each do |node|
            outer_coords = collect_polygon(node)
            border_id = "border:#{park_id}:#{random_id()}"

            feature = create_feature('parkBorder', border_id, "border")
            feature_property(feature, "parkID", park_id)
            feature['geometry']['type'] = 'Polygon'
            polygons = [outer_coords]

            inners = unprocessed_inner_borders[park_id] || []
            inners.each do |inner_node|
                polygons.push(collect_polygon(inner_node))
            end
            feature['geometry']['coordinates'] = polygons
            gpx_features.push(feature)
        end
    end

    waypoints = gpx_xml.root().search("wpt")
    waypoints.each do |node|
        names = node.>("name")
        point_id = nil
        point = nil
        if names.count > 0 then
            point_id = names.first.content
        end
        descs = node.>("desc")
        if descs.count > 0 && descs.first.content.length > 0 then
            point = JSON.load(descs.first.content)
        end

        if !point_id || !point_id.include?(":") || !point
            next
        end

        #register_and_validate_unique_id(point_id, "waypoint")
        poi_type = point["type"] || point_id.split(":").first
        if !$metadata[:poiTypes].include?(poi_type)
            $metadata[:poiTypes].push(poi_type)
        end

        feature = create_feature(poi_type, point_id, "waypoint")

        feature['geometry'] = create_point_geometry([node["lon"].to_f, node["lat"].to_f])

        if point['name']
            feature_property(feature, 'name', point['name'])
        end

        short_name = point["shortName"] || point["name"]
        if short_name
            feature_property(feature, 'shortName', short_name)
        end
        if point["parentIDs"]
            point["parentIDs"].each do |parent_id|
                validate_id_exists(parent_id, "waypoint parentID")
            end
            feature_property(feature, "parentIDs", point["parentIDs"].join(","))
        end
        optional_property(feature, 'url', point)
        default_allows_directions = ['point-boat_launch', 'point-lodge', 'point-parking', 'point-smparking', 'point-shelter'].include?(poi_type)
        optional_property(feature, 'allowsDirections', point, dflt: default_allows_directions)
        if point['directionsCoordinate']
            feature_property(feature, 'directionsCoordinate', point['directionsCoordinate'].reverse)
        end
        optional_property(feature, 'visibilityConstraint', point)
        optional_property(feature, "keywords", point)

        gpx_features.push(feature)
    end

    return gpx_features
end

def track_type(name)
    tokens = name.split(":")
    if tokens.count < 1
        return nil
    end
    return tokens.first
end

def park_id_from_border_id(name)
    tokens = name.split(":")
    if tokens.count == 2
        return tokens[1]
    else
        abort_msg("Invalid GPX track ID format.", name)
    end
end

def trail_ids_from_segment_id(name)
    tokens = name.split(":")
    if tokens.count >= 2
        return tokens[1]
    else
        abort_msg("Invalid GPX track ID format.", name)
    end
end

def collect_coords(track_or_route)
    json_coords = []
    points = track_or_route.search('trkpt', 'rtept')
    points.each do |point|
        json_coords << [point["lon"].to_f, point["lat"].to_f]
    end

    if json_coords.count < 2
        abort_msg('Fewer than two coords', track_or_route)
    end
    return json_coords
end

def collect_polygon(track_or_route)
    json_coords = collect_coords(track_or_route)
    if !json_coords.empty?
        json_coords.push(json_coords[0])
    end
    return json_coords
end

### JSON ######################

def load_bundle(filename)
    $metadata['bundle'] = JSON.load(IO.read(filename))
end

def parse_json(filename)

    debug_trace('Parsing JSON ' + filename)

    data = JSON.load(IO.read(filename))
    if data["version"] != $data_version
        abort_msg("Incompatible JSON data version for #{filename}", nil)
    end

    json_features = []

    if data['parks']
        data["parks"].each do |park_id, park|
            $metadata[:parks][park_id] = park
            #register_and_validate_unique_id(park_id, "JSON park")

            feature = create_feature('park', park_id, "JSON park")
            feature['geometry'] = create_point_geometry(park['mainPin'].reverse)

            shortName = nil_or_blank(park['shortName']) ? park['name'] : park['shortName']
            if !nil_or_blank(shortName)
                feature_property(feature, 'shortName', shortName)
            end

            if !nil_or_blank(park['name'])
                optional_property(feature, 'name', park)
            end
            optional_property(feature, 'url', park)
            optional_property(feature, 'allowsDirections', park, dflt: true)
            optional_property(feature, 'annotationIconName', park)
            optional_property(feature, 'hideInListView', park, dflt: nil_or_blank(park['name']))
            optional_property(feature, 'visibilityConstraint', park)
            optional_property(feature, "keywords", park)
            
            if park['directionsCoordinate']
                feature_property(feature, 'directionsCoordinate', park['directionsCoordinate'].reverse)
            end

            json_features << feature
        end
    end

    if data['trails']
        data['trails'].each do |trail_id, trail|

            if [].include?(trail_id)
                trail['surface'] = ''
            else
                trail['surface'] = ''
            end
            
            $metadata[:trails][trail_id] = trail
            #register_and_validate_unique_id(trail_id, "JSON trail")

            feature = create_feature('trail', trail_id, "JSON trail")
            feature['geometry'] = create_point_geometry(center_of(trail['SW'], trail['NE']))

            if trail['parkID']
                feature_property(feature, 'parkID', trail['parkID'])
            end
            if !nil_or_blank(trail['name'])
                optional_property(feature, 'name', trail)
            end
            optional_property(feature, 'url', trail)
            feature_property(feature, 'color', color_for(trail['color']))

            shortName = nil_or_blank(trail['shortName']) ? trail['name'] : trail['shortName']
            if !nil_or_blank(shortName)
                feature_property(feature, 'shortName', shortName)
            end

            optional_property(feature, 'hideInListView', trail, dflt: nil_or_blank(trail['name']))
            optional_property(feature, 'visibilityConstraint', trail)
            optional_property(feature, "keywords", trail)

            json_features << feature
        end
    end

    json_features
end

# do it ################################

if $dest_dir
    $features = {}
else
    $features = []
end


load_bundle($source_dir + 'bundle.json')
# if $pretty || $dry_run
#     print JSON.pretty_generate($metadata['bundle'])
# end

$json_filenames.each do |filename|
    next_features = parse_json($source_dir + filename + '.json')
    if $dest_dir
        if !$features.has_key?(filename)
            $features[filename] = []
        end
        $features[filename] = $features[filename] + next_features
    else
        $features = $features + next_features
    end
end

$gpx_filenames.each do |filename|
    next_features = parse_gpx($source_dir + filename + '.gpx')
    if $dest_dir
        if !$features.has_key?(filename)
            $features[filename] = []
        end
        $features[filename] = $features[filename] + next_features
    else
        $features = $features + next_features
    end
end

if $dest_dir

    if !$dry_run
        if !Dir.exist?($dest_dir)
            abort_msg('Output directory missing.', $dest_dir)
        end
        if !(Dir.empty?($dest_dir) || ['.', '..', '.DS_Store'] == Dir.entries($dest_dir))
            abort_msg('Output directory not empty.', $dest_dir)
        end
    end

    print('Writing GeoJSON files to ' + $dest_dir + "...\n")
    $features.each do |filename, featureset|
        doc = {}
        doc['type'] = 'FeatureCollection'
        doc['features'] = featureset
        full_filename = filename + '.geojson'
        print('Writing data to ' + full_filename + "...\n")

        if $dry_run
            next
        end

        if $pretty
            IO.write($dest_dir + full_filename, JSON.pretty_generate(doc))
        else
            IO.write($dest_dir + full_filename, JSON.generate(doc))
        end
    end
else
    doc = {}
    doc['type'] = 'FeatureCollection'
    doc['features'] = $features

    if $dry_run
        print "Dry run complete."
        print JSON.pretty_generate($metadata)
#        print JSON.pretty_generate(doc)
    elsif $pretty
        print JSON.pretty_generate(doc)
    else
        print JSON.generate(doc)
    end
    print "\n"
end
