#!/usr/bin/env python3
# fileUtils.py
# MusicBox: Utility functions for managing collections of NetCDF files.
#
# Author: Carl Drews
# Copyright 2026 by Atmospheric Chemistry Observations & Modeling (UCAR/ACOM)

import sys
import pathlib
import xarray
import datetime

import logging
logger = logging.getLogger(__name__)


# A file (probably NetCDF) containing output from an atmospheric model.
class Model_File:
    hourStride = 1                   # default time step for model output
    modelType = "Generic model"      # for diagnosing errors of wrong model type

    def __init__(self, myPath):
        self.filePath = myPath       # full directory, name, and file extension
        self.dateTimes = []          # date-time steps contained in the file

    # show the fields of this object
    def display(self):
        friendlyDates = [f"{dt}" for dt in self.dateTimes]
        logger.info(f"\t{self.filePath}:\n\t\t{friendlyDates}")

    # gather the date-time values contained in this file
    # The file is open and known to be NetCDF file.
    # fileDataSet = xarray dataset
    # dateTimes[] should be loaded
    def inventoryDateTimes(self, fileDataset):
        logger.debug(f"inventoryDateTimes for {self}")


# WACCM output file
class WACCM_File(Model_File):
    hourStride = 6       # WACCM global output is typically every 6 hours
    modelType = "WACCM"

    def __init__(self, myPath="blank-WACCM.txt"):
        super().__init__(myPath)
        logger.debug(f"WACCM file type: {myPath}")

    # WACCM: date = 20260208, 20260208, 20260208, 20260208 ; int
    #        datesec = 0, 21600, 43200, 64800 ;              int
    def inventoryDateTimes(self, fileDataset):
        super().inventoryDateTimes(fileDataset)
        for date, datesec in zip(fileDataset["date"].data, fileDataset["datesec"].data):
            logger.debug(f"date = {date}   datesec = {datesec}")
            dateStr = str(date)
            stepDate = (datetime.datetime.strptime(dateStr, "%Y%m%d")
                        + datetime.timedelta(seconds=int(datesec)))
            self.dateTimes.append(stepDate)


class WRF_Chem_File(Model_File):
    modelType = "WRF-Chem"

    def __init__(self, myPath="blank-WRF-Chem.txt"):
        super().__init__(myPath)
        logger.debug(f"WRF-Chem file type: {myPath}")

    # WRF-Chem:   Times = "2025-08-20_08:00:00";                  char
    def inventoryDateTimes(self, fileDataset):
        super().inventoryDateTimes(fileDataset)
        timesVar = fileDataset["Times"].data
        timesVarStrings = [tv.decode("utf-8") for tv in timesVar]
        for timeStr in timesVarStrings:
            logger.debug(f"timeStr = {timeStr}")
            stepDate = datetime.datetime.strptime(timeStr, "%Y-%m-%d_%H:%M:%S")
            self.dateTimes.append(stepDate)


# Scan a directory and create a list of NetCDF files.
# Each file represents several time steps of model output.
# Those times are collected with the filename.
# Note: The NetCDF files currently produced by the ACOM near-real-time
# forecast system do not have any extension:
#     wrfout_hourly_d02_2025-08-21_08:00:00
# That is why we don't glob() on *.nc as of May 18, 2026.
# We can tolerate README.txt files in the same directory.
# modelDir = scan this directory
# modelClass = class of model (WACCM or WRF-Chem) expected in this directory
# return list of populated modelClass objects
def collectFilesDates(modelDir, modelClass):
    # retrieve filenames
    dirFiles = [f for f in pathlib.Path(modelDir).iterdir() if f.is_file()]
    logger.debug(f"dirFiles = {dirFiles}")

    # create Model_File objects for each filename
    # This first list might not be all NetCDF files.
    maybeFiles = []
    for dirFile in dirFiles:
        myModelFile = modelClass(dirFile)
        maybeFiles.append(myModelFile)

    # extract the date and time
    # This second list of files are known to be NetCDF.
    modelFiles = []
    for maybeFile in maybeFiles:
        try:
            # attempt to open the file as NetCDF
            filename = maybeFile.filePath
            with xarray.open_dataset(filename) as dataSet:
                logger.debug(f"Opened {filename}")
            modelFiles.append(maybeFile)

            # gather all the date-times in the file
            maybeFile.inventoryDateTimes(dataSet)

        except ValueError as oops:
            logger.warning(f"Cannot open {filename} because it is not a NetCDF file.")
            logger.debug(f"Cannot open {filename} because {oops}.")

        except KeyError as oops:
            logger.warning(f"Cannot find expected date-time in {filename} as {modelClass.modelType} model output."
                           + " Wrong model specified?")
            logger.debug(f"Cannot get date-time for {filename} because {oops}.")

    # pass back just the NetCDF files
    return modelFiles


# Sort list of model files in place, by first date-time contained.
def sortFiles(myModelList):
    myModelList.sort(key=lambda modelFile: modelFile.dateTimes[0])


# Expand the original Model_File collection:
#    File2:  time1, time2, time3, time4
# strictly into pairs:
#    File2:  time1
#    File2:  time2
#    File2:  time3
#    File2:  time4
# This separation makes the extraction loop easier
# and permits interleaving of model output frames.
# Return the separated pairs as Model_Files objects.
def collectionToPairs(myFiles):
    pairCollection = []

    for compositeFile in myFiles:
        for myTime in compositeFile.dateTimes:
            pairFile = Model_File(compositeFile.filePath)
            pairFile.dateTimes = [myTime]
            pairCollection.append(pairFile)

    # sort the file objects by date-time
    sortFiles(pairCollection)
    return pairCollection


dateTimeTolerance = datetime.timedelta(minutes=5)

# Locate and return the closest model file to the requested date-time.
# "Nearest" currently is the first file within the tolerance above.
# myDateTime = seeking this model step
# myModelFiles = list of Model_File objects, sorted by date-time


def findNearestDateTime(myDateTime, myModelFiles):

    for modelFile in myModelFiles:
        timeDifference = abs(myDateTime - modelFile.dateTimes[0])
        if (timeDifference < dateTimeTolerance):
            return modelFile.filePath

    return None
