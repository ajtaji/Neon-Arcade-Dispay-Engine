"""Focused ASM proof of the UI kit (GlUI, GlUIChrome): the widget gallery's script
played with the mouse and keys and with a pad's actions, in an invisible window
(nothing is shown on the screen), every step checked and the record compared with
tools/ui_check_expected.txt. --write writes that file instead.
Built in the repository's ignored build folder, never the system temp folder."""
from pathlib import Path
import os
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]

def main():
    compiler=os.environ.get('PMF_PBC_ASM')
    if not compiler and os.name=='nt':compiler=str(Path(os.environ['LOCALAPPDATA'])/'Programs/PureBasic/Compilers/pbcompiler.exe')
    if not compiler:raise RuntimeError('Set PMF_PBC_ASM to the ASM compiler')
    td=ROOT/'build'/'ui_check';td.mkdir(parents=True,exist_ok=True)
    exe=td/('check.exe' if os.name=='nt' else 'check')
    flags=['/CONSOLE','/EXE'] if os.name=='nt' else ['-c','-e']
    p=subprocess.run([compiler,str(ROOT/'tools/ui_check.pb'),*flags,str(exe)],capture_output=True,text=True,timeout=120)
    assert p.returncode==0,p.stdout+p.stderr
    args=[str(exe)]
    if '--write' in sys.argv[1:]:args.append('--write')
    args.append(str(ROOT/'tools'/'ui_check_expected.txt'))
    subprocess.run(args,check=True,timeout=120)

if __name__=='__main__':main()
