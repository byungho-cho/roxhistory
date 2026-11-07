#!/usr/bin/env python3
"""Focused, reproducible headless checks. Not a device or pixel-render test."""
import argparse,json,os,pathlib,subprocess,tempfile
p=argparse.ArgumentParser();p.add_argument('--godot',required=True);args=p.parse_args()
root=pathlib.Path(__file__).resolve().parents[1]
out=root/'game/reports/v0151-final';out.mkdir(parents=True,exist_ok=True)
run_home=pathlib.Path(tempfile.mkdtemp(prefix='rox-v0151-qa-'))
env=os.environ.copy()
for name,folder in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
    dest=run_home/folder;dest.mkdir();env[name]=str(dest)
suites=['building_model_v0151_tests','building_ui_v0151_tests','v0151_world_population_tests','v0151_main_integration_tests','building_audio_v0151_tests','approved_assets_v0151_tests','a303_art_tests','recorded_action_audio_tests','play_music_tests','village_bounds_tests']
results=[]
for name in suites:
    result=subprocess.run([args.godot,'--headless','--path',str(root/'game'),'--script','tests/'+name+'.gd','--','--test-ui'],env=env,text=True,capture_output=True,timeout=100)
    text=result.stdout+result.stderr;(out/(name+'.log')).write_text(text)
    report={}
    for line in text.splitlines():
        try:
            obj=json.loads(line)
            if isinstance(obj,dict) and ('checks' in obj or 'failed' in obj):report=obj
        except (ValueError,TypeError):pass
    errors=report.get('failed',report.get('failures',[]))
    ok=result.returncode==0 and not errors and 'SCRIPT ERROR' not in text
    entry={'suite':name,'exit_code':result.returncode,'pass':ok,'checks':report.get('checks'),'failures':errors,'shutdown_resource_warning':'resources still in use' in text or 'ObjectDB instances leaked' in text}
    results.append(entry);print(json.dumps(entry),flush=True)
summary={'runtime':'Godot4.5.1 headless; state, input, geometry, source assets and mixer only','device_or_pixel_render':False,'all_focused_suites_pass':all(r['pass'] for r in results),'assertions_reported':sum(r['checks'] or 0 for r in results),'suites':results}
(out/'summary.json').write_text(json.dumps(summary,indent=2));print(json.dumps(summary))
raise SystemExit(0 if summary['all_focused_suites_pass'] else 1)
