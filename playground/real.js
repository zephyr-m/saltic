/**
 * ReaL.js — JTML Interpreter v0.1
 * JSON Markup Language → DOM with reactive state
 *
 * Usage:
 *   ReaL.render(document.body, jtmlObject)
 *   or: &lt;script type="application/jtml"&gt; {...} &lt;/script&gt;
 */
console.log('[ReaL] v0.2 loaded');
const ReaL = (() => {
    const LOG = (...args) => console.log('[ReaL]', ...args);
    let _state = {};
    let _bindings = {}; // fieldName → [updateFn, ...]
    let _styles = {};
    let _storageKey = null;

    // --- Protocol Registry ---
    const _protocols = {
        http: { type: 'request', format: 'json' },
        sse: { type: 'stream', linePrefix: 'data: ', end: '[DONE]', format: 'json' },
        ws: { type: 'socket', format: 'json' }
    };

    // --- Reactive State ---
    function createState(initial = {}) {
        _state = {};
        _bindings = {};
        return new Proxy(initial, {
            set(target, key, value) {
                target[key] = value;
                _state[key] = value;
                LOG('state', key, '=', value);
                notify(key);
                if (_storageKey) {
                    try { localStorage.setItem(_storageKey, JSON.stringify(target)); } catch { }
                }
                return true;
            },
            get(target, key) {
                return target[key];
            }
        });
    }

    let state;

    function notify(key) {
        if (_bindings[key]) {
            _bindings[key].forEach(fn => fn(state[key]));
        }
    }

    function subscribe(key, fn) {
        if (!_bindings[key]) _bindings[key] = [];
        _bindings[key].push(fn);
    }

    function bindVisibility(el, expression) {
        if (typeof expression !== 'string') return;
        const inverted = expression.startsWith('!$');
        const key = expression.replace(/^!?\$/, '');
        const update = value => {
            const visible = inverted ? !value : !!value;
            el.style.display = visible ? '' : 'none';
        };
        update(state[key]);
        subscribe(key, update);
    }

    // --- Template: $var substitution ---
    function interpolate(text) {
        if (typeof text !== 'string') return text;
        return text.replace(/\$([a-zA-Z_][a-zA-Z0-9_]*)/g, (_, key) => {
            return state[key] !== undefined ? state[key] : '';
        });
    }

    // --- JSS → CSS custom properties ---
    function applyStyles(styles, root) {
        _styles = styles || {};
        if (_styles.colors) {
            Object.entries(_styles.colors).forEach(([name, value]) => {
                root.style.setProperty(`--color-${name}`, value);
            });
        }
        if (_styles.radius) {
            Object.entries(_styles.radius).forEach(([name, value]) => {
                root.style.setProperty(`--radius-${name}`, value);
            });
        }
        if (_styles.shadow) {
            Object.entries(_styles.shadow).forEach(([name, value]) => {
                root.style.setProperty(`--shadow-${name}`, value);
            });
        }
    }

    function resolveStyle(styleObj) {
        if (!styleObj) return '';
        const parts = [];
        // JSS token shortcuts
        const shortcuts = {
            bg: (v) => `background:${_styles.colors?.[v] || v}`,
            color: (v) => `color:${_styles.colors?.[v] || v}`,
            radius: (v) => `border-radius:${_styles.radius?.[v] || v}`,
            shadow: (v) => `box-shadow:${_styles.shadow?.[v] || v}`,
        };
        Object.entries(styleObj).forEach(([key, val]) => {
            if (shortcuts[key]) {
                parts.push(shortcuts[key](val));
            } else {
                // CSS passthrough: camelCase → kebab-case
                const cssKey = key.replace(/[A-Z]/g, m => '-' + m.toLowerCase());
                parts.push(`${cssKey}:${val}`);
            }
        });
        return parts.join(';');
    }

    // --- Render node ---
    function renderNode(desc, parent) {
        // Each desc is like {"div": {...}} or {"button": {...}}
        const tag = Object.keys(desc)[0];
        const props = desc[tag];

        if (tag === 'enter') {
            parent.appendChild(document.createElement('br'));
            return;
        }

        let el;

        switch (tag) {
            case 'div': {
                el = document.createElement('div');

                // Static text with $var interpolation
                if (props.text) {
                    el.textContent = interpolate(props.text);
                    // Subscribe to reactive updates for $vars
                    const vars = (props.text.match(/\$([a-zA-Z_]\w*)/g) || []).map(v => v.slice(1));
                    vars.forEach(v => subscribe(v, () => {
                        el.textContent = interpolate(props.text);
                    }));
                }

                // Bind: one-way from state → div text
                if (props.bind) {
                    subscribe(props.bind, val => {
                        if (props.format === 'json') {
                            el.textContent = JSON.stringify(val, null, 2);
                        } else {
                            el.textContent = val;
                        }
                    });
                    // Init
                    const initVal = state[props.bind];
                    if (initVal !== undefined) {
                        el.textContent = props.format === 'json'
                            ? JSON.stringify(initVal, null, 2)
                            : initVal;
                    }
                }

                if (props.format === 'json') {
                    el.style.whiteSpace = 'pre';
                    el.style.fontFamily = 'monospace';
                }

                // Visibility
                if (props.visible !== undefined) {
                    bindVisibility(el, props.visible);
                }

                // Children
                if (props.children) {
                    props.children.forEach(child => renderNode(child, el));
                }
                break;
            }

            case 'button': {
                // Smart: navigate → <a>, otherwise <button>
                if (props.onClick?.navigate) {
                    el = document.createElement('a');
                    el.href = interpolate(props.onClick.navigate);
                    el.textContent = interpolate(props.text || '');
                } else {
                    el = document.createElement('button');
                    el.textContent = interpolate(props.text || '');
                    if (props.onClick) {
                        el.addEventListener('click', () => handleAction(props.onClick));
                    }
                    if (typeof props.disabled === 'string' && props.disabled.startsWith('$')) {
                        const key = props.disabled.slice(1);
                        const update = value => { el.disabled = !!value; };
                        update(state[key]);
                        subscribe(key, update);
                    }
                }
                break;
            }

            case 'textarea': {
                const rows = props.rows || 1;
                if (rows <= 1) {
                    el = document.createElement('input');
                    el.type = props.type || 'text';
                    el.placeholder = props.placeholder || '';
                } else {
                    el = document.createElement('textarea');
                    el.rows = rows;
                    el.placeholder = props.placeholder || '';
                }

                if (props.id) el.id = props.id;

                // Bind: two-way
                if (props.bind) {
                    el.value = state[props.bind] || '';
                    el.addEventListener('input', () => { state[props.bind] = el.value; });
                    subscribe(props.bind, val => { if (el.value !== val) el.value = val || ''; });
                }
                break;
            }

            case 'progress': {
                el = document.createElement('progress');
                el.value = props.value || 0;
                el.max = props.max || 100;

                if (props.bind) {
                    subscribe(props.bind, val => { el.value = val; });
                }

                if (props.visible !== undefined) {
                    bindVisibility(el, props.visible);
                }
                break;
            }

            case 'select': {
                el = document.createElement('select');
                if (props.options) {
                    props.options.forEach(opt => {
                        const o = document.createElement('option');
                        o.value = typeof opt === 'object' ? opt.value : opt;
                        o.textContent = typeof opt === 'object' ? opt.label : opt;
                        el.appendChild(o);
                    });
                }
                if (props.bind) {
                    const first = props.options?.[0];
                    const firstValue = typeof first === 'object' ? first.value : first;
                    el.value = state[props.bind] || firstValue || '';
                    if (!state[props.bind] && firstValue) state[props.bind] = firstValue;
                    el.addEventListener('change', () => { state[props.bind] = el.value; });
                    subscribe(props.bind, val => { if (el.value !== val) el.value = val; });
                }
                break;
            }

            default: {
                // SVG namespace tags
                const SVG_NS = 'http://www.w3.org/2000/svg';
                const SVG_TAGS = new Set([
                    'svg', 'g', 'defs', 'use', 'symbol',
                    'rect', 'circle', 'ellipse', 'line', 'polyline', 'polygon', 'path',
                    'text', 'tspan', 'textPath',
                    'linearGradient', 'radialGradient', 'stop', 'pattern',
                    'filter', 'feGaussianBlur', 'feColorMatrix', 'feMerge', 'feMergeNode',
                    'feDropShadow', 'feBlend', 'feComposite', 'feOffset', 'feFlood',
                    'clipPath', 'mask', 'marker',
                    'animate', 'animateTransform', 'animateMotion', 'set',
                    'image', 'foreignObject'
                ]);

                const isSvg = SVG_TAGS.has(tag) || parent.namespaceURI === SVG_NS;
                el = isSvg
                    ? document.createElementNS(SVG_NS, tag)
                    : document.createElement(tag);

                // Apply all props as attributes (skip children, text, style)
                if (props && typeof props === 'object') {
                    Object.entries(props).forEach(([key, val]) => {
                        if (key === 'children' || key === 'text' || key === 'style') return;
                        if (isSvg) {
                            el.setAttribute(key, val);
                        } else {
                            el.setAttribute(key, val);
                        }
                    });

                    // Text content
                    if (props.text !== undefined) {
                        el.textContent = interpolate(String(props.text));
                    }

                    // Inline style object
                    if (props.style) {
                        el.setAttribute('style', resolveStyle(props.style));
                    }

                    // Recursive children
                    if (props.children) {
                        props.children.forEach(child => renderNode(child, el));
                    }
                }
                break;
            }
        }

        // Common props
        if (props.id) el.id = props.id;
        if (props.class) el.className = props.class;
        if (props.style) el.setAttribute('style', resolveStyle(props.style));

        parent.appendChild(el);
    }

    // --- JSON path resolver (e.g. "choices.0.delta.content") ---
    function resolvePath(obj, path) {
        if (!path) return obj;
        return path.split('.').reduce((o, k) => o?.[k], obj);
    }

    // --- Action handler ---
    function handleAction(action) {
        if (action.set) {
            Object.entries(action.set).forEach(([k, v]) => {
                const raw = typeof v === 'string' ? interpolate(v) : v;
                // Evaluate simple expressions: "1 + 1", "5 - 2", "3 * 4"
                if (typeof raw === 'string' && /^[\d.\s+\-*/%()]+$/.test(raw.trim())) {
                    try { state[k] = Function('"use strict"; return (' + raw + ')')(); } catch { state[k] = raw; }
                } else { state[k] = raw; }
            });
        }
        if (action.navigate) {
            window.location.href = interpolate(action.navigate);
        }
        LOG('action', action);
        if (action.fetch) {
            const f = action.fetch;
            const url = interpolate(f.url);
            const method = f.method ? interpolate(f.method) : 'GET';
            const target = f.into;
            const proto = _protocols[f.protocol] || _protocols.http;

            // Build headers
            const headers = { 'Content-Type': 'application/json' };
            if (f.headers) {
                Object.entries(f.headers).forEach(([k, v]) => {
                    headers[k] = interpolate(v);
                });
            }

            // Build body
            // Deep interpolation for object values
            function deepInterpolate(obj) {
                if (typeof obj === 'string') return interpolate(obj);
                if (Array.isArray(obj)) return obj.map(deepInterpolate);
                if (obj && typeof obj === 'object') {
                    const out = {};
                    for (const [k, v] of Object.entries(obj)) out[k] = deepInterpolate(v);
                    return out;
                }
                return obj;
            }

            let body;
            if (f.body && method !== 'GET') {
                body = typeof f.body === 'string'
                    ? interpolate(f.body)
                    : JSON.stringify(deepInterpolate(f.body));
            }

            const opts = { method, headers };
            if (body) opts.body = body;

            LOG('fetch →', method, url, '\nheaders:', JSON.stringify(headers), '\nbody:', body);

            // --- Stream protocol (SSE) ---
            if (proto.type === 'stream') {
                state[target] = '';
                fetch(url, opts)
                    .then(r => {
                        const reader = r.body.getReader();
                        const decoder = new TextDecoder();
                        (function read() {
                            reader.read().then(({ done, value }) => {
                                if (done) {
                                    if (action.set?.loading !== undefined) state.loading = false;
                                    return;
                                }
                                const chunk = decoder.decode(value, { stream: true });
                                chunk.split('\n').forEach(line => {
                                    if (proto.end && line.includes(proto.end)) return;
                                    const prefix = proto.linePrefix || '';
                                    if (!line.startsWith(prefix)) return;
                                    const payload = line.slice(prefix.length).trim();
                                    if (!payload) return;
                                    try {
                                        const json = proto.format === 'json' ? JSON.parse(payload) : payload;
                                        const token = resolvePath(json, f.path) || '';
                                        state[target] += token;
                                    } catch { }
                                });
                                read();
                            });
                        })();
                    })
                    .catch(err => {
                        state[target] = `Error: ${err.message}`;
                        if (action.set?.loading !== undefined) state.loading = false;
                    });
            }
            // --- Request protocol (HTTP) ---
            else {
                fetch(url, opts)
                    .then(r => r.text())
                    .then(text => {
                        try {
                            const value = JSON.parse(text);
                            state[target] = resolvePath(value, f.path) ?? value.error ?? text;
                        }
                        catch { state[target] = text; }
                        if (action.set?.loading !== undefined) state.loading = false;
                    })
                    .catch(err => {
                        state[target] = `Error: ${err.message}`;
                        if (action.set?.loading !== undefined) state.loading = false;
                    });
            }
        }
    }

    // --- Main render ---
    function render(root, jtml) {
        // LocalStorage persistence
        _storageKey = 'real:' + (jtml.id || location.pathname);
        let initial = jtml.state || {};
        try {
            const saved = localStorage.getItem(_storageKey);
            if (saved) initial = { ...initial, ...JSON.parse(saved) };
        } catch { }
        state = createState(initial);

        // Merge custom protocols
        if (jtml.protocols) {
            Object.assign(_protocols, jtml.protocols);
        }

        // Apply JSS
        applyStyles(jtml.styles, root);

        // Render markup
        if (jtml.markup) {
            jtml.markup.forEach(node => renderNode(node, root));
        }

        return state;
    }

    // --- Auto-discover <script type="application/jtml"> ---
    function autoInit() {
        document.querySelectorAll('script[type="application/jtml"]').forEach(script => {
            try {
                // Support yes/no → true/false
                const raw = script.textContent
                    .replace(/:\s*yes\b/g, ': true')
                    .replace(/:\s*no\b/g, ': false');
                const jtml = JSON.parse(raw);
                const container = document.createElement('div');
                container.className = 'real-app';
                script.parentNode.insertBefore(container, script);
                render(container, jtml);
            } catch (e) {
                console.error('[ReaL] Failed to parse JTML:', e);
            }
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', autoInit);
    } else {
        autoInit();
    }

    return { render, state: () => state };
})();
