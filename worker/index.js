/**
 * Secrets Storage Worker
 *
 * Provides secure storage for encrypted secrets with named group support.
 * Authenticates via Bearer token and stores data in Cloudflare KV.
 */

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const auth = request.headers.get('Authorization');

    // Check authentication
    if (auth !== `Bearer ${env.SECRET_PASSPHRASE}`) {
      return new Response('Unauthorized', {
        status: 401,
        headers: { 'Content-Type': 'text/plain' }
      });
    }

    // Route: GET /list - List all available groups
    if (url.pathname === '/list' && request.method === 'GET') {
      const list = await env.SECRETS.list({ prefix: 'secrets:' });
      const groups = list.keys
        .filter(k => !k.name.endsWith(':meta'))
        .map(k => k.name.replace('secrets:', ''));
      return new Response(JSON.stringify(groups), {
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // Route: GET /metadata/:group - Get metadata for a group
    const metaMatch = url.pathname.match(/^\/metadata(?:\/([^\/]+))?$/);
    if (metaMatch && request.method === 'GET') {
      const group = metaMatch[1] || 'default';
      const metaKey = `secrets:${group}:meta`;
      const metadata = await env.SECRETS.get(metaKey);

      if (!metadata) {
        return new Response('Not found', { status: 404 });
      }

      return new Response(metadata, {
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // Route: /secrets/:group - CRUD operations on secret groups
    const pathMatch = url.pathname.match(/^\/secrets(?:\/([^\/]+))?$/);
    if (!pathMatch) {
      return new Response('Not found', { status: 404 });
    }

    const group = pathMatch[1] || 'default';
    const key = `secrets:${group}`;
    const metaKey = `secrets:${group}:meta`;

    // GET - Retrieve secrets for a group
    if (request.method === 'GET') {
      const data = await env.SECRETS.get(key);
      if (!data) {
        return new Response('Not found', { status: 404 });
      }
      return new Response(data, {
        headers: { 'Content-Type': 'application/octet-stream' }
      });
    }

    // POST - Store secrets for a group
    if (request.method === 'POST') {
      const data = await request.text();

      // Extract metadata from request headers
      const filesHeader = request.headers.get('X-Files');
      const sizeHeader = request.headers.get('X-Size');

      if (filesHeader && sizeHeader) {
        const metadata = {
          files: JSON.parse(filesHeader),
          size: sizeHeader,
          uploaded: new Date().toISOString()
        };
        await env.SECRETS.put(metaKey, JSON.stringify(metadata));
      }

      await env.SECRETS.put(key, data);
      return new Response(`Stored: ${group}`, {
        headers: { 'Content-Type': 'text/plain' }
      });
    }

    // DELETE - Remove secrets for a group
    if (request.method === 'DELETE') {
      await env.SECRETS.delete(key);
      await env.SECRETS.delete(metaKey);
      return new Response(`Deleted: ${group}`, {
        headers: { 'Content-Type': 'text/plain' }
      });
    }

    return new Response('Method not allowed', { status: 405 });
  }
};
