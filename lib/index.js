// dsh-offensive bundle entry.
//
// Why a JS entry instead of YAML paths: bundle patch layers are merged into
// the profile's root include tree, so `baseUrl` inside a bundle patch
// resolves against the PROFILE directory, not this package. The only
// location-independent anchor for bundle-internal files is import.meta.url —
// hence every path below is resolved from this module's own location.

import { resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import * as HooksBridge from '@deepseek-ai/dsh-hooks-claude-code'

export const name = 'dsh-offensive'
export const inject = ['agentPresets']

/** Register the bundled preset root and hooks for the lifetime of this component. */
export async function* apply(ctx) {
  const modesRoot = new URL('../modes/', import.meta.url)
  const modeRoot = new URL('offensive/', modesRoot)

  // 1. Claude Code hook bridge: SessionStart / SubagentStart dispatcher hooks.
  //    Mounted as a child plugin with absolute, bundle-internal paths.
  ctx.plugin(HooksBridge, {
    configPath: fileURLToPath(new URL('hooks/hooks.json', modeRoot)),
    pluginRoot: fileURLToPath(modeRoot),
  })

  // 2. Preset registration: this host (DSH 0.1.5) discovers presets through
  //    `resolvedRoots`; there is no `register()` declaration API here.
  //    Unshift so the bundle wins id collisions against the user root
  //    (~/.dsh/.agent-presets), and splice on dispose for a clean uninstall.
  const presets = ctx.get('agentPresets')
  if (!presets || !Array.isArray(presets.resolvedRoots)) {
    throw new Error('dsh-offensive: unsupported agentPresets API (expected resolvedRoots)')
  }
  const roots = presets.resolvedRoots
  const path = fileURLToPath(modesRoot)
  if (!roots_has(roots, path)) {
    const entry = { path, trust: 'system' }
    roots.unshift(entry)
    yield () => {
      const index = roots.indexOf(entry)
      if (index !== -1) roots.splice(index, 1)
    }
  }
}

function roots_has(roots, path) {
  return roots.some((entry) => typeof entry.path === 'string' && resolve(entry.path) === resolve(path))
}
