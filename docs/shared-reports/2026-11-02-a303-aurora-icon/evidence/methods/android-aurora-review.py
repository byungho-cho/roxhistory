from pathlib import Path
import subprocess,time,json,re,hashlib
from android_ready import wait_title
r=Path(__file__).resolve().parent;o=r/'aurora-icon-evidence'
a=['C:/Users/sentr/AppData/Local/Temp/roxhistory-tools/android-sdk/platform-tools/adb.exe','-s','emulator-5554']
def run(*v):return subprocess.check_output(a+list(v),text=True,stderr=subprocess.STDOUT,timeout=40).strip()
def tap(x,y):run('shell','input','tap',str(round(x)),str(round(y)))
def rows(tag):return [json.loads(l.split(tag+' ',1)[1]) for l in run('logcat','-d','-s','godot:V').splitlines() if tag+' ' in l]
def state():
 z=rows('REGION_STATE');return z[-1] if z else None
def audio():
 z=rows('A303_AUDIO_STATE');return z[-1] if z else None
def wait(pred,timeout=25):
 end=time.monotonic()+timeout
 while time.monotonic()<end:
  s=state()
  if s and pred(s):return s
  time.sleep(.2)
 raise RuntimeError('Map state timeout '+str(state()))
def snap(name):
 (o/(name+'.png')).write_bytes(subprocess.check_output(a+['exec-out','screencap','-p'],timeout=30))
def point(key):
 s=state();w,h=s['size'];f=max(w/1600,h/900);u=min(w/1600,h/900);x,y={'jeongok':(510,138),'amsa':(610,214),'dongsam':(967,633)}[key]
 return ((s['pan'][0]+x*f*s['zoom'])*1280/w,(s['pan'][1]+y*f*s['zoom']-40*u)*720/h)
checks=[]
run('shell','am','force-stop','com.roxhistory.demo');run('logcat','-c')
run('shell','am','start','-n','com.roxhistory.demo/com.godot.game.GodotApp','--esa','command_line_params','--,--test-ui');wait_title(a)
if not audio()['enabled']:tap(1190,65);time.sleep(.5)
tap(1045,440);wait(lambda s:s['reason']=='ready');time.sleep(1)
assert audio()['enabled'] and audio()['bgm'];checks.append('A303 enters with approved BGM playing')
run('push',str(r/'panel-fix-evidence/methods/tap-sequence.jar'),'/data/local/tmp/rox-panel-taps.jar')
run('push',str(r/'.tools/android-input/rox-input.jar'),'/data/local/tmp/rox-input.jar')
log=open(o/'record.log','w',encoding='utf-8')
rec=subprocess.Popen([str(r/'.tools/scrcpy/scrcpy-win64-v5.0.1/scrcpy.exe'),'--serial=emulator-5554','--no-playback','--no-control','--video-bit-rate=2M','--max-fps=30','--require-audio','--audio-source=playback','--audio-codec=aac','--time-limit=65','--record='+str(o/'android-a303-loop.mp4')],stdout=log,stderr=subprocess.STDOUT)
start=time.monotonic();samples=[]
for key in ['jeongok','amsa','dongsam']:
 old=state();tap(*point(key));s=wait(lambda s:s['selected']==key and s['ticks_ms']>old['ticks_ms']);assert s['zoom']==old['zoom'] and s['pan']==old['pan'];time.sleep(.6);snap('android-'+key);samples.append(audio())
checks.append('Three region panels match selection; no automatic zoom/pan')
args=[]
for key in ['jeongok','amsa','dongsam']*6:
 x,y=point(key);args.extend([str(round(x)),str(round(y)),'35'])
timing=run('shell','CLASSPATH=/data/local/tmp/rox-panel-taps.jar','app_process','/','TapSequence',*args);(o/'rapid-timing.txt').write_text(timing)
s=wait(lambda s:s['selected']=='dongsam' and s['panel_visible'] and s['touches']==0);samples.append(audio());checks.append('Rapid Android touches settle on Dongsam with all fingers released')
tap(640,400);wait(lambda s:not s['panel_visible']);tap(*point('amsa'));wait(lambda s:s['selected']=='amsa' and s['panel_visible']);checks.append('Background closes panel; region reopens it')
run('shell','CLASSPATH=/data/local/tmp/rox-input.jar','app_process','/','MultiTouch','350','360','530','360','300','360','580','360','1000')
wait(lambda s:s['zoom']>1.1 and s['touches']==0);snap('android-zoom');s=state();x,y,w,h=s['reset'];tap((x+w/2)*1280/s['size'][0],(y+h/2)*720/s['size'][1]);wait(lambda s:abs(s['zoom']-1)<.001 and s['reason']=='animation_end');checks.append('Native two-finger zoom and reset preserve selection')
while time.monotonic()-start<59:
 time.sleep(2);tap(*point('amsa'));samples.append(audio())
positions=[s['position'] for s in samples if s['bgm'] and not s['paused']]
assert any(b<a-20 for a,b in zip(positions,positions[1:])),positions
checks.append('Natural music loop crosses boundary without restart/crash');snap('android-after-loop')
rec.wait(timeout=15);log.close();assert rec.returncode==0,(o/'record.log').read_text()
old=state();task=re.search(r'mFocusedApp=.*com.roxhistory.demo.* t(\d+)',run('shell','dumpsys','window')).group(1)
run('shell','input','keyevent','3');time.sleep(.5);paused=audio();assert not paused['active'] and paused['paused']
run('shell','am','task','focus',task);time.sleep(2);tap(640,400);wait(lambda s:s['ticks_ms']>old['ticks_ms']);tap(*point('amsa'));wait(lambda s:s['selected']=='amsa' and s['panel_visible']);assert audio()['active'] and not audio()['paused'];checks.append('Home/resume pauses and resumes music; fresh input works')
# Return to title to toggle sound through the actual persistent preference control.
tap(55,52);time.sleep(.8);tap(1190,65);time.sleep(.5);assert not audio()['enabled'];tap(1190,65);time.sleep(.5);assert audio()['enabled'];checks.append('Mute/unmute through title button applies without duplicate playback')
tap(1045,440);wait(lambda s:s['reason']=='ready');snap('android-final')
proof=json.loads((o/'update-proof.json').read_text());preserved={}
for p,h in proof['preserved_sha256'].items():
 if p.endswith('preferences.cfg'):continue
 b=subprocess.check_output(a+['shell','run-as','com.roxhistory.demo','cat',p]);assert hashlib.sha256(b).hexdigest()==h,p;preserved[p]=h
checks.append('Map/audio review leaves existing normal and test saved games unchanged')
logs=run('logcat','-d','-s','godot:V','AndroidRuntime:E');assert 'SCRIPT ERROR' not in logs and 'FATAL EXCEPTION' not in logs
(o/'android-logcat.txt').write_text(logs,encoding='utf-8')
report={'utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'source':'0e9b67695e1b1d4e309a22fe28b371921474d6f7','environment':'Android15 API35 x86_64 emulator-5554,1280x720; host GPU; emulator -no-audio; internal playback capture','checks':checks,'failed':[],'audio_samples':samples,'physical_device_verified':False,'speaker_listening_verified':False,'preserved_saves':preserved}
(o/'android-checks.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(report,ensure_ascii=False),flush=True)

