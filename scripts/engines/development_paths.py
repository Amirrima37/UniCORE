"""Process-local UniCORE development locations; no global environment changes."""
import os
from pathlib import Path
PROJECT_ROOT=Path(os.environ.get('UNICORE_DEVELOPMENT_ROOT','D:/PROJECT'))
def sdk_root():return Path(os.environ.get('UNICORE_OCCT_SDK_ROOT',str(PROJECT_ROOT/'SDK/OCCT')))
def godot_environment_root():return Path(os.environ.get('UNICORE_GODOT_ENV_ROOT',str(PROJECT_ROOT/'GODOT/TEST_ENVIRONMENTS/godot472-migration')))
def test_output_root():return Path(os.environ.get('UNICORE_TEST_OUTPUT_ROOT',str(PROJECT_ROOT/'TEST_OUTPUTS')))
def output_dir(name):
    p=test_output_root()/name;p.mkdir(parents=True,exist_ok=True);return p
if __name__=='__main__':
    import sys
    print({'sdk':sdk_root,'godot':godot_environment_root,'tests':test_output_root}[sys.argv[1]]())
