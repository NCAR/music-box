# WACCM

This is data downloaded from [ACOM's data repository](https://www.acom.ucar.edu/waccm/DATA/). Each file has been reduced to have only ground level data and only chemical species needed for the IGAC demo. 
This brings the file size from 8GB per file to 93MB per file, small enough that it can fit in github and be easily used for the demo. This data is temporary and will be removed after the demo. 


The script to reduce the data is this:


```
import xarray as xr
import os

keep = ['ALKNIT', 'AODVISdn', 'BCARY', 'BENZENE', 'BIGALD', 'BIGALD1', 'BIGALD2', 'BIGALD3', 'BIGALD4', 'BIGALK', 'BIGENE', 'C2H2', 'C2H4', 'C2H5OH', 'C2H6', 'C3H6', 'C3H8', 'CH2O', 'CH3CHO', 'CH3CN', 'CH3COCH3', 'CH3COCHO', 'CH3COOH', 'CH3OH', 'CH3OOH', 'CH4', 'CHBR3', 'CO', 'CO01', 'CO02', 'CO03', 'CO04', 'CO05', 'CO06', 'CO07', 'CO08', 'CO09', 'CRESOL', 'DMS', 'GLYOXAL', 'H2O', 'H2O2', 'HCN', 'HCOOH', 'HNO3', 'HO2', 'HO2NO2', 'HONITR', 'HYAC', 'ISOP', 'ISOPNITA', 'ISOPNITB', 'MACR', 'MEK', 'MPAN', 'MTERP', 'MVK', 'M_dens', 'N2O', 'N2O5', 'NH3', 'NH4', 'NO', 'NO2', 'NO3', 'NOA', 'O3', 'O3S', 'OH', 'ONITR', 'P0', 'PAN', 'PBZNIT', 'PHENOL', 'PS', 'Q', 'SO2', 'T', 'TERPNIT', 'TOLUENE', 'XYLENES', 'Z3', 'ap', 'bc_a1', 'bc_a4', 'ch4vmr', 'co2vmr', 'date', 'dst_a1', 'dst_a2', 'dst_a3', 'f107', 'f107a', 'f107p', 'f11vmr', 'f12vmr', 'kp', 'mdt', 'n2ovmr', 'ncl_a1', 'ncl_a2', 'ncl_a3', 'num_a1', 'num_a2', 'num_a3', 'pom_a1', 'pom_a4', 'so4_a1', 'so4_a2', 'so4_a3', 'soa1_a1', 'soa1_a2', 'soa2_a1', 'soa2_a2', 'soa3_a1', 'soa3_a2', 'soa4_a1', 'soa4_a2', 'soa5_a1', 'soa5_a2', 'soa_a1', 'soa_a2', 'sol_tsi',]

for root, _, files in os.walk('data'):
    for file in files:
        file_path = os.path.join(root, file)
        ds = xr.open_dataset(file_path)
        # Select the second time index and nearest lev, expand both dimensions
        ds_sel = ds[keep].isel(time=1).sel(lev=1000.0, method="nearest").expand_dims(['lev', 'time'])
        ds_sel.to_netcdf(f'sample_waccm_data/{file}')
```

You can extract a configuration file with 

```
waccmToMusicBox waccmDir="./sample_waccm_data" date="20240904" time="07:00" latitude=3.1 longitude=101.7
```
