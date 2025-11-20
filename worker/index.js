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

    // Route: GET /metadata - Get metadata for all groups
    if (url.pathname === '/metadata' && request.method === 'GET') {
      const metadata = await env.SECRETS.get('secrets:metadata');
      if (!metadata) {
        return new Response('{}', {
          headers: { 'Content-Type': 'application/json' }
        });
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
        // Get existing metadata
        const metadataStr = await env.SECRETS.get('secrets:metadata') || '{}';
        const allMetadata = JSON.parse(metadataStr);

        // Update this group's metadata
        allMetadata[group] = {
          files: JSON.parse(filesHeader),
          size: sizeHeader,
          uploaded: new Date().toISOString()
        };

        // Store updated metadata
        await env.SECRETS.put('secrets:metadata', JSON.stringify(allMetadata));
      }

      await env.SECRETS.put(key, data);
      return new Response(`Stored: ${group}`, {
        headers: { 'Content-Type': 'text/plain' }
      });
    }

    // DELETE - Remove secrets for a group
    if (request.method === 'DELETE') {
      await env.SECRETS.delete(key);

      // Remove from metadata
      const metadataStr = await env.SECRETS.get('secrets:metadata');
      if (metadataStr) {
        const allMetadata = JSON.parse(metadataStr);
        delete allMetadata[group];
        await env.SECRETS.put('secrets:metadata', JSON.stringify(allMetadata));
      }

      return new Response(`Deleted: ${group}`, {
        headers: { 'Content-Type': 'text/plain' }
      });
    }

    return new Response('Method not allowed', { status: 405 });
  }
};
