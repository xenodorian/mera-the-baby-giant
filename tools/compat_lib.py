from PIL import Image
import glob,re,os,colorsys
A='/workspace/assets_survey'
G=f'{A}/ansimuz/Legacy Collection/Legacy Collection/Assets/Gothicvania/Characters'
FK=f'{A}/chierit/Elementals_fire_knight_FREE_v1.1/Elementals_fire_knight_FREE_v1.1/png/fire_knight'
WP=f'{A}/chierit/Elementals_water_priestess_FREE_v1.1/Elementals_water_priestess_FREE_v1.1/png'
LR=f'{A}/chierit/Elementals_Leaf_ranger_Free_v1.0/Elementals_Leaf_ranger_Free_v1.0/animations/PNG'
BG_=f'{A}/recolor/Brawler-Girl-skin'
def nat(s): return [int(t) if t.isdigit() else t.lower() for t in re.split(r'(\d+)',s)]
def folder(d): return [Image.open(p).convert('RGBA') for p in sorted(glob.glob(d+'/*.png'),key=nat)]
CH={ # name: (pack, idle dir, attack dir)
 'Fire Knight':('chierit',f'{FK}/01_idle',f'{FK}/05_1_atk'),
 'Water Priestess':('chierit',f'{WP}/01_idle',f'{WP}/08_2_atk'),
 'Leaf Ranger':('chierit',f'{LR}/idle',f'{LR}/1_atk'),
 'Brawler Girl (recolor)':('ansimuz',f'{BG_}/Idle',f'{BG_}/Kick'),
 'Terrible Knight':('ansimuz',f'{G}/Terrible Knight/Sprites/Idle',f'{G}/Terrible Knight/Sprites/SwordSlash'),
 'Ogre':('ansimuz',f'{G}/Ogre/Sprites/Idle',f'{G}/Ogre/Sprites/Attack'),
 'Demon':('ansimuz',f'{G}/demon-Files/Sprites/Idle',f'{G}/demon-Files/Sprites/DemonAttack'),
 'WereWolf':('ansimuz',f'{G}/WereWolf/Sprites/Idle',None),
 'Hell Hound':('ansimuz',f'{G}/Hell-Hound-Files/Sprites/Idle',None),
 'Hell Beast':('ansimuz',f'{G}/Hell-Beast-Files/Idle/Sprites',None),
 'Mutant Toad':('ansimuz',f'{G}/mutant-toad/Sprites/idle',f'{G}/mutant-toad/Sprites/attack'),
}
def ubox(fr):
    b=[f.getbbox() for f in fr if f.getbbox()]
    return (min(x[0] for x in b),min(x[1] for x in b),max(x[2] for x in b),max(x[3] for x in b))
