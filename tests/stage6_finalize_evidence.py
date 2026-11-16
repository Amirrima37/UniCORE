"""Archive fixed-path fixture outputs, restore historical bytes, and collect receipts."""
import hashlib, json, re, shutil, struct
from pathlib import Path
root=Path(__file__).resolve().parents[1]
out=root/'docs/workbench-2/stage6-final'
refreshed=out/'refreshed';refreshed.mkdir(exist_ok=True)
record=out/'restored-historical-files.json'
restored=json.loads(record.read_text()) if record.exists() else []
# Always restore the earliest saved version. The graphics backup was taken after
# focused fixtures ran and therefore must not supersede the earlier backup.
seen=set()
for backup in [out/'before-focused',out/'before-graphics']:
    for p in backup.iterdir():
        if p.suffix.lower()=='.md':continue
        if p.name in seen:continue
        seen.add(p.name);target=root/'docs/workbench-2'/p.name
        if target.exists() and target.read_bytes()!=p.read_bytes():
            if not (refreshed/p.name).exists():shutil.copy2(target,refreshed/p.name)
            shutil.copy2(p,target)
            if p.name not in restored:restored.append(p.name)
(out/'restored-historical-files.json').write_text(json.dumps(restored,indent=2))
matrix=json.loads((out/'native-matrix-fields.json').read_text())
for i,row in enumerate(matrix):
    source=Path(row['directory']);dest=out/'native-jobs'/str(i);dest.mkdir(parents=True,exist_ok=True)
    for p in source.iterdir():
        if p.is_file():shutil.copy2(p,dest/p.name)
for p in (root/'docs/workbench-2').glob('stage6-ui-*.png'):
    if not (refreshed/p.name).exists():shutil.copy2(p,refreshed/p.name)
images=[]
for p in [*out.glob('cylinder-*.png'),*refreshed.glob('stage6-ui-*.png')]:
    width,height=struct.unpack('>II',p.read_bytes()[16:24]);assert (width,height) in [(1280,720),(1920,1080)]
    images.append(dict(path=str(p.relative_to(root)),width=width,height=height,sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
(out/'images.json').write_text(json.dumps(images,indent=2))
receipts=[]
for phase in ['lifecycle','build','native','focused','regression','graphics','references']:
    entries=json.loads((out/(phase+'.json')).read_text())
    for entry in entries:
        if phase=='focused' and entry['name']=='test_stage51_cache' and entry.get('timeout'):
            entry['log']=str((out/'cache-fixture-failed.log').relative_to(root))
            entry['engine_log']=str((out/'cache-fixture-failed-engine.log').relative_to(root))
        if phase=='native' and entry['name']=='test_stage6_native_matrix':
            entry['log']=str((out/'native-six-initial.log').relative_to(root))
    receipts.extend(entries)
for row in json.loads((out/'regression/results.json').read_text()):
    log=out/'regression'/(Path(row['script']).stem+'.log')
    text=log.read_text(encoding='utf-8')
    parent_command=json.loads((out/'regression.json').read_text())[0]['command']
    engine=parent_command[parent_command.index('--godot')+1]
    row.update(command=[engine,'--headless','--path',str(root),'-s','res://'+row['script']],appdata=str(root/'.tools/cae-appdata'),log=str(log.relative_to(root)),assertions=[s for s in text.splitlines() if re.search(r'PASS|Passed|checks=|failures=',s)],diagnostics=[s for s in text.splitlines() if 'ERROR:' in s or 'WARNING:' in s])
    receipts.append(row)
(out/'all-test-receipts.json').write_text(json.dumps(receipts,indent=2))
print(len(receipts),'receipts;',len(images),'dimension-verified images;',len(restored),'historical files restored')
