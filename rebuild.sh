#!/usr/bin/env bash
rm geojson/* && scripts/make_geojson.rb && geojson-merge geojson/* > features2.geojson
