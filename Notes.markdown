## The GeoJSON format

- There is a fair amount of repetition in the metadata (e.g. every trail segment has the trail name, color, etc.). This is done to support the various layers in the Mapbox Style
- Each trail, park, and point of interest is represented by a single “Point” feature in the Geojson, as a single place to store the metadata for these entities. The coordinate of the point determines where the point of interest or park icon appears on the map. For trails, the coordinate is not important. The actual tracks for trails are LineString features, and park borders are Polygon features.
- Every GPX should be split into segments. The rule is to split a track at every road or trail intersection. This is to support selecting individual segments in the app to get information such as segment length, and eventually for additional possible features such as selecting a series of segments 
- Every feature needs a unique "trailsroc-id" property - even individual trail segments and park borders. You’ll see that the ID values follow a naming convention; the app requires the IDs to be properly formatted

## Migrating/preparing GPX/JSON files and converting to GeoJSON

The GeoJSON data hosted on Mapbox is generated using a script, from the GPX+JSON files used in the old version of the app. The `scripts` directory contains the Ruby scripts that assist in generating the GeoJSON.

The main script, `make_geojson.rb`, is what generates GeoJSON files from GPX+JSON input. It does a bunch of validation, to ensure that IDs are valid and unique, all required fields exist, etc. It generates all of the GeoJSON features, including all trail segments, park borders, etc.

The GPX+JSON source files have been updated a bit in order to work well with the GeoJSON schema. Check the `source` directory to see the latest GPX+JSON files. Some of the JSON fields have changed, and points of interest are now GPX waypoints instead of JSON objects. If you have an older style GPX+JSON pair, there are other scripts that can help migrate it to the latest format. These are listed in the order that they should be run:

1. `schema_migrator.rb` - mainly generates unique IDs compatible with the new format, and moves points of interest from JSON to GPX
2. `parentID_migrator.rb` - changes parkID/trailID field for points of interest to the combined parentIDs field
3. `shortName_normalizer.rb` - masages the shortName field so it's properly displayed by the Mapbox Style
4. `trailSystems.rb` - converts some trails to trail systems, changes trails' parkID field to parentID, changes hideInListView to isSearchable

######

westmost point on erie canal trail:
43.237757, -78.026937

eastmost point on canal trail:
43.073989, -77.301157

southernmost: hitor/letchworth:
42.544895, -78.055244

northernmost: lake ontario shore:
43.391925, -78.138655

For the above region:
SW: 42.544895, -78.138655
NE: 43.391925, -77.301157

comfortable padding to the west: outside albion/batavia/letchworth:
lon -78.323191

comfortable padding to the east: outside sodus/newark/hammondsport:
lon -77.047307

Including the comfortable padding:

SW: 42.544895, -78.323191
NE: 43.391925, -77.047307




42.7736
-77.8772

43.4047
-77.3913



zoom 16
▿ MGLCoordinateBounds
  ▿ sw : CLLocationCoordinate2D
    - latitude : 43.0186603325281
    - longitude : -77.586046458744022
  ▿ ne : CLLocationCoordinate2D
    - latitude : 43.023892184631052
    - longitude : -77.582023145261815


zoom 15
▿ MGLCoordinateBounds
  ▿ sw : CLLocationCoordinate2D
    - latitude : 43.021118420648662
    - longitude : -77.587102390022665
  ▿ ne : CLLocationCoordinate2D
    - latitude : 43.03158126009393
    - longitude : -77.57905576305842



