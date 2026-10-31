from pathlib import Path
import subprocess,time,json,hashlib
r=Path.cwd();o=r/'play-evidence';a=['adb','-s','emulator-5556']
def run(*v):return subprocess.check_output(a+list(v),text=True,stderr=subprocess.STDOUT).strip()
def snap(n):run('shell','screencap','-p','/sdcard/contact.png');run('pull','/sdcard/contact.png',str(o/(n+'.png')))
checks=[]
for kind,pos,gesture in [('wood',[1320,830],[480,507,640,507,380,570,820,570]),('stone',[1440,1070],[560,533,720,533,380,570,820,570])]:
 envelope=json.loads((o/'comparison-fixture.json').read_text());state=json.loads(envelope['payload']);state['position']=pos;payload=json.dumps(state,separators=(',',':'));fixture=o/('contact-'+kind+'-fixture.json');fixture.write_text(json.dumps({'payload':payload,'sha256':hashlib.sha256(payload.encode()).hexdigest()}))
 run('shell','am','force-stop','com.roxhistory.demo');run('push',str(fixture),'/data/local/tmp/contact-fixture.json');run('shell','run-as','com.roxhistory.demo','cp','/data/local/tmp/contact-fixture.json','files/tests/session/save.json');run('shell','am','start','-n','com.roxhistory.demo/com.godot.game.GodotApp','--esa','command_line_params','--,--test-ui');time.sleep(9);run('shell','input','tap','1010','350');time.sleep(2)
 log=open(o/('contact-'+kind+'.log'),'w');rec=subprocess.Popen([str(r/'.tools/scrcpy/scrcpy-win64-v5.0.1/scrcpy.exe'),'--serial=emulator-5556','--no-playback','--no-control','--require-audio','--audio-source=playback','--audio-codec=aac','--time-limit=12','--record='+str(o/('android-contact-'+kind+'.mp4'))],stdout=log,stderr=subprocess.STDOUT)
 time.sleep(1.5);run('shell','CLASSPATH=/data/local/tmp/rox-input.jar','app_process','/','MultiTouch',*map(str,gesture),'1000');time.sleep(.5)
 run('shell','input','tap','830','630');time.sleep(.55);snap('android-contact-'+kind);time.sleep(.65);snap('android-credit-'+kind);time.sleep(.5)
 current=json.loads(json.loads(run('shell','run-as','com.roxhistory.demo','cat','files/tests/session/save.json'))['payload']);assert current[kind]==1,current
 checks.append(kind+' contact and exactly one grant at zoom');rec.wait(timeout=15);log.close()
assert (o/'normal-save-preserved.json').read_text()==run('shell','run-as','com.roxhistory.demo','cat','files/save.json')
(o/'android-contact.json').write_text(json.dumps({'utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'checks':checks,'method':'Actual Android two-pointer MotionEvents and action tap; separate isolated saved-position fixtures for closeups, not a continuous playthrough','failed':[]},indent=2))
