#!/usr/bin/env python3
# 生成 Telesales dmg 背景图:黑板粉笔风,虚线框分区 + 手绘箭头 + 手写标注
#
# 用法(在仓库根目录):  python3 electron/build/gen-bg.py
# 产物:  electron/build/background.png      (600x450,1x)
#        electron/build/background@2x.png   (1200x900,2x,Retina)
# package.json 已通过 "dmg.background": "build/background.png" 引用。
# 改布局只需调整下面 draw_all() 里的坐标 + 重新跑本脚本,然后 git commit 新 png。
# 依赖:Pillow(macOS 自带 STHeiti Light 字体,无需额外字体安装)。

from PIL import Image, ImageDraw, ImageFont
import math, os, random

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_1X = os.path.join(HERE, "background.png")
OUT_2X = os.path.join(HERE, "background@2x.png")

W, H = 600, 450  # window 逻辑尺寸

FONT_CN = "/System/Library/Fonts/STHeiti Light.ttc"
CHALK = (241, 238, 224, 240)        # 粉笔白(略暖)
CHALK_SOFT = (241, 238, 224, 180)   # 半透明粉笔
ACCENT = (255, 183, 77, 245)        # 橙色强调(用于 ①②③)

def lerp(a, b, t):
    return int(round(a + (b - a) * t))

def make_bg(w, h):
    img = Image.new("RGB", (w, h), "#303841")
    px = img.load()
    # 黑板色微渐变(顶亮底略深)
    top = (0x36, 0x3E, 0x47)
    bot = (0x28, 0x30, 0x38)
    for y in range(h):
        t = y / (h - 1)
        c = (lerp(top[0], bot[0], t), lerp(top[1], bot[1], t), lerp(top[2], bot[2], t))
        for x in range(w):
            px[x, y] = c
    return img

def dashed_rounded_rect(draw, xy, r, color, dash=(10, 7), width=2):
    # 沿圆角矩形画虚线
    x0, y0, x1, y1 = xy
    d_on, d_off = dash
    def dline(p1, p2):
        x1_, y1_ = p1; x2_, y2_ = p2
        L = math.hypot(x2_ - x1_, y2_ - y1_)
        if L < 1: return
        dx = (x2_ - x1_) / L; dy = (y2_ - y1_) / L
        t = 0.0
        while t < L:
            a = (x1_ + dx * t, y1_ + dy * t)
            tt = min(t + d_on, L)
            b = (x1_ + dx * tt, y1_ + dy * tt)
            draw.line([a, b], fill=color, width=width)
            t += d_on + d_off
    def darc(bbox, start, end):
        # 用短弧近似画虚线弧
        cx = (bbox[0] + bbox[2]) / 2; cy = (bbox[1] + bbox[3]) / 2
        rr = (bbox[2] - bbox[0]) / 2
        ang = math.radians(end - start)
        L = ang * rr
        n = max(1, int(L / (d_on + d_off)))
        for i in range(n):
            a0 = start + (i * (d_on + d_off) / rr) * (180 / math.pi)
            a1 = start + ((i * (d_on + d_off) + d_on) / rr) * (180 / math.pi)
            if a0 < end:
                draw.arc(bbox, min(a0, end), min(a1, end), fill=color, width=width)
    # 四条直边
    dline((x0 + r, y0), (x1 - r, y0))           # top
    dline((x1, y0 + r), (x1, y1 - r))           # right
    dline((x1 - r, y1), (x0 + r, y1))           # bottom (方向不影响虚线点)
    dline((x0, y1 - r), (x0, y0 + r))           # left
    # 四个圆角
    darc((x1 - 2 * r, y0, x1, y0 + 2 * r), 270, 360)  # 右上
    darc((x1 - 2 * r, y1 - 2 * r, x1, y1), 0, 90)     # 右下
    darc((x0, y1 - 2 * r, x0 + 2 * r, y1), 90, 180)   # 左下
    darc((x0, y0, x0 + 2 * r, y0 + 2 * r), 180, 270)  # 左上

def hand_arrow(draw, p1, p2, color, width=3, head=12, wobble=1.2):
    # 略带抖动的手绘风直线 + 三角箭头
    x1, y1 = p1; x2, y2 = p2
    L = math.hypot(x2 - x1, y2 - y1)
    n = max(8, int(L / 6))
    pts = []
    for i in range(n + 1):
        t = i / n
        x = x1 + (x2 - x1) * t
        y = y1 + (y2 - y1) * t
        # 法线方向小抖动
        nx = -(y2 - y1) / L; ny = (x2 - x1) / L
        off = math.sin(t * math.pi * 3) * wobble + (random.random() - 0.5) * wobble * 0.6
        pts.append((x + nx * off, y + ny * off))
    for i in range(len(pts) - 1):
        draw.line([pts[i], pts[i + 1]], fill=color, width=width)
    # 箭头头
    ang = math.atan2(y2 - y1, x2 - x1)
    a1 = ang + math.radians(150); a2 = ang - math.radians(150)
    h1 = (x2 + math.cos(a1) * head, y2 + math.sin(a1) * head)
    h2 = (x2 + math.cos(a2) * head, y2 + math.sin(a2) * head)
    draw.polygon([(x2, y2), h1, h2], fill=color)

