#!/bin/bash

# Copyright (C) 2009-2013 Ed Bueler and Andy Aschwanden

# submits scripts produced by paramspawn.sh; uses QSUB environment variable if set
# "qsub" is from PBS job scheduler
# (see  http://www.adaptivecomputing.com/products/open-source/torque/)
#
# usage for real, using qsub:
#   $ ./paramsubmit.sh
#
# usage for test:
#   $ PISM_QSUB=cat ./paramsubmit.sh

set -e -x # exit on error

SCRIPTNAME=paramsubmit.sh

CLIMLIST="{const, pdd}"
TYPELIST="{ctrl, 970mW_hs}"
GRIDLIST="{10,5}"
if [ $# -lt 5 ] ; then
  echo "paramsubmit.sh ERROR: needs 3 positional arguments ... ENDING NOW"
  echo
  echo "usage:"
  echo
  echo "    paramsubmit.sh GRID CLIMATE TYPE"
  echo
  echo "  where:"
  echo "    GRID        in $GRIDLIST (km)"
  echo "    CLIMATE     in $CLIMLIST"
  echo "    TYPE        in $TYPELIST"
  echo
  echo
  exit
fi

# submission command
if [ -n "${PISM_QSUB:+1}" ] ; then  # check if env var PREFIX is already set
    QSUB=$PISM_QSUB
    echo "($SCRIPTNAME) QSUB = $PISM_QSUB"
else
    QSUB="qsub"
    echo "($SCRIPTNAME) QSUB = $QSUB"
fi

for SCRIPT in do_${GRID}km_$CLIMATE}_${TYPE}_*.sh
do
  echo "($SCRIPTNAME) doing '$QSUB $SCRIPT' ..."
  $QSUB $SCRIPT
done
