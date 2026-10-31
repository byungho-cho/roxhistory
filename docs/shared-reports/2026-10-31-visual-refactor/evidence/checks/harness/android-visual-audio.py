import subprocess,time,json,wave,array,math
from android_ready import wait_title
from pathlib import Path
r=Path(__file__).resolve().parent;out=r/'visual-evidence'
adb='C:/Users/sentr/AppData/Local/Temp/roxhistory-tools/android-sdk/platform-tools/adb.exe'
base=[adb,'-s','emulator-5556'];scrcpy=r/'.tools/scrcpy/scrcpy-win64-v5.0.1/scrcpy.exe'
def run(*a):return subprocess.check_output(base+list(a),text=True,stderr=subprocess.STDOUT).strip()
def tap(x,y):run('shell','input','tap',str(x),str(y));time.sleep(.5)
def record(name):
 p=out/(name+'.wav')
 with open(out/(name+'.log'),'w',encoding='utf-8') as log:
  subprocess.run([str(scrcpy),'--serial=emulator-5556','--no-video','--no-playback','--no-control','--require-audio','--audio-source=playback','--audio-codec=raw','--time-limit=5','--record='+str(p)],stdout=log,stderr=subprocess.STDOUT,check=True)
 with wave.open(str(p),'rb') as w:
  rate=w.getframerate();channels=w.getnchannels();width=w.getsampwidth();data=w.readframes(w.getnframes())
 assert width==2,width
 x=array.array('h',data)[rate*channels:]
 rms=math.sqrt(sum(v*v for v in x)/len(x))/32768
 return {'rms':rms,'dbfs':round(20*math.log10(max(rms,1e-10)),2),'samples':len(x)}
results={}
run('shell','cmd','media_session','volume','--stream','3','--set','15')
time.sleep(3) # System volume overlay temporarily owns focus/touches.
if 'sound=false' in run('shell','run-as','com.roxhistory.demo','cat','files/tests/preferences.cfg'):
 tap(68,65);tap(925,625);tap(450,625);tap(845,625)
time.sleep(2)
assert 'sound=true' in run('shell','run-as','com.roxhistory.demo','cat','files/tests/preferences.cfg')
results['foreground']=record('audio-foreground')
run('shell','input','keyevent','3');time.sleep(1)
results['background']=record('audio-background')
run('shell','am','start','-n','com.roxhistory.demo/com.godot.game.GodotApp','--esa','command_line_params','--,--test-ui');time.sleep(2)
results['resumed']=record('audio-resumed')
tap(68,65);tap(925,625);tap(450,625);tap(845,625)
results['muted']=record('audio-muted')
prefs=run('shell','run-as','com.roxhistory.demo','cat','files/tests/preferences.cfg')
assert 'sound=false' in prefs,prefs
run('shell','am','force-stop','com.roxhistory.demo');run('shell','am','start','-n','com.roxhistory.demo/com.godot.game.GodotApp','--esa','command_line_params','--,--test-ui');wait_title(base);tap(1010,350)
results['muted_after_restart']=record('audio-muted-restart')
assert results['foreground']['rms']>.0001,results
assert results['resumed']['rms']>.0001,results
for key in ['background','muted','muted_after_restart']:
 assert results[key]['rms']<results['foreground']['rms']*.03,(key,results)
assert results['resumed']['rms']<results['foreground']['rms']*1.5,'Possible duplicated ambience'
report={'utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'method':'Android playback capture by scrcpy PCM; media volume15/15; excludes first second per segment','results':results,'failed':[]}
(out/'android-audio.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps(report),flush=True)

# Restore sound only in the isolated test settings.
tap(68,65);tap(925,625);tap(450,625);tap(845,625)
assert "sound=true" in run("shell","run-as","com.roxhistory.demo","cat","files/tests/preferences.cfg")
