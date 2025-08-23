#!/usr/bin/env python

import os
import glob
import gpxpy
import tr_process as tp
import astropy.units as u
from numpy.random import default_rng
import struct
import json
import numpy as np

rng = default_rng()

valid_colors = [
    "black",
    "blue",
    "brown",
    "dark_green",
    "grass",
    "green",
    "orange",
    "pink",
    "purple",
    "red",
    "sky",
    "teal",
    "white",
    "yellow",
]


def populate_trails(path, url, gpx_all):
    trails = dict()
    for x in os.listdir(path):
        if not os.path.isdir(os.path.join(path, x)):
            continue
        if x.lower() not in valid_colors:
            continue
        for g in glob.glob(os.path.join(path, x, "*gpx")):
            with open(g, "r") as fd:
                a = tp.read_gpx(fd)
            for track in a.tracks:
                bounds = track.get_bounds()
                id = "trails-{}-{}".format(path.lower(), extract_id(track.name))
                trails[id] = dict()
                trails[id]["name"] = track.name
                trails[id]["color"] = x.lower()
                trails[id]["length"] = (
                    np.ceil((track.length_2d() * u.m).to_value(u.imperial.mile) * 100)
                    / 100
                )
                trails[id]["SW"] = [bounds.min_latitude, bounds.min_longitude]
                trails[id]["NE"] = [bounds.max_latitude, bounds.max_longitude]
                trails[id]["parentID"] = "park-{}".format(path.lower())
                trails[id]["url"] = url
                rand_id = "{:08x}".format(struct.unpack("!L", rng.bytes(4))[0])
                track.name = "{}:{}:{}".format("seg", id, rand_id)
                # gpx_all.tracks.append(track)
            gpx_all.tracks.extend(a.tracks)
            gpx_all.waypoints.extend(a.waypoints)

    return gpx_all, trails


def extract_id(s):
    if "-" in s:
        name = s.split("-")[1].strip()
    else:
        name = s
    return name.replace(" ", "_").lower()


def populate_parks(path):
    with open(os.path.join(path, "park.json"), "r") as fd:
        park = json.load(fd)
    with open(os.path.join(path, "Boundary.gpx"), "r") as fd:
        a = tp.read_gpx(fd)
    key = [k for k in park.keys() if "park" in k]

    return a, park, park[key[0]]["url"]


def populate_poi(path, gpx_all):
    with open(os.path.join(path, "POI.gpx"), "r") as fd:
        a = tp.read_gpx(fd)
        gpx_all.waypoints.extend(a.waypoints)
    return gpx_all


def gather_data(path):
    meta = dict()
    meta["version"] = 5
    meta["trailsSystems"] = dict()
    trails, meta["parks"], url = populate_parks(path)
    trails = populate_poi(path, trails)
    trails, meta["trails"] = populate_trails(path, url, trails)
    trails.remove_elevation()
    return trails, meta


def scatter_data(name, gpx_all, meta):
    with open(os.path.join("..", "source", name + ".json"), "w") as fd:
        json.dump(meta, fd, indent=1)
    with open(os.path.join("..", "source", name + ".gpx"), "w") as fd:
        fd.write(gpx_all.to_xml(version="1.1"))


if __name__ == "__main__":
    scatter_data("tryon", *gather_data("Tryon"))
    scatter_data("letchworth", *gather_data("Letchworth"))
