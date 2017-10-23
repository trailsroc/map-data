# usage: ruby make_geojson.rb | pbcopy

require 'json'
require 'nokogiri'

# initialize ################################

$pretty = false
$dry_run = true
$source_dir = '/Users/mike/Documents/src/Trails/maps.trailsroc.org/map-data/source/'
#$dest_dir = '/Users/mike/Documents/src/Trails/maps.trailsroc.org/geojson/'
#gpx_filenames = ['mponds']
gpx_filenames = ['abe', 'auburntr', 'black_creek', 'canal', 'churchville_park', 'city_parks', 'corbetts', 'crescenttr', 'durand_eastman', 'ellison', 'gcanal', 'gosnell', 'gvalley', 'highland', 'hitor', 'ibaymar', 'ibaywest', 'lehigh', 'lmorin', 'mponds', 'nhamp', 'oatka', 'ontariob', 'pmills', 'senecapk', 'senecatr', 'tryon', 'vht', 'webstercp', 'webstertr', 'wrnp']
json_filenames = gpx_filenames

$metadata = {:parks => {}, :trails => {}, :poiTypes => [], :bundle => {}, :idlist => []}

# ls ../source/*.gpx | cut -d '/' -f 3 | cut -d '.' -f 1 | pbcopy
# ls ../source/*.json | cut -d '/' -f 3 | cut -d '.' -f 1 | pbcopy

# process funcs ################################

def nil_or_blank(str)
    str == nil || str.strip().empty?
end

# transform a lat/lng pair to a string for use in ID generation
def coordinate_id(lng_lat)
    lat = lng_lat[1]
    lng = lng_lat[0]
    return "#{sprintf('%3.6f', lat.abs).gsub(/\./, '')}#{lat < 0 ? 's' : 'n'}#{sprintf('%3.6f', lng.abs).gsub(/\./, '')}#{lng < 0 ? 'w' : 'e'}"
end

# idempotent.
def standardize_park_id(park_id)
    fix_id_punct(require_prefix(park_id, 'park-'))
end

# idempotent.
def standardize_trail_id(trail_id_or_plural)
    ids = trail_id_or_plural.split(',')
    ids = ids.map do |id| fix_id_punct(require_prefix(id, 'trail-')) end
    ids.join(',')
end

def trail_metadata_for(trail_id_or_plural)
    return standardize_trail_id(trail_id_or_plural).split(',').map do |id|
        $metadata[:trails][id]
    end
end

def color_for(name)
    name
#    return $metadata['bundle']['appConfig']['colors'][name]['hex']
end

# idempotent.
def standardize_poi_type(type)
    if type == 'boat_launch'
        type = 'boatLaunch'
    end
    type = fix_id_punct(require_prefix(type, 'point-'))
end

# NOT idempotent.
def standardize_poi_name(raw_name, raw_type)
    name = raw_name
    if raw_type == 'intersection'
        name = 'Intersection ' + name
    end
    # TODO do this?? if !name
    #     name_type_map = {
    #         'parking' => 'Parking',
    #         'restroom' => 'Restroom',
    #         'scenic' => ''
    #     }
    #     name = name_type_map[raw_type]
    # end
    name
end

# idempotent.
def require_prefix(value, prefix)
    if !value.match?(prefix)
        value = prefix + value
    end
    value
end

# idempotent.
def fix_id_punct(value)
    value = value.gsub(/_/, '-')
end

def surface_of(trail_id_standardized)
    surface_map = {
        'trail-lehigh-valley-main' => 'gravel',
        'trail-lvt-auburntr-ramp' => 'gravel',
        'trail-ecanal-main' => 'paved',
        'trail-pmills-roads' => 'road'
    }
    surface_map[trail_id_standardized.split(',')[0]] || 'singletrack'
end

def create_feature(trailsroc_type, trailsroc_id)
    if $metadata[:idlist].include?(trailsroc_id)
        error_msg('Duplicate feature ID detected', trailsroc_id)
        Kernel.exit(1)
    end
    $metadata[:idlist].push(trailsroc_id)

    feature = {}
    feature['properties'] = {}
    feature['geometry'] = {}
    feature['type'] = 'Feature'
    feature_property(feature, 'type', trailsroc_type)
    feature_property(feature, 'id', trailsroc_id)
    feature
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
    if source.has_key?(short_key)
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
            if name_is_border(name) then
                park_id = standardize_park_id(get_border_name(name))
                if is_inner_border(name) then
                    if !unprocessed_inner_borders[park_id]
                        unprocessed_inner_borders[park_id] = []
                    end
                    unprocessed_inner_borders[park_id].push(node)
                else
                    if !unprocessed_borders[park_id]
                        unprocessed_borders[park_id] = []
                    end
                    unprocessed_borders[park_id].push(node)
                end
            else
                trail_id = standardize_trail_id(name)
                trails = trail_metadata_for(trail_id)
                coordinates = collect_coords(node)
                segment_id = "seg-#{trail_id}-id#{coordinate_id(center_of_list(coordinates))}"
                feature = create_feature('trailSegment', segment_id)
                feature['geometry']['type'] = 'LineString'
                feature['geometry']['coordinates'] = coordinates
                feature_property(feature, 'trailIDs', trail_id)

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

                feature_property(feature, 'surface', surface_of(trail_id))
                feature_property(feature, 'color', color_for(trails[0]['color']))
                if trails.count > 1
                    feature_property(feature, 'color2', color_for(trails[1]['color']))
                end
                if trails.count > 2
                    feature_property(feature, 'color3', color_for(trails[2]['color']))
                end
                gpx_features << feature
            end
        else
            error_msg('Route or track with no name', node)
        end
    end

    # NB: inner borders will get duplicated if there's > 1 main border
    unprocessed_borders.each do |park_id, nodes|
        nodes.each do |node|
            outer_coords = collect_polygon(node)
            border_id = "border-#{park_id}-id#{coordinate_id(center_of_list(outer_coords))}"

            feature = create_feature('parkBorder', border_id)
            feature['geometry']['type'] = 'Polygon'
            polygons = [outer_coords]

            inners = unprocessed_inner_borders[park_id] || []
            inners.each do |inner_node|
                polygons.push(collect_polygon(inner_node))
            end
            feature['geometry']['coordinates'] = polygons
            gpx_features << feature
        end
    end

    gpx_features
