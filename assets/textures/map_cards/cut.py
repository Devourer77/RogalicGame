from PIL import Image, ImageFilter
import numpy as np, json
from scipy import ndimage
U='/mnt/user-data/uploads/'
files={'battle':'5eea8393','elite':'57b976ec','boss':'1ba809be','spirit':'9c15d30a','event':'253b21a9','calm':'75176071'}
info={}
for name,id in files.items():
    a=np.asarray(Image.open(U+id+'-image.jpg').convert('RGB')).astype(int)
    bg=np.median(np.concatenate([a[:5].reshape(-1,3),a[-5:].reshape(-1,3)]),axis=0)
    diff=np.abs(a-bg).max(axis=2)
    lab,n=ndimage.label(diff<45)   # фон и серая тень от рамки
    border=set(np.unique(np.concatenate([lab[0],lab[-1],lab[:,0],lab[:,-1]])))-{0}
    bgmask=ndimage.binary_dilation(np.isin(lab,list(border)),iterations=2)
    alpha=np.asarray(Image.fromarray(np.where(bgmask,0,255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7)))
    dark=a.max(axis=2)<22
    dl,dn=ndimage.label(dark)
    sizes=ndimage.sum(dark,dl,range(1,dn+1)); objs=ndimage.find_objects(dl)
    cand=sorted([(sizes[i],objs[i],i+1) for i in range(dn) if sizes[i]>2000],key=lambda t:-t[0])
    win=cand[0]; bar=[c for c in cand[1:] if (c[1][1].stop-c[1][1].start)>3*(c[1][0].stop-c[1][0].start)][0]
    al=alpha.copy(); al[ndimage.binary_dilation(dl==win[2],iterations=1)]=0   # окошко — прозрачное
    fr=Image.fromarray(np.dstack([a.astype(np.uint8),al]),'RGBA'); bb=fr.getbbox(); fr=fr.crop(bb)
    r=lambda o:(o[1].start-bb[0],o[0].start-bb[1],o[1].stop-bb[0],o[0].stop-bb[1])
    fr.save(f'frame_{name}.png'); info[name]={'size':fr.size,'window':r(win[1]),'bar':r(bar[1])}
json.dump(info,open('frames.json','w'),indent=1); print(info)
