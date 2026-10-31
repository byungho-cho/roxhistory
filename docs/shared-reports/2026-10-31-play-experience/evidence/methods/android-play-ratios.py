import subprocess,time,json
from pathlib import Path
out=Path(__file__).resolve().parent/'play-evidence'
b=['adb','-s','emulator-5556']
def run(*a):return subprocess.check_output(b+list(a),text=True,stderr=subprocess.STDOUT).strip()
results=[]
try:
 for name,size in [('cover','370x896'),('unfolded','616x816')]:
  run('shell','wm','size',size);time.sleep(3)
  run('shell','screencap','-p','/sdcard/ratio.png');run('pull','/sdcard/ratio.png',str(out/('android-'+name+'.png')))
  width,height=map(int,size.split('x'));wide=max(width,height);short=min(width,height)
  x0=int(wide*.40);x1=int(wide*.60);y=int(short*.50)
  run('shell','CLASSPATH=/data/local/tmp/rox-input.jar','app_process','/','MultiTouch',str(x0),str(y),str(x1),str(y),str(int(wide*.30)),str(y),str(int(wide*.70)),str(y),'800')
  time.sleep(.5);run('shell','screencap','-p','/sdcard/ratio.png');run('pull','/sdcard/ratio.png',str(out/('android-'+name+'-zoom.png')))
  run('shell','CLASSPATH=/data/local/tmp/rox-input.jar','app_process','/','MultiTouch',str(int(wide*.30)),str(y),str(int(wide*.70)),str(y),str(x0),str(y),str(x1),str(y),'800')
  results.append({'name':name,'physical_override':size,'check':'Live resize; screenshot visual review required'})
finally:run('shell','wm','size','720x1280')
(out/'android-ratios.json').write_text(json.dumps({'utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'mode':'ADB wm size, not physical folding device','screens':results},indent=2),encoding='utf-8')
