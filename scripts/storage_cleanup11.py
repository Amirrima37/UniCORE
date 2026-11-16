"""Storage audit and recorded, explicitly selected cleanup operations."""
import sys,json,gzip,os,hashlib,collections,stat,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/maintenance/evidence/cleanup11'
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
 return h.hexdigest()
def scan():
 files=[];errors=[];reparse=[];dirs=collections.Counter()
 for base,children,names in os.walk(ROOT,followlinks=False,onerror=lambda e:errors.append(dict(path=e.filename,error=str(e),bytes=None))):
  for n in children[:]:
   p=Path(base)/n
   if p.lstat().st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT:children.remove(n);reparse.append(str(p.relative_to(ROOT)))
  for n in names:
   p=Path(base)/n
   try:
    s=p.lstat()
    if s.st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT:reparse.append(str(p.relative_to(ROOT)));continue
    r=p.relative_to(ROOT).as_posix();files.append(dict(path=r,size=s.st_size,mtime=s.st_mtime))
    for parent in p.relative_to(ROOT).parents:
     if str(parent)!='.':dirs[parent.as_posix()]+=s.st_size
   except OSError as e:errors.append(dict(path=str(p),error=str(e),bytes=None))
 return dict(accessible_bytes=sum(f['size'] for f in files),file_count=len(files),files=files,directories=dict(dirs.most_common()),errors=errors,reparse=reparse)
def save(name,d):
 OUT.mkdir(parents=True,exist_ok=True);(OUT/name).write_text(json.dumps(d,indent=2),encoding='utf-8')
if __name__=='__main__':
 d=scan();name=sys.argv[1] if len(sys.argv)>1 else 'before'
 OUT.mkdir(parents=True,exist_ok=True)
 with gzip.open(OUT/(name+'-inventory.json.gz'),'wt',encoding='utf-8') as f:json.dump(d,f)
 save(name+'-summary.json',{k:v for k,v in d.items() if k!='files'})
 print(json.dumps(dict(bytes=d['accessible_bytes'],files=d['file_count'],errors=d['errors'],largest_directories=list(d['directories'].items())[:30],largest_files=sorted(d['files'],key=lambda x:x['size'],reverse=True)[:100],largest_logs=sorted([f for f in d['files'] if Path(f['path']).suffix in ['.log','.txt','.out']],key=lambda x:x['size'],reverse=True)[:40]),indent=2))
