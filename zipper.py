import zipfile
import sys
import glob
import os

file_name = sys.argv[1]
dir_path = sys.argv[2]


with zipfile.ZipFile(f'{os.path.join(dir_path,file_name)}.result.zip', 'w') as f:
    for file in glob.glob(f'{os.path.join(dir_path,file_name)}*.*'):
        if "_unrelaxed_" in file: 
            os.rename(file,file.replace('_unrelaxed_', '_relaxed_'),src_dir_fd=None, dst_dir_fd=None)
        if not ".zip" in file:
            f.write(file.replace('_unrelaxed_', '_relaxed_'))

