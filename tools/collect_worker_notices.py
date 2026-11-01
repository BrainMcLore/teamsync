from pathlib import Path
import importlib.metadata as metadata
import shutil
import sys

root=Path(__file__).resolve().parents[1]
target=root/'.tools/worker-dist/teamsync-demo/notices'
target.mkdir(parents=True,exist_ok=True)
for name in ['demoparser2','numpy','pandas','pyarrow','polars','polars-runtime-32','rarfile','curl_cffi','cffi','pycparser','certifi']:
    dist=metadata.distribution(name)
    for file in dist.files or []:
        text=str(file).lower()
        path=Path(dist.locate_file(file))
        if path.is_file() and ('license' in text or 'copying' in text) and path.suffix.lower() in ['.txt','.md','']:
            output=target/name/Path(*file.parts[-3:]);output.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(path,output)
license_file=Path(sys.base_prefix)/'LICENSE.txt'
if license_file.exists():shutil.copyfile(license_file,target/'PYTHON-LICENSE.txt')
