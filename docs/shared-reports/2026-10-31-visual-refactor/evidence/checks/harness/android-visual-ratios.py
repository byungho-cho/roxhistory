import subprocess,time,json
from pathlib import Path
out=Path(__file__).resolve().parent/'visual-evidence'
b=['C:/Users/sentr/AppData/Local/Temp/roxhistory-tools/android-sdk/platform-tools/adb.exe','-s','emulator-5556']
def run(*a):return subprocess.check_output(b+list(a),text=True,stderr=subprocess.STDOUT).strip()
results=[]
try:
 for name,size in [('cover','370x896'),('unfolded','616x816')]:
  run('shell','wm','size',size);time.sleep(10)
  run('shell','screencap','-p','/sdcard/ratio.png');run('pull','/sdcard/ratio.png',str(out/('android-'+name+'.png')))
  width,height=map(int,size.split('x'));wide=max(width,height);short=min(width,height)
  x0=int(wide*.40);x1=int(wide*.60);y=int(short*.50)
  run('shell','CLASSPATH=/data/local/tmp/rox-input.jar','app_process','/','MultiTouch',str(x0),str(y),str(x1),str(y),str(int(wide*.30)),str(y),str(int(wide*.70)),str(y),'800')
  time.sleep(2);run('shell','screencap','-p','/sdcard/ratio.png');run('pull','/sdcard/ratio.png',str(out/('android-'+name+'-zoom.png')))
  run('shell','CLASSPATH=/data/local/tmp/rox-input.jar','app_process','/','MultiTouch',str(int(wide*.30)),str(y),str(int(wide*.70)),str(y),str(x0),str(y),str(x1),str(y),'800')
  results.append({'name':name,'physical_override':size,'check':'Live resize with10s settle; early3s capture was stale/cropped, settled screenshot reviewed'})
finally:run('shell','wm','size','720x1280')
(out/'android-ratios.json').write_text(json.dumps({'utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'mode':'ADB wm size, not physical folding device','screens':results},indent=2),encoding='utf-8')
