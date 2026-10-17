#!/usr/bin/env python3
"""Decode original tiled BIN images. Preserve all other BIN formats as unresolved."""
from pathlib import Path
import json,struct
from decode_anm import payload,sha,require
from cing_container import decompress
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'extracted/unpacked_wpf'
DEST=ROOT/'Sources/HotelDuskDuoKit/Resources/OriginalBitmaps'

class Bitmap:
    def __init__(self,data):
        self.decoded=decompress(data) if data[:3]==bytes.fromhex('123dda') else data
        b=self.decoded
        require(len(b)>=16,'Truncated image header')
        kind,count,self.width,self.height,pixel_bytes,palette_bytes=struct.unpack_from('<4H2I',b)
        require(kind==0 and count in (16,256),'Not a recovered tiled bitmap format')
        require(0<self.width<=1024 and 0<self.height<=1024 and self.width%8==0 and self.height%8==0,'Unrecovered tiled dimensions')
        require(palette_bytes==count*2 and pixel_bytes==self.width*self.height*(1 if count==256 else .5),'Bitmap section sizes')
        require(len(b)==16+palette_bytes+pixel_bytes,'Bitmap payload size')
        self.palette=b[16:16+palette_bytes];self.pixels=b[16+palette_bytes:];self.palette_count=count
        colours=[]
        for p in struct.unpack('<'+'H'*count,self.palette):
            colours.append(bytes([((p>>s&31)<<3)|(p>>s&31)>>2 for s in (0,5,10)]+[255]))
        rgba=bytearray(self.width*self.height*4)
        for y in range(self.height):
            for x in range(self.width):
                tile=(y//8)*(self.width//8)+x//8
                i=tile*64+(y%8)*8+x%8
                colour=self.pixels[i] if count==256 else (self.pixels[i//2]>>(4*(i%2)))&15
                at=(y*self.width+x)*4;rgba[at:at+4]=colours[colour]
        self.rgba=bytes(rgba)

def main():
    records=[]
    for file in sorted(SOURCE.rglob('*.bin')):
        relative=file.relative_to(SOURCE);raw=payload(file);out=DEST/relative;out.parent.mkdir(parents=True,exist_ok=True);out.write_bytes(raw)
        r={'source':str(relative),'payloadSHA256':sha(raw)}
        try:
            b=Bitmap(raw)
            r.update(status='decoded',width=b.width,height=b.height,paletteCount=b.palette_count,decodedSHA256=sha(b.decoded),rgbaSHA256=sha(b.rgba))
        except ValueError as error:r.update(status='unresolved',error=str(error))
        records.append(r)
    count=sum(r['status']=='decoded' for r in records)
    manifest={'formatVersion':1,'coverage':{'files':len(records),'decoded':count,'unresolved':len(records)-count},'images':records}
    (DEST/'OriginalBitmapManifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(manifest['coverage'])
if __name__=='__main__':main()
