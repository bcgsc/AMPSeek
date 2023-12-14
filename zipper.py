import zipfile
import sys
import glob
import os

file_name = sys.argv[1]
dir_path = sys.argv[2]

with zipfile.ZipFile(f'{os.path.join(dir_path,file_name)}.result.zip', 'w') as f:
    for file in glob.glob(f'{os.path.join(dir_path,file_name)}*.*'):
        if not ".zip" in file:
            f.write(file)
        