from storage_cleanup11 import *
import zipfile
OUT=ROOT/'docs/maintenance/evidence/disk-cleanup'
rows=json.loads((OUT/'deleted-files.json').read_text());audit=[]
for rel,base in [('.tools/godot-4.0.zip','.tools/godot'),('.tools/engines/gmsh.zip','.tools/engines'),('.tools/engines/calculix-2.23.zip','.tools/engines/calculix')]:
 p=ROOT/rel
 if not p.exists():continue
 members=[];valid=True
 with zipfile.ZipFile(p) as z:
  for member in z.infolist():
   if member.is_dir():continue
   installed=ROOT/base/member.filename
   if not installed.resolve().is_relative_to(ROOT/base) or not installed.is_file():valid=False;break
   digest=hashlib.sha256(z.read(member)).hexdigest()
   if digest!=sha(installed):valid=False;break
   members.append(dict(member=member.filename,installed=installed.relative_to(ROOT).as_posix(),size=member.file_size,sha256=digest))
 audit.append(dict(archive=rel,all_members_match_installed=valid,members=members))
 (OUT/'download-cache-verification.json').write_text(json.dumps(audit,indent=2))
 if valid and members:
  record=dict(path=rel,size=p.stat().st_size,sha256=sha(p),classification='redundant verified download ZIP',recovery='Complete installed contents preserved at '+base+'; repack these files for offline installation or reacquire original official archive and verify recorded SHA-256. Original ZIP byte stream not needed for running installed binaries.')
  rows.append(record);(OUT/'deleted-files.json').write_text(json.dumps(rows,indent=2));p.unlink()
  print(json.dumps(record),flush=True)
