// Shared helper for endpoints that are defined in the API surface but land in a
// later project. They return 501 Not Implemented with a clear, honest message so
// the iOS team (and Postman) can see the route exists and which project fills it.

import type { Context } from 'hono';
import type { HonoEnv } from '../types.js';

export function notImplemented(endpoint: string, project: number) {
  return (c: Context<HonoEnv>) =>
    c.json(
      {
        error: 'not_implemented',
        message: `${endpoint} is not implemented yet — arrives in Project ${project}.`,
        endpoint,
        project,
      },
      501,
    );
}
