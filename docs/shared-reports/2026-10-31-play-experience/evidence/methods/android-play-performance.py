from pathlib import Path
import subprocess,time,json,hashlib
r=Path.cwd();out=r/'play-evidence';a=['adb','-s','emulator-5556']
def run(*v):return subprocess.check_output(a+list(v),text=True,stderr=subprocess.STDOUT).strip()
normal=run('shell','run-as','com.roxhistory.demo','cat','files/save.json');results=[]
run('shell','wm','size','720x1280')
for version,apk in [('0.1.6-hero',out/'before/RoxHistory-0.1.6-hero-debug.apk'),('0.1.7-play',out/'build/RoxHistory-0.1.7-play-debug.apk')]:
 run('shell','am','force-stop','com.roxhistory.demo');run('install','-r','-d',str(apk))
 for name,target in [('comparison-fixture.json','files/tests/session/save.json'),('comparison-prefs.cfg','files/tests/preferences.cfg')]:
  run('push',str(out/name),'/data/local/tmp/'+name);run('shell','run-as','com.roxhistory.demo','cp','/data/local/tmp/'+name,target)
 run('logcat','-c');run('shell','am','start','-n','com.roxhistory.demo/com.godot.game.GodotApp','--esa','command_line_params','--,--test-ui');time.sleep(12)
 run('shell','input','tap','1010','350');time.sleep(1)
 if version.startswith('0.1.6'):
  run('shell','input','tap','120','65');time.sleep(.3);run('shell','input','tap','780','625')
 metric=None
 for i in range(40):
  time.sleep(1.5);log=run('logcat','-d','-s','godot:V')
  lines=[l.split('HYBRID_PERF ',1)[1] for l in log.splitlines() if 'HYBRID_PERF ' in l]
  if lines:
   candidate=json.loads(lines[-1])
   if candidate['mode']=='3D':metric=candidate;break
 assert metric,version+' did not produce 3D timing sample'
 metric.update(version=version,apk_sha256=hashlib.sha256(apk.read_bytes()).hexdigest(),utc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()))
 results.append(metric);(out/'android-performance-progress.json').write_text(json.dumps(results,indent=2));print(json.dumps(metric),flush=True)
 assert normal==run('shell','run-as','com.roxhistory.demo','cat','files/save.json'),'Normal progress changed'
report={'conditions':'Android15/API35 x86_64, RTX5060 host, physical1280x720, logical960x540, staged test position1060,1030, base zoom, 3D idle, no video/audio recording or other Godot test process; first60 frames discarded, next600 process intervals. One sample each; not physical-device GPU profiling or sustained thermal test.','results':results,'normal_save_unchanged':True}
(out/'android-performance.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
