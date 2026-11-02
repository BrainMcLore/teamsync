"""Seed/check only a disposable CI profile for native installer acceptance."""
import argparse
import sqlite3
from pathlib import Path


def main():
    cli = argparse.ArgumentParser()
    cli.add_argument('action', choices=['seed', 'check'])
    cli.add_argument('directory', type=Path)
    cli.add_argument('--schema', type=int)
    args = cli.parse_args()
    database = args.directory / 'teamsync.sqlite'
    marker = args.directory / 'media' / 'installer-acceptance.txt'
    if args.action == 'seed':
        if database.exists():
            raise RuntimeError('Refusing to overwrite an existing user database')
        args.directory.mkdir(parents=True, exist_ok=True)
        with sqlite3.connect(database) as db:
            db.executescript((Path(__file__).resolve().parents[1] / 'client/test/fixtures/schema_v1.sql').read_text())
            db.execute('INSERT INTO settings VALUES(?,?)', ('installer_acceptance', 'preserve-me'))
            db.execute('INSERT INTO teams(id,name,created_at) VALUES(?,?,?)', ('acceptance-team', 'Preserved team', '2026-11-02T00:00:00Z'))
        marker.parent.mkdir(parents=True, exist_ok=True)
        marker.write_text('preserve-media', encoding='utf-8')
    else:
        if not database.is_file():
            raise RuntimeError('Application database was removed')
        with sqlite3.connect(f'{database.as_uri()}?mode=ro', uri=True) as db:
            assert db.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
            assert db.execute('SELECT value FROM settings WHERE key=?', ('installer_acceptance',)).fetchone() == ('preserve-me',)
            assert db.execute('SELECT name FROM teams WHERE id=?', ('acceptance-team',)).fetchone() == ('Preserved team',)
            if args.schema is not None:
                assert db.execute('PRAGMA user_version').fetchone()[0] == args.schema
        assert marker.read_text(encoding='utf-8') == 'preserve-media'
    print(f'Installer data {args.action}: passed')


if __name__ == '__main__':
    main()
