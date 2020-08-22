# common car camera tools

using LinearAlgebra
using DataStructures
using RoME, DistributedFactorGraphs

## clear old memory

# delete!(vis[:tags])
# delete!(vis[:poses])

##

abstract type SynchronizingBuffer end

struct SynchronizeCarMono <: SynchronizingBuffer
  syncList::Vector{Symbol}
  # sequence #, time nanoseconds, data
  leftFwdCam::CircularBuffer{Tuple{Int, Int64, Any}}
  rightFwdCam::CircularBuffer{Tuple{Int, Int64, Any}}
  camOdo::CircularBuffer{Tuple{Int, Int64, Any}}
  cmdVal::CircularBuffer{Tuple{Int, Int64, Any}}
end

SynchronizeCarMono(len::Int=30;
                   syncList::Vector=Symbol[],
                   leftFwdCam=CircularBuffer{Tuple{Int, Int, Any}}(len),
                   rightFwdCam=CircularBuffer{Tuple{Int, Int, Any}}(len),
                   camOdo=CircularBuffer{Tuple{Int, Int, Any}}(len),
                   cmdVal=CircularBuffer{Tuple{Int, Int, Any}}(len) ) = SynchronizeCarMono(syncList,leftFwdCam,rightFwdCam,camOdo,cmdVal)
#

struct RacecarTools
  tagDetector
end

struct RacecarVisualizations
  gui
  vis
end

struct FrontEndContainer{M,T,A}
  slam::SLAMWrapperLocal
  middleware::M
  synchronizer::T
  tools::A
  datastore
end

FrontEndContainer(s::SLAMWrapperLocal,m::M,t::T,a::A,d) where {M, T, A} = FrontEndContainer{M,T,A}(s,m,t,a,d)

## data management functions

# function getSyncLatestPair(syncHdlrs::Dict; weirdOffset::Dict=Dict())::Tuple
function findSyncLatestIdx(syncz::SynchronizingBuffer;
                           weirdOffset::Dict=Dict(),
                           syncList::Vector{Symbol}=syncz.syncList)
  # get all sequence numbers
  len = length(syncList)
  if len == 1
    # simply return the newest element in the buffer
    sy = getfield(syncz, syncList[1])
    return length(sy)
  elseif len == 0
    @warn "findSyncLatestIdx has nothing to synchronize -- on account of .syncList being empty."
    return 0  # error
  end
  LEN = Vector{Int}(undef, len)
  for idx in 1:len
    LEN[idx] = getfield(syncz, syncList[idx]) |> length
    if LEN[idx] == 0
      return (NTuple{len, Int}(zeros(len)))
    end
  end

  SEQ = Vector{Vector{Int}}(undef, len)
  for idx in 1:len
    SEQ[idx] = (x->getfield(syncz, syncList[idx])[x][1]).(1:LEN[idx])
    if haskey(weirdOffset, syncList[idx])
      SEQ[idx] .+= weirdOffset[syncList[idx]]
    end
  end

  # find greatest common number
  seqLR = intersect(SEQ...)
  if 0 == length(seqLR)
    return NTuple{len,Int}(zeros(len))
  end
  seq = maximum(seqLR)
  # IDX = Vector{Int}(undef, len)

  return NTuple{len, Int}( (y->findfirst(x->x==seq, y)).(SEQ) )
end





function jsonResultsSLAM2D(dfg::AbstractDFG)
  allDicts = []
  allvars = ls(dfg, r"x\d") |> sortDFG

  for vidx in 1:(length(allvars)-1)
    ps = allvars[vidx]
    ns = allvars[vidx+1]
    if 0 == getPPEDict(getVariable(dfg, ns)) |> length || 0 == getPPEDict(getVariable(dfg, ps)) |> length
      continue
    end
    @show "fetchDataElement for $ps"
    if !hasDataEntry(getVariable(dfg,ps), :JOYSTICK_CMD_VALS)
      @error "missing data entry :JOYSTICK_CMD_VALS in $ps of length(allvars)=$(length(allvars))"
      continue
    end
    cmdData = fetchDataElement(dfg, ps, :JOYSTICK_CMD_VALS)
    # axis: 2:throttle, 4:steering
    cd = Dict{Symbol,Any}(
      :posei => ps,
      :posej => ns,
      :axis_time => (x->x[2]).(cmdData),
      :axis_throttle => (x->x[3].axis[2]).(cmdData),
      :axis_steer => (x->x[3].axis[4]).(cmdData),
      :world_posei => getPPE(dfg,ps).suggested,
      :world_posej => getPPE(dfg,ns).suggested,
      :ti => getTimestamp(getVariable(dfg, ps)),
      :tj => getTimestamp(getVariable(dfg, ns)),
    )
    DT = (cd[:tj]-cd[:ti]).value*1e-3
    cd[:deltaT] = DT
    deltax = (cd[:world_posej][1] - cd[:world_posei][1])
    deltay = (cd[:world_posej][2] - cd[:world_posei][2])
    velx = deltax./DT
    vely = deltay./DT
    wVelx = isnan(velx) ? 0.0 : velx
    wVely = isnan(vely) ? 0.0 : vely
    # rotate velocity from world to body frame
    cd[:bodyi_delta_pose] = se2vee(SE2(cd[:world_posei])\SE2(cd[:world_posej]))
    biRw = TU.R(-cd[:world_posei][3])
    bVel = biRw*[wVelx;wVely]
    velx = bVel[1]
    vely = bVel[2]
    if vidx in [1;2]
      velx = 0.0
      vely = 0.0
    end
    cd[:body_veli] = [velx;vely]
    push!(allDicts, cd)
  end
  return allDicts
end


# # moved into Caesar
# # load image (png, jpg, jpeg) from supported a data blob store 
# function fetchDataImage(dfg::AbstractDFG,
#                         varLbl::Symbol,
#                         dataLbl::Symbol,
#                         getDataLambda::Function = (g,vl,dl) -> getData(g,vl,dl),
#                         checkMimeType::Bool=true )
#   #
#   imgEntry, imgBytes = getDataLambda(dfg, varLbl, dataLbl)
#   checkMimeType && (@assert imgEntry.mimeType in ["image/png"; "image/jpg"; "image/jpeg"] "Unknown image format DataBlobEntry.mimeType=$(imgEntry.mimeType)")
#   ImageMagick.readblob(imgBytes)
# end
# fetchDataImage(dfg::AbstractDFG,datastore::AbstractBlobStore,varLbl::Symbol,dataLbl::Symbol,checkMimeType::Bool=true) = fetchDataImage(dfg, varLbl, dataLbl, (g,vl,dl) -> getData(g,datastore,vl,dl) , checkMimeType)


# reproject a bearing range onto (assumed level) image.




#
