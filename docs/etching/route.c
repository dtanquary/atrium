// The router of docs/etching/bake.py: the one slow loop, in C. bake.py builds it with clang when it runs.
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct { int32_t d, n; } Item;
static Item *heap; static long hn;
static void hpush(int32_t d, int32_t n) {
    long i = hn++;
    while (i > 0) { long p = (i - 1) / 2; if (heap[p].d <= d) break; heap[i] = heap[p]; i = p; }
    heap[i].d = d; heap[i].n = n;
}
static Item hpop(void) {
    Item top = heap[0], last = heap[--hn]; long i = 0;
    for (;;) {
        long c = 2 * i + 1; if (c >= hn) break;
        if (c + 1 < hn && heap[c + 1].d < heap[c].d) c++;
        if (last.d <= heap[c].d) break;
        heap[i] = heap[c]; i = c;
    }
    heap[i] = last; return top;
}

static const int DX[8] = {1, 0, -1, 0, 1, -1, -1, 1}, DY[8] = {0, 1, 0, -1, 1, 1, -1, -1};

// One stylus route over a grid of wanted ink, never lifting. tier: 0 bare, 1..K ink, drawn stage by stage (stage s
// wants every tier <= s). The stylus walks to an undrawn neighbour while it has one (straight on first); stuck, it
// finds the cheapest way to the nearest wanted cell: back along lines already drawn (kind 1, no new mark), through
// ink wanted later (kind 0, at 3x) or across bare screen (kind 2, a stray mark, at `bridge`x).
// out/kind: the cell reached at each step and how. Returns the number of steps, or -1 if `cap` is too small.
long route(const uint8_t *tier, int W, int H, int K, int start, int bridge,
           int32_t *out, uint8_t *kind, long cap, uint8_t *drawn) {
    long N = (long)W * H, n = 0;
    int32_t *dist = malloc(N * 4), *prev = malloc(N * 4), *path = malloc(N * 4);
    uint32_t *stamp = calloc(N, 4), sid = 0;
    long cnt[256] = {0};
    for (long i = 0; i < N; i++) cnt[tier[i]]++;
    heap = malloc(sizeof(Item) * (N * 8 + 16));
    int cur = start, lastdir = -1;
    out[n] = cur; kind[n++] = 3;
    if (!drawn[cur]) { drawn[cur] = 1; if (tier[cur]) cnt[tier[cur]]--; }
    for (int s = 1; s <= K; s++) {
        long left = 0; for (int t = 1; t <= s; t++) left += cnt[t];
        while (left > 0) {
            if (n + 4 >= cap) return -1;
            int cx = cur % W, cy = cur / W, best = -1, bestscore = 1 << 30;
            for (int k = 0; k < 8; k++) {
                int x = cx + DX[k], y = cy + DY[k]; if (x < 0 || y < 0 || x >= W || y >= H) continue;
                int c = y * W + x; if (drawn[c] || !tier[c] || tier[c] > s) continue;
                int onward = 0;
                for (int j = 0; j < 8; j++) {
                    int x2 = x + DX[j], y2 = y + DY[j]; if (x2 < 0 || y2 < 0 || x2 >= W || y2 >= H) continue;
                    int c2 = y2 * W + x2; if (c2 != cur && !drawn[c2] && tier[c2] && tier[c2] <= s) onward++;
                }
                int score = (k == lastdir ? 0 : 8) + (k < 4 ? 0 : 2) + onward;
                if (score < bestscore) { bestscore = score; best = k; }
            }
            if (best >= 0) {
                cur = (cy + DY[best]) * W + cx + DX[best]; drawn[cur] = 1; cnt[tier[cur]]--; left--; lastdir = best;
                out[n] = cur; kind[n++] = 0; continue;
            }
            // straight on through a line already drawn, if wanted ink lies just beyond it (a hatch line crossing an outline)
            if (lastdir >= 0) {
                int j = 1, x = cx + DX[lastdir], y = cy + DY[lastdir], hit = 0;
                for (; j <= 3 && x >= 0 && y >= 0 && x < W && y < H; j++, x += DX[lastdir], y += DY[lastdir]) {
                    int c = y * W + x;
                    if (drawn[c]) continue;
                    if (tier[c] && tier[c] <= s) hit = 1;
                    break;
                }
                if (hit) {
                    for (int i = 1; i < j; i++) { cur += DY[lastdir] * W + DX[lastdir]; out[n] = cur; kind[n++] = 1; }
                    cur += DY[lastdir] * W + DX[lastdir]; drawn[cur] = 1; cnt[tier[cur]]--; left--;
                    out[n] = cur; kind[n++] = 0; continue;
                }
            }
            // stuck: cheapest way to the nearest wanted cell
            sid++; hn = 0; dist[cur] = 0; prev[cur] = -1; stamp[cur] = sid; hpush(0, cur);
            int goal = -1;
            while (hn > 0) {
                Item it = hpop(); int c = it.n; if (it.d > dist[c]) continue;
                if (c != cur && !drawn[c] && tier[c] && tier[c] <= s) { goal = c; break; }
                int x0 = c % W, y0 = c / W;
                for (int k = 0; k < 8; k++) {
                    int x = x0 + DX[k], y = y0 + DY[k]; if (x < 0 || y < 0 || x >= W || y >= H) continue;
                    int c2 = y * W + x, step = k < 4 ? 10 : 14;
                    if (drawn[c2]) ;
                    else if (tier[c2]) step *= (tier[c2] <= s ? 1 : 3);
                    else step *= bridge;
                    int32_t d2 = it.d + step;
                    if (stamp[c2] != sid || d2 < dist[c2]) { stamp[c2] = sid; dist[c2] = d2; prev[c2] = c; hpush(d2, c2); }
                }
            }
            if (goal < 0) break;
            long m = 0; for (int c = goal; c != cur; c = prev[c]) path[m++] = c;
            if (n + m + 4 >= cap) return -1;
            int from = cur;
            for (long i = m - 1; i >= 0; i--) {
                int c = path[i];
                if (drawn[c]) kind[n] = 1;
                else { kind[n] = tier[c] ? 0 : 2; drawn[c] = 1; if (tier[c]) { cnt[tier[c]]--; if (tier[c] <= s) left--; } }
                out[n++] = c;
                int ddx = c % W - from % W, ddy = c / W - from / W;
                for (int k = 0; k < 8; k++) if (DX[k] == ddx && DY[k] == ddy) lastdir = k;
                from = c;
            }
            cur = goal;
        }
    }
    free(dist); free(prev); free(path); free(stamp); free(heap);
    return n;
}
