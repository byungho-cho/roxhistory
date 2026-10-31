from pathlib import Path
import subprocess,time,json,wave,array,math
r=Path.cwd();o=r/'play-evidence';a=['adb','-s','emulator-5556']
def run(*v):return subprocess.check_output(a+list(v),text=True,stderr=subprocess.STDOUT).strip()
run('shell','am','force-stop','com.roxhistory.demo')
for name,target in [('comparison-fixture.json','files/tests/session/save.json'),('comparison-prefs.cfg','files/tests/preferences.cfg')]:
 run('push',str(o/name),'/data/local/tmp/'+name);run('shell','run-as','com.roxhistory.demo','cp','/data/local/tmp/'+name,target)
run('shell','am','start','-n','com.roxhistory.demo/com.godot.game.GodotApp','--esa','command_line_params','--,--test-ui');time.sleep(10);run('shell','input','tap','1010','350');time.sleep(3)
with open(o/'after/audio-final.log','w') as log:
 subprocess.run([str(r/'.tools/scrcpy/scrcpy-win64-v5.0.1/scrcpy.exe'),'--serial=emulator-5556','--no-video','--no-playback','--no-control','--require-audio','--audio-source=playback','--audio-codec=raw','--time-limit=12','--record='+str(o/'after/android-ambience.wav')],stdout=log,stderr=subprocess.STDOUT,check=True)
metrics={}
for key in ['before','after']:
 p=o/key/'android-ambience.wav'
 with wave.open(str(p),'rb') as w:
  channels=w.getnchannels();rate=w.getframerate();assert w.getsampwidth()==2
  x=array.array('h',w.readframes(w.getnframes()))[rate*channels:]
 rms=math.sqrt(sum(v*v for v in x)/len(x))/32768
 assert rms>.0001
 metrics[key]={'rms_dbfs':round(20*math.log10(rms),2),'peak_dbfs':round(20*math.log10(max(abs(v) for v in x)/32768),2),'sample_rate':rate,'channels':channels}
report={'utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'position':[1060,1030],'media_volume':'15/15','output':'Android playback capture to PCM; no physical speaker/headphone listening performed','before_apk_sha256':'ef254148f81fc1d7d6e76ea1e34ef0859a09098682f3af687d87fe210327d9fb','after_apk_sha256':json.loads((o/'build/validation.json').read_text())['sha256'],'metrics':metrics}
(o/'audio-comparison.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
assert (o/'normal-save-preserved.json').read_text()==run('shell','run-as','com.roxhistory.demo','cat','files/save.json')
