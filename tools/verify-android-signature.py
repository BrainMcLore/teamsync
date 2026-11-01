"""Check an already cryptographically verified apksigner report's public cert."""
import argparse
from pathlib import Path
from release_utils import verify_android_certificate

cli = argparse.ArgumentParser()
cli.add_argument('report', type=Path)
cli.add_argument('--certificate', required=True, type=Path)
args = cli.parse_args()
if not verify_android_certificate(args.report.read_text(encoding='utf-8'),
                                  args.certificate.read_text(encoding='ascii').strip()):
    cli.error('Unexpected or missing Android signing certificate')
print('Android signing certificate verified.')
