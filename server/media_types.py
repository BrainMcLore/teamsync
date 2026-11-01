"""Bounded container checks; decoding remains the system player's responsibility."""
import struct

MAX_MEDIA = 20 * 1024 * 1024


def valid_mp4(content: bytes) -> bool:
    if not 24 <= len(content) <= MAX_MEDIA:
        return False
    count = 0
    found = set()

    def walk(start, end, depth=0):
        nonlocal count
        offset = start
        while offset < end:
            count += 1
            if count > 2048 or depth > 4 or end-offset < 8:
                raise ValueError('invalid_atom')
            size, atom = struct.unpack_from('>I4s', content, offset)
            header = 8
            if size == 1:
                if end-offset < 16:
                    raise ValueError('invalid_atom')
                size = struct.unpack_from('>Q', content, offset+8)[0]
                header = 16
            elif size == 0:
                size = end-offset
            if size < header or size > end-offset:
                raise ValueError('invalid_atom')
            if depth == 0:
                if offset == 0 and atom == b'ftyp' and size >= 16:
                    found.add('type')
                if atom == b'moov':
                    found.add('movie')
                if atom == b'mdat' and size > header:
                    found.add('data')
            if atom in (b'moov', b'trak', b'mdia'):
                walk(offset+header, offset+size, depth+1)
            if depth == 3 and atom == b'hdlr' and size >= header+12 and content[offset+header+8:offset+header+12] == b'vide':
                found.add('video')
            offset += size
    try:
        walk(0, len(content))
    except (ValueError, struct.error):
        return False
    return found == {'type', 'movie', 'data', 'video'}


def media_type(content: bytes) -> str | None:
    if not content or len(content) > MAX_MEDIA:
        return None
    if content.startswith(b'\x89PNG\r\n\x1a\n'):
        return 'image/png'
    if content.startswith(b'\xff\xd8\xff'):
        return 'image/jpeg'
    return 'video/mp4' if valid_mp4(content) else None
