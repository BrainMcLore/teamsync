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


def valid_evidence_image(content: bytes) -> bool:
    """Bound image containers and dimensions; full decoding stays on the client."""
    import zlib
    if len(content) > MAX_MEDIA:
        return False
    if content.startswith(b'\x89PNG\r\n\x1a\n'):
        pos, count, image_data = 8, 0, False
        while pos+12 <= len(content):
            size = int.from_bytes(content[pos:pos+4], 'big')
            end = pos+12+size
            if end > len(content) or count > 4096:
                return False
            kind = content[pos+4:pos+8]
            data = content[pos+8:pos+8+size]
            if zlib.crc32(kind+data) != int.from_bytes(content[pos+8+size:end], 'big'):
                return False
            if count == 0:
                if kind != b'IHDR' or size != 13:
                    return False
                width, height = struct.unpack_from('>II', data)
                if not (1 <= width <= 8192 and 1 <= height <= 8192):
                    return False
            elif kind == b'IHDR':
                return False
            if kind == b'IDAT' and size:
                image_data = True
            if kind == b'IEND':
                return size == 0 and end == len(content) and image_data
            pos, count = end, count+1
        return False
    if not content.startswith(b'\xff\xd8') or not content.endswith(b'\xff\xd9'):
        return False
    pos, dimensions = 2, False
    while pos+4 <= len(content):
        if content[pos] != 255:
            return False
        while pos < len(content) and content[pos] == 255:
            pos += 1
        if pos >= len(content):
            return False
        marker = content[pos]
        pos += 1
        if marker == 0xDA:
            return dimensions and pos+2 <= len(content) and 2 <= int.from_bytes(content[pos:pos+2], 'big') <= len(content)-pos
        if marker in (0xD8, 0xD9, 0x00) or 0xD0 <= marker <= 0xD7:
            return False
        if pos+2 > len(content):
            return False
        size = int.from_bytes(content[pos:pos+2], 'big')
        if size < 2 or pos+size > len(content):
            return False
        if marker in (0xC0, 0xC1, 0xC2):
            if size < 8:
                return False
            height, width = struct.unpack_from('>HH', content, pos+3)
            dimensions = 1 <= width <= 8192 and 1 <= height <= 8192
            if not dimensions:
                return False
        pos += size
    return False
