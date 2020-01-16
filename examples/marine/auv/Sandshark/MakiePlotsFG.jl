# plot factor graph using Makie for belief space representation

using Distributed

using Caesar, RoME, DistributedFactorGraphs
@everywhere using Caesar, RoME, DistributedFactorGraphs
@everywhere using KernelDensityEstimate
@everywhere using ProgressMeter

@everywhere import RoME: Point2, Point3
using Makie
using DocStringExtensions

import DistributedFactorGraphs: getEstimates

"""
    $SIGNATURES

Get the cartesian range over which the factor graph variables span.

Notes:
- Optional `regexFilter` can be used to subselect, according to label, which variable IDs to use.

DevNotes
- TODO, allow `tags` as filter too.
"""
function getRangeCartesian(dfg::AbstractDFG,
                           regexFilter::Union{Nothing, Regex}=nothing;
                           extend::Float64=0.2,
                           digits::Int=6  )
  #
  # which variables to consider
  vsyms = getVariableIds(dfg, regexFilter)

  # find the cartesian range over all the vsyms variables
  xmin = 99999999
  xmax = -99999999
  ymin = 99999999
  ymax = -99999999
  for vsym in vsyms
    lran = getKDERange(getVariable(dfg, vsym) |> getKDE)
    xmin = lran[1,1] < xmin ? lran[1,1] : xmin
    ymin = lran[2,1] < ymin ? lran[2,1] : ymin
    xmax = xmax < lran[1,2] ? lran[1,2] : xmax
    ymax = ymax < lran[2,2] ? lran[2,2] : ymax
  end

  # extend the range for looser bounds on plot
  xra = xmax-xmin; xra *= extend
  yra = ymax-ymin; yra *= extend
  xmin -= extend; xmax += extend
  ymin -= extend; ymax += extend

  # clamp to nearest integers
  xmin = floor(xmin, digits=digits); xmax = ceil(xmax, digits=digits)
  ymin = floor(ymin, digits=digits); ymax = ceil(ymax, digits=digits)

  return [xmin xmax; ymin ymax]
end


"""
    $SIGNATURES

2D plot of variable marginal belief estimates.

Notes:
- Uses `Makie.contour` as backend
- Disable with `fadeFloor=0`, must be ∈ [0,1].

DevNotes
- TODO, allow `tags` as filter too.

Example
-------
```julia
fg = loadCanonicalFG_Hexagonal()
pl = plotVariableBeliefs(fg, r"x\\d") # using optional Regex filter
```

Related

getRangeCartesian,
"""
function plotVariableBeliefs(dfg::AbstractDFG,
                             regexFilter::Union{Nothing, Regex}=nothing;
                             N::Int=500,
                             minColorBase::Float64=-0.3,
                             sortVars::Bool=false,
                             varStride::Int=1,
                             fade::Int=0,
                             fadeFloor::Real=0.3,
                             # fadeClamp::Bool=true,
                             tail::Int=-1,
                             digits::Int=-1,
                             extend::Real=0.2  )
  #
  dfgran = getRangeCartesian(dfg, regexFilter, digits=digits, extend=extend)

  x = LinRange(dfgran[1,1], dfgran[1,2], N)
  y = LinRange(dfgran[2,1], dfgran[2,2], N)
  Z = zeros(N,N)
  zz = zeros(N,N)
  xy = zeros(Threads.nthreads(), 2,N)
  for i in 1:Threads.nthreads()
    xy[i,2,:] .= y
  end

  # get the variables for plotting, while applying available filters
  vsyms = getVariableIds(dfg, regexFilter)
  # specialty feature
  sortVars ? (vsyms .= vsyms |> sortDFG) : nothing
  sortVars && varStride != 1 ? (vsyms = vsyms[1:varStride:end]) : nothing
  sortVars && 0 < tail ? (vsyms = vsyms[end-tail:end]) : nothing
  !sortVars && varStride != 1 ? @warn("set sortVars=true to use varStride") : nothing
  !sortVars && 0 < fade ? @warn("set sortVars=true to use fade > 0") : nothing
  # walk through all variables and plotting accordingly
  len = length(vsyms)
  count = 0
  @showprogress "Evaluating symbols" for vsym in vsyms
    count += 1
    XY = marginal(getVariable(dfg, vsym) |> getKDE, [1;2])
    Threads.@threads for i in 1:N
      xy[Threads.threadid(), 1,:] .= x[i]
      zz[i,:] = XY(xy[Threads.threadid(), :,:])
    end
    # normalize all beliefs to same scope
    zz ./= maximum(zz)
    # do the requested fading
    zz .*= maximum( [(fade-(len-count))/fade; 0.0]) * (1-fadeFloor) + fadeFloor

    # Accumulate and clamp max value of accumulated beliefs
    Z .+= zz
    if count < len-fade && 0 < fadeFloor
      # i.e. count still in fade tail, must now do fade clamping
      Z[Z .> fadeFloor] .= fadeFloor
    else
      Z[Z .> 1] .= 1
    end
    # fade == -1 ? (Z .*= count/len) : nothing # alternatively
  end

  # set the base "background" color level by dropping one element to the desired minimum
  Z[1,1] += minColorBase

  # finally use Makie to draw the figure
  Makie.contour(x, y, Z, levels = 0, linewidth = 0, fillrange = true)
end





# fg = loadCanonicalFG_Hexagonal()
# pl = plotVariableBeliefs(fg, r"x\d") # using optional Regex filter
# pl = plotVariableBeliefs(fg, r"x\d", sortVars=true, fade=3) # using optional Regex filter
# pl = plotVariableBeliefs(fg, r"x\d", sortVars=true, fade=2, tail=4) # using optional Regex filter



0

# targetResultsDir = "2020-01-08T17:57:25.612"
# targetResultsDir = "2020-01-15T18:30:40.98"
# fg = LightDFG{SolverParams}(params=SolverParams())
# loadDFG("/tmp/caesar/$targetResultsDir/fg_final.tar.gz", Main, fg)
# getSolverParams(fg).logpath = "/tmp/caesar/$targetResultsDir"
# dontMarginalizeVariablesAll!(fg)

# scene = plotVariableBeliefs(fg, r"x\d", sortVars=true, varStride=2, fade=20, digits=-2, fadeFloor=0.1)

# mask = YYf .< -32
# drt_data = readdlm(joinLogPath(fg, "DRT.csv"), ',')
# ... from GenerateResults.jl
# XXfm = XXf[mask]; YYfm = YYf[mask];
# lines!(scene, XXfm, YYfm, color=:red)

# xyt = getPPESuggestedAll(fg2, r"x\d")
# lines!(scene, xyt[2][:,1], xyt[2][:,2], color=:black)




# N = 20
# x = LinRange(-0.3, 1, N)
# y = LinRange(-1, 0.5, N)
# z = x .* y'
# hbox(
#    vbox(
#        contour(x, y, z, levels = 20, linewidth =3),
#        contour(x, y, z, levels = 0, linewidth = 0, fillrange = true),
#        heatmap(x, y, z),
#    ),
#    vbox(
#        image(x, y, z, colormap = :viridis),
#        surface(x, y, fill(0f0, N, N), color = z, shading = false),
#        image(-0.3..1, -1..0.5, AbstractPlotting.logo())
#    )
# )
