from setuptools import find_packages, setup
from dbx_metrics_examples import __version__

INSTALL_REQUIRES = ["faker"]

setup(
    name="dbx_metrics_examples",
    packages=find_packages(exclude=["tests", "tests.*"]),
    setup_requires=["wheel"],
    version=__version__,
    description="Databricks metrics examples",
    author="Ivan Trusov",
    install_requires=INSTALL_REQUIRES,
)
