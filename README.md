green-hydro
===========

Scripts to probe the parameter space of a coupled ice dynamics / basal hydrology model for Greenland. All content is highly experimental.

The scripts in run/ mark a major change in input data and modeling domain choice. We have switched to the mass conservative bed provided by Mathieu Morlighem which is in NSIDC north polar stereographic project (EPSG:3413). As bed elevation and ice thickness is our main input data, all other foring is reprojected onto EPSG:3413. Consequencently, comparison with older simulations will be non-straightforward. To facilitate comparison, however, Bamber's 2013 will be reprojected at some point in the near future (Bamber 2001 is already part of the preprocessing script).

NOTE: MCBs are not yet publicly available. You need to have an account on beauregard to get access. Run:

$ ./process.sh
