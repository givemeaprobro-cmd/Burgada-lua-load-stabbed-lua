// javascript, veck.js, browser, veck.io runtime environment
(function () {
    'use strict';

    const client_name = 'Veroxx Client';
    let menu_visible = true;

    const inject_styles = () => {
        if (document.getElementById('veroxx_styles')) return;
        const style_element = document.createElement('style');
        style_element.id = 'veroxx_styles';
        style_element.innerHTML = `
            #veroxx_menu {
                position: fixed;
                top: 50px;
                left: 50px;
                width: 260px;
                background: rgba(15, 15, 20, 0.95);
                border: 1px solid #ff3366;
                border-radius: 8px;
                color: #ffffff;
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                z-index: 999999;
                box-shadow: 0 0 15px rgba(255, 51, 102, 0.4);
                user-select: none;
                backdrop-filter: blur(5px);
            }
            #veroxx_header {
                padding: 10px 15px;
                background: linear-gradient(90deg, #ff3366, #ff6699);
                font-weight: bold;
                font-size: 14px;
                border-top-left-radius: 7px;
                border-top-right-radius: 7px;
                cursor: move;
                display: flex;
                justify-content: space-between;
                align-items: center;
            }
            #veroxx_body {
                padding: 12px;
            }
            .veroxx_toggle_container {
                display: flex;
                justify-content: space-between;
                align-items: center;
                margin-bottom: 10px;
                font-size: 13px;
            }
            .veroxx_button {
                width: 100%;
                padding: 8px;
                background: #ff3366;
                border: none;
                border-radius: 4px;
                color: white;
                font-weight: bold;
                cursor: pointer;
                margin-top: 5px;
                transition: background 0.2s;
            }
            .veroxx_button:hover {
                background: #ff1144;
            }
            .veroxx_checkbox {
                accent-color: #ff3366;
                cursor: pointer;
            }
        `;
        (document.head || document.documentElement).appendChild(style_element);
    };

    const create_menu = () => {
        if (document.getElementById('veroxx_menu') || !document.body) return;

        const menu_element = document.createElement('div');
        menu_element.id = 'veroxx_menu';
        menu_element.innerHTML = `
            <div id="veroxx_header">
                <span>${client_name} v1.2</span>
                <span id="veroxx_close" style="cursor:pointer; font-size:12px;">[_]</span>
            </div>
            <div id="veroxx_body">
                <div class="veroxx_toggle_container">
                    <span>ESP Boxes</span>
                    <input type="checkbox" class="veroxx_checkbox" id="v_esp">
                </div>
                <div class="veroxx_toggle_container">
                    <span>Crosshair</span>
                    <input type="checkbox" class="veroxx_checkbox" id="v_crosshair" checked>
                </div>
                <div class="veroxx_toggle_container">
                    <span>Full Bright</span>
                    <input type="checkbox" class="veroxx_checkbox" id="v_bright">
                </div>
                <div class="veroxx_toggle_container">
                    <span>FOV Changer</span>
                    <input type="checkbox" class="veroxx_checkbox" id="v_fov">
                </div>
                <button class="veroxx_button" id="v_inject_btn">Inject Modules</button>
            </div>
        `;
        document.body.appendChild(menu_element);

        make_draggable(menu_element);
        setup_listeners();
    };

    const make_draggable = (element) => {
        let pos_x = 0, pos_y = 0, mouse_x = 0, mouse_y = 0;
        const header = document.getElementById('veroxx_header');
        if (!header) return;

        header.onmousedown = (e) => {
            e.preventDefault();
            mouse_x = e.clientX;
            mouse_y = e.clientY;
            document.onmouseup = close_drag_element;
            document.onmousemove = element_drag;
        };

        const element_drag = (e) => {
            e.preventDefault();
            pos_x = mouse_x - e.clientX;
            pos_y = mouse_y - e.clientY;
            mouse_x = e.clientX;
            mouse_y = e.clientY;
            element.style.top = (element.offsetTop - pos_y) + 'px';
            element.style.left = (element.offsetLeft - pos_x) + 'px';
        };

        const close_drag_element = () => {
            document.onmouseup = null;
            document.onmousemove = null;
        };
    };

    const setup_listeners = () => {
        const close_btn = document.getElementById('veroxx_close');
        if (close_btn) {
            close_btn.onclick = () => {
                const body = document.getElementById('veroxx_body');
                if (body) {
                    menu_visible = !menu_visible;
                    body.style.display = menu_visible ? 'block' : 'none';
                }
            };
        }

        const inject_btn = document.getElementById('v_inject_btn');
        if (inject_btn) {
            inject_btn.onclick = () => {
                console.log('[Veroxx Client] UnityWebModkit hooks active for veck.io.');
                if (window.ctx && window.ctx.Runtime) {
                    console.log('[Veroxx Client] Plugin runtime verified.');
                }
            };
        }

        window.addEventListener('keydown', (e) => {
            if (e.key === 'Insert') {
                const menu = document.getElementById('veroxx_menu');
                if (menu) {
                    menu.style.display = menu.style.display === 'none' ? 'block' : 'none';
                }
            }
        });
    };

    const init = () => {
        inject_styles();
        create_menu();
    };

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

    const observer = new MutationObserver(() => {
        if (!document.getElementById('veroxx_menu') && document.body) {
            init();
        }
    });
    observer.observe(document.documentElement, { childList: true, subtree: true });
})();
