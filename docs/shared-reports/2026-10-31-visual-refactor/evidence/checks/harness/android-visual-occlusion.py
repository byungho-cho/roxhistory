import subprocess,time,json,hashlib
from android_ready import wait_title
from pathlib import Path
r=Path.cwd();out=r/'visual-evidence';a=['C:/Users/sentr/AppData/Local/Temp/roxhistory-tools/android-sdk/platform-tools/adb.exe','-s','emulator-5556']
def run(*v):return subprocess.check_output(a+list(v),text=True,stderr=subprocess.STDOUT).strip()
def move(dx,dy,ms):run('shell','input','swipe',str(184+dx),str(582+dy),str(184+dx),str(582+dy),str(ms));time.sleep(.3)
def snap(name):
 run('shell','screencap','-p','/sdcard/scene-occlusion.png');run('pull','/sdcard/scene-occlusion.png',str(out/(name+'.png')))
def position():
 run('shell','input','tap','106','65');time.sleep(.2)
 p=json.loads(json.loads(run('shell','run-as','com.roxhistory.demo','cat','files/tests/session/save.json'))['payload'])['position']
 run('shell','input','keyevent','4');time.sleep(.2);return p
normal=run('shell','run-as','com.roxhistory.demo','cat','files/save.json')
outer=json.loads((out/'comparison-fixture.json').read_text());data=json.loads(outer['payload']);data['position']=[1700,1150]
payload=json.dumps(data,separators=(',',':'));outer={'payload':payload,'sha256':hashlib.sha256(payload.encode()).hexdigest()}
f=out/'occlusion-fixture.json';f.write_text(json.dumps(outer),encoding='utf-8')
run('shell','am','force-stop','com.roxhistory.demo');run('push',str(f),'/data/local/tmp/occlusion-fixture.json');run('shell','run-as','com.roxhistory.demo','cp','/data/local/tmp/occlusion-fixture.json','files/tests/session/save.json')
run('logcat','-c');run('shell','am','start','-n','com.roxhistory.demo/com.godot.game.GodotApp','--esa','command_line_params','--,--test-ui');wait_title(a);run('shell','input','tap','1010','350');time.sleep(2)
log=open(out/'occlusion-record.log','w',encoding='utf-8');rec=subprocess.Popen([str(r/'.tools/scrcpy/scrcpy-win64-v5.0.1/scrcpy.exe'),'--serial=emulator-5556','--no-playback','--no-control','--require-audio','--audio-source=playback','--audio-codec=aac','--time-limit=28','--record='+str(out/'android-occlusion.mp4')],stdout=log,stderr=subprocess.STDOUT)
time.sleep(1);snap('occlusion-front');positions={'front':position()}
move(0,-64,1000);snap('occlusion-blocked');positions['blocked']=position()
move(64,0,700);move(0,-64,1100);move(-64,0,700);snap('occlusion-behind');positions['behind']=position()
move(64,0,700);move(0,64,1500);move(-64,0,700);snap('occlusion-return');positions['return']=position()
assert positions['blocked'][1]>1060 and positions['blocked'][1]<1150,positions
assert positions['behind'][1]<1020 and positions['return'][1]>1080,positions
assert normal==run('shell','run-as','com.roxhistory.demo','cat','files/save.json')
rec.wait(timeout=35);log.close();assert rec.returncode==0
report={'utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'method':'Initial staged isolated test position1700,1150; all subsequent movement actual Android touch, normal save preserved','positions':positions,'ui_calibration':'After wm-size restoration, observed safe inset shifts joystick center to184/582 and back center to106/65; coordinates confirmed from live screenshot','checks':['visible trunk blocks forward movement','walk around trunk to behind canopy','return to front'],'visual_review':'screenshots and original-speed clip reviewed separately'}
(out/'android-occlusion.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps(report))
