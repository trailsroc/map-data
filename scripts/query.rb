# usage: ruby query.rb help

require 'json'

def process(query_terms, file_paths)
    query = GeoJSONQuery.new(query_terms)

    file_paths.each do |path|
        if !File.exist?(path)
            abort_msg("File does not exist.", path)
        end
        geojson = JSON.load(IO.read(path))
        if !geojson || !geojson.has_key?("features")
            abort_msg("Unable to parse GeoJSON file.", path)
        end
        filename = File.split(path).last
        process_shapes(query, geojson["features"], filename)
    end
end

def process_shapes(query, shapes, filename)
    shapes.each do |shape|
        result = query.visit(shape)
        if !nil_or_blank(result)
            print "#{filename}:#{result}\n"
        end
    end
end

class GeoJSONQuery
    def initialize(text)
        tokens = (text || "").strip().split(".").map { |token| token.strip }
        case tokens.count
        when 0 then
            type = nil
            key = nil
        when 1 then
            type = tokens.first
            key = nil
        when 2 then
            type = tokens.first
            key = tokens.last
        else
            abort_msg("Bad query string.", $usage)
        end

        if nil_or_blank(type)
            @entity_filter = lambda { |etype| true }
        elsif type == "poi"
            @entity_filter = lambda { |etype| etype.split("-").first == "point" }
        else
            @entity_filter = lambda { |etype| etype == type }
        end

        @property_key = nil_or_blank(key) ? nil : key
    end

    def visit(shape)
        if @entity_filter.call(shape["properties"]["trailsroc-type"] || "")
            return result_for(shape)
        else
            return nil
        end
    end

    def result_for(shape)
        if !@property_key
            return shape["properties"]["trailsroc-id"]
        elsif shape["properties"].has_key?("trailsroc-" + @property_key)
            return shape["properties"]["trailsroc-" + @property_key]
        else
            return nil
        end
    end
end

# General helpers ################################

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

def nil_or_blank(str)
    str == nil || str.strip().empty?
end

# Go #############################################

$usage = <<-USAGE
USAGE:
List all entities in the given geojson files:
$ ruby query.rb . file1.geojson [file2.geojson...]

Query the geojson files:
$ ruby query.rb entityType file1.geojson [file2.geojson...]
$ ruby query.rb .propertyName file1.geojson [file2.geojson...]
$ ruby query.rb entityType.propertyName file1.geojson [file2.geojson...]

entityType: Filters the features selected from the geojson files based
on their "trailsroc-type" property value.
Valid values: park, trail, trailSystem, trailSegment, parkBorder, point-X
Can also specify "poi" to query all points of interest.

propertyName: Determines what to print for each selected feature.
If unspecified, prints a general description of the entity.
Otherwise, prints the value of the "trailsroc-X" property. Omit the 
"trailsroc-" prefix.

Note that each line of output is prefixed by the file name and a colon, 
e.g. "X.geojson:".

Specific examples:

Count total number of features:
$ ruby query.rb . *.geojson | wc -l
List of all trail colors:
$ ruby query.rb .color *.geojson | cut -d : -f 2- | sort -u
List of all POI types:
$ ruby query.rb poi.type | sort -u
List of all park names:
$ ruby query.rb park.name
USAGE

query_text = ARGV.shift
file_paths = ARGV

if nil_or_blank(query_text) || file_paths.empty?
    abort_msg($usage, nil)
end

process(query_text, file_paths)