def hand_curve_arrow(draw, p1, p2, ctrl, color, width=3, head=12):
    # 二次贝塞尔手绘曲线 + 箭头
    x1, y1 = p1; cx, cy = ctrl; x2, y2 = p2
    last = None
    n = 50
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        x = u * u * x1 + 2 * u * t * cx + t * t * x2
        y = u * u * y1 + 2 * u * t * cy + t * t * y2
        if last is not None:
            draw.line([last, (x, y)], fill=color, width=width)
        last = (x, y)
    # 方向 = 末端切线
    t = 1.0; u = 0.0
    dx = 2 * u * (cx - x1) + 2 * t * (x2 - cx)
    dy = 2 * u * (cy - y1) + 2 * t * (y2 - cy)
    ang = math.atan2(dy, dx)
    a1 = ang + math.radians(150); a2 = ang - math.radians(150)
    h1 = (x2 + math.cos(a1) * head, y2 + math.sin(a1) * head)
    h2 = (x2 + math.cos(a2) * head, y2 + math.sin(a2) * head)
    draw.polygon([(x2, y2), h1, h2], fill=color)

def chalk_text(draw, xy, text, font, color):
    # 文字 + 轻微"粉笔"质感(半透明描边模糊感)
    draw.text(xy, text, font=font, fill=color)

def draw_all(scale):
    random.seed(7)
    w, h = W * scale, H * scale
    img = make_bg(w, h)
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay, "RGBA")

    def S(v): return int(round(v * scale))

    f_title = ImageFont.truetype(FONT_CN, S(20))
    f_step  = ImageFont.truetype(FONT_CN, S(22))
    f_num   = ImageFont.truetype(FONT_CN, S(34))
    f_tip   = ImageFont.truetype(FONT_CN, S(16))

    # ───── 第 1 步框:包住 Telesales 与 应用程序 ─────
    box1 = (S(40), S(75), S(560), S(258))
    dashed_rounded_rect(d, box1, S(18), CHALK, dash=(S(10), S(7)), width=S(2))
    # 序号 ①(橙)
    d.text((S(54), S(82)), "①", font=f_num, fill=ACCENT)
    # 标注:"先把这个拖进去 →"
    chalk_text(d, (S(220), S(89)), "先把这个拖进去", f_step, CHALK)
    # 手绘箭头:从 Telesales 图标右下 → Applications 图标左下(略带弧度)
    hand_curve_arrow(d,
                     (S(218), S(170)), (S(382), S(170)),
                     ctrl=(S(300), S(192)),
                     color=CHALK, width=S(3), head=S(14))

    # ───── 第 2 步框:包住「双击解锁并打开.command」,紧贴图标避免挤掉文字空隙 ─────
    box2 = (S(70), S(263), S(230), S(408))
    dashed_rounded_rect(d, box2, S(16), CHALK, dash=(S(9), S(6)), width=S(2))
    d.text((S(80), S(270)), "②", font=f_num, fill=ACCENT)
    # 第 2 步标注:严格居中放在 box2 与 txt 图标之间的空隙(x≈230-390)
    # 用 anchor="mm" 中心对齐,确保文字宽度落在空隙内
    f_step2 = ImageFont.truetype(FONT_CN, S(20))
    f_tip2  = ImageFont.truetype(FONT_CN, S(14))
    d.text((S(310), S(300)), "再双击这个",   font=f_step2, fill=CHALK,      anchor="mm")
    d.text((S(310), S(328)), "自动解锁并打开", font=f_tip2,  fill=CHALK_SOFT, anchor="mm")
    # 箭头从标注左下出发,落到 command 图标内部
    hand_arrow(d,
               (S(258), S(322)), (S(198), S(298)),
               color=CHALK, width=S(3), head=S(14))

    # ───── 第 3 步小提示:指向「安装说明」 ─────
    d.text((S(420), S(415)), "③", font=ImageFont.truetype(FONT_CN, S(20)), fill=ACCENT)
    chalk_text(d, (S(448), S(417)), "看不懂?读这个说明", f_tip, CHALK_SOFT)

    out = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
    out.save(OUT_2X if scale == 2 else OUT_1X)
    print("saved", OUT_2X if scale == 2 else OUT_1X, out.size)

if __name__ == "__main__":
    draw_all(1)
    draw_all(2)
