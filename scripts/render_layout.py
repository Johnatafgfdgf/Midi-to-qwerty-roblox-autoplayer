"""Render actual App instance bounds from the test model; not a Roblox screenshot."""
import json,sys
from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
for mode in ['Full','Compact','Mini','Hidden']:
 d=json.loads(Path('.tmp/layouts/1280x720-'+mode+'.json').read_text())
 im=Image.new('RGB',(1280,720),'#23352f')
 for o in d['draw']:
  if o['w']<=0 or o['h']<=0:continue
  layer=Image.new('RGBA',im.size);draw=ImageDraw.Draw(layer);x,y,w,h=[o[k]for k in ('x','y','w','h')]
  rgb=tuple(int(c*255)for c in o['bg'])+(int(o['alpha']*255),)
  draw.rounded_rectangle((x,y,x+w,y+h),radius=min(o['radius'],w/2,h/2),fill=rgb)
  if o['text']:
   font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',int(o['fontSize']))
   text=o['text'];lines=[]
   for line in text.split('\n'):
    if not o['wrap']:
     while draw.textlength(line,font=font)>max(0,w-8) and len(line)>1:line=line[:-2]+'…'
     lines.append(line)
    else:
     s=''
     for word in line.split(' '):
      if draw.textlength(s+' '+word,font=font)>w-8 and s:lines.append(s);s=word
      else:s=(s+' '+word).strip()
     lines.append(s)
   ty=y+(h-len(lines)*o['fontSize']*1.2)/2
   for line in lines:
    width=draw.textlength(line,font=font);tx=x+4 if o['align']=='Left'else x+w-width-4 if o['align']=='Right'else x+(w-width)/2
    draw.text((tx,ty),line,font=font,fill=tuple(int(c*255)for c in o['fg'])+(255,));ty+=o['fontSize']*1.2
  clip=o.get('clip')
  if clip:
   cx,cy,cw,ch=clip;region=layer.crop((max(0,int(cx)),max(0,int(cy)),min(1280,int(cx+cw)),min(720,int(cy+ch))));im.paste(region,(max(0,int(cx)),max(0,int(cy))),region)
  else:im.paste(layer,(0,0),layer)
 im.save('.tmp/'+mode+'.png')
