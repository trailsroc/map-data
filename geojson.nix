{python3Packages}:
python3Packages.buildPythonPackage rec {
  pname = "geojson_pydantic";
  version = "1.0.2";
  pyproject = true;
  src = python3Packages.fetchPypi {
    inherit pname version;
    sha256 = "sha256-MXnWZa2HY2cGgbc63tIijfIKEWSVHp1wdb6PNw62gfQ=";
  };
  buildInputs = [
    python3Packages.flit
    python3Packages.pydantic
  ];
}
