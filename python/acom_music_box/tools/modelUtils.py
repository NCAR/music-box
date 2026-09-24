#!/usr/bin/env python3
# modelUtils.py
# MusicBox: Utility functions for managing different atmospheric models.
#
# Author: Carl Drews
# Copyright 2026 by Atmospheric Chemistry Observations & Modeling (UCAR/ACOM)

import sys
import pathlib
import xarray
import datetime
from acom_music_box.tools import fileUtils

import logging
logger = logging.getLogger(__name__)


# The base class for all atmospheric models.
class Base_Model:
    modelType = fileUtils.Model_File.modelType        # for diagnosing errors of wrong model type

    def __init__(self):
        return

    # show the fields of this object
    def display(self):
        logger.debug(f"modelType is {self.modelType}")

    # return set of native component vars used to calculate the varName
    def getDerivedComponents(self, varName):
        logger.debug(f"getDerivedComponents for {self}")
        return set()

    # Calculated derived variable from component native species.
    # columnVars = xarray.Dataset; multiple variable horizontal means
    #       at a single lat-lon point, at many vertical levels
    # varToDerive = name of the non-native chemical to calculate
    # return tuple of (waccmVarName, units, [verticalMean])
    def calcDerivedVar(self, columnVars, varToDerive):
        return (None, None, [None])


# WACCM model
class WACCM_Model(Base_Model):
    modelType = fileUtils.WACCM_File.modelType

    def __init__(self):
        super().__init__()
        logger.debug(f"WACCM model type: {self.modelType}")

    def getDerivedComponents(self, varName):
        components = super().getDerivedComponents(varName)
        if (varName.lower() == "pressure"):
            components.add("P0")
            components.add("PS")
            components.add("hyam")
            components.add("hybm")

        return components

    # Calculated derived variable from component native species.
    # columnVars = xarray.Dataset; multiple variable horizontal means
    #       at a single lat-lon point, at many vertical levels
    # varToDerive = name of the non-native chemical to calculate
    # return tuple of (waccmVarName, units, [verticalMean])
    def calcDerivedVar(self, columnVars, varToDerive):
        logger.debug(f"columnVars = {columnVars}   varToDerive = {varToDerive}")

        # set up default error values in case variable name not known
        units = "None"
        verticalMean = 0.0
        foundVariable = False

        varNameOnly = varToDerive.replace("derived", "").replace(" ", "")

        if not foundVariable:
            logger.warning(f"Requested variable name {varNameOnly} not found in calcDerivedVar().")

        return (varToDerive, units, [verticalMean])


class WRF_Chem_Model(Base_Model):
    modelType = fileUtils.WRF_Chem_File.modelType

    def __init__(self):
        super().__init__()
        logger.debug(f"WRF-Chem model type: {self.modelType}")

    def getDerivedComponents(self, varName):
        components = super().getDerivedComponents(varName)
        if (varName.lower() == "temperature"):
            components.add("T")     # perturbation potential temperature theta-t0, units K
            components.add("P")     # perturbation pressure, units Pa
            components.add("PB")    # base state pressure, units Pa

        if (varName.lower() == "pressure"):
            components.add("P")
            components.add("PB")

        return components

    # Calculated derived variable from component native species.
    # columnVars = xarray.Dataset; multiple variable horizontal means
    #       at a single lat-lon point, at many vertical levels
    # varToDerive = name of the non-native chemical to calculate
    # return tuple of (waccmVarName, units, [verticalMean])
    def calcDerivedVar(self, columnVars, varToDerive):
        logger.debug(f"columnVars = {columnVars}   varToDerive = {varToDerive}")

        # set up default error values in case variable name not known
        units = "None"
        verticalMean = 0.0
        foundVariable = False

        varNameOnly = varToDerive.replace("derived", "").replace(" ", "")
        if (varNameOnly.lower() == "pressure"):
            pSinglePoint = columnVars["P"]      # WRF-Chem: perturbation pressure (Pa)
            pbSinglePoint = columnVars["PB"]    # WRF-Chem: base state pressure (Pa)

            pressureSinglePoint = pSinglePoint + pbSinglePoint  # actual atmospheric pressure (Pa)
            units = pSinglePoint.units      # should be Pa
            verticalMean = float(pressureSinglePoint.values.mean())
            foundVariable = True

        if (varNameOnly.lower() == "temperature"):
            tSinglePoint = columnVars["T"]      # WRF-Chem: perturbation potential temperature theta-t0
            pSinglePoint = columnVars["P"]      # WRF-Chem: perturbation pressure (Pa)
            pbSinglePoint = columnVars["PB"]    # WRF-Chem: base state pressure (Pa)

            theta0 = 300.0  # WRF baseline constant potential temperature (K)
            tSinglePoint += theta0  # actual potential temperature (K)

            P1000MB = 100000.0      # sea level pressure in Pascals
            RD = 287.0              # specific gas constant R for dry air J/(kg K)
            CP = 1004.50            # heat capacity of dry air J/(kg K) at constant pressure

            # Perform the numeric calculation; convert potential temperature to actual temperature.
            # see fortran/wrf_user.f90 SUBROUTINE DCOMPUTETK(tk, pressure, theta, nx)
            pressureSinglePoint = pSinglePoint + pbSinglePoint  # actual atmospheric pressure (Pa)
            temperatureSinglePoint = ((pressureSinglePoint / P1000MB) ** (RD / CP)) * tSinglePoint

            units = tSinglePoint.units  # should be K
            verticalMean = float(temperatureSinglePoint.values.mean())
            foundVariable = True

        if not foundVariable:
            logger.warning(f"Requested variable name {varNameOnly} not found in calcDerivedVar().")

        return (varToDerive, units, [verticalMean])


# Create a Model object based on the type of NetCDF file.
def factory(myFileClass):
    if (myFileClass == fileUtils.WACCM_File):
        return WACCM_Model()
    if (myFileClass == fileUtils.WRF_Chem_File):
        return WRF_Chem_Model()

    return Base_Model()

