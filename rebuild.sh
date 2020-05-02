#!/usr/bin/env bash
rm geojson/* && ruby scripts/make_geojson.rb && geojson-merge geojson/* > features2.geojson
