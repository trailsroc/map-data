import numpy as np
import geopandas as gpd
from pathlib import Path
import fiona
import hashlib
from typing import Any

from tr_process.features import (
    Surfaces,
    Colors,
    Border,
    Trail,
    POI,
    TrailsRocFeatures,
    TrailsRocBorder,
    TrailsRocTrail,
    TrailsRocPoi,
    BorderProps,
    PoiProps,
    PoiTypes,
    TrailProps,
)
# from devtools import pprint

(
    Border,
    Trail,
    POI,
    TrailsRocFeatures,
    TrailsRocBorder,
    TrailsRocTrail,
    TrailsRocPoi,
    BorderProps,
)


def get_hash(obj):
    return hashlib.shake_128(str(obj).encode("utf-8")).hexdigest(4)


def round_coord(d):
    return list(np.asarray(d.coords).round(5))


def from_boundary(pkg: gpd.GeoDataFrame, parkID: str) -> list[TrailsRocBorder]:
    features = []
    for p in pkg.itertuples():
        coords = [round_coord(p.geometry.boundary)]
        id = f"border:park-{parkID}"
        obj = TrailsRocBorder(
            geometry=Border(coordinates=coords),
            properties=BorderProps(
                **{"trailsroc-parkID": f"park-{parkID}", "trailsroc-id": id}
            ),
        )
        features.append(obj)
    return features


def fill_props(obj) -> dict[str, Any]:
    data = {
        f"trailsroc-{k}": v
        for k, v in obj._asdict().items()
        if k != "Index"
        and k != "geometry"
        and k != "directions"
        and v is not None
        and not (isinstance(v, float) and np.isnan(v))
    }
    return data


def from_poi(pkg: gpd.GeoDataFrame, parkID: str) -> list[TrailsRocPoi]:
    features = []
    for p in pkg.itertuples():
        if p.type == "directions":
            continue
        data = fill_props(p)
        obj_hash = get_hash(p)
        data["trailsroc-type"] = PoiTypes[data["trailsroc-type"]]
        data["trailsroc-id"] = f'{data["trailsroc-type"]}:{parkID}:{obj_hash}'

        if p.directions:
            target = round_coord(pkg.loc[int(p.directions)].geometry)[0]
            data["trailsroc-directionsCoordinate"] = target
            data["trailsroc-allowsDirections"] = True

        coords = round_coord(p.geometry)[0]
        obj = TrailsRocPoi(
            geometry=POI(coordinates=coords), properties=PoiProps(**data)
        )
        features.append(obj)
    return features


def from_tracks(pkg: gpd.GeoDataFrame, parkID: str) -> list[TrailsRocTrail]:
    features = []
    for p in pkg.itertuples():
        data = fill_props(p)
        obj_hash = get_hash(p)
        name = (
            getattr(p, "name", getattr(p, "shortName", getattr(p, "color", "trail")))
            .lower()
            .replace(" ", "-")
        )
        data["trailsroc-trailIDs"] = f"trail-{parkID}-{name}"
        data["trailsroc-id"] = f'seg:{data["trailsroc-trailIDs"]}:{obj_hash}'
        data["trailsroc-surface"] = Surfaces[p.surface]
        data["trailsroc-color"] = Colors(p.color)

        coords = round_coord(p.geometry)
        obj = TrailsRocTrail(
            geometry=Trail(coordinates=coords), properties=TrailProps(**data)
        )
        features.append(obj)
    return features


def from_gpkg(pkg: Path, parkName: str) -> TrailsRocFeatures:
    layers = fiona.listlayers(pkg)
    features = []
    for name in layers:
        db = gpd.read_file(pkg, layer=name, engine="pyogrio", fid_as_index=True)
        if "park boundary" == name:
            features.extend(from_boundary(db, parkName.lower()))
        elif "poi" == name:
            features.extend(from_poi(db, parkName.lower()))
        elif "tracks" == name:
            features.extend(from_tracks(db, parkName.lower()))
    return TrailsRocFeatures(features=features)


features = from_gpkg(Path("../HermanRoadForeverForest.gpkg"), "Herman")
print(features.json(exclude_none=True))
# print(pkg)

# with open("features.geojson", "r") as fd:
#    v = TrailsRocFeatures.model_validate_json(fd.read())
#    pprint(v)
