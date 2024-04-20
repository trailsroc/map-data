{python3Packages}:
python3Packages.buildPythonPackage rec {
  pname = "pyogrio";
  version = "0.7.2";
  format = "wheel";
  src = builtins.fetchurl {
    url = "https://files.pythonhosted.org/packages/cp311/p/pyogrio/pyogrio-0.7.2-cp311-cp311-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
    sha256 = "sha256:1al64jgyhc81cpg0jvr720bj0m4qdq68ayw0cc9837gspz8kccd2";
  };
  buildInputs = [
    python3Packages.setuptools
    python3Packages.versioneer
    python3Packages.cython
    python3Packages.tomli
    python3Packages.numpy
  ];
}
