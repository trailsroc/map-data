#!/usr/bin/env python3
import gpxpy
import numpy as np
import click


def truncate(gpx):
    for waypoint in gpx.waypoints:
        waypoint.latitude = np.round(waypoint.latitude, decimals=6)
        waypoint.longitude = np.round(waypoint.longitude, decimals=6)
        if waypoint.elevation:
            waypoint.elevation = np.round(waypoint.elevation, decimals=6)

    for track in gpx.tracks:
        track.reduce_points(min_distance=1)
        for segment in track.segments:
            for point in segment.points:
                point.latitude = np.round(point.latitude, decimals=6)
                point.longitude = np.round(point.longitude, decimals=6)
                if point.elevation:
                    point.elevation = np.round(point.elevation, decimals=2)


def p(gpx):
    for track in gpx.tracks:
        for segment in track.segments:
            for point in segment.points:
                print(point)


def read_gpx(fd):
    gpx = gpxpy.parse(fd)
    truncate(gpx)
    return gpx


@click.command()
@click.argument("infn", type=click.File("r"))
@click.argument("outfn", type=click.File("w"))
def main(infn, outfn):
    gpx = gpxpy.parse(infn)
    truncate(gpx)
    outfn.write(gpx.to_xml())


if __name__ == "__main__":
    main()
