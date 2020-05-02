#!/usr/bin/env python3

import json
import dictdiffer
import numpy as np


def compare_names(a, b):
    a_names = set([d["properties"]["trailsroc-id"] for d in a["features"]])
    b_names = set([d["properties"]["trailsroc-id"] for d in b["features"]])
    print(a_names - b_names)
    print(b_names - a_names)


def prune_diff(d):
    pruned = list()
    for x in d:
        if x[0] == "add" and x[2][0][0] == "id":
            continue
        if x[0] == "change" and x[1][0] == "geometry":
            if np.abs((x[2][0] - x[2][1])) < 1e-6:
                continue
        # [('change', ['geometry', 'coordinates', 1], (43.1877755, 43.187775))]

        pruned.append(x)
    return pruned


def compare_by_name(a, b, a_data, name):
    c = [x for x in b["features"] if x["properties"]["trailsroc-id"] == name]
    if len(c) == 0:
        return
    if len(c) != 1:
        print("Unexpected {} length {}".format(name, len(c)))
    diff = prune_diff([d for d in dictdiffer.diff(c[0], a_data)])
    if len(diff) == 0:
        return
    print(name)
    print(diff)


if __name__ == "__main__":
    a = json.load(open("from_mapbox_features.geojson", "r"))
    b = json.load(open("features2.geojson", "r"))
    compare_names(a, b)
    for feature in a["features"]:
        compare_by_name(a, b, feature, feature["properties"]["trailsroc-id"])
