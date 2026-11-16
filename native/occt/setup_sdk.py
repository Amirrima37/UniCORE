import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[2]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
"""Reproduce the official package extraction; never modifies pinned engine packs."""
import json,subprocess,hashlib,os
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];SDK=sdk_root();SDK.mkdir(parents=True,exist_ok=True)
lock=json.loads(Path(__file__).with_name('sdk-lock.json').read_text())
env=os.environ.copy();env['PATH']='D:/msys64/usr/bin;'+env.get('PATH','')
for record in lock['packages']:
    archive=SDK/record.get('local_archive',record['filename'])
    if not archive.exists():subprocess.run(['curl.exe','-L','--fail','--max-time','180',record['url'],'-o',str(archive)],check=True)
    if hashlib.sha256(archive.read_bytes()).hexdigest()!=record['sha256']:raise RuntimeError('SDK package hash mismatch: '+str(archive))
    subprocess.run(['D:/msys64/usr/bin/tar.exe','--force-local','-xf',str(archive),'-C',str(SDK)],env=env,check=True)
subprocess.run(['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',str(ROOT/'native/build_occt.ps1')],cwd=ROOT,check=True)
