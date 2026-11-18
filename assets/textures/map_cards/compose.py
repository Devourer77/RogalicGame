from PIL import Image, ImageDraw, ImageFont, ImageFilter
import json
info=json.load(open('frames.json'))
G='/home/claude/rogalicgame/assets/'
font=G+'fonts/AlegreyaSC-Bold.ttf'
BR=(222,180,96); BRD=(90,66,30)
cards=[('battle','gat','map_battle',2,'Старая гать'),('elite','grove','map_elite',3,'Мёртвая роща'),('boss','lair','map_boss',3,'Логово огра'),
       ('spirit','spirit','map_lair',0,'Логово духа'),('event','event','map_event',0,'Событие'),('calm','shop','map_shop',0,'Лавка'),('calm','rest','map_rest',0,'Привал')]
def tint(icon,size,col):
    i=Image.open(G+'icons/'+icon+'.png').resize((size,size),Image.LANCZOS)
    c=Image.new('RGBA',(size,size),col+(255,)); c.putalpha(i.getchannel('A')); return c
TW=380
out=[]
for fname,pic,icon,danger,title in cards:
    fr=Image.open(f'frame_{fname}.png'); inf=info[fname]
    k=TW/fr.size[0]; fr=fr.resize((int(fr.size[0]*k),int(fr.size[1]*k)),Image.LANCZOS)
    S=lambda r:[int(v*k) for v in r]; wr=S(inf['window']); br=S(inf['bar'])
    card=Image.new('RGBA',fr.size,(0,0,0,0))
    p=Image.open(G+f'textures/map_cards/card_{pic}.jpg').convert('RGB')
    ww,wh=wr[2]-wr[0]+6,wr[3]-wr[1]+6
    s=max(ww/p.width,wh/p.height); p=p.resize((int(p.width*s)+1,int(p.height*s)+1),Image.LANCZOS)
    p=p.crop(((p.width-ww)//2,(p.height-wh)//2,(p.width-ww)//2+ww,(p.height-wh)//2+wh))
    card.paste(p,(wr[0]-3,wr[1]-3)); card.alpha_composite(fr)
    d=ImageDraw.Draw(card)
    mt,mb=wr[3],br[1]; isz=int((mb-mt)*0.5); fl=int(isz*0.36) if danger else 0; gap=6 if danger else 0
    y0=mt+((mb-mt)-(isz+gap+fl))//2; cx=(wr[0]+wr[2])//2
    card.alpha_composite(tint(icon,isz,(0,0,0)).filter(ImageFilter.GaussianBlur(2)),(cx-isz//2+2,y0+3))
    card.alpha_composite(tint(icon,isz,BR),(cx-isz//2,y0))
    step=int(fl*1.15)
    for i in range(3 if danger else 0):
        card.alpha_composite(tint('map_danger',fl,BR if i<danger else BRD),(cx-step-fl//2+i*step,y0+isz+gap))
    f=ImageFont.truetype(font,int((br[3]-br[1])*0.7)); ty=(br[1]+br[3])//2
    d.text((cx+1,ty+2),title,font=f,fill=(0,0,0),anchor='mm'); d.text((cx,ty),title,font=f,fill=BR,anchor='mm')
    out.append(card)
H=max(c.height for c in out); W=sum(c.width for c in out)+30*(len(out)+1)
sheet=Image.new('RGB',(W,H+60),(13,17,17)); x=30
for c in out: sheet.paste(c,(x,30+H-c.height),c); x+=c.width+30
sheet.resize((sheet.width*2//3,sheet.height*2//3),Image.LANCZOS).save('/tmp/claude-0/shots/map_cards_framed.png')
