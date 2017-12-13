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
        results = query.visit(shape)
        results.select { |result| !nil_or_blank(result) }.each do |result|
            print "#{filename}:#{result}\n"
        end
    end
end

class GeoJSONQuery
    def initialize(text)
        tokens = (text || "").strip().split(".").map { |token| token.strip }
        case tokens.count
        when 0 then
            filter_text = nil
            selector = nil
        when 1 then
            filter_text = tokens.first
            selector = nil
        when 2 then
            filter_text = tokens.first
            selector = tokens.last
        else
            abort_msg("Bad query string.", $usage)
        end

        if nil_or_blank(filter_text)
            @entity_filter = lambda { |etype, shape| true }
        elsif filter_text.start_with?("?")
            filter_text = filter_text[1..-1]
            if filter_text.empty?
                abort_msg("Bad query string: #{text}", $usage)
            end
            filter_key = "trailsroc-" + filter_text
            @entity_filter = lambda { |shape, etype| shape["properties"].has_key?(filter_key) }
        elsif filter_text == "poi"
            @entity_filter = lambda { |shape, etype| etype.start_with?("point-") }
        else
            @entity_filter = lambda { |shape, etype| etype == filter_text }
        end

        if nil_or_blank(selector)
            selector = "id"
        end

        if selector == "@keys"
            @output_selector = lambda { |shape| shape["properties"].keys }
        else
            output_key = "trailsroc-" + selector
            @output_selector = lambda { |shape| shape["properties"].has_key?(output_key) ? [shape["properties"][output_key]] : [] }
        end
    end

    def visit(shape)
        if @entity_filter.call(shape, shape["properties"]["trailsroc-type"] || "")
            return @output_selector.call(shape)
        else
            return []
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
$ ruby query.rb [filter].[selector] file1.geojson [file2.geojson...]

filter: determines which GeoJSON features to output.

Possible values of filter:
- (unspecified):
    Matches all features.
- park, trail, trailSystem, trailSegment, parkBorder, point-XYZ:
    Matches features with the given trailsroc-type value.
- poi:
    Matches features with any point-XYZ trailsroc-type.
- ?key: 
    Matches features where the trailsroc-<key> property exists.

selector: determines what to print about each feature.

Each line of output starts with the filename and a colon, followed
by a description of the matched feature, as deterined by selector.
Possible values of selector:
- (unspecified):
    Prints the trailsroc-id value of each feature.
- key:
    Prints the value of the feature's trailsroc-<key> property.
- @keys:
    Lists the names of the trailsroc-XYZ property keys that exist 
    for the matched features. Note this may produce more than one line
    of output per feature.

Examples:

Count total number of features:
$ ruby query.rb . *.geojson | wc -l
List of all trail colors ("cut" removes the filenames):
$ ruby query.rb .color *.geojson | cut -d : -f 2- | sort -u
List of all POI types:
$ ruby query.rb poi.type *.geojson | cut -d : -f 2- | sort -u
List of all park names:
$ ruby query.rb park.name *.geojson
List of features that have any search keywords:
$ ruby query.rb ?keywords *.geojson
List of all properties used by points of interest:
$ ruby query.rb poi.@keys *.geojson | cut -d : -f 2- | sort -u
List of geojson files that have some obsolete property:
$ ruby query.rb ?bogus *.geojson | cut -d : -f 1 | sort -u

USAGE

query_text = ARGV.shift
file_paths = ARGV

if nil_or_blank(query_text) || query_text == "help" || file_paths.empty?
    abort_msg($usage, nil)
end

process(query_text, file_paths)
