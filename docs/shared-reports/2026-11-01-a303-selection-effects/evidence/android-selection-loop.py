from pathlib import Path
import subprocess,time,json,math,re
from android_ready import read_state,wait_title,wait_game_touch
r=Path(__file__).resolve().parent; out=r/'selection-evidence'
a=['C:/Users/sentr/AppData/Local/Temp/roxhistory-tools/android-sdk/platform-tools/adb.exe','-s','emulator-5580']
def run(*args):return subprocess.check_output(a+list(args),text=True,stderr=subprocess.STDOUT,timeout=30).strip()
def tap(x,y,wait=.4):run('shell','input','tap',str(x),str(y));time.sleep(wait)
def snap(name):
 run('shell','screencap','-p','/sdcard/c001-review.png');run('pull','/sdcard/c001-review.png',str(out/(name+'.png')))
def state():return read_state(a)
def wait_state(predicate,timeout=10):
 deadline=time.monotonic()+timeout
 while time.monotonic()<deadline:
  s=state()
  if predicate(s):return s
  time.sleep(.2)
 raise AssertionError('Timed out waiting for committed gameplay state: '+str(state()))

def walk(x,y):
 for i in range(20):
  tap(110,100,.2);s=state();run('shell','input','keyevent','4');time.sleep(.2)
  px,py=s['position'];dx=x-px;dy=y-py;distance=math.hypot(dx,dy)
  if distance<25:return
  xx=round(185+64*dx/distance);yy=round(583+64*dy/distance)
  run('shell','input','swipe','185','583',str(xx),str(yy),str(min(1300,max(180,int(distance/165*1000)))))
  time.sleep(.2)
 raise RuntimeError('Movement did not reach '+str((x,y,state()['position'])))
(out/'normal-save-resume-before.json').write_text(run('shell','run-as','com.roxhistory.demo','cat','files/save.json'),encoding='utf-8')
run('shell','am','force-stop','com.roxhistory.demo')
prefs=out/'test-preferences.cfg';prefs.write_text('[app]\nwelcomed=false\nsound=true\ncharacter_3d=false\n')
run('push',str(prefs),'/data/local/tmp/c001-test-preferences.cfg')
run('shell','run-as','com.roxhistory.demo','cp','/data/local/tmp/c001-test-preferences.cfg','files/tests/preferences.cfg')
run('logcat','-c')
run('shell','am','start','-n','com.roxhistory.demo/com.godot.game.GodotApp','--esa','command_line_params','--,--test-ui')
time.sleep(9);snap('android-onboarding');tap(830,512);snap('android-title')
assert 'sound=true' in run('shell','run-as','com.roxhistory.demo','cat','files/tests/preferences.cfg')
tap(1045,440);tap(845,625);snap('android-region');tap(1100,654,2);tap(640,625,2)
snap('android-fresh');assert state()['wood']==0 and state()['stone']==0 and not state()['built']
start=time.monotonic()
log=open(out/'android-record.log','w',encoding='utf-8')
rec=subprocess.Popen([str(r/'.tools/scrcpy/scrcpy-win64-v5.0.1/scrcpy.exe'),'--serial=emulator-5580','--no-playback','--no-control','--video-bit-rate=3M','--max-fps=30','--require-audio','--audio-source=playback','--audio-codec=aac','--time-limit=90','--record='+str(out/'android-region-gameplay-raw.mp4')],stdout=log,stderr=subprocess.STDOUT)
walk(1367,846);tap(584,650,.08);tap(584,650,.1);wait_state(lambda s:s['wood']==1);snap('android-wood')
walk(1293,1086);tap(584,650,.08);tap(584,650,.1);wait_state(lambda s:s['stone']==1);snap('android-stone')
walk(780,1080);tap(808,650);snap('android-build-confirm');tap(845,625,.08);tap(845,625,.1);wait_state(lambda s:s['built'])
time.sleep(.8);snap('android-reward');tap(950,340,.08);tap(950,340);wait_state(lambda s:s['reward_claimed'])
s=state();assert s['built'] and s['reward_claimed'] and s['tokens']==10 and s['wood']==0 and s['stone']==0,s
time.sleep(1.5);elapsed=time.monotonic()-start;snap('android-completed')
run('shell','am','force-stop','com.roxhistory.demo');run('shell','am','start','-n','com.roxhistory.demo/com.godot.game.GodotApp','--esa','command_line_params','--,--test-ui');wait_title(a);tap(1045,354,2)
assert state()==s,'Saved game differs after restart';snap('android-continued')
tap(1075,650);snap('android-journal');run('shell','input','keyevent','4');time.sleep(.5);snap('android-journal-closed')
task_id=re.search(r'mFocusedApp=.*com.roxhistory.demo.* t(\d+)',run('shell','dumpsys','window')).group(1);run('shell','input','keyevent','3');time.sleep(1);run('shell','am','task','focus',task_id);time.sleep(2);time.sleep(2)
resume_wait=wait_game_touch(a)
run('shell','input','swipe','185','583','185','640','850');time.sleep(.5);tap(110,100);after=state();run('shell','input','keyevent','4')
assert after['position']!=s['position'],'Movement failed after resume'
normal=run('shell','run-as','com.roxhistory.demo','cat','files/save.json')
assert normal==(out/'normal-save-resume-before.json').read_text(encoding='utf-8-sig').strip(),'Normal save changed'
report={'version':'0.1.12-selection','source_commit':'feat/a303-fixed-selection working tree','utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'elapsed_seconds':round(elapsed,2),'resume_input_ready_wait_seconds':resume_wait,'environment':'Android15/API35 x86_64 emulator, RTX5060 host,1280x720; actual ADB touch input','checks':['onboarding sound choice persisted','legacy 2D setting ignored','fresh test session','wood once with repeat tap','stone once with repeat tap','build once costs 1+1','reward once grants10','force-stop/continue exact save','popup/back','home/resume center-to-edge joystick drag','normal save unchanged'],'state':s,'failed':[]}
(out/'android-loop.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(report,ensure_ascii=False),flush=True)
rec.wait(timeout=115);log.close()
(out/'android-logcat.txt').write_text(run('logcat','-d','-s','godot:V','AndroidRuntime:E'),encoding='utf-8')
assert rec.returncode==0,'Recording failed'
