#!/usr/bin/env python3
""" truncate_gpx
Usage:
    truncate_gpx.py INGPX OUTGPX
"""
import gpxpy
import docopt
import numpy as np


def truncate(g):
    for waypoint in gpx.waypoints:
        waypoint.latitude = np.round(waypoint.latitude, decimals=6)
        waypoint.longitude = np.round(waypoint.longitude, decimals=6)
        if waypoint.elevation:
            waypoint.elevation = np.round(waypoint.elevation, decimals=6)

    for track in gpx.tracks:
        for segment in track.segments:
            for point in segment.points:
                point.latitude = np.round(point.latitude, decimals=6)
                point.longitude = np.round(point.longitude, decimals=6)
                if point.elevation:
                    point.elevation = np.round(point.elevation, decimals=2)


def p(g):
    for track in gpx.tracks:
        for segment in track.segments:
            for point in segment.points:
                print(point)


if __name__ == "__main__":
    args = docopt.docopt(__doc__)

    with open(args["INGPX"], "r") as fd:
        gpx = gpxpy.parse(fd)
        truncate(gpx)
        with open(args["OUTGPX"], "w") as outFD:
            outFD.write(gpx.to_xml())
