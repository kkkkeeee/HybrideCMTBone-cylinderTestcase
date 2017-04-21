#!/bin/bash
#PBS -l nodes=2
#PBS -l walltime=01:00:00
#PBS -A CSC188
cd /lustre/atlas/scratch/kekezhai/csc188/cylinderTestHybrid/lb/3dbox-4096-512000
rm box.sch
sleep 5


aprun -n 32 -N 16 ./nek5000 > outputscript.txt-n2-71-0.4-delta2

