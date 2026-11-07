class_name BuildingWorkAudio
extends Node
## Sparse work phrases, shared across simultaneous durable jobs. No endless loop.
const SECOND_PHRASE:=1.5
const LATER_INTERVAL:=35.0
var app:Node
var observed:Dictionary={}
var cooldown:=0.0
func _init(owner_app:Node)->void:app=owner_app
func job_snapshot()->Dictionary:
 var jobs:Dictionary={}
 for job in app.model.construction_jobs():jobs["build:"+str(job.uid)]=job
 if app.model.state.has("chief_upgrade"):jobs["chief"]=app.model.state.chief_upgrade
 for key in OwnedBuildingUpgrades.keys(app.model):
  var job:Dictionary=app.model.lookup_building(key).get("data",{}).get("upgrade",{})
  if not job.is_empty():jobs[key]=job
 return jobs
static func phase(age:float)->int:
 if age<SECOND_PHRASE:return 0
 if age<LATER_INTERVAL:return 1
 return 2+int(age/LATER_INTERVAL)
func _process(delta:float)->void:
 cooldown=maxf(0,cooldown-delta)
 if app.model.state.is_empty():observed.clear();return
 var now:=Time.get_unix_time_from_system()
 var eligible:bool=app.screen=="play" and not app.modal and not app.world_map_open and app.application_active and app.task.is_empty()
 var current:=job_snapshot()
 var candidate:=false
 for key in current:
  var job:Dictionary=current[key]
  if float(job.finishes_at)<=now:continue
  var age:=maxf(0,now-float(job.started_at))
  var identity:="%s:%s:%s"%[key,job.started_at,job.to]
  var stage:=phase(age)
  if not observed.has(identity):
   # Resuming an old job does not replay its historical first phrase.
   candidate=candidate or age<.6
  elif int(observed[identity])<stage:candidate=true
  observed[identity]=stage
 var live:Dictionary={}
 for key in current:
  var job:Dictionary=current[key]
  var identity:="%s:%s:%s"%[key,job.started_at,job.to]
  if observed.has(identity):live[identity]=observed[identity]
 observed=live
 if eligible and candidate and cooldown<=0:
  app.audio.cue("build");cooldown=1.0
