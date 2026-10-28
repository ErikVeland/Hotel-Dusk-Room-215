#!/usr/bin/env python3
"""Audit original story process references against native host handlers.

A handler is an implementation entry, not evidence of full fidelity or an
uninterrupted route. This report never treats missing handlers as successes.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import struct
from collections import defaultdict
from cing_container import decode_member
from recover_original_logic import parse_blocks

ROOT = Path(__file__).resolve().parents[1]


def audit():
    scripts = ROOT / 'Sources/HotelDuskDuoKit/Resources/Original/Scripts'
    manifest = json.loads((scripts / 'manifest.json').read_text())
    host = (ROOT / 'Sources/HotelDuskDuoKit/Engine/OriginalPlaySession.swift').read_text()
    settle = host.split('private func settle()', 1)[1].split('private func applyAudioControls', 1)[0]
    handlers = {int(value) for match in re.findall(r'\.process\((\d+)\)|id == (\d+)', settle)
                for value in match if value}
    unsupported = {int(process) for process in re.findall(
        r'case \.process\((\d+)\):\s*runner\.halt\(', settle)}
    references = defaultdict(list)
    modes = defaultdict(int)
    chapters = defaultdict(set)
    for file in manifest['files']:
        name = file['name']
        match = re.fullmatch(r'EP(\d+)_.*\.blk', name)
        if not match:
            continue
        raw = (scripts / name).read_bytes()
        if hashlib.sha256(raw).hexdigest() != file['sha256']:
            raise ValueError(f'Checksum mismatch: {name}')
        decoded = decode_member(raw)
        if file.get('decodedSHA256') and hashlib.sha256(decoded).hexdigest() != file['decodedSHA256']:
            raise ValueError(f'Decoded checksum mismatch: {name}')
        graph = parse_blocks(decoded)
        chapter = int(match[1])
        for event in graph['tables'][2]['records']:
            data = bytes.fromhex(event['hex'])
            mode = struct.unpack_from('<H', data)[0]
            modes[mode] += 1
            if mode != 15:
                continue
            process = data[16] + 23
            chapters[chapter].add(process)
            references[process].append({'program': name[:-4], 'event': event['index'],
                                       'sourceOffset': event['byteOffset']})
    processes = [{'processID': process, 'hasNativeHandler': process in handlers,
                  'explicitlyUnsupported': process in unsupported,
                  'references': events} for process, events in sorted(references.items())]
    return {'schemaVersion': 1, 'romSHA256': manifest['romSHA256'],
            'scope': 'Static story process coverage checks handler IDs only. It does not establish factory-resource matching, route completion, presentation fidelity, input fidelity, or optional inventory processes.',
            'nativeHostProcessIDs': sorted(handlers), 'processes': processes,
            'chapters': [{'chapter': chapter, 'requiredProcesses': sorted(ids),
                          'missingProcesses': sorted(ids - handlers),
                          'unsupportedProcesses': sorted(ids & unsupported)}
                         for chapter, ids in sorted(chapters.items())],
            'eventModeCounts': {str(k): v for k, v in sorted(modes.items())}}


def markdown(report):
    required = report['processes']
    missing = [p for p in required if not p['hasNativeHandler']]
    lines = ['# Story process coverage', '', report['scope'], '',
             f"The original chapter scripts reference {len(required)} distinct embedded processes. "
             f"{len(missing)} still have no native host handler.", '',
             '| Chapter | Required process IDs | Missing handlers | Explicitly unsupported |',
             '| --- | --- | --- | --- |']
    for chapter in report['chapters']:
        ids = lambda values: ', '.join(map(str, values)) or 'None'
        lines.append(f"| {chapter['chapter']} | {ids(chapter['requiredProcesses'])} | "
                     f"{ids(chapter['missingProcesses'])} | {ids(chapter['unsupportedProcesses'])} |")
    lines += ['', '## Missing handlers', '', '| Process | Original references |', '| --- | --- |']
    for process in missing:
        refs = ', '.join(f"{r['program']} event {r['event']}" for r in process['references'])
        lines.append(f"| {process['processID']} | {refs} |")
    unsupported = [p for p in required if p['explicitlyUnsupported']]
    lines += ['', '## Explicitly unsupported processes', '', '| Process | Original references |', '| --- | --- |']
    for process in unsupported:
        refs = ', '.join(f"{r['program']} event {r['event']}" for r in process['references'])
        lines.append(f"| {process['processID']} | {refs} |")
    lines += ['', 'Regenerate with `python3 tools/audit_story_coverage.py`.',
              'Unknown process outcomes must remain blocked. A fabricated success result would bypass the original puzzle and its state changes.', '']
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'docs/story-process-coverage.json')
    parser.add_argument('--markdown', type=Path, default=ROOT / 'docs/story-process-coverage.md')
    args = parser.parse_args()
    result = audit()
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    args.markdown.write_text(markdown(result))
    print(f"Audited {len(result['processes'])} story processes across {len(result['chapters'])} chapters.")


if __name__ == '__main__':
    main()
