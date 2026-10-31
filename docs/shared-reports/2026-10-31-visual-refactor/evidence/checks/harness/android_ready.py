import subprocess,time

def wait_title(adb, timeout=75):
    """Await an actual title-screen event after cold start; no gameplay input is retried."""
    deadline=time.monotonic()+timeout
    start=len(subprocess.check_output(adb+['logcat','-d','-s','godot:V'],text=True,timeout=10))
    while time.monotonic()<deadline:
        subprocess.run(adb+['shell','input','tap','10','10'],check=True,timeout=15)
        time.sleep(.5)
        log=subprocess.check_output(adb+['logcat','-d','-s','godot:V'],text=True,timeout=10)
        if 'screen=title' in log[start:]:
            time.sleep(1)
            return
    raise RuntimeError('Title screen did not become ready')


def read_state(adb):
    import json,hashlib
    for attempt in range(20):
        p=subprocess.run(adb+['shell','run-as','com.roxhistory.demo','cat','files/tests/session/save.json'],capture_output=True,text=True,timeout=10)
        if p.returncode==0:
            envelope=json.loads(p.stdout)
            assert hashlib.sha256(envelope['payload'].encode()).hexdigest()==envelope['sha256']
            return json.loads(envelope['payload'])
        if 'No such file' not in p.stderr+p.stdout:
            raise RuntimeError(p.stderr+p.stdout)
        time.sleep(.1)
    raise RuntimeError('Current save absent after bounded atomic-replacement wait')


def walk_to(adb,x,y):
    import math
    def cmd(*args): return subprocess.check_output(adb+list(args),text=True,timeout=15)
    for _ in range(16):
        cmd('shell','input','tap','68','65');time.sleep(.2)
        state=read_state(adb);cmd('shell','input','keyevent','4');time.sleep(.2)
        px,py=state['position'];dx=x-px;dy=y-py;distance=math.hypot(dx,dy)
        if distance<30:return
        xx=round(144+64*dx/distance);yy=round(582+64*dy/distance)
        cmd('shell','input','swipe',str(xx),str(yy),str(xx),str(yy),str(min(1400,max(200,int(distance/165*1000)))))
        time.sleep(.2)
    raise RuntimeError('Did not reach interaction stand through actual movement')
