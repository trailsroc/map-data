# map-data

Raw map data for the [\#TrailsRoc](https://trailsroc.org/) app and web-based maps.

## Process for adding and updating data

1. Create GPX data in `source/file.gpx`
    - One track for each trail segment
    - One waypoint for each POI
2. Define metadata in GPX
    - Decide on unique IDs for top level entities (trails, trail systems, and parks). e.g. `trail-elcamino-main`, `tsystem:elcamino`, `park:mponds`
    - Assign unique IDs to all trail segments and waypoints using naming conventions. Set these as the text of each track/waypoint's `name` element. `ruby query.rb --makeids count` will create a batch of IDs for convenience
    - Populate the `desc` element of each waypoint with a JSON string of additional metadata
3. Generate JSON files and populate remaining metadata
    - Any _new_ trails, trail systems, or parks need to be added to `source/file.json`. POI and additional segments for existing trails do not require JSON file changes
    - To get started, run `ruby extract_trail_json.rb path-to-gpx-file` and paste the output into the JSON file
    - Add additional properties to the JSON as needed
    - Manually define `trailSystem` objects as needed (not currently supported by `extract_trail_json.rb`)
4. Generate geojson files
    - `ruby scripts/make_geojson.rb`. Modify `gpx_filenames` array as needed to use only a subset of files, etc. Note that you may need to include some unchanged files to satisfy dependencies if you encounter "ID does not exist" errors
5. Prepare dataset/tileset/style for review and testing
    - Upload geojson file(s) to a new or existing test dataset
    - Create or replace a test tileset with the updated geojson data
    - Replace the tileset ID in a test styleset with the appropriate tileset ID:
        - Search the style JSON for `trailsroc.` and replace that string with the tileset ID
        - Replace all `source-layer` string values with the tileset name
    - Test the style. Use the Mapbox Studio Preview app, or on studio.mapbox.com click the style's Share button to access some preview URLs
    - Publish the test style and test app behavior and dataset metadata/search functionality in map.trailsroc.org and the app
6. Create a pull request
7. Integrate with the production maps
    - Run `rebuild.sh`
    - Create or update a `prod-v1-build1` dataset with the combined geojson file
    - Export tileset
    - Ensure the prod outdoors and satellite styles use the updated tileset
