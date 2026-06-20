document.addEventListener('DOMContentLoaded', () => {

    const container = document.querySelector('.game-container');
    const frame = document.getElementById('game-frame');
    const fullscreenBtn = document.getElementById('fullscreen-btn');
    if (!container || !frame) return;

    // ── État : le jeu a-t-il reçu un vrai clic ? ──
    let gameFocused = false;

    // ─────────────────────────────────────────────
    // Overlay devant l'iframe (capte les clics sans
    // laisser le jeu voler le focus tant qu'inactif)
    // ─────────────────────────────────────────────
    const overlay = document.createElement('div');
    overlay.style.cssText = 'position:absolute;inset:0;z-index:10;cursor:pointer;';
    container.appendChild(overlay);

    function focusGame() {
        gameFocused = true;
        overlay.style.display = 'none';
        container.classList.add('focused');

        frame.focus({ preventScroll: true });
        try {
            frame.contentWindow?.focus();
            const canvas = frame.contentDocument?.getElementById('canvas') || frame.contentDocument?.querySelector('canvas');
            if (canvas && typeof canvas.focus === 'function') {
                canvas.focus({ preventScroll: true });
            }
        } catch (_) {
            // Cross-document focus can fail while iframe is still loading.
        }
    }

    function blurGame() {
        gameFocused = false;
        overlay.style.display = 'block';
        container.classList.remove('focused');
    }

    // ─────────────────────────────────────────────
    // Clic sur l'overlay → active le jeu
    // ─────────────────────────────────────────────
    overlay.addEventListener('click', (e) => {
        e.preventDefault();
        e.stopPropagation();
        focusGame();

        // Retry on next frame in case iframe internals are not ready yet.
        requestAnimationFrame(focusGame);
    });

    frame.addEventListener('load', () => {
        if (gameFocused) {
            focusGame();
        }
    });

    function isGameFullscreen() {
        return document.fullscreenElement === container;
    }

    function updateFullscreenButton() {
        if (!fullscreenBtn) return;

        const icon = fullscreenBtn.querySelector('i');
        const label = isGameFullscreen() ? 'Quitter le plein écran' : 'Plein écran';

        fullscreenBtn.setAttribute('aria-label', label);
        fullscreenBtn.setAttribute('title', label);

        if (icon) {
            icon.classList.toggle('fa-expand', !isGameFullscreen());
            icon.classList.toggle('fa-compress', isGameFullscreen());
        }
    }

    fullscreenBtn?.addEventListener('click', async (e) => {
        e.preventDefault();
        e.stopPropagation();

        try {
            if (isGameFullscreen()) {
                await document.exitFullscreen();
            } else {
                await container.requestFullscreen();
                focusGame();
            }
        } catch (_) {
            // Some browsers reject fullscreen when the page is not user-activated.
        }

        updateFullscreenButton();
    });

    document.addEventListener('fullscreenchange', () => {
        updateFullscreenButton();
        if (isGameFullscreen()) {
            requestAnimationFrame(focusGame);
        }
    });

    updateFullscreenButton();

    let pendingGameLang = null;

    function notifyGameLocale(lang) {
        try {
            const win = frame.contentWindow;
            if (win && typeof win.godotSetLocale === 'function') {
                win.godotSetLocale(lang);
                pendingGameLang = null;
            } else {
                pendingGameLang = lang;
            }
        } catch (_) {
            pendingGameLang = lang;
        }
    }

    frame.addEventListener('load', () => {
        if (pendingGameLang) {
            notifyGameLocale(pendingGameLang);
        }
    });

    // ─────────────────────────────────────────────
    // Clic ailleurs → désactive le jeu
    // ─────────────────────────────────────────────
    document.addEventListener('click', (e) => {
        if (!container.contains(e.target)) {
            blurGame();
        }
    });

    // ─────────────────────────────────────────────
    // WHEEL — Zone jeu
    // Bloqué si le jeu n'a pas reçu de vrai clic
    // (le simple survol ne suffit pas)
    // ─────────────────────────────────────────────
    container.addEventListener('wheel', (e) => {
        if (!gameFocused) {
            e.stopPropagation();
            e.preventDefault();
        }
    }, { passive: false });

    // ─────────────────────────────────────────────
    // Sécurité : reset si l'utilisateur change d'onglet
    // ─────────────────────────────────────────────
    window.addEventListener('blur', () => {
        blurGame();
    });
    // ═══════════════════════════════════════════
    //  TRADUCTIONS
    // ═══════════════════════════════════════════
    const translations = {

        fr: {
            subtitle: 'Descendez dans les profondeurs.',
            'controls-title': '🎮 Contrôles',
            'ctrl-move-key': 'Z Q S D / Flèches',
            'ctrl-move': 'Déplacement',
            'ctrl-attack-key': 'Espace',
            'ctrl-attack': 'Attaque',
            'ctrl-interact': 'Interaction',
            'ctrl-r': 'Raccourcis',
            'about-title': '📖 À propos du jeu',
            'about-p1': 'Plongez dans un monde mystérieux où chaque étage de la tour recèle des secrets et des dangers. Explorez, combattez et découvrez l\'histoire qui se cache derrière cette tour énigmatique.',
            'about-p2': 'Chaque étage devient plus dangereux. Seuls les héros les plus courageux atteindront les profondeurs de la tour et découvriront ses véritables secrets.',
        },

        en: {
            subtitle: 'Descend into the depths.',
            'controls-title': '🎮 Controls',
            'ctrl-move-key': 'W A S D / Arrows',
            'ctrl-move': 'Movement',
            'ctrl-attack-key': 'Space',
            'ctrl-attack': 'Attack',
            'ctrl-interact': 'Interaction',
            'ctrl-r': 'Shortcuts',
            'about-title': '📖 About the game',
            'about-p1': 'Dive into the world of <strong>Tower of Destiny</strong>, an RPG where you must descend into the depths of a mysterious tower filled with monsters, traps, and mysteries.',
            'about-p2': 'Each floor grows more dangerous. Only the bravest heroes will reach the depths and uncover the truth hidden within.',
        },

        es: {
            subtitle: 'Desciende a las profundidades.',
            'controls-title': '🎮 Controles',
            'ctrl-move-key': 'W A S D / Flechas',
            'ctrl-move': 'Movimiento',
            'ctrl-attack-key': 'Espacio',
            'ctrl-attack': 'Ataque',
            'ctrl-interact': 'Interacción',
            'ctrl-r': 'Atajos',
            'about-title': '📖 Sobre el juego',
            'about-p1': 'Sumérgete en el mundo de <strong>Tower of Destiny</strong>, un RPG donde debes subir a la cima de una torre llena de monstruos, trampas y misterios.',
            'about-p2': 'Cada piso se vuelve más peligroso. Solo los héroes más valientes llegarán a la cima y descubrirán la verdad oculta.',
        },

        ja: {
            subtitle: '深淵へと降り立て。',
            'controls-title': '🎮 操作方法',
            'ctrl-move-key': 'W A S D / 矢印キー',
            'ctrl-move': '移動',
            'ctrl-attack-key': 'スペース',
            'ctrl-attack': '攻撃',
            'ctrl-interact': 'インタラクト',
            'ctrl-r': 'ショートカット',
            'about-title': '📖 ゲームについて',
            'about-p1': '<strong>タワー・オブ・デスティニー</strong>の世界に飛び込み、モンスター、罠、謎に満ちた塔の深部を探索するRPGです。',
            'about-p2': '各階層はより危険になります。最も勇敢な英雄だけが塔の深部に到達し、隠された真実を発見するでしょう。',
        },

    };

    // ═══════════════════════════════════════════
    //  FONCTION D'APPLICATION
    // ═══════════════════════════════════════════

// ═══════════════════════════════════════════
//  DROPDOWN LANGUE
// ═══════════════════════════════════════════

const langMeta = {
    fr: { flag: '🇫🇷', name: 'Français' },
    en: { flag: '🇬🇧', name: 'English'  },
    es: { flag: '🇪🇸', name: 'Español'  },
    ja: { flag: '🇯🇵', name: '日本語'   },
};

const dropdown    = document.getElementById('langDropdown');
const toggle      = document.getElementById('langToggle');
const selectedFlag = document.getElementById('selectedFlag');
const selectedName = document.getElementById('selectedName');

// Ouvre / ferme le menu
toggle.addEventListener('click', (e) => {
    e.stopPropagation();
    dropdown.classList.toggle('open');
});

// Ferme si clic ailleurs
document.addEventListener('click', () => dropdown.classList.remove('open'));

// Clics sur les options
document.querySelectorAll('.lang-option').forEach(opt => {
    opt.addEventListener('click', () => {
        applyLang(opt.dataset.lang);
        dropdown.classList.remove('open');
    });
});

// ═══════════════════════════════════════════
//  FONCTION D'APPLICATION (mise à jour du bouton)
// ═══════════════════════════════════════════
function applyLang(lang) {
    const dict = translations[lang];
    if (!dict) return;

    // i18n
    document.querySelectorAll('[data-i18n]').forEach(el => {
        const key = el.getAttribute('data-i18n');
        if (dict[key] !== undefined) el.innerHTML = dict[key];
    });

    // Met à jour le bouton principal
    const meta = langMeta[lang];
    if (meta) {
        selectedFlag.textContent = meta.flag;
        selectedName.textContent = meta.name;
    }

    // Active visuellement l'option choisie
    document.querySelectorAll('.lang-option').forEach(opt => {
        opt.classList.toggle('active', opt.dataset.lang === lang);
    });

    localStorage.setItem('rpg-lang', lang);
    notifyGameLocale(lang);
}

    // ═══════════════════════════════════════════
    //  INIT : langue mémorisée ou français par défaut
    // ═══════════════════════════════════════════
    const saved = localStorage.getItem('rpg-lang') || 'fr';
    applyLang(saved);

});
