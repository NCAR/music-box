#!/usr/bin/env python
"""
Loads a music-box v1 config, solves it, and prints the result as JSON to
stdout. Lets a JS test solve a config with the Python/native backend by
running this as a subprocess (see cross_language.test.js).

Usage: python cross_language_solve.py <config_path>
"""

import json
import sys

from acom_music_box import MusicBox


def main():
    if len(sys.argv) != 2:
        print('Usage: python cross_language_solve.py <config_path>', file=sys.stderr)
        sys.exit(1)

    config_path = sys.argv[1]
    box = MusicBox()
    box.loadJson(config_path)
    df = box.solve()

    result = {
        'columns': df.columns.tolist(),
        'height': len(df),
        'data': {column: df[column].tolist() for column in df.columns},
    }
    json.dump(result, sys.stdout)


if __name__ == '__main__':
    main()
