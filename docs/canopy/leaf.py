# How alike neighbouring blocks of a film move, at a leaf's scale: phase correlation of B px blocks (no overlap) between
# frames `step` apart, over a crop at the film's own size, then the correlation of the motion of blocks 1, 2, 4 and 8
# blocks apart (textured blocks only), and how much of a block's motion is its own (not its 4 neighbours' mean).
#   python3 -I leaf.py film.mp4 x y w h [step=4] [B=16] [frames=240] [scale=1]
import sys, subprocess, json, numpy as np
path = sys.argv[1]; x, y, w, h = map(int, sys.argv[2:6])
step = int(sys.argv[6]) if len(sys.argv) > 6 else 4
B = int(sys.argv[7]) if len(sys.argv) > 7 else 16
frames = int(sys.argv[8]) if len(sys.argv) > 8 else 240
scale = float(sys.argv[9]) if len(sys.argv) > 9 else 1.0
vf = f'crop={w}:{h}:{x}:{y}' + (f',scale={int(w*scale)}:{int(h*scale)}:flags=bicubic' if scale != 1 else '')
W, H = (int(w * scale), int(h * scale)) if scale != 1 else (w, h)
raw = subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', path, '-vf', vf, '-pix_fmt', 'gray', '-f', 'rawvideo',
                      '-frames:v', str(frames), '-'], capture_output=True).stdout
f = np.frombuffer(raw, np.uint8).reshape(-1, H, W).astype(np.float32)
T = len(f); ny, nx = H // B, W // B
win = np.outer(np.hanning(B), np.hanning(B)).astype(np.float32)
def spec(img):
    b = img[:ny * B, :nx * B].reshape(ny, B, nx, B).transpose(0, 2, 1, 3)
    return np.fft.fft2((b - b.mean(axis=(2, 3), keepdims=True)) * win), b.std(axis=(2, 3))
def pc(fa, fb):
    R = fb * np.conj(fa); R /= np.abs(R) + 1e-3
    r = np.fft.ifft2(R).real.reshape(ny * nx, B, B); n = np.arange(ny * nx)
    i = r.reshape(len(n), -1).argmax(1); iy, ix = i // B, i % B; peak = r[n, iy, ix]
    def sub(m, p, c):
        d = m - 2 * c + p; return np.where(np.abs(d) > 1e-9, 0.5 * (m - p) / d, 0)
    dy = iy + sub(r[n, (iy - 1) % B, ix], r[n, (iy + 1) % B, ix], peak)
    dx = ix + sub(r[n, iy, (ix - 1) % B], r[n, iy, (ix + 1) % B], peak)
    dy = (dy + B / 2) % B - B / 2; dx = (dx + B / 2) % B - B / 2
    return dx.reshape(ny, nx), dy.reshape(ny, nx), peak.reshape(ny, nx)
S = [spec(g) for g in f]
tex = np.median([s[1] for s in S[::10]], axis=0)
ok0 = tex > np.percentile(tex, 40)  # the textured blocks: leaves and twigs, not open sky or solid shade
U, V, OK = [], [], []
for t in range(0, T - step, max(1, step // 2)):
    dx, dy, pk = pc(S[t][0], S[t + step][0])
    U.append(dx); V.append(dy); OK.append(ok0 & (pk > 0.15) & (np.hypot(dx, dy) < B / 3))
U, V, OK = np.array(U), np.array(V), np.array(OK)
out = {'frames': T, 'blocks': int(ok0.sum()), 'matched': float(OK.mean() / max(ok0.mean(), 1e-9)), 'rms_px': float(np.sqrt((U[OK] ** 2 + V[OK] ** 2).mean()))}
def corr(k, axis):
    a = [slice(None)] * 3; b = [slice(None)] * 3
    a[axis] = slice(0, -k); b[axis] = slice(k, None); a, b = tuple(a), tuple(b)
    m = OK[a] & OK[b]
    num = (U[a] * U[b] + V[a] * V[b])[m].sum()
    return num / np.sqrt((U[a] ** 2 + V[a] ** 2)[m].sum() * (U[b] ** 2 + V[b] ** 2)[m].sum())
for k in (1, 2, 4, 8):
    out[f'alike_{k * B}px'] = float((corr(k, 1) + corr(k, 2)) / 2)
# a block's own motion: what is left after the mean of its 4 neighbours (where all 5 match)
m = OK[:, 1:-1, 1:-1] & OK[:, :-2, 1:-1] & OK[:, 2:, 1:-1] & OK[:, 1:-1, :-2] & OK[:, 1:-1, 2:]
def own(A):
    return (A[:, 1:-1, 1:-1] - (A[:, :-2, 1:-1] + A[:, 2:, 1:-1] + A[:, 1:-1, :-2] + A[:, 1:-1, 2:]) / 4)[m]
out['own_share'] = float(np.sqrt((own(U) ** 2 + own(V) ** 2).mean() / (U[:, 1:-1, 1:-1][m] ** 2 + V[:, 1:-1, 1:-1][m] ** 2).mean()))
# the light: how much a block's mean brightness changes in `step` frames, against its own texture
mean = np.array([g[:ny * B, :nx * B].reshape(ny, B, nx, B).mean(axis=(1, 3)) for g in f])
out['light_change'] = float(np.abs(mean[step:] - mean[:-step])[:, ok0].mean())
print(json.dumps({k: (round(v, 3) if isinstance(v, float) else v) for k, v in out.items()}))
