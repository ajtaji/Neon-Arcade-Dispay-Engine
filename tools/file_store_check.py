"""Focused ASM proof of Neon's durable file store; no window."""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]

def main():
    compiler=os.environ.get('PMF_PBC_ASM')
    if not compiler and os.name=='nt':compiler=str(Path(os.environ['LOCALAPPDATA'])/'Programs/PureBasic/Compilers/pbcompiler.exe')
    if not compiler:raise RuntimeError('Set PMF_PBC_ASM to the ASM compiler')
    with tempfile.TemporaryDirectory(prefix='neon file store ') as tmp:
        td=Path(tmp);exe=td/('check.exe' if os.name=='nt' else 'check')
        flags=['/CONSOLE','/EXE'] if os.name=='nt' else ['-c','-e']
        p=subprocess.run([compiler,str(ROOT/'tools/file_store_check.pb'),*flags,str(exe)],capture_output=True,text=True,timeout=30)
        assert p.returncode==0,p.stdout+p.stderr
        subprocess.run([str(exe),str(td/'image.bin')],check=True,timeout=10)

if __name__=='__main__':main()
