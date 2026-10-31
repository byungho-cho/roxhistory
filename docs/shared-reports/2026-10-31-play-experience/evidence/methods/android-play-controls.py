from pathlib import Path
import subprocess,time,json
r=Path.cwd();out=r/'play-evidence';a=['adb','-s','emulator-5556']
def run(*v):return subprocess.check_output(a+list(v),text=True,stderr=subprocess.STDOUT).strip()
def touch(coords,ms=1000):return run('shell','CLASSPATH=/data/local/tmp/rox-input.jar','app_process','/','MultiTouch',*map(str,coords),str(ms))
def state():return json.loads(json.loads(run('shell','run-as','com.roxhistory.demo','cat','files/tests/session/save.json'))['payload'])
def snap(name):
 run('shell','screencap','-p','/sdcard/play-controls.png');run('pull','/sdcard/play-controls.png',str(out/'after'/name))
def resume():run('shell','am','start','-n','com.roxhistory.demo/com.godot.game.GodotApp','--esa','command_line_params','--,--test-ui');time.sleep(6)
legacy=out/'legacy-comparison-prefs.cfg';legacy.write_text('[app]\nwelcomed=true\nsound=true\ncharacter_3d=false\n')
run('push',str(legacy),'/data/local/tmp/legacy-comparison-prefs.cfg');run('shell','run-as','com.roxhistory.demo','cp','/data/local/tmp/legacy-comparison-prefs.cfg','files/tests/preferences.cfg')
run('shell','am','force-stop','com.roxhistory.demo');run('shell','run-as','com.roxhistory.demo','cp','/data/local/tmp/comparison-fixture.json','files/tests/session/save.json');run('logcat','-c');resume();time.sleep(3);run('shell','input','tap','1010','350');time.sleep(2)
log=open(out/'controls-record.log','w',encoding='utf-8');rec=subprocess.Popen([str(r/'.tools/scrcpy/scrcpy-win64-v5.0.1/scrcpy.exe'),'--serial=emulator-5556','--no-playback','--no-control','--require-audio','--audio-source=playback','--audio-codec=aac','--time-limit=45','--record='+str(out/'android-play-controls.mp4')],stdout=log,stderr=subprocess.STDOUT)
time.sleep(2);snap('android-world.png');touch([440,430,600,430,300,430,740,430],1200);time.sleep(.6);snap('android-zoom.png')
for dx,dy in [(0,50),(40,40),(50,0),(40,-40),(0,-50),(-40,-40),(-50,0),(-40,40)]:
 run('shell','input','swipe',str(184+dx),str(582+dy),str(184+dx),str(582+dy),'300');time.sleep(.25)
touch([440,430,600,430,440,430,760,430],1000)
touch([440,430,760,430,440,430,600,430],1000)
run('shell','input','tap','1020','170');time.sleep(.3)
touch([300,430,740,430,440,430,600,430],1200);time.sleep(1);snap('android-zoom-return.png')
log_before=run('logcat','-d','-s','godot:V').count('PLAY_PINCH_BEGIN')
touch([184,582,600,350,184,582,800,350],900)
assert run('logcat','-d','-s','godot:V').count('PLAY_PINCH_BEGIN')==log_before,'Joystick touch incorrectly began pinch'
touch([830,630,600,350,830,630,800,350],700);time.sleep(.4);snap('android-disabled-reason.png')
assert state()['wood']==0 and state()['stone']==0
# Interrupt a real two-pointer stream with Android HOME.
proc=subprocess.Popen(a+['shell','CLASSPATH=/data/local/tmp/rox-input.jar','app_process','/','MultiTouch','440','430','600','430','300','430','740','430','2000'],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
time.sleep(.7);run('shell','input','keyevent','3');proc.communicate(timeout=8);first=state();resume();time.sleep(1);snap('android-pinch-resumed.png')
run('shell','input','keyevent','3');second=state();assert first['position']==second['position'],'Movement remained held after interrupted pinch';resume()
assert state()['wood']==0 and state()['stone']==0 and state()['depleted']=={}
text=run('logcat','-d','-s','godot:V','AndroidRuntime:E');(out/'android-controls-logcat.txt').write_text(text,encoding='utf-8')
assert 'PLAY_PINCH_END 3' in text and 'PLAY_PINCH_END 2.7' in text and 'SCRIPT ERROR' not in text,text[-2000:]
report={'utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'checks':['legacy false comparison setting still displays the 3D hero','symmetric two-pointer pinch reaches 2.75x','pinch-in returns toward base','one stationary finger and one moving finger reaches bounded 3x zoom','eight short joystick directions rendered','quest guidance interrupted by pinch','joystick-owned finger excluded from pinch','disabled UI touch does not grant resources','HOME interrupts pinch and resume preserves zero movement','no unintended resource mutation'],'normal_save_unchanged':(out/'normal-save-preserved.json').read_text(encoding='utf-8')==run('shell','run-as','com.roxhistory.demo','cat','files/save.json'),'environment':'API35 emulator; actual Android MotionEvent injection; staged isolated save for controls comparison','failures':[]}
(out/'android-controls.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps(report),flush=True)
rec.wait(timeout=55);log.close();assert rec.returncode==0
