"""Repackage the exact Godot runtime resources in a signed Android APK as a PCK.
Read-only on inputs. Excludes the Android command-line entry and its sparse PCK index.
"""
import argparse, hashlib, json, pathlib, shutil, struct, zipfile

header_struct=struct.Struct("<4s5I2Q")
entry_struct=struct.Struct("<QQ16sI")
base=112; alignment=16
skip={"_cl_","assets.sparsepck"}

def runtime_entries(z):
    index={}
    for row in z.infolist():
        if not row.filename.startswith("assets/") or row.is_dir():
            continue
        path=row.filename[7:]
        if path in skip:
            continue
        if not path or any(x in ["",".",".."] for x in path.split("/")) or "\\" in path or path in index:
            raise ValueError(f"Invalid APK asset path: {path}")
        index[path]=row
    if len(index)<100 or not {"project.binary",".godot/uid_cache.bin"}.issubset(index.keys()):
        raise ValueError("Expected native Godot runtime assets missing")
    return index

def sha(path):
    with path.open("rb") as f: return hashlib.file_digest(f,"sha256").hexdigest()

def pad(f):
    n=-f.tell()%alignment
    if n: f.write(bytes(n))

def make(apk, target, pin, baseline, anchor, commit, runtime):
    if any(p.exists() for p in [target,pin]):
        raise ValueError("Refusing to overwrite existing baseline evidence.")
    with zipfile.ZipFile(apk) as z:
        index=runtime_entries(z); rows={}
        with target.open("xb") as f:
            f.write(bytes(base))
            for name,row in sorted(index.items()):
                pad(f)
                pos=f.tell()-base
                md5=hashlib.md5()
                with z.open(row) as src:
                    while chunk:=src.read(1<<20):
                        md5.update(chunk); f.write(chunk)
                rows[name]=(pos,row.file_size,md5.digest(),0)
                if f.tell()!=pos+base+row.file_size:
                    raise ValueError(f"Length mismatch: {name}")
            pad(f); table=f.tell()
            f.write(struct.pack("<I",len(rows)))
            for path,encoded in rows.items():
                p=path.encode("utf8")
                p+=b"\0"*(-len(p)%4)
                f.write(struct.pack("<I",len(p)));f.write(p);f.write(entry_struct.pack(*encoded))
            f.seek(0)
            f.write(header_struct.pack(b"GDPC",3,4,5,1,2,base,table))
        compare(apk,target)
    report=dict(base=baseline,base_commit=anchor,build_commit=commit,runtime=runtime,reference_file=target.name,reference_size=target.stat().st_size,reference_sha256=sha(target),apk_file=apk.name,apk_size=apk.stat().st_size,apk_sha256=sha(apk),resource_count=len(rows),apk_reference_every_payload_exact=True)
    pin.write_text(json.dumps(report,indent=2)+"\n",encoding="utf8")
    print(json.dumps(report,indent=2))

def compare(apk,target):
    with target.open("rb") as f, zipfile.ZipFile(apk) as z:
        magic,v,major,minor,patch,flags,base,table=header_struct.unpack(f.read(header_struct.size))
        if (magic,v,major,minor,patch,flags)!=(b"GDPC",3,4,5,1,2): raise ValueError("Unexpected PCK")
        f.seek(table); count=struct.unpack("<I",f.read(4))[0]
        paths={}
        for _ in range(count):
            n=struct.unpack("<I",f.read(4))[0]
            path=f.read(n).rstrip(b"\0").decode().removeprefix("res://")
            paths[path]=entry_struct.unpack(f.read(entry_struct.size))
        index=runtime_entries(z)
        if paths.keys()!=index.keys(): raise ValueError(f"Path mismatch: {sorted(paths.keys()^index.keys())[:15]}")
        for name,row in index.items():
            pos,size,md5,entry_flags=paths[name]
            if pos<0 or size!=row.file_size or entry_flags!=0 or base+pos+size>table:
                raise ValueError(f"Inconsistent PCK entry: {name}")
            f.seek(base+pos); thought=hashlib.md5()
            with z.open(row) as src:
                while chunk:=src.read(1<<20):
                    if f.read(len(chunk))!=chunk: raise ValueError(f"Payload mismatch: {name}")
                    thought.update(chunk)
            if thought.digest()!=md5: raise ValueError(f"Digest mismatch: {name}")
        print(f"{count} exact APK resource payloads")

if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("apk",type=pathlib.Path);p.add_argument("reference",type=pathlib.Path)
    p.add_argument("--pin",type=pathlib.Path);p.add_argument("--base");p.add_argument("--anchor");p.add_argument("--commit");p.add_argument("--runtime",default="godot-4.5.1-android-pck-4")
    a=p.parse_args()
    if a.pin:
        if not all((a.base,a.anchor,a.commit)): p.error("--pin requires --base, --anchor and --commit")
        make(a.apk,a.reference,a.pin,a.base,a.anchor,a.commit,a.runtime)
    else: compare(a.apk,a.reference)