end

def name_is_border(name)
    return get_border_name(name) != nil
end

def is_inner_border(name)
    name.split(":")[0] == 'innerBorder'
end

def get_border_name(name)
    splitted = name.split(":")
    return splitted.count > 0 ? splitted[1] : nil
end

def collect_coords(track_or_route)
    json_coords = []
    points = track_or_route.search('trkpt', 'rtept')
    points.each do |point|
        json_coords << [point["lon"].to_f, point["lat"].to_f]
    end

    if json_coords.count < 2
        error_msg('Fewer than two coords', track_or_route)
        Kernel.exit(1)
    end
    json_coords
end

def collect_polygon(track_or_route)
    json_coords = collect_coords(track_or_route)
    if !json_coords.empty?
        json_coords.push(json_coords[0])
    end
    json_coords
end

### JSON ######################

def load_bundle(filename)
    $metadata['bundle'] = JSON.load(IO.read(filename))
end

def parse_json(filename)

    debug_trace('Parsing JSON ' + filename)

    data = JSON.load(IO.read(filename))

    json_features = []

    if data['parks']
        data["parks"].each do |park_id, park|
            park_id = standardize_park_id(park_id)
            $metadata[:parks][park_id] = park

            feature = create_feature('park', park_id)
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
            optional_property(feature, 'hideInListView', park, dflt: false)
            optional_property(feature, 'visibilityConstraint', park)
            
            if park['directionsCoordinate']
                feature_property(feature, 'directionsCoordinate', park['directionsCoordinate'].reverse)
            end

            json_features << feature
        end
    end

    if data['trails']
        proto_trail = data['trails']['_prototype'] || {}

        data['trails'].each do |trail_id, trail|
            if trail_id == '_prototype'
                next
            end


            if [].include?(trail_id)
                trail['surface'] = ''
            else
                trail['surface'] = ''
            end
            
            trail = proto_trail.merge(trail)
            trail_id = standardize_trail_id(trail_id)
            $metadata[:trails][trail_id] = trail

            feature = create_feature('trail', trail_id)
            feature['geometry'] = create_point_geometry(center_of(trail['SW'], trail['NE']))

            if trail['parkId']
                park_id = standardize_park_id(trail['parkId'])
                feature_property(feature, 'parkID', park_id)
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

            optional_property(feature, 'hideInListView', trail, dflt: false)
            optional_property(feature, 'visibilityConstraint', trail)

            json_features << feature

            (trail['trailheads'] || []).each do |trailhead|
                trailhead_id = "trailhead-#{trail_id}-id#{coordinate_id(trailhead.reverse)}"
                feature = create_feature('trailhead', trailhead_id)
                feature['geometry'] = create_point_geometry(trailhead.reverse)
                feature_property(feature, 'trailID', trail_id)
                json_features << feature
            end
        end
    end

    if data['points']
        data['points'].each do |point|
            if point['type']
                standard_type = standardize_poi_type(point['type'])
                if !$metadata[:poiTypes].include?(standard_type)
                    $metadata[:poiTypes].push(standard_type)
                end
                point_id = point['id'] || "poi-id#{coordinate_id(point['loc'].reverse)}"
                feature = create_feature(standard_type, point_id)
                feature['geometry'] = create_point_geometry(point['loc'].reverse)

                name = standardize_poi_name(point['name'], point['type'])
                if name
                    feature_property(feature, 'name', name)
                end
                optional_property(feature, 'url', point)
                default_allows_directions = ['boat_launch', 'lodge', 'parking', 'shelter'].include?(point['type'])
                optional_property(feature, 'allowsDirections', point, dflt: default_allows_directions)
                if point['directionsCoordinate']
                    feature_property(feature, 'directionsCoordinate', point['directionsCoordinate'].reverse)
                end
                optional_property(feature, 'visibilityConstraint', point)
                json_features << feature
            else
                error_msg('Point has no type:', point)
            end
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

json_filenames.each do |filename|
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

gpx_filenames.each do |filename|
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
            error_msg('Output directory missing.', $dest_dir)
            Kernel.exit(1)
        end
        if !(Dir.empty?($dest_dir) || ['.', '..', '.DS_Store'] == Dir.entries($dest_dir))
            error_msg('Output directory not empty.', $dest_dir)
            Kernel.exit(1)
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
    elsif $pretty
        print JSON.pretty_generate(doc)
    else
        print JSON.generate(doc)
    end
    print "\n"
end
