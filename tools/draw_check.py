"""Focused ASM proof of Neon's tile, layer and palette drawing, read back from
an invisible window's render target (nothing is shown on the screen).
Built in the repository's ignored build folder, never the system temp folder."""
from pathlib import Path
import os
import subprocess

ROOT=Path(__file__).resolve().parents[1]

def main():
    compiler=os.environ.get('PMF_PBC_ASM')
    if not compiler and os.name=='nt':compiler=str(Path(os.environ['LOCALAPPDATA'])/'Programs/PureBasic/Compilers/pbcompiler.exe')
    if not compiler:raise RuntimeError('Set PMF_PBC_ASM to the ASM compiler')
    td=ROOT/'build'/'draw_check';td.mkdir(parents=True,exist_ok=True)
    exe=td/('check.exe' if os.name=='nt' else 'check')
    flags=['/CONSOLE','/EXE'] if os.name=='nt' else ['-c','-e']
    p=subprocess.run([compiler,str(ROOT/'tools/draw_check.pb'),*flags,str(exe)],capture_output=True,text=True,timeout=60)
    assert p.returncode==0,p.stdout+p.stderr
    subprocess.run([str(exe)],check=True,timeout=60)

if __name__=='__main__':main()
