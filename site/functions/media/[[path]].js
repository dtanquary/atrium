// Pages serves a static file whole, with a 200, even when asked for a byte range, and Safari (Mac, iPhone, iPad)
// won't play video from a server like that. This answers ranges from the whole file, for everything in /media.
// ponytail: one Function call per range request, fine at a hobby site's traffic. Past the free tier, cache /media
// at the edge with a Cache Rule on atrium.show, or serve it from R2, which answers ranges itself.

/** The [start, end] bytes a Range header asks for, null to send the whole file, or 'unsatisfiable'. */
export function byteRange(header, size) {
  const m = /^bytes=(\d*)-(\d*)$/.exec(header ?? '');
  if (!m || (m[1] === '' && m[2] === '')) return null; // none, several ranges, or nonsense: the whole file is allowed
  const [start, end] = m[1] === ''
    ? [Math.max(0, size - +m[2]), size - 1] // the last n bytes
    : [+m[1], m[2] === '' ? size - 1 : Math.min(+m[2], size - 1)];
  return start >= size || start > end ? 'unsatisfiable' : [start, end];
}

export async function onRequestGet({ request, env }) {
  const res = await env.ASSETS.fetch(request.url);
  if (!res.ok) return res;
  const headers = new Headers(res.headers);
  headers.set('Accept-Ranges', 'bytes');
  const body = await res.arrayBuffer();
  const range = byteRange(request.headers.get('Range'), body.byteLength);
  if (range === null) return new Response(body, { headers });
  if (range === 'unsatisfiable') return new Response(null, { status: 416, headers: { 'Content-Range': `bytes */${body.byteLength}` } });
  const [start, end] = range;
  headers.set('Content-Range', `bytes ${start}-${end}/${body.byteLength}`);
  headers.set('Content-Length', String(end - start + 1));
  return new Response(body.slice(start, end + 1), { status: 206, headers });
}
