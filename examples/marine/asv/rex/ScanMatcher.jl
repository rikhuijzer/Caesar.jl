"""
this script fetches sequential pairs of poses, fetches the big data (radar pings) tied to those poses, and then determines the pairwise factors that should be added between these sequential pairs
"""

using GraphPlot
using DistributedFactorGraphs
using IncrementalInference, RoME
using JSON2

using DocStringExtensions

##

# Where to fetch data
# dfgDataFolder = ENV["HOME"]*"/data/rex";
dfgDataFolder = "/tmp/caesar/rex"

# Load the graph
fg = loadDFG("$dfgDataFolder/dfg")

# add the datastore locations
ds = FolderStore{Vector{UInt8}}(:radar, "$dfgDataFolder/data/radar")
addBlobStore!(fg, ds)

ds = FolderStore{Vector{UInt8}}(:gps_fix, "$dfgDataFolder/data/gps")
addBlobStore!(fg, ds)

ds = FolderStore{Vector{UInt8}}(:lidar, "$dfgDataFolder/data/lidar")
addBlobStore!(fg, ds)

##

# fetch variables containing a full sweep
allSweepVariables = filter(v -> :RADARSWEEP in listDataEntries(v), getVariables(fg)) |> sortDFG

fsvars = allSweepVariables .|> getLabel

# helper function to retrieve the radar sweep for a given variable
function fetchSweep(dfg::AbstractDFG, varlabel::Symbol)

    entry,rawData = getData(dfg, varlabel, :RADARSWEEP)
    rawdata = Vector{Float64}(JSON2.read(IOBuffer(rawData)))
    n = Int(sqrt(length(rawdata)))
    sweep = reshape(rawdata,(n,n))
    return sweep # That's pretty sweep if i say so myself...
end

##

# fetch all radar pings
sweeps = fetchSweep.(fg, fsvars);
using Images, ImageView
# Filter the images
kg = Kernel.gaussian(7)
sweeps = map(s -> imfilter(s, kg), sweeps)
# Normalize
sweeps = map(s -> s/maximum(s), sweeps)

# Clamp out NaN's:
#map(clamp01nan, img)
#
# using ImageMagick
# for i in 5:length(sweeps)
#   s = sweeps[i]./maximum(sweeps[i])
#   save("/home/gearsad/SlamInDb/seagrant/$i.jpg", Gray.(s))
# end

# At this point we can load the sweeps; let's work on registration
# First step is to have a function that evaluates the cost of a given transform
# between two subsequent images.

##

import Rotations as _Rotations
using CoordinateTransformations
using ImageTransformations
using Manifolds



## Building the graph


include("RadarFactor.jl")

using LinearAlgebra
using Optim

##

startsweep = 5
endsweep = 6
graphinit = false

# newfg = initfg()
newfg = generateCanonicalFG_ZeroPose(varType=Pose2)
for i in 1:(endsweep-startsweep)
    addVariable!(newfg, Symbol("x$i"), Pose2, solvable=1)
end
for i in 1:(endsweep-startsweep)
    factor = AlignRadarPose2( sweeps[i+startsweep-1], sweeps[i+startsweep], 1, 0.1 )
    addFactor!(newfg, Symbol.(["x$(i-1)", "x$i"]), factor, graphinit=graphinit, solvable=1)
end

##



##


# Run the initialization (very slow right now)
# ensureAllInitialized!(newfg)

# Factor debugging
# fs = getFactorFunction.(getFactor.(newfg, lsf(newfg)))
# fs = filter(f -> f isa AlignRadarPose2, fs)
# pf = convert.(PackedAlignRadarPose3, fs)
# convert.(AlignRadarPose2, pf)

# Save the graph
saveDFG(newfg, "$dfgDataFolder/segment_test.tar.gz");

##

lsf(newfg)
# this should run the radar alignment
X1_ = approxConvBelief(newfg, :x0x1f1, :x1)
pts = getPoints(X1_)

# solving will internally call ensureAllInitialized!(newfg)
tree = solveTree!(newfg)

## Looking at the results
using Plots

ppes = map(v -> getSuggestedPPE(getPPE(getVariable(newfg, v))), ls(newfg))
x = map(ppe -> ppe[1], ppes); y = map(ppe -> ppe[2], ppes); h = map(ppe -> ppe[3], ppes)
Plots.plot(x, y, title="Path Plot", lw=3)


## Stuff
using Optim


cost(tf, im1, im2) = evaluateTransform(im1,im2, tf )


# Plotting
xrange = -100.0:1.0:100.0
hrange = -pi:0.1:pi
val = reshape(
    [sweepx(sweeps[10],sweeps[11],xrange); sweepx(sweep_original[10],sweep_original[11],xrange)],
    length(xrange), 2)
Plots.plot(xrange,val)
# Heading
val = reshape(
    [sweeph(sweeps[10],sweeps[11],hrange); sweeph(sweep_original[10],sweep_original[11],hrange)],
    length(hrange), 2)
Plots.plot(hrange,val)

corr_func = (a,b)->sqrt(sum((a .- 0.5).*(b .- 0.5)))
val = reshape(
    [sweepx(sweeps[10],sweeps[11],xrange,diff_func=corr_func);
    sweepx(sweep_original[10],sweep_original[11],xrange,diff_func=corr_func)],
    length(xrange), 2)
Plots.plot(xrange,val)

## Sweep plotting
# sanity check: identity transform should yield zero cost
# @assert evaluateTransform(sweeps[11],sweeps[11],0.,0.,0.) == 0 "There's error with no transform!"

# let's try small displacements:
# sweepx(im1, im2, xrange) = (x->@show evaluateTransform(im1,im2,x,0.,0.)).(xrange)
# sweepy(im1, im2, yrange) = (y->@show evaluateTransform(im1,im2,0.,y,0.)).(yrange)
# sweeph(im1, im2, hrange) = (h->@show evaluateTransform(im1,im2,0.,0.,h)).(hrange)


# using Plots
# xrange = -10:0.1:10
# hrange = -pi:0.1:pi
# Plots.plot(xrange,sweepx(sweeps[10],sweeps[11],xrange))
# Plots.plot(xrange,sweepy(sweeps[10],sweeps[11],xrange))
# Plots.plot(hrange,sweeph(sweeps[10],sweeps[11],hrange))


# fs10 = imfilter(sweeps[10],Kernel.gaussian(3))
# fs11 = imfilter(sweeps[11],Kernel.gaussian(3))
# ffs10 = imfilter(fs10,Kernel.gaussian(3))
# ffs11 = imfilter(fs11,Kernel.gaussian(3))
#
# Plots.plot(xrange,sweepx(ffs10,ffs11,xrange))
# Plots.plot(xrange,sweepy(fs10,fs11,xrange))
