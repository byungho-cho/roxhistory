from pathlib import Path
import subprocess,time,json,math,re
from android_ready import wait_title
r=Path(__file__).resolve().parent;out=r/'selection-evidence'
a=['C:/Users/sentr/AppData/Local/Temp/roxhistory-tools/android-sdk/platform-tools/adb.exe','-s','emulator-5580']
def run(*args):return subprocess.check_output(a+list(args),text=True,stderr=subprocess.STDOUT,timeout=120).strip()
def tap(x,y):run('shell','input','tap',str(round(x)),str(round(y)))
def state():
 rows=[l.split('REGION_STATE ',1)[1] for l in run('logcat','-d','-s','godot:V').splitlines() if 'REGION_STATE ' in l]
 return json.loads(rows[-1]) if rows else None
def wait(predicate,timeout=15):
 deadline=time.monotonic()+timeout
 while time.monotonic()<deadline:
  s=state()
  if s and predicate(s):return s
  time.sleep(.15)
 raise RuntimeError('Map state timeout: '+str(state()))
def snap(name):
 run('shell','screencap','-p','/sdcard/selection-review.png');run('pull','/sdcard/selection-review.png',str(out/(name+'.png')))
def logical_tap(x,y):
 s=state();tap(x*1280/s['size'][0],y*720/s['size'][1])
def select(key):
 s=state();w,h=s['size'];f=max(w/1600,h/900);u=min(w/1600,h/900)
 x,y={'jeongok':(580,138),'amsa':(610,214),'dongsam':(967,633)}[key]
 logical_tap(s['pan'][0]+x*f*s['zoom'],s['pan'][1]+y*f*s['zoom']-40*u)
 return wait(lambda v:v['ticks_ms']>s['ticks_ms'] and v['selected']==key and v['panel_visible'])
def reset():
 s=state();x,y,w,h=s['reset'];logical_tap(x+w/2,y+h/2)
 return wait(lambda v:v['ticks_ms']>s['ticks_ms'] and v['reason']=='animation_end' and abs(v['zoom']-1)<.001)
def pinch():run('shell','CLASSPATH=/data/local/tmp/rox-input.jar','app_process','/','MultiTouch','350','360','530','360','300','360','580','360','1000')


results=[]
try:
 for value,label in [('370x896','cover'),('616x816','unfolded')]:
  old=state();run('shell','wm','size',value);s=wait(lambda s:s['reason']=='ready' and s['size']!=old['size']);time.sleep(1)
  task=re.search(r'mFocusedApp=.*com.roxhistory.demo.* t(\d+)',run('shell','dumpsys','window')).group(1)
  run('shell','input','keyevent','3');time.sleep(.7);run('shell','am','task','focus',task);time.sleep(2)
  snap('android-'+label+'-final');s=state()
  assert s['zoom']==1 and s['selected']=='amsa' and s['panel_visible']
  for key,rect in s['markers'].items():
   x,y,w,h=rect;assert x>=0 and y>=0 and x+w<=s['size'][0] and y+h<=s['size'][1],(key,s)
  results.append({'ratio':value,'state':s})
finally:run('shell','wm','size','720x1280')
report={'source_commit':'4d23753c91ba1b55f687e4dee09810b54556e039','utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'checks':results,'failed':[],'physical_device_verified':False}
(out/'android-ratios.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(report),flush=True)
