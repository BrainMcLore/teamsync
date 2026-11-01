"""Generate TeamSync's code-native app mark at native platform sizes."""
from pathlib import Path
from PIL import Image, ImageDraw
import json

root=Path(__file__).resolve().parents[1]
def icon(size):
    image=Image.new('RGB',(1024,1024),'#101417')
    draw=ImageDraw.Draw(image)
    draw.rounded_rectangle((100,100,924,924),radius=200,fill='#192822')
    draw.line([(280,330),(744,330)],fill='#81c8b2',width=100)
    draw.line([(512,330),(512,730)],fill='#81c8b2',width=100)
    draw.ellipse((438,656,586,804),fill='#e9eef2')
    return image.resize((size,size),Image.Resampling.LANCZOS)

icon(256).save(root/'client/windows/runner/resources/app_icon.ico',sizes=[(16,16),(32,32),(48,48),(64,64),(128,128),(256,256)])
for folder,size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    icon(size).save(root/f'client/android/app/src/main/res/mipmap-{folder}/ic_launcher.png')
catalog=root/'client/ios/Runner/Assets.xcassets/AppIcon.appiconset'
for entry in json.loads((catalog/'Contents.json').read_text())['images']:
    if 'filename' in entry:
        size=round(float(entry['size'].split('x')[0])*float(entry['scale'].rstrip('x')))
        icon(size).save(catalog/entry['filename'])
icon(512).save(root/'artifacts/app-icon.png')
