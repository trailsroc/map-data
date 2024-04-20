from typing import Literal, Optional, Union
from pydantic import BaseModel, AnyHttpUrl, conlist, Extra
from geojson_pydantic import FeatureCollection, Polygon, Point, LineString, Feature
import enum

# Stuff to handle the hyphens :(
# And forbid extra fields


def hyphenize(field: str):
    return field.replace("_", "-")


class Hyphenator(BaseModel):
    class Config:
        alias_generator = hyphenize
        extra = Extra.forbid


# Now the real stuff


class Colors(enum.StrEnum):
    Black = enum.auto()
    Blue = enum.auto()
    Brown = enum.auto()
    Dark_Green = enum.auto()
    Grass = enum.auto()
    Green = enum.auto()
    Orange = enum.auto()
    Pink = enum.auto()
    Purple = enum.auto()
    Red = enum.auto()
    Sky = enum.auto()
    Teal = enum.auto()
    Unmarked_Trail = enum.auto()
    White = enum.auto()
    Yellow = enum.auto()


class Blazes(enum.StrEnum):
    Unpainted = "none"
    Color = enum.auto()


class Styles(enum.StrEnum):
    minorPark = "minorPark"
    trailSystem = "trailSystem"


class Surfaces(enum.StrEnum):
    gravel = enum.auto()
    paved = enum.auto()
    road = enum.auto()
    singletrack = enum.auto()


class PoiTypes(enum.StrEnum):
    admin = "point-admin"
    boatLaunch = "point-boatLaunch"
    campsite = "point-campsite"
    intersection = "point-intersection"
    lodge = "point-lodge"
    parking = "point-parking"
    poi = "point-poi"
    restroom = "point-restroom"
    scenic = "point-scenic"
    shelter = "point-shelter"
    smparking = "point-smparking"
    sports = "point-sports"
    park = "park"
    trail = "trail"
    trailSystem = "trailSystem"


class BorderProps(Hyphenator):
    trailsroc_type: Literal["parkBorder"] = "parkBorder"
    trailsroc_id: str
    trailsroc_parkID: str
    trailsroc_style: Optional[Styles] = None


class TrailProps(Hyphenator):
    trailsroc_type: Literal["trailSegment"] = "trailSegment"
    trailsroc_id: str
    trailsroc_style: Optional[Styles] = None
    trailsroc_trailIDs: str
    trailsroc_name: Optional[str] = None
    trailsroc_shortName: Optional[str] = None
    trailsroc_surface: Surfaces
    # Middle trail color
    trailsroc_color: Colors
    # Left trail color
    trailsroc_color2: Optional[Colors] = None
    # Right trail color
    trailsroc_color3: Optional[Colors] = None
    # Added by Jeff
    trailsroc_length: Optional[float] = None


class PoiProps(Hyphenator):
    trailsroc_type: PoiTypes
    trailsroc_allowsDirections: Optional[bool] = None
    trailsroc_blazes: Optional[Blazes] = None
    trailsroc_color: Optional[Colors] = None
    trailsroc_directionsCoordinate: Optional[
        conlist(float, min_length=2, max_length=2)
    ] = None
    trailsroc_id: str
    trailsroc_isPrimary: Optional[bool] = None
    trailsroc_isSearchable: Optional[bool] = None
    trailsroc_keywords: Optional[str] = None
    trailsroc_name: Optional[str] = None
    trailsroc_parentID: Optional[str] = None
    trailsroc_parentIDs: Optional[str] = None
    trailsroc_shortName: Optional[str] = None
    trailsroc_style: Optional[Styles] = None
    # This should be a URL, but cobbs has invalid URLs
    trailsroc_url: Optional[AnyHttpUrl] = None


class Border(Polygon):
    type: Literal["Polygon"] = "Polygon"


class Trail(LineString):
    type: Literal["LineString"] = "LineString"


class POI(Point):
    type: Literal["Point"] = "Point"


class TrailsRocBorder(Feature[Border, BorderProps]):
    type: Literal["Feature"] = "Feature"


class TrailsRocTrail(Feature[Trail, TrailProps]):
    type: Literal["Feature"] = "Feature"


class TrailsRocPoi(Feature[POI, PoiProps]):
    type: Literal["Feature"] = "Feature"


class TrailsRocFeatures(
    FeatureCollection[Union[TrailsRocBorder, TrailsRocTrail, TrailsRocPoi]]
):
    type: Literal["FeatureCollection"] = "FeatureCollection"
